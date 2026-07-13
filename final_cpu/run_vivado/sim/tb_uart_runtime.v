`timescale 1ns/1ps
module tb_uart_runtime;
    reg clk=0,resetn=0,send=0;
    reg [7:0] tx_data=0;
    wire serial,tx_ready,tx_busy;
    wire [7:0] rx_data;
    wire rx_valid,frame_error;
    always #10 clk=~clk;
    uart_tx #(.CLOCK_HZ(50_000_000),.BAUD(115_200)) tx(
        .clk(clk),.resetn(resetn),.enable(1'b1),.data(tx_data),.valid(send),
        .tx(serial),.ready(tx_ready),.busy(tx_busy));
    uart_rx #(.CLOCK_HZ(50_000_000),.BAUD(115_200)) rx(
        .clk(clk),.resetn(resetn),.enable(1'b1),.clear_error(1'b0),.rx(serial),
        .data(rx_data),.valid(rx_valid),.frame_error(frame_error));
    initial begin
        repeat(5)@(posedge clk);resetn=1;
        @(posedge clk);while(!tx_ready)@(posedge clk);tx_data=8'ha5;send=1;
        @(posedge clk);send=0;
        wait(rx_valid);
        if(rx_data!==8'ha5||frame_error)begin $display("FAIL UART %h %b",rx_data,frame_error);$finish;end
        $display("PASS UART");$finish;
    end
endmodule
