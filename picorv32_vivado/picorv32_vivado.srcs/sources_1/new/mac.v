module mac (
    input  wire signed [7:0]  b,     // Activation operand (8-bit signed)
    input  wire signed [7:0]  a,     // Weight operand (8-bit signed)
    input  wire signed [31:0] acc_in,  // Previous partial sum input (32-bit signed)
    output wire signed [31:0] acc_out   // New partial sum output (32-bit signed)
);

    // 1. Core multiplier: 8-bit x 8-bit yields a 16-bit signed product
    wire signed [15:0] product;
    assign product = b * a;

    // 2. Accumulator adder: Verilog automatically handles sign-extension 
    //    when adding a narrower signed variable (16-bit) to a wider one (32-bit).
    assign acc_out = acc_in + product;

endmodule