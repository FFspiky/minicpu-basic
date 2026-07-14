`timescale 1ns / 1ps
`include "la32_defs.vh"

module la32_pipeline_core(
    input wire clk, input wire resetn, input wire cpu_en, input wire [7:0] hw_int,
    output wire inst_sram_en, output wire [3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr, output wire [31:0] inst_sram_wdata,
    input wire [31:0] inst_sram_rdata,
    output wire data_sram_en, output wire [3:0] data_sram_we,
    output wire [31:0] data_sram_addr, output wire [31:0] data_sram_wdata,
    input wire [31:0] data_sram_rdata,
    output reg [31:0] debug_wb_pc, output reg [3:0] debug_wb_rf_we,
    output reg [4:0] debug_wb_rf_wnum, output reg [31:0] debug_wb_rf_wdata,
    output reg debug_last_wb_valid, output reg [31:0] debug_last_wb_pc,
    output reg [4:0] debug_last_wb_wnum, output reg [31:0] debug_last_wb_wdata,
    output wire debug_commit_valid, output wire [31:0] debug_commit_pc,
    output wire [31:0] debug_commit_inst, output wire [31:0] debug_fetch_pc,
    output wire [3:0] debug_pipe_valid, output wire [2:0] debug_pipe_hazard
);
    assign inst_sram_we = 4'b0;
    assign inst_sram_wdata = 32'b0;

    /* PC and fetch */
    wire [31:0] pc, pc_plus4, next_pc, redirect_target;
    wire [1:0] redirect_sel;
    wire redirect_valid, pc_en, fetch_issue_fire;
    wire exception_enter, ertn_taken, branch_redirect_pulse;
    wire [31:0] csr_eentry, csr_era, branch_target;
    la32_pc u_pc(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en),
        .fetch_issue_fire(fetch_issue_fire), .exception_enter(exception_enter),
        .eentry(csr_eentry), .ertn_taken(ertn_taken), .era(csr_era),
        .branch_redirect_pulse(branch_redirect_pulse), .branch_target(branch_target),
        .redirect_sel(redirect_sel), .redirect_valid(redirect_valid),
        .redirect_target(redirect_target), .next_pc(next_pc), .pc(pc),
        .pc_plus4(pc_plus4), .pc_en(pc_en)
    );

    wire fetch_hold, fetch_flush, inst_req_pending;
    wire [31:0] fetch_resume_pc;
    wire if_valid, if_exc_valid;
    wire [31:0] if_pc, if_pc_plus4, if_inst, if_badv;
    wire [5:0] if_ecode; wire [8:0] if_esubcode;
    la32_fetch_unit u_fetch(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .pc(pc),
        .pc_plus4(pc_plus4), .fetch_hold(fetch_hold), .fetch_flush(fetch_flush),
        .inst_rdata(inst_sram_rdata), .inst_sram_en(inst_sram_en),
        .inst_sram_addr(inst_sram_addr), .fetch_issue_fire(fetch_issue_fire),
        .inst_req_pending_o(inst_req_pending), .fetch_resume_pc(fetch_resume_pc),
        .if_valid(if_valid), .if_pc(if_pc), .if_pc_plus4(if_pc_plus4),
        .if_inst(if_inst), .if_exc_valid(if_exc_valid), .if_ecode(if_ecode),
        .if_esubcode(if_esubcode), .if_badv(if_badv)
    );

    /* Pipeline-control wires are declared early because every stage uses them. */
    wire if_id_hold, if_id_flush, if_id_bubble;
    wire id_ex_hold, id_ex_flush, id_ex_bubble;
    wire ex_mem_hold, ex_mem_flush, ex_mem_bubble;
    wire mem_wb_hold, mem_wb_flush, mem_wb_bubble;
    wire global_flush, kill_write, pipe_empty, data_hazard;

    /* IF/ID */
    wire ds_valid, ds_exc_valid;
    wire [31:0] ds_pc, ds_pc_plus4, ds_inst, ds_badv;
    wire [5:0] ds_ecode; wire [8:0] ds_esubcode;
    la32_if_id_reg u_if_id(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .flush(if_id_flush),
        .hold(if_id_hold), .bubble(if_id_bubble),
        .in_valid(if_valid && !fetch_hold), .in_pc(if_pc),
        .in_pc_plus4(if_pc_plus4), .in_inst(if_inst),
        .in_exc_valid(if_exc_valid), .in_ecode(if_ecode),
        .in_esubcode(if_esubcode), .in_badv(if_badv),
        .out_valid(ds_valid), .out_pc(ds_pc), .out_pc_plus4(ds_pc_plus4),
        .out_inst(ds_inst), .out_exc_valid(ds_exc_valid), .out_ecode(ds_ecode),
        .out_esubcode(ds_esubcode), .out_badv(ds_badv)
    );

    /* Decode */
    wire [4:0] ds_src1, ds_src2, ds_dest, ds_alu_op;
    wire ds_src1_used, ds_src2_used, ds_src2_sel;
    wire [25:0] ds_imm; wire [2:0] ds_EXTOP, ds_wb_sel;
    wire [1:0] ds_src1_sel, ds_csr_op, ds_counter_sel;
    wire [3:0] ds_br_op, ds_mem_op; wire [13:0] ds_csr_num;
    wire ds_rf_we, ds_is_load, ds_is_csr, ds_is_counter, ds_is_muldiv;
    wire ds_ertn, ds_inst_valid, ds_dec_exc_valid;
    wire [5:0] ds_dec_ecode; wire [8:0] ds_dec_esubcode;
    wire [31:0] ds_dec_badv, ds_ext_imm;
    la32_decoder u_decoder(
        .inst(ds_inst), .valid(ds_valid), .if_exc_valid(ds_exc_valid),
        .if_ecode(ds_ecode), .if_esubcode(ds_esubcode), .if_badv(ds_badv),
        .src1(ds_src1), .src2(ds_src2), .src1_used(ds_src1_used),
        .src2_used(ds_src2_used), .dest(ds_dest), .imm(ds_imm),
        .EXTOP(ds_EXTOP), .alu_op(ds_alu_op), .src1_sel(ds_src1_sel),
        .src2_sel(ds_src2_sel), .br_op(ds_br_op), .mem_op(ds_mem_op),
        .wb_sel(ds_wb_sel), .csr_op(ds_csr_op), .counter_sel(ds_counter_sel),
        .csr_num(ds_csr_num), .rf_we(ds_rf_we), .is_load(ds_is_load),
        .is_csr(ds_is_csr), .is_counter(ds_is_counter),
        .is_muldiv(ds_is_muldiv), .ertn(ds_ertn), .inst_valid(ds_inst_valid),
        .id_exc_valid(ds_dec_exc_valid), .id_ecode(ds_dec_ecode),
        .id_esubcode(ds_dec_esubcode), .id_badv(ds_dec_badv)
    );
    la32_imm_gen u_imm(
        .imm(ds_imm), .EXTOP(ds_EXTOP), .ext_imm(ds_ext_imm)
    );

    wire rf_we_final, csr_we_final;
    wire [31:0] ws_wb_data; wire [4:0] ws_dest;
    wire [31:0] ds_src1_data, ds_src2_data;
    regfile u_regfile(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .wen(rf_we_final),
        .waddr(ws_dest), .wdata(ws_wb_data), .raddr1(ds_src1),
        .rdata1(ds_src1_data), .raddr2(ds_src2), .rdata2(ds_src2_data)
    );

    /* ID/EX */
    wire es_valid, es_src1_used, es_src2_used, es_src2_sel;
    wire [31:0] es_pc, es_pc_plus4, es_inst, es_src1_data, es_src2_data;
    wire [31:0] es_ext_imm, es_badv;
    wire [4:0] es_src1, es_src2, es_dest, es_alu_op;
    wire [1:0] es_src1_sel, es_csr_op, es_counter_sel;
    wire [3:0] es_br_op, es_mem_op; wire [2:0] es_wb_sel;
    wire [13:0] es_csr_num;
    wire es_rf_we, es_is_load, es_is_csr, es_is_counter, es_is_muldiv;
    wire es_ertn, es_inst_valid, es_exc_valid, es_branch_redirect_sent;
    wire [5:0] es_ecode; wire [8:0] es_esubcode;
    wire [31:0] es_src1_fwd, es_src2_fwd, es_store_fwd, es_ex_result;
    la32_id_ex_reg u_id_ex(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .flush(id_ex_flush),
        .hold(id_ex_hold), .bubble(id_ex_bubble),
        .set_branch_redirect_sent(branch_redirect_pulse),
        .hold_src1_data(es_src1_fwd), .hold_src2_data(es_src2_fwd),
        .in_valid(ds_valid), .in_pc(ds_pc), .in_pc_plus4(ds_pc_plus4),
        .in_inst(ds_inst), .in_src1_data(ds_src1_data),
        .in_src2_data(ds_src2_data), .in_src1(ds_src1), .in_src2(ds_src2),
        .in_src1_used(ds_src1_used), .in_src2_used(ds_src2_used),
        .in_dest(ds_dest), .in_ext_imm(ds_ext_imm), .in_alu_op(ds_alu_op),
        .in_src1_sel(ds_src1_sel), .in_src2_sel(ds_src2_sel),
        .in_br_op(ds_br_op), .in_mem_op(ds_mem_op), .in_wb_sel(ds_wb_sel),
        .in_csr_op(ds_csr_op), .in_counter_sel(ds_counter_sel),
        .in_csr_num(ds_csr_num), .in_rf_we(ds_rf_we),
        .in_is_load(ds_is_load), .in_is_csr(ds_is_csr),
        .in_is_counter(ds_is_counter), .in_is_muldiv(ds_is_muldiv),
        .in_ertn(ds_ertn), .in_inst_valid(ds_inst_valid),
        .in_exc_valid(ds_dec_exc_valid), .in_ecode(ds_dec_ecode),
        .in_esubcode(ds_dec_esubcode), .in_badv(ds_dec_badv),
        .out_valid(es_valid), .out_pc(es_pc), .out_pc_plus4(es_pc_plus4),
        .out_inst(es_inst), .out_src1_data(es_src1_data),
        .out_src2_data(es_src2_data), .out_src1(es_src1), .out_src2(es_src2),
        .out_src1_used(es_src1_used), .out_src2_used(es_src2_used),
        .out_dest(es_dest), .out_ext_imm(es_ext_imm), .out_alu_op(es_alu_op),
        .out_src1_sel(es_src1_sel), .out_src2_sel(es_src2_sel),
        .out_br_op(es_br_op), .out_mem_op(es_mem_op), .out_wb_sel(es_wb_sel),
        .out_csr_op(es_csr_op), .out_counter_sel(es_counter_sel),
        .out_csr_num(es_csr_num), .out_rf_we(es_rf_we),
        .out_is_load(es_is_load), .out_is_csr(es_is_csr),
        .out_is_counter(es_is_counter), .out_is_muldiv(es_is_muldiv),
        .out_ertn(es_ertn), .out_inst_valid(es_inst_valid),
        .out_exc_valid(es_exc_valid), .out_ecode(es_ecode),
        .out_esubcode(es_esubcode), .out_badv(es_badv),
        .branch_redirect_sent(es_branch_redirect_sent)
    );

    /* EX, forwarding and branch */
    wire [1:0] forward_src1_sel, forward_src2_sel, forward_store_sel;
    wire [31:0] ms_forward_data;
    wire div_stall;
    wire ex_advance = cpu_en && !ex_mem_hold && !ex_mem_flush && !ex_mem_bubble;
    la32_exu u_exu(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .valid(es_valid),
        .exception(es_exc_valid), .is_muldiv(es_is_muldiv),
        .ex_advance(ex_advance), .kill(global_flush), .pc(es_pc),
        .raw_src1(es_src1_data), .raw_src2(es_src2_data),
        .ext_imm(es_ext_imm), .alu_op(es_alu_op), .src1_sel(es_src1_sel),
        .src2_sel(es_src2_sel), .forward_src1_sel(forward_src1_sel),
        .forward_src2_sel(forward_src2_sel),
        .forward_store_sel(forward_store_sel),
        .mem_forward_data(ms_forward_data), .wb_forward_data(ws_wb_data),
        .src1_forwarded(es_src1_fwd), .src2_forwarded(es_src2_fwd),
        .store_data_forwarded(es_store_fwd), .ex_result(es_ex_result),
        .div_stall(div_stall)
    );
    wire branch_taken;
    la32_branch u_branch(
        .valid(es_valid), .exception(es_exc_valid), .br_op(es_br_op),
        .pc(es_pc), .src1_value(es_src1_fwd), .src2_value(es_src2_fwd),
        .ext_imm(es_ext_imm), .taken(branch_taken), .target(branch_target)
    );
    assign branch_redirect_pulse = branch_taken && !es_branch_redirect_sent;

    wire ex_csr_we = es_csr_op == `CSR_WRITE || es_csr_op == `CSR_XCHG;
    wire [31:0] ex_csr_wmask = es_csr_op == `CSR_WRITE ? 32'hffff_ffff :
                                   es_csr_op == `CSR_XCHG ? es_src1_fwd : 32'b0;
    wire [31:0] ex_csr_wdata = es_src2_fwd;

    /* EX/MEM */
    wire ms_valid, ms_csr_we, ms_rf_we, ms_is_load, ms_is_csr, ms_is_counter;
    wire ms_ertn, ms_exc_valid; wire [31:0] ms_pc, ms_pc_plus4, ms_inst;
    wire [31:0] ms_ex_result, ms_addr, ms_store_data, ms_csr_wmask, ms_csr_wdata;
    wire [31:0] ms_badv; wire [4:0] ms_dest; wire [3:0] ms_mem_op;
    wire [2:0] ms_wb_sel; wire [1:0] ms_counter_sel; wire [13:0] ms_csr_num;
    wire [5:0] ms_ecode; wire [8:0] ms_esubcode;
    la32_ex_mem_reg u_ex_mem(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .flush(ex_mem_flush),
        .hold(ex_mem_hold), .bubble(ex_mem_bubble), .in_valid(es_valid),
        .in_pc(es_pc), .in_pc_plus4(es_pc_plus4), .in_inst(es_inst),
        .in_ex_result(es_ex_result), .in_addr(es_ex_result),
        .in_store_data(es_store_fwd), .in_dest(es_dest), .in_mem_op(es_mem_op),
        .in_wb_sel(es_wb_sel), .in_counter_sel(es_counter_sel),
        .in_csr_num(es_csr_num), .in_csr_wmask(ex_csr_wmask),
        .in_csr_wdata(ex_csr_wdata), .in_csr_we(ex_csr_we),
        .in_rf_we(es_rf_we), .in_is_load(es_is_load), .in_is_csr(es_is_csr),
        .in_is_counter(es_is_counter), .in_ertn(es_ertn),
        .in_exc_valid(es_exc_valid), .in_ecode(es_ecode),
        .in_esubcode(es_esubcode), .in_badv(es_badv),
        .out_valid(ms_valid), .out_pc(ms_pc), .out_pc_plus4(ms_pc_plus4),
        .out_inst(ms_inst), .out_ex_result(ms_ex_result), .out_addr(ms_addr),
        .out_store_data(ms_store_data), .out_dest(ms_dest), .out_mem_op(ms_mem_op),
        .out_wb_sel(ms_wb_sel), .out_counter_sel(ms_counter_sel),
        .out_csr_num(ms_csr_num), .out_csr_wmask(ms_csr_wmask),
        .out_csr_wdata(ms_csr_wdata), .out_csr_we(ms_csr_we),
        .out_rf_we(ms_rf_we), .out_is_load(ms_is_load), .out_is_csr(ms_is_csr),
        .out_is_counter(ms_is_counter), .out_ertn(ms_ertn),
        .out_exc_valid(ms_exc_valid), .out_ecode(ms_ecode),
        .out_esubcode(ms_esubcode), .out_badv(ms_badv)
    );
    assign ms_forward_data = ms_wb_sel == `WB_PC4 ? ms_pc_plus4 : ms_ex_result;

    /* LSU */
    wire mem_wait, mem_complete, load_result_valid, ms_ale;
    wire [31:0] lsu_load_result, ms_ale_badv;
    wire load_req_fire, store_req_fire, store_complete;
    la32_lsu u_lsu(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en),
        .global_flush(global_flush), .stage_advance(cpu_en && !ex_mem_hold),
        .mem_valid(ms_valid), .mem_exc_valid(ms_exc_valid), .mem_op(ms_mem_op),
        .addr(ms_addr), .store_data(ms_store_data),
        .data_sram_rdata(data_sram_rdata), .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we), .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata), .mem_wait(mem_wait),
        .mem_complete(mem_complete), .load_result_valid(load_result_valid),
        .load_result(lsu_load_result), .ale(ms_ale), .ale_badv(ms_ale_badv),
        .load_req_fire(load_req_fire), .store_req_fire(store_req_fire),
        .store_complete(store_complete)
    );
    wire ms_final_exc = ms_exc_valid || ms_ale;
    wire [5:0] ms_final_ecode = ms_ale ? `ECODE_ALE : ms_ecode;
    wire [8:0] ms_final_esubcode = ms_ale ? 9'b0 : ms_esubcode;
    wire [31:0] ms_final_badv = ms_ale ? ms_ale_badv : ms_badv;
    wire mem_wb_in_valid = ms_valid && mem_complete;

    /* MEM/WB */
    wire ws_valid, ws_rf_we, ws_csr_we, ws_ertn, ws_exc_valid;
    wire [31:0] ws_pc, ws_pc_plus4, ws_inst, ws_ex_result, ws_load_result;
    wire [31:0] ws_csr_wmask, ws_csr_wdata, ws_badv;
    wire [2:0] ws_wb_sel; wire [1:0] ws_counter_sel;
    wire [13:0] ws_csr_num; wire [5:0] ws_ecode; wire [8:0] ws_esubcode;
    la32_mem_wb_reg u_mem_wb(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .flush(mem_wb_flush),
        .hold(mem_wb_hold), .bubble(mem_wb_bubble), .in_valid(mem_wb_in_valid),
        .in_pc(ms_pc), .in_pc_plus4(ms_pc_plus4), .in_inst(ms_inst),
        .in_ex_result(ms_ex_result), .in_load_result(lsu_load_result),
        .in_dest(ms_dest), .in_wb_sel(ms_wb_sel),
        .in_counter_sel(ms_counter_sel), .in_csr_num(ms_csr_num),
        .in_csr_wmask(ms_csr_wmask), .in_csr_wdata(ms_csr_wdata),
        .in_csr_we(ms_csr_we), .in_rf_we(ms_rf_we), .in_ertn(ms_ertn),
        .in_exc_valid(ms_final_exc), .in_ecode(ms_final_ecode),
        .in_esubcode(ms_final_esubcode), .in_badv(ms_final_badv),
        .out_valid(ws_valid), .out_pc(ws_pc), .out_pc_plus4(ws_pc_plus4),
        .out_inst(ws_inst), .out_ex_result(ws_ex_result),
        .out_load_result(ws_load_result), .out_dest(ws_dest),
        .out_wb_sel(ws_wb_sel), .out_counter_sel(ws_counter_sel),
        .out_csr_num(ws_csr_num), .out_csr_wmask(ws_csr_wmask),
        .out_csr_wdata(ws_csr_wdata), .out_csr_we(ws_csr_we),
        .out_rf_we(ws_rf_we), .out_ertn(ws_ertn),
        .out_exc_valid(ws_exc_valid), .out_ecode(ws_ecode),
        .out_esubcode(ws_esubcode), .out_badv(ws_badv)
    );

    /* CSR, counter, exception and writeback */
    wire [63:0] stable_counter;
    la32_stable_counter u_counter(.clk(clk), .resetn(resetn), .value(stable_counter));
    wire [31:0] csr_read_data, csr_crmd, csr_prmd, csr_ecfg, csr_estat, csr_badv;
    wire csr_has_int, sync_exception_enter, interrupt_enter;
    wire interrupt_block_fetch; wire [31:0] exception_pc, exception_badv;
    wire [5:0] exception_ecode; wire [8:0] exception_esubcode;
    la32_exception_control u_exception(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .mem_wb_valid(ws_valid),
        .mem_wb_exc_valid(ws_exc_valid), .mem_wb_ertn(ws_ertn),
        .mem_wb_pc(ws_pc), .mem_wb_ecode(ws_ecode),
        .mem_wb_esubcode(ws_esubcode), .mem_wb_badv(ws_badv),
        .pipe_empty(pipe_empty), .has_interrupt(csr_has_int),
        .fetch_resume_pc(fetch_resume_pc),
        .branch_redirect_pulse(branch_redirect_pulse),
        .branch_target(branch_target),
        .sync_exception_enter(sync_exception_enter),
        .interrupt_enter(interrupt_enter), .exception_enter(exception_enter),
        .ertn_taken(ertn_taken), .interrupt_block_fetch(interrupt_block_fetch),
        .exception_pc(exception_pc), .exception_ecode(exception_ecode),
        .exception_esubcode(exception_esubcode), .exception_badv(exception_badv)
    );
    la32_csr u_csr(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .hw_int(hw_int),
        .read_addr(ws_csr_num), .read_data(csr_read_data),
        .csr_we(csr_we_final), .csr_waddr(ws_csr_num),
        .csr_wmask(ws_csr_wmask), .csr_wdata(ws_csr_wdata),
        .exc_valid(exception_enter), .exc_pc(exception_pc),
        .exc_badv(exception_badv), .exc_ecode(exception_ecode),
        .exc_esubcode(exception_esubcode), .ertn_flush(ertn_taken),
        .has_int(csr_has_int), .ertn_pc(), .exc_entry(), .csr_crmd(csr_crmd),
        .csr_prmd(csr_prmd), .csr_ecfg(csr_ecfg), .csr_estat(csr_estat),
        .csr_era(csr_era), .csr_badv(csr_badv), .csr_eentry(csr_eentry)
    );
    la32_wb_select u_wb(
        .valid(ws_valid), .exception(ws_exc_valid), .ertn(ws_ertn),
        .rf_we_in(ws_rf_we), .dest(ws_dest), .wb_sel(ws_wb_sel),
        .ex_result(ws_ex_result), .load_result(ws_load_result),
        .pc_plus4(ws_pc_plus4), .csr_old_value(csr_read_data),
        .stable_counter(stable_counter), .csr_tid(csr_read_data),
        .csr_we_in(ws_csr_we), .wb_data(ws_wb_data),
        .rf_we_final(rf_we_final), .csr_we_final(csr_we_final),
        .wb_forward_valid()
    );

    /* Hazard, forwarding and per-stage age control. */
    wire ex_csr_we_for_hazard = ex_csr_we && !es_exc_valid;
    wire ds_reads_tid = ds_is_counter && ds_counter_sel == 2'd2;
    la32_pipeline_control u_control(
        .if_id_valid(ds_valid), .id_ex_valid(es_valid), .ex_mem_valid(ms_valid),
        .mem_wb_valid(ws_valid), .id_src1(ds_src1), .id_src2(ds_src2),
        .id_src1_used(ds_src1_used && !ds_dec_exc_valid),
        .id_src2_used(ds_src2_used && !ds_dec_exc_valid),
        .id_is_csr(ds_is_csr), .id_reads_tid(ds_reads_tid),
        .id_csr_num(ds_csr_num), .ex_src1(es_src1), .ex_src2(es_src2),
        .ex_src1_used(es_src1_used), .ex_src2_used(es_src2_used),
        .ex_dest(es_dest), .ex_rf_we(es_rf_we && !es_exc_valid),
        .ex_is_load(es_is_load), .ex_is_csr(es_is_csr),
        .ex_is_counter(es_is_counter), .ex_csr_we(ex_csr_we_for_hazard),
        .ex_csr_num(es_csr_num), .mem_dest(ms_dest),
        .mem_rf_we(ms_rf_we && !ms_final_exc), .mem_is_load(ms_is_load),
        .mem_is_csr(ms_is_csr), .mem_is_counter(ms_is_counter),
        .mem_csr_we(ms_csr_we && !ms_final_exc), .mem_csr_num(ms_csr_num),
        .wb_dest(ws_dest), .wb_rf_we(rf_we_final), .wb_csr_we(csr_we_final),
        .wb_csr_num(ws_csr_num), .mem_wait(mem_wait), .div_stall(div_stall),
        .exception_enter(exception_enter), .ertn_taken(ertn_taken),
        .branch_redirect_pulse(branch_redirect_pulse),
        .interrupt_block_fetch(interrupt_block_fetch),
        .forward_src1_sel(forward_src1_sel),
        .forward_src2_sel(forward_src2_sel),
        .forward_store_sel(forward_store_sel), .pc_hold(),
        .fetch_hold(fetch_hold), .fetch_flush(fetch_flush),
        .if_id_hold(if_id_hold), .if_id_flush(if_id_flush),
        .if_id_bubble(if_id_bubble), .id_ex_hold(id_ex_hold),
        .id_ex_flush(id_ex_flush), .id_ex_bubble(id_ex_bubble),
        .ex_mem_hold(ex_mem_hold), .ex_mem_flush(ex_mem_flush),
        .ex_mem_bubble(ex_mem_bubble), .mem_wb_hold(mem_wb_hold),
        .mem_wb_flush(mem_wb_flush), .mem_wb_bubble(mem_wb_bubble),
        .global_flush(global_flush), .kill_write(kill_write),
        .pipe_empty(pipe_empty), .data_hazard(data_hazard)
    );

    assign debug_fetch_pc = pc;
    // Present the instruction currently at the precise MEM/WB commit point.
    // The board run controller samples this bus on the same edge that performs
    // the architectural writeback, so END_PC cannot be detected one cycle late.
    assign debug_commit_valid = ws_valid;
    assign debug_commit_pc = ws_pc;
    assign debug_commit_inst = ws_inst;
    assign debug_pipe_valid = {ws_valid | ms_valid, es_valid, ds_valid,
                               if_valid | inst_req_pending};
    assign debug_pipe_hazard = {data_hazard, div_stall, mem_wait};

    always @(posedge clk) begin
        if (!resetn) begin
            debug_wb_pc <= 0; debug_wb_rf_we <= 0; debug_wb_rf_wnum <= 0;
            debug_wb_rf_wdata <= 0; debug_last_wb_valid <= 0;
            debug_last_wb_pc <= 0; debug_last_wb_wnum <= 0;
            debug_last_wb_wdata <= 0;
        end else if (cpu_en) begin
            debug_wb_rf_we <= 4'b0;
            if (ws_valid) begin
                debug_wb_pc <= ws_pc;
            end
            if (rf_we_final) begin
                debug_wb_rf_we <= 4'hf; debug_wb_rf_wnum <= ws_dest;
                debug_wb_rf_wdata <= ws_wb_data; debug_last_wb_valid <= 1'b1;
                debug_last_wb_pc <= ws_pc; debug_last_wb_wnum <= ws_dest;
                debug_last_wb_wdata <= ws_wb_data;
            end
        end
    end
endmodule
