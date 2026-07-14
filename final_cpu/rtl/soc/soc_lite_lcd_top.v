`timescale 1ns / 1ps
`default_nettype none

module soc_lite_lcd_top #(
    parameter SIMULATION  = 1'b0,
    parameter SINGLE_STEP = 1'b1,
    parameter [31:0] END_PC = 32'h1c000100
)
(
    input  wire        resetn,
    input  wire        clk,
    input  wire        uart_rx,
    output wire        uart_dtr,
    output wire        uart_tx,
    inout  wire [7:0]  nand_io,
    input  wire        nand_rb_n,
    output wire        nand_cle,
    output wire        nand_ale,
    output wire        nand_ce_n,
    output wire        nand_re_n,
    output wire        nand_we_n,
    output wire        nand_wp_n,

    output wire [15:0] led,
    output wire [1 :0] led_rg0,
    output wire [1 :0] led_rg1,
    output wire [7 :0] num_csn,
    output wire [6 :0] num_a_g,
    input  wire [7 :0] switch,
    output wire [3 :0] btn_key_col,
    input  wire [3 :0] btn_key_row,
    input  wire [1 :0] btn_step,

    input  wire        ps2_clk,
    input  wire        ps2_data,

    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,

    output wire        lcd_rst,
    output wire        lcd_cs,
    output wire        lcd_rs,
    output wire        lcd_wr,
    output wire        lcd_rd,
    inout  wire [15:0] lcd_data_io,
    output wire        lcd_bl_ctr,
    inout  wire        ct_int,
    inout  wire        ct_sda,
    output wire        ct_scl,
    output wire        ct_rstn
);

    // K9F1G08 WP# is an active-low hardware write protect input.  The board
    // routes it to T19, so keep it deasserted for erase/program operations.
    assign nand_wp_n = 1'b1;

    wire lcd_clk;
    wire clock_ready;
    wire peripheral_async_resetn = resetn && clock_ready;
    (* ASYNC_REG = "TRUE" *) reg [1:0] peripheral_reset_sync;
    wire peripheral_resetn = peripheral_reset_sync[1];
    wire [31:0] num_data;

    // Assert immediately when the board reset or PLL lock is lost, then
    // release synchronously in the 100 MHz peripheral domain.
    always @(posedge lcd_clk or negedge peripheral_async_resetn)
    begin
        if (!peripheral_async_resetn)
            peripheral_reset_sync <= 2'b00;
        else
            peripheral_reset_sync <= {peripheral_reset_sync[0], 1'b1};
    end

    wire [31:0] debug_wb_pc;
    wire [3 :0] debug_wb_rf_we;
    wire [4 :0] debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata;
    wire [31:0] debug_inst;
    wire        debug_cpu_en;
    wire [31:0] debug_step_count;
    wire [31:0] debug_cycle_count;
    wire        debug_commit_valid;
    wire [31:0] debug_commit_pc;
    wire [31:0] debug_commit_inst;
    wire [31:0] debug_fetch_pc;
    wire [3 :0] debug_pipe_valid;
    wire [2 :0] debug_pipe_hazard;
    wire        debug_last_wb_valid;
    wire [31:0] debug_last_wb_pc;
    wire [4 :0] debug_last_wb_wnum;
    wire [31:0] debug_last_wb_wdata;
    wire        debug_mode_run;
    wire        debug_run_active;
    wire        debug_run_done;
    wire [1:0]  debug_system_mode;
    wire [3:0]  debug_active_slot;
    wire [3:0]  menu_selected_slot;
    wire [15:0] menu_slot_valid;
    wire [7:0]  menu_status;

    wire [31:0] game_car;
    wire [31:0] game_obs;
    wire [31:0] game_obs1;
    wire [31:0] game_obs2;
    wire [31:0] game_bonus;
    wire [31:0] game_flags;
    wire [31:0] game_score;
    wire        game_commit_toggle;
    wire [31:0] lcd_status;
    wire [15:0] ps2_game_keys;
    wire [7:0]  ps2_last_scan_code;
    wire        ps2_scan_valid;
    wire [127:0] leaderboard_scores;
    wire [159:0] leaderboard_bcd_scores;
    wire [3:0]   leaderboard_count;
    reg f12_key_last;
    wire f12_key_event = ps2_game_keys[8] && !f12_key_last;
    reg [2:0] f12_request_stretch;
    wire f12_reset_request = |f12_request_stretch;

    // The keyboard decoder runs from the PLL's 100 MHz peripheral clock.
    // Stretch F12 long enough for the 50 MHz CPU domain to synchronize it.
    always @(posedge lcd_clk or negedge peripheral_resetn)
    begin
        if (!peripheral_resetn)
        begin
            f12_key_last <= 1'b0;
            f12_request_stretch <= 3'd0;
        end
        else
        begin
            f12_key_last <= ps2_game_keys[8];
            if (f12_key_event)
                f12_request_stretch <= 3'd7;
            else if (f12_request_stretch != 0)
                f12_request_stretch <= f12_request_stretch - 1'b1;
        end
    end

    ps2_game_keyboard u_ps2_game_keyboard (
        .clk            (lcd_clk),
        .resetn         (peripheral_resetn),
        .ps2_clk        (ps2_clk),
        .ps2_data       (ps2_data),
        .game_keys      (ps2_game_keys),
        .last_scan_code (ps2_last_scan_code),
        .scan_valid     (ps2_scan_valid)
    );

    game_leaderboard u_game_leaderboard (
        .clk                (lcd_clk),
        .resetn             (peripheral_resetn),
        .game_flags         (game_flags),
        .game_score         (game_score),
        .game_score_bcd     (num_data),
        .game_commit_toggle (game_commit_toggle),
        .scores_packed      (leaderboard_scores),
        .scores_bcd_packed  (leaderboard_bcd_scores),
        .score_count        (leaderboard_count)
    );

    wire game_vga_hsync, game_vga_vsync;
    wire [3:0] game_vga_r, game_vga_g, game_vga_b;
    wire menu_vga_hsync, menu_vga_vsync;
    wire [3:0] menu_vga_r, menu_vga_g, menu_vga_b;

    vga_game_top u_vga_game_top (
        .clk                (lcd_clk),
        .resetn             (peripheral_resetn),
        .game_car           (game_car),
        .game_obs           (game_obs),
        .game_obs1          (game_obs1),
        .game_obs2          (game_obs2),
        .game_bonus         (game_bonus),
        .game_flags         (game_flags),
        .game_score         (game_score),
        .game_commit_toggle (game_commit_toggle),
        .current_score_bcd  (num_data[19:0]),
        .leaderboard_bcd_scores (leaderboard_bcd_scores),
        .leaderboard_count  (leaderboard_count),
        .vga_hsync          (game_vga_hsync),
        .vga_vsync          (game_vga_vsync),
        .vga_r              (game_vga_r),
        .vga_g              (game_vga_g),
        .vga_b              (game_vga_b)
    );

    vga_program_menu u_vga_program_menu (
        .clk(lcd_clk), .resetn(peripheral_resetn),
        .selected_slot(menu_selected_slot), .slot_valid(menu_slot_valid),
        .status(menu_status), .system_mode(debug_system_mode),
        .led_rg0(led_rg0), .led_rg1(led_rg1),
        .vga_hsync(menu_vga_hsync), .vga_vsync(menu_vga_vsync),
        .vga_r(menu_vga_r), .vga_g(menu_vga_g), .vga_b(menu_vga_b)
    );

    wire game_vga_selected = debug_system_mode == 2'd1;
    assign vga_hsync = game_vga_selected ? game_vga_hsync : menu_vga_hsync;
    assign vga_vsync = game_vga_selected ? game_vga_vsync : menu_vga_vsync;
    assign vga_r = game_vga_selected ? game_vga_r : menu_vga_r;
    assign vga_g = game_vga_selected ? game_vga_g : menu_vga_g;
    assign vga_b = game_vga_selected ? game_vga_b : menu_vga_b;

    soc_lite_top #(
        .SIMULATION  (SIMULATION),
        .SINGLE_STEP (SINGLE_STEP),
        .END_PC      (END_PC)
    ) u_soc (
        .resetn              (resetn),
        .clk                 (clk),
        .uart_rx             (uart_rx),
        .uart_dtr            (uart_dtr),
        .warm_reset_request  (f12_reset_request),
        .uart_tx             (uart_tx),
        .nand_io             (nand_io),
        .nand_rb_n           (nand_rb_n),
        .nand_cle            (nand_cle),
        .nand_ale            (nand_ale),
        .nand_ce_n           (nand_ce_n),
        .nand_re_n           (nand_re_n),
        .nand_we_n           (nand_we_n),

        .led                 (led),
        .led_rg0             (led_rg0),
        .led_rg1             (led_rg1),
        .num_csn             (num_csn),
        .num_a_g             (num_a_g),
        .num_data            (num_data),
        .switch              (switch),
        .btn_key_col         (btn_key_col),
        .btn_key_row         (btn_key_row),
        .btn_step            (btn_step),
        .external_key_state  (ps2_game_keys),
        .lcd_clk             (lcd_clk),
        .clock_ready         (clock_ready),

        .game_car            (game_car),
        .game_obs            (game_obs),
        .game_obs1           (game_obs1),
        .game_obs2           (game_obs2),
        .game_bonus          (game_bonus),
        .game_flags          (game_flags),
        .game_score          (game_score),
        .game_commit_toggle  (game_commit_toggle),
        .lcd_status          (lcd_status),

        .debug_wb_pc         (debug_wb_pc),
        .debug_wb_rf_we      (debug_wb_rf_we),
        .debug_wb_rf_wnum    (debug_wb_rf_wnum),
        .debug_wb_rf_wdata   (debug_wb_rf_wdata),
        .debug_inst          (debug_inst),
        .debug_cpu_en        (debug_cpu_en),
        .debug_step_count    (debug_step_count),
        .debug_cycle_count   (debug_cycle_count),
        .debug_commit_valid  (debug_commit_valid),
        .debug_commit_pc     (debug_commit_pc),
        .debug_commit_inst   (debug_commit_inst),
        .debug_fetch_pc      (debug_fetch_pc),
        .debug_pipe_valid    (debug_pipe_valid),
        .debug_pipe_hazard   (debug_pipe_hazard),
        .debug_last_wb_valid (debug_last_wb_valid),
        .debug_last_wb_pc    (debug_last_wb_pc),
        .debug_last_wb_wnum  (debug_last_wb_wnum),
        .debug_last_wb_wdata (debug_last_wb_wdata),
        .debug_mode_run      (debug_mode_run),
        .debug_run_active    (debug_run_active),
        .debug_run_done      (debug_run_done),
        .debug_system_mode   (debug_system_mode),
        .debug_active_slot   (debug_active_slot),
        .menu_selected_slot (menu_selected_slot),
        .menu_slot_valid    (menu_slot_valid),
        .menu_status        (menu_status)
    );

    reg         display_valid;
    reg  [39:0] display_name;
    reg  [31:0] display_value;

    wire [5 :0] display_number;
    wire        input_valid;
    wire [31:0] input_value;

    reg  [31:0] debug_wb_pc_lcd;
    reg  [31:0] debug_inst_lcd;
    reg  [31:0] debug_step_count_lcd;
    reg  [31:0] debug_cycle_count_lcd;
    reg  [31:0] debug_commit_pc_lcd;
    reg  [31:0] debug_commit_inst_lcd;
    reg  [31:0] debug_fetch_pc_lcd;
    reg  [3 :0] debug_pipe_valid_lcd;
    reg  [2 :0] debug_pipe_hazard_lcd;
    reg         debug_last_wb_valid_lcd;
    reg  [31:0] debug_last_wb_pc_lcd;
    reg  [4 :0] debug_last_wb_wnum_lcd;
    reg  [31:0] debug_last_wb_wdata_lcd;
    reg         debug_mode_run_lcd;
    reg         debug_run_active_lcd;
    reg         debug_run_done_lcd;
    reg  [1 :0] debug_system_mode_lcd;
    reg  [3 :0] debug_active_slot_lcd;
    reg  [7 :0] menu_status_lcd;
    reg  [31:0] num_data_lcd;
    reg  [7 :0] switch_lcd;

    reg         display_valid_next;
    reg  [39:0] display_name_next;
    reg  [31:0] display_value_next;

    assign lcd_status = 32'd0;

    lcd_module u_lcd_module(
            .clk            (lcd_clk),
            .resetn         (peripheral_resetn),

            .display_valid  (display_valid),
            .display_name   (display_name),
            .display_value  (display_value),
            .display_number (display_number),

            .input_valid    (input_valid),
            .input_value    (input_value),

            .lcd_rst        (lcd_rst),
            .lcd_cs         (lcd_cs),
            .lcd_rs         (lcd_rs),
            .lcd_wr         (lcd_wr),
            .lcd_rd         (lcd_rd),
            .lcd_data_io    (lcd_data_io),
            .lcd_bl_ctr     (lcd_bl_ctr),

            .ct_int         (ct_int),
            .ct_sda         (ct_sda),
            .ct_scl         (ct_scl),
            .ct_rstn        (ct_rstn)
    );

    always @(posedge lcd_clk)
    begin
        if (!peripheral_resetn)
        begin
            debug_wb_pc_lcd          <= 32'd0;
            debug_inst_lcd           <= 32'd0;
            debug_step_count_lcd     <= 32'd0;
            debug_cycle_count_lcd    <= 32'd0;
            debug_commit_pc_lcd      <= 32'd0;
            debug_commit_inst_lcd    <= 32'd0;
            debug_fetch_pc_lcd       <= 32'd0;
            debug_pipe_valid_lcd     <= 4'd0;
            debug_pipe_hazard_lcd    <= 3'd0;
            debug_last_wb_valid_lcd  <= 1'b0;
            debug_last_wb_pc_lcd     <= 32'd0;
            debug_last_wb_wnum_lcd   <= 5'd0;
            debug_last_wb_wdata_lcd  <= 32'd0;
            debug_mode_run_lcd       <= 1'b0;
            debug_run_active_lcd     <= 1'b0;
            debug_run_done_lcd       <= 1'b0;
            debug_system_mode_lcd    <= 2'd0;
            debug_active_slot_lcd    <= 4'd0;
            menu_status_lcd          <= 8'd0;
            num_data_lcd             <= 32'd0;
            switch_lcd               <= 8'd0;
            display_valid            <= 1'b0;
            display_name             <= 40'd0;
            display_value            <= 32'd0;
        end
        else
        begin
            debug_wb_pc_lcd          <= debug_wb_pc;
            debug_inst_lcd           <= debug_inst;
            debug_step_count_lcd     <= debug_step_count;
            debug_cycle_count_lcd    <= debug_cycle_count;
            debug_commit_pc_lcd      <= debug_commit_pc;
            debug_commit_inst_lcd    <= debug_commit_inst;
            debug_fetch_pc_lcd       <= debug_fetch_pc;
            debug_pipe_valid_lcd     <= debug_pipe_valid;
            debug_pipe_hazard_lcd    <= debug_pipe_hazard;
            debug_last_wb_valid_lcd  <= debug_last_wb_valid;
            debug_last_wb_pc_lcd     <= debug_last_wb_pc;
            debug_last_wb_wnum_lcd   <= debug_last_wb_wnum;
            debug_last_wb_wdata_lcd  <= debug_last_wb_wdata;
            debug_mode_run_lcd       <= debug_mode_run;
            debug_run_active_lcd     <= debug_run_active;
            debug_run_done_lcd       <= debug_run_done;
            debug_system_mode_lcd    <= debug_system_mode;
            debug_active_slot_lcd    <= debug_active_slot;
            menu_status_lcd          <= menu_status;
            num_data_lcd             <= num_data;
            switch_lcd               <= switch;
            display_valid            <= display_valid_next;
            display_name             <= display_name_next;
            display_value            <= display_value_next;
        end
    end

    wire [3:0] last_wb_ones_value = (debug_last_wb_wnum_lcd >= 5'd30) ? (debug_last_wb_wnum_lcd - 5'd30) :
                                    (debug_last_wb_wnum_lcd >= 5'd20) ? (debug_last_wb_wnum_lcd - 5'd20) :
                                    (debug_last_wb_wnum_lcd >= 5'd10) ? (debug_last_wb_wnum_lcd - 5'd10) :
                                                                        debug_last_wb_wnum_lcd[3:0];
    wire [7:0] last_wb_tens_char  = (debug_last_wb_wnum_lcd >= 5'd30) ? 8'h33 :
                                    (debug_last_wb_wnum_lcd >= 5'd20) ? 8'h32 :
                                    (debug_last_wb_wnum_lcd >= 5'd10) ? 8'h31 :
                                                                    8'h30;
    wire [7:0] last_wb_ones_char  = 8'h30 + {4'b0, last_wb_ones_value};
    wire [39:0] last_wb_name = debug_last_wb_valid_lcd ? {8'h52, last_wb_tens_char, last_wb_ones_char, 16'h2020} :
                                                         "R--  ";

    always @(*)
    begin
        // A completed generic program parks in its runtime exit loop, so its
        // last commit PC is intentionally static.  Replace every selected
        // debug page with the application result until a warm reset returns
        // to the menu or another program starts.
        if (debug_system_mode_lcd == 2'd3 && menu_status_lcd == 8'd4)
        begin
            display_valid_next = 1'b1;
            display_name_next  = "OUT: ";
            display_value_next = num_data_lcd;
        end
        else
        begin
          case (display_number)
            6'd1:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "WBPC ";
                display_value_next = debug_wb_pc_lcd;
            end
            6'd2:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "INST ";
                display_value_next = debug_inst_lcd;
            end
            6'd3:
            begin
                display_valid_next = 1'b1;
                display_name_next  = last_wb_name;
                display_value_next = debug_last_wb_valid_lcd ? debug_last_wb_wdata_lcd : 32'd0;
            end
            6'd4:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "WRPC ";
                display_value_next = debug_last_wb_valid_lcd ? debug_last_wb_pc_lcd : 32'd0;
            end
            6'd5:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "STEP ";
                display_value_next = debug_step_count_lcd;
            end
            6'd6:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "CYCL ";
                display_value_next = debug_cycle_count_lcd;
            end
            6'd7:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "IFPC ";
                display_value_next = debug_fetch_pc_lcd;
            end
            6'd8:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "CMTPC";
                display_value_next = debug_commit_pc_lcd;
            end
            6'd9:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "CMTI ";
                display_value_next = debug_commit_inst_lcd;
            end
            6'd10:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "PVLD ";
                display_value_next = {28'd0, debug_pipe_valid_lcd};
            end
            6'd11:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "HZD  ";
                display_value_next = {29'd0, debug_pipe_hazard_lcd};
            end
            6'd12:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "OUT: ";
                display_value_next = num_data_lcd;
            end
            6'd13:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "MODE ";
                display_value_next = {31'd0, debug_mode_run_lcd};
            end
            6'd14:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "RUN  ";
                display_value_next = {31'd0, debug_run_active_lcd};
            end
            6'd15:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "DONE ";
                display_value_next = {31'd0, debug_run_done_lcd};
            end
            6'd16:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "SW   ";
                display_value_next = {24'd0, switch_lcd};
            end
            6'd17:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "SYS  ";
                display_value_next = {30'd0, debug_system_mode_lcd};
            end
            6'd18:
            begin
                display_valid_next = 1'b1;
                display_name_next  = "SLOT ";
                display_value_next = {28'd0, debug_active_slot_lcd};
            end
            default:
            begin
                display_valid_next = 1'b0;
                display_name_next  = 40'd0;
                display_value_next = 32'd0;
            end
          endcase
        end
    end

endmodule

`default_nettype wire
