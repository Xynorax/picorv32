// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

`timescale 1 ns / 1 ps

`ifndef VERILATOR
module testbench #(
	parameter AXI_TEST = 0,
	parameter VERBOSE = 0
);
	reg clk = 1;
	reg resetn = 0;
	wire trap;

	always #5 clk = ~clk;

	initial begin
		repeat (100) @(posedge clk);
		resetn <= 1;
	end

	initial begin
		if ($test$plusargs("vcd")) begin
			$dumpfile("testbench.vcd");
			$dumpvars(0, testbench);
		end
		repeat (100000000) @(posedge clk);
		$display("TIMEOUT");
		$finish;
	end

	always @(posedge clk) begin
		if (trap) begin
			$display("TRAP at time %t", $time);
			$finish;
		end
	end

	wire trace_valid;
	wire [35:0] trace_data;
	integer trace_file;

	initial begin
		if ($test$plusargs("trace")) begin
			trace_file = $fopen("testbench.trace", "w");
			repeat (10) @(posedge clk);
			while (!trap) begin
				@(negedge clk);
				if (trace_valid)
					$fwrite(trace_file, "%x\n", trace_data);
			end
			$fclose(trace_file);
			$display("Finished writing testbench.trace.");
		end
	end

	picorv32_wrapper #(
		.AXI_TEST (AXI_TEST),
		.VERBOSE  (VERBOSE)
	) top (
		.clk(clk),
		.resetn(resetn),
		.trap(trap),
		.trace_valid(trace_valid),
		.trace_data(trace_data)
	);
endmodule
`endif

module picorv32_wrapper #(
	parameter AXI_TEST = 0,
	parameter VERBOSE = 0
) (
	input clk,
	input resetn,
	output trap,
	output trace_valid,
	output [35:0] trace_data
);
	wire tests_passed;
	reg [31:0] irq = 0;

	reg [15:0] count_cycle = 0;
	always @(posedge clk) count_cycle <= resetn ? count_cycle + 1 : 0;

	always @* begin
		irq = 0;
		irq[4] = &count_cycle[12:0];
		irq[5] = &count_cycle[15:0];
	end

	wire        mem_axi_awvalid;
	wire        mem_axi_awready;
	wire [31:0] mem_axi_awaddr;
	wire [ 2:0] mem_axi_awprot;

	wire        mem_axi_wvalid;
	wire        mem_axi_wready;
	wire [31:0] mem_axi_wdata;
	wire [ 3:0] mem_axi_wstrb;

	wire        mem_axi_bvalid;
	wire        mem_axi_bready;

	wire        mem_axi_arvalid;
	wire        mem_axi_arready;
	wire [31:0] mem_axi_araddr;
	wire [ 2:0] mem_axi_arprot;

	wire        mem_axi_rvalid;
	wire        mem_axi_rready;
	wire [31:0] mem_axi_rdata;

`ifdef DIRECT_MEM
	axi4_memory #(
    .AXI_TEST (AXI_TEST),
    .VERBOSE  (VERBOSE)
	) mem (
		.clk             (clk             ),
		.mem_axi_awvalid (mem_axi_awvalid ),
		.mem_axi_awready (mem_axi_awready ),
		.mem_axi_awaddr  (mem_axi_awaddr  ),
		.mem_axi_awprot  (mem_axi_awprot  ),

		.mem_axi_wvalid  (mem_axi_wvalid  ),
		.mem_axi_wready  (mem_axi_wready  ),
		.mem_axi_wdata   (mem_axi_wdata   ),
		.mem_axi_wstrb   (mem_axi_wstrb   ),

		.mem_axi_bvalid  (mem_axi_bvalid  ),
		.mem_axi_bready  (mem_axi_bready  ),

		.mem_axi_arvalid (mem_axi_arvalid ),
		.mem_axi_arready (mem_axi_arready ),
		.mem_axi_araddr  (mem_axi_araddr  ),
		.mem_axi_arprot  (mem_axi_arprot  ),

		.mem_axi_rvalid  (mem_axi_rvalid  ),
		.mem_axi_rready  (mem_axi_rready  ),
		.mem_axi_rdata   (mem_axi_rdata   ),

		.tests_passed    (tests_passed     )
	);
`else
	wire        s0_awvalid, s0_awready; wire [31:0] s0_awaddr;
	wire        s0_wvalid,  s0_wready;  wire [31:0] s0_wdata; wire [3:0] s0_wstrb;
	wire        s0_bvalid,  s0_bready;
	wire        s0_arvalid, s0_arready; wire [31:0] s0_araddr;
	wire        s0_rvalid,  s0_rready;  wire [31:0] s0_rdata;
	wire [3:0]  s0_awid, s0_bid, s0_arid, s0_rid;
	wire [7:0]  s0_awlen, s0_arlen;
	wire [2:0]  s0_awsize, s0_arsize;
	wire [1:0]  s0_awburst, s0_arburst;
	wire 		s0_wlast, s0_rlast;
	wire [1:0]  s0_bresp, s0_rresp;
	wire [1:0]  s1_bresp, s1_rresp;
	wire        s1_awvalid, s1_awready; wire [31:0] s1_awaddr;
	wire        s1_wvalid,  s1_wready;  wire [31:0] s1_wdata; wire [3:0] s1_wstrb;
	wire        s1_bvalid,  s1_bready;
	wire        s1_arvalid, s1_arready; wire [31:0] s1_araddr;
	wire        s1_rvalid,  s1_rready;  wire [31:0] s1_rdata;
	wire [3:0]  s1_awid, s1_bid, s1_arid, s1_rid;
	wire [7:0]  s1_awlen, s1_arlen;
	wire [2:0]  s1_awsize, s1_arsize;
	wire [1:0]  s1_awburst, s1_arburst;
	wire 		s1_wlast, s1_rlast;
	wire        s2_awvalid, s2_awready; wire [31:0] s2_awaddr;
	wire        s2_wvalid,  s2_wready;  wire [31:0] s2_wdata; wire [3:0] s2_wstrb;
	wire        s2_bvalid,  s2_bready;  wire [1:0] s2_bresp;
	wire        s2_arvalid, s2_arready; wire [31:0] s2_araddr;
	wire        s2_rvalid,  s2_rready;  wire [31:0] s2_rdata; wire [1:0] s2_rresp;

	// taxi_axi_if arrays for interconnect (separate read/write channels)
	taxi_axi_if s_axi_wr_if [2] ();
	taxi_axi_if s_axi_rd_if [2] ();
	taxi_axi_if m_axi_wr_if [3] ();
	taxi_axi_if m_axi_rd_if [3] ();
	wire [31:0] cdma_tvect_out;
	wire cdma_introut;
	taxi_axil_if s_axil_wr();
	taxi_axil_if s_axil_rd();
	taxi_axi_if  m_axi_wr();
	taxi_axi_if  m_axi_rd();

	taxi_axi_if  m_axi_dma();

	// picorv32 -> adapter (AXI4-lite slave interface)
	always @* begin
		s_axil_wr.awvalid  = mem_axi_awvalid;
		s_axil_wr.awaddr   = mem_axi_awaddr;
		s_axil_wr.awprot   = mem_axi_awprot;
		s_axil_wr.wvalid   = mem_axi_wvalid;
		s_axil_wr.wdata    = mem_axi_wdata;
		s_axil_wr.wstrb    = mem_axi_wstrb;
		s_axil_wr.bready   = mem_axi_bready;

		s_axil_rd.arvalid  = mem_axi_arvalid;
		s_axil_rd.araddr   = mem_axi_araddr;
		s_axil_rd.arprot   = mem_axi_arprot;
		s_axil_rd.rready   = mem_axi_rready;
	end

	assign mem_axi_awready = s_axil_wr.awready;
	assign mem_axi_wready  = s_axil_wr.wready;
	assign mem_axi_bvalid  = s_axil_wr.bvalid;
	assign mem_axi_arready = s_axil_rd.arready;
	assign mem_axi_rvalid  = s_axil_rd.rvalid;
	assign mem_axi_rdata   = s_axil_rd.rdata;

	// Bridge: adapter -> interconnect slave port 0 (write)
	assign s_axi_wr_if[0].awvalid = m_axi_wr.awvalid;
	assign s_axi_wr_if[0].awaddr  = m_axi_wr.awaddr;
	assign s_axi_wr_if[0].awlen   = m_axi_wr.awlen;
	assign s_axi_wr_if[0].awsize  = m_axi_wr.awsize;
	assign s_axi_wr_if[0].awburst = m_axi_wr.awburst;
	assign s_axi_wr_if[0].awlock  = m_axi_wr.awlock;
	assign s_axi_wr_if[0].awcache = m_axi_wr.awcache;
	assign s_axi_wr_if[0].awprot  = m_axi_wr.awprot;
	assign s_axi_wr_if[0].awqos   = m_axi_wr.awqos;
	assign s_axi_wr_if[0].awuser  = m_axi_wr.awuser;
	assign s_axi_wr_if[0].awid    = m_axi_wr.awid;
	assign m_axi_wr.awready = s_axi_wr_if[0].awready;

	assign s_axi_wr_if[0].wvalid = m_axi_wr.wvalid;
	assign s_axi_wr_if[0].wdata  = m_axi_wr.wdata;
	assign s_axi_wr_if[0].wstrb  = m_axi_wr.wstrb;
	assign s_axi_wr_if[0].wlast  = m_axi_wr.wlast;
	assign s_axi_wr_if[0].wuser  = m_axi_wr.wuser;
	assign m_axi_wr.wready = s_axi_wr_if[0].wready;

	assign m_axi_wr.bvalid = s_axi_wr_if[0].bvalid;
	assign m_axi_wr.bid    = s_axi_wr_if[0].bid;
	assign m_axi_wr.bresp  = s_axi_wr_if[0].bresp;
	assign m_axi_wr.buser  = s_axi_wr_if[0].buser;
	assign s_axi_wr_if[0].bready = m_axi_wr.bready;

	// Bridge: adapter -> interconnect slave port 0 (read)
	assign s_axi_rd_if[0].arvalid = m_axi_rd.arvalid;
	assign s_axi_rd_if[0].araddr  = m_axi_rd.araddr;
	assign s_axi_rd_if[0].arlen   = m_axi_rd.arlen;
	assign s_axi_rd_if[0].arsize  = m_axi_rd.arsize;
	assign s_axi_rd_if[0].arburst = m_axi_rd.arburst;
	assign s_axi_rd_if[0].arlock  = m_axi_rd.arlock;
	assign s_axi_rd_if[0].arcache = m_axi_rd.arcache;
	assign s_axi_rd_if[0].arprot  = m_axi_rd.arprot;
	assign s_axi_rd_if[0].arqos   = m_axi_rd.arqos;
	assign s_axi_rd_if[0].aruser  = m_axi_rd.aruser;
	assign s_axi_rd_if[0].arid    = m_axi_rd.arid;
	assign m_axi_rd.arready = s_axi_rd_if[0].arready;

	assign m_axi_rd.rvalid = s_axi_rd_if[0].rvalid;
	assign m_axi_rd.rid    = s_axi_rd_if[0].rid;
	assign m_axi_rd.rdata  = s_axi_rd_if[0].rdata;
	assign m_axi_rd.rresp  = s_axi_rd_if[0].rresp;
	assign m_axi_rd.rlast  = s_axi_rd_if[0].rlast;
	assign m_axi_rd.ruser  = s_axi_rd_if[0].ruser;
	assign s_axi_rd_if[0].rready = m_axi_rd.rready;

	// Bridge: DMA -> interconnect slave port 1 (write)
	assign s_axi_wr_if[1].awvalid = m_axi_dma.awvalid;
	assign s_axi_wr_if[1].awaddr  = m_axi_dma.awaddr;
	assign s_axi_wr_if[1].awlen   = m_axi_dma.awlen;
	assign s_axi_wr_if[1].awsize  = m_axi_dma.awsize;
	assign s_axi_wr_if[1].awburst = m_axi_dma.awburst;
	assign s_axi_wr_if[1].awlock  = 1'b0;
	assign s_axi_wr_if[1].awcache = m_axi_dma.awcache;
	assign s_axi_wr_if[1].awprot  = m_axi_dma.awprot;
	assign s_axi_wr_if[1].awqos   = 4'd0;
	assign s_axi_wr_if[1].awuser  = '0;
	assign s_axi_wr_if[1].awid    = '0;
	assign m_axi_dma.awready = s_axi_wr_if[1].awready;

	assign s_axi_wr_if[1].wvalid = m_axi_dma.wvalid;
	assign s_axi_wr_if[1].wdata  = m_axi_dma.wdata;
	assign s_axi_wr_if[1].wstrb  = m_axi_dma.wstrb;
	assign s_axi_wr_if[1].wlast  = m_axi_dma.wlast;
	assign s_axi_wr_if[1].wuser  = '0;
	assign m_axi_dma.wready = s_axi_wr_if[1].wready;

	assign m_axi_dma.bvalid = s_axi_wr_if[1].bvalid;
	assign m_axi_dma.bid    = s_axi_wr_if[1].bid;
	assign m_axi_dma.bresp  = s_axi_wr_if[1].bresp;
	assign m_axi_dma.buser  = s_axi_wr_if[1].buser;
	assign s_axi_wr_if[1].bready = m_axi_dma.bready;

	// Bridge: DMA -> interconnect slave port 1 (read)
	assign s_axi_rd_if[1].arvalid = m_axi_dma.arvalid;
	assign s_axi_rd_if[1].araddr  = m_axi_dma.araddr;
	assign s_axi_rd_if[1].arlen   = m_axi_dma.arlen;
	assign s_axi_rd_if[1].arsize  = m_axi_dma.arsize;
	assign s_axi_rd_if[1].arburst = m_axi_dma.arburst;
	assign s_axi_rd_if[1].arlock  = 1'b0;
	assign s_axi_rd_if[1].arcache = m_axi_dma.arcache;
	assign s_axi_rd_if[1].arprot  = m_axi_dma.arprot;
	assign s_axi_rd_if[1].arqos   = 4'd0;
	assign s_axi_rd_if[1].aruser  = '0;
	assign s_axi_rd_if[1].arid    = '0;
	assign m_axi_dma.arready = s_axi_rd_if[1].arready;

	assign m_axi_dma.rvalid = s_axi_rd_if[1].rvalid;
	assign m_axi_dma.rid    = s_axi_rd_if[1].rid;
	assign m_axi_dma.rdata  = s_axi_rd_if[1].rdata;
	assign m_axi_dma.rresp  = s_axi_rd_if[1].rresp;
	assign m_axi_dma.rlast  = s_axi_rd_if[1].rlast;
	assign m_axi_dma.ruser  = s_axi_rd_if[1].ruser;
	assign s_axi_rd_if[1].rready = m_axi_dma.rready;

	taxi_axil_axi_adapter adapter (
		.clk(clk), .rst(!resetn),

		.s_axil_wr(s_axil_wr),
		.s_axil_rd(s_axil_rd),

		.m_axi_wr(m_axi_wr),
		.m_axi_rd(m_axi_rd)
	);

	// Bridge: interconnect master port 0 -> accel (write)
	assign s1_awvalid = m_axi_wr_if[0].awvalid;
	assign s1_awaddr  = m_axi_wr_if[0].awaddr;
	assign s1_awlen   = m_axi_wr_if[0].awlen;
	assign s1_awsize  = m_axi_wr_if[0].awsize;
	assign s1_awburst = m_axi_wr_if[0].awburst;
	assign s1_awlock  = m_axi_wr_if[0].awlock;
	assign s1_awcache = m_axi_wr_if[0].awcache;
	assign s1_awprot  = m_axi_wr_if[0].awprot;
	assign m_axi_wr_if[0].awready = s1_awready;

	assign s1_wvalid  = m_axi_wr_if[0].wvalid;
	assign s1_wdata   = m_axi_wr_if[0].wdata;
	assign s1_wstrb   = m_axi_wr_if[0].wstrb;
	assign s1_wlast   = m_axi_wr_if[0].wlast;
	assign m_axi_wr_if[0].wready = s1_wready;

	assign m_axi_wr_if[0].bvalid = s1_bvalid;
	assign m_axi_wr_if[0].bresp  = s1_bresp;
	assign m_axi_wr_if[0].bid    = '0;
	assign m_axi_wr_if[0].buser  = '0;
	assign s1_bready  = m_axi_wr_if[0].bready;

	// Bridge: interconnect master port 0 -> accel (read)
	assign s1_arvalid = m_axi_rd_if[0].arvalid;
	assign s1_araddr  = m_axi_rd_if[0].araddr;
	assign s1_arlen   = m_axi_rd_if[0].arlen;
	assign s1_arsize  = m_axi_rd_if[0].arsize;
	assign s1_arburst = m_axi_rd_if[0].arburst;
	assign s1_arlock  = m_axi_rd_if[0].arlock;
	assign s1_arcache = m_axi_rd_if[0].arcache;
	assign s1_arprot  = m_axi_rd_if[0].arprot;
	assign m_axi_rd_if[0].arready = s1_arready;

	assign m_axi_rd_if[0].rvalid = s1_rvalid;
	assign m_axi_rd_if[0].rdata  = s1_rdata;
	assign m_axi_rd_if[0].rresp  = s1_rresp;
	assign m_axi_rd_if[0].rlast  = s1_rlast;
	assign m_axi_rd_if[0].rid    = '0;
	assign m_axi_rd_if[0].ruser  = '0;
	assign s1_rready  = m_axi_rd_if[0].rready;

	// Bridge: interconnect master port 1 -> memory (write)
	assign s0_awvalid = m_axi_wr_if[1].awvalid;
	assign s0_awaddr  = m_axi_wr_if[1].awaddr;
	assign s0_awlen   = m_axi_wr_if[1].awlen;
	assign s0_awsize  = m_axi_wr_if[1].awsize;
	assign s0_awburst = m_axi_wr_if[1].awburst;
	assign s0_awid    = m_axi_wr_if[1].awid[3:0];
	assign m_axi_wr_if[1].awready = s0_awready;

	assign s0_wvalid  = m_axi_wr_if[1].wvalid;
	assign s0_wdata   = m_axi_wr_if[1].wdata;
	assign s0_wstrb   = m_axi_wr_if[1].wstrb;
	assign s0_wlast   = m_axi_wr_if[1].wlast;
	assign m_axi_wr_if[1].wready = s0_wready;

	assign m_axi_wr_if[1].bvalid = s0_bvalid;
	assign m_axi_wr_if[1].bid    = {4'b0, s0_bid};
	assign m_axi_wr_if[1].bresp  = s0_bresp;
	assign s0_bready  = m_axi_wr_if[1].bready;

	// Bridge: interconnect master port 1 -> memory (read)
	assign s0_arvalid = m_axi_rd_if[1].arvalid;
	assign s0_araddr  = m_axi_rd_if[1].araddr;
	assign s0_arlen   = m_axi_rd_if[1].arlen;
	assign s0_arsize  = m_axi_rd_if[1].arsize;
	assign s0_arburst = m_axi_rd_if[1].arburst;
	assign s0_arid    = m_axi_rd_if[1].arid[3:0];
	assign m_axi_rd_if[1].arready = s0_arready;

	assign m_axi_rd_if[1].rvalid = s0_rvalid;
	assign m_axi_rd_if[1].rdata  = s0_rdata;
	assign m_axi_rd_if[1].rresp  = s0_rresp;
	assign m_axi_rd_if[1].rlast  = s0_rlast;
	assign m_axi_rd_if[1].rid    = {4'b0, s0_rid};
	assign s0_rready  = m_axi_rd_if[1].rready;

	// Bridge: interconnect master port 2 -> DMA config (AXI-Lite, write)
	assign s2_awvalid = m_axi_wr_if[2].awvalid;
	assign s2_awaddr  = m_axi_wr_if[2].awaddr;
	assign m_axi_wr_if[2].awready = s2_awready;

	assign s2_wvalid  = m_axi_wr_if[2].wvalid;
	assign s2_wdata   = m_axi_wr_if[2].wdata;
	assign s2_wstrb   = m_axi_wr_if[2].wstrb;
	assign m_axi_wr_if[2].wready = s2_wready;

	assign m_axi_wr_if[2].bvalid = s2_bvalid;
	assign m_axi_wr_if[2].bresp  = s2_bresp;
	assign m_axi_wr_if[2].bid    = '0;
	assign m_axi_wr_if[2].buser  = '0;
	assign s2_bready  = m_axi_wr_if[2].bready;

	// Bridge: interconnect master port 2 -> DMA config (AXI-Lite, read)
	assign s2_arvalid = m_axi_rd_if[2].arvalid;
	assign s2_araddr  = m_axi_rd_if[2].araddr;
	assign m_axi_rd_if[2].arready = s2_arready;

	assign m_axi_rd_if[2].rvalid = s2_rvalid;
	assign m_axi_rd_if[2].rdata  = s2_rdata;
	assign m_axi_rd_if[2].rresp  = s2_rresp;
	assign m_axi_rd_if[2].rlast  = 1'b1;
	assign m_axi_rd_if[2].rid    = '0;
	assign m_axi_rd_if[2].ruser  = '0;
	assign s2_rready  = m_axi_rd_if[2].rready;

	taxi_axi_interconnect #(
		.S_COUNT(2), // 0: picorv32, 1: DMA
		.M_COUNT(3), // 0: accel, 1: memory, 2: DMA config
		.ADDR_W(32),
		.M_REGIONS(2),
		.M_BASE_ADDR({32'h40000000, 32'h40000000, 32'h20000000, 32'h00000000, 32'h00000000, 32'h30000000}),
		.M_ADDR_W({32'd0, 32'd16, 32'd28, 32'd29, 32'd0, 32'd16})
	) axi_intercon (
		.clk(clk), .rst(!resetn),

		.s_axi_wr(s_axi_wr_if),
		.s_axi_rd(s_axi_rd_if),

		.m_axi_wr(m_axi_wr_if),
		.m_axi_rd(m_axi_rd_if)
	);

	ai_accel_axi accel (
		.clk(clk), .resetn(resetn),
		.s_axi_awvalid(s1_awvalid), .s_axi_awready(s1_awready), .s_axi_awaddr(s1_awaddr),
		.s_axi_awlen(s1_awlen),
		.s_axi_awsize(s1_awsize),
		.s_axi_awburst(s1_awburst),
		.s_axi_awlock(s1_awlock),
		.s_axi_awcache(s1_awcache),
		.s_axi_awprot(s1_awprot),
		.s_axi_wvalid(s1_wvalid),   .s_axi_wready(s1_wready),   .s_axi_wdata(s1_wdata), .s_axi_wstrb(s1_wstrb),
		.s_axi_wlast(s1_wlast), .s_axi_bresp(s1_bresp),
		.s_axi_bvalid(s1_bvalid),   .s_axi_bready(s1_bready),
		.s_axi_arvalid(s1_arvalid), .s_axi_arready(s1_arready), .s_axi_araddr(s1_araddr),
		.s_axi_rvalid(s1_rvalid),   .s_axi_rready(s1_rready),   .s_axi_rdata(s1_rdata), 
		.s_axi_arlen(s1_arlen),
		.s_axi_arsize(s1_arsize),
		.s_axi_arburst(s1_arburst),
		.s_axi_arlock(s1_arlock),
		.s_axi_arcache(s1_arcache),
		.s_axi_arprot(s1_arprot),
		.s_axi_rresp(s1_rresp),
		.s_axi_rlast(s1_rlast)
	);

	// Replace axi4_mem with blk_mem_gen_1
	blk_mem_gen_1 flash_mem (
		.rsta_busy(),          // output wire rsta_busy
		.rstb_busy(),          // output wire rstb_busy
		.s_aclk(clk),                // input wire s_aclk
		.s_aresetn(resetn),          // input wire s_aresetn
		.s_axi_awid(s0_awid),        // input wire [3 : 0] s_axi_awid
		.s_axi_awaddr(s0_awaddr),    // input wire [31 : 0] s_axi_awaddr
		.s_axi_awlen(s0_awlen),      // input wire [7 : 0] s_axi_awlen
		.s_axi_awsize(s0_awsize),    // input wire [2 : 0] s_axi_awsize
		.s_axi_awburst(s0_awburst),  // input wire [1 : 0] s_axi_awburst
		.s_axi_awvalid(s0_awvalid),  // input wire s_axi_awvalid
		.s_axi_awready(s0_awready),  // output wire s_axi_awready
		.s_axi_wdata(s0_wdata),      // input wire [31 : 0] s_axi_wdata
		.s_axi_wstrb(s0_wstrb),      // input wire [3 : 0] s_axi_wstrb
		.s_axi_wlast(s0_wlast),      // input wire s_axi_wlast
		.s_axi_wvalid(s0_wvalid),    // input wire s_axi_wvalid
		.s_axi_wready(s0_wready),    // output wire s_axi_wready
		.s_axi_bid(s0_bid),          // output wire [3 : 0] s_axi_bid
		.s_axi_bresp(s0_bresp),      // output wire [1 : 0] s_axi_bresp
		.s_axi_bvalid(s0_bvalid),    // output wire s_axi_bvalid
		.s_axi_bready(s0_bready),    // input wire s_axi_bready
		.s_axi_arid(s0_arid),        // input wire [3 : 0] s_axi_arid
		.s_axi_araddr(s0_araddr),    // input wire [31 : 0] s_axi_araddr
		.s_axi_arlen(s0_arlen),      // input wire [7 : 0] s_axi_arlen
		.s_axi_arsize(s0_arsize),    // input wire [2 : 0] s_axi_arsize
		.s_axi_arburst(s0_arburst),  // input wire [1 : 0] s_axi_arburst
		.s_axi_arvalid(s0_arvalid),  // input wire s_axi_arvalid
		.s_axi_arready(s0_arready),  // output wire s_axi_arready
		.s_axi_rid(s0_rid),          // output wire [3 : 0] s_axi_rid
		.s_axi_rdata(s0_rdata),      // output wire [31 : 0] s_axi_rdata
		.s_axi_rresp(s0_rresp),      // output wire [1 : 0] s_axi_rresp
		.s_axi_rlast(s0_rlast),      // output wire s_axi_rlast
		.s_axi_rvalid(s0_rvalid),    // output wire s_axi_rvalid
		.s_axi_rready(s0_rready)    // input wire s_axi_rready
		);
	axi_cdma_0 dma0 (
		.m_axi_aclk(clk),                  // input wire m_axi_aclk
		.s_axi_lite_aclk(clk),        // input wire s_axi_lite_aclk
		.s_axi_lite_aresetn(resetn),  // input wire s_axi_lite_aresetn
		.cdma_introut(cdma_introut),              // output wire cdma_introut
		.s_axi_lite_awready(s2_awready),  // output wire s_axi_lite_awready
		.s_axi_lite_awvalid(s2_awvalid),  // input wire s_axi_lite_awvalid
		.s_axi_lite_awaddr(s2_awaddr),    // input wire [5 : 0] s_axi_lite_awaddr
		.s_axi_lite_wready(s2_wready),    // output wire s_axi_lite_wready
		.s_axi_lite_wvalid(s2_wvalid),    // input wire s_axi_lite_wvalid
		.s_axi_lite_wdata(s2_wdata),      // input wire [31 : 0] s_axi_lite_wdata
		.s_axi_lite_bready(s2_bready),    // input wire s_axi_lite_bready
		.s_axi_lite_bvalid(s2_bvalid),    // output wire s_axi_lite_bvalid
		.s_axi_lite_bresp(s2_bresp),      // output wire [1 : 0] s_axi_lite_bresp
		.s_axi_lite_arready(s2_arready),  // output wire s_axi_lite_arready
		.s_axi_lite_arvalid(s2_arvalid),  // input wire s_axi_lite_arvalid
		.s_axi_lite_araddr(s2_araddr),    // input wire [5 : 0] s_axi_lite_araddr
		.s_axi_lite_rready(s2_rready),    // input wire s_axi_lite_rready
		.s_axi_lite_rvalid(s2_rvalid),    // output wire s_axi_lite_rvalid
		.s_axi_lite_rdata(s2_rdata),      // output wire [31 : 0] s_axi_lite_rdata
		.s_axi_lite_rresp(s2_rresp),      // output wire [1 : 0] s_axi_lite_rresp
		.m_axi_arready(m_axi_dma.arready),            // input wire m_axi_arready
		.m_axi_arvalid(m_axi_dma.arvalid),            // output wire m_axi_arvalid
		.m_axi_araddr(m_axi_dma.araddr),              // output wire [31 : 0] m_axi_araddr
		.m_axi_arlen(m_axi_dma.arlen),                // output wire [7 : 0] m_axi_arlen
		.m_axi_arsize(m_axi_dma.arsize),              // output wire [2 : 0] m_axi_arsize
		.m_axi_arburst(m_axi_dma.arburst),            // output wire [1 : 0] m_axi_arburst
		.m_axi_arprot(m_axi_dma.arprot),              // output wire [2 : 0] m_axi_arprot
		.m_axi_arcache(m_axi_dma.arcache),            // output wire [3 : 0] m_axi_arcache
		.m_axi_rready(m_axi_dma.rready),              // output wire m_axi_rready
		.m_axi_rvalid(m_axi_dma.rvalid),              // input wire m_axi_rvalid
		.m_axi_rdata(m_axi_dma.rdata),                // input wire [31 : 0] m_axi_rdata
		.m_axi_rresp(m_axi_dma.rresp),                // input wire [1 : 0] m_axi_rresp
		.m_axi_rlast(m_axi_dma.rlast),                // input wire m_axi_rlast
		.m_axi_awready(m_axi_dma.awready),            // input wire m_axi_awready
		.m_axi_awvalid(m_axi_dma.awvalid),            // output wire m_axi_awvalid
		.m_axi_awaddr(m_axi_dma.awaddr),              // output wire [31 : 0] m_axi_awaddr
		.m_axi_awlen(m_axi_dma.awlen),                // output wire [7 : 0] m_axi_awlen
		.m_axi_awsize(m_axi_dma.awsize),              // output wire [2 : 0] m_axi_awsize
		.m_axi_awburst(m_axi_dma.awburst),            // output wire [1 : 0] m_axi_awburst
		.m_axi_awprot(m_axi_dma.awprot),              // output wire [2 : 0] m_axi_awprot
		.m_axi_awcache(m_axi_dma.awcache),            // output wire [3 : 0] m_axi_awcache
		.m_axi_wready(m_axi_dma.wready),              // input wire m_axi_wready
		.m_axi_wvalid(m_axi_dma.wvalid),              // output wire m_axi_wvalid
		.m_axi_wdata(m_axi_dma.wdata),                // output wire [31 : 0] m_axi_wdata
		.m_axi_wstrb(m_axi_dma.wstrb),                // output wire [3 : 0] m_axi_wstrb
		.m_axi_wlast(m_axi_dma.wlast),                // output wire m_axi_wlast
		.m_axi_bready(m_axi_dma.bready),              // output wire m_axi_bready
		.m_axi_bvalid(m_axi_dma.bvalid),              // input wire m_axi_bvalid
		.m_axi_bresp(m_axi_dma.bresp),                // input wire [1 : 0] m_axi_bresp
		.cdma_tvect_out(cdma_tvect_out)          // output wire [31 : 0] cdma_tvect_out
	);
`endif

`ifdef RISCV_FORMAL
	wire        rvfi_valid;
	wire [63:0] rvfi_order;
	wire [31:0] rvfi_insn;
	wire        rvfi_trap;
	wire        rvfi_halt;
	wire        rvfi_intr;
	wire [4:0]  rvfi_rs1_addr;
	wire [4:0]  rvfi_rs2_addr;
	wire [31:0] rvfi_rs1_rdata;
	wire [31:0] rvfi_rs2_rdata;
	wire [4:0]  rvfi_rd_addr;
	wire [31:0] rvfi_rd_wdata;
	wire [31:0] rvfi_pc_rdata;
	wire [31:0] rvfi_pc_wdata;
	wire [31:0] rvfi_mem_addr;
	wire [3:0]  rvfi_mem_rmask;
	wire [3:0]  rvfi_mem_wmask;
	wire [31:0] rvfi_mem_rdata;
	wire [31:0] rvfi_mem_wdata;
`endif

	picorv32_axi #(
`ifndef SYNTH_TEST
`ifdef SP_TEST
		.ENABLE_REGS_DUALPORT(0),
`endif

		.COMPRESSED_ISA(1),

		.ENABLE_MUL(1),
		.ENABLE_DIV(1),
		.ENABLE_IRQ(1),
		.ENABLE_TRACE(1)
`endif
	) uut (
		.clk            (clk            ),
		.resetn         (resetn         ),
		.trap           (trap           ),
		.mem_axi_awvalid(mem_axi_awvalid),
		.mem_axi_awready(mem_axi_awready),
		.mem_axi_awaddr (mem_axi_awaddr ),
		.mem_axi_awprot (mem_axi_awprot ),
		.mem_axi_wvalid (mem_axi_wvalid ),
		.mem_axi_wready (mem_axi_wready ),
		.mem_axi_wdata  (mem_axi_wdata  ),
		.mem_axi_wstrb  (mem_axi_wstrb  ),
		.mem_axi_bvalid (mem_axi_bvalid ),
		.mem_axi_bready (mem_axi_bready ),
		.mem_axi_arvalid(mem_axi_arvalid),
		.mem_axi_arready(mem_axi_arready),
		.mem_axi_araddr (mem_axi_araddr ),
		.mem_axi_arprot (mem_axi_arprot ),
		.mem_axi_rvalid (mem_axi_rvalid ),
		.mem_axi_rready (mem_axi_rready ),
		.mem_axi_rdata  (mem_axi_rdata  ),
		.irq            (irq            ),
`ifdef RISCV_FORMAL
		.rvfi_valid     (rvfi_valid     ),
		.rvfi_order     (rvfi_order     ),
		.rvfi_insn      (rvfi_insn      ),
		.rvfi_trap      (rvfi_trap      ),
		.rvfi_halt      (rvfi_halt      ),
		.rvfi_intr      (rvfi_intr      ),
		.rvfi_rs1_addr  (rvfi_rs1_addr  ),
		.rvfi_rs2_addr  (rvfi_rs2_addr  ),
		.rvfi_rs1_rdata (rvfi_rs1_rdata ),
		.rvfi_rs2_rdata (rvfi_rs2_rdata ),
		.rvfi_rd_addr   (rvfi_rd_addr   ),
		.rvfi_rd_wdata  (rvfi_rd_wdata  ),
		.rvfi_pc_rdata  (rvfi_pc_rdata  ),
		.rvfi_pc_wdata  (rvfi_pc_wdata  ),
		.rvfi_mem_addr  (rvfi_mem_addr  ),
		.rvfi_mem_rmask (rvfi_mem_rmask ),
		.rvfi_mem_wmask (rvfi_mem_wmask ),
		.rvfi_mem_rdata (rvfi_mem_rdata ),
		.rvfi_mem_wdata (rvfi_mem_wdata ),
`endif
		.trace_valid    (trace_valid    ),
		.trace_data     (trace_data     )
	);

`ifdef RISCV_FORMAL
	picorv32_rvfimon rvfi_monitor (
		.clock          (clk           ),
		.reset          (!resetn       ),
		.rvfi_valid     (rvfi_valid    ),
		.rvfi_order     (rvfi_order    ),
		.rvfi_insn      (rvfi_insn     ),
		.rvfi_trap      (rvfi_trap     ),
		.rvfi_halt      (rvfi_halt     ),
		.rvfi_intr      (rvfi_intr     ),
		.rvfi_rs1_addr  (rvfi_rs1_addr ),
		.rvfi_rs2_addr  (rvfi_rs2_addr ),
		.rvfi_rs1_rdata (rvfi_rs1_rdata),
		.rvfi_rs2_rdata (rvfi_rs2_rdata),
		.rvfi_rd_addr   (rvfi_rd_addr  ),
		.rvfi_rd_wdata  (rvfi_rd_wdata ),
		.rvfi_pc_rdata  (rvfi_pc_rdata ),
		.rvfi_pc_wdata  (rvfi_pc_wdata ),
		.rvfi_mem_addr  (rvfi_mem_addr ),
		.rvfi_mem_rmask (rvfi_mem_rmask),
		.rvfi_mem_wmask (rvfi_mem_wmask),
		.rvfi_mem_rdata (rvfi_mem_rdata),
		.rvfi_mem_wdata (rvfi_mem_wdata)
	);
`endif

reg printing_statement = 1'b0;
always @(posedge clk) begin
	if (mem_axi_awvalid && mem_axi_awready && mem_axi_awaddr == 32'h10000000) begin
		printing_statement = 1'b1;
	end
	if(printing_statement) begin
		if (mem_axi_wvalid && mem_axi_wready) begin
			$write("%c", mem_axi_wdata[7:0]);
			printing_statement = 1'b0;
		end else begin
			printing_statement = 1'b1;
		end
	end

end
	
	integer cycle_counter;
	always @(posedge clk) begin
		cycle_counter <= resetn ? cycle_counter + 1 : 0;
		if (resetn && trap) begin
`ifndef VERILATOR
			repeat (10) @(posedge clk);
`endif
			$display("TRAP after %1d clock cycles", cycle_counter);
			if (tests_passed) begin
				$display("ALL TESTS PASSED.");
				$finish;
			end else begin
				$display("ERROR!");
				if ($test$plusargs("noerror"))
					$finish;
				$stop;
			end
		end
	end
endmodule

