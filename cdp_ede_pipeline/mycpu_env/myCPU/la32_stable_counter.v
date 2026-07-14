`timescale 1ns / 1ps

module la32_stable_counter(
    input  wire        clk,
    input  wire        resetn,
    output reg  [63:0] value
);
    always @(posedge clk) begin
        if (!resetn)
            value <= 64'b0;
        else
            value <= value + 64'd1;
    end
endmodule
