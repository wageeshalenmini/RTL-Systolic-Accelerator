module processing_element (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        clear,      // Synchronous clear for the accumulator
    input  logic        en,         // Enable signal to start/stop math
    input  logic [7:0]  data_in,    // From Left neighbor (INT8)
    input  logic [7:0]  weight_in,  // From Top neighbor  (INT8)
    
    output logic [7:0]  data_out,   // To Right neighbor
    output logic [7:0]  weight_out, // To Bottom neighbor
    output logic [19:0] acc_out     // The current running sum (20-bit)
);

    // Internal register for the running total
    logic [19:0] accumulator;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset everything to zero
            accumulator <= 20'h0;
            data_out    <= 8'h0;
            weight_out  <= 8'h0;
        end 
        else if (clear) begin
            accumulator <= 20'h0;
        end
        else if (en) begin
            // 1. PERFORM THE MATH: Multiply and Add to the bin
            accumulator <= accumulator + (data_in * weight_in);

            // 2. PASS THE DATA: Move inputs to outputs for the next PE
            // This creates the 1-cycle delay needed for the "flow"
            data_out    <= data_in;
            weight_out  <= weight_in;
        end
    end

    // Continuous assignment so the controller can always see the sum
    assign acc_out = accumulator;

endmodule