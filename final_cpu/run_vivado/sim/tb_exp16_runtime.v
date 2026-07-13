`timescale 1ns/1ps
`default_nettype none

module tb_exp16_runtime;
    reg clk=0, resetn=0;
    wire [1:0] led_rg0,led_rg1;
    wire [31:0] debug_commit_pc;
    wire debug_commit_valid;
    wire uart_dtr;
    tri [7:0] nand_io;
    integer cycles;

    always #5 clk=~clk;

    soc_lite_top #(.SIMULATION(1'b1),.SINGLE_STEP(1'b0)) dut(
        .resetn(resetn),.clk(clk),.uart_rx(1'b1),.uart_dtr(uart_dtr),
        .warm_reset_request(1'b0),.nand_io(nand_io),.nand_rb_n(1'b1),
        .switch(8'hff),.btn_key_row(4'hf),.btn_step(2'b11),
        .external_key_state(16'd0),.lcd_status(32'd0),
        .led_rg0(led_rg0),.led_rg1(led_rg1),
        .debug_commit_pc(debug_commit_pc),.debug_commit_valid(debug_commit_valid));

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
            $display("PASS PIPELINE EXP16 cycles=%0d pc=%h",cycles,debug_commit_pc);
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
