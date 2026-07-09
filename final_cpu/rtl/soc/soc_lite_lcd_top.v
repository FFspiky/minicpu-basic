`timescale 1ns / 1ps
`default_nettype none

module soc_lite_lcd_top #(
    parameter SIMULATION  = 1'b0,
    parameter SINGLE_STEP = 1'b0,
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

    wire board_clk;

    generate if (SIMULATION)
    begin: sim_clock
        assign board_clk = clk;
    end
    else
    begin: board_clock
        wire clk_ibuf;

        IBUF u_board_clk_ibuf(
            .I (clk),
            .O (clk_ibuf)
        );

        BUFG u_board_clk_bufg(
            .I (clk_ibuf),
            .O (board_clk)
        );
    end
    endgenerate

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

    soc_lite_top #(
        .SIMULATION  (SIMULATION),
        .SINGLE_STEP (SINGLE_STEP),
        .END_PC      (END_PC)
    ) u_soc (
        .resetn              (resetn),
        .clk                 (board_clk),

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

    lcd_module u_lcd_module(
        .clk            (board_clk),
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

    always @(posedge board_clk)
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
