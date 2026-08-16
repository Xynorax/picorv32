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

	wire trace_valid;
	wire [35:0] trace_data;
	integer trace_file;

	initial begin
		if ($test$plusargs("trace")) begin
			trace_file = $fopen("testbench.trace", "w");
			repeat (10) @(posedge clk);
			while (!trap) begin
				@(posedge clk);
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
	wire 		s0_bresp, s0_rresp;
	wire        s1_awvalid, s1_awready; wire [31:0] s1_awaddr;
	wire        s1_wvalid,  s1_wready;  wire [31:0] s1_wdata; wire [3:0] s1_wstrb;
	wire        s1_bvalid,  s1_bready;
	wire        s1_arvalid, s1_arready; wire [31:0] s1_araddr;
	wire        s1_rvalid,  s1_rready;  wire [31:0] s1_rdata;

	// adapter to interconnect wires
	wire        int_awvalid, int_awready, int_wvalid, int_wready;
	wire        int_bvalid, int_bready;
	wire        int_arvalid, int_arready, int_rvalid, int_rready;
	wire [31:0] int_awaddr, int_wdata, int_araddr, int_rdata;
	wire [ 3:0] int_wstrb;
	wire [ 2:0] int_awprot, int_arprot;

	taxi_axil_if s_axil_wr();
	taxi_axil_if s_axil_rd();
	taxi_axi_if  m_axi_wr();
	taxi_axi_if  m_axi_rd();

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

	// adapter -> interconnect (AXI4 master interface)
	assign int_awvalid = m_axi_wr.awvalid;
	assign int_awaddr  = m_axi_wr.awaddr;
	assign int_awprot  = m_axi_wr.awprot;
	assign int_wvalid  = m_axi_wr.wvalid;
	assign int_wdata   = m_axi_wr.wdata;
	assign int_wstrb   = m_axi_wr.wstrb;
	assign int_bready  = m_axi_wr.bready;

	assign int_arvalid = m_axi_rd.arvalid;
	assign int_araddr  = m_axi_rd.araddr;
	assign int_arprot  = m_axi_rd.arprot;
	assign int_rready  = m_axi_rd.rready;

	always @* begin
		m_axi_wr.awready = int_awready;
		m_axi_wr.wready  = int_wready;
		m_axi_wr.bvalid  = int_bvalid;
		m_axi_rd.arready = int_arready;
		m_axi_rd.rvalid  = int_rvalid;
		m_axi_rd.rdata   = int_rdata;
	end

	taxi_axil_axi_adapter adapter (
		.clk(clk), .rst(!resetn),

		.s_axil_wr(s_axil_wr),
		.s_axil_rd(s_axil_rd),

		.m_axi_wr(m_axi_wr),
		.m_axi_rd(m_axi_rd)
	);

	// interconnect master port 0 -> accel (higher priority), master port 1 -> memory (catch-all)
	wire [ 1:0] int_m_awvalid, int_m_awready;
	wire [ 1:0] int_m_wvalid,  int_m_wready;
	wire [ 1:0] int_m_bvalid,  int_m_bready;
	wire [ 1:0] int_m_arvalid, int_m_arready;
	wire [ 1:0] int_m_rvalid,  int_m_rready;
	wire [63:0] int_m_awaddr, int_m_wdata, int_m_araddr, int_m_rdata;
	wire [ 7:0] int_m_wstrb;
	wire [ 5:0] int_m_awprot, int_m_arprot;
	wire [7:0] int_m_awid, int_m_bid, int_m_arid, int_m_rid;
	wire [15:0] int_m_awlen, int_m_arlen;
	wire [5:0] int_m_awsize, int_m_arsize;
	wire [3:0] int_m_awburst, int_m_arburst;
	// port 0 -> accel (s1), port 1 -> memory (s0)
	assign int_m_awready[0] = s1_awready;
	assign int_m_awready[1] = s0_awready;
	assign int_m_wready[0]  = s1_wready;
	assign int_m_wready[1]  = s0_wready;
	assign int_m_bvalid[0]  = s1_bvalid;
	assign int_m_bvalid[1]  = s0_bvalid;
	assign int_m_arready[0] = s1_arready;
	assign int_m_arready[1] = s0_arready;
	assign int_m_rvalid[0]  = s1_rvalid;
	assign int_m_rvalid[1]  = s0_rvalid;
	assign int_m_rdata[0*32 +: 32] = s1_rdata;
	assign int_m_rdata[1*32 +: 32] = s0_rdata;
	assign s0_awid = int_m_awid[1*4 +: 4];
	assign int_m_bid[1*4 +: 4] = s0_bid;
	assign s0_arid = int_m_arid[1*4 +: 4];
	assign int_m_rid[1*4 +: 4] = s0_rid;
	assign s0_awlen = int_m_awlen[1*8 +: 8];
	assign s0_arlen = int_m_arlen[1*8 +: 8];
	assign s0_awsize = int_m_awsize[1*3 +: 3];
	assign s0_arsize = int_m_arsize[1*3 +: 3];
	assign s0_awburst = int_m_awburst[1*2 +: 2];
	assign s0_arburst = int_m_arburst[1*2 +: 2];

	assign s1_awvalid = int_m_awvalid[0];
	assign s0_awvalid = int_m_awvalid[1];
	assign s1_awaddr  = int_m_awaddr[0*32 +: 32];
	assign s0_awaddr  = int_m_awaddr[1*32 +: 32];
	assign s1_awprot  = int_m_awprot[0*3 +: 3];
	assign s0_awprot  = int_m_awprot[1*3 +: 3];
	assign s1_wvalid  = int_m_wvalid[0];
	assign s0_wvalid  = int_m_wvalid[1];
	assign s1_wdata   = int_m_wdata[0*32 +: 32];
	assign s0_wdata   = int_m_wdata[1*32 +: 32];
	assign s1_wstrb   = int_m_wstrb[0*4 +: 4];
	assign s0_wstrb   = int_m_wstrb[1*4 +: 4];
	assign s1_bready  = int_m_bready[0];
	assign s0_bready  = int_m_bready[1];
	assign s1_arvalid = int_m_arvalid[0];
	assign s0_arvalid = int_m_arvalid[1];
	assign s1_araddr  = int_m_araddr[0*32 +: 32];
	assign s0_araddr  = int_m_araddr[1*32 +: 32];
	assign s1_arprot  = int_m_arprot[0*3 +: 3];
	assign s0_arprot  = int_m_arprot[1*3 +: 3];
	assign s1_rready  = int_m_rready[0];
	assign s0_rready  = int_m_rready[1];

	axi_interconnect #(
		.S_COUNT(1),
		.M_COUNT(2),
		.DATA_WIDTH(32),
		.ADDR_WIDTH(32),
		.STRB_WIDTH(4),
		.ID_WIDTH(1),
		.M_REGIONS(2),
		.M_BASE_ADDR({32'h20000000, 32'h00000000, 32'h00000000, 32'h30000000}),
		.M_ADDR_WIDTH({32'd28, 32'd29, 32'd0, 32'd16}),
		.AWUSER_ENABLE(0), .AWUSER_WIDTH(1),
		.WUSER_ENABLE(0),  .WUSER_WIDTH(1),
		.BUSER_ENABLE(0),  .BUSER_WIDTH(1),
		.ARUSER_ENABLE(0), .ARUSER_WIDTH(1),
		.RUSER_ENABLE(0),  .RUSER_WIDTH(1),
		.FORWARD_ID(0)
	) interconnect (
		.clk(clk), .rst(!resetn),

		.s_axi_awid    (1'b0),
		.s_axi_awaddr  (int_awaddr),
		.s_axi_awlen   (8'd0),
		.s_axi_awsize  (3'd2),
		.s_axi_awburst (2'b00),
		.s_axi_awlock  (1'b0),
		.s_axi_awcache (4'b0000),
		.s_axi_awprot  (int_awprot),
		.s_axi_awqos   (4'b0000),
		.s_axi_awuser  (1'b0),
		.s_axi_awvalid (int_awvalid),
		.s_axi_awready (int_awready),

		.s_axi_wdata(int_wdata),
		.s_axi_wstrb(int_wstrb),
		.s_axi_wlast(1'b1),
		.s_axi_wuser(1'b0),
		.s_axi_wvalid(int_wvalid),
		.s_axi_wready(int_wready),

		.s_axi_bid    (),
		.s_axi_bresp  (),
		.s_axi_buser  (),
		.s_axi_bvalid (int_bvalid),
		.s_axi_bready (int_bready),

		.s_axi_arid    (1'b0),
		.s_axi_araddr  (int_araddr),
		.s_axi_arlen   (8'd0),
		.s_axi_arsize  (3'd2),
		.s_axi_arburst (2'b00),
		.s_axi_arlock  (1'b0),
		.s_axi_arcache (4'b0000),
		.s_axi_arprot  (int_arprot),
		.s_axi_arqos   (4'b0000),
		.s_axi_aruser  (1'b0),
		.s_axi_arvalid (int_arvalid),
		.s_axi_arready (int_arready),

		.s_axi_rid    (),
		.s_axi_rdata  (int_rdata),
		.s_axi_rresp  (),
		.s_axi_rlast  (),
		.s_axi_ruser  (),
		.s_axi_rvalid (int_rvalid),
		.s_axi_rready (int_rready),

		.m_axi_awid    (int_m_awid),
		.m_axi_awaddr  (int_m_awaddr),
		.m_axi_awlen   (int_m_awlen),
		.m_axi_awsize  (int_m_awsize),
		.m_axi_awburst (int_m_awburst),
		.m_axi_awlock  (int_m_awlock),
		.m_axi_awcache (int_m_awcache),
		.m_axi_awprot  (int_m_awprot),
		.m_axi_awqos   (int_m_awqos),
		.m_axi_awregion(int_m_awregion),
		.m_axi_awuser  (int_m_awuser),
		.m_axi_awvalid (int_m_awvalid),
		.m_axi_awready (int_m_awready),

		.m_axi_wdata(int_m_wdata),
		.m_axi_wstrb(int_m_wstrb),
		.m_axi_wlast(int_m_wlast),
		.m_axi_wuser(int_m_wuser),
		.m_axi_wvalid(int_m_wvalid),
		.m_axi_wready(int_m_wready),

		.m_axi_bid   (int_m_bid),
		.m_axi_bresp (int_m_bresp),
		.m_axi_buser ({2{1'b0}}),
		.m_axi_bvalid(int_m_bvalid),
		.m_axi_bready(int_m_bready),

		.m_axi_arid    (int_m_arid),
		.m_axi_araddr  (int_m_araddr),
		.m_axi_arlen   (int_m_arlen),
		.m_axi_arsize  (int_m_arsize),
		.m_axi_arburst (int_m_arburst),
		.m_axi_arlock  (int_m_arlock),
		.m_axi_arcache (int_m_arcache),
		.m_axi_arprot  (int_m_arprot),
		.m_axi_arqos   (int_m_arqos),
		.m_axi_arregion(int_m_arregion),
		.m_axi_aruser  (int_m_aruser),
		.m_axi_arvalid (int_m_arvalid),
		.m_axi_arready (int_m_arready),

		.m_axi_rid    (int_m_rid),
		.m_axi_rdata  (int_m_rdata),
		.m_axi_rresp  ({2{2'b00}}),
		.m_axi_rlast  ({2{1'b1}}),
		.m_axi_ruser  ({2{1'b0}}),
		.m_axi_rvalid (int_m_rvalid),
		.m_axi_rready (int_m_rready)
	);

	ai_accel_axi accel (
		.clk(clk), .resetn(resetn),
		.s_axi_awvalid(s1_awvalid), .s_axi_awready(s1_awready), .s_axi_awaddr(s1_awaddr),
		.s_axi_wvalid(s1_wvalid),   .s_axi_wready(s1_wready),   .s_axi_wdata(s1_wdata), .s_axi_wstrb(s1_wstrb),
		.s_axi_bvalid(s1_bvalid),   .s_axi_bready(s1_bready),
		.s_axi_arvalid(s1_arvalid), .s_axi_arready(s1_arready), .s_axi_araddr(s1_araddr),
		.s_axi_rvalid(s1_rvalid),   .s_axi_rready(s1_rready),   .s_axi_rdata(s1_rdata)
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

reg printing_statement = 1'b0; ;
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

