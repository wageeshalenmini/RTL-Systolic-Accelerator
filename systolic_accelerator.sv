module systolic_accelerator #(parameter N = 4) (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        start,          // Pulse to begin multiplication

    // External "Raw" Inputs (from Memory or Testbench)
    input  logic [7:0]  raw_row_in [N-1:0],
    input  logic [7:0]  raw_col_in [N-1:0],

    // Status Outputs
    output logic        busy,           // High while computing
    output logic        done,           // Single pulse when matrix is ready

    // Final Results from all Accumulators
    output logic [19:0] final_matrix [N-1:0][N-1:0]
);

    // =========================================================
    //  FSM Controller
    // =========================================================
    typedef enum logic [1:0] {IDLE, COMPUTE, DONE_STATE} state_t;
    state_t state, next_state;

    // Internal enable for the Array/PEs
    logic acc_en;

    // Counter to track the 3N-2 latency
    logic [7:0] cycle_count;
    localparam TOTAL_CYCLES = 3*N - 2;

    // State Transition Logic
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            cycle_count <= 0;
        end else begin
            state <= next_state;
            if (state == COMPUTE)
                cycle_count <= cycle_count + 1;
            else
                cycle_count <= 0;
        end
    end

    // Next State & Output Logic
    always_comb begin
        next_state = state;
        acc_en = 0;
        busy = 0;
        done = 0;

        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE;
            end

            COMPUTE: begin
                acc_en = 1;
                busy = 1;
                if (cycle_count == TOTAL_CYCLES) next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1;
                next_state = IDLE;
            end
        endcase
    end

    // =========================================================
    //  Datapath: Input Skewers + Systolic Array
    // =========================================================

    // Internal wires to hold the "Staggered" data
    logic [7:0] skewed_rows [N-1:0];
    logic [7:0] skewed_cols [N-1:0];

    // 1. Instance of the Input Skewer for Rows (Left side)
    input_skewer #(.N(N)) row_skewer_inst (
        .clk(clk),
        .reset_n(reset_n),
        .data_in(raw_row_in),
        .data_out(skewed_rows)
    );

    // 2. Instance of the Input Skewer for Columns (Top side)
    input_skewer #(.N(N)) col_skewer_inst (
        .clk(clk),
        .reset_n(reset_n),
        .data_in(raw_col_in),
        .data_out(skewed_cols)
    );

    // 3. Instance of the Actual Computing Mesh
    systolic_array #(.N(N)) mesh_inst (
        .clk(clk),
        .reset_n(reset_n),
        .en(acc_en),              // Gated by the FSM
        .row_in(skewed_rows),
        .col_in(skewed_cols),
        .final_out(final_matrix)
    );

endmodule