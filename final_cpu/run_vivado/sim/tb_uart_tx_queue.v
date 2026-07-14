`timescale 1ns/1ps
`default_nettype none

module tb_uart_tx_queue;
    localparam integer CLOCK_HZ = 1_000_000;
    localparam integer BAUD = 100_000;

    reg clk = 1'b0;
    reg resetn = 1'b0;
    reg [7:0] push_data = 8'd0;
    reg push = 1'b0;
    wire [7:0] front;
    wire empty, full, overflow;
    wire tx_ready, tx_busy, tx_start, serial_tx;
    wire [7:0] rx_data;
    wire rx_valid, rx_frame_error;
    integer received = 0;

    always #5 clk = ~clk;
    assign tx_start = !empty && tx_ready;

    uart_fifo #(.DEPTH(16), .ADDR_WIDTH(4)) queue (
        .clk(clk), .resetn(resetn), .clear(1'b0),
        .clear_overflow(1'b0), .push_data(push_data), .push(push),
        .pop(tx_start), .front(front), .empty(empty), .full(full),
        .overflow(overflow)
    );

    uart_tx #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD)) transmitter (
        .clk(clk), .resetn(resetn), .enable(1'b1), .data(front),
        .valid(tx_start), .tx(serial_tx), .ready(tx_ready), .busy(tx_busy)
    );

    uart_rx #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD)) receiver (
        .clk(clk), .resetn(resetn), .enable(1'b1), .clear_error(1'b0),
        .rx(serial_tx), .data(rx_data), .valid(rx_valid),
        .frame_error(rx_frame_error)
    );

    always @(posedge clk)
    begin
        if (rx_valid)
        begin
            if (rx_frame_error)
            begin
                $display("FAIL UART TX queue frame error");
                $fatal;
            end
            if ((received == 0 && rx_data !== 8'h12) ||
                (received == 1 && rx_data !== 8'h34))
            begin
                $display("FAIL UART TX queue byte %0d = %02h", received, rx_data);
                $fatal;
            end
            received = received + 1;
            if (received == 2)
            begin
                $display("PASS UART TX queue preserves consecutive writes");
                $finish;
            end
        end
    end

    initial
    begin
        repeat (4) @(negedge clk);
        resetn = 1'b1;
        @(negedge clk); push_data = 8'h12; push = 1'b1;
        @(negedge clk); push_data = 8'h34; push = 1'b1;
        @(negedge clk); push = 1'b0;
    end

    initial
    begin
        #100_000;
        $display("FAIL UART TX queue timeout received=%0d", received);
        $fatal;
    end
endmodule

`default_nettype wire
