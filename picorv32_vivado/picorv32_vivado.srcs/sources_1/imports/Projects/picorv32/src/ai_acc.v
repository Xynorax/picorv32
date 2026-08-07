module ai_accel_axi #(
    parameter integer ROWS   = 16,
    parameter integer COLS   = 16,
    parameter integer DATA_W = 8,
    parameter integer ACC_W  = 32
)(
    input             clk,
    input             resetn,

    input             s_axi_awvalid, output reg s_axi_awready,
    input      [31:0] s_axi_awaddr,
    input             s_axi_wvalid,  output reg s_axi_wready,
    input      [31:0] s_axi_wdata,
    input      [3:0]  s_axi_wstrb,
    output reg        s_axi_bvalid,  input      s_axi_bready,

    input             s_axi_arvalid, output reg s_axi_arready,
    input      [31:0] s_axi_araddr,
    output reg        s_axi_rvalid,  input      s_axi_rready,
    output reg [31:0] s_axi_rdata
);
    reg ena_write, ena_read;
    wire ena = ena_write | ena_read;
    reg [0:0] wea;
    reg [12:0] addra;
    reg [31:0] dina;
    wire enb;
    wire [0:0] web;
    wire [12:0] addrb;
    wire [31:0] dinb;
    wire [31:0] douta, doutb;
    blk_mem_gen_0 global_buffer (
      .clka(clk),    // input wire clka
      .ena(ena),      // input wire ena
      .wea(wea),      // input wire [0 : 0] wea
      .addra(addra),  // input wire [12 : 0] addra
      .dina(dina),    // input wire [31 : 0] dina
      .douta(douta),  // output wire [31 : 0] douta
      .clkb(clk),    // input wire clkb
      .enb(enb),      // input wire enb
      .web(web),      // input wire [0 : 0] web
      .addrb(addrb),  // input wire [12 : 0] addrb
      .dinb(dinb),    // input wire [31 : 0] dinb
      .doutb(doutb)  // output wire [31 : 0] doutb
    );

    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;
    wire [DATA_W-1:0]            weight_in;
    wire                         load_weight;
    wire [ROWS*DATA_W-1:0]       act_in_flat;
    wire [COLS*ACC_W-1:0]        psum_out_flat;
    wire [COLS*ACC_W-1:0]        o_results;
    wire                         o_done, o_busy;

    pe_array #(.DATA_W(DATA_W), .COLS(COLS), .ROWS(ROWS), .ACC_W(ACC_W) ) pe_array_inst (
        .clk(clk),
        .rst_n(resetn),
        .load_weight(load_weight),
        .weight_in(weight_in),
        .act_in_flat(act_in_flat),
        .psum_out_flat(psum_out_flat)
    );

    pe_array_controller #(.DATA_W(DATA_W), .COLS(COLS), .ROWS(ROWS), .ACC_W(ACC_W) ) pe_array_controller_inst (
        .clk(clk),
        .resetn(resetn),
        .ctrl_reg(ctrl_reg),
        .o_busy(o_busy),
        .o_done(o_done),
        .o_results(o_results),
        .load_weight(load_weight),
        .weight_in(weight_in),
        .act_in_flat(act_in_flat),
        .psum_out_flat(psum_out_flat),
        .enb(enb),
        .web(web),
        .addrb(addrb),
        .dinb(dinb),
        .doutb(doutb)
    );

    // Status is read-only: bit0 = done, bit1 = busy.
    always @(posedge clk) begin
        status_reg[0] <= o_done;
        status_reg[1] <= o_busy;
        status_reg[31:2] <= 30'd0;
    end

    // ---- AXI write channel ----
    reg [31:0] waddr;
    always @(posedge clk) begin
        if (!resetn) begin
            s_axi_awready <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0;
            ctrl_reg <= 0;
        end else begin
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            ena_write <= 0;
            if (s_axi_awvalid && !s_axi_awready && !s_axi_bvalid) begin
                s_axi_awready <= 1;
                waddr = s_axi_awaddr;
            end
            if (s_axi_wvalid && !s_axi_wready && !s_axi_bvalid) begin
                if (waddr == 32'h30000000)
                    ctrl_reg <= s_axi_wdata;
                else begin
                    ena_write <= 1;
                    wea <= 1;
                    addra <= waddr[14:2];
                    dina <= s_axi_wdata; // DATA: write to memory
                end
                s_axi_wready <= 1;
                s_axi_bvalid <= 1;
            end
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 0;
        end
    end

    // ---- AXI read channel ----
    reg [31:0] raddr;
    reg [4:0]  result_idx;
    // make states
    parameter IDLE = 2'b00, WAIT_READ_1 = 2'b01, WAIT_READ_2 = 2'b10, WAIT_READ_3 = 2'b11;
    reg [1:0] current_state;
    always @(posedge clk) begin
        if (!resetn) begin
            s_axi_arready <= 0; s_axi_rvalid <= 0;
            current_state <= IDLE;
        end else begin
            s_axi_arready <= 0;
            ena_read <= 0;
            if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
                s_axi_arready <= 1;
                raddr <= s_axi_araddr;
            end
            if (s_axi_arready) begin
                if (raddr == 32'h30000000) begin
                    s_axi_rdata <= ctrl_reg;
                    s_axi_rvalid <= 1;
                end
                else if (raddr == 32'h30000004) begin
                    s_axi_rdata <= status_reg;
                    s_axi_rvalid <= 1;
                end
                else if (raddr >= 32'h30000080 && raddr <= 32'h300000BC) begin
                    result_idx <= (raddr - 32'h30000080) >> 2;
                    s_axi_rdata <= o_results[((raddr - 32'h30000080) >> 2)*32 +: 32];
                    s_axi_rvalid <= 1;
                end
                else begin
                    ena_read <= 1;
                    wea <= 0;
                    addra <= raddr[14:2];
                    current_state <= WAIT_READ_1;
                    s_axi_rvalid <= 0;
                end
            end
            if (current_state == WAIT_READ_1) begin
                ena_read <= 1;
                s_axi_rvalid <= 0;
                current_state <= WAIT_READ_2;
            end
            if (current_state == WAIT_READ_2) begin
                ena_read <= 1;
                s_axi_rvalid <= 0;
                current_state <= WAIT_READ_3;
            end
            if (current_state == WAIT_READ_3) begin
                ena_read <= 1;
                s_axi_rdata <= douta;
                s_axi_rvalid <= 1;
                current_state <= IDLE;
            end
            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 0;
        end
    end
endmodule
