//============================================================================
//  ddram_rotate_arb.sv
//
//  Two-master arbiter for the single HPS->FPGA DDR3 bridge (top-level DDRAM_*),
//  added to let the standard MiSTer sys/screen_rotate.v rotation frame buffer
//  share the DDR3 port with the PSX VRAM store.
//
//  ------------------------------------------------------------------------
//  Why this module instead of routing both masters through rtl/ddram.sv:
//
//  The user's directive was to share the DDR bridge "via rtl/ddram.sv". After
//  reading the actual module shapes that turned out to be infeasible without a
//  high-risk rewrite of the latency-critical VRAM path, so a thin 2:1 DDRAM
//  passthrough mux is used instead (this is sub-approach (b) from the design
//  doc, which explicitly permits "adapt ddram.sv or write a minimal one"):
//
//    * rtl/ddram.sv exposes narrow ch1..ch5 word channels (16/32/64-bit,
//      single/double-word, address HARD-WIRED to 0x30000000). It cannot carry
//      psx_top's native 64-bit *burst* master (BURSTCNT/DOUT_READY streaming) -
//      that is exactly the VRAM path the task says must stay bit-identical.
//    * sys/screen_rotate.v already exposes a COMPLETE DDRAM-style master
//      (BURSTCNT/ADDR/DIN/BE/WE/RD). It is write-only, single-beat, and targets
//      a DISTINCT DDR region (0x24000000, 3x8MB) that never overlaps VRAM
//      (0x30000000). So both sides already speak the raw DDRAM protocol and the
//      cleanest, lowest-risk join is a small priority mux, not ddram.sv.
//
//  Design:
//    * Master 0 (psx VRAM) has ABSOLUTE priority and read+write burst access.
//      Reads are always routed straight back to it (the rotate master never
//      reads, so DDRAM_DOUT/DOUT_READY are unconditionally psx's).
//    * Master 1 (screen_rotate) is a write-only, single-beat master. Its writes
//      are buffered in a small synchronous FIFO and drained onto the bus only in
//      cycles where psx is not requesting. Once a rotate write has been presented
//      it is held (psx stalled via p_busy) until the bridge accepts it, so no
//      write is ever lost mid-handshake.
//    * ROTATION OFF path is bit-identical to before: screen_rotate emits no
//      writes when no_rotate=1 (its FB_EN stays 0), so r_we never fires, the FIFO
//      stays empty, rot_drive stays 0, and every DDRAM_* pin plus p_busy tracks
//      the psx master exactly as when it drove the port directly.
//
//  This module and the screen_rotate master both run in the DDRAM clock domain
//  (clk_2x). The pixel->clk_2x crossing for screen_rotate's CE_PIXEL is done in
//  ZN1.sv (data held stable between pixel enables; only the enable is synced).
//============================================================================

module ddram_rotate_arb
(
	input         clk,              // DDRAM clock (clk_2x)

	// ---- physical DDRAM bridge (to sys_top) ----
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	// ---- master 0: PSX VRAM (priority, read+write burst) ----
	input   [7:0] p_burstcnt,
	input  [28:0] p_addr,
	output [63:0] p_dout,
	output        p_dout_ready,
	input         p_rd,
	input  [63:0] p_din,
	input   [7:0] p_be,
	input         p_we,
	output        p_busy,

	// ---- master 1: screen_rotate framebuffer (write-only, single-beat) ----
	input         r_we,             // 1-cycle write pulse (clk domain)
	input  [28:0] r_addr,
	input  [63:0] r_din,
	input   [7:0] r_be,

	// ---- master 2: Taito Zoom sound board (read + write, lowest priority) ----
	// Level request held until z_ack; reads return z_burstcnt beats on
	// z_dout/z_dout_ready.  Carries I-cache line fills (2-beat), ZSG-2 sample
	// fetches (1 beat) and the MRA ROM download writes.
	input         z_req,
	input         z_we,
	input  [28:0] z_addr,
	input  [63:0] z_din,
	input   [7:0] z_be,
	input   [7:0] z_burstcnt,
	output reg    z_ack,
	output [63:0] z_dout,
	output        z_dout_ready
);

// ---------------- small write FIFO for the rotate master ----------------
localparam AW = 6;                     // depth 64
localparam DW = 29 + 64 + 8;           // {addr, din, be} = 101 bits

reg  [DW-1:0] fifo [0:(1<<AW)-1];
reg  [AW:0]   wptr = 0;
reg  [AW:0]   rptr = 0;

wire          empty = (wptr == rptr);
wire          full  = (wptr[AW-1:0] == rptr[AW-1:0]) && (wptr[AW] != rptr[AW]);

wire [DW-1:0] fdat  = fifo[rptr[AW-1:0]];
wire [28:0]   f_addr = fdat[100:72];
wire [63:0]   f_din  = fdat[71:8];
wire  [7:0]   f_be   = fdat[7:0];

always @(posedge clk) begin
	if (r_we && !full) begin
		fifo[wptr[AW-1:0]] <= {r_addr, r_din, r_be};
		wptr <= wptr + 1'b1;
	end
end

// ---------------- priority arbitration (pipelined for DDR-clock timing) ----------------
// The rotate write is captured from the FIFO into a REGISTERED "presented" latch
// one cycle before it drives the bus, so the DDRAM_* data muxes see only registered
// inputs (pres_* and psx's already-registered p_*) with a registered select (issuing).
// This removes the FIFO-memory-read->wide-mux->pin path and the psx_active->p_busy
// feedback path that dominated the -0.981ns setup violation. The extra capture cycle
// only delays the (latency-tolerant) rotate writes; the PSX VRAM path is unaffected.
reg         issuing = 0;               // a captured rotate write is driving the bus
reg  [28:0] pres_addr;
reg  [63:0] pres_din;
reg   [7:0] pres_be;
wire        psx_active = p_rd | p_we;

// ---------------- master 2 (zoom) read-response ownership ----------------
// DDR3 read responses come back strictly in order, so all that is needed to
// keep the two reading masters apart is a beat count per owner plus the rule
// "a zoom read may only be issued while psx has NO outstanding read beats".
// That guarantees zoom's beats are always at the head of the response queue,
// so `z_out != 0` is an exact ownership test.  psx is free to issue afterwards
// (its beats simply queue behind), which keeps the VRAM path unthrottled.
reg  [15:0] psx_out = 0;               // outstanding psx read beats
reg   [3:0] z_out   = 0;               // outstanding zoom read beats
wire        to_zoom = (z_out != 0);

reg         z_drive = 0;               // a captured zoom access is driving the bus
reg         z_we_r;
reg  [28:0] z_addr_r;
reg  [63:0] z_din_r;
reg   [7:0] z_be_r;
reg   [7:0] z_bc_r;

// ---------------- master 2 (zoom) bounded-wait anti-starvation ----------------
// Normally zoom only wins the bus when psx is fully idle (~psx_active) and its
// read queue has drained (psx_out==0).  Under sustained PSX 3D rendering psx_out
// is continuously >0 and psx_active never drops, so a zoom fetch can be starved
// for thousands of clocks (measured ~11148 on HW) and the real-time ZSG-2 (~1041
// clk/sample) overruns -> audible pitch wobble.
//
// Fix: count clocks a zoom request waits un-granted (z_wait).  Past THRESHOLD we
// assert z_starving, which (a) stops accepting NEW psx bus commands (psx_gate,
// added to p_busy and gating the psx passthrough + psx_rd_accept in LOCKSTEP) so
// the in-flight psx read beats drain and psx_out reaches 0, and (b) lets start_z
// fire even while psx_active is still high (the psx master may hold its request
// lines while stalled by p_busy).  This never preempts an in-flight psx access -
// it only stops issuing NEW ones, inserting a short read bubble (~the drain
// length) that is bounded and rare.  Once zoom issues, z_out!=0 and the existing
// in-order response demux is exact because psx_out was 0 at issue time.
localparam  THRESHOLD = 9'd100;        // clocks a zoom request may wait before it forces a drain
reg  [8:0]  z_wait = 0;                // saturating wait counter (0..511)
wire        z_starving = (z_wait >= THRESHOLD);
wire        psx_gate   = z_starving;   // block NEW psx bus commands while draining for zoom

// begin presenting the next rotate write only when psx is idle and one is queued
// (also held off while draining for a starving zoom so zoom wins the bubble)
wire        start_rot  = ~issuing & ~z_drive & ~psx_active & ~empty & ~z_starving;
// zoom is lowest priority and additionally waits for the psx read queue to drain.
// It may fire while psx_active is high ONLY when starving, and only then because
// psx_gate has already bubbled the psx bus so no in-flight psx access is corrupted.
wire        start_z    = ~issuing & ~z_drive & ~start_rot
                         & (psx_out == 0) & z_req & (~psx_active | z_starving);

always @(posedge clk) begin
	if (start_rot) begin
		pres_addr <= f_addr;             // capture FIFO head into registers
		pres_din  <= f_din;
		pres_be   <= f_be;
		issuing   <= 1'b1;
		rptr      <= rptr + 1'b1;         // pop
	end
	else if (issuing && !DDRAM_BUSY) begin
		issuing   <= 1'b0;               // write accepted by the bridge
	end
end

always @(posedge clk) begin
	z_ack <= 1'b0;
	if (start_z) begin
		z_ack    <= 1'b1;                 // request captured; requester may drop z_req
		z_drive  <= 1'b1;
		z_we_r   <= z_we;
		z_addr_r <= z_addr;
		z_din_r  <= z_din;
		z_be_r   <= z_be;
		z_bc_r   <= z_burstcnt;
	end
	else if (z_drive && !DDRAM_BUSY) begin
		z_drive <= 1'b0;                  // accepted by the bridge
	end
end

// bounded-wait starvation counter: counts clocks a zoom request is pending and
// un-granted; reset the moment it is granted (start_z) or no request is pending.
always @(posedge clk) begin
	if (start_z)                z_wait <= 9'd0;             // granted this cycle
	else if (z_req & ~z_drive)  z_wait <= &z_wait ? z_wait : z_wait + 1'b1;  // pending & waiting (saturate)
	else                        z_wait <= 9'd0;             // no pending request
end

// outstanding-beat bookkeeping
// psx_gate held off keeps psx_rd_accept in LOCKSTEP with p_busy (accept <=> ~p_busy)
wire psx_rd_accept = ~issuing & ~z_drive & ~psx_gate & p_rd & ~DDRAM_BUSY;
wire z_rd_accept   =  z_drive & ~z_we_r  & ~DDRAM_BUSY;
wire psx_beat      = DDRAM_DOUT_READY & ~to_zoom;
wire z_beat        = DDRAM_DOUT_READY &  to_zoom;

always @(posedge clk) begin
	psx_out <= psx_out + (psx_rd_accept ? {8'd0, p_burstcnt} : 16'd0) - (psx_beat ? 16'd1 : 16'd0);
	z_out   <= z_out   + (z_rd_accept   ? z_bc_r[3:0]        :  4'd0) - (z_beat   ?  4'd1 :  4'd0);
end

// registered mux selects only (issuing / z_drive), as before
// While psx_gate (draining for a starving zoom) the psx passthrough is bubbled:
// RD/WE forced 0 so no NEW psx command is placed on the bus.  ADDR/DIN/BE/BURSTCNT
// are don't-care when RD=WE=0, so they are left as p_* (harmless).  An in-flight
// psx access is never touched - only the issue of a new one is suppressed.
assign DDRAM_ADDR     = issuing ? pres_addr : z_drive ? z_addr_r : p_addr;
assign DDRAM_DIN      = issuing ? pres_din  : z_drive ? z_din_r  : p_din;
assign DDRAM_BE       = issuing ? pres_be   : z_drive ? z_be_r   : p_be;
assign DDRAM_BURSTCNT = issuing ? 8'd1      : z_drive ? z_bc_r   : p_burstcnt;
assign DDRAM_WE       = issuing ? 1'b1      : z_drive ? z_we_r   : (psx_gate ? 1'b0 : p_we);
assign DDRAM_RD       = issuing ? 1'b0      : z_drive ? ~z_we_r  : (psx_gate ? 1'b0 : p_rd);

assign p_dout       = DDRAM_DOUT;
assign p_dout_ready = DDRAM_DOUT_READY & ~to_zoom;
assign z_dout       = DDRAM_DOUT;
assign z_dout_ready = DDRAM_DOUT_READY &  to_zoom;
// stall psx while a rotate or zoom access is actually driving the bus (registered).
// start_rot/start_z cannot collide with a psx request (both require ~psx_active),
// so p_busy need not depend combinationally on psx_active.
// psx_gate added in LOCKSTEP with psx_rd_accept (p_busy=1 <=> psx not accepted).
assign p_busy       = DDRAM_BUSY | issuing | z_drive | psx_gate;

endmodule
