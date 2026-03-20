// ============================================================
// Module: tile_accumulator
// Description: After the systolic array completes a tile (N×N),
//   reads the partial sum from C BRAM, adds the new result,
//   and writes it back.
//   If it's the first tile (k=0), it initializes to the new result.
// ============================================================
module tile_accumulator #(
    parameter N          = 4,
    parameter DATA_WIDTH = 20,
    parameter ADDR_WIDTH = 10
)(
    input  logic                    clk,
    input  logic                    reset_n,

    // --- Control from Tiling Controller ---
    input  logic                    start_accum,  // Pulse: begin accumulation phase
    input  logic                    is_first_k,   // 1 if tile_k == 0 (no read-add, just write)
    
    // --- Tile Coordinates ---
    input  logic [7:0]              tile_row,     // Tile row index
    input  logic [7:0]              tile_col,     // Tile col index

    // --- Matrix Dimensions ---
    input  logic [7:0]              dim_P,        // Columns of C (same as B)

    // --- Systolic Array Output ---
    input  logic [DATA_WIDTH-1:0]   sa_out [N-1:0][N-1:0],

    // --- BRAM Read Interface for C ---
    output logic [ADDR_WIDTH-1:0]   c_rd_addr,
    input  logic [DATA_WIDTH-1:0]   c_rd_data,

    // --- BRAM Write Interface for C ---
    output logic                    c_wr_en,
    output logic [ADDR_WIDTH-1:0]   c_wr_addr,
    output logic [DATA_WIDTH-1:0]   c_wr_data,

    // --- Status ---
    output logic                    accum_done
);

    // =========================================================
    //  FSM
    // =========================================================
    typedef enum logic [1:0] {
        IDLE,
        READ_ADD_WRITE,
        DONE_STATE
    } state_t;

    state_t state;

    // Counter (0 to N*N-1)
    logic [7:0] cnt;
    
    // Current row/col within the tile
    logic [7:0] row_idx, col_idx;
    assign row_idx = cnt / N;
    assign col_idx = cnt % N;

    // Pipeline registers for read-modify-write
    logic [ADDR_WIDTH-1:0] wr_addr_d1, wr_addr_d2;
    logic [DATA_WIDTH-1:0] sa_val_d1, sa_val_d2;
    logic                  write_valid_d1, write_valid_d2;

    // =========================================================
    //  Address Generation
    // =========================================================
    // C is stored row-major: C[i][j] at addr = i * dim_P + j
    wire [ADDR_WIDTH-1:0] addr_calc = (tile_row * N + row_idx) * dim_P + (tile_col * N + col_idx);
    
    // Systolic array value for current cnt
    wire [DATA_WIDTH-1:0] current_sa_val = sa_out[row_idx][col_idx];

    // =========================================================
    //  Main FSM & Pipeline
    // =========================================================
    // The pipeline has 3 stages (cycles):
    // Cycle 0: Issue Read Address & Save State (cnt)
    // Cycle 1: BRAM reads data. Buffer SA value.
    // Cycle 2: Data from BRAM is available. Add SA value and Write out.

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state         <= IDLE;
            cnt           <= 0;
            accum_done    <= 0;
            
            c_rd_addr     <= '0;
            c_wr_en       <= 0;
            c_wr_addr     <= '0;
            c_wr_data     <= '0;

            wr_addr_d1    <= '0;
            sa_val_d1     <= '0;
            write_valid_d1<= 0;
            
            wr_addr_d2    <= '0;
            sa_val_d2     <= '0;
            write_valid_d2<= 0;
        end else begin
            accum_done <= 0;
            c_wr_en    <= 0; // Default off

            // --- Pipeline Stage 2: Write En (Cycle 2) ---
            if (write_valid_d2) begin
                c_wr_en   <= 1;
                c_wr_addr <= wr_addr_d2;
                // If first k, just write SA value. Otherwise, add to read data.
                c_wr_data <= is_first_k ? sa_val_d2 : (sa_val_d2 + c_rd_data);
            end

            // --- Pipeline Stage 1: Wait for BRAM Read (Cycle 1) ---
            wr_addr_d2     <= wr_addr_d1;
            sa_val_d2      <= sa_val_d1;
            write_valid_d2 <= write_valid_d1;

            case (state)
                IDLE: begin
                    if (start_accum) begin
                        state <= READ_ADD_WRITE;
                        cnt   <= 0;
                    end
                end

                READ_ADD_WRITE: begin
                    // --- Pipeline Stage 0: Issue Address (Cycle 0) ---
                    c_rd_addr <= addr_calc;
                    
                    // Pass info down pipeline
                    wr_addr_d1     <= addr_calc;
                    sa_val_d1      <= current_sa_val;
                    write_valid_d1 <= 1;

                    if (cnt == N*N - 1) begin
                        state <= DONE_STATE;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end

                DONE_STATE: begin
                    // Clear Stage 0
                    write_valid_d1 <= 0;
                    
                    // We must wait for the pipeline to flush
                    // write_valid_d2 will be 1 this cycle (processing last item)
                    // Next cycle c_wr_en will assert for the last item
                    // So we wait until write_valid_d2 is 0 AND c_wr_en is 0
                    if (!write_valid_d2 && !c_wr_en) begin
                        accum_done <= 1;
                        state      <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
