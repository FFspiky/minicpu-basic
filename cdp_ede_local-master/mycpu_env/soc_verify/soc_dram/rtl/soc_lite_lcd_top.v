`timescale 1ns / 1ps
`default_nettype none

module soc_lite_lcd_top(
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

    wire clk_ibuf;
    wire board_clk;

    IBUF u_board_clk_ibuf(
        .I (clk),
        .O (clk_ibuf)
    );

    BUFG u_board_clk_bufg(
        .I (clk_ibuf),
        .O (board_clk)
    );

    wire [31:0] debug_wb_pc;
    wire [3 :0] debug_wb_rf_we;
    wire [4 :0] debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata;
    wire [31:0] debug_inst;
    wire        debug_cpu_en;
    wire [31:0] debug_step_count;

    soc_lite_top #(
        .SIMULATION  (1'b0),
        .SINGLE_STEP (1'b1)
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
        .debug_step_count    (debug_step_count)
    );

    reg         display_valid;
    reg  [39:0] display_name;
    reg  [31:0] display_value;

    wire [5 :0] display_number;
    wire        input_valid;
    wire [31:0] input_value;

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

    always @(*)
    begin
        case (display_number)
            6'd1:
            begin
                display_valid = 1'b1;
                display_name  = "WBPC ";
                display_value = debug_wb_pc;
            end
            6'd2:
            begin
                display_valid = 1'b1;
                display_name  = "INST ";
                display_value = debug_inst;
            end
            6'd3:
            begin
                display_valid = 1'b1;
                display_name  = "WNUM ";
                display_value = {27'd0, debug_wb_rf_wnum};
            end
            6'd4:
            begin
                display_valid = 1'b1;
                display_name  = "WDAT ";
                display_value = debug_wb_rf_wdata;
            end
            6'd5:
            begin
                display_valid = 1'b1;
                display_name  = "WE   ";
                display_value = {28'd0, debug_wb_rf_we};
            end
            6'd6:
            begin
                display_valid = 1'b1;
                display_name  = "STEP ";
                display_value = debug_step_count;
            end
            6'd7:
            begin
                display_valid = 1'b1;
                display_name  = "NUM  ";
                display_value = num_data;
            end
            6'd8:
            begin
                display_valid = 1'b1;
                display_name  = "SW   ";
                display_value = {24'd0, switch};
            end
            6'd9:
            begin
                display_valid = 1'b1;
                display_name  = "CPUE ";
                display_value = {31'd0, debug_cpu_en};
            end
            default:
            begin
                display_valid = 1'b0;
                display_name  = 40'd0;
                display_value = 32'd0;
            end
        endcase
    end

endmodule

`default_nettype wire
