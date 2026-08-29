// ---------------------------------------------------------------------------
// Copyright (c) 2026 XelaNotPu
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Original ZN-1 for MiSTer chip re-implementation. MAME is cited in-file only
// as the behavioral ground-truth reference, not as a source of code.
// ---------------------------------------------------------------------------

//============================================================================
//  Capcom QSound external SOUND subsystem for the ZN-1 MiSTer core
//  ---------------------------------------------------------------------------
//  Z80 (T80) @ 8 MHz  +  Capcom QSound DL-1425 (DSP16A) @ ~60 MHz  +  4MB
//  sample ROM.  Group B ZN-1 titles: sfex / sfexp / starglad / ts2 (coh1002c).
//
//  Reference hardware: MAME src/mame/sony/zn.cpp  capcom_zn_state (coh1002c)
//    - Z80        = XTAL 8 MHz                                (zn.cpp:573)
//    - QSound     = qsound_device, default 60 MHz DSP16A clk  (qsound.h:20-21)
//                   sample rate = 60e6 / 2 / 1248 = 24038 Hz
//    - main-CPU -> Z80 comm : generic_latch_8 @ 0x1FB60000    (zn.cpp:613)
//                   latch write -> Z80 /NMI (data_pending_cb) (zn.cpp:581)
//                   Z80 reads it via IN (I/O port 0x00)       (zn.cpp:627-629)
//    - Z80 also gets a 250 Hz periodic INT (line 0, HOLD)     (zn.cpp:576,643)
//
//  Z80 qsound_map (zn.cpp:616-624):
//    0x0000-0x7FFF  ROM (fixed, first 32 KB of 256 KB audiocpu region)
//    0x8000-0xBFFF  banked ROM window (16 KB, bank = write 0xD003 & 0x0F)
//    0xD000-0xD002  qsound_w  (DSP command:  D000=data MSB, D001=data LSB,
//                              D002=address, triggers DSP IRQ, clears ready)
//    0xD003         soundbank switch  (bank = data & 0x0F)   (zn.cpp:638-641)
//    0xD007         qsound_r  (status:  bit7 = DSP ready, 0x80=ready)
//    0xF000-0xFFFF  RAM (4 KB)
//  Z80 qsound_portmap (zn.cpp:626-629):
//    IN 0x00        soundlatch read (0x1FB60000 byte from main CPU)
//
//  QSound register/ROM semantics: MAME src/devices/sound/qsound.cpp
//    qsound_w  offset0=data[15:8], offset1=data[7:0], offset2=addr (+trigger)
//    qsound_r  = m_dsp_ready ? 0x80 : 0x00                 (qsound.cpp:175-178)
//    sample ROM addressed a byte at a time, high 8 bits used (qsound.cpp:289)
//
//  DSP wiring mirrors jotego jtcps15_sound.v (the CPS1.5 QSound board), minus
//  the Kabuki decode (ZN Z80 is plain) and minus the M68000-shared-bus DSP
//  writes (on ZN the Z80 itself writes D000-D002; the PSX side is only the
//  single 0x1FB60000 latch).
//
//  >>> DSP CORE = REAL jotego jtdsp16 (rtl/sound/jt_qsound/) <<<
//      The DL-1425 microcode (dl-1425.bin, first 8KB) is streamed into the DSP
//      internal program ROM via prog_addr/prog_data/prog_we (MRA index 8) while
//      the DSP is held in reset.  Everything AROUND the DSP (Z80, comm, banking,
//      SDRAM sample/program streaming, serial-sample recovery, mix) matches the
//      jtcps15_sound.v reference board.
//
//  Two clock domains (both from the core PLL, phase-aligned 1x/2x like jtcps15
//  clk48/clk96):
//    clk      = core clk_1x  = 33.8688 MHz : Z80, comm, banking, SDRAM streams
//    clk_dsp  = core clk_2x  = 67.7376 MHz : DSP16A + serial sample recovery
//               (>= 60 MHz needed so the DSP completes 2496 clocks per 24 kHz
//                sample; clk_1x alone (1409 clk/sample) is too slow — see note)
//============================================================================

module capcom_qsound
(
	input                clk,        // core clk_1x = 33.8688 MHz
	input                clk_dsp,    // core clk_2x = 67.7376 MHz (>=60 MHz)
	input                reset,      // active-high synchronous reset
	input                enable,     // Capcom-QSound active (platform==Capcom &
	                                 //   QSound ROM present); 0 -> inert, silent

	//-- PSX main-CPU -> Z80 command latch (0x1FB60000 byte write) --------------
	input                latch_wr,   // 1-cycle write strobe from main CPU
	input         [7:0]  latch_din,  // byte written to 0x1FB60000

	//-- QSound DL-1425 DSP program-ROM load (dl-1425.bin, first 8KB = 4K words) -
	//   Streamed in from the ioctl download (MRA index 8) while the DSP is held
	//   in reset.  Mirrors jtcps15_sound.v's prog_addr/prog_data/prog_we path:
	//   prog_addr[0] selects the byte lane (0=lsb,1=msb), prog_addr[12:1] the
	//   4K-word DSP internal ROM address (see jtdsp16_rom.v).
	input        [12:0]  prog_addr,
	input         [7:0]  prog_data,
	input                prog_we,

	//-- Z80 program ROM read bus (256 KB, read-only, from SDRAM) ---------------
	output reg   [17:0]  rom_addr,   // byte address into the audiocpu region
	output reg           rom_req,    // 1-cycle read request
	input         [7:0]  rom_data,   // returned byte (byte-selected by top level)
	input                rom_ready,  // read-data valid strobe

	//-- QSound sample ROM read bus (4 MB, read-only, from SDRAM) ---------------
	//   NOTE: MAME loads this region with ROM_LOAD16_WORD_SWAP, so the SDRAM
	//   image MUST be 16-bit word-byteswapped (see MRA note).  Address is a
	//   plain byte address; only [21:0] are meaningful for the 4 MB region.
	output reg   [22:0]  qsnd_addr,  // byte address into the 4 MB sample region
	output reg           qsnd_req,   // 1-cycle read request
	input         [7:0]  qsnd_data,  // returned byte
	input                qsnd_ready, // read-data valid strobe
	input        [22:0]  qsnd_rsp_addr, // #310: address qsnd_data was READ for (torn-address filter)

	//-- Stereo audio out (signed 16-bit) --------------------------------------
	output signed [15:0] snd_left,
	output signed [15:0] snd_right,

	//-- ZNQS ISSP debug taps (live DSP external-fetch handshake) ----------------
	// Driven unconditionally from the internal cen_dsp / dsp_ext_rq wires below.
	// Cost nothing if left unread; consumed only by the ZN1_ZNQS_PROBE ISSP vector.
	output               dbg_ext_rq,
	output               dbg_cen,
	// ZNQS STORED-content readback: word-0 byte snapshots from the DSP internal ROM
	// (jtdsp16_rom mem[0]).  {msb,lsb} == 0x0288 proves the microcode load committed.
	output        [7:0]  dbg_stored0_msb,
	output        [7:0]  dbg_stored0_lsb
);

	wire rst_all = reset | ~enable;

	//========================================================================
	// Clock enables
	//   Z80  : 8.0 MHz from 33.8688 MHz (fractional accumulator)
	//   INT  : 250 Hz periodic tick (line 0, HOLD-style) from clk
	//========================================================================
	localparam [26:0] CLK_HZ   = 27'd33_868_800;
	localparam [26:0] Z80_HZ   = 27'd8_000_000;
	localparam [26:0] CEN_WRAP = CLK_HZ - Z80_HZ;

	reg [26:0] cen_acc = 0;
	reg        cen_z80_raw = 0;
	always @(posedge clk) begin
		cen_z80_raw <= 0;
		if (cen_acc >= CEN_WRAP) begin
			cen_acc     <= cen_acc - CEN_WRAP;
			cen_z80_raw <= 1;
		end else begin
			cen_acc <= cen_acc + Z80_HZ;
		end
	end

	// 250 Hz periodic interrupt tick (clk / 135475.2 ~= 250 Hz)
	localparam [17:0] INT_DIV = 18'd135475;
	reg [17:0] int_cnt = 0;
	reg        int_tick = 0;
	always @(posedge clk) begin
		int_tick <= 0;
		if (rst_all) int_cnt <= 0;
		else if (int_cnt >= INT_DIV) begin int_cnt <= 0; int_tick <= 1; end
		else int_cnt <= int_cnt + 18'd1;
	end

	//========================================================================
	// Main-CPU -> Z80 command latch (generic_latch_8 @ 0x1FB60000)
	//   Write sets the latch and pulses /NMI (edge).  Z80 IN 0x00 reads it.
	//========================================================================
	reg  [7:0] soundlatch;
	reg        nmi_pulse;     // 1-cycle -> Z80 NMI edge
	always @(posedge clk) begin
		nmi_pulse <= 1'b0;
		if (rst_all) soundlatch <= 8'h00;
		else if (latch_wr) begin soundlatch <= latch_din; nmi_pulse <= 1'b1; end
	end

	//========================================================================
	// T80 Z80 CPU
	//========================================================================
	wire [15:0] z80_a;
	wire  [7:0] z80_do;
	reg   [7:0] z80_di;
	wire        z80_mreq_n, z80_iorq_n, z80_rd_n, z80_wr_n, z80_m1_n;

	// 250 Hz maskable INT on line 0 (level, cleared at end of ISR M1/IORQ ack).
	reg  z80_int_n;
	always @(posedge clk) begin
		if (rst_all) z80_int_n <= 1'b1;
		else if (int_tick) z80_int_n <= 1'b0;
		else if (~z80_m1_n & ~z80_iorq_n) z80_int_n <= 1'b1;  // interrupt ack
	end

	// NMI edge : hold /NMI low for one Z80 cen after a latch write.
	reg z80_nmi_n;
	always @(posedge clk) begin
		if (rst_all) z80_nmi_n <= 1'b1;
		else if (nmi_pulse) z80_nmi_n <= 1'b0;
		else if (cen_z80_g) z80_nmi_n <= 1'b1;  // released after Z80 sees it
	end

	wire z80_reset_n = ~rst_all;

	T80s z80
	(
		.RESET_n (z80_reset_n),
		.CLK     (clk),
		.CEN     (cen_z80_g),
		.WAIT_n  (1'b1),
		.INT_n   (z80_int_n),
		.NMI_n   (z80_nmi_n),
		.BUSRQ_n (1'b1),
		.M1_n    (z80_m1_n),
		.MREQ_n  (z80_mreq_n),
		.IORQ_n  (z80_iorq_n),
		.RD_n    (z80_rd_n),
		.WR_n    (z80_wr_n),
		.RFSH_n  (),
		.HALT_n  (),
		.BUSAK_n (),
		.A       (z80_a),
		.DI      (z80_di),
		.DO      (z80_do)
	);

	//------------------------------------------------------------------------
	// Z80 bus edge detection
	//------------------------------------------------------------------------
	reg z80_wr_n_d;
	always @(posedge clk) z80_wr_n_d <= z80_wr_n;
	wire mem_cyc  = ~z80_mreq_n;
	wire io_cyc   = ~z80_iorq_n & z80_m1_n;              // I/O (not intack)
	wire wr_start = mem_cyc & ~z80_wr_n & z80_wr_n_d;    // falling edge of WR

	//------------------------------------------------------------------------
	// Address decode  (matches zn.cpp qsound_map / qsound_portmap)
	//------------------------------------------------------------------------
	wire sel_rom_fix = (z80_a[15]   == 1'b0);                 // 0x0000-0x7FFF
	wire sel_rom_bnk = (z80_a[15:14]== 2'b10);                // 0x8000-0xBFFF
	wire sel_dpage   = (z80_a[15:12]== 4'hD);                 // 0xD000-0xDFFF
	wire sel_qs_wr   = sel_dpage & (z80_a[2:0] <= 3'd2);      // D000-D002
	wire sel_bank    = sel_dpage & (z80_a[2:0] == 3'd3);      // D003
	wire sel_qs_rd   = sel_dpage & (z80_a[2:0] == 3'd7);      // D007
	wire sel_ram     = (z80_a[15:12]== 4'hF);                 // 0xF000-0xFFFF
	wire sel_iolatch = io_cyc & (z80_a[7:0] == 8'h00);        // IN port 0

	//------------------------------------------------------------------------
	// Sound bank register (0xD003 & 0x0F) -> 16 x 16 KB window at 0x8000
	//------------------------------------------------------------------------
	reg [3:0] soundbank = 4'd0;
	always @(posedge clk) begin
		if (rst_all) soundbank <= 4'd0;
		else if (wr_start & sel_bank) soundbank <= z80_do[3:0];
	end

	// audiocpu region byte address:
	//   fixed  0x0000-0x7FFF -> {3'b000, a[14:0]}
	//   banked 0x8000-0xBFFF -> 0x8000 + bank*0x4000 + a[13:0]
	wire [17:0] rom_rd_addr = sel_rom_bnk
		? (18'h08000 + {soundbank, 14'd0} + {4'd0, z80_a[13:0]})
		: {3'b000, z80_a[14:0]};

	//------------------------------------------------------------------------
	// Z80 program ROM : 256 KB in SDRAM (read-only), wait-state fetch.
	//   Identical scheme to taito_fx1a_sound.sv : on a ROM read issue one SDRAM
	//   read and freeze the Z80 (gate cen) until the byte returns; a 1-entry
	//   cache keyed on address serves the completing cycle without re-fetch.
	//------------------------------------------------------------------------
	reg  [7:0]  rom_dout;
	reg         rom_valid;
	reg [17:0]  rom_addr_lat;

	wire        rom_read  = mem_cyc & ~z80_rd_n & (sel_rom_fix | sel_rom_bnk);
	wire        rom_hit   = rom_valid & (rom_addr_lat == rom_rd_addr);
	wire        rom_stall = rom_read & ~rom_hit;
	wire        cen_z80_g = cen_z80_raw & ~rom_stall;

	localparam ROMF_IDLE = 1'b0, ROMF_WAIT = 1'b1;
	reg rom_fstate;
	always @(posedge clk) begin
		rom_req <= 1'b0;
		if (rst_all) begin
			rom_valid    <= 1'b0;
			rom_fstate   <= ROMF_IDLE;
			rom_addr     <= 18'd0;
			rom_addr_lat <= 18'd0;
			rom_dout     <= 8'h00;
		end else begin
			case (rom_fstate)
				ROMF_IDLE:
					if (rom_read & ~rom_hit) begin
						rom_addr   <= rom_rd_addr;
						rom_req    <= 1'b1;
						rom_fstate <= ROMF_WAIT;
					end
				ROMF_WAIT:
					if (rom_ready) begin
						rom_dout     <= rom_data;
						rom_addr_lat <= rom_addr;
						rom_valid    <= 1'b1;
						rom_fstate   <= ROMF_IDLE;
					end
			endcase
		end
	end

	//------------------------------------------------------------------------
	// Z80 work RAM : 4 KB (0xF000-0xFFFF)
	//------------------------------------------------------------------------
	wire [7:0] ram_dout;
	qsnd_snd_bram #(.AW(12), .DW(8)) u_zram
	(
		.clk   (clk),
		.we    (wr_start & sel_ram),
		.waddr (z80_a[11:0]),
		.wdata (z80_do),
		.raddr (z80_a[11:0]),
		.rdata (ram_dout)
	);

	//========================================================================
	// QSound host command registers (Z80 writes D000-D002)   qsound.cpp:147
	//   cpu2dsp[15:8]=D000 (data MSB), [7:0]=D001 (data LSB), [23:16]=D002 addr
	//   A write to D002 raises the DSP IRQ handshake and clears "ready".
	//========================================================================
	reg [23:0] cpu2dsp;
	reg        dsp_irq;       // host->DSP interrupt (UR6B in CPS schematics)
	reg [1:0]  dsp_datasel;
	wire       qs_d002_w = wr_start & sel_dpage & (z80_a[2:0] == 3'd2);

	// pids_n from DSP (clk_dsp) synchronised into clk for the irq handshake.
	wire       dsp_pids_n_dspdom;
	reg  [1:0] pids_sync;
	always @(posedge clk) pids_sync <= {pids_sync[0], dsp_pids_n_dspdom};
	wire       dsp_pids_n = pids_sync[1];
	reg        last_pids_n;

	always @(posedge clk) begin
		if (rst_all) begin
			cpu2dsp     <= 24'd0;
			dsp_irq     <= 1'b0;
			dsp_datasel <= 2'd0;
			last_pids_n <= 1'b1;
		end else begin
			if (wr_start & sel_qs_wr) begin
				case (z80_a[2:0])
					3'd0: cpu2dsp[15: 8] <= z80_do;   // data MSB
					3'd1: cpu2dsp[ 7: 0] <= z80_do;   // data LSB
					3'd2: cpu2dsp[23:16] <= z80_do;   // address
					default: ;
				endcase
			end
			// DSP IRQ handshake (mirrors jtcps15_sound.v dsp glue)
			last_pids_n <= dsp_pids_n;
			if (qs_d002_w) begin
				dsp_irq     <= 1'b1;      // new command -> assert
				dsp_datasel <= 2'b11;     // present addr then data
			end else if (dsp_pids_n & ~last_pids_n) begin
				dsp_irq     <= 1'b0;      // DSP consumed a word
				dsp_datasel <= dsp_datasel >> 1;
			end
		end
	end

	// iack from DSP (clk_dsp) synchronised into clk for the status read.
	wire       dsp_iack_dspdom;
	reg  [1:0] iack_sync;
	always @(posedge clk) iack_sync <= {iack_sync[0], dsp_iack_dspdom};
	wire       dsp_ready = ~(dsp_irq | iack_sync[1]);   // qsound_r bit7

	//========================================================================
	// Z80 read-data mux
	//========================================================================
	always @(*) begin
		z80_di = 8'hFF;
		if (io_cyc & ~z80_rd_n) begin
			if (sel_iolatch) z80_di = soundlatch;      // IN 0x00
		end else if (mem_cyc & ~z80_rd_n) begin
			if      (sel_rom_fix | sel_rom_bnk) z80_di = rom_dout;
			else if (sel_ram)                   z80_di = ram_dout;
			else if (sel_qs_rd)                 z80_di = {dsp_ready, 7'b0}; // 0x80/0x00
		end
	end

	//========================================================================
	// ----  DSP DOMAIN (clk_dsp)  ------------------------------------------
	//   DSP16A + external sample-ROM address latch + serial sample recovery.
	//   Structure mirrors jotego jtcps15_sound.v (clk96 section).
	//========================================================================

	// cross cpu2dsp into clk_dsp (slow, quasi-static once dsp_irq set)
	reg [23:0] cpu2dsp_s;
	reg        dsp_irq_s;
	always @(posedge clk_dsp) begin
		dsp_irq_s <= dsp_irq;
		if (dsp_irq) cpu2dsp_s <= cpu2dsp;
	end

	reg  dsp_dsel96;
	always @(posedge clk_dsp) dsp_dsel96 <= dsp_datasel[1];

	reg [15:0] dsp_pbus_in;
	always @(*) dsp_pbus_in = dsp_dsel96 ? {8'd0, cpu2dsp_s[23:16]}
	                                     : cpu2dsp_s[15:0];

	// DSP core clock-enable / resample generator
	wire cen_dsp, dsp_cen_cko, base_sample;
	wire signed [15:0] pre_l, pre_r;
	wire dsp_ext_rq;

	// ZNQS debug taps: expose the live DSP external-fetch request and DSP clock-enable.
	assign dbg_ext_rq = dsp_ext_rq;
	assign dbg_cen    = cen_dsp;

	// DSP wires
	wire [15:0] dsp_ab, dsp_pbus_out;
	wire        dsp_pods_n;
	wire        dsp_do, dsp_ock, dsp_sadd, dsp_psel;

	// external sample byte held for the DSP ROM bus
	reg  [7:0]  qsnd_hold;
	reg         qsnd_ok;
	reg  [22:0] qsnd_hold_addr;   // #310: address qsnd_hold's byte was fetched for (stale-read fix)
	// #310 STALE-READ FIX (ported from ZN-2, silicon-verified there: 0/2048 corrupted fetches,
	// was 182/2048): only treat the held byte as valid when it was fetched for the CURRENT
	// address. qsnd_ok alone lags 1 clk_dsp behind an address change, letting the DSP consume
	// the previous address's byte -> in-band static that rides with the music.
	wire        qsnd_ok_valid = qsnd_ok & (qsnd_hold_addr == qsnd_addr);

	jtdsp16 u_dsp16
	(
		.rst      (rst_all),
		.clk      (clk_dsp),
		.clk_en   (cen_dsp),
		.cen_cko  (dsp_cen_cko),
		.ab       (dsp_ab),
		.rb_din   ({qsnd_hold, 8'h00}),
		.ext_rq   (dsp_ext_rq),
		.ext_ok   (qsnd_ok_valid),   // #310: address-tagged validity (no stale reads)
		.pbus_in  (dsp_pbus_in),
		.pbus_out (dsp_pbus_out),
		.pods_n   (dsp_pods_n),
		.pids_n   (dsp_pids_n_dspdom),
		.sdo      (dsp_do),
		.ock      (dsp_ock),
		.doen     (1'b1),
		.sadd     (dsp_sadd),
		.psel     (dsp_psel),
		.ser_out  (),
		.ose      (),
		.old      (),
		.ibf      (),
		.di       (1'b0),
		.ick      (1'b0),
		.ild      (1'b0),
		.irq      (dsp_irq_s),
		.iack     (dsp_iack_dspdom),
		.prog_addr(prog_addr),   // dl-1425.bin streamed from ioctl (MRA index 8)
		.prog_data(prog_data),
		.prog_we  (prog_we),
		.dbg_stored0_msb(dbg_stored0_msb),   // ZNQS: BRAM word-0 readback
		.dbg_stored0_lsb(dbg_stored0_lsb),
		.fault    ()
	);

	//------------------------------------------------------------------------
	// QSound sample ROM address latch (jtcps15_sound.v clk96 section)
	//   PODS strobe latches the low 16 bits (offset); ab[15] gated cen_cko
	//   latches the high bank bits.  We then stream that byte from SDRAM.
	//------------------------------------------------------------------------
	reg last_pods_n_d;
	always @(posedge clk_dsp) begin
		if (rst_all) begin
			qsnd_addr     <= 23'd0;
			last_pods_n_d <= 1'b1;
		end else begin
			last_pods_n_d <= dsp_pods_n;
			if (dsp_pods_n & ~last_pods_n_d) qsnd_addr[15:0]  <= dsp_pbus_out;
			if (dsp_ab[15] & dsp_cen_cko)    qsnd_addr[22:16] <= {1'b0, dsp_ab[5:0]};
		end
	end

	//------------------------------------------------------------------------
	// SDRAM sample fetch : request one byte, hold it, and raise qsnd_ok.
	//   (latency-tolerant : DSP cen is stalled via cen_dsp until qsnd_ok.)
	//
	//   BUGFIX (no-QSound-music): qsnd_ok must behave like jtcps15's LEVEL
	//   "data-valid-for-current-address" signal, NOT a one-shot pulsed only on
	//   address change.  The DSP gates its clock on qsnd_ok whenever it wants an
	//   external byte (cen_dsp: ext_rq ? qsnd_ok : 1).  The DL-1425 firmware's
	//   FIRST external (table/sample) read happens at the reset address (0) before
	//   it has issued any PODS address write, so qsnd_addr never "changes" from its
	//   reset value -> the old change-only trigger never fetched -> qsnd_ok stuck 0
	//   -> the DSP clock froze forever at that first read (verified in Verilator:
	//   ext_rq asserted ~99% of the time, 0 fetches served, PC frozen, 0 serial
	//   output).  We now ALSO fetch when the DSP requests a byte we do not yet hold
	//   for the current (unchanged) address, matching jtframe's continuous serve.
	//------------------------------------------------------------------------
	reg [22:0] qsnd_addr_d;
	reg        qsnd_busy;
	always @(posedge clk_dsp) begin
		qsnd_req <= 1'b0;
		if (rst_all) begin
			qsnd_addr_d    <= 23'd0;
			qsnd_hold      <= 8'h00;
			qsnd_hold_addr <= 23'h7FFFFF;  // != any real addr at reset -> ok invalid until first fetch
			qsnd_ok        <= 1'b0;
			qsnd_busy      <= 1'b0;
		end else begin
			qsnd_addr_d <= qsnd_addr;
			// Service a completed fetch FIRST, so that if a new address arrives on the SAME
			// cycle the address-change block below overrides qsnd_ok<=1 back to 0. Otherwise
			// (ready textually last) qsnd_ok would latch 1 while qsnd_hold still held the OLD
			// address's byte -> the DSP reads a STALE sample -> intermittent audio static.
			if (qsnd_ready) begin
				// #310 TORN-ADDRESS FILTER (root cause of the static, ported from ZN-2):
				// qsnd_addr is assembled from two separate DSP events (PODS = low 16 bits,
				// ab[15] = bank bits), so a bank switch fires the address-change trigger
				// twice — the FIRST request goes out for a hybrid "torn" address. Accept a
				// response only if it was read for the CURRENT full address; otherwise drop
				// it and clear busy so the ext_rq branch re-issues for the right address.
				if (qsnd_rsp_addr == qsnd_addr) begin
					qsnd_hold      <= qsnd_data;
					qsnd_hold_addr <= qsnd_addr;   // tag the byte with its address (DSP is stalled -> stable)
					qsnd_ok        <= 1'b1;
				end
				qsnd_busy <= 1'b0;   // superseded response: allow immediate re-issue
			end
			if (qsnd_addr != qsnd_addr_d) begin
				// address changed -> held byte is stale, fetch the new one (wins over ready)
				qsnd_req  <= 1'b1;
				qsnd_ok   <= 1'b0;
				qsnd_busy <= 1'b1;
			end else if (dsp_ext_rq & ~qsnd_ok & ~qsnd_busy) begin
				// DSP wants an external byte we do not hold yet for the current
				// (unchanged) address — notably the first read after reset.
				qsnd_req  <= 1'b1;
				qsnd_busy <= 1'b1;
			end
		end
	end

	//------------------------------------------------------------------------
	// Serial sample recovery (TDA1543-style) + resample cen generator.
	//------------------------------------------------------------------------
	wire sample_tick;
	qsnd_cen u_cen
	(
		.clk_dsp    (clk_dsp),
		.rst        (rst_all),
		.base_sample(base_sample),
		.qsnd_ok    (qsnd_ok_valid),   // #310: address-tagged validity (no stale reads)
		.ext_rq     (dsp_ext_rq),
		.qsnd_cen   (cen_dsp),
		.sample_tick(sample_tick)
	);

	reg [15:0] ser_cnt;
	reg        dsp_ockl, last_sadd, audio_ws;
	reg        left_done, right_done;
	reg signed [15:0] reg_left, reg_right;
	reg signed [15:0] r_pre_l, r_pre_r;
	reg               r_base_sample;

	always @(posedge clk_dsp) begin
		if (rst_all) begin
			ser_cnt    <= 16'd0;
			dsp_ockl   <= 1'b0;
			last_sadd  <= 1'b0;
			audio_ws   <= 1'b0;
			left_done  <= 1'b0;
			right_done <= 1'b0;
			reg_left   <= 16'sd0;
			reg_right  <= 16'sd0;
			r_pre_l    <= 16'sd0;
			r_pre_r    <= 16'sd0;
			r_base_sample <= 1'b0;
		end else begin
			dsp_ockl  <= dsp_ock;
			last_sadd <= dsp_sadd;
			r_base_sample <= 1'b0;
			// start of frame : latch channel and reload the 16-bit shift count
			if (~dsp_sadd & last_sadd) begin
				audio_ws <= dsp_psel;
				ser_cnt  <= 16'hFFFF;
			end
			// shift in one bit on each falling OCK
			if (dsp_ockl & ~dsp_ock & ser_cnt[15]) begin
				ser_cnt <= ser_cnt << 1;
				if (audio_ws) begin
					reg_right <= {reg_right[14:0], dsp_do};
					if (~ser_cnt[14]) right_done <= 1'b1;
				end else begin
					reg_left <= {reg_left[14:0], dsp_do};
					if (~ser_cnt[14]) left_done <= 1'b1;
				end
			end
			if (left_done & right_done) begin
				r_pre_l    <= reg_left;
				r_pre_r    <= reg_right;
				r_base_sample <= 1'b1;
				left_done  <= 1'b0;
				right_done <= 1'b0;
			end
		end
	end

	assign pre_l       = r_pre_l;
	assign pre_r       = r_pre_r;
	assign base_sample = r_base_sample;

	//========================================================================
	// Audio output (gated by enable).  pre_l/pre_r live in clk_dsp; they are
	// quasi-static between samples (24 kHz) so a plain resync into clk is safe.
	//========================================================================
	// pre_l/pre_r are a 16-bit value written in clk_dsp at the ~24 kHz sample rate. Sampling
	// them directly in clk_1x is an UNSYNCHRONIZED multi-bit CDC: whenever a clk_1x edge lands
	// on the sample-update edge the changing bits tear, injecting low-level noise that rides
	// with the music (audible static). Fix: cross a 1-bit "new sample" toggle through a 2-FF
	// synchronizer and latch pre_l only on the synchronized edge — by then pre_l has been
	// stable for several clk_1x cycles (next update is ~2817 clk_dsp cycles away), so no tearing.
	// Latch the output on the PRECISE period boundary (sample_tick), NOT the jittery base_sample:
	// pre_l is stable by then (DSP has slept since finishing the frame), and this removes the
	// frame-compute/ROM-fetch timing jitter that otherwise sidebands the signal (audible static
	// that "rides with the music"). Result: a true jitter-free 24 kHz output rate.
	reg signed [15:0] out_l, out_r;
	reg        smp_tog = 1'b0;
	always @(posedge clk_dsp) if (rst_all) smp_tog <= 1'b0; else if (sample_tick) smp_tog <= ~smp_tog;
	reg [2:0]  smp_sync = 3'b0;
	always @(posedge clk) begin
		smp_sync <= {smp_sync[1:0], smp_tog};
		if (smp_sync[2] ^ smp_sync[1]) begin
			out_l <= pre_l;
			out_r <= pre_r;
		end
	end

	// out_l/out_r is the CDC-clean 24 kHz sample held (ZOH). Fed straight to MiSTer's 48 kHz
	// path its ZOH images (24 kHz ± f) fold in as high-frequency hiss. Reconstruct with a
	// 3-pole low-pass (~10.5 kHz @ clk_1x=33.8688 MHz, 2^9) so the held steps are smoothed and
	// the audible imaging is attenuated ~20 dB before the mixer sees it.
	// Mild 3-pole ~10.5 kHz reconstruction filter (removes the worst >16 kHz ZOH imaging without
	// dulling the music). NOTE: the residual in-band "rides-with-music" static is NOT imaging
	// (proven: a 5.3 kHz brick wall did not remove it) — it is subtly distorted DSP samples,
	// leading suspect = sample-ROM bank/offset addressing vs MAME (needs deeper analysis).
	reg signed [31:0] rc1_l, rc2_l, rc3_l, rc1_r, rc2_r, rc3_r;
	always @(posedge clk) begin
		rc1_l <= rc1_l + (($signed({out_l,16'd0}) - rc1_l) >>> 9);
		rc2_l <= rc2_l + ((rc1_l - rc2_l) >>> 9);
		rc3_l <= rc3_l + ((rc2_l - rc3_l) >>> 9);
		rc1_r <= rc1_r + (($signed({out_r,16'd0}) - rc1_r) >>> 9);
		rc2_r <= rc2_r + ((rc1_r - rc2_r) >>> 9);
		rc3_r <= rc3_r + ((rc2_r - rc3_r) >>> 9);
	end
	assign snd_left  = enable ? rc3_l[31:16] : 16'sd0;
	assign snd_right = enable ? rc3_r[31:16] : 16'sd0;

endmodule


//----------------------------------------------------------------------------
// QSound DSP clock-enable / stall generator.
//   Mirrors jtcps15_qsnd_cen: the DSP is paced to a fixed sample rate by SLEEPING
//   between frames.  The DL-1425 microcode assumes a 60 MHz DSP clock and emits one
//   stereo frame every 2496 clocks (60e6/2496 = 24038 Hz).  We clock the DSP at
//   clk_dsp = 67.7376 MHz (>60 MHz so a whole 2496-clock frame fits inside one
//   sample period); once a frame completes (base_sample) the DSP sleeps until the
//   MAXCNT counter reaches one sample period, forcing the output rate to 24038 Hz.
//   Without this pacing the DSP free-runs at 67.7 MHz -> ~27.1 kHz (music ~13% sharp).
//   The cen is additionally stalled while an external sample-ROM byte is being
//   fetched (ext_rq & ~qsnd_ok), tolerating SDRAM latency; those stall clocks are
//   counted against the frame budget exactly as jtcps15 does.
//----------------------------------------------------------------------------
module qsnd_cen
(
	input      clk_dsp,
	input      rst,
	input      base_sample,
	input      qsnd_ok,
	input      ext_rq,
	output reg qsnd_cen,
	output reg sample_tick   // 1-clk_dsp pulse at the PRECISE period boundary (jitter-free 24 kHz)
);
	// 67.7376 MHz / 2818 = 24037 Hz (matches the 60 MHz/1248/2 = 24038 Hz hardware rate)
	localparam [11:0] MAXCNT = 12'd2817;
	reg [11:0] cnt   = 12'd0;
	reg        sleep = 1'b0;

	always @(posedge clk_dsp) begin
		sample_tick <= 1'b0;
		if (rst) begin
			cnt      <= 12'd0;
			sleep    <= 1'b0;
			qsnd_cen <= 1'b1;
		end else begin
			// run at full rate unless sleeping (rate pacing) or waiting on ROM (latency)
			qsnd_cen <= ~sleep & (ext_rq ? qsnd_ok : 1'b1);
			if (cnt == MAXCNT) begin
				sleep       <= 1'b0;      // wake for the next sample period
				cnt         <= 12'd0;
				sample_tick <= 1'b1;      // exact period boundary: pre_l is stable (DSP slept) -> latch output here
			end else begin
				cnt <= cnt + 12'd1;
				if (base_sample) sleep <= 1'b1;   // frame done -> sleep until period elapses
			end
		end
	end
endmodule


//----------------------------------------------------------------------------
// Simple synchronous dual-port byte BRAM (1 write port, 1 read port).
//----------------------------------------------------------------------------
module qsnd_snd_bram #(parameter AW=12, parameter DW=8)
(
	input               clk,
	input               we,
	input  [AW-1:0]     waddr,
	input  [DW-1:0]     wdata,
	input  [AW-1:0]     raddr,
	output reg [DW-1:0] rdata
);
	reg [DW-1:0] mem [0:(1<<AW)-1];
	always @(posedge clk) begin
		if (we) mem[waddr] <= wdata;
		rdata <= mem[raddr];
	end
endmodule
