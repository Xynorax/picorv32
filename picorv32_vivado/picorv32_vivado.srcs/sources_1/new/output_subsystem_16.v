module output_subsystem_16 #(
    parameter SHIFT_AMOUNT = 9 // Prevents saturation
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         en,           // Coming from testbench during input stream
    input  wire [16*32-1:0] psums_cols_i,
    output reg          write_valid,  // Stays 0 until final calculation is 100% complete
    output wire [16*8-1:0]  packed_data_o
);

    // --- Internal Latency Counter ---
    // 80 cycles requires a 7-bit counter (can count up to 127)
    reg [6:0] cycle_counter;
    reg       processing_active;

    wire [7:0] processed_channels [0:15];

    genvar c;
    generate
        for (c = 0; c < 16; c = c + 1) begin : gen_post_proc
            wire signed [31:0] raw_psum = psums_cols_i[c*32 +: 32];
            
            // Phase A: Parameterized Arithmetic Shift Right
            wire signed [31:0] scaled_psum = raw_psum >>> SHIFT_AMOUNT;
            
            // Phase B: Quantized ReLU Activation & Saturation Guard
            assign processed_channels[c] = (scaled_psum[31] == 1'b1) ? 8'b0 : 
                                            (scaled_psum > 32'sd127)   ? 8'd127 : 
                                                                         scaled_psum[7:0];
            
            // Phase C: Structural packing
            assign packed_data_o[c*8 +: 8] = processed_channels[c];
        end
    endgenerate

    // --- Control FSM / Delay Pipeline ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter     <= 7'd0;
            processing_active <= 1'b0;
            write_valid       <= 1'b0;
        end else begin
            // Detect when the stream starts
            if (en && !processing_active) begin
                processing_active <= 1'b1;
                cycle_counter     <= 7'd1;
                write_valid       <= 1'b0;
            end 
            // Track the cycles through the pipeline
            else if (processing_active) begin
                if (cycle_counter == 7'd80) begin
                    // 80 cycles have passed! Array is fully drained and data is ready.
                    write_valid       <= 1'b1; 
                    processing_active <= 1'b0; // Reset tracking loop
                    cycle_counter     <= 7'd0;
                end else begin
                    cycle_counter     <= cycle_counter + 1'b1;
                    write_valid       <= 1'b0;
                end
            end else begin
                write_valid <= 1'b0; // Default fallback state
            end
        end
    end

endmodule