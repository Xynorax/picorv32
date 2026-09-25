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
	reg mem_axi_awvalid;
	reg mem_axi_wvalid;
	reg mem_axi_awready;
	reg mem_axi_wready;
	reg [31:0] mem_axi_awaddr;
	reg [7:0] mem_axi_wdata;
	reg tests_passed;

	picorv32_wrapper #(
		.AXI_TEST (AXI_TEST),
		.VERBOSE  (VERBOSE)
	) top (
		.clk(clk),
		.resetn(resetn),
		.trap(trap),
		.trace_valid(trace_valid),
		.trace_data(trace_data),
		.mem_axi_awvalid_out(mem_axi_awvalid),
		.mem_axi_wvalid_out(mem_axi_wvalid),
		.mem_axi_awaddr_out(mem_axi_awaddr),
		.mem_axi_awready_out(mem_axi_awready),
		.mem_axi_wready_out(mem_axi_wready),
		.mem_axi_wdata_out(mem_axi_wdata),
		.tests_passed_out(tests_passed)
	);
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
`endif