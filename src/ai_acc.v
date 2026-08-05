module ai_accel_axi (
    input             clk,
    input             resetn,

    input             s_axi_awvalid, output reg s_axi_awready,
    input      [31:0] s_axi_awaddr,
    input             s_axi_wvalid,  output reg s_axi_wready,
    input      [31:0] s_axi_wdata,
    input      [3:0]  s_axi_wstrb,
    output reg        s_axi_bvalid,  input      s_axi_bready,

    input             s_axi_arvalid, output reg s_axi_arready,
    input      [31:0] s_axi_araddr,
    output reg        s_axi_rvalid,  input      s_axi_rready,
    output reg [31:0] s_axi_rdata
);
    reg [31:0] opa, opb, result;
    reg        busy, done;

    // ---- write channel ----
    reg [31:0] waddr;
    always @(posedge clk) begin
        if (!resetn) begin
            s_axi_awready <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0;
            opa <= 0; opb <= 0; busy <= 0; done <= 0;
        end else begin
            s_axi_awready <= 0;
            s_axi_wready  <= 0;

            if (s_axi_awvalid && !s_axi_awready && !s_axi_bvalid) begin
                s_axi_awready <= 1;
                waddr = s_axi_awaddr;
            end
            if (s_axi_wvalid && !s_axi_wready && !s_axi_bvalid) begin
                s_axi_wready <= 1;
                case (waddr[7:0])
                    8'h00: if (s_axi_wdata[0]) busy <= 1;   // CTRL: start
                    8'h08: opa <= s_axi_wdata;
                    8'h0C: opb <= s_axi_wdata;
                endcase
                s_axi_bvalid <= 1;
            end
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 0;

            // fake "compute" — 1 cycle MAC, replace with real pipeline later
            if (busy) begin
                result <= opa * opb;
                busy   <= 0;
                done   <= 1;
            end
        end
    end

    // ---- read channel ----
    reg [31:0] raddr;
    always @(posedge clk) begin
        if (!resetn) begin
            s_axi_arready <= 0; s_axi_rvalid <= 0;
        end else begin
            s_axi_arready <= 0;
            if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
                s_axi_arready <= 1;
                raddr <= s_axi_araddr;
            end
            if (s_axi_arready) begin
                s_axi_rvalid <= 1;
                case (raddr[7:0])
                    8'h04: s_axi_rdata <= {31'b0, done};
                    8'h10: s_axi_rdata <= result;
                    default: s_axi_rdata <= 32'hDEADBEEF;
                endcase
            end
            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 0;
        end
    end
endmodule