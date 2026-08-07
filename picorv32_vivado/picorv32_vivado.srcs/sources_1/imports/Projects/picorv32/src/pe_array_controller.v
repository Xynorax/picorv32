// pe_array_controller.v
// Drives the pe_array systolic array from the shared weight/activation
// BRAM (blk_mem_gen_0 global_buffer) one 16x16 input tile at a time.
//
// Memory map (13-bit BRAM word addresses, byte address >> 2):
//   WEIGHTS_START_ADDR + t*64 + w : weight word w of tile t
//   ACTS_START_ADDR     + t*4  + g : activation word g of tile t
//
// Per tile it:
//   1. reads 64 weight words (4 bytes each) and streams them into the
//      array's serial shift chain (LSB byte first) with load_weight=1
//      for ROWS*COLS consecutive shift cycles,
//   2. reads 4 activation words and assembles act_in_flat (row r =
//      bits [r*DATA_W +: DATA_W]),
//   3. holds act_in_flat for SETTLE cycles until the array reaches
//      steady state, then adds the settled per-column psums into 16
//      external 32-bit accumulators,
//   4. loops over all NUM_TILES tiles and finally asserts o_done.
//
// The result registers are exposed on o_results and read back over AXI.

module pe_array_controller #(
    parameter integer ROWS   = 16,
    parameter integer COLS   = 16,
    parameter integer DATA_W = 8,
    parameter integer ACC_W  = 32,
    parameter integer WEIGHTS_START_ADDR = 2,
    parameter integer ACTS_START_ADDR    = 4096,   // 0x1000
    parameter integer NUM_TILES          = 49,
    parameter integer WORDS_TO_LOAD      = ROWS*COLS/4,
    parameter integer SETTLE             = ROWS + COLS + 8
) (
    input  clk,
    input  resetn,
    input  [31:0] ctrl_reg,

    output reg o_busy,
    output reg o_done,
    output reg [COLS*ACC_W-1:0] o_results,

    // Array interface
    output reg [DATA_W-1:0]             weight_in,
    output reg                          load_weight,
    output reg [ROWS*DATA_W-1:0]        act_in_flat,
    input      [COLS*ACC_W-1:0]         psum_out_flat,

    // Memory interface (port B of the global buffer)
    output reg enb,
    output reg web,
    output reg [12:0] addrb,
    input      [31:0] dinb,
    input      [31:0] doutb
);

    localparam IDLE          = 4'd0,
               WT_READ       = 4'd1,
               WT_READ_WAIT  = 4'd2,
               WT_SHIFT      = 4'd3,
               ACT_READ      = 4'd4,
               ACT_READ_WAIT = 4'd5,
               ACT_STORE     = 4'd6,
               COMPUTE       = 4'd7,
               ACCUM         = 4'd8,
               DONE          = 4'd9;

    reg [3:0] state;
    reg prev_ctrl0;

    reg signed [ACC_W-1:0] acc [0:COLS-1];
    reg [12:0] current_address;
    reg [12:0] current_act_address;
    reg [7:0]  words_to_load;
    reg [1:0]  shift_bytes_cntr;
    reg [2:0]  read_cntr;
    reg [6:0]  tile_cntr;
    reg [1:0]  act_cntr;
    reg [5:0]  settle_cntr;

    integer c;

    always @* begin
        enb  = 1'b0;
        web  = 1'b0;
        addrb = 13'd0;
        case (state)
            WT_READ, WT_READ_WAIT: begin
                enb   = 1'b1;
                addrb = current_address;
            end
            ACT_READ, ACT_READ_WAIT: begin
                enb   = 1'b1;
                addrb = current_act_address + act_cntr;
            end
            default: ;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            state              <= IDLE;
            o_busy             <= 0;
            o_done             <= 0;
            prev_ctrl0         <= 0;
            load_weight        <= 0;
            weight_in          <= 0;
            act_in_flat        <= 0;
            current_address    <= 0;
            current_act_address<= 0;
            words_to_load      <= WORDS_TO_LOAD;
            for (c = 0; c < COLS; c = c + 1)
                acc[c] <= {ACC_W{1'b0}};
        end else begin
            prev_ctrl0 <= ctrl_reg[0];

            case (state)
                IDLE: begin
                    if (ctrl_reg[0] && !prev_ctrl0) begin
                        state              <= WT_READ;
                        o_busy             <= 1;
                        o_done             <= 0;
                        current_address    <= WEIGHTS_START_ADDR[12:0];
                        current_act_address<= ACTS_START_ADDR[12:0];
                        words_to_load      <= WORDS_TO_LOAD;
                        tile_cntr          <= 0;
                        act_in_flat        <= 0;
                        load_weight        <= 0;
                        weight_in          <= 0;
                        for (c = 0; c < COLS; c = c + 1)
                            acc[c] <= {ACC_W{1'b0}};
                    end
                end

                WT_READ: begin
                    read_cntr <= 3'd2;
                    state     <= WT_READ_WAIT;
                end

                WT_READ_WAIT: begin
                    if (read_cntr == 0) begin
                        load_weight      <= 1;
                        weight_in        <= doutb[0*DATA_W +: DATA_W];
                        shift_bytes_cntr <= 0;
                        state            <= WT_SHIFT;
                    end else begin
                        read_cntr <= read_cntr - 1;
                    end
                end

                WT_SHIFT: begin
                    load_weight <= 1;
                    // weight_in/load_weight are registered: the byte we
                    // assign here is latched by the array at the NEXT
                    // posedge. So while the counter is cnt, present byte
                    // cnt+1 (entry already presented byte 0 during the
                    // first WT_SHIFT cycle).
                    case (shift_bytes_cntr)
                        0: weight_in <= doutb[1*DATA_W +: DATA_W];
                        1: weight_in <= doutb[2*DATA_W +: DATA_W];
                        2: weight_in <= doutb[3*DATA_W +: DATA_W];
                        3: weight_in <= {DATA_W{1'b0}};
                    endcase
                    if (shift_bytes_cntr == 3) begin
                        shift_bytes_cntr <= 0;
                        load_weight      <= 0;
                        if (words_to_load == 8'd1) begin
                            // last word of this tile -> activations
                            words_to_load <= WORDS_TO_LOAD;
                            act_cntr      <= 0;
                            state         <= ACT_READ;
                        end else begin
                            words_to_load    <= words_to_load - 1;
                            current_address  <= current_address + 1;
                            state            <= WT_READ;
                        end
                    end else begin
                        shift_bytes_cntr <= shift_bytes_cntr + 1;
                    end
                end

                ACT_READ: begin
                    read_cntr <= 3'd2;
                    state     <= ACT_READ_WAIT;
                end

                ACT_READ_WAIT: begin
                    if (read_cntr == 0)
                        state <= ACT_STORE;
                    else
                        read_cntr <= read_cntr - 1;
                end

                ACT_STORE: begin
                    case (act_cntr)
                        0: act_in_flat[0*DATA_W*4 +: DATA_W*4] <= doutb;
                        1: act_in_flat[1*DATA_W*4 +: DATA_W*4] <= doutb;
                        2: act_in_flat[2*DATA_W*4 +: DATA_W*4] <= doutb;
                        3: act_in_flat[3*DATA_W*4 +: DATA_W*4] <= doutb;
                    endcase
                    if (act_cntr == 2'd3) begin
                        settle_cntr <= 0;
                        state       <= COMPUTE;
                    end else begin
                        act_cntr <= act_cntr + 1;
                        state    <= ACT_READ;
                    end
                end

                COMPUTE: begin
                    load_weight <= 0;
                    if (settle_cntr == SETTLE[5:0])
                        state <= ACCUM;
                    else
                        settle_cntr <= settle_cntr + 1;
                end

                ACCUM: begin
                    for (c = 0; c < COLS; c = c + 1)
                        acc[c] <= acc[c] + $signed(psum_out_flat[c*ACC_W +: ACC_W]);
                    act_in_flat <= 0;
                    load_weight <= 0;
                    if (tile_cntr == NUM_TILES-1) begin
                        state <= DONE;
                    end else begin
                        tile_cntr            <= tile_cntr + 1;
                        current_address      <= current_address + 1;
                        current_act_address  <= current_act_address + 4;
                        words_to_load        <= WORDS_TO_LOAD;
                        state                <= WT_READ;
                    end
                end

                DONE: begin
                    o_done  <= 1;
                    o_busy  <= 0;
                    state   <= IDLE;
                end

                default: ;
            endcase
        end
    end

    always @* begin
        for (c = 0; c < COLS; c = c + 1)
            o_results[c*ACC_W +: ACC_W] = acc[c];
    end

endmodule
