//==============================================================================
// pause_overlay.v
//
// Pause-overlay module for the ZN-1 MiSTer core.
//
// When `enable` is high, replaces the input video with:
//   - vertically scrolling Patreon credits text rendered with an 8x16 font,
//     on a black background
//
// Both remaining asset ROMs (text grid / font) are initialized from .mif files
// in rtl/pause_assets/ at synthesis time.
//
// Output color priority: text pixel > black background.
//
// 2026-08-09 (Stage B4): the 512x256 XN LOGO IMAGE ROM and its 256-entry RGB
// palette ROM were DELETED.  logo_rom was 131072x8 = 128 M10K (plus 1 for the
// palette) - 23% of the device's entire block-RAM budget spent on a cosmetic
// still image - and the TMS57002 effects DSP's 64 KB delay line needs 64 of
// them to live on-chip instead of behind a DDR3 cache.  Everything else about
// the overlay is untouched: enable/rotate/vertical plumbing, the frame-size
// auto-detection, the scroll counter and its restart-on-pause behaviour, and
// the passthrough path when `enable` is low.  The screen now shows the
// scrolling credits on black.
//==============================================================================

module pause_overlay (
    input  wire        clk,
    input  wire        ce_pix,        // pulse high once per output pixel
    input  wire        hblank,
    input  wire        vblank,
    input  wire        enable,        // 1 = show overlay, 0 = passthrough
    input  wire        rotate180,     // screen-flip toggle (game rotate180 / OSD Rotate)
    input  wire        vertical,      // 1 = TATE/vertical title: rotate overlay 90°

    input  wire  [7:0] vid_r_in,
    input  wire  [7:0] vid_g_in,
    input  wire  [7:0] vid_b_in,

    output reg   [7:0] vid_r_out,
    output reg   [7:0] vid_g_out,
    output reg   [7:0] vid_b_out
);

   // ----- Asset sizes -----
   localparam [11:0] TEXT_WIDTH   = 12'd320;   // 40 cols × 8 px = 320 px text band (1× scale)
   localparam [11:0] TEXT_HEIGHT  = 12'd2048;  // 128 lines × 16 px (38 used by pause.txt)

   // Auto-centering: track frame-by-frame display width/height. Latch the last
   // visible pixel index on each scanline (= width-1) and the last visible
   // line index in the frame (= height-1). The text band position derives
   // from these so the overlay self-centers for any game resolution.
   reg [11:0] disp_w = 12'd512;
   reg [11:0] disp_h = 12'd480;
   reg [11:0] frame_w_max = 0;
   reg [11:0] frame_h_max = 0;

   // ----- Logical canvas: swap axes for 90°/270° (vertical/TATE titles) -----
   // The overlay is authored for a landscape canvas (a scrolling text band).
   // For vertical titles the composited frame is scanned out sideways, so
   // we draw the overlay into a TRANSPOSED logical canvas (Lw×Lh = disp_h×disp_w)
   // and map each output pixel (px,py) through a rotation into logical (lx,ly).
   // All positioning below is done in logical space, so the overlay — glyphs and
   // scroll — comes out rotated to read in the game's orientation.
   //   vertical=0,flip=0 → 0°    vertical=0,flip=1 → 180°
   //   vertical=1,flip=0 → 90°   vertical=1,flip=1 → 270°
   wire [11:0] Lw = vertical ? disp_h : disp_w;   // logical canvas width
   wire [11:0] Lh = vertical ? disp_w : disp_h;   // logical canvas height

   // Text band is centred along its short axis (the 256-px reading width) and
   // spans the long axis as a scrolling marquee. When the canvas is narrower
   // than the band, centre the visible slice with a symmetric source offset.
   wire [11:0] TEXT_X_START = (Lw > TEXT_WIDTH) ? ((Lw - TEXT_WIDTH) >> 1) : 12'd0;
   wire [11:0] TEXT_SRCX    = (Lw < TEXT_WIDTH) ? ((TEXT_WIDTH - Lw) >> 1) : 12'd0;
   wire [11:0] TEXT_Y_START = 12'd0;
   wire [11:0] TEXT_Y_END   = Lh;

   // ----- Pixel counters from blank signals + per-frame size detection -----
   reg [11:0] px = 0, py = 0;
   reg        hblank_d = 0, vblank_d = 0;

   always @(posedge clk) begin
      if (ce_pix) begin
         hblank_d <= hblank;
         vblank_d <= vblank;

         if (hblank) begin
            // Entering hblank: latch line width (px now holds count of visible pixels)
            if (~hblank_d) begin
               if (px > frame_w_max) frame_w_max <= px;
            end
            px <= 0;
         end else begin
            px <= px + 1'd1;
         end

         if (hblank_d & ~hblank) begin
            py <= py + 1'd1;
            if (py > frame_h_max) frame_h_max <= py;
         end

         if (~vblank_d & vblank) begin
            // Entering vblank: latch detected dimensions for next frame use
            if (frame_w_max > 12'd64) disp_w <= frame_w_max;
            if (frame_h_max > 12'd64) disp_h <= frame_h_max;
            frame_w_max <= 0;
            frame_h_max <= 0;
            py <= 0;
         end
      end
   end

   // ----- Scroll counter: advances once per VBLANK -----
   // Text grid holds 67 pause.txt lines (of 128 ROM lines) × 16 px. Wrap after
   // the used lines plus an 8-line blank gap so the loop restarts cleanly.
   reg [10:0] scroll = 0;
   reg        vbl_d2 = 0;
   reg        enable_d = 0;
   // pause.txt holds 38 content lines (rows 0..37 of the text ROM). Loop over
   // those + a 4-line gap = 42 lines. The wrap MUST match the real content
   // height, else blank lines crawl past between cycles. Combined with the
   // mod-LOOP tiling of text_line below, the credits scroll continuously —
   // content is always on screen, so there is no blank stall at wrap.
   // (Set from pause_src/gen_pause_assets.py's reported line count + gap.)
   localparam [6:0]  TEXT_LOOP   = 7'd42;       // 38 content + 4-line gap
   localparam [10:0] SCROLL_WRAP = 11'd672;     // TEXT_LOOP × 16 px

   always @(posedge clk) begin
      if (ce_pix) begin
         vbl_d2   <= vblank_d;
         enable_d <= enable;
         if (~enable_d & enable) begin
            // Pause just pressed: restart the credits from the top immediately,
            // instead of catching the free-running marquee at a random position.
            scroll <= 11'd0;
         end else if (enable & ~vbl_d2 & vblank_d) begin
            // Advance once per frame, only while paused (no free-run drift).
            scroll <= (scroll == SCROLL_WRAP - 1) ? 11'd0 : scroll + 1'd1;
         end
      end
   end

   // ----- Output-pixel → logical-canvas rotation (0/90/180/270) -----
   // rpx,rpy are the logical coordinates the positioning logic below uses.
   //   {vertical,flip}=00 → 0°   : (px, py)
   //                   01 → 180° : reflect both axes
   //                   10 → 90°  : transpose (lx=py)
   //                   11 → 270° : transpose the other way
   // With vertical=0 this collapses to the upright/180 path (bit-identical to the
   // horizontal behaviour); direction of the 90/270 pair is chosen by the flip
   // toggle, exactly as a vertical title's own rotate180 selects its up/down.
   // TIMING: this rotation stage was once the critical path on clk_vid, through
   // the (now deleted) 17-bit logo_addr into logo_rom's M10K block-enable decode.
   // The two register cuts it needed are KEPT - they are free and the text path
   // depends on them being mutually consistent:
   //   1. disp_*_m1 registered - disp_w/disp_h only change at frame boundaries, so
   //      this is constant during active video and costs nothing.
   //   2. rpx/rpy registered - shifts overlay CONTENT one pixel. Invisible: the
   //      text/font ROM chain already runs 2 cycles behind the pixel it lands on,
   //      and in_text derives from the same registers so the band and its data
   //      stay mutually aligned. Registered under ce_pix to track px/py exactly.
   reg [11:0] disp_w_m1 = 0, disp_h_m1 = 0;
   always @(posedge clk) begin
      disp_w_m1 <= (disp_w != 0) ? (disp_w - 12'd1) : 12'd0;
      disp_h_m1 <= (disp_h != 0) ? (disp_h - 12'd1) : 12'd0;
   end

   reg  [11:0] rpx = 0, rpy = 0;
   reg  [11:0] rpx_c, rpy_c;
   always @* begin
      case ({vertical, rotate180})
         2'b00: begin rpx_c = px;              rpy_c = py;              end // 0°
         2'b01: begin rpx_c = disp_w_m1 - px;  rpy_c = disp_h_m1 - py;  end // 180°
         2'b10: begin rpx_c = py;              rpy_c = disp_w_m1 - px;  end // 90°
         default: begin rpx_c = disp_h_m1 - py; rpy_c = px;            end // 270°
      endcase
   end
   always @(posedge clk) begin
      if (ce_pix) begin
         rpx <= rpx_c;
         rpy <= rpy_c;
      end
   end

   // ===========================================================================
   // (Stage B4) ROM 1 "logo image" and ROM 2 "palette" DELETED - see the file
   // header.  129 M10K reclaimed for the TMS57002 delay RAM.  Nothing replaces
   // them: the background is the same black the old logo sat on, produced by the
   // existing `else` arm of the output mux, so there is no undefined pixel data
   // and no new logic.  The frame-size auto-detection, the rotation stage and
   // the two register cuts above are all still needed by the text band and are
   // unchanged.
   // ===========================================================================

   // ===========================================================================
   // Text scroller — 2D grid: 128 lines × 40 cols, address = line*40 + col
   // ===========================================================================
   wire in_text_x = (rpx >= TEXT_X_START) && (rpx < TEXT_X_START + TEXT_WIDTH);
   wire in_text_y = (rpy >= TEXT_Y_START) && (rpy < TEXT_Y_END);
   wire in_text   = in_text_x & in_text_y;

   wire [11:0] text_x_off = (rpx - TEXT_X_START) + TEXT_SRCX;
   wire [11:0] text_y_raw = (rpy - TEXT_Y_START) + {1'b0, scroll};

   // Each text line is 16 px tall. Tile the visible line index modulo TEXT_LOOP
   // so the credits wrap around seamlessly: as the top of the text scrolls off,
   // the first line reappears at the bottom of the same window (no blank stall).
   // text_line_raw = (scroll + py)>>4 can reach ~(351+disp_h)/16; for disp_h up
   // to ~1000 that is < 4*TEXT_LOOP, so three conditional subtracts reduce it
   // into [0, TEXT_LOOP) without an (expensive) hardware divider.
   wire  [6:0] text_line_raw = text_y_raw[10:4];
   wire  [6:0] tl_r1      = (text_line_raw >= TEXT_LOOP) ? (text_line_raw - TEXT_LOOP) : text_line_raw;
   wire  [6:0] tl_r2      = (tl_r1        >= TEXT_LOOP) ? (tl_r1        - TEXT_LOOP) : tl_r1;
   wire  [6:0] text_line  = (tl_r2        >= TEXT_LOOP) ? (tl_r2        - TEXT_LOOP) : tl_r2;
   wire  [3:0] text_yoff  = text_y_raw[3:0];   // row within the line (0..15)

   // 1× horizontal: each font pixel = one output pixel (8 px wide chars)
   wire  [5:0] text_col   = text_x_off[8:3];   // col within the line (0..39)
   wire  [2:0] text_xoff  = text_x_off[2:0];   // pixel within the char (0..7)

   // ===========================================================================
   // ROM 3: Text grid (128 × 40 = 5120 bytes). Width is 40 (not a power of two),
   // so the address is line*40 + col rather than a bit-concatenation.
   // ===========================================================================
   wire [7:0]  text_char;
   wire [12:0] text_addr = (text_line * 7'd40) + text_col;   // 128*40 = 5120 < 8192

   altsyncram #(
      .operation_mode("ROM"),
      .width_a(8),
      .widthad_a(13),
      .numwords_a(5120),
      .outdata_reg_a("UNREGISTERED"),
      .ram_block_type("M10K"),
      .init_file("patreon_text.mif"),
      .lpm_type("altsyncram")
   ) text_rom (
      .clock0(clk),
      .address_a(text_addr),
      .q_a(text_char)
   );

   // ===========================================================================
   // ROM 3b: per-line credits colour index (one byte per text line, 128 lines).
   // Generated alongside patreon_text.mif by gen_pause_assets.py so the tier
   // colours track pause.txt. The index is line-constant across a scanline, so
   // the horizontal ROM-latency skew of the text/font path does not affect it;
   // one register keeps the ROM->decode->mux path short at high fitter density.
   // ===========================================================================
   wire [7:0] line_colour_idx;
   altsyncram #(
      .operation_mode("ROM"),
      .width_a(8),
      .widthad_a(7),
      .numwords_a(128),
      .outdata_reg_a("UNREGISTERED"),
      .ram_block_type("M10K"),
      .init_file("patreon_color.mif"),
      .lpm_type("altsyncram")
   ) colour_rom (
      .clock0(clk),
      .address_a(text_line),
      .q_a(line_colour_idx)
   );

   // Decode tier index -> RGB (kept in sync with gen_pause_assets.py):
   //   0 white(names/body) 1 amber(banners) 2 gold(Hall of Fame)
   //   3 cyan(High Score)  4 green(Insert Coin)
   reg [7:0] colour_idx_q;
   always @(posedge clk) if (ce_pix) colour_idx_q <= line_colour_idx;

   reg [23:0] text_rgb;
   always @(*) begin
      case (colour_idx_q[2:0])
         3'd1:    text_rgb = 24'hFF_B0_30;   // amber - "--- ... ---" banners
         3'd2:    text_rgb = 24'hFF_D7_00;   // gold  - Hall of Fame
         3'd3:    text_rgb = 24'h40_E0_FF;   // cyan  - High Score
         3'd4:    text_rgb = 24'h50_E0_50;   // green - Insert Coin
         default: text_rgb = 24'hFF_FF_FF;   // white - names / body
      endcase
   end

   // ===========================================================================
   // ROM 4: Font 8x16 (96 printable chars × 16 bytes)
   // ===========================================================================
   wire  [7:0] disp_char = (text_char >= 8'h20 && text_char <= 8'h7E) ? text_char : 8'h20;
   wire [10:0] font_addr = {disp_char[6:0] - 7'd32, text_yoff};
   wire  [7:0] font_row_bits;

   altsyncram #(
      .operation_mode("ROM"),
      .width_a(8),
      .widthad_a(11),
      .numwords_a(1536),
      .outdata_reg_a("UNREGISTERED"),
      .ram_block_type("M10K"),
      .init_file("font_8x16.mif"),
      .lpm_type("altsyncram")
   ) font_rom (
      .clock0(clk),
      .address_a(font_addr),
      .q_a(font_row_bits)
   );

   // Pick out the bit corresponding to text_xoff (MSB = leftmost pixel).
   wire text_pixel = in_text & font_row_bits[7 - text_xoff];

   // ===========================================================================
   // Final output mux — gated by ce_pix to match the video pipeline
   // ===========================================================================
   always @(posedge clk) begin
      if (ce_pix) begin
         if (enable) begin
            if (text_pixel) begin
               vid_r_out <= text_rgb[23:16];   // per-tier colour (white for names/body)
               vid_g_out <= text_rgb[15:8];
               vid_b_out <= text_rgb[7:0];
            end else begin
               vid_r_out <= 8'h00;
               vid_g_out <= 8'h00;
               vid_b_out <= 8'h00;
            end
         end else begin
            vid_r_out <= vid_r_in;
            vid_g_out <= vid_g_in;
            vid_b_out <= vid_b_in;
         end
      end
   end

endmodule
