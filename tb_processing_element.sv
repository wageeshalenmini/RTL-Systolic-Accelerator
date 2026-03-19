`timescale 1ns/1ps

module tb_systolic_accelerator();

    localparam N = 2;
    logic clk, reset_n, en;
    logic [15:0] raw_row_in [N-1:0];
    logic [15:0] raw_col_in [N-1:0];
    logic [31:0] final_matrix [N-1:0][N-1:0];

    // Instantiate the Full Accelerator
    systolic_accelerator #(.N(N)) dut (.*);

    // Clock Generation (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // --- Initialization ---
        reset_n = 0; en = 0;
        raw_row_in[0] = 0; raw_row_in[1] = 0;
        raw_col_in[0] = 0; raw_col_in[1] = 0;
        
        #20 reset_n = 1;
        @(posedge clk); en = 1;

        // --- CYCLE 1: Feed a11 and b11 ---
        // Matrix A row 1 start: 1 | Matrix B col 1 start: 5
        raw_row_in[0] = 16'd1; raw_row_in[1] = 16'd3; // a11 and a21
        raw_col_in[0] = 16'd5; raw_col_in[1] = 16'd6; // b11 and b12
        @(posedge clk);

        // --- CYCLE 2: Feed a12, a21 and b12, b21 ---
        raw_row_in[0] = 16'd2; raw_row_in[1] = 16'd4; // a12 and a22
        raw_col_in[0] = 16'd7; raw_col_in[1] = 16'd8; // b21 and b22
        @(posedge clk);

        // --- CYCLE 3: Clear Inputs ---
        raw_row_in[0] = 0; raw_row_in[1] = 0;
        raw_col_in[0] = 0; raw_col_in[1] = 0;

        // --- WAIT FOR PROPAGATION ---
        // For N=2, it takes roughly 3N-2 cycles to finish
        repeat(5) @(posedge clk);

        // --- PRINT RESULTS TO TRANSCRIPT ---
        $display("\n========================================");
        $display("   FINAL SYSTEM MATRIX RESULT (2x2)");
        $display("========================================");
        $display("[%d]  [%d]", final_matrix[0][0], final_matrix[0][1]);
        $display("[%d]  [%d]", final_matrix[1][0], final_matrix[1][1]);
        $display("========================================\n");

        if (final_matrix[0][0] == 19 && final_matrix[1][1] == 50)
            $display("VERIFICATION: [SUCCESS]");
        else
            $display("VERIFICATION: [FAIL] Check your timing logic.");

        #20 $stop;
    end
endmodule