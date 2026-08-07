`timescale 1ns/1ps

module tb_pe_array_1d;

    // Inputs to the UUT (Unit Under Test)
    reg         clk;
    reg         rst_n;
    reg         en;
    reg         clear_acc;
    reg  signed [7:0]  ifmap_i;
    reg  signed [7:0]  w0_i;
    reg  signed [7:0]  w1_i;
    reg  signed [7:0]  w2_i;
    reg  signed [7:0]  w3_i;

    // Outputs from the UUT
    wire signed [31:0] psum0_o;
    wire signed [31:0] psum1_o;
    wire signed [31:0] psum2_o;
    wire signed [31:0] psum3_o;

    // Instantiate the Unit Under Test (UUT)
    pe_array uut (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (en),
        .clear_acc (clear_acc),
        .ifmap_i   (ifmap_i),
        .w0_i      (w0_i),
        .w1_i      (w1_i),
        .w2_i      (w2_i),
        .w3_i      (w3_i),
        .psum0_o   (psum0_o),
        .psum1_o   (psum1_o),
        .psum2_o   (psum2_o),
        .psum3_o   (psum3_o)
    );

    // 1. Clock Generation (50MHz -> 20ns period)
    always begin
        #10 clk = ~clk;
    end

    // 2. Stimulus Routine
    initial begin
        // Initialize Inputs
        clk       = 0;
        rst_n     = 0;
        en        = 0;
        clear_acc = 0;
        ifmap_i   = 8'sd0;
        
        // Define static weights for each PE
        w0_i = 8'sd2;  // PE0 Weight
        w1_i = 8'sd3;  // PE1 Weight
        w2_i = 8'sd4;  // PE2 Weight
        w3_i = 8'sd5;  // PE3 Weight

        // Wait 40ns for global reset release
        #40;
        rst_n = 1;
        #20;

        // --- Cycle 0: Clear Accumulators ---
        // Synchronously reset internal accumulation loops inside the PEs
        @(posedge clk);
        en        = 1;
        clear_acc = 1;
        ifmap_i   = 8'sd10; // First element in the input stream
        
        // --- Cycle 1: Feed Input 2 ---
        @(posedge clk);
        clear_acc = 0;      // Start accumulating
        ifmap_i   = 8'sd20; // PE0 registers 10. Computes: 10 * w0 (2) = 20.
        
        // --- Cycle 2: Feed Input 3 ---
        @(posedge clk);
        ifmap_i   = 8'sd30; // PE0 registers 20. Computes: 20*2 + 20 = 60.
                            // PE1 registers 10. Computes: 10 * w1 (3) = 30.

        // --- Cycle 3: Feed Input 4 ---
        @(posedge clk);
        ifmap_i   = 8'sd0;  // PE0 registers 30. Computes: 30*2 + 60 = 120.
                            // PE1 registers 20. Computes: 20*3 + 30 = 90.
                            // PE2 registers 10. Computes: 10 * w2 (4) = 40.

        // --- Cycle 4: Let data drain through the array pipeline ---
        @(posedge clk);
        ifmap_i   = 8'sd0;  // PE1 registers 30. Computes: 30*3 + 90 = 180.
                            // PE2 registers 20. Computes: 20*4 + 40 = 120.
                            // PE3 registers 10. Computes: 10 * w3 (5) = 50.

        // --- Cycle 5 ---
        @(posedge clk);
        ifmap_i   = 8'sd0;  // PE2 registers 30. Computes: 30*4 + 120 = 240.
                            // PE3 registers 20. Computes: 20*5 + 50 = 150.

        // --- Cycle 6 ---
        @(posedge clk);
        ifmap_i   = 8'sd0;  // PE3 registers 30. Computes: 30*5 + 150 = 300.

        // --- Cycle 7: Stop execution & Freeze pipeline ---
        @(posedge clk);
        en = 0;

        // --- Check Results ---
        #10;
        $display("======= Verification Results =======");
        $display("PE0 Final PSum (Expected: 120) -> Observed: %d", psum0_o);
        $display("PE1 Final PSum (Expected: 180) -> Observed: %d", psum1_o);
        $display("PE2 Final PSum (Expected: 240) -> Observed: %d", psum2_o);
        $display("PE3 Final PSum (Expected: 300) -> Observed: %d", psum3_o);
        
        if ((psum0_o == 120) && (psum1_o == 180) && (psum2_o == 240) && (psum3_o == 300)) begin
            $display("SUCCESS: 1D Systolic Array function matches timing model exactly!");
        end else begin
            $display("ERROR: Output mismatch. Check signed assignments or pipeline connections.");
        end

        $finish;
    end

endmodule