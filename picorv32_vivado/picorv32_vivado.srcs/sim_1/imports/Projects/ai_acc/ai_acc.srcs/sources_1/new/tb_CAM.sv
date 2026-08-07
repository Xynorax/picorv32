`timescale 1ns/1ps

module tb_CAM;

    logic        clk;
    logic        rst_n;
    logic        wr_en;
    logic [1:0]  wr_addr;
    logic [31:0] wr_data;
    logic        search_en;
    logic [31:0] search_data;
    logic        match;
    logic [1:0]  match_addr;

    int errors = 0;

    CAM dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .wr_en       (wr_en),
        .wr_addr     (wr_addr),
        .wr_data     (wr_data),
        .search_en   (search_en),
        .search_data (search_data),
        .match       (match),
        .match_addr  (match_addr)
    );

    always #5 clk = ~clk;

    task automatic write_entry(input [1:0] addr, input [31:0] data);
        @(negedge clk);
        wr_en   = 1'b1;
        wr_addr = addr;
        wr_data = data;
        @(negedge clk);
        wr_en   = 1'b0;
    endtask
    task automatic check_search(
        input [31:0] key,
        input logic  exp_match,
        input [1:0]  exp_addr,
        input string label
    );
        @(negedge clk);
        search_en   = 1'b1;
        search_data = key;
        @(negedge clk);        
        search_en   = 1'b0;

        if (match !== exp_match || (exp_match && match_addr !== exp_addr)) begin
            $display("FAIL [%s]: search=%h -> match=%b addr=%0d (expected match=%b addr=%0d)",
                       label, key, match, match_addr, exp_match, exp_addr);
            errors++;
        end else begin
            $display("PASS [%s]: search=%h -> match=%b addr=%0d",
                       label, key, match, match_addr);
        end
    endtask

    initial begin
        clk         = 0;
        rst_n       = 0;
        wr_en       = 0;
        wr_addr     = 0;
        wr_data     = 0;
        search_en   = 0;
        search_data = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;

        // 1) Search on empty CAM 
        check_search(32'h0000_0000, 1'b0, 2'b00, "empty CAM, search 0x0");
        check_search(32'hDEAD_BEEF, 1'b0, 2'b00, "empty CAM, search garbage");

        // 2) Write all 4 entries
        write_entry(2'd0, 32'hAAAA_AAAA);
        write_entry(2'd1, 32'hBBBB_BBBB);
        write_entry(2'd2, 32'hCCCC_CCCC);
        write_entry(2'd3, 32'hDDDD_DDDD);

        // 3) Exact match checks
        check_search(32'hAAAA_AAAA, 1'b1, 2'd0, "match entry 0");
        check_search(32'hBBBB_BBBB, 1'b1, 2'd1, "match entry 1");
        check_search(32'hCCCC_CCCC, 1'b1, 2'd2, "match entry 2");
        check_search(32'hDDDD_DDDD, 1'b1, 2'd3, "match entry 3");

        // 4) Miss with populated CAM
        check_search(32'h1234_5678, 1'b0, 2'b00, "no match, populated CAM");

        // 5) Overwrite entry 1, confirm old data no longer matches
        write_entry(2'd1, 32'hEEEE_EEEE);
        check_search(32'hBBBB_BBBB, 1'b0, 2'b00, "old value miss after overwrite");
        check_search(32'hEEEE_EEEE, 1'b1, 2'd1, "new value match after overwrite");

        // 6) Only entry 1 valid, others zero -> search for 0x0 must still miss
        //    (regression test for the valid-bit gating bug)
        rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        write_entry(2'd1, 32'hAAAA_AAAA);
        check_search(32'h0000_0000, 1'b0, 2'b00, "regression: search 0x0 with only entry1 valid");
        check_search(32'hAAAA_AAAA, 1'b1, 2'd1, "regression: correct entry still matches");

        // 7) search_en deasserted -> match/match_addr must clear
        @(negedge clk);
        search_en = 1'b0;
        @(negedge clk);
        if (match !== 1'b0 || match_addr !== 2'b00) begin
            $display("FAIL [search_en low]: match=%b addr=%0d (expected match=0 addr=0)",
                       match, match_addr);
            errors++;
        end else begin
            $display("PASS [search_en low]: match=%b addr=%0d", match, match_addr);
        end

        // 8) Reset clears everything
        rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        check_search(32'hAAAA_AAAA, 1'b0, 2'b00, "miss after reset");

        // Summary
        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===");
        else
            $display("\n=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule


module tb_cam_seq;

    logic        clk;
    logic        rst_n;
    logic        wr_en;
    logic [1:0]  wr_addr;
    logic [31:0] wr_data;
    logic        search_en;
    logic [31:0] search_data;
    logic        match;
    logic [1:0]  match_addr;
    logic        search_done;
    logic        busy;

    int errors = 0;

    // DUT
    cam_seq dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .wr_en       (wr_en),
        .wr_addr     (wr_addr),
        .wr_data     (wr_data),
        .search_en   (search_en),
        .search_data (search_data),
        .match       (match),
        .match_addr  (match_addr),
        .search_done (search_done),
        .busy        (busy)
    );
    always #5 clk = ~clk;

    task automatic write_entry(input [1:0] addr, input [31:0] data);
        @(negedge clk);
        wr_en   = 1'b1;
        wr_addr = addr;
        wr_data = data;
        @(negedge clk);
        wr_en   = 1'b0;
    endtask

    task automatic check_search(
        input [31:0] key,
        input logic  exp_match,
        input [1:0]  exp_addr,
        input string label
    );
        int timeout;
        timeout = 0;

        @(negedge clk);
        search_en   = 1'b1;
        search_data = key;
        @(negedge clk);
        search_en   = 1'b0;
        while (!search_done && timeout < 10) begin
            @(negedge clk);
            timeout++;
        end

        if (timeout == 10) begin
            $display("FAIL [%s]: search_done never asserted (FSM stuck / busy=%b)", label, busy);
            errors++;
            return;
        end

        if (match !== exp_match || (exp_match && match_addr !== exp_addr)) begin
            $display("FAIL [%s]: search=%h -> match=%b addr=%0d (expected match=%b addr=%0d)",
                       label, key, match, match_addr, exp_match, exp_addr);
            errors++;
        end else begin
            $display("PASS [%s]: search=%h -> match=%b addr=%0d", label, key, match, match_addr);
        end
    endtask

    initial begin
        clk         = 0;
        rst_n       = 0;
        wr_en       = 0;
        wr_addr     = 0;
        wr_data     = 0;
        search_en   = 0;
        search_data = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;

        // 1) Empty CAM
        check_search(32'h0000_0000, 1'b0, 2'b00, "empty CAM, search 0x0");
        check_search(32'hDEAD_BEEF, 1'b0, 2'b00, "empty CAM, search garbage");

        // 2) Write all 4 entries
        write_entry(2'd0, 32'hAAAA_AAAA);
        write_entry(2'd1, 32'hBBBB_BBBB);
        write_entry(2'd2, 32'hCCCC_CCCC);
        write_entry(2'd3, 32'hDDDD_DDDD);

        // 3) Exact match checks - entry 0 exercises best-case (1 cycle),
        //    entry 3 exercises worst-case (4 cycles) latency
        check_search(32'hAAAA_AAAA, 1'b1, 2'd0, "match entry 0 (best case latency)");
        check_search(32'hBBBB_BBBB, 1'b1, 2'd1, "match entry 1");
        check_search(32'hCCCC_CCCC, 1'b1, 2'd2, "match entry 2");
        check_search(32'hDDDD_DDDD, 1'b1, 2'd3, "match entry 3 (worst case latency)");

        // 4) Miss with populated CAM
        check_search(32'h1234_5678, 1'b0, 2'b00, "no match, populated CAM");

        // 5) Overwrite entry 1, confirm old data no longer matches
        write_entry(2'd1, 32'hEEEE_EEEE);
        check_search(32'hBBBB_BBBB, 1'b0, 2'b00, "old value miss after overwrite");
        check_search(32'hEEEE_EEEE, 1'b1, 2'd1, "new value match after overwrite");

        // 6) Only entry 1 valid, rest zero -> search 0x0 must still miss
        rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        write_entry(2'd1, 32'hAAAA_AAAA);
        check_search(32'h0000_0000, 1'b0, 2'b00, "regression: search 0x0 with only entry1 valid");
        check_search(32'hAAAA_AAAA, 1'b1, 2'd1, "regression: correct entry still matches");

        // 7) busy behavior
        @(negedge clk);
        search_en   = 1'b1;
        search_data = 32'hAAAA_AAAA;
        @(negedge clk);
        search_en = 1'b0;
        if (!busy && !search_done) begin
            $display("FAIL [busy check]: expected busy=1 immediately after search start");
            errors++;
        end else begin
            $display("PASS [busy check]: busy correctly asserted during sweep");
        end
        wait (search_done);
        @(negedge clk);
        if (busy) begin
            $display("FAIL [busy check]: busy should deassert after search_done");
            errors++;
        end else begin
            $display("PASS [busy check]: busy correctly cleared after search_done");
        end

        // 8) Priority check
        rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        write_entry(2'd0, 32'hFFFF_FFFF);
        write_entry(2'd2, 32'hFFFF_FFFF);   // duplicate value at a higher index
        check_search(32'hFFFF_FFFF, 1'b1, 2'd0, "priority: lowest index wins on duplicate");

        // 9) Reset
        rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        check_search(32'hFFFF_FFFF, 1'b0, 2'b00, "miss after reset");

        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===");
        else
            $display("\n=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule
