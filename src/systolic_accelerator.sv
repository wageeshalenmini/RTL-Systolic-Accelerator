module systolic_accelerator #(
    parameter N          = 4,
    parameter ADDR_WIDTH = 10     // Supports up to 32x32 matrices
)(
    input  logic        clk,
    input  logic        reset_n,
    input  logic        start,          // Pulse to begin matrix multiplication

    // Matrix Dimensions
    input  logic [7:0]  dim_M,          // Rows of A and C
    input  logic [7:0]  dim_K,          // Cols of A / Rows of B
    input  logic [7:0]  dim_P,          // Cols of B and C

    // Status Outputs
    output logic        busy,           // High while computing
    output logic        done            // Single pulse when C matrix is ready
);

    // =========================================================
    //  BRAMs for A, B, and C Matrices
    // =========================================================
    // In a real system, the CPU/testbench would write to Port A
    // For this module, we only control Port B (Reading A/B, Writing C)
    
    // Matrix A (8-bit)
    logic                  a_wr_en;
    logic [ADDR_WIDTH-1:0] a_wr_addr;
    logic [7:0]            a_wr_data;
    logic [ADDR_WIDTH-1:0] a_rd_addr;
    logic [7:0]            a_rd_data;
    matrix_bram #(.DATA_WIDTH(8), .ADDR_WIDTH(ADDR_WIDTH)) bram_A (
        .clk(clk),
        .wr_en(a_wr_en), .wr_addr(a_wr_addr), .wr_data(a_wr_data),
        .rd_addr(a_rd_addr), .rd_data(a_rd_data)
    );

    // Matrix B (8-bit)
    logic                  b_wr_en;
    logic [ADDR_WIDTH-1:0] b_wr_addr;
    logic [7:0]            b_wr_data;
    logic [ADDR_WIDTH-1:0] b_rd_addr;
    logic [7:0]            b_rd_data;
    matrix_bram #(.DATA_WIDTH(8), .ADDR_WIDTH(ADDR_WIDTH)) bram_B (
        .clk(clk),
        .wr_en(b_wr_en), .wr_addr(b_wr_addr), .wr_data(b_wr_data),
        .rd_addr(b_rd_addr), .rd_data(b_rd_data)
    );

    // Matrix C (20-bit)
    logic                  c_wr_en;
    logic [ADDR_WIDTH-1:0] c_wr_addr;
    logic [19:0]           c_wr_data;
    logic [ADDR_WIDTH-1:0] c_rd_addr;
    logic [19:0]           c_rd_data;
    matrix_bram #(.DATA_WIDTH(20), .ADDR_WIDTH(ADDR_WIDTH)) bram_C (
        .clk(clk),
        .wr_en(c_wr_en), .wr_addr(c_wr_addr), .wr_data(c_wr_data),
        .rd_addr(c_rd_addr), .rd_data(c_rd_data)
    );

    // Dummies for testbench access (normally you'd expose A/B wr_en and C rd_data to top level)
    assign a_wr_en = 0; assign a_wr_addr = 0; assign a_wr_data = 0;
    assign b_wr_en = 0; assign b_wr_addr = 0; assign b_wr_data = 0;

    // =========================================================
    //  Tile Feeder
    // =========================================================
    logic       tf_start_load, tf_start_feed;
    logic       tf_load_done, tf_feed_done;
    logic [7:0] tile_row, tile_col, tile_k;
    
    logic [7:0] raw_row_in [N-1:0];
    logic [7:0] raw_col_in [N-1:0];

    tile_feeder #(.N(N), .ADDR_WIDTH(ADDR_WIDTH)) feeder_inst (
        .clk(clk), .reset_n(reset_n),
        .start_load(tf_start_load), .start_feed(tf_start_feed),
        .tile_row(tile_row), .tile_col(tile_col), .tile_k(tile_k),
        .dim_K(dim_K), .dim_P(dim_P),
        .a_rd_addr(a_rd_addr), .a_rd_data(a_rd_data),
        .b_rd_addr(b_rd_addr), .b_rd_data(b_rd_data),
        .row_out(raw_row_in), .col_out(raw_col_in),
        .load_done(tf_load_done), .feed_done(tf_feed_done)
    );

    // =========================================================
    //  Datapath: Input Skewers + Systolic Array
    // =========================================================
    logic       acc_en;
    logic       clear_array;
    logic [19:0] sa_out [N-1:0][N-1:0];
    logic [7:0] skewed_rows [N-1:0];
    logic [7:0] skewed_cols [N-1:0];

    input_skewer #(.N(N)) row_skewer (
        .clk(clk), .reset_n(reset_n), .data_in(raw_row_in), .data_out(skewed_rows)
    );

    input_skewer #(.N(N)) col_skewer (
        .clk(clk), .reset_n(reset_n), .data_in(raw_col_in), .data_out(skewed_cols)
    );

    systolic_array #(.N(N)) mesh (
        .clk(clk), .reset_n(reset_n), .clear(clear_array), .en(acc_en),
        .row_in(skewed_rows), .col_in(skewed_cols), .final_out(sa_out)
    );

    // =========================================================
    //  Tile Accumulator
    // =========================================================
    logic start_accum, accum_done;
    logic is_first_k;
    assign is_first_k = (tile_k == 0);

    tile_accumulator #(.N(N), .DATA_WIDTH(20), .ADDR_WIDTH(ADDR_WIDTH)) accum_inst (
        .clk(clk), .reset_n(reset_n),
        .start_accum(start_accum), .is_first_k(is_first_k),
        .tile_row(tile_row), .tile_col(tile_col), .dim_P(dim_P),
        .sa_out(sa_out),
        .c_rd_addr(c_rd_addr), .c_rd_data(c_rd_data),
        .c_wr_en(c_wr_en), .c_wr_addr(c_wr_addr), .c_wr_data(c_wr_data),
        .accum_done(accum_done)
    );

    // =========================================================
    //  Tiling Master FSM
    // =========================================================
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_LOAD_TILE,
        ST_WAIT_LOAD,
        ST_FEED_ARRAY,
        ST_WAIT_FEED,
        ST_WAIT_ARRAY,
        ST_ACCUMULATE,
        ST_WAIT_ACCUM,
        ST_NEXT_TILE,
        ST_DONE
    } state_t;

    state_t state;

    // Counters to calculate number of tiles
    logic [7:0] num_tiles_row, num_tiles_col, num_tiles_k;
    
    // Counter for systolic array latency (3N-2)
    logic [7:0] sa_timer;
    localparam SA_LATENCY = 3*N - 2;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state         <= ST_IDLE;
            busy          <= 0;
            done          <= 0;
            tf_start_load <= 0;
            tf_start_feed <= 0;
            acc_en        <= 0;
            start_accum   <= 0;
            clear_array   <= 0;
            sa_timer      <= 0;
            
            tile_row      <= 0;
            tile_col      <= 0;
            tile_k        <= 0;
            
            num_tiles_row <= 0;
            num_tiles_col <= 0;
            num_tiles_k   <= 0;
        end else begin
            // Default pulse clear
            done          <= 0;
            tf_start_load <= 0;
            tf_start_feed <= 0;
            start_accum   <= 0;
            clear_array   <= 0;

            case (state)
                ST_IDLE: begin
                    if (start) begin
                        state         <= ST_LOAD_TILE;
                        busy          <= 1;
                        tile_row      <= 0;
                        tile_col      <= 0;
                        tile_k        <= 0;
                        // Calculate total tiles needed (assuming cleanly divisible by N for now)
                        num_tiles_row <= dim_M / N; // e.g. 8/4 = 2
                        num_tiles_col <= dim_P / N;
                        num_tiles_k   <= dim_K / N;
                    end
                end

                ST_LOAD_TILE: begin
                    tf_start_load <= 1;
                    clear_array   <= 1; // Pulse clear to reset PE accumulators
                    state         <= ST_WAIT_LOAD;
                end

                ST_WAIT_LOAD: begin
                    if (tf_load_done) begin
                        state         <= ST_FEED_ARRAY;
                        tf_start_feed <= 1;
                        acc_en        <= 1; // Enable array computation
                    end
                end

                ST_FEED_ARRAY: begin
                    // Feeding happens automatically via tile_feeder
                    state <= ST_WAIT_FEED;
                end

                ST_WAIT_FEED: begin
                    if (tf_feed_done) begin
                        state    <= ST_WAIT_ARRAY;
                        sa_timer <= 0;
                    end
                end

                ST_WAIT_ARRAY: begin
                    // SysArray continues computing internal wavefront
                    if (sa_timer == SA_LATENCY) begin
                        acc_en      <= 0; // Disable array calculation
                        state       <= ST_ACCUMULATE;
                        start_accum <= 1;
                    end else begin
                        sa_timer <= sa_timer + 1;
                    end
                end

                ST_ACCUMULATE: begin
                    state <= ST_WAIT_ACCUM;
                end

                ST_WAIT_ACCUM: begin
                    if (accum_done) begin
                        state <= ST_NEXT_TILE;
                    end
                end

                ST_NEXT_TILE: begin
                    // Tile loops (innermost is K-dimension)
                    if (tile_k < num_tiles_k - 1) begin
                        tile_k <= tile_k + 1;
                        state  <= ST_LOAD_TILE;
                    end else begin
                        tile_k <= 0;
                        if (tile_col < num_tiles_col - 1) begin
                            tile_col <= tile_col + 1;
                            state    <= ST_LOAD_TILE;
                        end else begin
                            tile_col <= 0;
                            if (tile_row < num_tiles_row - 1) begin
                                tile_row <= tile_row + 1;
                                state    <= ST_LOAD_TILE;
                            end else begin
                                // All tiles completed
                                state <= ST_DONE;
                            end
                        end
                    end
                end

                ST_DONE: begin
                    busy  <= 0;
                    done  <= 1;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule