module CAM(
    input clk,
    input rst_n,
    
    // Write ports
    input wr_en,
    input logic [1:0] wr_addr,
    input logic [31:0] wr_data,
    
    // Search ports
    input logic search_en,
    input logic [31:0] search_data,
    output logic match,
    output logic [1:0] match_addr
    );
    
    logic [31:0] mem[4];
    logic valid[4];
    always@ (posedge clk or negedge rst_n) begin
        integer i;
        if (!rst_n) begin
            for (i = 0; i < 4; i++) begin
                mem[i] <= 32'b0;
                valid[i] <= 1'b0;
            end
        end else begin
            if (wr_en) begin
                mem[wr_addr] <= wr_data;
                valid[wr_addr] <= 1'b1;
            end
            
            if(search_en) begin
                int j;
                match      <= 1'b0;
                match_addr <= 2'b00;
                for (j = 0; j < 4; j++) begin
                    if (mem[j] == search_data && valid[j]) begin
                        match_addr <= j[1:0];
                        match <= 1'b1;
                    end 
                end
            end else begin
                match <= 1'b0;
                match_addr <= 2'b00;
            end
        end
    end
    
endmodule: CAM

module cam_seq (
    input  logic        clk,
    input  logic        rst_n,

    // Write ports
    input  logic        wr_en,
    input  logic [1:0]  wr_addr,
    input  logic [31:0] wr_data,

    // Search ports
    input  logic        search_en,
    input  logic [31:0] search_data,
    output logic        match,
    output logic [1:0]  match_addr,
    output logic        search_done,   
    output logic        busy          
);

    logic [31:0] mem   [4];
    logic        valid [4];

    typedef enum logic [1:0] {IDLE, SEARCH, DONE} state_t;
    state_t     state;
    logic [1:0] ptr;

    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i++) begin
                mem[i]   <= 32'b0;
                valid[i] <= 1'b0;
            end
            state       <= IDLE;
            ptr         <= 2'd0;
            match       <= 1'b0;
            match_addr  <= 2'b00;
            search_done <= 1'b0;
        end else begin
            if (wr_en) begin
                mem[wr_addr]   <= wr_data;
                valid[wr_addr] <= 1'b1;
            end

            search_done <= 1'b0;

            case (state)
                IDLE: begin
                    if (search_en) begin
                        ptr   <= 2'd0;
                        match <= 1'b0;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    if (valid[ptr] && (mem[ptr] == search_data)) begin
                        match       <= 1'b1;
                        match_addr  <= ptr;
                        search_done <= 1'b1;
                        state       <= IDLE;    
                    end else if (ptr == 2'd3) begin
                        match       <= 1'b0;   
                        search_done <= 1'b1;
                        state       <= IDLE;
                    end else begin
                        ptr <= ptr + 1'b1; 
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign busy = (state == SEARCH);

endmodule: cam_seq