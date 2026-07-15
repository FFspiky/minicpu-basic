/*------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

Redistribution and use in source and binary forms, with or without modification,
are permitted under the terms distributed with the original teaching project.
------------------------------------------------------------------------------*/
`timescale 1ns / 1ps

`define TRACE_REF_FILE "../../../../../../../../gettrace/golden_trace.txt"
`define CONFREG_NUM_REG      soc_lite.u_confreg.num_data
`define CONFREG_OPEN_TRACE   soc_lite.u_confreg.open_trace
`define CONFREG_NUM_MONITOR  soc_lite.u_confreg.num_monitor
`define CONFREG_UART_DISPLAY soc_lite.u_confreg.write_uart_valid
`define CONFREG_UART_DATA    soc_lite.u_confreg.write_uart_data
`define END_PC 32'h1c000100

module tb_top();
    // These are the only fifteen signals intentionally kept at tb_top level.
    reg resetn;
    reg clk;
    wire soc_clk = soc_lite.cpu_clk;
    wire [31:0] debug_wb_pc = soc_lite.debug_wb_pc;
    wire [3 :0] debug_wb_rf_we = soc_lite.debug_wb_rf_we;
    wire [4 :0] debug_wb_rf_wnum = soc_lite.debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata = soc_lite.debug_wb_rf_wdata;
    wire [31:0] debug_commit_inst = soc_lite.debug_commit_inst;
    wire trace_cmp_flag;
    wire [31:0] ref_wb_pc;
    wire [4 :0] ref_wb_rf_wnum;
    wire [31:0] ref_wb_rf_wdata;
    wire [31:0] ref_wb_inst;
    wire [31:0] debug_wb_rf_wdata_v =
        mask_wdata(debug_wb_rf_wdata, debug_wb_rf_we);
    wire [31:0] ref_wb_rf_wdata_v =
        mask_wdata(ref_wb_rf_wdata, debug_wb_rf_we);

    function [31:0] mask_wdata;
        input [31:0] data;
        input [3:0] byte_we;
        begin
            mask_wdata = {
                data[31:24] & {8{byte_we[3]}},
                data[23:16] & {8{byte_we[2]}},
                data[15: 8] & {8{byte_we[1]}},
                data[7 : 0] & {8{byte_we[0]}}
            };
        end
    endfunction

    initial begin
        clk = 1'b0;
        resetn = 1'b0;
        #2000;
        resetn = 1'b1;
    end
    always #5 clk = ~clk;

    soc_lite_top #(.SIMULATION(1'b1)) soc_lite(
        .resetn      (resetn),
        .clk         (clk),
        .num_csn     (),
        .num_a_g     (),
        .led         (),
        .led_rg0     (),
        .led_rg1     (),
        .switch      (8'hff),
        .btn_key_col (),
        .btn_key_row (4'd0),
        .btn_step    (2'd3)
    );

    // All file handles, counters, lookup tables, and end/error state live in
    // this child scope so they do not appear in tb_top's Objects list.
    trace_scoreboard u_trace_scoreboard(
        .clk                 (soc_clk),
        .resetn              (resetn),
        .open_trace          (`CONFREG_OPEN_TRACE),
        .num_monitor         (`CONFREG_NUM_MONITOR),
        .num_reg             (`CONFREG_NUM_REG),
        .uart_display        (`CONFREG_UART_DISPLAY),
        .uart_data           (`CONFREG_UART_DATA),
        .commit_valid        (soc_lite.debug_commit_valid),
        .commit_pc           (soc_lite.debug_commit_pc),
        .debug_wb_pc         (debug_wb_pc),
        .debug_wb_rf_we      (debug_wb_rf_we),
        .debug_wb_rf_wnum    (debug_wb_rf_wnum),
        .debug_wb_rf_wdata   (debug_wb_rf_wdata),
        .debug_commit_inst   (debug_commit_inst),
        .trace_cmp_flag      (trace_cmp_flag),
        .ref_wb_pc           (ref_wb_pc),
        .ref_wb_rf_wnum      (ref_wb_rf_wnum),
        .ref_wb_rf_wdata     (ref_wb_rf_wdata),
        .ref_wb_inst         (ref_wb_inst)
    );
endmodule

module trace_scoreboard(
    input  wire        clk,
    input  wire        resetn,
    input  wire        open_trace,
    input  wire        num_monitor,
    input  wire [31:0] num_reg,
    input  wire        uart_display,
    input  wire [7 :0] uart_data,
    input  wire        commit_valid,
    input  wire [31:0] commit_pc,
    input  wire [31:0] debug_wb_pc,
    input  wire [3 :0] debug_wb_rf_we,
    input  wire [4 :0] debug_wb_rf_wnum,
    input  wire [31:0] debug_wb_rf_wdata,
    input  wire [31:0] debug_commit_inst,
    output reg         trace_cmp_flag,
    output reg  [31:0] ref_wb_pc,
    output reg  [4 :0] ref_wb_rf_wnum,
    output reg  [31:0] ref_wb_rf_wdata,
    output reg  [31:0] ref_wb_inst
);
    localparam integer MAX_SIM_CYCLES = 1000000;

    function [31:0] mask_wdata;
        input [31:0] data;
        input [3:0] byte_we;
        begin
            mask_wdata = {
                data[31:24] & {8{byte_we[3]}},
                data[23:16] & {8{byte_we[2]}},
                data[15: 8] & {8{byte_we[1]}},
                data[7 : 0] & {8{byte_we[0]}}
            };
        end
    endfunction

    integer trace_ref;
    integer trace_scan_result;
    reg [1023:0] trace_file_path;
    reg trace_error;
    reg trace_eof;
    reg debug_end;
    reg [31:0] trace_index;
    reg [31:0] trace_skipped;
    reg [31:0] sim_cycle_count;

    reg [7:0] err_count;
    reg [31:0] num_reg_r;

    wire trace_fire = (|debug_wb_rf_we) &&
                      (debug_wb_rf_wnum != 5'd0) &&
                      !debug_end && open_trace;
    wire test_end = (commit_valid && commit_pc == `END_PC) ||
                    (uart_display && uart_data == 8'hff);

    initial begin
        trace_file_path = `TRACE_REF_FILE;
        if ($value$plusargs("TRACE_FILE=%s", trace_file_path))
            $display("Using trace file override: %0s", trace_file_path);
        trace_ref = $fopen(trace_file_path, "r");
        if (trace_ref == 0) begin
            $display("TRACE ERROR: cannot open trace file: %0s",
                     trace_file_path);
            #1;
            $finish;
        end
    end

    task finish_trace_failure;
        begin
            trace_error = 1'b1;
            debug_end = 1'b1;
            $display("==============================================================");
            $display("TRACE FAIL at valid writeback %0d", trace_index);
            $display("==============================================================");
            #40;
            if (trace_ref != 0)
                $fclose(trace_ref);
            $finish;
        end
    endtask

    always @(posedge clk) begin
        num_reg_r <= num_reg;
        if (!resetn) begin
            err_count <= 8'd0;
        end else if (num_reg_r != num_reg && num_monitor) begin
            if (num_reg[7:0] != num_reg_r[7:0] + 1'b1 ||
                num_reg[31:24] != num_reg_r[31:24] + 1'b1) begin
                $display("Functional test point mismatch at %t", $time);
                err_count <= err_count + 1'b1;
            end else begin
                $display("----[%t] Functional Test Point %0d PASS",
                         $time, num_reg[31:24]);
            end
        end
    end

    always @(posedge clk) begin
        if (uart_display && uart_data != 8'hff)
            $write("%c", uart_data);
    end

    always @(posedge clk) begin
        #1;
        if (!resetn) begin
            trace_cmp_flag = 1'b0;
            ref_wb_pc = 32'b0;
            ref_wb_rf_wnum = 5'b0;
            ref_wb_rf_wdata = 32'b0;
            ref_wb_inst = 32'b0;
            trace_error = 1'b0;
            trace_eof = 1'b0;
            debug_end = 1'b0;
            trace_index = 32'b0;
            trace_skipped = 32'b0;
            sim_cycle_count = 32'b0;
        end else if (!debug_end) begin
            sim_cycle_count = sim_cycle_count + 1'b1;
            if (sim_cycle_count >= MAX_SIM_CYCLES) begin
                $display("TRACE ERROR: timeout after %0d CPU cycles",
                         sim_cycle_count);
                finish_trace_failure;
            end

            if (trace_fire) begin
                trace_index = trace_index + 1'b1;
                trace_cmp_flag = 1'b0;
                while (!trace_cmp_flag && !trace_eof) begin
                    trace_scan_result = $fscanf(
                        trace_ref, "%h %h %h %h",
                        trace_cmp_flag, ref_wb_pc,
                        ref_wb_rf_wnum, ref_wb_rf_wdata
                    );
                    if (trace_scan_result == 4) begin
                        if (!trace_cmp_flag)
                            trace_skipped = trace_skipped + 1'b1;
                    end else if ($feof(trace_ref)) begin
                        trace_eof = 1'b1;
                    end else begin
                        $display("TRACE ERROR: malformed reference record");
                        finish_trace_failure;
                    end
                end

                if (trace_eof && !trace_cmp_flag) begin
                    $display("TRACE ERROR: CPU produced an extra writeback");
                    finish_trace_failure;
                end

                // The current repository intentionally keeps only the ROM
                // image, not the generated EXP23 objdump listing. The
                // simulation RAM is initialized from that same image, so its
                // word at the reference PC is the authoritative instruction
                // for the compact waveform and commit-instruction check.
                ref_wb_inst =
                    tb_top.soc_lite.sim_unified_ram.ram[ref_wb_pc[19:2]];

                if ((debug_wb_pc !== ref_wb_pc) ||
                    (debug_wb_rf_wnum !== ref_wb_rf_wnum) ||
                    (mask_wdata(debug_wb_rf_wdata, debug_wb_rf_we) !==
                     mask_wdata(ref_wb_rf_wdata, debug_wb_rf_we)) ||
                    (debug_commit_inst !== ref_wb_inst)) begin
                    $display("--------------------------------------------------------------");
                    $display("TRACE MISMATCH at valid writeback %0d (%t)",
                             trace_index, $time);
                    $display("  reference: pc=%08h inst=%08h r%02h=%08h",
                             ref_wb_pc, ref_wb_inst, ref_wb_rf_wnum,
                             mask_wdata(ref_wb_rf_wdata, debug_wb_rf_we));
                    $display("  mycpu:     pc=%08h inst=%08h r%02h=%08h",
                             debug_wb_pc, debug_commit_inst,
                             debug_wb_rf_wnum,
                             mask_wdata(debug_wb_rf_wdata,
                                        debug_wb_rf_we));
                    $display("--------------------------------------------------------------");
                    finish_trace_failure;
                end
            end

            if (test_end && !debug_end) begin
                debug_end = 1'b1;
                trace_cmp_flag = 1'b0;
                while (!trace_cmp_flag && !trace_eof) begin
                    trace_scan_result = $fscanf(
                        trace_ref, "%h %h %h %h",
                        trace_cmp_flag, ref_wb_pc,
                        ref_wb_rf_wnum, ref_wb_rf_wdata
                    );
                    if (trace_scan_result == 4) begin
                        if (!trace_cmp_flag)
                            trace_skipped = trace_skipped + 1'b1;
                    end else if ($feof(trace_ref)) begin
                        trace_eof = 1'b1;
                    end else begin
                        $display("TRACE ERROR: malformed trailing record");
                        finish_trace_failure;
                    end
                end

                if (trace_cmp_flag) begin
                    $display("TRACE ERROR: CPU ended before reference record");
                    finish_trace_failure;
                end

                $display("==============================================================");
                $display("Test end: valid writebacks=%0d skipped=%0d cycles=%0d",
                         trace_index, trace_skipped, sim_cycle_count);
                if (trace_error || err_count != 0)
                    $display("----FAIL: CPU/reference comparison failed");
                else
                    $display("----PASS: CPU writeback and instruction trace match reference");
                $display("==============================================================");
                #40;
                $fclose(trace_ref);
                $finish;
            end
        end
    end

    initial begin
        $timeformat(-9, 0, " ns", 10);
        while (!resetn) #5;
        $display("==============================================================");
        $display("Minimal CPU/reference trace comparison begins");
        $display("==============================================================");
    end
endmodule
