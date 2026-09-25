module mac #(
    parameter integer DATA_W = 8,
    parameter integer ACC_W  = 32
) (
    input  wire signed [DATA_W-1:0]  b,       // activation
    input  wire signed [DATA_W-1:0]  a,       // weight
    input  wire signed [ACC_W-1:0]   acc_in,
    output wire signed [ACC_W-1:0]   acc_out
);
    wire signed [2*DATA_W-1:0] product;
    assign product = b * a;
    assign acc_out = acc_in + product;
endmodule