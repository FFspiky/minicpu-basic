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
    reg         ps2_clk;
    reg         ps2_data;
    reg         uart_rx;
    wire        uart_dtr;
    wire        uart_tx;
    tri  [7:0]  nand_io;
    reg         nand_rb_n;
    wire        nand_cle;
    wire        nand_ale;
    wire        nand_ce_n;
    wire        nand_re_n;
    wire        nand_we_n;

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
    wire        vga_hsync;
    wire        vga_vsync;
    wire [3:0]  vga_r;
    wire [3:0]  vga_g;
    wire [3:0]  vga_b;
    integer     timeout;
    reg         initial_commit_toggle;
    reg         test_passed = 1'b0;

    soc_lite_lcd_top #(
        .SIMULATION  (1'b1),
        .SINGLE_STEP (1'b0)
    ) dut (
        .resetn      (resetn),
        .clk         (clk),
        .uart_rx     (uart_rx),
        .uart_dtr    (uart_dtr),
        .uart_tx     (uart_tx),
        .nand_io     (nand_io),
        .nand_rb_n   (nand_rb_n),
        .nand_cle    (nand_cle),
        .nand_ale    (nand_ale),
        .nand_ce_n   (nand_ce_n),
        .nand_re_n   (nand_re_n),
        .nand_we_n   (nand_we_n),
        .led         (led),
        .led_rg0     (led_rg0),
        .led_rg1     (led_rg1),
        .num_csn     (num_csn),
        .num_a_g     (num_a_g),
        .switch      (switch),
        .btn_key_col (btn_key_col),
        .btn_key_row (btn_key_row),
        .btn_step    (btn_step),
        .ps2_clk     (ps2_clk),
        .ps2_data    (ps2_data),
        .vga_hsync   (vga_hsync),
        .vga_vsync   (vga_vsync),
        .vga_r       (vga_r),
        .vga_g       (vga_g),
        .vga_b       (vga_b),
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
        ps2_clk     = 1'b1;
        ps2_data    = 1'b1;
        uart_rx     = 1'b1;
        nand_rb_n   = 1'b1;

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

        if (dut.game_car[1:0] != 2'd1 || dut.game_car[15:4] != 12'd210 ||
            dut.game_flags[5:0] != 6'h39 ||
            dut.game_obs[31] != 1'b0 || dut.game_obs[15:4] != 12'd799 ||
            dut.game_obs1[31] != 1'b0 || dut.game_obs1[15:4] != 12'd799 ||
            dut.game_obs2[31] != 1'b0 || dut.game_obs2[15:4] != 12'd799 ||
            num_data != 32'h0000_0000 || led != 16'hffff)
        begin
            $display("FAIL: racing game initial MMIO state mismatch car=%h obs=%h obs1=%h obs2=%h flags=%h score=%h num=%h led=%h",
                     dut.game_car, dut.game_obs, dut.game_obs1, dut.game_obs2,
                     dut.game_flags, dut.game_score, num_data, led);
            $fatal;
        end

        // The dedicated LED register directly drives active-low board LEDs.
        force dut.u_soc.u_confreg.led_data = 32'h0000_8000;
        #10;
        if (led != 16'h7fff)
        begin
            $display("FAIL: level 1 did not light only the leftmost LED, led=%h", led);
            $fatal;
        end
        force dut.u_soc.u_confreg.led_data = 32'h0000_ffff;
        #10;
        if (led != 16'h0000)
        begin
            $display("FAIL: level 16 did not light all LEDs, led=%h", led);
            $fatal;
        end
        release dut.u_soc.u_confreg.led_data;

        // Start, exercise a running control, pause, resume, then hardware-reset.
        force dut.u_soc.u_confreg.btn_key_data = 32'h0000_2000;
        #20000;
        release dut.u_soc.u_confreg.btn_key_data;
        #20000;
        if (dut.game_flags[5] !== 1'b0 || dut.game_flags[1] !== 1'b0)
        begin
            $display("FAIL: first key did not start the waiting game, flags=%h",
                     dut.game_flags);
            $fatal;
        end

        initial_commit_toggle = dut.game_commit_toggle;
        force dut.u_soc.u_confreg.btn_key_data = 32'h0000_8000;
        #20000;
        release dut.u_soc.u_confreg.btn_key_data;
        #20000;
        if (dut.game_commit_toggle !== initial_commit_toggle ||
            dut.game_flags[1] !== 1'b0)
        begin
            $display("FAIL: running direction key caused an immediate restart, commit=%b flags=%h",
                     dut.game_commit_toggle, dut.game_flags);
            $fatal;
        end

        force dut.u_soc.u_confreg.btn_key_data = 32'h0000_4000;
        #20000;
        release dut.u_soc.u_confreg.btn_key_data;
        #20000;
        if (dut.game_flags[1] !== 1'b1 || dut.game_car[1:0] !== 2'd2)
        begin
            $display("FAIL: pause did not preserve the running lane, car=%h flags=%h",
                     dut.game_car, dut.game_flags);
            $fatal;
        end

        force dut.u_soc.u_confreg.btn_key_data = 32'h0000_2000;
        #20000;
        release dut.u_soc.u_confreg.btn_key_data;
        #20000;
        if (dut.game_flags[1] !== 1'b1 || dut.game_car[1:0] !== 2'd2)
        begin
            $display("FAIL: non-pause key incorrectly restarted the paused game, car=%h flags=%h",
                     dut.game_car, dut.game_flags, led);
            $fatal;
        end

        force dut.u_soc.u_confreg.btn_key_data = 32'h0000_4000;
        #20000;
        release dut.u_soc.u_confreg.btn_key_data;
        #20000;
        if (dut.game_flags[1] !== 1'b0 || dut.game_car[1:0] !== 2'd2)
        begin
            $display("FAIL: Down key did not resume the paused game, car=%h flags=%h",
                     dut.game_car, dut.game_flags);
            $fatal;
        end

        force dut.u_soc.u_confreg.btn_key_data = 32'h0000_4000;
        #20000;
        release dut.u_soc.u_confreg.btn_key_data;
        #20000;
        force dut.u_soc.u_confreg.btn_key_data = 32'h0000_1000;
        #20000;
        release dut.u_soc.u_confreg.btn_key_data;
        #20000;
        if (dut.game_car[1:0] !== 2'd1 || dut.game_flags[1] !== 1'b0)
        begin
            $display("FAIL: SW13 soft restart did not reset game state, car=%h flags=%h",
                     dut.game_car, dut.game_flags);
            $fatal;
        end

`ifndef GAME_SIM_FAST
        if (led !== 16'hffff)
        begin
            $display("FAIL: SW13 soft restart did not clear LEDs, led=%h", led);
            $fatal;
        end
`endif

        resetn = 1'b0;
        #200;
        initial_commit_toggle = dut.game_commit_toggle;
        resetn = 1'b1;
        timeout = 0;
        while (dut.game_commit_toggle == initial_commit_toggle && timeout < 200000)
        begin
            #10;
            timeout = timeout + 1;
        end
        if (timeout >= 200000 || dut.game_car[1:0] !== 2'd1 ||
            dut.game_flags[5:0] !== 6'h39 || led !== 16'hffff)
        begin
            $display("FAIL: board reset did not return the game to PRESS KEY, car=%h flags=%h led=%h",
                     dut.game_car, dut.game_flags, led);
            $fatal;
        end

`ifdef GAME_SIM_FAST
        force dut.u_soc.u_confreg.btn_key_data = 32'h0000_2000;
        #5000;
        release dut.u_soc.u_confreg.btn_key_data;
        #5000;
        timeout = 0;
        while (dut.game_flags[10:6] == 5'd0 && timeout < 500000)
        begin
            #10;
            timeout = timeout + 1;
        end
        if (timeout >= 500000 || dut.game_flags[10:6] !== 5'd1 ||
            dut.u_soc.u_confreg.led_data[15:0] !== 16'h8000 ||
            led !== 16'h7fff)
        begin
            $display("FAIL: CPU level-up did not write the level-1 LED mask, flags=%h led_data=%h led=%h",
                     dut.game_flags, dut.u_soc.u_confreg.led_data, led);
            $fatal;
        end
`endif

        force dut.display_number = 6'd1;
        #100;
        if (dut.display_valid !== 1'b1 || dut.display_name !== "WBPC " ||
            dut.lcd_status !== 32'd0)
        begin
            $display("FAIL: LCD debug page did not select WBPC after reset name=%h valid=%b status=%h",
                     dut.display_name, dut.display_valid, dut.lcd_status);
            $fatal;
        end
        release dut.display_number;

        force dut.input_value = 32'h1234_abcd;
        force dut.input_valid = 1'b1;
        #40;
        force dut.input_valid = 1'b0;
        #40;
        if (dut.lcd_status[30:0] !== 31'h1234_abcd ||
            dut.lcd_status[31] !== 1'b1)
        begin
            $display("FAIL: LCD touch input did not reach CPU mailbox status=%h",
                     dut.lcd_status);
            $fatal;
        end
        force dut.input_valid = 1'b1;
        #40;
        force dut.input_valid = 1'b0;
        #40;
        if (dut.lcd_status[31] !== 1'b0)
        begin
            $display("FAIL: repeated LCD input did not toggle mailbox status=%h",
                     dut.lcd_status);
            $fatal;
        end
        release dut.input_valid;
        release dut.input_value;

        // Generic runtime completion must replace the static exit-loop PC
        // with the C program's result, independent of the selected page.
        force dut.debug_system_mode = 2'd3;
        force dut.menu_status = 8'd4;
        force dut.num_data = 32'h1234_abcd;
        force dut.display_number = 6'd8;
        #100;
        if (dut.display_valid !== 1'b1 || dut.display_name !== "OUT: " ||
            dut.display_value !== 32'h1234_abcd)
        begin
            $display("FAIL: completed C program left stale PC on LCD name=%h value=%h",
                     dut.display_name, dut.display_value);
            $fatal;
        end
        release dut.debug_system_mode;
        release dut.menu_status;
        release dut.num_data;
        release dut.display_number;
        #100;
        if (dut.display_name === "OUT: ")
        begin
            $display("FAIL: LCD output override survived program/menu transition");
            $fatal;
        end

        if (lcd_cs !== 1'b1 || lcd_rd !== 1'b1 || lcd_bl_ctr !== 1'b1)
        begin
            $display("FAIL: LCD debug module pins are not in the expected state");
            $fatal;
        end

        $display("PASS: racing game CPU MMIO boot and LCD debug-page smoke test completed");
        test_passed = 1'b1;
        #100;
        $finish;
    end

endmodule

`default_nettype wire
