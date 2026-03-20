// ============================================================
// Module: tile_feeder
// Description: Loads N×N tiles from A and B BRAMs into local
//   register files, then feeds them to the systolic array
//   one column-of-A / row-of-B per cycle for N cycles.
//
//   Operation (2 phases):
//     Phase 1 - LOAD:  Read N*N elements from each BRAM into
//                      local tile buffers (N*N + 1 cycles due
//                      to BRAM's 1-cycle read latency).
//     Phase 2 - FEED:  Output N values per cycle for N cycles.
//
//   Memory layout (row-major):
//     A[i][j] stored at address: i * dim_K + j
//     B[i][j] stored at address: i * dim_P + j
// ============================================================
module tile_feeder #(
    parameter N          = 4,
    parameter ADDR_WIDTH = 10
)(
    input  logic                    clk,
    input  logic                    reset_n,

    // --- Control from Tiling Controller ---
    input  logic                    start_load,   // Pulse: begin loading tile from BRAM
    input  logic                    start_feed,   // Pulse: begin feeding systolic array

    // --- Tile Coordinates ---
    input  logic [7:0]              tile_row,     // Tile row index    (i-th block row)
    input  logic [7:0]              tile_col,     // Tile column index (j-th block col)
    input  logic [7:0]              tile_k,       // K-dimension tile index

    // --- Matrix Dimensions ---
    input  logic [7:0]              dim_K,        // Columns of A (= rows of B)
    input  logic [7:0]              dim_P,        // Columns of B

    // --- BRAM Read Interface for A ---
    output logic [ADDR_WIDTH-1:0]   a_rd_addr,
    input  logic [7:0]              a_rd_data,

    // --- BRAM Read Interface for B ---
    output logic [ADDR_WIDTH-1:0]   b_rd_addr,
    input  logic [7:0]              b_rd_data,

    // --- Output to Systolic Array ---
    output logic [7:0]              row_out [N-1:0],   // Fed to raw_row_in
    output logic [7:0]              col_out [N-1:0],   // Fed to raw_col_in

    // --- Status ---
    output logic                    load_done,
    output logic                    feed_done
);

    // =========================================================
    //  Local Tile Buffers (N×N register files)
    // =========================================================
    logic [7:0] tile_A [0:N-1][0:N-1];   // Buffered tile of matrix A
    logic [7:0] tile_B [0:N-1][0:N-1];   // Buffered tile of matrix B

    // =========================================================
    //  FSM
    // =========================================================
    typedef enum logic [2:0] {
        IDLE,
        LOADING,
        LOAD_WAIT,       // Extra cycle for last BRAM read latency
        LOAD_COMPLETE,
        FEEDING,
        FEED_COMPLETE
    } state_t;

    state_t state;

    // Counter for load phase (0 to N*N-1)
    logic [7:0] load_cnt;

    // Counter for feed phase (0 to N-1)
    logic [7:0] feed_cnt;

    // Row/col indices derived from load counter
    logic [7:0] ld_row, ld_col;
    assign ld_row = load_cnt / N;    // Which row within the tile
    assign ld_col = load_cnt % N;    // Which col within the tile

    // Pipeline register: matching BRAM latency for capturing data
    logic [7:0] ld_row_d1, ld_col_d1;
    logic [7:0] ld_row_d2, ld_col_d2;
    logic       capture_valid_d1, capture_valid_d2;

    // =========================================================
    //  BRAM Address Generation
    // =========================================================
    // A is stored row-major: A[i][j] at addr = i * dim_K + j
    // For tile(tile_row, tile_k): global row = tile_row*N + ld_row
    //                             global col = tile_k*N   + ld_col
    wire [ADDR_WIDTH-1:0] a_addr_calc = (tile_row * N + ld_row) * dim_K + (tile_k * N + ld_col);

    // B is stored row-major: B[i][j] at addr = i * dim_P + j
    // For tile(tile_k, tile_col): global row = tile_k*N   + ld_row
    //                             global col = tile_col*N + ld_col
    wire [ADDR_WIDTH-1:0] b_addr_calc = (tile_k * N + ld_row) * dim_P + (tile_col * N + ld_col);

    // =========================================================
    //  Main FSM
    // =========================================================
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state            <= IDLE;
            load_cnt         <= 0;
            feed_cnt         <= 0;
            load_done        <= 0;
            feed_done        <= 0;
            capture_valid_d1 <= 0;
            capture_valid_d2 <= 0;
            ld_row_d1        <= 0;
            ld_col_d1        <= 0;
            ld_row_d2        <= 0;
            ld_col_d2        <= 0;
            a_rd_addr        <= '0;
            b_rd_addr        <= '0;
        end else begin
            // Default: clear single-cycle pulses
            load_done <= 0;
            feed_done <= 0;

            case (state)
                // -----------------------------------------
                IDLE: begin
                    if (start_load) begin
                        state            <= LOADING;
                        load_cnt         <= 0;
                        capture_valid_d1 <= 0;
                        capture_valid_d2 <= 0;
                    end
                    if (start_feed) begin
                        state    <= FEEDING;
                        feed_cnt <= 0;
                    end
                end

                // -----------------------------------------
                // LOADING: Issue BRAM addresses and capture
                //   data two cycles later (pipeline)
                // -----------------------------------------
                LOADING: begin
                    // Stage 0: Issue address for current element
                    a_rd_addr <= a_addr_calc;
                    b_rd_addr <= b_addr_calc;

                    // Stage 1: Pipeline Wait
                    ld_row_d1        <= ld_row;
                    ld_col_d1        <= ld_col;
                    capture_valid_d1 <= 1;

                    // Stage 2: Capture Data
                    ld_row_d2        <= ld_row_d1;
                    ld_col_d2        <= ld_col_d1;
                    capture_valid_d2 <= capture_valid_d1;

                    if (capture_valid_d2) begin
                        tile_A[ld_row_d2][ld_col_d2] <= a_rd_data;
                        tile_B[ld_row_d2][ld_col_d2] <= b_rd_data;
                    end

                    // Advance counter
                    if (load_cnt == N*N - 1) begin
                        state <= LOAD_WAIT;  // Flush pipeline
                    end else begin
                        load_cnt <= load_cnt + 1;
                    end
                end

                // -----------------------------------------
                // LOAD_WAIT: Capture the last BRAM reads
                // -----------------------------------------
                LOAD_WAIT: begin
                    // Stage 1 clears
                    capture_valid_d1 <= 0;
                    
                    // Stage 2 shifts
                    ld_row_d2        <= ld_row_d1;
                    ld_col_d2        <= ld_col_d1;
                    capture_valid_d2 <= capture_valid_d1;

                    if (capture_valid_d2) begin
                        tile_A[ld_row_d2][ld_col_d2] <= a_rd_data;
                        tile_B[ld_row_d2][ld_col_d2] <= b_rd_data;
                    end

                    // When pipeline is fully flushed
                    if (!capture_valid_d1 && !capture_valid_d2) begin
                        state         <= LOAD_COMPLETE;
                    end
                end

                // -----------------------------------------
                LOAD_COMPLETE: begin
                    load_done <= 1;
                    state     <= IDLE;
                end

                // -----------------------------------------
                // FEEDING: Output one column of A and one
                //   row of B per cycle for N cycles
                // -----------------------------------------
                FEEDING: begin
                    // At cycle c, the systolic array needs:
                    //   raw_row_in[i] = A_tile[i][c]  (column c of tile_A)
                    //   raw_col_in[j] = B_tile[c][j]  (row c of tile_B)
                    // (This is handled combinationally below)

                    if (feed_cnt == N - 1) begin
                        state <= FEED_COMPLETE;
                    end else begin
                        feed_cnt <= feed_cnt + 1;
                    end
                end

                // -----------------------------------------
                FEED_COMPLETE: begin
                    feed_done <= 1;
                    state     <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // =========================================================
    //  Feed Output Logic (Combinational)
    // =========================================================
    // During FEEDING state, output tile data indexed by feed_cnt.
    // During other states, output zeros.
    genvar g;
    generate
        for (g = 0; g < N; g++) begin : feed_mux
            assign row_out[g] = (state == FEEDING) ? tile_A[g][feed_cnt] : 8'h0;
            assign col_out[g] = (state == FEEDING) ? tile_B[feed_cnt][g] : 8'h0;
        end
    endgenerate

endmodule

