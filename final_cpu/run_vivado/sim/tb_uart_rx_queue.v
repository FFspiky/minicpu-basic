`timescale 1ns/1ps
`default_nettype none

module tb_uart_rx_queue;
    localparam integer CLOCK_HZ = 1_000_000;
    localparam integer BAUD = 100_000;
    localparam integer CLKS_PER_BIT = 10;
    localparam integer FRAME_BYTES = 270;

    reg clk = 1'b0;
    reg resetn = 1'b0;
    reg serial_rx = 1'b1;
    reg pop = 1'b0;
    wire [7:0] rx_data;
    wire rx_valid, frame_error;
    wire [7:0] front;
    wire empty, full, overflow;
    integer sent;
    integer consumed;

    always #5 clk = ~clk;

    uart_rx #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD)) receiver (
        .clk(clk), .resetn(resetn), .enable(1'b1),
        .clear_error(1'b0), .rx(serial_rx), .data(rx_data),
        .valid(rx_valid), .frame_error(frame_error)
    );

    uart_fifo #(.DEPTH(512), .ADDR_WIDTH(9)) queue (
        .clk(clk), .resetn(resetn), .clear(1'b0),
        .clear_overflow(1'b0), .push_data(rx_data), .push(rx_valid),
        .pop(pop), .front(front), .empty(empty), .full(full),
        .overflow(overflow)
    );

    task send_byte;
        input [7:0] value;
        integer bit_index;
        begin
            serial_rx = 1'b0;
            repeat (CLKS_PER_BIT) @(negedge clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            begin
                serial_rx = value[bit_index];
                repeat (CLKS_PER_BIT) @(negedge clk);
            end
            serial_rx = 1'b1;
            repeat (CLKS_PER_BIT) @(negedge clk);
        end
    endtask

    initial
    begin
        repeat (4) @(negedge clk);
        resetn = 1'b1;
        for (sent = 0; sent < FRAME_BYTES; sent = sent + 1)
            send_byte(sent[7:0]);
        repeat (4) @(negedge clk);
        if (overflow || frame_error || full)
        begin
            $display("FAIL UART RX queue status overflow=%0d frame_error=%0d full=%0d",
                     overflow, frame_error, full);
            $fatal;
        end
        for (consumed = 0; consumed < FRAME_BYTES; consumed = consumed + 1)
        begin
            if (empty || front !== consumed[7:0])
            begin
                $display("FAIL UART RX queue byte %0d = %02h empty=%0d",
                         consumed, front, empty);
                $fatal;
            end
            pop = 1'b1;
            @(negedge clk);
            pop = 1'b0;
            @(negedge clk);
        end
        if (!empty)
        begin
            $display("FAIL UART RX queue contains trailing data");
            $fatal;
        end
        $display("PASS UART RX queue retains a complete DATA frame");
        $finish;
    end

    initial
    begin
        #500_000;
        $display("FAIL UART RX queue timeout");
        $fatal;
    end
endmodule

`default_nettype wire
