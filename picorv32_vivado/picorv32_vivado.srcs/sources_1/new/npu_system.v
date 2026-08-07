module npu_system_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         en,
    input  wire         clear_acc,
    
    // System Data Interfaces
    input  wire [16*8-1:0]  sram_ifmap_bus_i,  // Parallel input activation read port
    input  wire [256*8-1:0] sram_weights_bus_i, // Parallel core weight configuration matrix
    
    output wire         sram_write_valid_o, // High when data is ready to be stored
    output wire [16*8-1:0]  sram_pack_data_o   // Outbound 128-bit packed word
);

    // Internal routing networks
    wire [16*8-1:0]  skewed_activations;
    wire [16*32-1:0] raw_column_psums;

    // 1. Instantiate the Timing Skew Network
    activation_skew_16 input_skew_unit (
        .clk            (clk),
        .rst_n          (rst_n),
        .en             (en),
        .ifmap_raw_i    (sram_ifmap_bus_i),
        .ifmap_skewed_o (skewed_activations)
    );

    // 2. Instantiate your 16x16 Systolic Array Compute Core
    array_2d compute_core (
        .clk           (clk),
        .rst_n         (rst_n),
        .en            (en),
        .clear_acc     (clear_acc),
        .ifmap_rows_i  (skewed_activations),
        .weights_i     (sram_weights_bus_i),
        .psums_cols_o  (raw_column_psums)
    );

    // 3. Instantiate the Output Post-Processing Pipelines
    output_subsystem_16 output_pipeline (
        .clk           (clk),
        .rst_n         (rst_n),
        .en            (en),
        .psums_cols_i  (raw_column_psums),
        .write_valid   (sram_write_valid_o),
        .packed_data_o (sram_pack_data_o)
    );
    
endmodule