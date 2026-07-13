`timescale 1ns / 1ps
`default_nettype none

module uart_tx #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer BAUD     = 115_200
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire       enable,
    input  wire [7:0] data,
    input  wire       valid,
    output reg        tx,
    output wire       ready,
    output reg        busy
);
    localparam integer CLKS_PER_BIT = (CLOCK_HZ + BAUD / 2) / BAUD;
    reg [15:0] count;
    reg [3:0]  bit_index;
    reg [9:0]  shift;

    assign ready = enable && !busy;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            tx        <= 1'b1;
            busy      <= 1'b0;
            count     <= 0;
            bit_index <= 0;
            shift     <= 10'h3ff;
        end
        else if (!enable)
        begin
            tx   <= 1'b1;
            busy <= 1'b0;
        end
        else if (!busy)
        begin
            tx <= 1'b1;
            if (valid)
            begin
                shift     <= {1'b1, data, 1'b0};
                tx        <= 1'b0;
                busy      <= 1'b1;
                bit_index <= 0;
                count     <= CLKS_PER_BIT - 1;
            end
        end
        else if (count != 0)
            count <= count - 1'b1;
        else if (bit_index == 9)
        begin
            tx   <= 1'b1;
            busy <= 1'b0;
        end
        else
        begin
            bit_index <= bit_index + 1'b1;
            shift     <= {1'b1, shift[9:1]};
            tx        <= shift[1];
            count     <= CLKS_PER_BIT - 1;
        end
    end
endmodule

`default_nettype wire
