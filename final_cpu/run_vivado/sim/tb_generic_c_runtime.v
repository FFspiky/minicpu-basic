`timescale 1ns/1ps
`default_nettype none

module tb_generic_c_runtime;
    reg clk=0, resetn=0;
    wire serial_tx;
    wire uart_dtr;
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_frame_error;
    tri [7:0] nand_io;
    integer cycles=0;
    integer output_count=0;

    always #5 clk=~clk;

    soc_lite_top #(.SIMULATION(1'b1),.SINGLE_STEP(1'b0)) dut(
        .resetn(resetn),.clk(clk),.uart_rx(1'b1),.uart_tx(serial_tx),
        .uart_dtr(uart_dtr),.warm_reset_request(1'b0),
        .nand_io(nand_io),.nand_rb_n(1'b1),
        .switch(8'hff),.btn_key_row(4'hf),.btn_step(2'b11),
        .external_key_state(16'd0),.lcd_status(32'd0));

    uart_rx #(.CLOCK_HZ(50_000_000),.BAUD(115_200)) output_decoder(
        .clk(clk),.resetn(resetn),.enable(1'b1),.clear_error(1'b0),
        .rx(serial_tx),.data(rx_data),.valid(rx_valid),
        .frame_error(rx_frame_error));

    function [7:0] expected_prefix;
        input integer position;
        begin
            case(position)
                0:expected_prefix="c";
                1:expected_prefix=" ";
                2:expected_prefix="=";
                3:expected_prefix=" ";
                4:expected_prefix="3";
                5:expected_prefix=8'h0d;
                6:expected_prefix=8'h0a;
                default:expected_prefix=0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if(rx_valid) begin
            if(rx_frame_error) begin
                $display("FAIL GENERIC C UART frame error");
                $fatal;
            end
            if(output_count<7 && rx_data!==expected_prefix(output_count)) begin
                $display("FAIL GENERIC C output[%0d]=%h expected=%h",
                         output_count,rx_data,expected_prefix(output_count));
                $fatal;
            end
            if(rx_data==8'h04) begin
                if(output_count<7) begin
                    $display("FAIL GENERIC C premature EOT");
                    $fatal;
                end
                if(dut.num_data!==32'd3) begin
                    $display("FAIL GENERIC C LCD/seven-segment output=%h expected=00000003",
                             dut.num_data);
                    $fatal;
                end
                if(dut.menu_status!==8'd4) begin
                    $display("FAIL GENERIC C program status=%h expected=04",
                             dut.menu_status);
                    $fatal;
                end
                $display("PASS GENERIC C UART, LCD output value, and DONE status");
                $finish;
            end
            output_count=output_count+1;
        end
    end

    initial begin
        #1;
        dut.sim_unified_ram.ram[0]=32'h51000000; // b 0x1c010000
        $readmemb("tools/la32asm/build/playground.mif",
                  dut.sim_unified_ram.ram,18'h04000);
        repeat(20)@(negedge clk);
        resetn=1;
        while(cycles<2_000_000) begin
            @(negedge clk);
            cycles=cycles+1;
        end
        $display("FAIL GENERIC C timeout, bytes=%0d",output_count);
        $fatal;
    end
endmodule

`default_nettype wire
