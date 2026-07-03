`timescale 1ns / 1ps

// 32×32 位寄存器堆
// 1 个写端口，2 个读端口
// r0 恒为 0
module regfile(
    input           clk,
    input           resetn,

    input           wen,        // 写使能
    input  [4:0]    waddr,      // 写地址
    input  [31:0]   wdata,      // 写数据

    input  [4:0]    raddr1,     // 读端口1地址
    output [31:0]   rdata1,     // 读端口1数据

    input  [4:0]    raddr2,     // 读端口2地址
    output [31:0]   rdata2      // 读端口2数据
);

    reg [31:0] rf [31:0];
    integer i;

    // 同步写，低电平复位
    always @(posedge clk) begin
        if (!resetn) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'b0;
            end
        end
        else begin
            // r0 不允许被写入
            if (wen && (waddr != 5'b0)) begin
                rf[waddr] <= wdata;
            end

            // 强制保持 r0 为 0
            rf[0] <= 32'b0;
        end
    end

    // 异步读
    assign rdata1 = rf[raddr1];
    assign rdata2 = rf[raddr2];

endmodule