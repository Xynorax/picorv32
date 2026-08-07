module pe_array #(
    parameter integer ROWS   = 16,
    parameter integer COLS   = 16,
    parameter integer DATA_W = 8,
    parameter integer ACC_W  = 32
)(
    input  wire                                    clk,
    input  wire                                    rst_n,

    input  wire                                    load_weight,
    input  wire signed [DATA_W-1:0]                weight_in,

    input  wire signed [ROWS*DATA_W-1:0]           act_in_flat,
    output wire signed [COLS*ACC_W-1:0]            psum_out_flat
);

    genvar r, c;

    wire signed [DATA_W-1:0] act_in_row [0:ROWS-1];
    generate
        for (r = 0; r < ROWS; r = r + 1) begin : g_extract_act
            assign act_in_row[r] = act_in_flat[r*DATA_W +: DATA_W];
        end
    endgenerate

    wire signed [DATA_W-1:0] act_grid  [0:ROWS-1][0:COLS];
    wire signed [ACC_W-1:0]  psum_grid [0:ROWS][0:COLS-1];

    localparam integer N_W = ROWS * COLS;
    wire signed [DATA_W-1:0] w_chain [0:N_W];
    assign w_chain[0] = weight_in;

    // Top edge: no partial sum flows in from above the array.
    generate
        for (c = 0; c < COLS; c = c + 1) begin : g_top_edge
            assign psum_grid[0][c] = {ACC_W{1'b0}};
        end
    endgenerate

    // Left edge
    generate
        for (r = 0; r < ROWS; r = r + 1) begin : g_skew
            delay_chain #(.WIDTH(DATA_W), .STAGES(r)) u_skew (
                .clk   (clk),
                .rst_n (rst_n),
                .din   (act_in_row[r]),
                .dout  (act_grid[r][0])
            );
        end
    endgenerate

    // The grid 
    generate
        for (r = 0; r < ROWS; r = r + 1) begin : g_row
            for (c = 0; c < COLS; c = c + 1) begin : g_col
                processing_element #(.DATA_W(DATA_W), .ACC_W(ACC_W)) u_pe (
                    .clk         (clk),
                    .rst_n       (rst_n),
                    .load_weight (load_weight),
                    .weight_in   (w_chain[r*COLS + c]),
                    .weight_out  (w_chain[r*COLS + c + 1]),
                    .act_in      (act_grid[r][c]),
                    .psum_in     (psum_grid[r][c]),
                    .act_out     (act_grid[r][c+1]),
                    .psum_out    (psum_grid[r+1][c])
                );
            end
        end
    endgenerate

    // Bottom edge
    generate
        for (c = 0; c < COLS; c = c + 1) begin : g_bottom_edge
            assign psum_out_flat[c*ACC_W +: ACC_W] = psum_grid[ROWS][c];
        end
    endgenerate

endmodule