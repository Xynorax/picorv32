module taxi_axil_axi_adapter (
    input  wire       clk,
    input  wire       rst,

    input  wire       s_axil_awvalid,
    output wire       s_axil_awready,
    input  wire [31:0] s_axil_awaddr,
    input  wire [ 2:0] s_axil_awprot,

    input  wire       s_axil_wvalid,
    output wire       s_axil_wready,
    input  wire [31:0] s_axil_wdata,
    input  wire [ 3:0] s_axil_wstrb,

    output wire       s_axil_bvalid,
    input  wire       s_axil_bready,
    output wire [1:0] s_axil_bresp,

    input  wire       s_axil_arvalid,
    output wire       s_axil_arready,
    input  wire [31:0] s_axil_araddr,
    input  wire [ 2:0] s_axil_arprot,

    output wire       s_axil_rvalid,
    input  wire       s_axil_rready,
    output wire [31:0] s_axil_rdata,
    output wire [1:0] s_axil_rresp,

    output wire       m_axi_awid,
    output wire       m_axi_awvalid,
    input  wire       m_axi_awready,
    output wire [31:0] m_axi_awaddr,
    output wire [ 7:0] m_axi_awlen,
    output wire [ 2:0] m_axi_awsize,
    output wire [ 1:0] m_axi_awburst,
    output wire       m_axi_awlock,
    output wire [ 3:0] m_axi_awcache,
    output wire [ 2:0] m_axi_awprot,
    output wire [ 3:0] m_axi_awqos,
    output wire [ 3:0] m_axi_awregion,

    output wire       m_axi_wvalid,
    input  wire       m_axi_wready,
    output wire [31:0] m_axi_wdata,
    output wire [ 3:0] m_axi_wstrb,
    output wire       m_axi_wlast,

    input  wire       m_axi_bvalid,
    output wire       m_axi_bready,
    input  wire [ 1:0] m_axi_bresp,

    output wire       m_axi_arid,
    output wire       m_axi_arvalid,
    input  wire       m_axi_arready,
    output wire [31:0] m_axi_araddr,
    output wire [ 7:0] m_axi_arlen,
    output wire [ 2:0] m_axi_arsize,
    output wire [ 1:0] m_axi_arburst,
    output wire       m_axi_arlock,
    output wire [ 3:0] m_axi_arcache,
    output wire [ 2:0] m_axi_arprot,
    output wire [ 3:0] m_axi_arqos,
    output wire [ 3:0] m_axi_arregion,

    input  wire       m_axi_rvalid,
    output wire       m_axi_rready,
    input  wire [31:0] m_axi_rdata,
    input  wire [ 1:0] m_axi_rresp,
    input  wire       m_axi_rlast
);

    assign m_axi_awid     = 1'b0;
    assign m_axi_awaddr   = s_axil_awaddr;
    assign m_axi_awlen    = 8'd0;
    assign m_axi_awsize   = 3'd2;
    assign m_axi_awburst  = 2'b01;
    assign m_axi_awlock   = 1'b0;
    assign m_axi_awcache  = 4'b0011;
    assign m_axi_awprot   = s_axil_awprot;
    assign m_axi_awqos    = 4'd0;
    assign m_axi_awregion = 4'd0;
    assign m_axi_awvalid  = s_axil_awvalid;
    assign s_axil_awready = m_axi_awready;

    assign m_axi_wdata  = s_axil_wdata;
    assign m_axi_wstrb  = s_axil_wstrb;
    assign m_axi_wvalid = s_axil_wvalid;
    assign m_axi_wlast  = 1'b1;
    assign s_axil_wready = m_axi_wready;

    assign s_axil_bvalid = m_axi_bvalid;
    assign s_axil_bresp  = m_axi_bresp;
    assign m_axi_bready  = s_axil_bready;

    assign m_axi_arid     = 1'b0;
    assign m_axi_araddr   = s_axil_araddr;
    assign m_axi_arlen    = 8'd0;
    assign m_axi_arsize   = 3'd2;
    assign m_axi_arburst  = 2'b01;
    assign m_axi_arlock   = 1'b0;
    assign m_axi_arcache  = 4'b0011;
    assign m_axi_arprot   = s_axil_arprot;
    assign m_axi_arqos    = 4'd0;
    assign m_axi_arregion = 4'd0;
    assign m_axi_arvalid  = s_axil_arvalid;
    assign s_axil_arready = m_axi_arready;

    assign s_axil_rvalid = m_axi_rvalid;
    assign s_axil_rdata  = m_axi_rdata;
    assign s_axil_rresp  = m_axi_rresp;
    assign m_axi_rready  = s_axil_rready;

endmodule
