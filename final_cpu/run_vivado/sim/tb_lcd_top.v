`timescale 1ns / 1ps
`default_nettype none

module tb_lcd_top;
    localparam [31:0] LCD_SIM_END_PC = 32'h1c01018c;

    reg         clk;
    reg         resetn;
    reg  [7:0]  switch;
    wire [15:0] led;
    wire [1:0]  led_rg0;
    wire [1:0]  led_rg1;
    wire [7:0]  num_csn;
    wire [6:0]  num_a_g;
    wire [31:0] num_data;
    wire [3:0]  btn_key_col;
    reg  [3:0]  btn_key_row;
    reg  [1:0]  btn_step;

    wire        lcd_rst;
    wire        lcd_cs;
    wire        lcd_rs;
    wire        lcd_wr;
    wire        lcd_rd;
    wire [15:0] lcd_data_io;
    wire        lcd_bl_ctr;
    wire        ct_int;
    wire        ct_sda;
    wire        ct_scl;
    wire        ct_rstn;
    integer     timeout;

    soc_lite_lcd_top #(
        .SIMULATION  (1'b1),
        .SINGLE_STEP (1'b0),
        .END_PC      (LCD_SIM_END_PC)
    ) dut (
        .resetn      (resetn),
        .clk         (clk),
        .led         (led),
        .led_rg0     (led_rg0),
        .led_rg1     (led_rg1),
        .num_csn     (num_csn),
        .num_a_g     (num_a_g),
        .num_data    (num_data),
        .switch      (switch),
        .btn_key_col (btn_key_col),
        .btn_key_row (btn_key_row),
        .btn_step    (btn_step),
        .lcd_rst     (lcd_rst),
        .lcd_cs      (lcd_cs),
        .lcd_rs      (lcd_rs),
        .lcd_wr      (lcd_wr),
        .lcd_rd      (lcd_rd),
        .lcd_data_io (lcd_data_io),
        .lcd_bl_ctr  (lcd_bl_ctr),
        .ct_int      (ct_int),
        .ct_sda      (ct_sda),
        .ct_scl      (ct_scl),
        .ct_rstn     (ct_rstn)
    );

    initial
    begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial
    begin
        resetn      = 1'b0;
        switch      = 8'hff;
        btn_key_row = 4'hf;
        btn_step    = 2'b11;

        #200;
        resetn = 1'b1;
        #200;

        timeout = 0;
        while (!(dut.u_soc.debug_commit_valid && dut.u_soc.debug_commit_pc == LCD_SIM_END_PC) && timeout < 3000000)
        begin
            #10;
            timeout = timeout + 1;
        end
        if (timeout >= 3000000)
        begin
            $display("FAIL: continuous LCD smoke test did not reach LCD_SIM_END_PC");
            $display("DBG: step=%h cycle=%h mode=%b active=%b done=%b fetch=%h cmt=%h wb=%h pvld=%h hzd=%h",
                     dut.u_soc.debug_step_count,
                     dut.u_soc.debug_cycle_count,
                     dut.u_soc.debug_mode_run,
                     dut.u_soc.debug_run_active,
                     dut.u_soc.debug_run_done,
                     dut.u_soc.debug_fetch_pc,
                     dut.u_soc.debug_commit_pc,
                     dut.u_soc.debug_wb_pc,
                     dut.u_soc.debug_pipe_valid,
                     dut.u_soc.debug_pipe_hazard);
            $fatal;
        end

        $display("PASS: final_cpu LCD continuous smoke test completed");
        #100;
        $finish;
    end

endmodule

`default_nettype wire
