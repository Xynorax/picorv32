module input_subsystem (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        read_start,
    
    // Memory Interface (Simulated SRAM read ports)
    input  wire signed [7:0] sram_bank0_data, // Flat data stream for Row 0
    input  wire signed [7:0] sram_bank1_data, // Flat data stream for Row 1
    output reg  [7:0]        sram_read_addr,  // Address sent to memory banks
    
    // Skewed Outputs feeding the 2D Systolic Array directly
    output wire signed [7:0] array_row0_o,
    output wire signed [7:0] array_row1_o
);

    // 1. Simple Address Generation Unit (AGU) Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_read_addr <= 8'd0;
        end else if (en && read_start) begin
            sram_read_addr <= sram_read_addr + 1'b1; // Stream sequentially
        end
    end

    // 2. The Skewing Pipeline
    // Row 0 doesn't need a delay; it hooks up straight to the memory output
    assign array_row0_o = sram_bank0_data;

    // Row 1 needs a 1-cycle delay loop to wait for PE(0,0) to finish its first step
    reg signed [7:0] row1_skew_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row1_skew_reg <= 8'sd0;
        end else if (en) begin
            row1_skew_reg <= sram_bank1_data; // Capture and hold for 1 cycle
        end
    end

    // The delayed signal is fed to Row 1 of the 2D array
    assign array_row1_o = row1_skew_reg;

endmodule