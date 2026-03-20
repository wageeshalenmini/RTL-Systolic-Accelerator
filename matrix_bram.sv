// ============================================================
// Module: matrix_bram
// Description: Simple Dual-Port BRAM for storing matrix data.
//   - Port A: Write-only (for loading data from testbench/CPU)
//   - Port B: Read-only  (for feeding systolic array / reading results)
//   - Infers BRAM on FPGA synthesis tools (Xilinx/Intel)
// ============================================================
module matrix_bram #(
    parameter DATA_WIDTH = 8,       // 8 for A/B matrices, 20 for C matrix
    parameter ADDR_WIDTH = 10       // Supports up to 2^10 = 1024 entries
)(
    input  logic                    clk,

    // --- Port A: Write Port ---
    input  logic                    wr_en,
    input  logic [ADDR_WIDTH-1:0]   wr_addr,
    input  logic [DATA_WIDTH-1:0]   wr_data,

    // --- Port B: Read Port ---
    input  logic [ADDR_WIDTH-1:0]   rd_addr,
    output logic [DATA_WIDTH-1:0]   rd_data
);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    // Port A: Synchronous Write
    always_ff @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    // Port B: Synchronous Read (1-cycle read latency)
    always_ff @(posedge clk) begin
        rd_data <= mem[rd_addr];
    end

endmodule
