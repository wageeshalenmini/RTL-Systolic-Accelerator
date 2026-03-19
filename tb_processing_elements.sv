`timescale 1ns/1ps

module tb_processing_element();

    // 1. Declare signals to connect to the PE
    logic        clk;
    logic        reset_n;
    logic        en;
    logic [15:0] data_in;
    logic [15:0] weight_in;
    
    logic [15:0] data_out;
    logic [15:0] weight_out;
    logic [31:0] acc_out;

    // 2. Instantiate the module (The "Unit Under Test")
    processing_element dut (
        .clk(clk),
        .reset_n(reset_n),
        .en(en),
        .data_in(data_in),
        .weight_in(weight_in),
        .data_out(data_out),
        .weight_out(weight_out),
        .acc_out(acc_out)
    );

    // 3. Generate the Clock (10ns period = 100MHz)
    always #5 clk = ~clk;

    // 4. The Testing Sequence
    initial begin
        // Initialize signals
        clk = 0;
        reset_n = 0;
        en = 0;
        data_in = 0;
        weight_in = 0;

        // Release Reset after 20ns
        #20 reset_n = 1;
        #10 en = 1;

        // --- TEST CASE 1 ---
        // Input: 2, Weight: 5 -> Expected Acc: 10
        data_in = 16'd2; weight_in = 16'd5;
        #10; // Wait for one clock edge
        
        // --- TEST CASE 2 ---
        // Input: 3, Weight: 4 -> Expected Acc: 10 + (3*4) = 22
        // Also check if data_out is now 2 (from previous cycle)
        data_in = 16'd3; weight_in = 16'd4;
        #10;

        // 5. AUTOMATED CHECK
        if (acc_out == 32'd22 && data_out == 16'd2) begin
            $display("SUCCESS: Logic is correct!");
        end else begin
            $display("ERROR: Expected 22, but got %d", acc_out);
        end

        #50 $stop; // Pause the simulation so you can look at the waves
    end

endmodule