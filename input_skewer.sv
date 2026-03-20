module input_skewer #(parameter N = 4) (
    input  logic       clk,
    input  logic       reset_n,
    input  logic [7:0] data_in [N-1:0],
    output logic [7:0] data_out [N-1:0]
);

    // We need a 2D array of registers to act as the delay chain
    // Row 'i' needs 'i' stages of delay
    logic [7:0] delay_chain [N-1:0][N-1:0];

    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : row_delay
            if (i == 0) begin
                // Row 0 has 0 delay
                assign data_out[i] = data_in[i];
            end else begin
                // Row 'i' passes through 'i' flip-flops
                always_ff @(posedge clk or negedge reset_n) begin
                    if (!reset_n) begin
                        for (int k = 0; k < i; k++) delay_chain[i][k] <= 16'h0;
                    end else begin
                        delay_chain[i][0] <= data_in[i];
                        for (int k = 1; k < i; k++) begin
                            delay_chain[i][k] <= delay_chain[i][k-1];
                        end
                    end
                end
                assign data_out[i] = delay_chain[i][i-1];
            end
        end
    endgenerate

endmodule