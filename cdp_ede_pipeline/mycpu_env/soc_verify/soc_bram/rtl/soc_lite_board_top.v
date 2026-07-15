`timescale 1ns / 1ps
`default_nettype none

// Physical-board wrapper for the BRAM SoC.
//
// soc_lite_top intentionally exposes a wide set of pipeline observation
// signals for trace simulation and the LCD debug UI.  Making that module the
// implementation top turns every debug bit into a package pin.  Keep those
// ports inside this wrapper so implementation only sees real board I/O.
module soc_lite_board_top
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
    input  wire [1 :0] btn_step
);

    soc_lite_top u_soc (
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

        .debug_wb_pc         (),
        .debug_wb_rf_we      (),
        .debug_wb_rf_wnum    (),
        .debug_wb_rf_wdata   (),
        .debug_inst          (),
        .debug_cpu_en        (),
        .debug_step_count    (),
        .debug_cycle_count   (),
        .debug_commit_valid  (),
        .debug_commit_pc     (),
        .debug_commit_inst   (),
        .debug_fetch_pc      (),
        .debug_pipe_valid    (),
        .debug_pipe_hazard   (),
        .debug_last_wb_valid (),
        .debug_last_wb_pc    (),
        .debug_last_wb_wnum  (),
        .debug_last_wb_wdata (),
        .debug_mode_run      (),
        .debug_run_active    (),
        .debug_run_done      (),
        .lcd_clk             ()
    );

endmodule

`default_nettype wire
