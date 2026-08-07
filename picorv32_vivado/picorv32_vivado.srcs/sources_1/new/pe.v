// pe.v
// Weight-stationary systolic Processing Element.
//
// Dataflow convention (standard weight-stationary array, e.g. TPU-style):
//   - weight is loaded ONCE and stays put in this PE for the whole
//     matmul/conv (that's what "weight-stationary" means).
//   - activation flows horizontally: act_in comes from the PE to the
//     left (or from the edge of the array), and act_out is registered
//     and passed to the PE on the right. Every PE in a row eventually
//     sees the same activation stream, one cycle later than its
//     left neighbor.
//   - partial sum flows vertically: psum_in comes from the PE above
//     (or 0 at the top edge), gets this PE's weight*activation added
//     to it, and the registered result (psum_out) is passed down to
//     the PE below. By the time it exits the bottom of a column, it
//     has accumulated weight*activation from every PE in that column
//     - i.e. one full dot-product reduction.
//
// This single PE is the unit cell you tile into an MxN grid to build
// the full array. It reuses the mac8 combinational multiply-add and
// wraps it with the two pieces of state a systolic PE actually needs:
// the stationary weight, and the pipeline registers that move
// activation/psum to the next PE on the correct clock edge.

module processing_element #(
    parameter integer DATA_W = 8,
    parameter integer ACC_W  = 32
)(
    input  wire                      clk,
    input  wire                      rst_n,        // async active-low reset

    input  wire                      load_weight,  // 1 = capture weight_in this cycle
    input  wire signed [DATA_W-1:0]  weight_in,

    input  wire signed [DATA_W-1:0]  act_in,        // from PE to the left
    input  wire signed [ACC_W-1:0]   psum_in,       // from PE above

    output wire signed [DATA_W-1:0]  weight_out,    // to the next PE in the load chain
    output wire signed [DATA_W-1:0]  act_out,       // to PE to the right
    output wire signed [ACC_W-1:0]   psum_out       // to PE below
);

    // The stationary weight. Only changes when explicitly told to
    // (load_weight=1); otherwise holds its value indefinitely, which is
    // exactly what "stationary" means here. During a load burst the
    // value latched here is also pushed out of weight_out, so the
    // weight stream shifts one PE further down the chain each cycle.
    reg signed [DATA_W-1:0] weight_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            weight_reg <= {DATA_W{1'b0}};
        else if (load_weight)
            weight_reg <= weight_in;
    end

    assign weight_out = weight_reg;

    // Combinational MAC: this cycle's weight * this cycle's incoming
    // activation, added to this cycle's incoming partial sum.
    wire signed [ACC_W-1:0] psum_comb;

    mac #(.DATA_W(DATA_W), .ACC_W(ACC_W)) u_mac (
        .a       (weight_reg),
        .b       (act_in),
        .acc_in  (psum_in),
        .acc_out (psum_comb)
    );

    // Pipeline registers. These are what actually make it "systolic":
    // every PE holds its outputs for exactly one cycle before its
    // neighbor sees them, so data marches through the array in lockstep
    // with the clock instead of racing through combinationally.
    reg signed [DATA_W-1:0] act_out_reg;
    reg signed [ACC_W-1:0]  psum_out_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_out_reg  <= {DATA_W{1'b0}};
            psum_out_reg <= {ACC_W{1'b0}};
        end else begin
            act_out_reg  <= act_in;     // pass activation one step right
            psum_out_reg <= psum_comb;  // pass accumulated sum one step down
        end
    end

    assign act_out  = act_out_reg;
    assign psum_out = psum_out_reg;

endmodule