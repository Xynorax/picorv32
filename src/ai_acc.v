module ai_accel_axi #(
    parameter integer ROWS   = 16,
    parameter integer COLS   = 16,
    parameter integer DATA_W = 8,
    parameter integer ACC_W  = 32
)(
    input             clk,
    input             resetn,

    // Write Address Channel
    input             s_axi_awvalid, 
    output            s_axi_awready,
    input      [31:0] s_axi_awaddr,
    input      [7:0]  s_axi_awlen,    // AXI4 burst length
    input      [2:0]  s_axi_awsize,   // Burst size
    input      [1:0]  s_axi_awburst,  // Burst type
    input      [1:0]  s_axi_awlock,   // Lock type
    input      [3:0]  s_axi_awcache,  // Cache type
    input      [2:0]  s_axi_awprot,   // Protection type

    // Write Data Channel
    input             s_axi_wvalid,  
    output            s_axi_wready,   
    input      [31:0] s_axi_wdata, 
    input      [3:0]  s_axi_wstrb,
    input             s_axi_wlast,    // Last transfer in burst

    // Write Response Channel
    output     [1:0]  s_axi_bresp,
    output            s_axi_bvalid,   
    input             s_axi_bready,

    // Read Address Channel
    input             s_axi_arvalid, 
    output            s_axi_arready,
    input      [31:0] s_axi_araddr,
    input      [7:0]  s_axi_arlen,    // AXI4 burst length
    input      [2:0]  s_axi_arsize,   // Burst size
    input      [1:0]  s_axi_arburst,  // Burst type
    input      [1:0]  s_axi_arlock,   // Lock type
    input      [3:0]  s_axi_arcache,  // Cache type
    input      [2:0]  s_axi_arprot,   // Protection type

    // Read Data Channel
    output            s_axi_rvalid,  
    input             s_axi_rready,   
    output     [31:0] s_axi_rdata,
    output     [1:0]  s_axi_rresp,
    output            s_axi_rlast     // Last transfer in burst
);

    wire [14:0] s_axi_awaddr_w  = s_axi_awaddr[14:0];
    wire [14:0] s_axi_araddr_w  = s_axi_araddr[14:0];


    wire        bram_en_a;
    wire [3:0]  bram_we_a;
    wire [14:0] bram_addr_a;
    wire [31:0] bram_wrdata_a;
    wire [31:0] bram_rddata_a;

    wire [DATA_W-1:0]          weight_in;
    wire                       load_weight;
    wire [ROWS*DATA_W-1:0]     act_in_flat;
    wire [COLS*ACC_W-1:0]      psum_out_flat;
    wire [COLS*ACC_W-1:0]      o_results;
    wire                       o_done, o_busy;
    wire                       enb;
    wire [0:0]                 web;
    wire [12:0]                addrb;
    wire [31:0]                dinb;
    wire [31:0]                doutb;

    reg [31:0] ctrl_reg;
    reg [31:0] status_reg;

    wire is_reg_addr   = (bram_addr_a == 15'h0000 || bram_addr_a == 15'h0004);
    wire is_ctrl_write = is_reg_addr && bram_we_a[0] && bram_addr_a == 15'h0000 && bram_en_a;

    always @(posedge clk) begin
        if (!resetn)
            ctrl_reg <= 0;
        else if (is_ctrl_write)
            ctrl_reg <= bram_wrdata_a;
        if(ctrl_reg[0] == 1) 
            ctrl_reg[0] <= 0;
    end

    always @(posedge clk) begin
        status_reg[0]    <= o_done;
        status_reg[1]    <= o_busy;
        status_reg[31:2] <= 30'd0;
    end

    wire       bram_en_a_gated  = bram_en_a & ~is_reg_addr;
    wire [0:0] bram_we_a_gated = bram_we_a[0] & ~is_reg_addr;

    wire is_reg_read = bram_en_a && ~|bram_we_a && is_reg_addr;

    reg [14:0] read_addr_reg;
    reg        read_en_reg;
    always @(posedge clk) begin
        read_addr_reg <= bram_addr_a;
        read_en_reg   <= is_reg_read;
    end

    wire [31:0] blk_douta;
    wire [31:0] reg_rddata = (read_addr_reg == 15'h0000) ?
                              {24'b0, ctrl_reg} :
                              {24'b0, status_reg};
    assign bram_rddata_a = read_en_reg ? reg_rddata : blk_douta;
    wire bram_rst_a;
    wire bram_clk_a;
    axi_bram_ctrl_1 accel_bram_ctrl (
        .s_axi_aclk(clk),
        .s_axi_aresetn(resetn),
        .s_axi_awaddr(s_axi_awaddr_w),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr_w),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .bram_rst_a(bram_rst_a),
        .bram_clk_a(bram_clk_a),
        .bram_en_a(bram_en_a),
        .bram_we_a(bram_we_a),
        .bram_addr_a(bram_addr_a),
        .bram_wrdata_a(bram_wrdata_a),
        .bram_rddata_a(bram_rddata_a)
    );

    blk_mem_gen_0 global_buffer (
        .clka(bram_clk_a),
        .ena(bram_en_a_gated),
        .wea(bram_we_a_gated),
        .addra(bram_addr_a[14:2]),
        .dina(bram_wrdata_a),
        .douta(blk_douta),
        .clkb(clk),
        .enb(enb),
        .web(web),
        .addrb(addrb),
        .dinb(dinb),
        .doutb(doutb)
    );

    pe_array #(.DATA_W(DATA_W), .COLS(COLS), .ROWS(ROWS), .ACC_W(ACC_W)) pe_array_inst (
        .clk(clk),
        .rst_n(resetn),
        .load_weight(load_weight),
        .weight_in(weight_in),
        .act_in_flat(act_in_flat),
        .psum_out_flat(psum_out_flat)
    );

    pe_array_controller #(.DATA_W(DATA_W), .COLS(COLS), .ROWS(ROWS), .ACC_W(ACC_W)) pe_array_controller_inst (
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

endmodule
