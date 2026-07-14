`timescale 1ns / 1ps
`default_nettype none

module uart_fifo #(
    parameter integer DEPTH = 16,
    parameter integer ADDR_WIDTH = 4
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire       clear,
    input  wire       clear_overflow,
    input  wire [7:0] push_data,
    input  wire       push,
    input  wire       pop,
    output wire [7:0] front,
    output wire       empty,
    output wire       full,
    output reg        overflow
);
    reg [7:0] memory [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] read_pointer;
    reg [ADDR_WIDTH-1:0] write_pointer;
    reg [ADDR_WIDTH:0] count;

    assign front = memory[read_pointer];
    assign empty = count == 0;
    assign full  = count == DEPTH;

    always @(posedge clk)
    begin
        if (!resetn || clear)
        begin
            read_pointer  <= 0;
            write_pointer <= 0;
            count         <= 0;
            overflow      <= 1'b0;
        end
        else
        begin
            if (clear_overflow)
                overflow <= 1'b0;
            if (push && full)
                overflow <= 1'b1;
            if (push && !full)
            begin
                memory[write_pointer] <= push_data;
                write_pointer <= write_pointer + 1'b1;
            end
            if (pop && !empty)
                read_pointer <= read_pointer + 1'b1;
            case ({push && !full, pop && !empty})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule

`default_nettype wire
