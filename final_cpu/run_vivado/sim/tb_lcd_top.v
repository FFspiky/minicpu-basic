`timescale 1ns / 1ps
`default_nettype none

module tb_lcd_top;
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
    reg         initial_commit_toggle;

    soc_lite_lcd_top #(
        .SIMULATION  (1'b1),
        .SINGLE_STEP (1'b0)
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
        initial_commit_toggle = dut.game_commit_toggle;
        resetn = 1'b1;
        #200;

        timeout = 0;
        while (dut.game_commit_toggle == initial_commit_toggle && timeout < 200000)
        begin
            #10;
            timeout = timeout + 1;
        end
        if (timeout >= 200000)
        begin
            $display("FAIL: racing game did not write GAME_COMMIT");
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

        if (dut.game_car[1:0] != 2'd1 || dut.game_flags[4:0] != 5'b11001 ||
            dut.game_obs[31] != 1'b1 || dut.game_obs[15:4] != 12'd799)
        begin
            $display("FAIL: racing game initial MMIO state mismatch car=%h obs=%h flags=%h score=%h",
                     dut.game_car, dut.game_obs, dut.game_flags, dut.game_score);
            $fatal;
        end

        timeout = 0;
        while (dut.lcd_status[0] != 1'b1 && timeout < 3000000)
        begin
            #10;
            timeout = timeout + 1;
        end
        if (timeout >= 3000000)
        begin
            $display("FAIL: LCD game renderer did not finish initialization");
            $display("DBG: lcd_status=%h", dut.lcd_status);
            $fatal;
        end

        if (lcd_cs !== 1'b0 || lcd_rd !== 1'b1 || lcd_bl_ctr !== 1'b1)
        begin
            $display("FAIL: LCD pins are not in active write-display mode");
            $fatal;
        end

        $display("PASS: racing game CPU MMIO boot and LCD init smoke test completed");
        #100;
        $finish;
    end

endmodule

`default_nettype wire
