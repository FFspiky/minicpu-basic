`timescale 1ns / 1ps

module la32_stable_counter(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    output reg  [63:0] value
);
    always @(posedge clk) begin
        if (!resetn) begin
            value <= 64'b0;
        end
        else if (cpu_en) begin
            value <= value + 64'd1;
        end
    end
endmodule
