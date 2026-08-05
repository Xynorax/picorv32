`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * DMA with AXI4 slave (register config) and AXI4 master (data) interfaces
 */
module dma #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = 1
)
(
    input  wire                  clk,
    input  wire                  rst,

    /*
     * AXI4 slave interface (register configuration)
     */
    input  wire [ID_WIDTH-1:0]   s_axi_awid,
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire [7:0]            s_axi_awlen,
    input  wire [2:0]            s_axi_awsize,
    input  wire [1:0]            s_axi_awburst,
    input  wire                  s_axi_awlock,
    input  wire [3:0]            s_axi_awcache,
    input  wire [2:0]            s_axi_awprot,
    input  wire [3:0]            s_axi_awqos,
    input  wire [3:0]            s_axi_awregion,
    input  wire                  s_axi_awuser,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [STRB_WIDTH-1:0] s_axi_wstrb,
    input  wire                  s_axi_wlast,
    input  wire                  s_axi_wuser,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,
    output wire [ID_WIDTH-1:0]   s_axi_bid,
    output wire [1:0]            s_axi_bresp,
    output wire                  s_axi_buser,
    output wire                  s_axi_bvalid,
    input  wire                  s_axi_bready,
    input  wire [ID_WIDTH-1:0]   s_axi_arid,
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire [7:0]            s_axi_arlen,
    input  wire [2:0]            s_axi_arsize,
    input  wire [1:0]            s_axi_arburst,
    input  wire                  s_axi_arlock,
    input  wire [3:0]            s_axi_arcache,
    input  wire [2:0]            s_axi_arprot,
    input  wire [3:0]            s_axi_arqos,
    input  wire [3:0]            s_axi_arregion,
    input  wire                  s_axi_aruser,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,
    output wire [ID_WIDTH-1:0]   s_axi_rid,
    output wire [DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    output wire                  s_axi_rlast,
    output wire                  s_axi_ruser,
    output wire                  s_axi_rvalid,
    input  wire                  s_axi_rready,

    /*
     * AXI4 master interface (data transfer)
     */
    output wire [ID_WIDTH-1:0]   m_axi_awid,
    output wire [ADDR_WIDTH-1:0] m_axi_awaddr,
    output wire [7:0]            m_axi_awlen,
    output wire [2:0]            m_axi_awsize,
    output wire [1:0]            m_axi_awburst,
    output wire                  m_axi_awlock,
    output wire [3:0]            m_axi_awcache,
    output wire [2:0]            m_axi_awprot,
    output wire [3:0]            m_axi_awqos,
    output wire [3:0]            m_axi_awregion,
    output wire                  m_axi_awuser,
    output wire                  m_axi_awvalid,
    input  wire                  m_axi_awready,
    output wire [DATA_WIDTH-1:0] m_axi_wdata,
    output wire [STRB_WIDTH-1:0] m_axi_wstrb,
    output wire                  m_axi_wlast,
    output wire                  m_axi_wuser,
    output wire                  m_axi_wvalid,
    input  wire                  m_axi_wready,
    input  wire [ID_WIDTH-1:0]   m_axi_bid,
    input  wire [1:0]            m_axi_bresp,
    input  wire                  m_axi_buser,
    input  wire                  m_axi_bvalid,
    output wire                  m_axi_bready,
    output wire [ID_WIDTH-1:0]   m_axi_arid,
    output wire [ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [7:0]            m_axi_arlen,
    output wire [2:0]            m_axi_arsize,
    output wire [1:0]            m_axi_arburst,
    output wire                  m_axi_arlock,
    output wire [3:0]            m_axi_arcache,
    output wire [2:0]            m_axi_arprot,
    output wire [3:0]            m_axi_arqos,
    output wire [3:0]            m_axi_arregion,
    output wire                  m_axi_aruser,
    output wire                  m_axi_arvalid,
    input  wire                  m_axi_arready,
    input  wire [ID_WIDTH-1:0]   m_axi_rid,
    input  wire [DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [1:0]            m_axi_rresp,
    input  wire                  m_axi_rlast,
    input  wire                  m_axi_ruser,
    input  wire                  m_axi_rvalid,
    output wire                  m_axi_rready
);

// register addresses
localparam REG_CTRL     = 3'd0;
localparam REG_STATUS   = 3'd1;
localparam REG_SRC_ADDR = 3'd2;
localparam REG_DST_ADDR = 3'd3;
localparam REG_LEN      = 3'd4;

localparam CTRL_START  = 0;
localparam CTRL_ENABLE = 1;
localparam STATUS_BUSY = 0;
localparam STATUS_DONE = 1;
localparam STATUS_ERR  = 2;

// register file
reg [DATA_WIDTH-1:0] reg_ctrl = '0;
reg [DATA_WIDTH-1:0] reg_status = '0;
reg [DATA_WIDTH-1:0] reg_src_addr = '0;
reg [DATA_WIDTH-1:0] reg_dst_addr = '0;
reg [DATA_WIDTH-1:0] reg_len = '0;

// slave interface signals
reg s_axi_awready_reg = 1'b0;
reg s_axi_wready_reg = 1'b0;
reg s_axi_bvalid_reg = 1'b0;
reg [1:0] s_axi_bresp_reg = 2'b00;
reg s_axi_arready_reg = 1'b0;
reg s_axi_rvalid_reg = 1'b0;
reg [DATA_WIDTH-1:0] s_axi_rdata_reg = '0;
reg [1:0] s_axi_rresp_reg = 2'b00;

// master interface signals
reg m_axi_awvalid_reg = 1'b0;
reg [ADDR_WIDTH-1:0] m_axi_awaddr_reg = '0;
reg [7:0] m_axi_awlen_reg = 8'd0;
reg m_axi_wvalid_reg = 1'b0;
reg [DATA_WIDTH-1:0] m_axi_wdata_reg = '0;
reg [STRB_WIDTH-1:0] m_axi_wstrb_reg = '0;
reg m_axi_wlast_reg = 1'b0;
reg m_axi_bready_reg = 1'b0;
reg m_axi_arvalid_reg = 1'b0;
reg [ADDR_WIDTH-1:0] m_axi_araddr_reg = '0;
reg [7:0] m_axi_arlen_reg = 8'd0;
reg m_axi_rready_reg = 1'b0;

assign s_axi_awready = s_axi_awready_reg;
assign s_axi_wready = s_axi_wready_reg;
assign s_axi_bid = s_axi_awid;
assign s_axi_bresp = s_axi_bresp_reg;
assign s_axi_buser = 1'b0;
assign s_axi_bvalid = s_axi_bvalid_reg;
assign s_axi_arready = s_axi_arready_reg;
assign s_axi_rid = s_axi_arid;
assign s_axi_rdata = s_axi_rdata_reg;
assign s_axi_rresp = s_axi_rresp_reg;
assign s_axi_rlast = s_axi_rvalid_reg;
assign s_axi_ruser = 1'b0;
assign s_axi_rvalid = s_axi_rvalid_reg;

assign m_axi_awid = '0;
assign m_axi_awaddr = m_axi_awaddr_reg;
assign m_axi_awlen = m_axi_awlen_reg;
assign m_axi_awsize = $clog2(STRB_WIDTH);
assign m_axi_awburst = 2'b01;
assign m_axi_awlock = 1'b0;
assign m_axi_awcache = 4'b0011;
assign m_axi_awprot = 3'b010;
assign m_axi_awqos = 4'b0000;
assign m_axi_awregion = 4'b0000;
assign m_axi_awuser = 1'b0;
assign m_axi_awvalid = m_axi_awvalid_reg;
assign m_axi_wdata = m_axi_wdata_reg;
assign m_axi_wstrb = m_axi_wstrb_reg;
assign m_axi_wlast = m_axi_wlast_reg;
assign m_axi_wuser = 1'b0;
assign m_axi_wvalid = m_axi_wvalid_reg;
assign m_axi_bready = m_axi_bready_reg;
assign m_axi_arid = '0;
assign m_axi_araddr = m_axi_araddr_reg;
assign m_axi_arlen = m_axi_arlen_reg;
assign m_axi_arsize = $clog2(STRB_WIDTH);
assign m_axi_arburst = 2'b01;
assign m_axi_arlock = 1'b0;
assign m_axi_arcache = 4'b0011;
assign m_axi_arprot = 3'b010;
assign m_axi_arqos = 4'b0000;
assign m_axi_arregion = 4'b0000;
assign m_axi_aruser = 1'b0;
assign m_axi_arvalid = m_axi_arvalid_reg;
assign m_axi_rready = m_axi_rready_reg;

always @(posedge clk) begin
    s_axi_awready_reg <= 1'b0;
    s_axi_wready_reg <= 1'b0;
    s_axi_bvalid_reg <= 1'b0;

    if (s_axi_awvalid && s_axi_wvalid && !s_axi_awready_reg) begin
        s_axi_awready_reg <= 1'b1;
        s_axi_wready_reg <= 1'b1;
    end

    if (s_axi_awready_reg && s_axi_wready_reg) begin
        s_axi_bvalid_reg <= 1'b1;
        s_axi_bresp_reg <= 2'b00;
        case (s_axi_awaddr[4:2])
            REG_CTRL: begin
                if (s_axi_wstrb[0]) reg_ctrl <= s_axi_wdata;
            end
            REG_SRC_ADDR: begin
                if (s_axi_wstrb[0]) reg_src_addr <= s_axi_wdata;
            end
            REG_DST_ADDR: begin
                if (s_axi_wstrb[0]) reg_dst_addr <= s_axi_wdata;
            end
            REG_LEN: begin
                if (s_axi_wstrb[0]) reg_len <= s_axi_wdata;
            end
            default: begin
                s_axi_bresp_reg <= 2'b10;
            end
        endcase
    end

    s_axi_arready_reg <= 1'b0;
    s_axi_rvalid_reg <= 1'b0;

    if (s_axi_arvalid && !s_axi_arready_reg) begin
        s_axi_arready_reg <= 1'b1;
    end

    if (s_axi_arready_reg) begin
        s_axi_rvalid_reg <= 1'b1;
        s_axi_rresp_reg <= 2'b00;
        case (s_axi_araddr[4:2])
            REG_CTRL:     s_axi_rdata_reg <= reg_ctrl;
            REG_STATUS:   s_axi_rdata_reg <= reg_status;
            REG_SRC_ADDR: s_axi_rdata_reg <= reg_src_addr;
            REG_DST_ADDR: s_axi_rdata_reg <= reg_dst_addr;
            REG_LEN:      s_axi_rdata_reg <= reg_len;
            default: begin
                s_axi_rdata_reg <= '0;
                s_axi_rresp_reg <= 2'b10;
            end
        endcase
    end

    if (rst) begin
        s_axi_awready_reg <= 1'b0;
        s_axi_wready_reg <= 1'b0;
        s_axi_bvalid_reg <= 1'b0;
        s_axi_arready_reg <= 1'b0;
        s_axi_rvalid_reg <= 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        reg_ctrl <= '0;
        reg_status <= '0;
        reg_src_addr <= '0;
        reg_dst_addr <= '0;
        reg_len <= '0;

        m_axi_awvalid_reg <= 1'b0;
        m_axi_awaddr_reg <= '0;
        m_axi_awlen_reg <= 8'd0;
        m_axi_wvalid_reg <= 1'b0;
        m_axi_wdata_reg <= '0;
        m_axi_wstrb_reg <= '0;
        m_axi_wlast_reg <= 1'b0;
        m_axi_bready_reg <= 1'b0;
        m_axi_arvalid_reg <= 1'b0;
        m_axi_araddr_reg <= '0;
        m_axi_arlen_reg <= 8'd0;
        m_axi_rready_reg <= 1'b0;
    end
end

endmodule

`resetall
