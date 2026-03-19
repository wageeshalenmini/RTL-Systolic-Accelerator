module systolic_array #(parameter N = 4) (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        en,
    input  logic [7:0]  row_in   [N-1:0],
    input  logic [7:0]  col_in   [N-1:0],
    output logic [19:0] final_out [N-1:0][N-1:0]
);
    // Internal wires for horizontal and vertical data flow
    // h_wire[row][column_boundary]
    logic [7:0] h_wire [N-1:0][N:0];
    // v_wire[row_boundary][column]
    logic [7:0] v_wire [N:0][N-1:0];

    // Connect boundary inputs to the first wires of the mesh
    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : boundary_connect
            assign h_wire[i][0] = row_in[i];
            assign v_wire[0][i] = col_in[i];
        end

        // Mesh Generation: Connecting PEs in a Grid
        for (i = 0; i < N; i++) begin : row_gen
            for (j = 0; j < N; j++) begin : col_gen
                processing_element pe (
                    .clk(clk),
                    .reset_n(reset_n),
                    .en(en),
                    .data_in(h_wire[i][j]),       // Data from left
                    .weight_in(v_wire[i][j]),     // Weight from top
                    .data_out(h_wire[i][j+1]),    // Pass data to right
                    .weight_out(v_wire[i+1][j]),  // Pass weight to bottom
                    
                    // Directly map the PE's internal accumulator 
                    // to the corresponding matrix result index
                    .acc_out(final_out[i][j]) 
                );
            end
        end
    endgenerate
endmodule