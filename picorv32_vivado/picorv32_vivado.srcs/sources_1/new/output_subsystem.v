module output_subsystem (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire signed [31:0] psum_col0_i, // 32-bit output from column 0
    input  wire signed [31:0] psum_col1_i, // 32-bit output from column 1
    output reg         write_valid,       // Asserted when packed data is ready
    output wire        [15:0] packed_data_o  // Combined 16-bit word for SRAM write
);

    // 1. Truncation / Fixed-point Quantization Phase
    // Arithmetic right-shift maintains the sign bit while discarding lower bits
    wire signed [31:0] scaled_col0 = psum_col0_i >>> 8;
    wire signed [31:0] scaled_col1 = psum_col1_i >>> 8;

    // 2. Activation Function Phase (Hardware ReLU)
    // If the sign bit (MSB) is 1, the number is negative -> output 0.
    // Otherwise, grab the lower 8 bits safely.
    wire [7:0] relu_col0 = (scaled_col0[31] == 1'b1) ? 8'b0 : scaled_col0[7:0];
    wire [7:0] relu_col1 = (scaled_col1[31] == 1'b1) ? 8'b0 : scaled_col1[7:0];

    // 3. Sequential Output Buffering & Packing
    reg [7:0] r_out_col0;
    reg [7:0] r_out_col1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_out_col0  <= 8'b0;
            r_out_col1  <= 8'b0;
            write_valid <= 1'b0;
        end else if (en) begin
            r_out_col0  <= relu_col0;
            r_out_col1  <= relu_col1;
            write_valid <= 1'b1; // Signal to memory that data is stable
        end else begin
            write_valid <= 1'b0;
        end
    end

    // Pack the separate 8-bit channels into a tight 16-bit single-cycle bus word
    assign packed_data_o = {r_out_col1, r_out_col0};

endmodule