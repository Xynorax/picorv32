module pe_output_stationary (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        clear_acc,   // High when we are done with a pixel and want to reset
    input  wire signed [7:0]  ifmap_i,     // Input activation from left neighbor
    input  wire signed [7:0]  weight_i,    // Weight from top neighbor
    output reg  signed [7:0]  ifmap_o,     // Pass activation to right neighbor
    output reg  signed [7:0]  weight_o,    // Pass weight to bottom neighbor
    output wire signed [31:0] psum_o       // Exposed local accumulator value
);

    // Local accumulation register (Stays stationary!)
    reg signed [31:0] r_accumulator;
    
    wire signed [31:0] next_psum;
    wire signed [31:0] current_mac_input;

    // The local feedback loop
    assign current_mac_input = clear_acc ? 32'sd0 : r_accumulator;

    // Reuse the exact same combinational MAC block from Step 0!
    mac core_mac (
        .a_i    (ifmap_i),
        .w_i    (weight_i),
        .psum_i (current_mac_input),
        .psum_o (next_psum)
    );

    // Sequential data movement
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ifmap_o       <= 8'sd0;
            weight_o      <= 8'sd0;
            r_accumulator <= 32'sd0;
        end else if (en) begin
            // Pass the data forward to neighbors for spatial reuse next cycle
            ifmap_o  <= ifmap_i;
            weight_o <= weight_i;
            
            // Accumulate locally
            r_accumulator <= next_psum;
        end
    end

    // The accumulated pixel value can be read out when calculations finish
    assign psum_o = r_accumulator;

endmodule