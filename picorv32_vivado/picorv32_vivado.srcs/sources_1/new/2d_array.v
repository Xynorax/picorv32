module array_2d (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        clear_acc,
    
    // Horizontal Input Activation Streams (16 channels of 8-bit inputs)
    input  wire signed [16*8-1:0]  ifmap_rows_i, 
    
    // Static Weight Matrix Configuration (256 weights of 8-bit inputs)
    input  wire signed [256*8-1:0] weights_i, 
    
    // Vertical Output Partial Sum Streams (16 columns of 32-bit outputs)
    output wire signed [16*32-1:0] psums_cols_o 
);

    // --- Array Parameters ---
    localparam ROWS = 16;
    localparam COLS = 16;

    // --- Internal 2D Routing Grids ---
    // Horizontal activation routing: ROWS rows, each having (COLS + 1) connection boundaries
    wire signed [7:0] ifmap_grid [0:ROWS-1][0:COLS];
    
    // Vertical partial sum routing: (ROWS + 1) rows, each having COLS connection boundaries
    // Note: If your PE design passes partial sums down the columns, we route them here.
    wire signed [31:0] psum_grid [0:ROWS][0:COLS-1];

    // --- Unpack Inputs and Pack Outputs ---
    genvar r, c;
    generate
        // Connect row inputs to the left edge of the grid
        for (r = 0; r < ROWS; r = r + 1) begin : gen_row_inputs
            assign ifmap_grid[r][0] = ifmap_rows_i[r*8 +: 8];
        end

        // Connect the top-most partial sum inputs to 0 (since nothing is above Row 0)
        for (c = 0; c < COLS; c = c + 1) begin : gen_top_psums
            assign psum_grid[0][c] = 32'sd0;
        end

        // Pack the bottom-most partial sums into the final output port
        for (c = 0; c < COLS; c = c + 1) begin : gen_col_outputs
            assign psums_cols_o[c*32 +: 32] = psum_grid[ROWS][c];
        end
    endgenerate

    // --- 2D Generate Grid of Processing Elements ---
    generate
        for (r = 0; r < ROWS; r = r + 1) begin : gen_rows
            for (c = 0; c < COLS; c = c + 1) begin : gen_cols
                
                // Extract the specific 8-bit static weight for PE(r,c) from flat vector
                wire signed [7:0] local_weight = weights_i[((r * COLS) + c)*8 +: 8];

                processing_element pe_inst (
                    .clk       (clk),
                    .rst_n     (rst_n),
                    .en        (en),
                    .clear_acc (clear_acc),
                    .ifmap_i   (ifmap_grid[r][c]),
                    .weight_i  (local_weight),
                    .psum_i    (psum_grid[r][c]),      // Vertical input from above
                    .psum_o    (psum_grid[r+1][c])     // Vertical output to below
                );

                // Replicate the horizontal propagation of the input activation
                // Using hierarchical path to get registered activation from the PE instance
                assign ifmap_grid[r][c+1] = pe_inst.r_ifmap; 

            end
        end
    endgenerate

endmodule