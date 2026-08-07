// tb_mnist_layer.v
// Drives the 784->16 dense layer using the .mem files produced by
// gen_mnist_sram_data.py (sram_weight_init.mem, sram_ifmap_init.mem).
//
// Both files are already packed exactly the way the array wants them:
//   - sram_weight_init.mem: 49 lines, each one full 2048-bit
//     (16x16x8-bit) weight tile, streamed into weight_in one byte per
//     cycle through the shift chain. The chain reverses the order, so
//     bytes are fed BACKWARDS (element [r][c] on cycle 255-(r*16+c)).
//   - sram_ifmap_init.mem: 49 lines, each one 128-bit (16x8-bit)
//     activation slice, ready to drop straight into act_in_flat.
//
// Same K-tiling/settle strategy as tb_dense_layer.v: load a tile's
// weights, hold its activations until the array reaches steady state,
// accumulate the settled result into an external per-column
// accumulator, move to the next tile.
//
// This only reproduces the RAW accumulator (matches the Python
// script's `raw_accumulated`) - there is no requantization/ReLU stage
// in the hardware yet, so this does NOT reproduce `expected_output`.
`timescale 1ns/1ps

module tb_npu_system;
    localparam ROWS    = 16;
    localparam COLS    = 16;   // 16 outputs, matches num_output_tiles=1 in the script
    localparam DATA_W  = 8;
    localparam ACC_W   = 32;
    localparam K_TILES = 49;               // 49 * 16 = 784 inputs
    localparam SETTLE  = ROWS + COLS + 8;  // cycles to reach steady state per tile

    reg clk, rst_n, load_weight;
    reg  signed [DATA_W-1:0]            weight_in;
    reg  signed [ROWS*DATA_W-1:0]       act_in_flat;
    wire signed [COLS*ACC_W-1:0]        psum_out_flat;

    pe_array #(.ROWS(ROWS), .COLS(COLS), .DATA_W(DATA_W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rst_n(rst_n), .load_weight(load_weight),
        .weight_in(weight_in), .act_in_flat(act_in_flat),
        .psum_out_flat(psum_out_flat)
    );

    always #5 clk = ~clk;

    // Each line of these files is already a full flat-bus word for one
    // tile - only the weight word must be broken back into per-byte
    // serial values before streaming.
    reg signed [ROWS*COLS*DATA_W-1:0] weight_sram [0:K_TILES-1];
    reg signed [ROWS*DATA_W-1:0]      ifmap_sram  [0:K_TILES-1];

    reg signed [ACC_W-1:0] acc [0:COLS-1];
    integer tile, r, c, s;

    initial begin
        $readmemh("sram_weight_init.mem", weight_sram);
        $readmemh("sram_ifmap_init.mem",  ifmap_sram);

        clk = 0; rst_n = 0; load_weight = 0;
        weight_in = 0; act_in_flat = 0;
        for (c = 0; c < COLS; c = c + 1) acc[c] = 0;

        @(negedge clk); @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        for (tile = 0; tile < K_TILES; tile = tile + 1) begin
            // Stream the whole 16x16 weight tile into the head of the
            // shift chain, one byte per cycle. The chain reverses the
            // order, so weights must go in BACKWARDS: element [r][c]
            // lands in PE(r,c) when presented on cycle 255-(r*16+c),
            // i.e. (15,15) first and (0,0) last.
            for (r = ROWS-1; r >= 0; r = r - 1) begin
                for (c = COLS-1; c >= 0; c = c - 1) begin
                    weight_in   = weight_sram[tile][(r*COLS+c)*DATA_W +: DATA_W];
                    load_weight = 1;
                    @(negedge clk);
                end
            end
            load_weight = 0;

            act_in_flat    = ifmap_sram[tile];

            for (s = 0; s < SETTLE; s = s + 1)
                @(negedge clk);

            for (c = 0; c < COLS; c = c + 1)
                acc[c] = acc[c] + $signed(psum_out_flat[c*ACC_W +: ACC_W]);
        end

        $display("RTL Raw Accumulator Outputs (32-bit PSUMs):");
        $write("[");
        for (c = 0; c < COLS; c = c + 1) begin
            $write("%0d", acc[c]);
            if (c != COLS-1) $write(", ");
        end
        $display("]");
        $display("\nCompare this list directly against the Python script's");
        $display("printed 'Raw Accumulator Outputs (32-bit PSUMs)' line -");
        $display("they should match element-for-element. (No requant/ReLU");
        $display("stage exists in hardware yet, so don't compare against");
        $display("the script's 'Quantized Output Vector'.)");

        $finish;
    end
endmodule