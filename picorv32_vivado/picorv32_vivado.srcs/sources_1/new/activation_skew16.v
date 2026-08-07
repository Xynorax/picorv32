module activation_skew_16 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire [16*8-1:0] ifmap_raw_i,   // Un-skewed parallel input from SRAM
    output wire [16*8-1:0] ifmap_skewed_o // Perfectly skewed output to the array
);

    genvar i, j;
    generate
        // Row 0 connects directly (0 cycles delay)
        assign ifmap_skewed_o[7:0] = ifmap_raw_i[7:0];

        // Rows 1 to 15 require a chain of flip-flops matching their index
        for (i = 1; i < 16; i = i + 1) begin : gen_skew_channels
            reg signed [7:0] delay_pipe [0:i-1];

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (integer k = 0; k < i; k = k + 1) begin
                        delay_pipe[k] <= 8'sd0;
                    end
                end else if (en) begin
                    delay_pipe[0] <= ifmap_raw_i[i*8 +: 8];
                    for (integer k = 1; k < i; k = k + 1) begin
                        delay_pipe[k] <= delay_pipe[k-1];
                    end
                end
            end

            // Assign the last register in the pipeline chain to the output
            assign ifmap_skewed_o[i*8 +: 8] = delay_pipe[i-1];
        end
    endgenerate

endmodule