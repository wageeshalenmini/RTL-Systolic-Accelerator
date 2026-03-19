`timescale 1ns/1ps

module tb_systolic_accelerator();

    localparam N = 4;
    logic clk, reset_n;
    logic start, busy, done;
    logic [7:0]  raw_row_in [N-1:0];
    logic [7:0]  raw_col_in [N-1:0];
    logic [19:0] final_matrix [N-1:0][N-1:0];

    // --- GOLDEN DATA STORAGE ---
    logic [19:0] expected_matrix [0:(N*N)-1];
    int error_count = 0;

    // Define Input Matrices (use ascending range [0:N-1] so the initializer
    // maps the first element to index 0, matching the natural row/column order)
    logic [7:0] mat_A [0:N-1][0:N-1] = '{ '{1,2,3,4}, '{5,6,7,8}, '{9,10,11,12}, '{13,14,15,16} };
    logic [7:0] mat_B [0:N-1][0:N-1] = '{ '{1,2,3,4}, '{5,6,7,8}, '{9,10,11,12}, '{13,14,15,16} };

    systolic_accelerator #(.N(N)) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // 1. Load the Python-generated file
        $readmemh("golden_results.hex", expected_matrix);

        // Reset
        reset_n = 0; start = 0;
        foreach (raw_row_in[i]) begin raw_row_in[i] = 0; raw_col_in[i] = 0; end
        #20 reset_n = 1;

        // Pulse 'start' to kick off the FSM
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // 2. Feed Data while the FSM is in COMPUTE state (busy=1)
        for (int cycle = 0; cycle < N; cycle++) begin
            for (int i = 0; i < N; i++) begin
                raw_row_in[i] = mat_A[i][cycle]; 
                raw_col_in[i] = mat_B[cycle][i]; 
            end
            @(posedge clk);
        end

        // 3. Zero out inputs and wait for the FSM to signal 'done'
        foreach (raw_row_in[i]) begin raw_row_in[i] = 0; raw_col_in[i] = 0; end
        wait (done == 1);
        @(posedge clk);

        // 4. THE COMPARISON LOOP
        $display("\n==================================================");
        $display("   VERIFYING HARDWARE VS. PYTHON GOLDEN MODEL");
        $display("==================================================");
        
        for (int r = 0; r < N; r++) begin
            for (int c = 0; c < N; c++) begin
                if (final_matrix[r][c] !== expected_matrix[r*N + c]) begin
                    $display("[ERROR] Cell [%0d][%0d] Mismatch! HW: %10d, Python: %10d", 
                              r, c, final_matrix[r][c], expected_matrix[r*N + c]);
                    error_count++;
                end else begin
                    $display("[MATCH] Cell [%0d][%0d]: %d", r, c, final_matrix[r][c]);
                end
            end
        end

        $display("==================================================");
        if (error_count == 0)
            $display("   FINAL VERIFICATION: [SUCCESS] 100%% MATCH!");
        else
            $display("   FINAL VERIFICATION: [FAIL] %0d errors found.", error_count);
        $display("==================================================\n");

        #50 $stop;
    end
endmodule