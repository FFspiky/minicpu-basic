`timescale 1ns / 1ps
`default_nettype none

module tb_lcd_game_top;
    reg         clk;
    reg         resetn;
    reg  [31:0] game_car;
    reg  [31:0] game_obs;
    reg  [31:0] game_obs1;
    reg  [31:0] game_obs2;
    reg  [31:0] game_bonus;
    reg  [31:0] game_flags;
    reg  [31:0] game_score;
    reg         game_commit_toggle;

    wire [31:0] lcd_status;
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

    reg  [15:0] setup_data;
    reg         setup_rs;
    integer     wr_count;
    integer     ram_cmd_count;
    integer     pixel_count;
    integer     low_cycles;
    reg         first_frame_toggle;
    integer     rotation_checks;

    lcd_game_top #(
        .SIMULATION (1'b1),
        .H_RES      (16),
        .V_RES      (8)
    ) dut (
        .clk                (clk),
        .resetn             (resetn),
        .game_car           (game_car),
        .game_obs           (game_obs),
        .game_obs1          (game_obs1),
        .game_obs2          (game_obs2),
        .game_bonus         (game_bonus),
        .game_flags         (game_flags),
        .game_score         (game_score),
        .game_commit_toggle (game_commit_toggle),
        .leaderboard_bcd_scores (160'd0),
        .leaderboard_count  (4'd0),
        .lcd_status         (lcd_status),
        .lcd_rst            (lcd_rst),
        .lcd_cs             (lcd_cs),
        .lcd_rs             (lcd_rs),
        .lcd_wr             (lcd_wr),
        .lcd_rd             (lcd_rd),
        .lcd_data_io        (lcd_data_io),
        .lcd_bl_ctr         (lcd_bl_ctr),
        .ct_int             (ct_int),
        .ct_sda             (ct_sda),
        .ct_scl             (ct_scl),
        .ct_rstn            (ct_rstn)
    );

    initial
    begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk)
    begin
        setup_data = lcd_data_io;
        setup_rs   = lcd_rs;

        if (!lcd_wr)
        begin
            low_cycles = low_cycles + 1;
        end
        else if (low_cycles != 0)
        begin
            if (low_cycles < 2)
            begin
                $display("FAIL: WR low pulse too short: %0d", low_cycles);
                $fatal;
            end
            low_cycles = 0;
        end
    end

    always @(negedge lcd_wr)
    begin
        if (lcd_data_io !== setup_data || lcd_rs !== setup_rs)
        begin
            $display("FAIL: LCD data/RS changed without a setup cycle");
            $fatal;
        end

        wr_count = wr_count + 1;

        if (!lcd_rs && lcd_data_io == 16'h2C00)
        begin
            ram_cmd_count = ram_cmd_count + 1;
        end
        else if (lcd_rs && ram_cmd_count != 0)
        begin
            pixel_count = pixel_count + 1;
        end
    end

    always @(posedge clk)
    begin
        if (resetn && dut.init_done && dut.stream_fire &&
            dut.stream_state == dut.S_PIXELS)
        begin
            if (dut.px_y == 0 && dut.px_x == 0)
            begin
                if (dut.rotated_render_x !== 10'd0 || dut.rotated_render_y !== 9'd479)
                begin
                    $display("FAIL: LCD CW top-left maps to source (%0d,%0d)",
                             dut.rotated_render_x, dut.rotated_render_y);
                    $fatal;
                end
                rotation_checks = rotation_checks + 1;
            end
            if (dut.px_y == 0 && dut.px_x == 2)
            begin
                if (dut.rotated_render_x !== 10'd0 || dut.rotated_render_y !== 9'd478)
                begin
                    $display("FAIL: LCD CW column progression source=(%0d,%0d)",
                             dut.rotated_render_x, dut.rotated_render_y);
                    $fatal;
                end
                rotation_checks = rotation_checks + 1;
            end
            if (dut.px_y == 1 && dut.px_x == 0)
            begin
                if (dut.rotated_render_x !== 10'd1 || dut.rotated_render_y !== 9'd479)
                begin
                    $display("FAIL: LCD CW row progression source=(%0d,%0d)",
                             dut.rotated_render_x, dut.rotated_render_y);
                    $fatal;
                end
                rotation_checks = rotation_checks + 1;
            end
        end
    end

    initial
    begin
        resetn             = 1'b0;
        game_car           = 32'h0000_0d21;
        game_obs           = 32'h8000_0200;
        game_obs1          = 32'h8000_0281;
        game_obs2          = 32'h8000_0302;
        game_bonus         = 32'h8000_0301;
        game_flags         = 32'h0000_0019;
        game_score         = 32'h0002_0010;
        game_commit_toggle = 1'b0;
        wr_count           = 0;
        ram_cmd_count      = 0;
        pixel_count        = 0;
        low_cycles         = 0;
        first_frame_toggle = 1'b0;
        rotation_checks     = 0;

        #100;
        resetn = 1'b1;
        wait (lcd_status[0] == 1'b1);
        wait (pixel_count >= 16);
        first_frame_toggle = lcd_status[1];

        game_car = 32'h0000_0642;
        game_obs1 = 32'h8000_0182;
        game_commit_toggle = ~game_commit_toggle;
        wait (lcd_status[2] == game_commit_toggle);

        if (dut.render_car_lane !== 2'd1)
        begin
            $display("FAIL: render snapshot changed before frame boundary");
            $fatal;
        end

        wait (lcd_status[1] != first_frame_toggle);
        @(posedge clk);

        if (dut.render_car_lane !== 2'd2 || dut.render_car_y !== 9'd100 ||
            dut.render_obs1_x !== 10'd24)
        begin
            $display("FAIL: pending state was not applied at frame boundary");
            $fatal;
        end

        repeat (16) @(posedge clk);

        if (lcd_cs !== 1'b0 || lcd_rd !== 1'b1 || lcd_bl_ctr !== 1'b1)
        begin
            $display("FAIL: fixed LCD control pins are not in write-display mode");
            $fatal;
        end

        if (ram_cmd_count < 1 || pixel_count < 128)
        begin
            $display("FAIL: insufficient LCD stream writes, ram_cmd=%0d pixel=%0d total=%0d",
                     ram_cmd_count, pixel_count, wr_count);
            $fatal;
        end
        if (rotation_checks < 3)
        begin
            $display("FAIL: insufficient LCD CW rotation checks: %0d", rotation_checks);
            $fatal;
        end

        $display("PASS: LCD timing, frame snapshot, stream, and CW mapping checked");
        #100;
        $finish;
    end

endmodule

`default_nettype wire
