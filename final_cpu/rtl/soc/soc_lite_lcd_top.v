`timescale 1ns / 1ps
`default_nettype none

module soc_lite_lcd_top #(
    parameter SIMULATION  = 1'b0,
    parameter SINGLE_STEP = 1'b0,
    parameter GAME_LCD    = 1'b1,
    parameter [31:0] END_PC = 32'h1c000100
)
(
    input  wire        resetn,
    input  wire        clk,

    output wire [15:0] led,
    output wire [1 :0] led_rg0,
    output wire [1 :0] led_rg1,
    output wire [7 :0] num_csn,
    output wire [6 :0] num_a_g,
    output wire [31:0] num_data,
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

    wire lcd_clk;

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

    ps2_game_keyboard u_ps2_game_keyboard (
        .clk            (clk),
        .resetn         (resetn),
        .ps2_clk        (ps2_clk),
        .ps2_data       (ps2_data),
        .game_keys      (ps2_game_keys),
        .last_scan_code (ps2_last_scan_code),
        .scan_valid     (ps2_scan_valid)
    );

    game_leaderboard u_game_leaderboard (
        .clk                (lcd_clk),
        .resetn             (resetn),
        .game_flags         (game_flags),
        .game_score         (game_score),
        .game_score_bcd     (num_data),
        .game_commit_toggle (game_commit_toggle),
        .scores_packed      (leaderboard_scores),
        .scores_bcd_packed  (leaderboard_bcd_scores),
        .score_count        (leaderboard_count)
    );

    vga_game_top u_vga_game_top (
        .clk                (lcd_clk),
        .resetn             (resetn),
        .game_car           (game_car),
        .game_obs           (game_obs),
        .game_obs1          (game_obs1),
        .game_obs2          (game_obs2),
        .game_bonus         (game_bonus),
        .game_flags         (game_flags),
        .game_score         (game_score),
        .game_commit_toggle (game_commit_toggle),
        .vga_hsync          (vga_hsync),
        .vga_vsync          (vga_vsync),
        .vga_r              (vga_r),
        .vga_g              (vga_g),
        .vga_b              (vga_b)
    );

    soc_lite_top #(
        .SIMULATION  (SIMULATION),
        .SINGLE_STEP (SINGLE_STEP),
        .END_PC      (END_PC)
    ) u_soc (
        .resetn              (resetn),
        .clk                 (clk),

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
        .debug_run_done      (debug_run_done)
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
    reg  [31:0] num_data_lcd;
    reg  [7 :0] switch_lcd;

    reg         display_valid_next;
    reg  [39:0] display_name_next;
    reg  [31:0] display_value_next;

    generate if (GAME_LCD)
    begin: game_lcd
        assign display_number = 6'd0;
        assign input_valid    = 1'b0;
        assign input_value    = 32'd0;

        lcd_game_top #(
            .SIMULATION       (SIMULATION),
            .LEADERBOARD_MODE (1)
        ) u_lcd_game_top (
            .clk                (lcd_clk),
            .resetn             (resetn),
            .game_car           (game_car),
            .game_obs           (game_obs),
            .game_obs1          (game_obs1),
            .game_obs2          (game_obs2),
            .game_bonus         (game_bonus),
            .game_flags         (game_flags),
            .game_score         (game_score),
            .game_commit_toggle (game_commit_toggle),
            .leaderboard_bcd_scores (leaderboard_bcd_scores),
            .leaderboard_count  (leaderboard_count),
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
    end
    else
    begin: debug_lcd
        assign lcd_status = 32'd0;

        lcd_module u_lcd_module(
            .clk            (lcd_clk),
            .resetn         (resetn),

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
    end
    endgenerate

    always @(posedge lcd_clk)
    begin
        if (!resetn)
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
                display_name_next  = "NUM  ";
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
            default:
            begin
                display_valid_next = 1'b0;
                display_name_next  = 40'd0;
                display_value_next = 32'd0;
            end
        endcase
    end

endmodule

`default_nettype wire
