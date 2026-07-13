`timescale 1ns/1ps
module tb_uart_runtime;
    localparam integer CLOCK_HZ = 40_000_000;
    localparam integer BAUD = 115_200;
    localparam integer CLKS_PER_BIT = (CLOCK_HZ + BAUD/2) / BAUD;
    localparam real BIT_NS = 1_000_000_000.0 / BAUD;

    reg clk=0,resetn=0,send=0,rx_line=1;
    reg [7:0] tx_data=0;
    wire tx_line,tx_ready,tx_busy;
    wire [7:0] rx_data;
    wire rx_valid,frame_error;

    // 40 MHz board CPU/UART clock.  TX and RX are verified independently:
    // no project UART is used to decode the transmitter under test.
    always #(500_000_000.0/CLOCK_HZ) clk=~clk;
    uart_tx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) tx(
        .clk(clk),.resetn(resetn),.enable(1'b1),.data(tx_data),.valid(send),
        .tx(tx_line),.ready(tx_ready),.busy(tx_busy));
    uart_rx #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) rx(
        .clk(clk),.resetn(resetn),.enable(1'b1),.clear_error(1'b0),.rx(rx_line),
        .data(rx_data),.valid(rx_valid),.frame_error(frame_error));

    task check_tx_byte;
        input [7:0] value;
        integer bit_number,cycle_number;
        reg expected;
    begin
        while(!tx_ready)@(posedge clk);
        @(negedge clk);tx_data=value;send=1'b1;
        @(posedge clk);#1;send=1'b0;
        for(bit_number=0;bit_number<10;bit_number=bit_number+1)
        begin
            expected=(bit_number==0)?1'b0:
                     (bit_number==9)?1'b1:value[bit_number-1];
            for(cycle_number=0;cycle_number<CLKS_PER_BIT;cycle_number=cycle_number+1)
            begin
                if(tx_line!==expected)
                begin
                    $display("FAIL UART TX bit=%0d cycle=%0d expected=%b got=%b",
                             bit_number,cycle_number,expected,tx_line);
                    $finish;
                end
                @(posedge clk);#1;
            end
        end
        if(tx_busy||!tx_ready||tx_line!==1'b1)
        begin
            $display("FAIL UART TX did not return idle");
            $finish;
        end
    end
    endtask

    task drive_ideal_rx_byte;
        input [7:0] value;
        integer bit_number;
    begin
        rx_line=1'b0;#(BIT_NS);
        for(bit_number=0;bit_number<8;bit_number=bit_number+1)
        begin
            rx_line=value[bit_number];#(BIT_NS);
        end
        rx_line=1'b1;#(BIT_NS);
    end
    endtask

    initial begin
        repeat(5)@(posedge clk);resetn=1;
        check_tx_byte(8'ha5);
        check_tx_byte(8'h00);
        fork
            drive_ideal_rx_byte(8'h3c);
            begin
                wait(rx_valid);
                if(rx_data!==8'h3c||frame_error)
                begin
                    $display("FAIL UART RX data=%h frame_error=%b",rx_data,frame_error);
                    $finish;
                end
            end
        join
        $display("PASS UART STANDARD 40MHz/115200 CLKS_PER_BIT=%0d",CLKS_PER_BIT);
        $finish;
    end
endmodule
