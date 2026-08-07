module delay_chain #(
    parameter integer WIDTH  = 8,
    parameter integer STAGES = 0
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire signed [WIDTH-1:0] din,
    output wire signed [WIDTH-1:0] dout
);
 
    generate
        if (STAGES == 0) begin : g_no_delay
            assign dout = din;
        end else begin : g_delay
            reg signed [WIDTH-1:0] pipe [0:STAGES-1];
            integer i;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (i = 0; i < STAGES; i = i + 1)
                        pipe[i] <= {WIDTH{1'b0}};
                end else begin
                    pipe[0] <= din;
                    for (i = 1; i < STAGES; i = i + 1)
                        pipe[i] <= pipe[i-1];
                end
            end
            assign dout = pipe[STAGES-1];
        end
    endgenerate
 
endmodule