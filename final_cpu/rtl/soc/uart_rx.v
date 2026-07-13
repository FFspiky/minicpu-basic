`timescale 1ns / 1ps
`default_nettype none

module uart_rx #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer BAUD     = 115_200
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire       enable,
    input  wire       clear_error,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid,
    output reg        frame_error
);
    localparam integer CLKS_PER_BIT = (CLOCK_HZ + BAUD / 2) / BAUD;
    localparam integer HALF_BIT = CLKS_PER_BIT / 2;
    localparam integer COUNT_WIDTH = 16;

    (* ASYNC_REG = "TRUE" *) reg [1:0] rx_sync;
    reg [COUNT_WIDTH-1:0] count;
    reg [3:0] bit_index;
    reg [7:0] shift;
    reg       active;

    always @(posedge clk)
    begin
        if (!resetn)
            rx_sync <= 2'b11;
        else
            rx_sync <= {rx_sync[0], rx};
    end

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            count       <= 0;
            bit_index   <= 0;
            shift       <= 0;
            data        <= 0;
            valid       <= 1'b0;
            frame_error <= 1'b0;
            active      <= 1'b0;
        end
        else
        begin
            valid <= 1'b0;
            if (clear_error)
                frame_error <= 1'b0;
            if (!enable)
            begin
                active <= 1'b0;
                count  <= 0;
            end
            else if (!active)
            begin
                if (!rx_sync[1])
                begin
                    active    <= 1'b1;
                    count     <= HALF_BIT;
                    bit_index <= 0;
                end
            end
            else if (count != 0)
                count <= count - 1'b1;
            else if (bit_index == 0)
            begin
                if (rx_sync[1])
                    active <= 1'b0;
                else
                begin
                    bit_index <= 1;
                    count <= CLKS_PER_BIT - 1;
                end
            end
            else if (bit_index <= 8)
            begin
                shift[bit_index-1] <= rx_sync[1];
                bit_index <= bit_index + 1'b1;
                count <= CLKS_PER_BIT - 1;
            end
            else
            begin
                active <= 1'b0;
                if (rx_sync[1])
                begin
                    data  <= shift;
                    valid <= 1'b1;
                end
                else
                    frame_error <= 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
