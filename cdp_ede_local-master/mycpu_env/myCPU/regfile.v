`timescale 1ns / 1ps

// 32 x 32-bit register file, two asynchronous read ports and one
// synchronous write port. Register r0 is hard-wired to zero.
module regfile(
    input           clk,
    input           resetn,

    input           wen,
    input  [4:0]    waddr,
    input  [31:0]   wdata,

    input  [4:0]    raddr1,
    output [31:0]   rdata1,

    input  [4:0]    raddr2,
    output [31:0]   rdata2
);

    reg [31:0] rf [31:0];
    integer i;

    always @(posedge clk) begin
        if (!resetn) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'b0;
            end
        end
        else begin
            if (wen && (waddr != 5'b0)) begin
                rf[waddr] <= wdata;
            end

            rf[0] <= 32'b0;
        end
    end

    assign rdata1 = (raddr1 == 5'b0) ? 32'b0 : rf[raddr1];
    assign rdata2 = (raddr2 == 5'b0) ? 32'b0 : rf[raddr2];

endmodule
