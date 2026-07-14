`timescale 1ns/1ps
`default_nettype none

module tb_exp16_runtime;
    reg clk=0, resetn=0;
    wire [1:0] led_rg0,led_rg1;
    wire [31:0] debug_commit_pc;
    wire debug_commit_valid;
    wire uart_dtr;
    wire serial_tx;
    wire [7:0] uart_data;
    wire uart_valid;
    wire uart_frame_error;
    tri [7:0] nand_io;
    integer cycles;
    integer telemetry_count=0;
    reg test_passed=1'b0;

    always #5 clk=~clk;

    soc_lite_top #(.SIMULATION(1'b1),.SINGLE_STEP(1'b0)) dut(
        .resetn(resetn),.clk(clk),.uart_rx(1'b1),.uart_tx(serial_tx),.uart_dtr(uart_dtr),
        .warm_reset_request(1'b0),.nand_io(nand_io),.nand_rb_n(1'b1),
        .switch(8'hff),.btn_key_row(4'hf),.btn_step(2'b11),
        .external_key_state(16'd0),.lcd_status(32'd0),
        .led_rg0(led_rg0),.led_rg1(led_rg1),
        .debug_commit_pc(debug_commit_pc),.debug_commit_valid(debug_commit_valid));

    uart_rx #(.CLOCK_HZ(50_000_000),.BAUD(115_200)) telemetry_decoder(
        .clk(clk),.resetn(resetn),.enable(1'b1),.clear_error(1'b0),
        .rx(serial_tx),.data(uart_data),.valid(uart_valid),
        .frame_error(uart_frame_error));

    function [7:0] expected_telemetry;
        input integer position;
        begin
            case(position)
                0,13:expected_telemetry="V";
                1,14:expected_telemetry="G";
                2,15:expected_telemetry="A";
                3,16:expected_telemetry=":";
                4:expected_telemetry="R"; 5:expected_telemetry="U";
                6,7:expected_telemetry="N"; 8:expected_telemetry="I";
                9:expected_telemetry="N"; 10:expected_telemetry="G";
                11,23:expected_telemetry=8'h0d;
                12,24:expected_telemetry=8'h0a;
                17:expected_telemetry="P"; 18:expected_telemetry="A";
                19,20:expected_telemetry="S"; 21:expected_telemetry="E";
                22:expected_telemetry="D";
                default:expected_telemetry=0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if(uart_valid) begin
            if(uart_frame_error || uart_data!==expected_telemetry(telemetry_count)) begin
                $display("FAIL EXP16 telemetry[%0d]=%h expected=%h frame_error=%b",
                         telemetry_count,uart_data,expected_telemetry(telemetry_count),
                         uart_frame_error);
                $fatal;
            end
            telemetry_count=telemetry_count+1;
        end
    end

    initial begin
        // Skip the monitor only in this regression and branch directly to the
        // relocated application.  The production MIF still contains Boot Monitor.
        #1;
        dut.sim_unified_ram.ram[0]=32'h51000000; // b 0x1c010000
        $readmemb("sw/selftest/build/trace_exp16.mif",
                  dut.sim_unified_ram.ram,18'h04000);
        repeat(20)@(negedge clk);
        resetn=1;
        cycles=0;
        while(cycles<20_000_000 && !((led_rg0==2'd1&&led_rg1==2'd1)||
                                      (led_rg0==2'd2&&led_rg1==2'd2))) begin
            @(negedge clk);cycles=cycles+1;
        end
        if(led_rg0==2'd1&&led_rg1==2'd1) begin
            while(cycles<21_000_000 && telemetry_count<25) begin
                @(negedge clk);cycles=cycles+1;
            end
            if(telemetry_count<25) begin
                $display("FAIL PIPELINE EXP16 missing PASSED telemetry bytes=%0d",
                         telemetry_count);
                $fatal;
            end
            $display("PASS PIPELINE EXP16 cycles=%0d pc=%h",cycles,debug_commit_pc);
            test_passed=1'b1;
            $finish;
        end
        if(led_rg0==2'd2&&led_rg1==2'd2) begin
            $display("FAIL PIPELINE EXP16 result lights pc=%h",debug_commit_pc);
            $fatal;
        end
        $display("FAIL PIPELINE EXP16 timeout pc=%h",debug_commit_pc);
        $fatal;
    end
endmodule
`default_nettype wire
