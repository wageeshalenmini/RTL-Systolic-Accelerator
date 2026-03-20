`timescale 1ns/1ps

module tb_systolic_accelerator();

    localparam N = 4;
    localparam ADDR_WIDTH = 10;
    
    // Matrix Dimensions for test (must match python script)
    localparam M_dim = 8;
    localparam K_dim = 8;
    localparam P_dim = 8;

    logic clk, reset_n;
    logic start, busy, done;
    
    logic [7:0] dim_M, dim_K, dim_P;
    
    // Testbench BRAM interface (we'll hack into the module's BRAMs for loading)
    logic                  tb_a_wr_en, tb_b_wr_en;
    logic [ADDR_WIDTH-1:0] tb_a_wr_addr, tb_b_wr_addr;
    logic [7:0]            tb_a_wr_data, tb_b_wr_data;
    
    // For verifying results
    logic [19:0] expected_matrix [0:(M_dim*P_dim)-1];
    int error_count = 0;

    // Instantiate the Top-Level Accelerator
    systolic_accelerator #(.N(N), .ADDR_WIDTH(ADDR_WIDTH)) dut (
        .clk(clk), .reset_n(reset_n), .start(start),
        .dim_M(dim_M), .dim_K(dim_K), .dim_P(dim_P),
        .busy(busy), .done(done)
    );

    // Override the 0-tied write ports in the DUT using hierarchical paths
    // This allows the testbench to load the BRAMs directly
    assign dut.a_wr_en   = tb_a_wr_en;
    assign dut.a_wr_addr = tb_a_wr_addr;
    assign dut.a_wr_data = tb_a_wr_data;
    
    assign dut.b_wr_en   = tb_b_wr_en;
    assign dut.b_wr_addr = tb_b_wr_addr;
    assign dut.b_wr_data = tb_b_wr_data;

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test Sequence
    initial begin
        // Reset signals
        reset_n = 0; start = 0;
        tb_a_wr_en = 0; tb_b_wr_en = 0;
        tb_a_wr_addr = 0; tb_b_wr_addr = 0;
        tb_a_wr_data = 0; tb_b_wr_data = 0;
        dim_M = M_dim; dim_K = K_dim; dim_P = P_dim;
        
        // 1. Load Golden Results
        $readmemh("golden_c.hex", expected_matrix);

        #20 reset_n = 1;

        // 2. Load Matrices A and B into BRAMs
        $display("Loading Matrices into BRAM...");
        // Use a temporary array to read the hex files
        begin
            logic [7:0] load_A [0:(M_dim*K_dim)-1];
            logic [7:0] load_B [0:(K_dim*P_dim)-1];
            $readmemh("matrix_a.hex", load_A);
            $readmemh("matrix_b.hex", load_B);
            
            @(posedge clk);
            for (int i = 0; i < (M_dim*K_dim); i++) begin
                tb_a_wr_en   = 1;
                tb_a_wr_addr = i;
                tb_a_wr_data = load_A[i];
                @(posedge clk);
            end
            tb_a_wr_en = 0;
            
            for (int i = 0; i < (K_dim*P_dim); i++) begin
                tb_b_wr_en   = 1;
                tb_b_wr_addr = i;
                tb_b_wr_data = load_B[i];
                @(posedge clk);
            end
            tb_b_wr_en = 0;
        end

        // 3. Start Accelerator
        $display("Starting Tiled Matrix Multiplication (8x8)...");
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // 4. Wait for Completion
        wait (done == 1);
        @(posedge clk);
        $display("Matrix Multiplication Complete!");

        // 5. Verify Results directly from C_BRAM
        $display("\n==================================================");
        $display("   VERIFYING HARDWARE VS. PYTHON GOLDEN MODEL");
        $display("==================================================");
        
        begin
            int addr;
            logic [19:0] hw_val;
            logic [19:0] py_val;
            for (int i = 0; i < M_dim; i++) begin
                for (int j = 0; j < P_dim; j++) begin
                    addr = i * P_dim + j;
                    // Read from C BRAM directly using hierarchical path
                    hw_val = dut.bram_C.mem[addr];
                    py_val = expected_matrix[addr];
                
                if (hw_val !== py_val) begin
                    $display("[ERROR] Cell [%0d][%0d] Mismatch! HW: %10d, Python: %10d", 
                              i, j, hw_val, py_val);
                    error_count++;
                end else begin
                    $display("[MATCH] Cell [%0d][%0d]: %d", i, j, hw_val);
                end
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