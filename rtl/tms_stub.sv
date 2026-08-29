// ---------------------------------------------------------------------------
// tms_stub.sv - TMS57002 host-interface stub for the Taito Zoom sound board
//
// Models exactly the part of MAME's tms57002_device that the MN10200 ROM can
// observe:  pload_w / cload_w (from port 1 bits 0/1, ACTIVE LOW), data_w byte
// assembly, and the 16-deep coefficient "update" FIFO whose empty flag drives
// MN10200 IRQ1 *inverted* (irq1 asserted while the FIFO is NOT empty).
//
// Mode (from port1):
//   bit0 = 0 -> IN_PLOAD active, bit1 = 0 -> IN_CLOAD active
//   P      : 3-byte groups (ST0, ST1, then microcode) - payload discarded
//   C      : first byte = sa, then 4-byte groups pushed into the update FIFO
//   P+C    : 4-byte groups -> coefficient RAM - payload discarded
//   none   : a write just resets the byte-assembly index
//
// The DSP consumes one FIFO entry per sample tick (get_cmem hits address sa
// once per microcode pass).  `sample_tick` is a 1-clk pulse at the ZSG-2/TMS
// stream rate, 25 MHz/768 = 32552.083 Hz (== 192 MN10200 cycles).
// data_r is never used by the ROM; it returns 0xFF.
// ---------------------------------------------------------------------------

module tms_stub (
    input  logic       clk,
    input  logic       rst,
    input  logic       ce,

    input  logic [7:0] ctrl,          // port 1 value (out | (dir ^ 0xff))
    input  logic       data_we,       // 1-clk strobe: host wrote the data port
    input  logic [7:0] data_in,

    input  logic       sample_tick,   // 1-clk pulse at 32552.083 Hz

    output logic       irq1,          // 1 == FIFO not empty  (-> MN10200 IRQ1)
    output logic [7:0] dbg_sa,
    output logic [4:0] dbg_level
);

    wire in_pload = ~ctrl[0];
    wire in_cload = ~ctrl[1];

    logic       pl_q, cl_q;
    logic [1:0] hidx;                 // byte assembly index (0..3)
    logic       su_cval;              // C mode: sa byte already taken
    logic [1:0] su_mask;              // 0 = ST0, 1 = ST1, 2 = PRG
    logic [7:0] sa;

    logic [3:0] head, tail;
    wire  [4:0] level = {1'b0, head} - {1'b0, tail};

    assign irq1      = (head != tail);
    assign dbg_sa    = sa;
    assign dbg_level = level;

    always_ff @(posedge clk) begin
        if (rst) begin
            pl_q <= 1'b0; cl_q <= 1'b0;
            hidx <= 2'd0; su_cval <= 1'b0; su_mask <= 2'd0; sa <= 8'h0;
            head <= 4'd0; tail <= 4'd0;
        end else if (ce) begin
            // ---- pload_w / cload_w edge behaviour ----
            pl_q <= in_pload;
            cl_q <= in_cload;
            if (in_pload && !pl_q) begin        // 0 -> 1 transition of IN_PLOAD
                hidx    <= 2'd0;
                su_mask <= 2'd0;                // SU_ST0
            end
            if (in_cload && !cl_q) begin
                hidx <= 2'd0;
            end

            // ---- data_w ----
            if (data_we) begin
                case ({in_pload, in_cload})
                2'b00: begin                    // no mode selected
                    hidx    <= 2'd0;
                    su_cval <= 1'b0;
                end
                2'b10: begin                    // P: 3-byte groups
                    if (hidx == 2'd2) begin
                        hidx <= 2'd0;
                        if (su_mask != 2'd2) su_mask <= su_mask + 2'd1;
                    end else
                        hidx <= hidx + 2'd1;
                end
                2'b01: begin                    // C: sa then 4-byte groups
                    if (su_cval) begin
                        if (hidx == 2'd3) begin
                            su_cval <= 1'b0;
                            head    <= head + 4'd1;
                            hidx    <= 2'd1;    // MAME sets hidx = 1 here
                        end else
                            hidx <= hidx + 2'd1;
                    end else begin
                        sa      <= data_in;
                        hidx    <= 2'd0;
                        su_cval <= 1'b1;
                    end
                end
                2'b11: begin                    // P+C: 4-byte coefficient groups
                    hidx <= hidx + 2'd1;        // wraps at 4 -> matches hidx=0
                end
                endcase
            end

            // ---- DSP consumes one update per sample pass ----
            if (sample_tick && (head != tail))
                tail <= tail + 4'd1;
        end
    end
endmodule
