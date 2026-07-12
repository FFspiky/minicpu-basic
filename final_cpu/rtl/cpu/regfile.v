`timescale 1ns / 1ps

// 32 x 32-bit, two-read/one-write architectural register file.
module regfile(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    input  wire        wen,
    input  wire [ 4:0] waddr,
    input  wire [31:0] wdata,
    input  wire [ 4:0] raddr1,
    output wire [31:0] rdata1,
    input  wire [ 4:0] raddr2,
    output wire [31:0] rdata2
);

    reg [31:0] rf [0:31];
    integer i;

    always @(posedge clk) begin
        if (!resetn) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'b0;
            end
        end
        else if (cpu_en) begin
            if (wen && (waddr != 5'b0)) begin
                rf[waddr] <= wdata;
            end
            rf[0] <= 32'b0;
        end
    end

    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : rf[raddr1];
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : rf[raddr2];

endmodule
