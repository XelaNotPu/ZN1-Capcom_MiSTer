//============================================================================
//  PSX
//  Copyright (C) 2019 Robert Peip
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	// [MiSTer-DB9 BEGIN] - widened to 8 bits + USER_OSD/USER_PP for joydb wrapper
	input   [7:0] USER_IN,
	output  [7:0] USER_OUT,
	output        USER_OSD,
	output  [7:0] USER_PP,
	// [MiSTer-DB9 END]

	input         OSD_STATUS
);

assign HDMI_FREEZE = 1'b0;
assign HDMI_BOB_DEINT = status[41];

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign AUDIO_S   = 1;
assign AUDIO_MIX = status[8:7];


assign LED_USER  = bios_download | fixedrom_download | bankedrom_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire [ 3:0] frameindex;
wire [11:0] DisplayWidth;
wire [11:0] DisplayHeight;
wire [ 9:0] DisplayOffsetX;
wire [ 8:0] DisplayOffsetY;

// 90-degree screen rotation control (OSD "Rotation": 0=None 1=CW 2=CCW).
wire [1:0] rot_mode = status[13:12];
wire       rot_en   = (rot_mode == 2'd1) || (rot_mode == 2'd2);
wire       rot_ccw  = (rot_mode == 2'd2);

// Framebuffer outputs of sys/screen_rotate.v (instantiated in the VIDEO section).
// When rotation is active they drive the HPS framebuffer scanout (FB path);
// otherwise the FB_* pins keep their original meaning bit-for-bit.
wire        sr_fb_en;
wire  [4:0] sr_fb_format;
wire [11:0] sr_fb_width;
wire [11:0] sr_fb_height;
wire [31:0] sr_fb_base;
wire [13:0] sr_fb_stride;

assign FB_BASE    = rot_en ? sr_fb_base   : (status[11] ? 32'h30000000 : {8'h30, frameindex, DisplayOffsetY, DisplayOffsetX, 1'b0});
assign FB_EN      = rot_en ? sr_fb_en     : (status[14] || video_fbmode);
assign FB_FORMAT  = rot_en ? sr_fb_format : ((status[10] || video_fb24) ? 5'b00101 : 5'b01100);
assign FB_WIDTH   = rot_en ? sr_fb_width  : (status[11] ? 12'd1024 : DisplayWidth);
assign FB_HEIGHT  = rot_en ? sr_fb_height : (status[11] ? 12'd512  : DisplayHeight);
assign FB_STRIDE  = rot_en ? sr_fb_stride : 14'd2048;
assign FB_FORCE_BLANK = 0;


///////////////////////  CLOCK/RESET  ///////////////////////////////////

wire pll_locked;
wire clk_1x;
wire clk_2x;
wire clk_3x;
wire clk_vid;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_1x),
	.outclk_1(clk_2x),
	.outclk_2(clk_3x),
	.locked(pll_locked)
);

pll2 pll2
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),
   .reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);


wire FFrequest = joy[17] && ~FB_LL && ~DIRECT_VIDEO;
wire syncVideoOut = 0; //status[57] && ~FB_LL && ~DIRECT_VIDEO;
wire syncVideoClock = 0; //status[56] && ~FB_LL && ~DIRECT_VIDEO;

always @(posedge CLK_50M) begin : cfg_block
	reg pald = 0, pald2 = 0;
	reg pdbg = 0, pdbg2 = 0;
	reg pffw = 0, pffw2 = 0;
	reg [3:0] state = 0;

	pald  <= isPal;
	pald2 <= pald;

	pdbg  <= syncVideoClock;
	pdbg2 <= pdbg;

	pffw  <= fast_forward;
	pffw2 <= pffw;

	cfg_write <= 0;
	if(pald2 != pald || pdbg2 != pdbg || pffw2 != pffw) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
         3: begin
					cfg_address <= 5;
					cfg_data <= pffw2 ? 131842 : pdbg2 ? 771 : 1028;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 7;
					cfg_data <= pffw2 ? 2147483648 : pdbg2 ? 551954751 : pald2 ? 2201376898 : 2537930535;
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

reg fast_forward;
reg ff_latch;

always @(posedge clk_1x) begin : ffwd
	reg last_ffw;
	reg ff_was_held;
	longint ff_count;

	last_ffw <= FFrequest;

	if (FFrequest)
		ff_count <= ff_count + 1;

	if (~last_ffw & FFrequest) begin
		ff_latch <= 0;
		ff_count <= 0;
	end

	if ((last_ffw & ~FFrequest)) begin
		ff_was_held <= 0;

		if (ff_count < 10000000 && ~ff_was_held) begin
			ff_was_held <= 1;
			ff_latch <= 1;
		end
	end

	fast_forward <= (FFrequest | ff_latch);
end

////////////////////////////  MB3773 WATCHDOG  //////////////////////////////
// Taito FX-1A/FX-1B boards carry a Fujitsu MB3773 power-supply monitor with a 5-second
// watchdog. The game strobes it by toggling bit5 of the bank register (0x1FB40000); the
// MB3773 re-arms on the FALLING edge (MAME: mb3773->write_line_ck(BIT(data,5)), 5s timeout,
// machine().schedule_soft_reset() on expiry).
//
// This is NOT just a hang-recovery nicety: it is the board's ONLY reset path. The test-menu
// "EXIT (RESET)" item works by deliberately STOPPING the strobe so the MB3773 resets the
// board, which reboots and re-reads the NVRAM the operator just wrote with FACTORY SETTING.
// Without a watchdog the game simply spins forever -> the black screen after EXIT.
//
// Verified in MAME (raystorm, attract): the strobe arrives roughly every ~3s, comfortably
// inside the 5s window, so a faithful 5s timeout never fires during normal play.
//
// Safety deviation from real hardware: the timer only ARMS after the first kick is seen.
// On a real board it is armed from power-on; arming lazily means a title that never strobes
// (for any reason) can never be put into a reset loop by this logic.
wire zn_wd_kick;
localparam [27:0] WD_TIMEOUT = 28'd169_344_000;   // 5s @ 33.8688 MHz
reg  [27:0] wd_cnt   = 0;
reg         wd_armed = 0;
reg  [15:0] wd_rst_cnt = 0;                       // hold reset ~2ms so the core restarts cleanly
wire        wd_reset = (wd_rst_cnt != 0);
// (the timer itself lives further down, after ioctl_download is declared)

wire reset_or = RESET | buttons[1] | status[0] | ioctl_download | wd_reset;

////////////////////  TAITO ZOOM SOUND BOARD (FX-1B/1Z)  ////////////////////
// MN10200 + TMS57002 stub + ZSG-2, see rtl/taito_zoom_top.sv.
// DDR3 MAP (all three regions verified non-overlapping):
//   0x24000000 + 3x8MB   screen_rotate frame buffer (sys/arcade_video.v MEM_BASE)
//   0x30000000 + 2MB     PSX VRAM (rtl/ddram.sv / psx_mister.vhd)
//   0x32000000 + 512KB   zoom program ROM   (MRA ioctl index 6, e24-09.14)
//   0x32100000 + 4MB     zoom sample ROM    (MRA ioctl index 7, e24-04.27)
// The zoom regions sit above VRAM inside the same FPGA DDR window and touch
// neither of the two existing users.
localparam [28:0] ZOOM_PROG_BASE = 29'h0640_0000;   // byte 0x32000000 >> 3
localparam [28:0] ZOOM_SMPL_BASE = 29'h0642_0000;   // byte 0x32100000 >> 3

wire        zoom_reg_data_wr;
wire [15:0] zoom_reg_data;
wire        zoom_reg_addr_wr;
wire [15:0] zoom_reg_addr;
wire        zoom_irq0_wr;
wire  [6:0] zoom_mbx_addr;
wire  [1:0] zoom_mbx_be;
wire [15:0] zoom_mbx_din;
wire        zoom_mbx_we;
wire [15:0] zoom_mbx_q;
wire signed [15:0] zoom_snd_l, zoom_snd_r;   // Taito Zoom (FX-1B) stereo, 0 unless zoom_enable
wire  [3:0] zoom_dbg;

// The FINAL audio mix -> AUDIO_L/R is assembled further down, after ALL secondary sound
// blocks (Taito Zoom, FX-1A YM2610B, Capcom QSound) are instantiated.  The secondaries are
// mutually exclusive per platform (a board is exactly one of FX-1B / FX-1A / Capcom / plain),
// so they OR-combine into one term that is added to the SPU with signed saturation.

////////////////////////////  HPS I/O  //////////////////////////////////

// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6          7         8         9
// 01234567890123456789012345678901 23456789012345678901234567890123 45678901234567890123456789012345
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
//  XXXX XXXXXX XXXXXX XXXXX  XX XX XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXXXXXXXXXXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"ZN1;;",
	"P1,Video & Audio;",
	"P1-;",
	"P1O[33:32],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[35:34],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"DEP1O[62],Fixed HBlank,On,Off;",
	"DEP1O[55],Fixed VBlank,Off,On;",
	"d5P1O[4:3],Vertical Crop,Off,On(224/270),On(216/256);",
	"P1O[67],Horizontal Crop,Off,On;",
	"P1O[61],Black Transitions,On,Off;",
	"P1O[41],Deinterlacing,Weave,Bob;",
	"P1O[89],Render 480i as 480p,Off,On;",
	"P1O[60],Sync 480i for HDMI,Off,On;",
	"P1O[24],Rotate,Off,On;",
	"P1O[13:12],Rotation,None,CW,CCW;",
	"P1O[25],Pause Screen,Horizontal,Vertical;",
	"P1-;",
	// CRT Adjust (analog CRT geometry, core-side crt_adjust.sv). Default Off ->
	// HDMI/analog untouched. On: analog picture stretches/shifts (HDMI follows).
	// Amounts hidden until On via status_menumask bit1 (H1). Auto-disabled while
	// digitally rotating (rot_en) - the screen_rotate DDR path would normalize it.
	"P1O[96],CRT Adjust (analog),Off,On;",
	"H1P1O[101:97],CRT H-Size,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H1P1O[106:102],CRT H-Position,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H1P1O[111:107],CRT V-Shift,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"P1-;",
	"P1O[22],Dithering,On,Off;",
	"P1O[8:7],Stereo Mix,None,25%,50%,100%;",
	"-;",
	"P2,Debug;",
	"P2O[94],Test Mode,Off,On;",
	"P2O[95],Service Mode,Off,On;",
	"-;",
	// [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
`ifdef DB9_NO_SATURN_KEYGATE
	// Saturn key gate compiled out on this variant (fit) - label it honestly.
	"O[127:126],UserIO Joystick,Off,Saturn (N/A),DB9 MD,DB15;",
`else
	"O[127:126],UserIO Joystick,Off,Saturn,DB9 MD,DB15;",
`endif
	"O[125],UserIO Players, 1 Player,2 Players;",
	// [MiSTer-DB9-Pro END]
	"-;",
	"DIP;",
	"-;",
	// Hidden: PSX_MiSTer leftovers not required by the ZN-1 core. The status bits
	// still exist (default 0 = Off = safe) so the datapath is unchanged; these
	// menu entries are hidden and may be removed entirely later.
	//	"O[79],Turbo,Off,Full;",
	//	"O[80],SDRAM Page-Mode,Off,On;",
	//	"O[81],ROM Prefetch,Off,On;",
	//	"O[82],Fast BIOS,Off,On;",
	//	"O[83],Fast Math,Off,On;",
	//	"O[84],CPU Late-Read Skip,Off,On;",
	//	"O[85],Data Cache,Off,On;",
	"R0,Reset;",
	"J1,Button1,Button2,Button3,Button4,Button5,Button6,Start,Coin,Pause;",
	"jn,A,B,X,Y,L,R,Start,Select,L3;",
	"V,v",`BUILD_DATE
};

reg dbg_enabled = 0;
wire  [1:0] buttons;
wire [127:0] status;
wire [15:0] status_menumask = {14'd0, ~status[96], 1'b0};  // H1 = hide CRT amounts until CRT Adjust On
wire        forced_scandoubler;
reg  [31:0] sd_lba0 = 0;
reg  [31:0] sd_lba1;
reg  [ 6:0] sd_lba2;
reg  [ 6:0] sd_lba3;
reg   [3:0] sd_rd;
reg   [3:0] sd_wr;
wire  [3:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din2;
wire [15:0] sd_buff_din3;
wire        sd_buff_wr;
wire  [3:0] img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        ioctl_download;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_wr;
wire  [7:0] ioctl_index;
reg         ioctl_wait_sdram = 0;                 // SDRAM download back-pressure
reg         ioctl_wait_dsp   = 0;                 // Capcom QSound DSP-ROM 2-byte expansion stall
reg         ioctl_wait_zoom  = 0;                 // Taito Zoom DDR download beat-cross stall
wire        ioctl_wait = ioctl_wait_sdram | ioctl_wait_dsp | ioctl_wait_zoom;

wire [19:0] joy;
// [MiSTer-DB9 BEGIN] - USB joysticks from hps_io are OR-merged with the DB9/DB15
// joydb pads (joy_unmod / joy2 are assigned after the joydb wrapper instance).
wire [19:0] joy_0_USB;
wire [19:0] joy_1_USB;
wire [19:0] joy_unmod;
wire [19:0] joy2;
// [MiSTer-DB9 END]
wire [19:0] joy3;
wire [19:0] joy4;

wire [10:0] ps2_key;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

wire [15:0] joystick_analog_l0;
wire [15:0] joystick_analog_r0;
wire [15:0] joystick_analog_l1;
wire [15:0] joystick_analog_r1;
wire [15:0] joystick_analog_l2;
wire [15:0] joystick_analog_r2;
wire [15:0] joystick_analog_l3;
wire [15:0] joystick_analog_r3;

wire [7:0] paddle_0;

wire [24:0] mouse;

wire [15:0] joystick1_rumble;
wire [15:0] joystick2_rumble;
wire [15:0] joystick3_rumble;
wire [15:0] joystick4_rumble;
wire [32:0] RTC_time;

wire filter_on = (status[82:81] == 2'b00) ? 1'b0 : 1'b1;

assign HDMI_BLACKOUT = ~status[61];

wire [127:0] status_in = {status[127:39],ss_slot,status[36:19], 2'b00, status[16:0]};

wire bk_pending = 1'b0;
wire saving_memcard = 1'b0;
wire DIRECT_VIDEO;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .VDNUM(4), .BLKSZ(3)) hps_io
(
	.clk_sys(clk_1x),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(EXT_BUS),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy_0_USB),
	.joystick_1(joy_1_USB),
	.joystick_2(joy3),
	.joystick_3(joy4),
	.ps2_key(ps2_key),

	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb payload + Saturn key gate + remap matrix
	.joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
	.saturn_unlocked(saturn_unlocked),
	.db9_remap_cmd(db9_remap_cmd),
	.db9_remap_byte_cnt(db9_remap_byte_cnt),
	.db9_remap_din(db9_remap_din),
	// [MiSTer-DB9 END]

	.status(status),
	.status_in(status_in),
	.status_set(statusUpdate),
	.status_menumask(status_menumask),
	.info_req(psx_info_req),
	.info(psx_info),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	// NVRAM (AT28C16) save-back: the HPS pulls the live EEPROM out over ioctl_din
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_upload_index(8'd9),
	.ioctl_din(ioctl_din),

	.sd_lba('{sd_lba0, sd_lba1, sd_lba2, sd_lba3}),
	.sd_blk_cnt('{0,0, 0, 0}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{0, 0, sd_buff_din2, sd_buff_din3}),
	.sd_buff_wr(sd_buff_wr),

	.TIMESTAMP(RTC_time),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.sdram_sz(sdram_sz),
	.gamma_bus(gamma_bus),

   .joystick_l_analog_0(joystick_analog_l0),
   .joystick_r_analog_0(joystick_analog_r0),
   .joystick_l_analog_1(joystick_analog_l1),
   .joystick_r_analog_1(joystick_analog_r1),
   .joystick_l_analog_2(joystick_analog_l2),
   .joystick_r_analog_2(joystick_analog_r2),
   .joystick_l_analog_3(joystick_analog_l3),
   .joystick_r_analog_3(joystick_analog_r3),
   .ps2_mouse(mouse),
   .joystick_0_rumble(paused ? 16'h0000 : joystick1_rumble),
   .joystick_1_rumble(paused ? 16'h0000 : joystick2_rumble),

   .paddle_0(paddle_0),

   .direct_video(DIRECT_VIDEO)
);

assign joy = joy_unmod[16] ? 20'b0 : joy_unmod;

assign sd_rd[0] = 0;
assign sd_wr[0] = 0;

assign sd_wr[1] = 0;

wire [35:0] EXT_BUS;
wire        heartbeat;

hps_ext hps_ext
(
	.clk_sys(clk_1x),
	.EXT_BUS(EXT_BUS),
	.heartbeat(heartbeat)
);


//////////////////////////  ROM DETECT  /////////////////////////////////

// SDRAM layout (25-bit byte address, flat):
//   0x0000000-0x03FFFFF: Main RAM   (4MB)
//   0x0400000-0x047FFFF: BIOS       (512KB) — ioctl_index 0, CPU 0x1FC00000
//   0x0480000-0x06FFFFF: Fixed ROM  (2.5MB) — ioctl_index 2, CPU 0x1F000000
//                        (Capcom "0101" reuses this region for the 512KB country/program
//                         ROM read/executed at CPU 0x1FB80000 instead.)
//   0x0800000-0x3FFFFFF: Banked ROM (up to 56MB, 7 banks×8MB) — ioctl_index 3, CPU 0x1F000000
//                        (Capcom "0101": 4MB fixed @0x1F000000 + 4MB banks @0x1F400000.)
localparam BIOS_START      = 27'h0400000;
localparam FIXEDROM_START  = 27'h0480000;
localparam BANKEDROM_START = 27'h0800000;
// FX-1A YM2610B ADPCM-A ROM (up to 4MB). Placed on the 2nd SDRAM chip (bit26=1) at
// 0x4000000 so it never overlaps the banked-ROM reserved region (0x0800000-0x3FFFFFF).
// Requires the 128MB SDRAM module (2x64MB). Only written/read for FX-1A titles.
localparam ADPCM_START     = 27'h4000000;
// FX-1A Z80 program ROM (128KB). Placed just above the 4MB ADPCM window (0x4000000-
// 0x43FFFFF) at 0x4400000 so the two never overlap. Read-only via SDRAM ch5.
localparam Z80ROM_START    = 27'h4400000;

reg bios_download, fixedrom_download, bankedrom_download, code_download;
reg eeprom_download;
reg zoomprog_download, zoomsmpl_download; // Taito FX-1B Zoom ROMs (index 6 = program, 7 = samples)
reg audiocpu_download, adpcm_download;   // Taito FX-1A / Capcom sound ROMs (index 6 = Z80, 7 = samples)
reg dsprom_download;                     // Capcom QSound DL-1425 DSP program ROM (index 8)
always @(posedge clk_1x) begin
	bios_download       <= ioctl_download & (ioctl_index[5:0] == 0);
	fixedrom_download   <= ioctl_download & (ioctl_index == 2);
	bankedrom_download  <= ioctl_download & (ioctl_index == 3);
	eeprom_download     <= ioctl_download & (ioctl_index == 9);   // AT28C16 EEPROM preload -> zn1_io
	audiocpu_download   <= ioctl_download & (ioctl_index == 6) & ~is_fx1b_zoom;   // Z80 program -> SDRAM (FX-1A 128KB / Capcom 256KB)
	adpcm_download      <= ioctl_download & (ioctl_index == 7) & ~is_fx1b_zoom;   // sample ROM  -> SDRAM (FX-1A ADPCM-A / Capcom QSound 4MB)
	dsprom_download     <= ioctl_download & (ioctl_index == 8);   // Capcom QSound DL-1425 microcode -> DSP prog ROM
	code_download       <= ioctl_download & (ioctl_index == 255);
	zoomprog_download   <= ioctl_download & (ioctl_index == 6) & is_fx1b_zoom;   // Taito Zoom MN10200 program -> DDR3
	zoomsmpl_download   <= ioctl_download & (ioctl_index == 7) & is_fx1b_zoom;   // Taito Zoom ZSG-2 samples  -> DDR3
end

// The zoom subsystem is only enabled for a Taito FX MRA that actually carries the
// sound ROMs; without index 6 the mailbox keeps the old "reads 0" stub behaviour
// that the sound-less command dispatcher in gdarius/ftimpact depends on.
reg zoom_rom_loaded = 0;
always @(posedge clk_1x) begin
	if (ioctl_download & ioctl_wr) begin
		if (ioctl_index[5:0] == 0) zoom_rom_loaded <= 0;   // BIOS = first part of a new MRA
		if (ioctl_index      == 6) zoom_rom_loaded <= 1;
	end
end

////////////////////////  AT28C16 NVRAM PERSISTENCE  ////////////////////////
// The ZN motherboard's AT28C16 holds operator settings and high scores. On a real cabinet
// the operator runs FACTORY SETTING once and the EEPROM keeps it; here the BRAM is volatile,
// so those settings die with the core. This streams the live EEPROM back to the HPS, which
// writes it to the MRA's .nvm file (declared with <nvram index="9" size="2048"/>), and the
// existing index-9 download path reloads it on the next launch.
//
// Upload protocol (sys/hps_io.sv FIO_FILE_TX_DAT): the HPS latches ioctl_din for the CURRENT
// ioctl_addr and then post-increments, so ioctl_din must be combinationally valid for
// ioctl_addr. The HPS bus is far slower than clk_1x, so the 1-cycle BRAM read has long
// settled by the time each word is taken.
wire        ioctl_upload;
wire [15:0] ioctl_din;
reg         ioctl_upload_req = 0;
wire [31:0] zn_ee_ul_q;
wire        zn_ee_game_wr;

// Word address into the 512x32 EEPROM; ioctl_addr[1] picks which 16-bit half goes out.
wire [8:0]  zn_ee_ul_addr = ioctl_addr[10:2];
assign      ioctl_din     = ioctl_addr[1] ? zn_ee_ul_q[31:16] : zn_ee_ul_q[15:0];

// Request a save once the game has stopped writing the EEPROM for ~1s (games write NVRAM in
// bursts; this coalesces a burst into a single .nvm write). Never fires during a download.
localparam [25:0] EE_SAVE_DELAY = 26'd33_868_800;   // 1s @ 33.8688 MHz
reg  [25:0] ee_dirty_cnt = 0;
reg         ee_dirty     = 0;
always @(posedge clk_1x) begin
	ioctl_upload_req <= 0;
	if (ioctl_download) begin
		ee_dirty     <= 0;
		ee_dirty_cnt <= 0;
	end else if (zn_ee_game_wr) begin
		ee_dirty     <= 1;
		ee_dirty_cnt <= 0;                       // restart the settle timer on every write
	end else if (ee_dirty && !ioctl_upload) begin
		if (ee_dirty_cnt >= EE_SAVE_DELAY) begin
			ee_dirty         <= 0;
			ee_dirty_cnt     <= 0;
			ioctl_upload_req <= 1;                // one-shot; hps_io edge-detects this
		end else begin
			ee_dirty_cnt <= ee_dirty_cnt + 1'd1;
		end
	end
end

// MB3773 watchdog timer (see the declarations near reset_or for the full rationale).
always @(posedge clk_1x) begin
	if (ioctl_download) begin                      // new game loading: disarm and clear
		wd_armed   <= 0;
		wd_cnt     <= 0;
		wd_rst_cnt <= 0;
	end else begin
		if (wd_rst_cnt != 0) wd_rst_cnt <= wd_rst_cnt - 1'd1;

		if (zn_wd_kick) begin
			wd_armed <= 1;
			wd_cnt   <= 0;
		end else if (wd_armed && !paused) begin
			// Freeze the timer while the core is paused (OSD open or Pause button):
			// pause halts the maincpu (psx_top.pause), so it stops strobing bit5 of
			// 0x1FB40000. Without this gate wd_cnt reaches WD_TIMEOUT after ~5s of OSD
			// and soft-resets the board — exactly the "OSD open -> reset" symptom.
			if (wd_cnt >= WD_TIMEOUT) begin
				wd_cnt     <= 0;
				wd_armed   <= 0;               // re-arms on the next kick after the reset
				wd_rst_cnt <= 16'hFFFF;
			end else begin
				wd_cnt <= wd_cnt + 1'd1;
			end
		end
	end
end

// FX-1A sound present: set once when either sound ROM begins downloading. Combined with
// the Taito platform id (0x2) it forms zn_syt_fx1a, which gates the TC0140SYT decode in
// memorymux (so FX-1B / non-Taito are provably unaffected) and enables the sound block.
// The same sticky flag also enables the mutually-exclusive Capcom QSound block: the two
// platforms never coexist, so index 6/7 are shared and the platform id disambiguates.
reg sound_rom_present = 0;
always @(posedge clk_1x) begin
	if (audiocpu_download | adpcm_download | dsprom_download) sound_rom_present <= 1;
end
// FX-1A (YM2610B) and FX-1B (Taito Zoom) are BOTH Taito platform "0010" (=2). They are told
// apart by MRA platform-byte bit4: 0x12 = FX-1A (YM2610B), 0x02 = FX-1B (Zoom). This mirrors the
// Capcom coh1002c 2MB bit4. Exactly one of fx1a_active / zoom_enable can be high at a time.
wire is_fx1a_ym   = (zn_platform_r[3:0] == 4'd2) &  zn_platform_r[4];
wire is_fx1b_zoom = (zn_platform_r[3:0] == 4'd2) & ~zn_platform_r[4];
`ifdef ZN1_HAS_YM2610B
wire fx1a_active   = is_fx1a_ym & sound_rom_present;
`else
wire fx1a_active   = 1'b0;   // FX-1A YM2610B compiled out for this variant -> TC0140SYT decode prunes
`endif
// Capcom QSound active: Capcom platform ("0101"=5) with QSound sound ROMs loaded. glpracr
// (Capcom, empty QSound sockets, no index-6/7/8 parts) keeps this low -> Z80 held in reset,
// silent, and non-Capcom titles are wholly unaffected.
wire capcom_active = (zn_platform_r[3:0] == 4'd5) & sound_rom_present;

// EEPROM preload writer (MRA index 9). 16-bit ioctl_dout carries 2 bytes (little-endian:
// ioctl_dout[7:0]=even byte, [15:8]=odd byte). Pack into the correct 16-bit lane of the
// 32-bit EEPROM word (word addr = ioctl_addr[10:2], 2KB=512 words) with a matching byte
// enable, and pulse ee_dl_wr. Games with no index-9 part never assert this, keeping the
// eeprom_ff.mif (0xFF) default. Used to preload the Taito FX-1A "TAITO_TG..." NVRAM signature.
reg        zn_ee_dl_wr = 0;
reg [8:0]  zn_ee_dl_addr;
reg [31:0] zn_ee_dl_data;
reg [3:0]  zn_ee_dl_be;
always @(posedge clk_1x) begin
	zn_ee_dl_wr <= 0;
	if (eeprom_download & ioctl_wr) begin
		zn_ee_dl_addr <= ioctl_addr[10:2];
		if (ioctl_addr[1] == 1'b0) begin
			zn_ee_dl_data <= {16'h0000, ioctl_dout};
			zn_ee_dl_be   <= 4'b0011;
		end else begin
			zn_ee_dl_data <= {ioctl_dout, 16'h0000};
			zn_ee_dl_be   <= 4'b1100;
		end
		zn_ee_dl_wr <= 1;
	end
end


// Dynamic platform config and CAT702 key loading (from MRA rom index 1/4/5)
reg [7:0]  zn_platform_r  = 8'h00;              // ioctl_index 1: platform id (0=Visco, 1=Raizing, 2=Taito, 3=Atlus, 4=Tecmo, 5=Capcom ZN-1)
// Default: COH-1002M mg01 key (80 F2 30 38 F9 FD 1C E0, byte[0] at [7:0]).
// Overwritten by MRA index 4 download when game ROM is loaded.
reg [63:0] zn_cat702_key_a  = 64'hE01CFDF93830F280;
// Default: DoA++ mg05 key (80 C2 38 F9 FD 0C 10 E0, byte[0] at [7:0]).
// Overwritten by MRA index 5 download when game ROM is loaded.
reg [63:0] zn_cat702_key_b_r = 64'hE0100CFDF938C280;

always @(posedge clk_1x) begin
	if (ioctl_wr) begin
		if (ioctl_index[5:0] == 1) begin
			zn_platform_r <= ioctl_dout[7:0];
		end else if (ioctl_index[5:0] == 4) begin
			case (ioctl_addr[2:1])
				2'd0: zn_cat702_key_a[15:0]  <= ioctl_dout;
				2'd1: zn_cat702_key_a[31:16] <= ioctl_dout;
				2'd2: zn_cat702_key_a[47:32] <= ioctl_dout;
				2'd3: zn_cat702_key_a[63:48] <= ioctl_dout;
			endcase
		end else if (ioctl_index[5:0] == 5) begin
			case (ioctl_addr[2:1])
				2'd0: zn_cat702_key_b_r[15:0]  <= ioctl_dout;
				2'd1: zn_cat702_key_b_r[31:16] <= ioctl_dout;
				2'd2: zn_cat702_key_b_r[47:32] <= ioctl_dout;
				2'd3: zn_cat702_key_b_r[63:48] <= ioctl_dout;
			endcase
		end
	end
end

// Taito FX platform code is "0010"; zoom_rom_loaded is set by the index-6 download above.
`ifdef ZN1_HAS_ZOOM
wire zoom_enable = zoom_rom_loaded & is_fx1b_zoom;   // FX-1B (Zoom) only, never FX-1A
`else
wire zoom_enable = 1'b0;   // Taito Zoom compiled out for this variant -> Zoom reg/mailbox decode prunes
`endif

// exe_download stub (unused in ZN, retained for save-state UI compatibility)
wire exe_download = 1'b0;

reg cart_loaded = 0;
always @(posedge clk_1x) begin
	if (fixedrom_download || bankedrom_download) cart_loaded <= 1;
end

reg [26:0] ramdownload_wraddr;
reg [31:0] ramdownload_wrdata;
reg        ramdownload_wr;

// Taito Zoom ROM download -> DDR3 (one 64-bit beat per 4 ioctl words)
reg        zoomdl_req = 0;
reg [28:0] zoomdl_addr;
reg [63:0] zoomdl_data;
wire       zoomdl_ack;

// ZN uses no CD
wire hasCD = 1'b0;

// loadExe and EXE header fields unused in ZN (no .EXE loading)
wire loadExe = 1'b0;
wire [31:0] exe_initial_pc    = 32'h0;
wire [31:0] exe_initial_gp    = 32'h0;
wire [31:0] exe_load_address  = 32'h0;
wire [31:0] exe_file_size     = 32'h0;
wire [31:0] exe_stackpointer  = 32'h0;

reg  [1:0] biosregion;
wire [1:0] region_out;
reg        isPal;

// ZN-1 Visco: NTSC-J (region JP)
always @(posedge clk_1x) begin
   isPal     <= 1'b0;
   biosregion <= 2'b01;  // JP BIOS
end
// (B157 banked-ROM download shadow-sum probe removed 2026-07-27: that saga closed when
//  the build-#55 sentinel was found and deleted. See zn1-release-20260727.)

// dl_to_sdram: any download routed through SDRAM ch3 (BIOS/fixed/banked/ADPCM-A/Z80 ROM).
// Zoom ROMs (index 6/7 on FX-1B) take the separate DDR path below; the QSound DSP ROM
// (index 8) takes its own de-raced loader FSM (ioctl_wait_dsp), not this block.
wire dl_to_sdram = bios_download | fixedrom_download | bankedrom_download | adpcm_download | audiocpu_download;
always @(posedge clk_1x) begin
   ramdownload_wr <= 0;
   // unconditional: a pending request must not survive the end of the download window
   if (zoomdl_ack) zoomdl_req <= 0;
   if (dl_to_sdram) begin
      if (ioctl_wr) begin
         if (~ioctl_addr[1]) begin
            ramdownload_wrdata[15:0] <= ioctl_dout;
            if (bios_download)
               // BIOS: SDRAM 0x400000 base (bit22 set, no region overlap)
               ramdownload_wraddr <= BIOS_START[26:0] | {8'b0, ioctl_addr[18:0]};
            else if (fixedrom_download)
               // Fixed ROM: SDRAM 0x480000 base (addition to handle overlapping bits)
               ramdownload_wraddr <= FIXEDROM_START[26:0] + {4'b0000, ioctl_addr[22:0]};
            else if (adpcm_download)
               // FX-1A ADPCM-A: SDRAM 0x4000000 base (2nd chip)
               ramdownload_wraddr <= ADPCM_START[26:0] + {4'b0000, ioctl_addr[22:0]};
            else if (audiocpu_download)
               // Z80 program: SDRAM 0x4400000 base (2nd chip). 18-bit slice covers both
               // FX-1A (128KB, addr[17]=0) and Capcom QSound audiocpu (256KB).
               ramdownload_wraddr <= Z80ROM_START[26:0] + {9'b0, ioctl_addr[17:0]};
            else
               // Banked ROM: SDRAM 0x800000 base, 24 banks × 1MB = 24MB
               ramdownload_wraddr <= BANKEDROM_START[26:0] + ioctl_addr[26:0];
         end else begin
            ramdownload_wrdata[31:16] <= ioctl_dout;
            ramdownload_wr            <= 1;
            ioctl_wait_sdram          <= 1;
         end
      end
      if (sdramCh3_done) ioctl_wait_sdram <= 0;
   end else if (zoomprog_download | zoomsmpl_download) begin
      // Taito Zoom ROMs go to DDR3 through the sound wrapper's arbiter port.
      // Pack four 16-bit ioctl words into one 64-bit DDR beat and only stall the
      // HPS on the beat that actually has to cross to the DDR clock domain.
      if (ioctl_wr) begin
         case (ioctl_addr[2:1])
            2'd0: zoomdl_data[15:0]  <= ioctl_dout;
            2'd1: zoomdl_data[31:16] <= ioctl_dout;
            2'd2: zoomdl_data[47:32] <= ioctl_dout;
            2'd3: begin
                     zoomdl_data[63:48] <= ioctl_dout;
                     zoomdl_addr        <= (zoomsmpl_download ? ZOOM_SMPL_BASE : ZOOM_PROG_BASE)
                                           + {9'd0, ioctl_addr[22:3]};
                     zoomdl_req         <= 1;
                     ioctl_wait_zoom    <= 1;
                  end
         endcase
      end
      if (zoomdl_ack) begin
         zoomdl_req <= 0;
         ioctl_wait_zoom <= 0;
      end
   end else begin
      ioctl_wait_sdram <= 0;
      ioctl_wait_zoom  <= 0;
   end
end

// -----------------------------------------------------------------------------
// Capcom QSound DL-1425 DSP program-ROM loader (MRA index 8 = dl-1425.bin).
// The DSP internal ROM is 4K words (8KB); only the first 0x2000 file bytes are
// used (MAME loads dsp region 0x2000; jtdsp16 prog_addr is [12:0]). Each ioctl
// halfword carries two bytes (even=[7:0], odd=[15:8]); jtdsp16 takes one byte per
// prog_we with prog_addr[0] selecting the lsb/msb lane. We therefore expand each
// halfword into two consecutive prog writes, stalling ioctl (ioctl_wait_dsp)
// across the 2-cycle expansion so no source word is dropped. Writes land in the
// DSP's clk_dsp-clocked ROM BRAM while the DSP is held in reset (reset_or high
// during any download) — required by jtdsp16_rom for safe programming.
`ifdef ZN1_HAS_QSOUND
reg  [12:0] dsp_prog_addr = 0;   // clk_dsp: byte address {word_index, lane} into DSP prog ROM
reg   [7:0] dsp_prog_data = 0;   // clk_dsp: byte payload for this lane
reg         dsp_prog_we   = 0;   // clk_dsp: single-cycle write strobe per byte
// ---------------------------------------------------------------------------------------------
// CLOCK-DOMAIN-CROSSING FIX (real HW bug: QSound silent on silicon, yet sim-clean):
// jtdsp16_rom (the DSP program ROM) is clocked SOLELY by clk_dsp (== clk_2x). The previous
// loader generated prog_addr/prog_data/prog_we on clk_1x, so EVERY microcode byte-write crossed
// clk_1x -> clk_dsp asynchronously. On silicon (near-full fit, tight timing) the clk_dsp write
// port could latch a mid-transition address/data and corrupt the DL-1425 microcode -> the DSP
// then never issues its external fetch (ZNQS probe on RBF c71b2444: cen_dsp=1, ext_rq=0) -> no
// music. The $readmemh baked-firmware build had perfect music, proving the whole chain is correct
// GIVEN correct microcode; only the runtime LOAD (this CDC) was the fault. Verilator cannot model
// the metastable latch, so the design was sim-clean yet silent on HW.
//
// FIX: prog_addr/prog_data/prog_we are now generated ENTIRELY in the clk_dsp domain — there is NO
// clk_1x -> clk_dsp crossing on the ROM write bus. Each ioctl word crosses via a data-stable-
// around-a-synced-toggle handshake (the same MCB discipline as the exonerated ch4 command CDC),
// with ioctl_wait backpressure so the HPS download stalls until each word's two byte-writes land:
//   clk_1x : capture {word address, 16-bit word}; flip req_tog; hold ioctl_wait until acked.
//   clk_dsp: 2-FF sync req_tog -> new_word pulse; latched {idx,data} are stable around it; drive
//            the two byte-writes (lsb @ {idx,0}, msb @ {idx,1}) on clk_dsp; flip ack_tog.
//   clk_1x : 2-FF sync ack_tog -> release ioctl_wait so the next index-8 word may arrive.
// Word 0 is NOT skipped: capture is gated on the COMBINATIONAL dsprom_dl_now (ioctl_download &
// index==8), which is already high when word 0's first ioctl_wr fires (the registered
// dsprom_download arms one clk_1x late and would drop word 0 = the DSP reset-vector instruction).
// jtdsp16_rom is intentionally left single-clock (clk_dsp); the fix is that we now WRITE it from
// clk_dsp. Writes still land while the DSP is held in reset (reset_or high during any download).
// clk_dsp is 2x clk_1x, so the 2 byte-writes always finish well within one ioctl word period; the
// handshake makes correctness independent of that ratio.
// ---------------------------------------------------------------------------------------------
wire dsprom_dl_now = ioctl_download & (ioctl_index == 8);

// handshake / CDC registers (declared together so neither always block forward-references a reg)
reg  [11:0] dsp_word_idx = 0;    // ROM WORD address (byte-addr[12:1] of the index-8 stream)
reg  [15:0] dsp_word_dat = 0;    // captured 16-bit MRA index-8 word (lsb=[7:0], msb=[15:8])
reg         dsp_req_tog  = 0;    // clk_1x -> clk_dsp: toggles once per captured word
reg         dsp_ack_tog  = 0;    // clk_dsp -> clk_1x: toggles when the word's 2 writes complete
reg         dsp_busy      = 0;   // clk_1x: high from capture until clk_dsp acks -> ioctl_wait_dsp
reg   [2:0] dsp_ack_s1x  = 0;    // clk_1x: 2-FF (+delayed) sync of dsp_ack_tog
reg   [2:0] dsp_req_s2x  = 0;    // clk_dsp: 2-FF (+delayed) sync of dsp_req_tog
reg   [2:0] dsp_ld_st    = 0;    // clk_dsp: byte-write FSM state
wire        dsp_ack_edge = dsp_ack_s1x[2] ^ dsp_ack_s1x[1];   // 1-clk_1x  ack pulse
wire        dsp_new_word = dsp_req_s2x[2] ^ dsp_req_s2x[1];   // 1-clk_dsp new-word pulse

// ---- clk_1x capture + backpressure side --------------------------------------------------
// NOTE: intentionally NOT gated on reset_or. reset_or is HIGH for the whole download window
// (it includes ioctl_download), so resetting these here would freeze the loader mid-stream.
always @(posedge clk_1x) begin
	dsp_ack_s1x <= {dsp_ack_s1x[1:0], dsp_ack_tog};
	if (dsprom_dl_now) begin
		if (~dsp_busy) begin
			if (ioctl_wr & (ioctl_addr[26:13] == 14'd0)) begin   // FULL byte addr < 0x2000 (first 4096 words only).
				dsp_word_dat   <= ioctl_dout[15:0];
				dsp_word_idx   <= ioctl_addr[12:1];  // byte addr / 2 = ROM word address
				dsp_req_tog    <= ~dsp_req_tog;      // hand word to clk_dsp (data stable at sync)
				dsp_busy       <= 1'b1;
				ioctl_wait_dsp <= 1'b1;              // stall HPS until the 2 byte-writes finish
			end
		end else if (dsp_ack_edge) begin
			dsp_busy       <= 1'b0;
			ioctl_wait_dsp <= 1'b0;                  // release backpressure -> next word may arrive
		end
	end else begin
		dsp_busy       <= 1'b0;
		ioctl_wait_dsp <= 1'b0;
	end
end

// ---- clk_dsp (clk_2x) write side: the ONLY driver of prog_addr/prog_data/prog_we ---------
// prog_we is held high on exactly the cycle after addr/data settle, so within this single clock
// domain a synchronous BRAM write never samples a mid-transition address or datum.
always @(posedge clk_2x) begin
	dsp_req_s2x <= {dsp_req_s2x[1:0], dsp_req_tog};
	dsp_prog_we <= 1'b0;                              // default: strobe low
	case (dsp_ld_st)
		3'd0: if (dsp_new_word) begin                // {idx,data} guaranteed stable by now
			dsp_prog_addr <= {dsp_word_idx, 1'b0};   // LSB (even) lane; settle 1 cycle before we
			dsp_prog_data <= dsp_word_dat[7:0];
			dsp_ld_st     <= 3'd1;
		end
		3'd1: begin dsp_prog_we <= 1'b1; dsp_ld_st <= 3'd2; end   // write LSB (addr/data stable)
		3'd2: begin                                              // we low; switch to MSB lane
			dsp_prog_addr <= {dsp_word_idx, 1'b1};
			dsp_prog_data <= dsp_word_dat[15:8];
			dsp_ld_st     <= 3'd3;
		end
		3'd3: begin dsp_prog_we <= 1'b1; dsp_ld_st <= 3'd4; end   // write MSB (addr/data stable)
		3'd4: begin dsp_ack_tog <= ~dsp_ack_tog; dsp_ld_st <= 3'd0; end // we low; ack back to clk_1x
	endcase
end
`endif // ZN1_HAS_QSOUND


///////////////////////////  SAVESTATE  /////////////////////////////////
// savestates removed 2026-07-29 per project owner decision (ALM budget for Taito Zoom sound)
// savestate_ui is not instantiated: it was the only thing that could assert
// ss_save/ss_load (Alt+F1..F4 / F1..F4 from an attached keyboard, plus the
// joySS combo).  Tying its outputs off here lets synthesis constant-propagate
// through psx_mister -> psx_top -> statemanager -> savestates and sweep the
// whole subsystem.  No OSD entry ever existed for savestates in CONF_STR, so
// nothing user-visible is lost.
wire [1:0] ss_slot     = 2'b00;
wire [7:0] ss_info     = 8'h00;
wire       ss_save     = 1'b0;
wire       ss_load     = 1'b0;
wire       ss_info_req = 1'b0;
wire       statusUpdate = 1'b0;
wire [3:0] validSStates;          // psx_mister output, now unused

////////////////////////////  PAD  ///////////////////////////////////

// 0000 -> DualShock
// 0001 -> off
// 0010 -> digital
// 0011 -> analog
// 0100 -> Namco GunCon lightgun
// 0101 -> Namco NeGcon
// 0110 -> Wheel Negcon
// 0111 -> Wheel Analog
// 1000 -> mouse
// 1001 -> Konami Justifier lightgun
// 1010 -> SNAC
// 1011 -> Analog Joystick
// 1100..1111 -> reserved

wire PadPortDS1      = (status[48:45] == 4'b0000);
wire PadPortEnable1  = (status[48:45] != 4'b0001);
wire PadPortDigital1 = (status[48:45] == 4'b0010) || (status[52:49] == 4'b1100);
wire PadPortAnalog1  = (status[48:45] == 4'b0011) || (status[48:45] == 4'b0111);
wire PadPortGunCon1  = (status[48:45] == 4'b0100);
wire PadPortNeGcon1  = (status[48:45] == 4'b0101) || (status[48:45] == 4'b0110);
wire PadPortWheel1   = (status[48:45] == 4'b0110) || (status[48:45] == 4'b0111);
wire PadPortMouse1   = (status[48:45] == 4'b1000);
wire PadPortJustif1  = (status[48:45] == 4'b1001);
wire snacPort1       = (status[48:45] == 4'b1010) && ~multitap;
wire PadPortStick1   = (status[48:45] == 4'b1011);
wire PadPortPopn1    = (status[48:45] == 4'b1100);

wire PadPortDS2      = (status[52:49] == 4'b0000);
wire PadPortEnable2  = (status[52:49] != 4'b0001) && ~multitap;
wire PadPortDigital2 = (status[52:49] == 4'b0010) || (status[52:49] == 4'b1100);
wire PadPortAnalog2  = (status[52:49] == 4'b0011) || (status[52:49] == 4'b0111);
wire PadPortGunCon2  = (status[52:49] == 4'b0100);
wire PadPortNeGcon2  = (status[52:49] == 4'b0101) || (status[52:49] == 4'b0110);
wire PadPortWheel2   = (status[52:49] == 4'b0110) || (status[52:49] == 4'b0111);
wire PadPortMouse2   = (status[52:49] == 4'b1000);
wire PadPortJustif2  = (status[52:49] == 4'b1001);
wire snacPort2       = (status[52:49] == 4'b1010) && ~multitap;
wire PadPortStick2   = (status[52:49] == 4'b1011);
wire PadPortPopn2    = (status[52:49] == 4'b1100);

reg paddleMode = 0;
reg paddleMin = 0;
reg paddleMax = 0;
wire [7:0] joy0_xmuxed = (paddleMode) ? (paddle_0 - 8'd128) : joystick_analog_l0[7:0];

// to activate paddleMode negcon mode must be active and paddle must best moved
always @(posedge clk_1x) begin
   if (PadPortNeGcon1) begin
      if (paddle_0 < 112) paddleMin <= 1'b1;
      if (paddle_0 > 144) paddleMax <= 1'b1;
      if (paddleMin && paddleMax) paddleMode <= 1'b1;
   end else begin
      paddleMode <= 0;
      paddleMin <= 0;
      paddleMax <= 0;
   end
end

// 00 -> multitap off
// 01 -> port1, 4 x digital
// 10 -> port1, 4 x analog
wire multitap        = (status[57:56] != 2'b00);
wire multitapDigital = (status[57:56] == 2'b01);
wire multitapAnalog  = (status[57:56] == 2'b10);

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
// This core drives the USER_IO pins for PSX SNAC controllers; when a SNAC port is
// selected it preempts the joydb wrapper so the two never contend for USER_OUT.
wire         snac_active     = snacPort1 | snacPort2;
wire         mt32_primary_active = 1'b0;
wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
wire   [2:0] JOY_FLAG        = {joy_db9md_en, joy_db15_en, joy_2p};
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire  [15:0] joy_raw_payload;
wire  [15:0] joydb_1_mapped, joydb_2_mapped;
wire         db9_remap_cmd;
wire   [5:0] db9_remap_byte_cnt;
wire  [15:0] db9_remap_din;

joydb joydb (
  .clk             ( CLK_JOY         ),
  .clk_sys         ( clk_1x             ),
  .USER_IN         ( USER_IN         ),
  .OSD_STATUS          ( OSD_STATUS          ),
  .snac_active         ( snac_active         ),
  .mt32_primary_active ( mt32_primary_active ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .remap_cmd       ( db9_remap_cmd      ),
  .remap_byte_cnt  ( db9_remap_byte_cnt ),
  .remap_din       ( db9_remap_din      ),
  .joydb_1_mapped  ( joydb_1_mapped     ),
  .joydb_2_mapped  ( joydb_2_mapped     ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_PP = USER_PP_DRIVE;
// USER_OUT is driven by the SNAC relay always-block (SerJoystick pattern): its
// non-SNAC branch falls through to USER_OUT_DRIVE, so no `assign USER_OUT` here.

// Merge DB9/DB15 pads into the joysticks the core consumes (muted while OSD open).
assign joy_unmod = joy_0_USB | (joydb_1ena ? (OSD_STATUS ? 20'b0 : {4'b0, joydb_1}) : 20'b0);
assign joy2      = joy_1_USB | (joydb_2ena ? (OSD_STATUS ? 20'b0 : {4'b0, joydb_2}) : 20'b0);
// [MiSTer-DB9 END]

wire [1:0] padMode;
reg  [1:0] padMode_1;

reg [7:0] psx_info;
reg psx_info_req;

wire resetFromCD = 1'b0;

reg [3:0] ToggleDS = 0;
reg [3:0] joy19_1 = 0;

always @(posedge clk_1x) begin

   psx_info_req <= 0;
   padMode_1    <= padMode;

   if (ss_info_req) begin
      psx_info_req <= 1;
      psx_info     <= ss_info;
   end

   if (joy[14] && joy[15] && joy[8]) dbg_enabled <= 1;  // L3+R3+Select

   // DS toggle (unused in arcade but kept for joypad struct compatibility)
   joy19_1 <= {joy4[19] ,joy3[19] ,joy2[19] ,joy[19] };
   ToggleDS[0] <=  joy[19] & ~joy19_1[0];
   ToggleDS[1] <= joy2[19] & ~joy19_1[1];
   ToggleDS[2] <= joy3[19] & ~joy19_1[2];
   ToggleDS[3] <= joy4[19] & ~joy19_1[3];

end

////////////////////////////  PAUSE and RESET  ///////////////////////////
reg paused = 0;
reg [9:0] unpause = 0;
reg status1_1;
wire isPaused;

reg [20:0] aliveCnt = 0;
reg heartbeat_1 = 0;
reg hps_busy = 0;

reg reset = 0;

reg buttonpause_1 = 0;
reg button_paused = 0;

localparam ZN1_EXPERIMENTAL_TOGGLES = 0;   // see the block below
reg TURBO_MEM;
reg TURBO_COMP;
reg TURBO_CACHE;
reg TURBO_CACHE50;
reg SDRAM_PAGEMODE;
reg ROM_PREFETCH;
reg FAST_BIOS;
reg FAST_MATH;
reg CPU_LATE_READ_SKIP;

always @(posedge clk_1x) begin

   paused <= 0;

   // pause from OSD open
   if (~status[64] & OSD_STATUS & (unpause == 0)) begin
      paused <= 1;
   end

   // pause from button — joy[12] = Pause button (J1 list index 8 = 9th entry)
   // J1 mapping: Button1..6 at joy[4..9], Start at joy[10], Coin at joy[11], Pause at joy[12]
   buttonpause_1 <= joy[12];
   if (joy[12] & ~buttonpause_1) begin
      button_paused <= ~button_paused;
   end
   if (button_paused) begin
      paused <= 1;
   end

   // Advance Pause OSD trigger
   status1_1 <= status[1];
   if (status[1] & ~status1_1) begin
      unpause <= 1023;
   end else if (unpause > 0) begin
      unpause <= unpause - 1'd1;
   end

   // pause from heartbeat -> only used for savestate
   hps_busy    <= 0;
   heartbeat_1 <= heartbeat;
   if (heartbeat == heartbeat_1) begin
      if (aliveCnt[20] == 0) begin
         aliveCnt <= aliveCnt + 1'b1;
      end else begin
         hps_busy <= 1;
      end
   end else begin
      aliveCnt <= 0;
   end

   // reset
   reset <= 0;
   if (reset_or) begin
      reset    <= 1;
      aliveCnt <= 0;
   end

   // 1 => low    -> only MEM
   // 2 => medium -> MEM + 50% cache
   // 3 => high   -> everything
   // Default OFF (status[79]=0). DoA++ crashed with TURBO defaulted on; leave as an opt-in
   // for experimentation per title.
   // ----------------------------------------------------------------------
   // [EXPERIMENTAL TOGGLES 2026-07-30] Every one of the toggles below is a
   // PSX_MiSTer leftover whose CONF_STR entry is commented out (see ZN1.sv
   // ~line 460), so status[79]..[85] can never be set at runtime and all of
   // these features are permanently OFF.  Synthesis cannot prove that -
   // status[] arrives from hps_io - so the full 16KB D-cache, the page-mode
   // SDRAM path, the ROM prefetch line buffer and the rest were all being
   // synthesized and placed.  The D-cache held the worst clk_1x path
   // (cpu|datacache|dpram -> memorymux|waitcnt, slack -0.607).
   //
   // Hardwiring them to their default-OFF values is behaviour-identical and
   // lets synthesis sweep the lot.  Flip ZN1_EXPERIMENTAL_TOGGLES to 1 (and
   // un-comment the CONF_STR lines) to restore OSD control in one step.
   //
   // SDRAM_PAGEMODE also carried a JTAG force term, la_src[10].  Page-mode is
   // known-broken (open-row reads return 0 - electrical, not RTL), so forcing
   // it off is correct as well as safe.  The whole jtag_la probe was removed in
   // Stage B4 (see the AREA DIET note further down), so that term is gone too.
   //
   // NOTE: status[83]/[84] have a SECOND, unrelated use further down
   // (.textureFilter2DOff / .render24 on the GPU) - those are deliberately left
   // alone here; this block only fixes the toggle registers.
   // ----------------------------------------------------------------------
   TURBO_MEM      <= ZN1_EXPERIMENTAL_TOGGLES ? status[79] : 1'b0;
   TURBO_COMP     <= ZN1_EXPERIMENTAL_TOGGLES ? status[79] : 1'b0;
   // status[85] = OSD opt-in for the 16KB data cache in cpu.vhd. Default OFF.
   // Synthesized but unused unless this bit OR the full Turbo bundle is on.
   // Real PSX has a 1KB scratchpad + I-cache; DoA++ math-heavy code thrashes
   // SDRAM data reads constantly without it (60% memoryMuxBusy at boot).
   // Cache is safe since the KSEG1 fix in cpu.vhd (never cache uncached-segment
   // reads); it helps CPU-bound code but not DMA/streaming-bound loads.
   TURBO_CACHE    <= ZN1_EXPERIMENTAL_TOGGLES ? (status[79] | status[85]) : 1'b0;
   TURBO_CACHE50  <= 1'b0;

   // OSD opt-in for the experimental ch1 page-mode SDRAM optimization.
   // Default OFF = baseline FSM proven to work; ON enables HIT/PRECHARGE path.
   // Page-mode follows OSD (default OFF = safe baseline).
   SDRAM_PAGEMODE <= ZN1_EXPERIMENTAL_TOGGLES ? status[80] : 1'b0;

   // OSD opt-in for ROM prefetch line cache in memorymux. Default OFF =
   // single-word uncached ROM reads (baseline); ON enables a 4-word line
   // buffer fed by burst-of-4 serial SDRAM reads with bank invalidation.
   ROM_PREFETCH   <= ZN1_EXPERIMENTAL_TOGGLES ? status[81] : 1'b0;

   // OSD opt-in for zero-wait BIOS reads. The 25-26 cycle waitcnt in
   // memorymux's READBIOS → WAITING path was tuned for original PSX slow
   // ROM-chip pacing; ZN-1 BIOS lives in SDRAM and doesn't need it.
   FAST_BIOS      <= ZN1_EXPERIMENTAL_TOGGLES ? status[82] : 1'b0;

   // B20: bypass MIPS R3000 DIV/MULT cycle pacing (37 cycles for DIV, 7-14
   // for MULT). Real hardware enforces these; MAME's interpreter may not.
   // If this toggle dramatically speeds DoA++ post-coin, math pacing IS
   // the dominant slow-window cost.
   FAST_MATH      <= ZN1_EXPERIMENTAL_TOGGLES ? status[83] : 1'b0;

   // CPU-only TURBO_COMP: skips lateReadStall in cpu.vhd. Subset of the
   // status[79] Turbo toggle that crashed DoA++ (which also skipped
   // memorymux RAM waits + cache 50% slow-mode). This bit only affects
   // the CPU's TURBO input — DMA, memorymux, CD timing untouched.
   CPU_LATE_READ_SKIP <= ZN1_EXPERIMENTAL_TOGGLES ? status[84] : 1'b0;

end

////////////////////////////  SYSTEM  ///////////////////////////////////

// MDEC (task #320): required by Capcom FMV titles (starglad/ts2). Compiled out
// only on the fit-constrained Zoom variant (~99% ALM, no known FMV titles).
`ifdef ZN1_NO_MDEC
localparam bit HAS_MDEC = 1'b0;
`else
localparam bit HAS_MDEC = 1'b1;
`endif

psx_mister
#(
   .has_mdec(HAS_MDEC)
)
psx
(
   .clk1x(clk_1x),
   .clk2x(clk_2x),
   .clk3x(clk_3x),
   .clkvid(clk_vid),
   .reset(reset),
   .isPaused(isPaused),
   // commands
   .pause(paused),
   .hps_busy(hps_busy),
   .loadExe(loadExe),
   .exe_initial_pc(exe_initial_pc),
   .exe_initial_gp(exe_initial_gp),
   .exe_load_address(exe_load_address),
   .exe_file_size(exe_file_size),
   .exe_stackpointer(exe_stackpointer),
   .fastboot(status[16] && hasCD),
   .ram8mb(1'b1),
   .TURBO_MEM(TURBO_MEM),
   .TURBO_COMP(TURBO_COMP),
   .TURBO_CACHE(TURBO_CACHE),
   .TURBO_CACHE50(TURBO_CACHE50),
   .ROM_PREFETCH(ROM_PREFETCH),
   .FAST_BIOS(FAST_BIOS),
   .FAST_MATH(FAST_MATH),
   .CPU_LATE_READ_SKIP(CPU_LATE_READ_SKIP),
   .REPRODUCIBLEGPUTIMING(0),
   .INSTANTSEEK(status[21]),
   .FORCECDSPEED(status[77:75]),
   .LIMITREADSPEED(status[78]),
   .IGNORECDDMATIMING(status[88]),
   .ditherOff(status[22]),
   .interlaced480pHack(status[89]),
   .showGunCrosshairs(status[9]),
   .enableNeGconRumble(status[91]),
   .fpscountOn(1'b0),   // status[28] not in CONF_STR (unreachable debug overlay) - hardwired off, prunes the GPU FPS counter/renderer
   .cdslowOn(status[59]),
   .testSeek(status[70]),
   .pauseOnCDSlow(~status[72]),
   .errorOn(1'b0),      // status[74] not in CONF_STR (unreachable debug overlay) - hardwired off, prunes the GPU error-text renderer
   .LBAOn(status[69]),
   .PATCHSERIAL(0), //.PATCHSERIAL(status[54]),
   .noTexture(status[27]),
   .textureFilter(status[82:81]),
   .textureFilterStrength(status[87:86]),
   .textureFilter2DOff(status[83]),
   .dither24(status[73]),
   .render24(status[84] && ~hack_480p),
   .drawSlow(status[90]),
   .syncVideoOut(syncVideoOut),
   .syncInterlace(status[60]),
   .rotate180(status[24]),
   .fixedVBlank(status[55] && ~hack_480p),
   .vCrop(hack_480p ? 2'b00 : status[4:3]),
   .hCrop(status[67]),
   .SPUon(~status[30]),
   .SPUIRQTrigger(status[2]),
   .SPUSDRAM(status[44] & SDRAM2_EN),
   .REVERBOFF(0),
   .REPRODUCIBLESPUDMA(status[43]),
   .WIDESCREEN(status[54:53]),
   .oldGPU(status[92]),   
   // RAM/BIOS interface
   .biosregion(biosregion),
   .ram_refresh(sdr_refresh),
   .ram_dataWrite(sdr_sdram_din),
   .ram_dataRead32(sdr_sdram_dout32),
   .ram_Adr(sdram_addr),
   .ram_cntDMA(sdram_cntDMA),
   .ram_be(sdram_be),
   .ram_rnw(sdram_rnw),
   .ram_ena(sdram_req),
   .ram_dma(sdram_dma),
   .ram_cache(sdram_cache),
   .ram_done(sdram_ack),
   .ram_dmafifo_adr  (sdram_dmafifo_adr),
   .ram_dmafifo_data (sdram_dmafifo_data),
   .ram_dmafifo_empty(sdram_dmafifo_empty),
   .ram_dmafifo_read (sdram_dmafifo_read),
   .cache_wr(cache_wr),
   .cache_data(cache_data),
   .cache_addr(cache_addr),
   .dma_wr(dma_wr),
   .dma_reqprocessed(dma_reqprocessed),
   .dma_data(dma_data),
   // vram/ddr3 (routed through the rotation arbiter, see ddram_rotate_arb)
   .DDRAM_BUSY      (psx_ddram_busy      ),
   .DDRAM_BURSTCNT  (psx_ddram_burstcnt  ),
   .DDRAM_ADDR      (psx_ddram_addr      ),
   .DDRAM_DOUT      (psx_ddram_dout      ),
   .DDRAM_DOUT_READY(psx_ddram_dout_ready),
   .DDRAM_RD        (psx_ddram_rd        ),
   .DDRAM_DIN       (psx_ddram_din       ),
   .DDRAM_BE        (psx_ddram_be        ),
   .DDRAM_WE        (psx_ddram_we        ),
   // cd (unused in ZN)
   .region          (2'b01),    // JP
   .region_out      (region_out),
   .hasCD           (1'b0),
   .LIDopen         (1'b0),
   .fastCD          (1'b0),
   .trackinfo_data  (32'h0),
   .trackinfo_addr  (9'h0),
   .trackinfo_write (1'b0),
   .resetFromCD     (resetFromCD),
   .cd_hps_req      (),
   .cd_hps_lba      (),
   .cd_hps_ack      (1'b0),
   .cd_hps_write    (1'b0),
   .cd_hps_data     (16'h0),
   // spuram
   .spuram_dataWrite(spuram_dataWrite),
   .spuram_Adr      (spuram_Adr      ),
   .spuram_be       (spuram_be       ),
   .spuram_rnw      (spuram_rnw      ),
   .spuram_ena      (spuram_ena      ),
   .spuram_dataRead (spuram_dataRead ),
   .spuram_done     (spuram_done     ),
   // memcard (unused in ZN)
   .memcard_changed (),
   .saving_memcard  (),
   .memcard1_load   (1'b0),
   .memcard2_load   (1'b0),
   .memcard_save    (1'b0),
   .memcard1_mounted   (1'b0),
   .memcard1_available (1'b0),
   .memcard1_rd     (),
   .memcard1_wr     (),
   .memcard1_lba    (),
   .memcard1_ack    (1'b0),
   .memcard1_write  (1'b0),
   .memcard1_addr   (9'h0),
   .memcard1_dataIn (16'h0),
   .memcard1_dataOut(),
   .memcard2_mounted   (1'b0),
   .memcard2_available (1'b0),
   .memcard2_rd     (),
   .memcard2_wr     (),
   .memcard2_lba    (),
   .memcard2_ack    (1'b0),
   .memcard2_write  (1'b0),
   .memcard2_addr   (9'h0),
   .memcard2_dataIn (16'h0),
   .memcard2_dataOut(),
   // video
   .videoout_on     (~status[14]),
   .isPal           (isPal),
   .pal60           (status[15]),
   .hsync           (hs),
   .vsync           (vs),
   .hblank          (hbl),
   .vblank          (vbl),
   .DisplayWidth    (DisplayWidth),
   .DisplayHeight   (DisplayHeight),
   .DisplayOffsetX  (DisplayOffsetX),
   .DisplayOffsetY  (DisplayOffsetY),
   .video_ce        (ce_pix),
   .video_interlace (video_interlace),
   .video_r         (r),
   .video_g         (g),
   .video_b         (b),
   .video_isPal     (video_isPal),
   .video_fbmode    (video_fbmode),
   .video_fb24      (video_fb24),
   .video_hResMode  (video_hResMode),
   .video_frameindex(frameindex),
   //Keys
   .DSAltSwitchMode(status[31]),
   .PadPortEnable1 (PadPortEnable1),
   .PadPortDigital1(PadPortDigital1),
   .PadPortAnalog1 (PadPortAnalog1),
   .PadPortMouse1  (PadPortMouse1 ),
   .PadPortGunCon1 (PadPortGunCon1),
   .PadPortNeGcon1 (PadPortNeGcon1),
   .PadPortWheel1  (PadPortWheel1),
   .PadPortDS1     (PadPortDS1),
   .PadPortJustif1 (PadPortJustif1),
   .PadPortStick1  (PadPortStick1),
   .PadPortPopn1   (PadPortPopn1),
   .PadPortEnable2 (PadPortEnable2),
   .PadPortDigital2(PadPortDigital2),
   .PadPortAnalog2 (PadPortAnalog2),
   .PadPortMouse2  (PadPortMouse2 ),
   .PadPortGunCon2 (PadPortGunCon2),
   .PadPortNeGcon2 (PadPortNeGcon2),
   .PadPortWheel2  (PadPortWheel2),
   .PadPortDS2     (PadPortDS2),
   .PadPortJustif2 (PadPortJustif2),
   .PadPortStick2  (PadPortStick2),
   .PadPortPopn2   (PadPortPopn2),
   .KeyTriangle({joy4[4], joy3[4], joy2[4], joy[4] }),
   .KeyCircle  ({joy4[5] ,joy3[5] ,joy2[5] ,joy[5] }),
   .KeyCross   ({joy4[6] ,joy3[6] ,joy2[6] ,joy[6] }),
   .KeySquare  ({joy4[7] ,joy3[7] ,joy2[7] ,joy[7] }),
   .KeySelect  ({joy4[8] ,joy3[8] ,joy2[8] ,joy[8] }),
   .KeyStart   ({joy4[9] ,joy3[9] ,joy2[9] ,joy[9] }),
   .KeyRight   ({joy4[0] ,joy3[0] ,joy2[0] ,joy[0] }),
   .KeyLeft    ({joy4[1] ,joy3[1] ,joy2[1] ,joy[1] }),
   .KeyUp      ({joy4[3] ,joy3[3] ,joy2[3] ,joy[3] }),
   .KeyDown    ({joy4[2] ,joy3[2] ,joy2[2] ,joy[2] }),
   .KeyR1      ({joy4[11],joy3[11],joy2[11],joy[11]}),
   .KeyR2      ({joy4[13],joy3[13],joy2[13],joy[13]}),
   .KeyR3      ({joy4[15],joy3[15],joy2[15],joy[15]}),
   .KeyL1      ({joy4[10],joy3[10],joy2[10],joy[10]}),
   .KeyL2      ({joy4[12],joy3[12],joy2[12],joy[12]}),
   .KeyL3      ({joy4[14],joy3[14],joy2[14],joy[14]}),
   .ToggleDS   (ToggleDS),
   .Analog1XP1(joy0_xmuxed),
   .Analog1YP1(joystick_analog_l0[15:8]),
   .Analog2XP1(joystick_analog_r0[7:0]),
   .Analog2YP1(joystick_analog_r0[15:8]),
   .Analog1XP2(joystick_analog_l1[7:0]),
   .Analog1YP2(joystick_analog_l1[15:8]),
   .Analog2XP2(joystick_analog_r1[7:0]),
   .Analog2YP2(joystick_analog_r1[15:8]),
   .Analog1XP3(joystick_analog_l2[7:0]),
   .Analog1YP3(joystick_analog_l2[15:8]),
   .Analog2XP3(joystick_analog_r2[7:0]),
   .Analog2YP3(joystick_analog_r2[15:8]),
   .Analog1XP4(joystick_analog_l3[7:0]),
   .Analog1YP4(joystick_analog_l3[15:8]),
   .Analog2XP4(joystick_analog_r3[7:0]),
   .Analog2YP4(joystick_analog_r3[15:8]),
   .RumbleDataP1(joystick1_rumble),
   .RumbleDataP2(joystick2_rumble),
   .RumbleDataP3(joystick3_rumble),
   .RumbleDataP4(joystick4_rumble),
   .padMode(padMode),
   .MouseEvent(mouse[24]),
   .MouseLeft(mouse[0]),
   .MouseRight(mouse[1]),
   .MouseX({mouse[4],mouse[15:8]}),
   .MouseY({mouse[5],mouse[23:16]}),
   .multitap(multitap),
   .multitapDigital(multitapDigital),
   .multitapAnalog(multitapAnalog),
   //snac
   .snacPort1(snacPort1),
   .snacPort2(snacPort2),
   .selectedPort1Snac(selectedPort1Snac),
   .selectedPort2Snac(selectedPort2Snac),
   .irq10Snac(irq10Snac),
   .transmitValueSnac(transmitValueSnac),
   .clk9Snac(clk9Snac),
   .receiveBufferSnac(receiveBufferSnac),
   .beginTransferSnac(beginTransferSnac),
   .actionNextSnac(actionNextSnac),
   .receiveValidSnac(receiveValidSnac),
   .ackSnac(~ack),//using real ack not the 1 cycle ack
   .snacMC(status[66]),

   //sound  (SPU output; mixed with Zoom / FX-1A YM2610B / Capcom QSound below to drive AUDIO_L/R)
	.sound_out_left(spu_out_left),
	.sound_out_right(spu_out_right),
   //savestates - disabled 2026-07-29 per project owner decision (ALM budget); module kept for reset/init
   .increaseSSHeaderCount (1'b0),
   .save_state            (1'b0),
   .load_state            (1'b0),
   .savestate_number      (ss_slot),
   .state_loaded          (),
   .validSStates          (validSStates),
   .rewind_on             (0), //(status[27]),
   .rewind_active         (0), //(status[27] & joy[15]),
   //cheats
   .cheat_clear(gg_reset),
   .cheats_enabled(~status[6] && ~TURBO_MEM && ~ioctl_download),
   .cheat_on(gg_valid),
   .cheat_in(gg_code),
   .cheats_active(gg_active),

   .Cheats_BusAddr(cheats_addr),
   .Cheats_BusRnW(cheats_rnw),
   .Cheats_BusByteEnable(cheats_be),
   .Cheats_BusWriteData(cheats_dout),
   .Cheats_Bus_ena(cheats_ena),
   .Cheats_BusReadData(cheats_din),
   .Cheats_BusDone(sdramCh3_done),

   // ZN-1 Arcade I/O
   .zn_p1_right   (joy[0]),
   .zn_p1_left    (joy[1]),
   .zn_p1_down    (joy[2]),
   .zn_p1_up      (joy[3]),
   .zn_p1_btn     (joy[9:4]),    // btn1-6 = joy[4..9]
   .zn_p1_start   (joy[10]),
   .zn_p1_coin    (joy[11]),
   .zn_p2_right   (joy2[0]),
   .zn_p2_left    (joy2[1]),
   .zn_p2_down    (joy2[2]),
   .zn_p2_up      (joy2[3]),
   .zn_p2_btn     (joy2[9:4]),
   .zn_p2_start   (joy2[10]),
   .zn_p2_coin    (joy2[11]),
   .zn_service    (status[95]),
   .zn_test_mode  (status[94]),
   .zn_dsw        (~status[103:96]),  // MRA <switches base="96">; status_bit=0 (default) → DSW bit=1 (Off); status_bit=1 → DSW bit=0 (On)
   // CAT702 keys loaded dynamically via MRA rom index 4 (key_a=KN01/motherboard) and 5 (key_b=KN02/game)
   // CAT702 select is ACTIVE LOW: key_a used for 0x88 path (KN01), key_b used for 0x84 path (KN02)
   .zn_cat702_key  (zn_cat702_key_a),
   .zn_cat702_key_b(zn_cat702_key_b_r),
   .zn_platform    (zn_platform_r[3:0]),
   .zn_capcom_4btn (zn_platform_r[5]),   // MRA platform-byte bit5: Capcom 4-button title (starglad)
   .zn_wd_kick     (zn_wd_kick),
   // Taito Zoom sound board glue (FX-1B/1Z)
   .zoom_enable      (zoom_enable),
   .zoom_reg_data_wr (zoom_reg_data_wr),
   .zoom_reg_data    (zoom_reg_data),
   .zoom_reg_addr_wr (zoom_reg_addr_wr),
   .zoom_reg_addr    (zoom_reg_addr),
   .zoom_irq0_wr     (zoom_irq0_wr),
   .zoom_mbx_addr    (zoom_mbx_addr),
   .zoom_mbx_be      (zoom_mbx_be),
   .zoom_mbx_din     (zoom_mbx_din),
   .zoom_mbx_we      (zoom_mbx_we),
   .zoom_mbx_q       (zoom_mbx_q),
   // MRA index-1 bit4: Capcom coh1002c 2MB-VRAM (sfex/sfexp, byte 0x15 -> boardconfig 0x69).
   // On Taito "0010" bit4 instead selects FX-1A (YM2610B) vs FX-1B (Zoom); zn1_io only reads
   // it for Capcom, so the dual use is safe.
   .zn_vram_2m     (zn_platform_r[4]),
   .zn_ee_dl_wr    (zn_ee_dl_wr),
   .zn_ee_dl_addr  (zn_ee_dl_addr),
   .zn_ee_dl_data  (zn_ee_dl_data),
   .zn_ee_ul_addr  (zn_ee_ul_addr),
   .zn_ee_ul_q     (zn_ee_ul_q),
   .zn_ee_game_wr  (zn_ee_game_wr),
   .zn_ee_dl_be    (zn_ee_dl_be),
   // stale build #17/#50/#51/#52 capture ports left unconnected so the fitter
   // sweeps the entire producer chain inside psx_top / memorymux
   .zn_debug_out   (),
   .zn_debug_val   (),
   .zn_debug_addr  (),
   .zn_debug_words (),
   // Taito FX-1A TC0140SYT sound-comm master port
   .zn_syt_fx1a    (fx1a_active),
   .zn_syt_wr      (syt_wr),
   .zn_syt_rd      (syt_rd),
   .zn_syt_a       (syt_a),
   .zn_syt_wdata   (syt_wdata),
   .zn_syt_rdata   (syt_rdata),
   // Capcom QSound main-CPU -> Z80 sound latch (write-only, 0x1FB60000)
   .zn_qsnd_wr     (qsnd_latch_wr),
   .zn_qsnd_wdata  (qsnd_latch_data),
   // MDEC input-stream debug tap (task #320)
   .dbg_mdec_ev    (mdin_ev),
   .dbg_mdec_word  (mdin_word)
);

// ============ MDEC input-stream JTAG capture (ISSP "MDIN", task #320) ============
// 2048-word ring of the exact words entering the MDEC data port (DMA0 or PIO).
// Arm from JTAG right before the FMV window; diff the capture against the MAME
// golden (scratchpad/starglad_mame/golden/mdec_in_first4k.txt). Debug builds only.
wire        mdin_ev;
wire [32:0] mdin_word;
`ifdef ZN1_MDIN_PROBE
wire [15:0] mdin_src;
wire [32:0] mdin_rddata;
wire [10:0] mdin_wptr;
wire        mdin_full;
mdin_cap #(.AW(11), .DW(33)) u_mdin (
	.clk    (clk_1x),
	.cen    (mdin_ev),
	.sample (mdin_word),
	.arm    (mdin_src[0]),
	.rdaddr (mdin_src[11:1]),
	.rddata (mdin_rddata),
	.wptr_o (mdin_wptr),
	.full   (mdin_full)
);
altsource_probe #(
	.sld_auto_instance_index ("YES"),
	.sld_instance_index      (0),
	.instance_id             ("MDIN"),
	.probe_width             (48),
	.source_width            (16),
	.source_initial_value    ("0"),
	.enable_metastability    ("NO")
) u_mdin_probe (
	.probe  ({3'd0, mdin_full, mdin_wptr, mdin_rddata}),
	.source (mdin_src)
);
`endif

////////////////////////////  MEMORY  ///////////////////////////////////

localparam ROM_START = (65536+131072)*4;

wire         sdr_refresh;
wire  [31:0] sdr_sdram_din;
wire  [31:0] sdr_sdram_dout32;
wire  [15:0] sdr_bram_din;
wire         sdr_sdram_ack;
wire         sdr_bram_ack;
wire  [26:0] sdram_addr;
wire   [1:0] sdram_cntDMA;
wire   [3:0] sdram_be;
wire         sdram_req;
wire         sdram_ack;
wire         sdram_readack;
wire         sdram_readack2;
wire         sdram_writeack;
wire         sdram_writeack2;
wire         sdram_rnw;
wire         sdram_dma;
wire         sdram_cache;
wire [ 3:0]  cache_wr;
wire [31:0]  cache_data;
wire [ 7:0]  cache_addr;
wire         dma_wr;
wire         dma_reqprocessed;
wire [31:0]  dma_data;

wire  [22:0] sdram_dmafifo_adr;
wire  [31:0] sdram_dmafifo_data;
wire         sdram_dmafifo_empty;
wire         sdram_dmafifo_read;


wire [20:0] cheats_addr;
wire cheats_rnw;
wire [3:0] cheats_be;
wire [31:0] cheats_dout;
wire cheats_ena;
wire [31:0] cheats_din;
wire sdramCh3_done;

//////////////////  build #54: SENTINEL-READBACK INSTRUMENT  /////////////////
// ===== B-inst7 (2026-07-17): SENTINEL REMOVED =====
// The build #55 "marker ramp" sentinel wrote 8 words 0xA0000000|slot to SDRAM
// 0x0E44800-0x0E4481C after EVERY banked-ROM download - overwriting 32 bytes of
// live banked ROM (image offset 0x644800) on every title. Proven corruption source
// for raystorm's "ROM R-3 ERROR" window (read-shadow sum mismatch) and prime
// suspect for the BR2 loader stall / hvnsgate garbage-bounds freeze.
// (the build #52 debug-word capture and its overlay were removed 2026-07-29)

assign sdram_ack = sdram_readack | sdram_writeack;

sdram sdram
(
   .SDRAM_DQ   (SDRAM_DQ),
   .SDRAM_A    (SDRAM_A),
   .SDRAM_DQML (SDRAM_DQML),
   .SDRAM_DQMH (SDRAM_DQMH),
   .SDRAM_BA   (SDRAM_BA),
   .SDRAM_nCS  (SDRAM_nCS),
   .SDRAM_nWE  (SDRAM_nWE),
   .SDRAM_nRAS (SDRAM_nRAS),
   .SDRAM_nCAS (SDRAM_nCAS),
   .SDRAM_CKE  (SDRAM_CKE),
   .SDRAM_CLK  (SDRAM_CLK),

   .SDRAM_EN(1),
	.init(~pll_locked),
	.clk(clk_3x),
	.clk_base(clk_1x),

	.refreshForce(sdr_refresh),
	.pagemode_en(SDRAM_PAGEMODE),

	.ch1_addr(sdram_addr),
	.ch1_din(),
	.ch1_dout(),
	.ch1_dout32(sdr_sdram_dout32),
	.ch1_req(sdram_req & sdram_rnw),
	.ch1_rnw(1'b1),
	.ch1_dma(sdram_dma),
	.ch1_cntDMA(sdram_cntDMA),
	.ch1_cache(sdram_cache),
	.ch1_ready(sdram_readack),
	.cache_wr(cache_wr),
	.cache_data(cache_data),
	.cache_addr(cache_addr),
	.dma_wr(dma_wr),
	.dma_reqprocessed(dma_reqprocessed),
	.dma_data(dma_data),

	.ch2_addr (sdram_addr),
	.ch2_din  (sdr_sdram_din),
	.ch2_dout (),
	.ch2_req  (sdram_req & ~sdram_rnw),
	.ch2_rnw  (1'b0),
	.ch2_be   (sdram_be),
	.ch2_ready(sdram_writeack),

	.ch3_addr (dl_to_sdram ? ramdownload_wraddr : {6'b0, cheats_addr}),
	.ch3_din  (dl_to_sdram ? ramdownload_wrdata : cheats_dout),
	.ch3_dout (cheats_din),
	.ch3_req  (dl_to_sdram ? ramdownload_wr     : cheats_ena),
	.ch3_rnw  (dl_to_sdram ? 1'b0 : cheats_rnw),
	.ch3_be   (dl_to_sdram ? 4'b1111            : cheats_be),
	.ch3_ready(sdramCh3_done),

	// ch4 : sample ROM read stream (read-only), shared by the two mutually-exclusive
	// sound blocks: FX-1A YM2610B ADPCM-A, or Capcom QSound 4MB sample ROM. Idle unless
	// one is active. Both live in the same 4MB SDRAM window at ADPCM_START.
	.ch4_addr (ADPCM_START[26:0] + (capcom_active ? {4'b0, qsnd_srv_addr[22:1], 1'b0}   // #310: registered serve
	                                              : {3'b0, snd_adpcma_addr[23:1], 1'b0})),
	.ch4_dout (sdram_ch4_dout),
	// QSound sample req: the clk_dsp (clk_2x) pulse is synchronised down to ONE clk_1x-
	// wide pulse (qsnd_smp_req_1x, see the CDC-hardened bridge below) so the ~100MHz SDRAM
	// sampler catches it exactly once — mirrors FX-1A's proven clk_1x pulse (snd_adpcma_req).
	.ch4_req  (capcom_active ? qsnd_smp_req_1x : snd_adpcma_req),
	.ch4_ready(sdramCh4_done),

	// ch5 : Z80 program ROM read stream (read-only), shared: FX-1A 128KB / Capcom 256KB.
	.ch5_addr (Z80ROM_START[26:0] + (capcom_active ? {9'b0, qsnd_z80_addr[17:1], 1'b0}
	                                               : {10'b0, snd_rom_addr[16:1], 1'b0})),
	.ch5_dout (sdram_ch5_dout),
	.ch5_req  (capcom_active ? qsnd_z80_req : snd_rom_req),
	.ch5_ready(sdramCh5_done),

	.dmafifo_adr  (sdram_dmafifo_adr),
	.dmafifo_data (sdram_dmafifo_data),
	.dmafifo_empty(sdram_dmafifo_empty),
	.dmafifo_read (sdram_dmafifo_read),
	.dbg_pm_hit   (),
	.dbg_pm_open  (),
	.dbg_pm_pre   (),
	.dbg_sdram    (),
	.dbg_drd1     ()
);
// ================================================================================================
// B4 AREA DIET: the jtag_la ring buffer + the ZNLA altsource_probe ISSP were removed here to make
// room for the TMS57002 DSP.  They cost ~126 ALM and 3 M10K, and every saga they were built for
// (SDRAM page mode, the 0x424/0x42C read corruption, the payload instruments) is closed.  The
// sdram.sv dbg_* outputs are still there, now unconnected, so the instrument can be restored by
// reverting this hunk and re-adding rtl/jtag_la.sv to ZN1.qsf.  Removed source is preserved in
// git history and in zoom_gt/tms_gt/b4/jtag_block_removed.txt.
//============================================================================
//  Taito FX-1A external SOUND subsystem (Z80 + YM2610B + TC0140SYT)
//============================================================================
// TC0140SYT master-port bus (from memorymux, threaded via psx_mister)
wire        syt_wr, syt_rd, syt_a;
wire  [7:0] syt_wdata;
wire  [7:0] syt_rdata;

// SPU audio (from psx_mister) before mixing with YM2610B
wire signed [15:0] spu_out_left, spu_out_right;

// FX-1A Z80 program ROM (index 6) now lives in SDRAM at Z80ROM_START, loaded via the
// shared ch3 download path (see dl_to_sdram above) — no on-chip BRAM. It is read back
// through SDRAM ch5 (glue below), freeing ~102 M10K blocks for the fit.

// Z80 program ROM read glue: module byte-request -> SDRAM ch5 32-bit read -> byte select.
wire [16:0] snd_rom_addr;
wire        snd_rom_req;
wire [31:0] sdram_ch5_dout;
wire        sdramCh5_done;
// The ch5 read fetches the 16-bit word at {addr[16:1],0}; the wanted byte is the low or
// high half depending on addr[0] (little-endian, matches the download byte packing).
wire  [7:0] snd_rom_data = snd_rom_addr[0] ? sdram_ch5_dout[15:8] : sdram_ch5_dout[7:0];

// ADPCM-A read glue: module byte-request -> SDRAM ch4 32-bit read -> byte select.
wire [23:0] snd_adpcma_addr;
wire        snd_adpcma_req;
wire [31:0] sdram_ch4_dout;
wire        sdramCh4_done;
// The ch4 read fetches the 16-bit word at {addr[23:1],0}; the wanted byte is the
// low or high half of that word depending on addr[0].
wire  [7:0] snd_adpcma_data = snd_adpcma_addr[0] ? sdram_ch4_dout[15:8] : sdram_ch4_dout[7:0];

`ifdef ZN1_HAS_YM2610B
wire signed [15:0] ym_out_left, ym_out_right;

taito_fx1a_sound u_fx1a_sound
(
	.clk          (clk_1x),
	.reset        (reset_or),
	.enable       (fx1a_active),
	// TC0140SYT master port
	.m_wr         (snd_m_wr),
	.m_rd         (syt_rd),
	.m_a          (snd_m_a),
	.m_din        (snd_m_din),
	.m_dout       (syt_rdata),
	// Z80 program ROM read bus (SDRAM ch5)
	.rom_addr     (snd_rom_addr),
	.rom_req      (snd_rom_req),
	.rom_data     (snd_rom_data),
	.rom_ready    (sdramCh5_done),
	// ADPCM-A ROM read bus
	.adpcma_addr  (snd_adpcma_addr),
	.adpcma_req   (snd_adpcma_req),
	.adpcma_data  (snd_adpcma_data),
	.adpcma_ready (sdramCh4_done),
	// stereo audio
	.snd_left     (ym_out_left),
	.snd_right    (ym_out_right),
	.dbg_fxmu     (fxmu_vec)
);

`ifdef ZN1_FXMU_PROBE
// FXMU v2: JTAG-driven SYT sound-command injection (mirrors the MAME Lua route:
// port_w 0, comm_w lo-nibble, port_w 1, comm_w hi-nibble). source = {toggle, code[7:0]}.
reg  [2:0] fxmu_tog_s = 0;
reg  [2:0] fxmu_inj_st = 0;
reg  [7:0] fxmu_code = 0;
reg  [7:0] fxmu_gap = 0;
reg        fxmu_wr = 0, fxmu_a = 0;
reg  [7:0] fxmu_wdata = 0;
always @(posedge clk_1x) begin
	fxmu_tog_s <= {fxmu_tog_s[1:0], fxmu_src[8]};
	fxmu_wr <= 1'b0;
	if (fxmu_inj_st == 0) begin
		if (fxmu_tog_s[2] ^ fxmu_tog_s[1]) begin
			fxmu_code   <= fxmu_src[7:0];
			fxmu_inj_st <= 3'd1;
			fxmu_gap    <= 8'd0;
		end
	end else begin
		fxmu_gap <= fxmu_gap + 1'b1;
		if (fxmu_gap == 8'hFF) begin
			case (fxmu_inj_st)
				3'd1: begin fxmu_a <= 1'b0; fxmu_wdata <= 8'h00;               fxmu_wr <= 1'b1; end
				3'd2: begin fxmu_a <= 1'b1; fxmu_wdata <= {4'h0, fxmu_code[3:0]}; fxmu_wr <= 1'b1; end
				3'd3: begin fxmu_a <= 1'b0; fxmu_wdata <= 8'h01;               fxmu_wr <= 1'b1; end
				3'd4: begin fxmu_a <= 1'b1; fxmu_wdata <= {4'h0, fxmu_code[7:4]}; fxmu_wr <= 1'b1; end
				default: ;
			endcase
			fxmu_inj_st <= (fxmu_inj_st == 3'd4) ? 3'd0 : fxmu_inj_st + 1'b1;
		end
	end
end
`endif

// FXMU ISSP (task #323 music diagnosis): read the FM-write/keyon/bank counters
// over JTAG while psyforce attract runs. Enable with ZN1_FXMU_PROBE=1 (taitofm
// debug builds only - NEVER in a release build).
wire [63:0] fxmu_vec;
`ifdef ZN1_FXMU_PROBE
// v3: count the PSX-side (memorymux-sourced) SYT master accesses - does the
// game ever touch 0x1FB80000/2? These count ONLY real PSX strobes, not the
// JTAG injector. Overrides the two upper counter bytes of the module vector.
reg [7:0] fxmu_psx_wr = 0, fxmu_psx_rd = 0;
always @(posedge clk_1x) begin
	if (syt_wr) fxmu_psx_wr <= fxmu_psx_wr + 1'b1;
	if (syt_rd) fxmu_psx_rd <= fxmu_psx_rd + 1'b1;
end
// v4 layout: {A5, last_mdin, slv01, slv23, bank_mask->psx_wr, keyon, fm_wr[16]}
wire [63:0] fxmu_vec3 = {fxmu_vec[63:32], fxmu_psx_wr, fxmu_vec[23:0]};
wire [15:0] fxmu_src;
wire        snd_m_wr  = syt_wr | fxmu_wr;
wire        snd_m_a   = fxmu_wr ? fxmu_a     : syt_a;
wire  [7:0] snd_m_din = fxmu_wr ? fxmu_wdata : syt_wdata;
altsource_probe #(
	.sld_auto_instance_index ("YES"),
	.sld_instance_index      (0),
	.instance_id             ("FXMU"),
	.probe_width             (64),
	.source_width            (16),
	.source_initial_value    ("0"),
	.enable_metastability    ("NO")
) u_fxmu_probe (
	.probe  (fxmu_vec3),
	.source (fxmu_src)
);
`else
wire        snd_m_wr  = syt_wr;
wire        snd_m_a   = syt_a;
wire  [7:0] snd_m_din = syt_wdata;
`endif
`else
// FX-1A YM2610B sound board COMPILED OUT for this variant. Its ch4/ch5 read glue
// (snd_rom_*, snd_adpcma_*) and YM output are tied off so the shared SDRAM muxes select
// only the other side and the audio mix carries the OR term as 0. (Pattern: capcom-wt b804360.)
wire signed [15:0] ym_out_left  = 16'sd0;
wire signed [15:0] ym_out_right = 16'sd0;
assign snd_rom_req     = 1'b0;
assign snd_adpcma_req  = 1'b0;
assign snd_rom_addr    = 17'd0;
assign snd_adpcma_addr = 24'd0;
`endif

//============================================================================
//  Capcom QSound external SOUND subsystem (Z80 + DL-1425 DSP16A + 4MB samples)
//============================================================================
// Mutually exclusive with FX-1A: shares SDRAM ch4 (samples) + ch5 (Z80 ROM), muxed
// above by capcom_active. Sound latch (0x1FB60000) threaded up from memorymux.
wire        qsnd_latch_wr;
wire  [7:0] qsnd_latch_data;

// Z80 program ROM read glue (SDRAM ch5, 256KB). Little-endian byte select, same as
// FX-1A (even byte address -> low half; matches the download byte packing).
wire [17:0] qsnd_z80_addr;
wire        qsnd_z80_req;
wire  [7:0] qsnd_z80_data = qsnd_z80_addr[0] ? sdram_ch5_dout[15:8] : sdram_ch5_dout[7:0];

// QSound sample ROM read glue (SDRAM ch4, 4MB). The MRA loads the ROM STRAIGHT, so the
// byte select is INVERTED vs FX-1A to reproduce MAME's ROM_LOAD16_WORD_SWAP ordering
// (odd byte address -> low half, even -> high half).
wire [22:0] qsnd_smp_addr;
wire        qsnd_smp_req;
// #310 (ported from ZN-2, silicon-verified): latch the ch4 word at its OWN clk_1x strobe and
// remember which address it was read for; byte-select from the RESPONSE address, not the live
// request address (which may already point at the next fetch when the synchronised done lands).
reg  [31:0] qsnd_ch4_dout_l;
reg  [22:0] qsnd_rsp_addr;
always @(posedge clk_1x) if (sdramCh4_done) begin
	qsnd_ch4_dout_l <= sdram_ch4_dout;
	qsnd_rsp_addr   <= qsnd_srv_addr;
end
wire  [7:0] qsnd_smp_data = qsnd_rsp_addr[0] ? qsnd_ch4_dout_l[7:0] : qsnd_ch4_dout_l[15:8];

`ifdef ZN1_HAS_QSOUND
wire signed [15:0] qs_out_left, qs_out_right;
wire qs_dbg_ext_rq, qs_dbg_cen;   // ZNQS ISSP taps (live cen_dsp / dsp_ext_rq inside capcom_qsound)
wire [7:0] qs_dbg_stored0_msb, qs_dbg_stored0_lsb;  // ZNQS: DSP internal-ROM word-0 readback ({msb,lsb}==0x0288 if stored OK)

capcom_qsound u_capcom_qsound
(
	.clk          (clk_1x),
	.clk_dsp      (clk_2x),
	.reset        (reset_or),
	.enable       (capcom_active),
	// main-CPU -> Z80 sound latch (0x1FB60000 byte write)
	.latch_wr     (qsnd_latch_wr),
	.latch_din    (qsnd_latch_data),
	// DL-1425 DSP program ROM load (MRA index 8, dl-1425.bin first 8KB)
	.prog_addr    (dsp_prog_addr),
	.prog_data    (dsp_prog_data),
	.prog_we      (dsp_prog_we),  // RUNTIME load of dl-1425.bin (MRA index 8) via the de-raced
	                              // loader FSM above. No firmware baked into the RBF (distributable).
	                              // FWLOAD ($readmemh) is disabled (JTDSP16_FWLOAD macro removed from qsf).
	// Z80 program ROM read bus (SDRAM ch5, 256KB)
	.rom_addr     (qsnd_z80_addr),
	.rom_req      (qsnd_z80_req),
	.rom_data     (qsnd_z80_data),
	.rom_ready    (sdramCh5_done),
	// QSound 4MB sample ROM read bus (SDRAM ch4)
	.qsnd_addr    (qsnd_smp_addr),
	.qsnd_req     (qsnd_smp_req),
	.qsnd_data    (qsnd_smp_data),
	.qsnd_ready   (qsnd_done_2x),
	.qsnd_rsp_addr(qsnd_rsp_addr),  // #310: address the response was actually read for
	// stereo audio (0 when ~enable)
	.snd_left     (qs_out_left),
	.snd_right    (qs_out_right),
	// ZNQS ISSP debug taps (live inside capcom_qsound; harmless when unread)
	.dbg_ext_rq   (qs_dbg_ext_rq),
	.dbg_cen      (qs_dbg_cen),
	// ZNQS STORED-content readback of DSP internal ROM word 0 (BRAM commit proof)
	.dbg_stored0_msb (qs_dbg_stored0_msb),
	.dbg_stored0_lsb (qs_dbg_stored0_lsb)
);

// ================================================================================================
// ZNQS in-system-source-probe (ISSP): diagnoses the Capcom QSound runtime DL-1425 DSP-ROM load.
// Compares the RAW MRA index-8 ioctl word (iow0) against the FIRST TWO byte writes the loader FSM
// actually presents to the DSP ROM (fw0/fw1), plus the live DSP external-fetch handshake
// (extrq/cen). The iow0 latch runs on clk_1x (it watches ioctl_wr); the fw0/fw1 latches now run
// on clk_dsp (== clk_2x) because prog_addr/prog_data/prog_we moved into the clk_dsp domain (see
// the CDC-fixed loader above) — sampling prog_we on clk_1x would itself be an async crossing.
// The 68-bit `znqs` vector mixes those two domains but is read asynchronously by the ISSP on its
// own JTAG clock, so no new timing-critical paths are created.
// Wrapped in ZN1_ZNQS_PROBE so normal shipping builds exclude the ISSP entirely.
// Read out with scratchpad/read_znqs.tcl (layout MUST stay in sync with that script).
`ifdef ZN1_ZNQS_PROBE
// --- capture-once: FIRST MRA index-8 (dl-1425) ioctl word -------------------------------------
reg [15:0] iow0_dout = 16'd0;
reg        iow0_seen = 1'b0;
always @(posedge clk_1x) begin
	if (dsprom_download & ioctl_wr & ~iow0_seen) begin
		iow0_dout <= ioctl_dout[15:0];
		iow0_seen <= 1'b1;
	end
end
// --- capture-once: FIRST and SECOND loader-FSM prog writes (the bytes actually sent to DSP ROM) -
reg [12:0] fw0_addr = 13'd0;
reg  [7:0] fw0_data = 8'd0;
reg [12:0] fw1_addr = 13'd0;
reg  [7:0] fw1_data = 8'd0;
reg  [1:0] fw_cnt   = 2'd0;
// clk_dsp (clk_2x): prog_* live in the clk_dsp domain now, so sample prog_we here (same clock)
// to capture the exact bytes presented to the DSP ROM without an added async crossing.
always @(posedge clk_2x) begin
	if (dsp_prog_we) begin
		case (fw_cnt)
			2'd0: begin fw0_addr <= dsp_prog_addr; fw0_data <= dsp_prog_data; fw_cnt <= 2'd1; end
			2'd1: begin fw1_addr <= dsp_prog_addr; fw1_data <= dsp_prog_data; fw_cnt <= 2'd2; end
			default: ; // hold after the first two writes
		endcase
	end
end
// --- WRITE-COMPLETENESS: count + checksum EVERY prog write (clk_dsp domain) --------------------
// Distinguishes an INCOMPLETE load (loader drops words -> wr_count < 0x2000) from a complete one.
// A full dl-1425.bin first-8KB load presents 8192 = 0x2000 byte-writes; wr_count is 14 bits so it
// can actually represent 0x2000 (a 13-bit counter would wrap 8192->0 and alias the "no writes"
// state, so this field is intentionally 14 bits -> the probe is 114 bits, not 113). wr_sum is a
// plain 16-bit running sum of every prog_data byte (natural wrap) — a whole-image fingerprint that
// differs if any byte along the bus is wrong, not just the first two captured by fw0/fw1.
reg [13:0] wr_count = 14'd0;
reg [15:0] wr_sum   = 16'd0;
always @(posedge clk_2x) begin
	if (dsp_prog_we) begin
		wr_count <= wr_count + 14'd1;
		wr_sum   <= wr_sum   + dsp_prog_data;
	end
end
// --- STORED-content readback: DSP internal-ROM word 0 as ACTUALLY stored in the BRAM -----------
wire [15:0] stored_w0 = { qs_dbg_stored0_msb, qs_dbg_stored0_lsb };  // expect 0x0288
// --- 114-bit probe vector (MSB-first), MUST match read_znqs.tcl slice map ----------------------
// Superset of the original 68-bit layout (bits [113:46] identical to the old [67:0]):
//  [113:106]=0x5A  [105:90]=iow0_dout(16)  [89:77]=fw0_addr(13)  [76:69]=fw0_data(8)
//  [68:56]=fw1_addr(13)  [55:48]=fw1_data(8)  [47]=extrq  [46]=cen
//  [45:32]=wr_count(14)  [31:16]=wr_sum(16)  [15:0]=stored_w0(16)
wire [113:0] znqs = { 8'h5A, iow0_dout, fw0_addr, fw0_data, fw1_addr, fw1_data,
                      qs_dbg_ext_rq, qs_dbg_cen,
                      wr_count, wr_sum, stored_w0 };
wire znqs_src;
altsource_probe #(
	.sld_auto_instance_index ("YES"),
	.sld_instance_index      (0),
	.instance_id             ("ZNQS"),
	.probe_width             (114),
	.source_width            (1),
	.source_initial_value    ("0"),
	.enable_metastability    ("NO")
) u_jtag_znqs (
	.probe      (znqs),
	.source     (znqs_src),
	.source_clk (clk_1x),
	.source_ena (1'b1)
);
`endif // ZN1_ZNQS_PROBE
// ================================================================================================
`else
// Capcom QSound sound board COMPILED OUT for this variant. Its stereo output and its ch4/ch5
// SDRAM-mux request/address signals are tied off so the shared muxes (capcom_active ? qsnd_* :
// snd_*) resolve to the other side, the CDC bridge below collapses to constant 0, and the
// audio mix carries qs_amp_l/r as 0. The qsnd_latch_* signals are memorymux outputs (left
// dangling, harmless) and dsp_prog_* loader outputs likewise go nowhere.
wire signed [15:0] qs_out_left  = 16'sd0;
wire signed [15:0] qs_out_right = 16'sd0;
assign qsnd_z80_req  = 1'b0;
assign qsnd_z80_addr = 18'd0;
assign qsnd_smp_req  = 1'b0;
assign qsnd_smp_addr = 23'd0;
`endif

// CDC-hardened clock-domain bridge for the QSound ch4 sample stream (verified in the
// extended Verilator sim: capcom_qsound + this bridge + a cycle-faithful ch4 model of
// sdram.sv across clk_1x/clk_2x/clk_3x).
//
//   The DSP sample-fetch handshake lives in clk_2x, the SDRAM ch4 request is sampled in
//   the ~100 MHz (clk_3x) domain gated to clk_1x, and sdramCh4_done is generated in
//   clk_1x.  The former held-level bridge had two hardware hazards:
//     (a) ch4_req stayed HIGH for the whole read latency, so sdram.sv re-armed ch4_rq on
//         every clk3xIndex tick and issued 2-3 REDUNDANT reads per fetch (sim: 198790
//         SDRAM reads for 77376 requests);
//     (b) the clk_1x sdramCh4_done fed the clk_2x DSP FSM (qsnd_ready) and this bridge
//         with NO synchroniser — an unconstrained clk_1x->clk_2x CDC that is benign in
//         phase-aligned RTL but can metastabilise on silicon (esp. at ~99% ALM / tight
//         timing), wedging the fetch FSM -> the DSP stalls -> no music.
//   Fix mirrors FX-1A's proven ch4 pattern: convert the clk_2x request pulse into ONE
//   clk_1x-wide request pulse (exactly one SDRAM read, sim: 77376 reads == 77376
//   requests), and 2-FF-synchronise the clk_1x done into clk_2x before it reaches
//   capcom_qsound.  FX-1A's own ch4 path (snd_adpcma_req/_data) is untouched.
//   The sample address is stable throughout (the DSP is stalled via cen_dsp until
//   qsnd_ok), and sdram_ch4_dout is held between reads, so the synchronised (later) load
//   still captures the correct byte.
// #310 TORN-ADDRESS FIX (ported from ZN-2, silicon-verified there: QCHK 0/2048 corrupted
// fetches, was 182/2048 — the audible "static that rides with the music"): qsnd_addr is
// assembled from TWO separate DSP events (PODS strobe = low 16 bits, ab[15]&cen_cko = bank
// bits), so on every voice/bank switch the fetch FSM fires its address-change trigger TWICE
// — once at a hybrid "torn" address and once at the real one. The old toggle crossing could
// cancel back-to-back requests, and a torn-request's data returned under the final address.
// Fix = serve-latest with the address carried end-to-end: seq-counter request crossing (no
// toggle cancel), full address latched at request and serve, response returns its serve
// address (qsnd_rsp_addr above), FSM drops responses for superseded addresses.
reg  [2:0]  qsnd_req_seq  = 0;  // clk_2x: counts DSP sample request pulses
reg  [22:0] qsnd_req_addr = 0;  // clk_2x: full address captured at the request pulse
always @(posedge clk_2x)
	if (reset_or) qsnd_req_seq <= 3'd0;
	else if (qsnd_smp_req) begin
		qsnd_req_seq  <= qsnd_req_seq + 3'd1;
		qsnd_req_addr <= qsnd_smp_addr;
	end
reg  [2:0]  qsnd_seq_s1 = 0, qsnd_seq_s2 = 0;  // clk_1x: 2-FF sync of the seq level
reg  [2:0]  qsnd_srv_seq  = 0;  // clk_1x: last seq a read was issued for
reg  [22:0] qsnd_srv_addr = 0;  // clk_1x: address of the read in flight (stable for sdram)
reg         qsnd_ch4_infl = 0;  // clk_1x: one ch4 read outstanding
reg         qsnd_smp_req_1x = 0;
always @(posedge clk_1x) begin
	qsnd_seq_s1 <= qsnd_req_seq;
	qsnd_seq_s2 <= qsnd_seq_s1;
	qsnd_smp_req_1x <= 1'b0;
	if (reset_or) begin
		qsnd_srv_seq  <= 3'd0;
		qsnd_ch4_infl <= 1'b0;
	end else begin
		if (sdramCh4_done) qsnd_ch4_infl <= 1'b0;
		if (qsnd_seq_s2 != qsnd_srv_seq && !qsnd_ch4_infl && !qsnd_smp_req_1x) begin
			qsnd_srv_seq    <= qsnd_seq_s2;
			qsnd_srv_addr   <= qsnd_req_addr;  // newest requested address (serve-latest)
			qsnd_ch4_infl   <= 1'b1;
			qsnd_smp_req_1x <= 1'b1;           // 1-clk_1x ch4_req pulse, addr registered same edge
		end
	end
end

reg  [2:0] qsnd_done_sync  = 0; // clk_2x: 2-FF sync of the clk_1x sdramCh4_done + edge
always @(posedge clk_2x)
	if (reset_or) qsnd_done_sync <= 3'b0;
	else          qsnd_done_sync <= {qsnd_done_sync[1:0], sdramCh4_done};
wire       qsnd_done_2x = qsnd_done_sync[1] & ~qsnd_done_sync[2];   // 1-clk_2x done pulse

// Audio mix: SPU (full) + FX-1A YM2610B / Capcom QSound (scaled ~1/2) with signed
// saturation. Each secondary source is gated to 0 when its block is inactive, and
// FX-1A/Capcom never coexist, so the two are OR-combined into one secondary term.
// Non-sound titles (and glpracr) = SPU only, bit-identical to the pre-sound behaviour.
// QSound DSP output level: the ~±6300 (~1/5 FS) figure was measured on the QUIET attract
// screen only.  The DL-1425 emits genuine full-scale 16-bit audio; in real gameplay (8-16
// simultaneous PCM voices) its output reaches ~40-75% FS (verified against MAME's qsound HLE,
// derived from the same dl-1425.bin our jtdsp16 runs).  The old <<<2 (x4) therefore HARD-
// CLIPPED every sample above 25% FS: 1-6% of samples on busy passages, 0% in silence ->
// exactly the reported in-band "static that rides with the music".  x2 (+6 dB) keeps a boost
// for the quiet attract level while dropping clip incidence to <=0.1% (inaudible) even at 16
// voices.  FX-1A YM path is unaffected (separate OR term, one side always 0).
wire signed [18:0] qs_g_l = $signed(qs_out_left)  <<< 1;   // x2 (+6 dB) -- was x4, which clipped
wire signed [18:0] qs_g_r = $signed(qs_out_right) <<< 1;
wire signed [15:0] qs_amp_l = (qs_g_l >  19'sd32767) ? 16'sd32767 :
                              (qs_g_l < -19'sd32768) ? -16'sd32768 : qs_g_l[15:0];
wire signed [15:0] qs_amp_r = (qs_g_r >  19'sd32767) ? 16'sd32767 :
                              (qs_g_r < -19'sd32768) ? -16'sd32768 : qs_g_r[15:0];
`ifdef ZN1_HAS_YMF271
// Raizing YMF271 (OPX) sound board -- NOT YET IMPLEMENTED. Macro reserved so the raizing
// variant compiles today as SPU-only; add the OR term here when the board lands.
`endif
`ifdef ZN1_HAS_YMZ280B
// Atlus / Cool Boarders YMZ280B sound board -- NOT YET IMPLEMENTED. Macro reserved so the
// atlus variant compiles today as SPU-only; add the OR term here when the board lands.
`endif
// Taito Zoom (FX-1B) / FX-1A YM2610B / Capcom QSound are mutually exclusive per platform,
// so exactly one of these is nonzero at a time and they OR-combine into one secondary term.
// Each term is a wire that is a constant 0 when its board is compiled out (see the `else
// branches above), so this mix stays UNCONDITIONAL across all six variants.
wire signed [15:0] snd2_left  = zoom_snd_l | ym_out_left  | qs_amp_l;
wire signed [15:0] snd2_right = zoom_snd_r | ym_out_right | qs_amp_r;
// The secondary board carries the game music at FULL scale (Capcom/Taito titles barely use the
// SPU); the 17-bit sum + saturation below prevents clipping. (Was >>1, which made QSound too quiet.)
// Music/SFX balance on QSound titles (user-reported on ZN-2, same mix here): MAME capcom_zn
// routes QSound at 1.0 and the SPU at 0.35 => music:SFX = 2.86:1. With QSound at x2 here,
// the SPU must sit at x0.6875 (>>1 + >>3 + >>4) => 2.91:1, within 0.15 dB of MAME. Trimming
// the SPU (not boosting QSound) keeps QSound clip incidence unchanged. Capcom-gated: the
// Zoom and FX-1A paths keep the SPU at unity.
wire signed [15:0] spu_bal_l = capcom_active
	? (($signed(spu_out_left)  >>> 1) + ($signed(spu_out_left)  >>> 3) + ($signed(spu_out_left)  >>> 4))
	:   $signed(spu_out_left);
wire signed [15:0] spu_bal_r = capcom_active
	? (($signed(spu_out_right) >>> 1) + ($signed(spu_out_right) >>> 3) + ($signed(spu_out_right) >>> 4))
	:   $signed(spu_out_right);
wire signed [16:0] mix_l = $signed({spu_bal_l[15],  spu_bal_l})  + $signed({snd2_left[15],  snd2_left});
wire signed [16:0] mix_r = $signed({spu_bal_r[15], spu_bal_r}) + $signed({snd2_right[15], snd2_right});
assign AUDIO_L = (mix_l >  17'sd32767) ? 16'sd32767 :
                 (mix_l < -17'sd32768) ? -16'sd32768 : mix_l[15:0];
assign AUDIO_R = (mix_r >  17'sd32767) ? 16'sd32767 :
                 (mix_r < -17'sd32768) ? -16'sd32768 : mix_r[15:0];

// ================================================================================================

wire [31:0] spuram_dataWrite;
wire [18:0] spuram_Adr;
wire  [3:0] spuram_be;
wire        spuram_rnw;
wire        spuram_ena;
wire [31:0] spuram_dataRead;
wire        spuram_done;

assign spuram_done     = sdram_readack2 | sdram_writeack2;

`ifdef MISTER_DUAL_SDRAM

sdram sdram2
(
	.SDRAM_DQ   (SDRAM2_DQ),
   .SDRAM_A    (SDRAM2_A),
   .SDRAM_DQML (),
   .SDRAM_DQMH (),
   .SDRAM_BA   (SDRAM2_BA),
   .SDRAM_nCS  (SDRAM2_nCS),
   .SDRAM_nWE  (SDRAM2_nWE),
   .SDRAM_nRAS (SDRAM2_nRAS),
   .SDRAM_nCAS (SDRAM2_nCAS),
   .SDRAM_CKE  (),
   .SDRAM_CLK  (SDRAM2_CLK),
   .SDRAM_EN   (SDRAM2_EN),

	.init(~pll_locked),
	.clk(clk_3x),
	.clk_base(clk_1x),

	.refreshForce(1'b0),
	.pagemode_en(1'b0),    // SPU SDRAM does not opt in to page-mode
	.ram_idle(),

	.ch1_addr(spuram_Adr),
	.ch1_din(),
	.ch1_dout(),
	.ch1_dout32(spuram_dataRead),
	.ch1_req(spuram_ena & spuram_rnw),
	.ch1_rnw(1'b1),
	.ch1_dma(1'b0),
   .ch1_cntDMA(2'b00),
	.ch1_cache(1'b0),
	.ch1_ready(sdram_readack2),

	.ch2_addr (spuram_Adr),
	.ch2_din  (spuram_dataWrite),
	.ch2_dout (),
	.ch2_req  (spuram_ena & ~spuram_rnw),
	.ch2_rnw  (1'b0),
   .ch2_be   (spuram_be),
	.ch2_ready(sdram_writeack2),

	.ch3_addr(0),
	.ch3_din(),
	.ch3_dout(),
	.ch3_req(1'b0),
	.ch3_rnw(1'b1),
	.ch3_ready(),

	.dmafifo_adr  (0),
	.dmafifo_data (0),
	.dmafifo_empty(1'b1),
	.dmafifo_read ()
);

`else

wire SDRAM2_EN = 0;

assign spuram_dataRead = '0;
assign sdram_readack2 = '0;
assign sdram_writeack2 = '0;

`endif


assign DDRAM_CLK = clk_2x;

// ---- DDR3 bridge sharing: PSX VRAM (priority) + screen_rotate frame buffer ----
// psx_top drives these instead of the top-level DDRAM_* pins directly; the
// arbiter muxes them with the screen_rotate write master onto the real pins.
wire  [7:0] psx_ddram_burstcnt;
wire [28:0] psx_ddram_addr;
wire [63:0] psx_ddram_dout;
wire        psx_ddram_dout_ready;
wire        psx_ddram_rd;
wire [63:0] psx_ddram_din;
wire  [7:0] psx_ddram_be;
wire        psx_ddram_we;
wire        psx_ddram_busy;

// screen_rotate write master (write-only, single-beat, region 0x24000000).
wire        sr_ddram_we;
wire        sr_ddram_rd;      // unused (screen_rotate never reads)
wire [28:0] sr_ddram_addr;
wire [63:0] sr_ddram_din;
wire  [7:0] sr_ddram_be;
wire  [7:0] sr_ddram_burstcnt;

// Taito Zoom master (read+write, lowest priority).
wire        z_ddram_req;
wire        z_ddram_we;
wire [28:0] z_ddram_addr;
wire [63:0] z_ddram_din;
wire  [7:0] z_ddram_be;
wire  [7:0] z_ddram_burstcnt;
wire        z_ddram_ack;
wire [63:0] z_ddram_dout;
wire        z_ddram_dout_ready;

ddram_rotate_arb ddram_rotate_arb
(
	.clk             (clk_2x),

	.DDRAM_BUSY      (DDRAM_BUSY      ),
	.DDRAM_BURSTCNT  (DDRAM_BURSTCNT  ),
	.DDRAM_ADDR      (DDRAM_ADDR      ),
	.DDRAM_DOUT      (DDRAM_DOUT      ),
	.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
	.DDRAM_RD        (DDRAM_RD        ),
	.DDRAM_DIN       (DDRAM_DIN       ),
	.DDRAM_BE        (DDRAM_BE        ),
	.DDRAM_WE        (DDRAM_WE        ),

	.p_burstcnt      (psx_ddram_burstcnt  ),
	.p_addr          (psx_ddram_addr      ),
	.p_dout          (psx_ddram_dout      ),
	.p_dout_ready    (psx_ddram_dout_ready),
	.p_rd            (psx_ddram_rd        ),
	.p_din           (psx_ddram_din       ),
	.p_be            (psx_ddram_be        ),
	.p_we            (psx_ddram_we        ),
	.p_busy          (psx_ddram_busy      ),

	.r_we            (sr_ddram_we   ),
	.r_addr          (sr_ddram_addr ),
	.r_din           (sr_ddram_din  ),
	.r_be            (sr_ddram_be   ),

	.z_req           (z_ddram_req      ),
	.z_we            (z_ddram_we       ),
	.z_addr          (z_ddram_addr     ),
	.z_din           (z_ddram_din      ),
	.z_be            (z_ddram_be       ),
	.z_burstcnt      (z_ddram_burstcnt ),
	.z_ack           (z_ddram_ack      ),
	.z_dout          (z_ddram_dout     ),
	.z_dout_ready    (z_ddram_dout_ready)
);

////////////////////  TAITO ZOOM SOUND BOARD INSTANCE  //////////////////////
// Held in reset unless a Taito FX MRA carrying the sound ROMs is loaded, so
// every other platform (and every FX MRA without indices 6/7) behaves exactly
// as before: no DDR3 traffic, no audio contribution, no mailbox side effects.
`ifdef ZN1_HAS_ZOOM
taito_zoom_top #(
	.WORKRAM_KB    (64),
	.DDR_PROG_BASE (ZOOM_PROG_BASE),
	.DDR_SMPL_BASE (ZOOM_SMPL_BASE)
) taito_zoom_top
(
	.clk          (clk_1x),
	.reset        (reset_or | ~zoom_enable),
	.clk_ddr      (clk_2x),

	.reg_data_wr  (zoom_reg_data_wr),
	.reg_data     (zoom_reg_data),
	.reg_addr_wr  (zoom_reg_addr_wr),
	.reg_addr     (zoom_reg_addr),
	.irq0_wr      (zoom_irq0_wr),

	.mbx_a_addr   (zoom_mbx_addr),
	.mbx_a_be     (zoom_mbx_be),
	.mbx_a_din    (zoom_mbx_din),
	.mbx_a_we     (zoom_mbx_we),
	.mbx_a_q      (zoom_mbx_q),

	.dl_req       (zoomdl_req),
	.dl_addr      (zoomdl_addr),
	.dl_data      (zoomdl_data),
	.dl_ack       (zoomdl_ack),

	.z_req        (z_ddram_req),
	.z_we         (z_ddram_we),
	.z_addr       (z_ddram_addr),
	.z_din        (z_ddram_din),
	.z_be         (z_ddram_be),
	.z_burstcnt   (z_ddram_burstcnt),
	.z_ack        (z_ddram_ack),
	.z_dout       (z_ddram_dout),
	.z_dout_ready (z_ddram_dout_ready),

	.snd_l        (zoom_snd_l),
	.snd_r        (zoom_snd_r),
	.dbg          (zoom_dbg)
);
`else
// Taito Zoom (FX-1B) sound board COMPILED OUT for this variant. All of its outputs are tied
// off: the audio mix OR term (zoom_snd_l/r), the mailbox read-back into psx (zoom_mbx_q), the
// download ack (zoomdl_ack), the DDR master port into ddram_rotate_arb (z_ddram_*), and dbg.
// zoom_enable is a constant 0 in this variant, so psx prunes the Zoom register/mailbox decode.
assign zoom_snd_l        = 16'sd0;
assign zoom_snd_r        = 16'sd0;
assign zoom_mbx_q        = 16'd0;
assign zoomdl_ack        = 1'b0;
assign zoom_dbg          = 4'd0;
assign z_ddram_req       = 1'b0;
assign z_ddram_we        = 1'b0;
assign z_ddram_addr      = 29'd0;
assign z_ddram_din       = 64'd0;
assign z_ddram_be        = 8'd0;
assign z_ddram_burstcnt  = 8'd0;
`endif

////////////////////////////  VIDEO  ////////////////////////////////////

assign CLK_VIDEO = clk_vid;

wire hs, vs, hbl, vbl, video_interlace, video_isPal, video_fbmode, video_fb24;

wire [2:0] video_hResMode;

wire ce_pix;
wire [7:0] r,g,b;
// build #53: LOAD-TIME capture of the 8 banked-ROM words written to SDRAM [0xE44800,0xE44820)
// during bankedrom_download. Game-independent — frozen after load. word slot s in bits [s*32 +: 32].
// Expected loaded ROM sequence: 0=0x00007FFF 1=0 2=0 3=0 4=0x00200000 5=0x00200020 6=0x00200020 7=0x00400020.

// Force progressive (480p) rendering while rotating: screen_rotate captures a
// whole frame into DDR, so interlaced fields would alternate half-height frames.
wire hack_480p = status[89] | rot_en;

typedef struct {
	logic [7:0] red;
	logic [7:0] green;
	logic [7:0] blue;
	logic       hs;
	logic       vs;
	logic       hb;
	logic       vb;
	logic       interlace;
} vid_info;

vid_info video_aspect;
vid_info video_gamma;

////////////////////////////  CRT ADJUST  ///////////////////////////////
// Core-side analog CRT geometry (MiSTer-CRT-Adjust / crt_adjust.sv): H-Size,
// H-Position, V-Shift from the OSD, applied to the post-gamma stream at the
// video-output boundary. See docs/core-side-integration.md. No sys/ edits.
// video_gamma.* is driven by the gamma_corr instance further below; continuous
// assigns / instances are concurrent, so reading it here (before that instance)
// is fine.
//
// ZN-1 specifics vs the reference (fixed-res arcade) integration:
//  * PSX resolution is variable -> the read-period base is LUT'd from the
//    core's own video_hResMode (256/320/368/512/640 -> clk_vid/pixel div
//    10/8/7/5/4 -> 40/32/28/20/16 quarter-cycles) instead of a hardcoded 64.
//  * Auto-disabled while digitally rotating (crt_on &= ~rot_en): the
//    screen_rotate DDR framebuffer normalizes pixel timing and would eat it.
//  * Default Off -> analog and HDMI both bit-native until the user opts in.

// -- decode OSD (uniform signed 5-bit fields, ±16; registered on native ce_pix)
reg              crt_on;
reg signed [4:0] crt_hsize_s, crt_hpos_s, crt_vsh_s;
always @(posedge clk_vid) if (ce_pix) begin
	crt_on      <= status[96] & ~rot_en;
	crt_hsize_s <= $signed(status[101:97]);
	crt_hpos_s  <= $signed(status[106:102]);
	crt_vsh_s   <= $signed(status[111:107]);
end
wire signed [8:0] crt_hpos_off = {{4{crt_hpos_s[4]}}, crt_hpos_s};   // ±16 px
wire signed [5:0] crt_vsh_off  = {crt_vsh_s[4], crt_vsh_s};          // ±16 lines

// -- read clock-enable: quarter-cycle stepped, base from the active PSX res.
// video_hResMode: 0=256,1=320,2=368,3=512,4=640 -> div 10,8,7,5,4 -> base*4.
logic [7:0] crt_base_lut[8];
assign      crt_base_lut = '{8'd40, 8'd32, 8'd28, 8'd20, 8'd16, 8'd16, 8'd16, 8'd16};
wire [7:0] crt_base_q  = crt_base_lut[video_hResMode];
wire [7:0] crt_rd_per  = crt_base_q + {{3{crt_hsize_s[4]}}, crt_hsize_s};  // base ± hsize

wire       crt_hs_ref;                    // registered inside module -> no comb loop
reg        crt_hs_ref_d;
always @(posedge clk_vid) crt_hs_ref_d <= crt_hs_ref;
wire       crt_hs_ref_rise = crt_hs_ref & ~crt_hs_ref_d;

reg  [7:0] crt_rd_acc;
wire       crt_rd_tick = (crt_rd_acc + 8'd4) >= crt_rd_per;
always @(posedge clk_vid) begin
	if      (crt_hs_ref_rise) crt_rd_acc <= 8'd0;
	else if (crt_rd_tick)     crt_rd_acc <= crt_rd_acc + 8'd4 - crt_rd_per;
	else                      crt_rd_acc <= crt_rd_acc + 8'd4;
end
wire rd_ce = crt_on ? crt_rd_tick : ce_pix;

// -- the module
wire [7:0] crt_r, crt_g, crt_b;
wire       crt_hs, crt_vs, crt_hb, crt_vb;
crt_adjust #(
`ifdef ZN1_HAS_ZOOM
	// FX-1B/Zoom titles (Ray Storm/G-Darius/Fighters' Impact) are 240p 15kHz —
	// never 480i — so the V-Shift shreg only needs progressive-frame depth. The
	// smaller shreg recovers logic to fit CRT Adjust into the (fullest) Zoom core.
	.VTOTAL   (320),
`else
	.VTOTAL   (640),      // V-Shift shreg depth (>= max PSX lines/frame incl. 480i PAL)
`endif
	.HTOTAL   (1024),     // HSync shreg depth  (>= max PSX line length)
	.HPOS_MODE(1)         // CONTENTSHIFT (wide/centered PSX games)
) u_crt_adjust (
	.clk       (clk_vid),
	.pxl_cen   (ce_pix),                        // write rate (native pixel)
	.pxl2_cen  (rd_ce),                         // read rate  (H-Size)
	.active    (crt_on),
	.hsize     (crt_hsize_s),
	.hoffset   (crt_hpos_off),
`ifdef ZN1_HAS_ZOOM
	// Zoom is the fullest core; tie V-Shift off so Quartus prunes the VSync shreg +
	// its variable-tap mux, reclaiming the ALM/routing headroom that lets
	// OPTIMIZE_HOLD_TIMING keep all clocks positive at ~98% (HIGH-density hold fails
	// at 99%). Zoom keeps H-Size + H-Position; the other 3 cores keep full V-Shift.
	.voffset   (6'sd0),
`else
	.voffset   (crt_vsh_off),
`endif
	.r_in      (video_gamma.red),
	.g_in      (video_gamma.green),
	.b_in      (video_gamma.blue),
	.hs_in     (video_gamma.hs),
	.vs_in     (video_gamma.vs),
	.hb_in     (video_gamma.hb | video_gamma.vb),
	.vb_in     (video_gamma.vb),               // TRUE vblank (keeps OSD visible)
	.r_out     (crt_r), .g_out (crt_g), .b_out (crt_b),
	.hs_out    (crt_hs), .vs_out (crt_vs),
	.hb_out    (crt_hb), .vb_out (crt_vb),
	.hs_ref_out(crt_hs_ref)
);

// -- OSD stays centered on the physical screen: a DE window whose rising edge
// is anchored to the NATIVE active region, closing on the stretched active end.
wire crt_native_active = ~(video_gamma.hb | video_gamma.vb);
reg  crt_native_active_d;
always @(posedge clk_vid) if (ce_pix) crt_native_active_d <= crt_native_active;
wire crt_native_rise = crt_native_active & ~crt_native_active_d;

wire crt_str_active = ~crt_hb;
reg  crt_str_active_d;
always @(posedge clk_vid) if (rd_ce) crt_str_active_d <= crt_str_active;
wire crt_str_fall = crt_str_active_d & ~crt_str_active;

reg crt_deosd;
always @(posedge clk_vid) begin
	if      (crt_native_rise) crt_deosd <= 1'b1;
	else if (crt_str_fall)    crt_deosd <= 1'b0;
end

// CRT Adjust output mux (glue block above; crt_adjust module + gamma_corr below).
// crt_on=0 -> native passthrough (analog + HDMI untouched). crt_on=1 -> analog
// geometry from crt_adjust; CE_PIXEL becomes the (H-Size) read rate so the DAC
// holds each pixel for its adjusted duration. Internal write-side pipeline stays
// on the native ce_pix (below), so the mux never disturbs raster generation.
assign CE_PIXEL = crt_on ? rd_ce   : ce_pix;
assign VGA_R    = crt_on ? crt_r   : video_gamma.red;
assign VGA_G    = crt_on ? crt_g   : video_gamma.green;
assign VGA_B    = crt_on ? crt_b   : video_gamma.blue;
assign VGA_VS   = crt_on ? crt_vs  : video_gamma.vs;
assign VGA_HS   = crt_on ? crt_hs  : video_gamma.hs;
assign VGA_DE   = crt_on ? crt_deosd : ~(video_gamma.vb | video_gamma.hb);
assign VGA_F1   =  status[14] ? 1'b0 : video_aspect.interlace;
assign VGA_SL = 0;
logic [11:0] aspect_x, aspect_y;

wire [1:0] ar = status[33:32];
// Base (unrotated) aspect. When the image is digitally rotated 90 degrees it
// becomes portrait, so in auto-AR mode (ar==0) swap ARX/ARY to letterbox on a
// landscape screen. User-forced AR (ar!=0, incl. Full Screen where ARY=0) is
// left untouched so those modes still behave as chosen.
wire [11:0] arx_base = (status[54:53] == 1) ? 12'd3 : (status[54:53] == 2) ? 12'd5 : (status[54:53] == 3) ? 12'd16 : status[11] ? 12'd2 : aspect_x;
wire [11:0] ary_base = (status[54:53] == 1) ? 12'd2 : (status[54:53] == 2) ? 12'd3 : (status[54:53] == 3) ? 12'd9  : status[11] ? 12'd1 : aspect_y;
wire        ar_swap  = rot_en & ~(|ar);
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? (ar_swap ? ary_base : arx_base) : (ar - 1'd1)),
	.ARY((!ar) ? (ar_swap ? arx_base : ary_base) : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[35:34])
);

// Res  Div Padding
// 256  10  +25
// 320  8   +32
// 368  7   +37
// 512  5   +51
// 640  4   +64

localparam reg [23:0] aspect_ratio_lut_ntsc[128] = '{
    24'h37015B, 24'h2B4113, 24'h1A10A7, 24'hEB45EF, 24'hA00411, 24'hF8365B, 24'hA31435, 24'h6A42C3,
    24'h85D381, 24'hF8F691, 24'h581257, 24'h1860A7, 24'hFD56D4, 24'h6EF303, 24'h497202, 24'hDA1601,
    24'hF8D6E6, 24'h8513B7, 24'hB014F3, 24'h3C51B5, 24'h3971A3, 24'hC02583, 24'hD09606, 24'h4E1245,
    24'hFEF776, 24'hC555D0, 24'hBD559D, 24'hE686E1, 24'hF7C771, 24'hC4F5F4, 24'h655315, 24'hB5158B,
    24'h2C015B, 24'h1750B9, 24'hC74637, 24'hF857CB, 24'h89B459, 24'h800411, 24'hC87668, 24'hA21536,
    24'hFB3820, 24'h443238, 24'hE17761, 24'hFD3856, 24'h207113, 24'h204113, 24'h3941EB, 24'hE6F7C8,
    24'h28015B, 24'hD55745, 24'hD21733, 24'hE9F810, 24'hC0A6AD, 24'h99955A, 24'hA0359D, 24'h7FF482,
    24'hD5B792, 24'hE5C82F, 24'hF558C9, 24'h35D1F0, 24'h6EF404, 24'h93155A, 24'h5BF35D, 24'h9F75DD,
    24'h6E0411, 24'h2DF1B5, 24'h44D292, 24'h1160A7, 24'hB4F6D4, 24'hD49810, 24'hD057F1, 24'h91B595,
    24'hB006C7, 24'hF959A6, 24'hE338D6, 24'hC1378D, 24'hC557C0, 24'hF579B0, 24'h7E1500, 24'hABD6D9,
    24'hFE3A2E, 24'hD3D886, 24'h54736A, 24'hFF3A5E, 24'hE19935, 24'hF42A03, 24'h356233, 24'hFEBA8B,
    24'h957637, 24'hEFAA03, 24'h43F2DA, 24'hA6F70A, 24'h20015B, 24'h24D191, 24'h72E4E9, 24'hC1E853,
    24'hDC097D, 24'hD09909, 24'hFE8B13, 24'hD5E959, 24'hFEFB31, 24'h2B81EB, 24'h8A5620, 24'h2B91F0,
    24'h2AF1EB, 24'hD3F982, 24'hED9AB4, 24'h163101, 24'h724531, 24'hDCBA12, 24'hC50907, 24'hFB7B92,
    24'h580411, 24'hFDDBC7, 24'hAA77F1, 24'hD259D7, 24'h2ED233, 24'h2431B5, 24'hC1992B, 24'h20F191,
    24'h7665A7, 24'h42D334, 24'hD09A0A, 24'hF17BAB, 24'hFFFC6B, 24'h6B653B, 24'h5153FA, 24'hFD9C73
};

localparam reg [23:0] aspect_ratio_lut_pal[160] = '{
    24'hE8F4D9, 24'h41015D, 24'h40815D, 24'h8EB30A, 24'hF8D557, 24'h1C009B, 24'h1CB0A0, 24'h473190,
    24'h711280, 24'hCEF49C, 24'hD734D4, 24'hCAC495, 24'h4791A1, 24'hF695A7, 24'hC7549A, 24'hC31489,
    24'hAEB417, 24'hB8C45B, 24'hA2C3DD, 24'hBCF484, 24'hD2E513, 24'hC2A4B7, 24'hEFF5DA, 24'h85D349,
    24'h18809B, 24'h0C9050, 24'hF59626, 24'hE595C9, 24'h35C15D, 24'hF81655, 24'h0EC061, 24'hEA160D,
    24'h68D2BA, 24'hD735A2, 24'h4731E0, 24'hE9A631, 24'hDC35DF, 24'h6D12ED, 24'h96D412, 24'hB87502,
    24'hCFF5AE, 24'h73732C, 24'hF1D6AF, 24'h7CA377, 24'h30C15D, 24'hA7A4B7, 24'h5C629D, 24'h3941A1,
    24'h4A221F, 24'hF5B712, 24'hD5F631, 24'h8ED428, 24'h8BC417, 24'hE236A8, 24'hA854FB, 24'hEAE6FD,
    24'hD73670, 24'hD5666B, 24'hFD97AB, 24'hA8751F, 24'hCDA649, 24'hCE1655, 24'h5C92DC, 24'h3BC1DB,
    24'hAEB574, 24'hB5A5B3, 24'hFE8807, 24'h2B015D, 24'h13009B, 24'hB6F5DC, 24'hA5E557, 24'hC7D677,
    24'hD1A6D1, 24'h099050, 24'hEF37DB, 24'hB8C619, 24'h25B140, 24'h4FD2A9, 24'hE1978E, 24'hD7373E,
    24'h28515D, 24'hE437C1, 24'hD35737, 24'hF4D866, 24'hF97899, 24'h42724D, 24'h5572F9, 24'h27015D,
    24'hCF0745, 24'h6D83DD, 24'hFFB910, 24'hE35818, 24'hEB2869, 24'hB1565F, 24'hF3F8CE, 24'hE05822,
    24'h10A09B, 24'hEFF8C7, 24'h9E35D0, 24'h87B502, 24'hBAF6EE, 24'hD7D809, 24'hD7380C, 24'hF59939,
    24'h2E31BE, 24'hE0B883, 24'h6B8417, 24'h93F5A7, 24'h09E061, 24'hE3B8C6, 24'hBCE74F, 24'h2FC1DB,
    24'h22F15D, 24'h818513, 24'h5ED3BB, 24'hFF3A15, 24'h5AB399, 24'hB52737, 24'hF0199A, 24'hEE5992,
    24'hBDB7A6, 24'hC74811, 24'h3FD298, 24'h77F4E5, 24'h4552D7, 24'h1390CE, 24'hE4D973, 24'h25B190,
    24'h91960F, 24'hBBD7D9, 24'h20815D, 24'h788513, 24'h20415D, 24'h9BF69E, 24'h8EB614, 24'h8435A7,
    24'hF8DAAE, 24'h9B26AF, 24'h0E009B, 24'h8EA631, 24'h1CB140, 24'h1B112F, 24'hD05925, 24'hD1F940,
    24'h89060F, 24'hD7098B, 24'h88060F, 24'h4172ED, 24'hD739A8, 24'hDBE9E7, 24'h656495, 24'hFF8B97,
    24'hD1A98B, 24'hA6D79F, 24'hB4E84B, 24'hEC7AE1, 24'hFF1BC7, 24'h5C944A, 24'hC31912, 24'hEE8B21
};

logic [11:0] h_pos, v_pos, vb_pos, v_total;
logic [11:0] hb_start_lut[8];
logic [11:0] hb_end_lut[8];
logic [11:0] hb_start, hb_end;

// FIXME: this should be adjusted if hsync changes size to maintain center
assign hb_start_lut = '{12'd63,  12'd50,  12'd36,  12'd31,  12'd24,  12'd0, 12'd0, 12'd0};
assign hb_end_lut =   '{12'd767, 12'd613, 12'd441, 12'd383, 12'd305, 12'd0, 12'd0, 12'd0};

always_comb begin
	hb_start = hb_start_lut[video_hResMode];
	hb_end = hb_end_lut[video_hResMode];
end

always_ff @(posedge CLK_VIDEO) if (ce_pix) begin   // native write-side enable (not the muxed CE_PIXEL output)
	logic old_vb;
	old_vb <= vbl;
	video_aspect.hs <= hs;
	video_aspect.vs <= vs;
	video_aspect.vb <= vbl;
	video_aspect.interlace <= video_interlace;
	video_aspect.red <= (vbl || hbl) ? 8'd0 : r;
	video_aspect.green <= (vbl || hbl) ? 8'd0 : g;
	video_aspect.blue <= (vbl || hbl) ? 8'd0 : b;
	{aspect_x, aspect_y} <= video_isPal ? aspect_ratio_lut_pal[v_total] : aspect_ratio_lut_ntsc[v_total];

	VGA_DISABLE <= fast_forward;

	h_pos <= h_pos + 1'd1;
	if (~old_vb && vbl)
		vb_pos <= 0;

	if (video_aspect.hs && ~hs) begin
		h_pos <= 0;
		if (~vbl)
			v_pos <= v_pos + 1'd1;
		else
			vb_pos <= vb_pos + 1'd1;
	end

	if (~video_aspect.vs && vs) begin
		v_pos <= 0;

		if (v_pos < 128)
			v_total <= 6'd0;
		else if (video_isPal && v_pos > 287)
			v_total <= 8'd159;
		else if (~video_isPal && v_pos > 255)
			v_total <= 7'd127;
		else
			v_total <= v_pos - 8'd128;
	end

	if (vb_pos > (video_isPal ? 161 : 135))
		video_aspect.vb <= 0;

	if (h_pos == hb_start)
		video_aspect.hb <= 0;
	if (h_pos == hb_end)
		video_aspect.hb <= 1;
	if (status[62] || hack_480p || (status[54:53] > 0))
		video_aspect.hb <= hbl;

	// (stale build #52/#80/#155 debug-bar overlay removed 2026-07-29: the DoA++/CLUT
	//  saga it instrumented is closed, and its zn_debug_words consumer was the only
	//  thing keeping the psx_top / memorymux capture chain alive.)

end

// Pause overlay: when the joystick "pause" button (joy[18]) toggles button_paused on,
// replace video with the XN logo + scrolling Patreon credits. Other pause sources
// (OSD-open, savestate) still display the last game frame.
wire [7:0] pause_overlay_r, pause_overlay_g, pause_overlay_b;
pause_overlay u_pause_overlay (
	.clk         (CLK_VIDEO),
	.ce_pix      (ce_pix),
	.hblank      (video_aspect.hb),
	.vblank      (video_aspect.vb),
	.enable      (button_paused),
	// When digital 90-degree rotation is active the overlay must be authored
	// upright in source space - screen_rotate turns the whole frame (overlay
	// included). Legacy Pause-H/V + 180 apply only when not digitally rotating.
	.rotate180   (rot_en ? 1'b0 : status[24]),
	.vertical    (rot_en ? 1'b0 : status[25]),
	.vid_r_in    (video_aspect.red),
	.vid_g_in    (video_aspect.green),
	.vid_b_in    (video_aspect.blue),
	.vid_r_out   (pause_overlay_r),
	.vid_g_out   (pause_overlay_g),
	.vid_b_out   (pause_overlay_b)
);

assign gamma_bus[21] = 1;
gamma_corr gamma(
	.clk_sys(gamma_bus[20]),
	.clk_vid(CLK_VIDEO),
	.ce_pix(ce_pix),

	.gamma_en(gamma_bus[19]),
	.gamma_wr(gamma_bus[18]),
	.gamma_wr_addr(gamma_bus[17:8]),
	.gamma_value(gamma_bus[7:0]),

	.HSync(video_aspect.hs),
	.VSync(video_aspect.vs),
	.HBlank(video_aspect.hb),
	.VBlank(video_aspect.vb),
	.RGB_in({pause_overlay_r, pause_overlay_g, pause_overlay_b}),

	.HSync_out(video_gamma.hs),
	.VSync_out(video_gamma.vs),
	.HBlank_out(video_gamma.hb),
	.VBlank_out(video_gamma.vb),
	.RGB_out({video_gamma.red,video_gamma.green,video_gamma.blue})
);

//////////////////////////  SCREEN ROTATE  //////////////////////////////
// Standard MiSTer sys/screen_rotate.v (in sys/arcade_video.v): captures the
// live post-gamma raster into a DDR frame buffer at 0x24000000 (transposed) and
// drives the HPS framebuffer scanout (FB_*), giving a true 90-degree rotation.
//
// screen_rotate runs in the clk_2x (DDRAM) domain so its write master is native
// to the DDR bridge - no async FIFO/CDC needed on the write side. The only cross
// from the pixel (clk_vid) domain is the CE_PIXEL enable; the RGB/HS/VS/DE data
// is held stable between pixel enables, so we synchronize just the enable and
// re-pulse it in clk_2x. clk_2x (~2x system clock) is far faster than the pixel
// clock, so every 1-clk_vid CE_PIXEL pulse is safely captured.
reg cep_s1, cep_s2, cep_s3;
always @(posedge clk_2x) begin
	cep_s1 <= CE_PIXEL;
	cep_s2 <= cep_s1;
	cep_s3 <= cep_s2;
end
wire ce_pix_2x = cep_s2 & ~cep_s3;   // rising edge -> single clk_2x pulse

screen_rotate u_screen_rotate
(
	.CLK_VIDEO   (clk_2x),
	.CE_PIXEL    (ce_pix_2x),

	.VGA_R       (VGA_R),
	.VGA_G       (VGA_G),
	.VGA_B       (VGA_B),
	.VGA_HS      (VGA_HS),
	.VGA_VS      (VGA_VS),
	.VGA_DE      (VGA_DE),

	.rotate_ccw  (rot_ccw),
	.no_rotate   (~rot_en),
	.flip        (1'b0),
	.video_rotated(),

	.FB_EN       (sr_fb_en),
	.FB_FORMAT   (sr_fb_format),
	.FB_WIDTH    (sr_fb_width),
	.FB_HEIGHT   (sr_fb_height),
	.FB_BASE     (sr_fb_base),
	.FB_STRIDE   (sr_fb_stride),
	.FB_VBL      (FB_VBL),
	.FB_LL       (FB_LL),

	.DDRAM_CLK   (),                 // uses clk_2x internally; pins driven by arbiter
	.DDRAM_BUSY  (1'b0),             // screen_rotate ignores busy; arbiter handles it
	.DDRAM_BURSTCNT(sr_ddram_burstcnt),
	.DDRAM_ADDR  (sr_ddram_addr),
	.DDRAM_DIN   (sr_ddram_din),
	.DDRAM_BE    (sr_ddram_be),
	.DDRAM_WE    (sr_ddram_we),
	.DDRAM_RD    (sr_ddram_rd)
);



////////////////////////////  CODES  ///////////////////////////////////

// Code layout:
// {code flags,     32'b address, 32'b compare, 32'b replace}
//  127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.
reg [127:0] gg_code;
reg gg_valid;
reg gg_reset;
reg code_download_1;
wire gg_active;
always_ff @(posedge clk_1x) begin

   gg_reset <= 0;
   code_download_1 <= code_download;
	if (code_download && ~code_download_1) begin
      gg_reset <= 1;
   end

   gg_valid <= 0;
	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_dout; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_dout; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_dout; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_dout; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_dout; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_dout; // Compare top Word
			12: gg_code[15:0]    <= ioctl_dout; // Replace Bottom Word
			14: begin
				gg_code[31:16]    <= ioctl_dout; // Replace Top Word
				gg_valid          <= 1;          // Clock it in
			end
		endcase
	end
end

wire clk8Snac;
wire clk9Snac;
wire oldClk8;
wire oldClk9;
wire selectedPort1Snac;
wire selectedPort2Snac;
wire oldselectedPort1;
wire oldselectedPort2;
wire [7:0]transmitValueSnac;
wire [7:0]receiveBufferSnac;
wire receiveValidSnac;
wire beginTransferSnac;
wire actionNextSnac;
wire actionNextPadSnac;
reg [7:0]Send;
reg [7:0]Receive;
wire Cmd;
wire Dat;
wire ack;
wire oldAck;
//wire ackSnac;
wire [15:0]ackTimer;
wire ackNone;
wire oneTime;
wire [3:0]bitCnt;
wire [8:0]byteCnt;
wire [8:0]bytesLeft;
wire [7:0]pad1ID;
wire [7:0]pad2ID;
wire [7:0]targetID;
wire irq10Snac;
wire csync;
wire MCtransfer;
wire PStransfer;
wire [7:0]PSdatalength;

reg USER_IN3_1;
reg USER_IN4_1;
reg USER_IN6_1;

reg USER_IN3_2;
reg USER_IN4_2;
reg USER_IN6_2;

reg USER_IN3_3;
reg USER_IN3_4;
reg ackglitch;

assign clk8Snac = bitCnt < 8 ? clk9Snac : 1'b1;

always @(posedge clk_1x)
begin

   USER_IN3_1 <= USER_IN[3];
   USER_IN4_1 <= USER_IN[4];
   USER_IN6_1 <= USER_IN[6];

   USER_IN3_2 <= USER_IN3_1;
   USER_IN4_2 <= USER_IN4_1;
   USER_IN6_2 <= USER_IN6_1;

   USER_IN3_3 <= USER_IN3_2;//glitch filter for ack
   USER_IN3_4 <= USER_IN3_3;
   ackglitch  <= ~USER_IN3_1 && ~USER_IN3_2 && ~USER_IN3_3 && ~USER_IN3_4 ? 1'b0 : 1'b1;

	if (snacPort1 || snacPort2) begin
		USER_OUT[0] <= ~selectedPort2Snac;
		USER_OUT[1] <= ~selectedPort1Snac;
		USER_OUT[2] <= Cmd;
		USER_OUT[3] <= 1'b1; //ACK
		USER_OUT[4] <= 1'b1; //DAT
		USER_OUT[5] <= oldClk8;
		USER_OUT[7] <= 1'b1;                         // DB9 disabled while SNAC active
		ack         <= ~ackglitch ? USER_IN3_2 : 1'b1;
		Dat         <= USER_IN4_2;

		if ((pad1ID == 8'h63 || pad2ID == 8'h63) && (pad1ID != 8'h31 || pad2ID != 8'h31)) begin //quirk for guncon, irq is N/C in guncon. so using irq line and outputting csync on snac for g-con. only if justifier isn't connected
			USER_OUT[6] <= ~csync;
			irq10Snac   <= 1'b0;
			csync       <= VGA_HS ^ VGA_VS;//real csync shifts HSync during VSync, should be close enough to work	with guncon
		end
		else begin
			USER_OUT[6] <= 1'b1;
			irq10Snac   <= ~USER_IN6_2;
		end
	end
	else begin
		// [MiSTer-DB9] SerJoystick relay falls through to the joydb USER_OUT_DRIVE
		USER_OUT  <= USER_OUT_DRIVE;
		irq10Snac <= 1'b0;
		ack       <= 1'b1;
		Dat       <= 1'b1;
	end

	oldselectedPort1 <= selectedPort1Snac;
	oldselectedPort2 <= selectedPort2Snac;

	if ((~oldselectedPort1 && selectedPort1Snac) || (~oldselectedPort2 && selectedPort2Snac)) begin
		byteCnt   <= 9'd0;
		bytesLeft <= 9'd0;
	end

	if (beginTransferSnac) begin
		bitCnt  <= 4'd0;
		byteCnt <= byteCnt + 9'd1 ;
	end

	oldClk8 <= clk8Snac;
	oldClk9 <= clk9Snac;

	if (oldClk9 && ~clk9Snac) begin	//send on falling edge
		if (bitCnt < 8) begin
			if (bitCnt==0) begin
				Cmd  <= transmitValueSnac[0];
				Send <= {1'b1, transmitValueSnac[7:1]};
			end
			else begin
				Cmd  <= Send[0];
				Send <= {1'b1, Send[7:1]};
			end
		end
		else begin
			Cmd  <= 1'b1;
			Send <= Send;
		end
	end

	if(~oldClk8 && clk8Snac) begin //receive on rising edge
		Receive <= { Dat, Receive[7:1]};
		bitCnt <= bitCnt + 1'b1;
		if(bitCnt == 4'd7) begin//check for ack
			oneTime <= 1'b1;
			if (MCtransfer) ackTimer <= 16'd60000;//very late ack after 7th byte. around 56000 cycles (1.7ms) with a sony MC. 3rd party MCs don't seem to do this
			else begin
				if (byteCnt == bytesLeft + 3) ackTimer <= 16'd400;//only wait around 150 on last byte
				else ackTimer <= 16'd1800;//1st byte of multitap(1375) cycles to ack,digital(460),analog(350-400),ds2(250-400),mouse(120),guncon(270)
			end
		end
	end

	if (ackTimer > 0) begin
		ackTimer <= ackTimer - 16'd1;
	end

	oldAck <= ack;
	if(oldAck && ~ack) begin //ack received
		actionNextPadSnac <= 1'b1;
		ackTimer <= 16'd173;//16'd255;//a delay between ack and next action. too small might cause a hang. was using acktimer 1-255
	end
	else if(ackTimer == 1) begin //wait over
		actionNextPadSnac <= 1'b1;
		oneTime <= 1'b0;
	end
	else if (ackTimer == 16'd258) begin //no ack
		ackNone <= 1'b1;
		actionNextPadSnac <= 1'b1;
	end
	else if (ackTimer == 16'd256) begin //reset if no ack
		oneTime <= 1'b0;
		ackTimer <= 16'd0;
	end
	else begin
		actionNextPadSnac <= 1'b0;
		ackNone <= 1'b0;
	end

	if (actionNextPadSnac && ((snacPort1 && selectedPort1Snac) || (snacPort2 && selectedPort2Snac))) begin //logic for joypad.vhd
		if (oneTime) begin
			if (ackNone) begin
				if (byteCnt < (bytesLeft + 4)) begin // no ack on last byte of transfer
					receiveBufferSnac <= Receive;
					receiveValidSnac <= 1'b1;
					actionNextSnac <= 1'b1;
				end
				else
					actionNextSnac <= 1'b1;
				end
			else begin
				if (byteCnt < (bytesLeft + 4)) begin
					receiveBufferSnac <= Receive;
					receiveValidSnac <= 1'b1;
					//ackSnac <= 1'b1;
				end
				actionNextSnac <= 1'b1;
			end
		end
		else begin
			actionNextSnac <= 1'b1;
		end
	end
	else begin
		receiveBufferSnac <= 8'd0;
		receiveValidSnac <= 1'b0;
		actionNextSnac <= 1'b0;
		//ackSnac <= 1'b0;
	end

	if (receiveValidSnac) begin
		if (byteCnt == 1) begin
			targetID <= transmitValueSnac;
		end
		if (byteCnt == 2) begin
			if (targetID == 8'h81 || targetID == 8'h82 || targetID == 8'h83 || targetID == 8'h84) begin 	//memcard quirks
				MCtransfer <= 1'b1;
				if (transmitValueSnac == 8'h52) bytesLeft <= 9'd137;//read
				if (transmitValueSnac == 8'h57) bytesLeft <= 9'd135;//write
				if (transmitValueSnac == 8'h53) bytesLeft <= 9'd7;//ID Cmd
				//pocketstation
				if (transmitValueSnac == 8'h50) bytesLeft <= 9'd0;//Change a FUNC 03h related value
				if (transmitValueSnac == 8'h58) bytesLeft <= 9'd2;//Get an ID or Version value
				if (transmitValueSnac == 8'h59) bytesLeft <= 9'd6;//Prepare File Execution with Dir_index, and Parameter
				if (transmitValueSnac == 8'h5A) bytesLeft <= 9'd18;//Get Dir_index, ComFlags, F_SN, Date, and Time
				if (transmitValueSnac == 8'h5D) bytesLeft <= 9'd3;//Execute Custom Download Notification
				if (transmitValueSnac == 8'h5E) bytesLeft <= 9'd3;//Get-and-Send ComFlags.bit1,3,2
				if (transmitValueSnac == 8'h5F) bytesLeft <= 9'd1;//Get-and-Send ComFlags.bit0
				if (transmitValueSnac == 8'h5B) begin//Execute Function and transfer data from Pocketstation to PSX--variable length
					bytesLeft <= 9'd3;
					PStransfer <= 1'b1;
				end
				if (transmitValueSnac == 8'h5C) begin//Execute Function and transfer data from PSX to Pocketstation--variable length
					bytesLeft <= 9'd3;
					PStransfer <= 1'b1;
				end
			end
			else begin //joypad quirks
				MCtransfer <= 1'b0;
				if (selectedPort1Snac) pad1ID <= Receive;
				if (selectedPort2Snac) pad2ID <= Receive;

				if (Receive == 8'h80) bytesLeft <= 9'd32; //for multitap
				else bytesLeft <= {5'd0, (Receive[3:0] + Receive[3:0])};
			end
		end
		if (byteCnt == 4 && PStransfer == 1) begin //for pocketstation
			bytesLeft <= bytesLeft + Receive;
			PSdatalength <=  Receive;
		end
		if ((byteCnt == PSdatalength + 5) && PStransfer == 1) begin
			bytesLeft <= bytesLeft + Receive;
			PStransfer <= 1'b0;
		end
	end
end

endmodule

// Capture ring for the MDIN ISSP (task #320) - same shape as ZN-2's qs_audcap.
module mdin_cap #(parameter AW = 11, parameter DW = 33) (
	input               clk,
	input               cen,       // 1-clk pulse per captured word
	input  [DW-1:0]     sample,
	input               arm,       // rising edge: start a fresh capture
	input  [AW-1:0]     rdaddr,
	output reg [DW-1:0] rddata = 0,
	output reg [AW-1:0] wptr_o = 0,
	output reg          full   = 0
);
	localparam DEPTH = (1 << AW);
	(* ramstyle = "M10K" *) reg [DW-1:0] mem [0:DEPTH-1];
	reg [AW-1:0] wptr  = 0;
	reg          armed = 1'b0;
	reg          arm_d = 1'b0;
	always @(posedge clk) begin
		arm_d  <= arm;
		rddata <= mem[rdaddr];
		wptr_o <= wptr;
		if (arm & ~arm_d) begin
			armed <= 1'b1; full <= 1'b0; wptr <= 0;
		end else if (armed & cen) begin
			mem[wptr] <= sample;
			if (wptr == DEPTH-1) begin armed <= 1'b0; full <= 1'b1; wptr <= 0; end
			else wptr <= wptr + 1'b1;
		end
	end
endmodule
