`timescale 1ns / 1ps

module la32_pipeline_core(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    input  wire [ 7:0] hw_int,

    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    output reg  [31:0] debug_wb_pc,
    output reg  [ 3:0] debug_wb_rf_we,
    output reg  [ 4:0] debug_wb_rf_wnum,
    output reg  [31:0] debug_wb_rf_wdata,
    output reg         debug_last_wb_valid,
    output reg  [31:0] debug_last_wb_pc,
    output reg  [ 4:0] debug_last_wb_wnum,
    output reg  [31:0] debug_last_wb_wdata,
    output reg         debug_commit_valid,
    output reg  [31:0] debug_commit_pc,
    output reg  [31:0] debug_commit_inst,
    output wire [31:0] debug_fetch_pc,
    output wire [ 3:0] debug_pipe_valid,
    output wire [ 2:0] debug_pipe_hazard
);

    localparam ECODE_INT  = 6'h00;
    localparam ECODE_ALE  = 6'h09;
    localparam ECODE_SYS  = 6'h0b;
    localparam ECODE_BRK  = 6'h0c;
    localparam ECODE_INE  = 6'h0d;

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_SLL  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b0110;
    localparam ALU_AND  = 4'b0111;
    localparam ALU_NOR  = 4'b1000;
    localparam ALU_OR   = 4'b1001;
    localparam ALU_XOR  = 4'b1010;

    wire [31:0] fetch_pc;
    wire        fetch_pending;

    wire        fs_valid;
    wire [31:0] fs_pc;
    wire [31:0] fs_inst;
    wire        fs_exc;
    wire [ 5:0] fs_ecode;
    wire [ 8:0] fs_esubcode;
    wire [31:0] fs_badv;
    wire        fs_tlbr;

    wire        ds_valid;
    wire [31:0] ds_pc;
    wire [31:0] ds_inst;
    wire        ds_exc;
    wire [ 5:0] ds_ecode;
    wire [ 8:0] ds_esubcode;
    wire [31:0] ds_badv;
    wire        ds_tlbr;

    wire        es_valid;
    wire [31:0] es_pc;
    wire [31:0] es_inst;
    wire        es_exc;
    wire [ 5:0] es_ecode;
    wire [ 8:0] es_esubcode;
    wire [31:0] es_badv;
    wire        es_tlbr;
    wire [31:0] es_rj_value;
    wire [31:0] es_rk_value;
    wire [31:0] es_rd_value;
    wire [ 4:0] es_rd;
    wire [ 4:0] es_rj;
    wire [ 4:0] es_rk;
    wire [13:0] es_csr_num;
    wire [ 4:0] es_invtlb_op;
    wire        es_serial;
    wire [ 4:0] es_dest;
    wire        es_dec_is_load;
    wire        es_dec_rf_we;

    wire es_inst_add_w, es_inst_sub_w, es_inst_slt, es_inst_sltu;
    wire es_inst_nor, es_inst_and, es_inst_or, es_inst_xor;
    wire es_inst_sll_w, es_inst_srl_w, es_inst_sra_w;
    wire es_inst_mul_w, es_inst_mulh_w, es_inst_mulh_wu;
    wire es_inst_div_w, es_inst_div_wu, es_inst_mod_w, es_inst_mod_wu;
    wire es_inst_slli_w, es_inst_srli_w, es_inst_srai_w;
    wire es_inst_addi_w, es_inst_slti, es_inst_sltui;
    wire es_inst_andi, es_inst_ori, es_inst_xori;
    wire es_inst_lu12i_w, es_inst_pcaddu12i;
    wire es_inst_ld_b, es_inst_ld_h, es_inst_ld_w;
    wire es_inst_ld_bu, es_inst_ld_hu;
    wire es_inst_st_b, es_inst_st_h, es_inst_st_w;
    wire es_inst_beq, es_inst_bne, es_inst_blt, es_inst_bge;
    wire es_inst_bltu, es_inst_bgeu, es_inst_jirl, es_inst_b, es_inst_bl;
    wire es_inst_csrrd, es_inst_csrwr, es_inst_csrxchg;
    wire es_inst_syscall, es_inst_break, es_inst_ertn;
    wire es_inst_rdcntvl_w, es_inst_rdcntvh_w, es_inst_rdcntid_w;
    wire es_inst_tlbsrch, es_inst_tlbrd, es_inst_tlbwr;
    wire es_inst_tlbfill, es_inst_invtlb, es_inst_cacop, es_inst_valid;

    wire        ms_valid;
    wire [31:0] ms_pc, ms_inst;
    wire        ms_exc;
    wire [ 5:0] ms_ecode;
    wire [ 8:0] ms_esubcode;
    wire [31:0] ms_badv;
    wire        ms_tlbr, ms_ertn, ms_serial, ms_flush_after;
    wire        ms_rf_we;
    wire [ 4:0] ms_rf_waddr;
    wire [31:0] ms_rf_wdata;
    wire        ms_mem_load, ms_mem_store, ms_mem_req_sent;
    wire [31:0] ms_mem_va, ms_mem_pa, ms_store_data;
    wire        ms_op_ld_b, ms_op_ld_h, ms_op_ld_w, ms_op_ld_bu, ms_op_ld_hu;
    wire        ms_op_st_b, ms_op_st_h, ms_op_st_w;
    wire        ms_csr_we;
    wire [13:0] ms_csr_waddr;
    wire [31:0] ms_csr_wmask, ms_csr_wdata;
    wire        ms_tlbidx_we, ms_tlbehi_we, ms_tlbelo0_we, ms_tlbelo1_we;
    wire [31:0] ms_tlbidx_wdata, ms_tlbehi_wdata;
    wire [31:0] ms_tlbelo0_wdata, ms_tlbelo1_wdata;
    wire        ms_asid_we;
    wire [31:0] ms_asid_wdata;
    wire        ms_op_tlbwr, ms_op_tlbfill, ms_op_invtlb;
    wire [ 4:0] ms_invtlb_op;
    wire [31:0] ms_invtlb_asid, ms_invtlb_va;

    wire        ws_valid;
    wire [31:0] ws_pc, ws_inst;
    wire        ws_exc;
    wire [ 5:0] ws_ecode;
    wire [ 8:0] ws_esubcode;
    wire [31:0] ws_badv;
    wire        ws_tlbr, ws_ertn, ws_serial, ws_flush_after;
    wire        ws_rf_we;
    wire [ 4:0] ws_rf_waddr;
    wire [31:0] ws_rf_wdata;
    wire        ws_csr_we;
    wire [13:0] ws_csr_waddr;
    wire [31:0] ws_csr_wmask, ws_csr_wdata;
    wire        ws_tlbidx_we, ws_tlbehi_we, ws_tlbelo0_we, ws_tlbelo1_we;
    wire [31:0] ws_tlbidx_wdata, ws_tlbehi_wdata;
    wire [31:0] ws_tlbelo0_wdata, ws_tlbelo1_wdata;
    wire        ws_asid_we;
    wire [31:0] ws_asid_wdata;
    wire        ws_op_tlbwr, ws_op_tlbfill, ws_op_invtlb;
    wire [ 4:0] ws_invtlb_op;
    wire [31:0] ws_invtlb_asid, ws_invtlb_va;

    wire [4:0] ds_rd;
    wire [4:0] ds_rj;
    wire [4:0] ds_rk;
    wire [11:0] ds_imm12;
    wire [13:0] ds_csr_num;
    wire [4:0] ds_cacop_code;
    wire [4:0] ds_invtlb_op;
    wire ds_inst_add_w;
    wire ds_inst_sub_w;
    wire ds_inst_slt;
    wire ds_inst_sltu;
    wire ds_inst_nor;
    wire ds_inst_and;
    wire ds_inst_or;
    wire ds_inst_xor;
    wire ds_inst_sll_w;
    wire ds_inst_srl_w;
    wire ds_inst_sra_w;
    wire ds_inst_mul_w;
    wire ds_inst_mulh_w;
    wire ds_inst_mulh_wu;
    wire ds_inst_div_w;
    wire ds_inst_div_wu;
    wire ds_inst_mod_w;
    wire ds_inst_mod_wu;
    wire ds_inst_slli_w;
    wire ds_inst_srli_w;
    wire ds_inst_srai_w;
    wire ds_inst_addi_w;
    wire ds_inst_slti;
    wire ds_inst_sltui;
    wire ds_inst_andi;
    wire ds_inst_ori;
    wire ds_inst_xori;
    wire ds_inst_lu12i_w;
    wire ds_inst_pcaddu12i;
    wire ds_inst_ld_b;
    wire ds_inst_ld_h;
    wire ds_inst_ld_w;
    wire ds_inst_ld_bu;
    wire ds_inst_ld_hu;
    wire ds_inst_st_b;
    wire ds_inst_st_h;
    wire ds_inst_st_w;
    wire ds_inst_beq;
    wire ds_inst_bne;
    wire ds_inst_blt;
    wire ds_inst_bge;
    wire ds_inst_bltu;
    wire ds_inst_bgeu;
    wire ds_inst_jirl;
    wire ds_inst_b;
    wire ds_inst_bl;
    wire ds_inst_csrrd;
    wire ds_inst_csrwr;
    wire ds_inst_csrxchg;
    wire ds_inst_syscall;
    wire ds_inst_break;
    wire ds_inst_ertn;
    wire ds_inst_rdcntvl_w;
    wire ds_inst_rdcntvh_w;
    wire ds_inst_rdcntid_w;
    wire ds_inst_tlbsrch;
    wire ds_inst_tlbrd;
    wire ds_inst_tlbwr;
    wire ds_inst_tlbfill;
    wire ds_inst_invtlb;
    wire ds_inst_cacop;
    wire ds_inst_valid;
    wire ds_use_rj;
    wire ds_use_rk;
    wire ds_use_rd;
    wire [4:0] ds_dest;
    wire ds_dec_is_load;
    wire ds_dec_rf_we;
    wire ds_serial;

    la32_decoder u_decoder_ds(
        .inst(ds_inst),
        .valid(ds_valid),
        .exception(ds_exc),
        .rd(ds_rd),
        .rj(ds_rj),
        .rk(ds_rk),
        .imm12(ds_imm12),
        .csr_num(ds_csr_num),
        .cacop_code(ds_cacop_code),
        .invtlb_op(ds_invtlb_op),
        .inst_add_w(ds_inst_add_w),
        .inst_sub_w(ds_inst_sub_w),
        .inst_slt(ds_inst_slt),
        .inst_sltu(ds_inst_sltu),
        .inst_nor(ds_inst_nor),
        .inst_and(ds_inst_and),
        .inst_or(ds_inst_or),
        .inst_xor(ds_inst_xor),
        .inst_sll_w(ds_inst_sll_w),
        .inst_srl_w(ds_inst_srl_w),
        .inst_sra_w(ds_inst_sra_w),
        .inst_mul_w(ds_inst_mul_w),
        .inst_mulh_w(ds_inst_mulh_w),
        .inst_mulh_wu(ds_inst_mulh_wu),
        .inst_div_w(ds_inst_div_w),
        .inst_div_wu(ds_inst_div_wu),
        .inst_mod_w(ds_inst_mod_w),
        .inst_mod_wu(ds_inst_mod_wu),
        .inst_slli_w(ds_inst_slli_w),
        .inst_srli_w(ds_inst_srli_w),
        .inst_srai_w(ds_inst_srai_w),
        .inst_addi_w(ds_inst_addi_w),
        .inst_slti(ds_inst_slti),
        .inst_sltui(ds_inst_sltui),
        .inst_andi(ds_inst_andi),
        .inst_ori(ds_inst_ori),
        .inst_xori(ds_inst_xori),
        .inst_lu12i_w(ds_inst_lu12i_w),
        .inst_pcaddu12i(ds_inst_pcaddu12i),
        .inst_ld_b(ds_inst_ld_b),
        .inst_ld_h(ds_inst_ld_h),
        .inst_ld_w(ds_inst_ld_w),
        .inst_ld_bu(ds_inst_ld_bu),
        .inst_ld_hu(ds_inst_ld_hu),
        .inst_st_b(ds_inst_st_b),
        .inst_st_h(ds_inst_st_h),
        .inst_st_w(ds_inst_st_w),
        .inst_beq(ds_inst_beq),
        .inst_bne(ds_inst_bne),
        .inst_blt(ds_inst_blt),
        .inst_bge(ds_inst_bge),
        .inst_bltu(ds_inst_bltu),
        .inst_bgeu(ds_inst_bgeu),
        .inst_jirl(ds_inst_jirl),
        .inst_b(ds_inst_b),
        .inst_bl(ds_inst_bl),
        .inst_csrrd(ds_inst_csrrd),
        .inst_csrwr(ds_inst_csrwr),
        .inst_csrxchg(ds_inst_csrxchg),
        .inst_syscall(ds_inst_syscall),
        .inst_break(ds_inst_break),
        .inst_ertn(ds_inst_ertn),
        .inst_rdcntvl_w(ds_inst_rdcntvl_w),
        .inst_rdcntvh_w(ds_inst_rdcntvh_w),
        .inst_rdcntid_w(ds_inst_rdcntid_w),
        .inst_tlbsrch(ds_inst_tlbsrch),
        .inst_tlbrd(ds_inst_tlbrd),
        .inst_tlbwr(ds_inst_tlbwr),
        .inst_tlbfill(ds_inst_tlbfill),
        .inst_invtlb(ds_inst_invtlb),
        .inst_cacop(ds_inst_cacop),
        .inst_valid(ds_inst_valid),
        .use_rj(ds_use_rj),
        .use_rk(ds_use_rk),
        .use_rd(ds_use_rd),
        .dest(ds_dest),
        .is_load(ds_dec_is_load),
        .rf_we(ds_dec_rf_we),
        .serial(ds_serial)
    );

    wire [13:0] csr_read_addr = es_inst_rdcntid_w ? 14'h040 : es_csr_num;
    wire [31:0] csr_read_data;
    wire [63:0] stable_counter;
    wire        csr_has_int;
    wire [31:0] csr_crmd;
    wire [31:0] csr_prmd;
    wire [31:0] csr_ecfg;
    wire [31:0] csr_estat;
    wire [31:0] csr_era;
    wire [31:0] csr_badv;
    wire [31:0] csr_eentry;
    wire [31:0] csr_tlbidx;
    wire [31:0] csr_tlbehi;
    wire [31:0] csr_tlbelo0;
    wire [31:0] csr_tlbelo1;
    wire [31:0] csr_asid;
    wire [31:0] csr_tlbrentry;
    wire [31:0] csr_dmw0;
    wire [31:0] csr_dmw1;

    la32_stable_counter u_stable_counter(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .value(stable_counter)
    );

    wire wb_exc_commit;
    wire wb_ertn_commit;
    wire rf_we_final;
    wire wb_csr_commit;
    wire wb_tlbidx_commit;
    wire wb_tlbehi_commit;
    wire wb_tlbelo0_commit;
    wire wb_tlbelo1_commit;
    wire wb_asid_commit;
    wire wb_tlbwr_commit;
    wire wb_tlbfill_commit;
    wire wb_invtlb_commit;

    la32_commit_control u_commit_control(
        .ws_valid(ws_valid),
        .ws_exception(ws_exc),
        .ws_ertn(ws_ertn),
        .ws_rf_we(ws_rf_we),
        .ws_rf_waddr(ws_rf_waddr),
        .ws_csr_we(ws_csr_we),
        .ws_tlbidx_we(ws_tlbidx_we),
        .ws_tlbehi_we(ws_tlbehi_we),
        .ws_tlbelo0_we(ws_tlbelo0_we),
        .ws_tlbelo1_we(ws_tlbelo1_we),
        .ws_asid_we(ws_asid_we),
        .ws_tlbwr(ws_op_tlbwr),
        .ws_tlbfill(ws_op_tlbfill),
        .ws_invtlb(ws_op_invtlb),
        .rf_we(rf_we_final),
        .csr_we(wb_csr_commit),
        .tlbidx_we(wb_tlbidx_commit),
        .tlbehi_we(wb_tlbehi_commit),
        .tlbelo0_we(wb_tlbelo0_commit),
        .tlbelo1_we(wb_tlbelo1_commit),
        .asid_we(wb_asid_commit),
        .tlbwr(wb_tlbwr_commit),
        .tlbfill(wb_tlbfill_commit),
        .invtlb(wb_invtlb_commit)
    );

    la32_csr u_csr(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .hw_int(hw_int),
        .read_addr(csr_read_addr),
        .read_data(csr_read_data),
        .csr_we(wb_csr_commit),
        .csr_waddr(ws_csr_waddr),
        .csr_wmask(ws_csr_wmask),
        .csr_wdata(ws_csr_wdata),
        .exc_valid(wb_exc_commit),
        .exc_pc(ws_pc),
        .exc_badv(ws_badv),
        .exc_ecode(ws_ecode),
        .exc_esubcode(ws_esubcode),
        .exc_tlbr(ws_tlbr),
        .ertn_flush(wb_ertn_commit),
        .tlbidx_we(wb_tlbidx_commit),
        .tlbidx_wdata(ws_tlbidx_wdata),
        .tlbehi_we(wb_tlbehi_commit),
        .tlbehi_wdata(ws_tlbehi_wdata),
        .tlbelo0_we(wb_tlbelo0_commit),
        .tlbelo0_wdata(ws_tlbelo0_wdata),
        .tlbelo1_we(wb_tlbelo1_commit),
        .tlbelo1_wdata(ws_tlbelo1_wdata),
        .asid_we(wb_asid_commit),
        .asid_wdata(ws_asid_wdata),
        .has_int(csr_has_int),
        .stable_counter(stable_counter),
        .ertn_pc(),
        .exc_entry(),
        .csr_crmd(csr_crmd),
        .csr_prmd(csr_prmd),
        .csr_ecfg(csr_ecfg),
        .csr_estat(csr_estat),
        .csr_era(csr_era),
        .csr_badv(csr_badv),
        .csr_eentry(csr_eentry),
        .csr_tlbidx(csr_tlbidx),
        .csr_tlbehi(csr_tlbehi),
        .csr_tlbelo0(csr_tlbelo0),
        .csr_tlbelo1(csr_tlbelo1),
        .csr_asid(csr_asid),
        .csr_tlbrentry(csr_tlbrentry),
        .csr_dmw0(csr_dmw0),
        .csr_dmw1(csr_dmw1)
    );

    wire [31:0] es_si12;
    wire [31:0] es_ui12;
    wire [31:0] es_si16_shift;
    wire [31:0] es_si26_shift;
    wire [31:0] es_si20_shift;

    la32_imm_gen u_imm_gen_es(
        .inst(es_inst),
        .si12(es_si12),
        .ui12(es_ui12),
        .offs16(es_si16_shift),
        .offs26(es_si26_shift),
        .si20(es_si20_shift)
    );
    wire [31:0] es_pc_plus4   = es_pc + 32'd4;
    wire [31:0] es_mem_va     = es_rj_value + es_si12;

    wire es_inst_load  = es_inst_ld_b | es_inst_ld_h | es_inst_ld_w |
                         es_inst_ld_bu | es_inst_ld_hu;
    wire es_inst_store = es_inst_st_b | es_inst_st_h | es_inst_st_w;
    wire es_mem_op     = es_valid & !es_exc & (es_inst_load | es_inst_store | es_inst_cacop);
    wire es_mem_store  = es_valid & !es_exc & es_inst_store;

    wire        tlb_trans_hit;
    wire [3:0]  tlb_trans_index;
    wire [5:0]  tlb_trans_ps;
    wire [31:0] tlb_trans_elo;
    wire        tlb_srch_hit;
    wire [3:0]  tlb_srch_index;
    wire [31:0] tlbrd_tlbidx;
    wire [31:0] tlbrd_tlbehi;
    wire [31:0] tlbrd_tlbelo0;
    wire [31:0] tlbrd_tlbelo1;
    wire [31:0] tlbrd_asid;

    wire [31:0] trans_va       = es_mem_op ? es_mem_va : fetch_pc;
    wire        trans_is_fetch = !es_mem_op;
    wire        trans_is_store = es_mem_store;

    la32_tlb u_tlb(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .csr_tlbidx(csr_tlbidx),
        .csr_tlbehi(csr_tlbehi),
        .csr_tlbelo0(csr_tlbelo0),
        .csr_tlbelo1(csr_tlbelo1),
        .csr_asid(csr_asid),
        .trans_va(trans_va),
        .trans_hit(tlb_trans_hit),
        .trans_index(tlb_trans_index),
        .trans_ps(tlb_trans_ps),
        .trans_elo(tlb_trans_elo),
        .srch_hit(tlb_srch_hit),
        .srch_index(tlb_srch_index),
        .tlbrd_tlbidx(tlbrd_tlbidx),
        .tlbrd_tlbehi(tlbrd_tlbehi),
        .tlbrd_tlbelo0(tlbrd_tlbelo0),
        .tlbrd_tlbelo1(tlbrd_tlbelo1),
        .tlbrd_asid(tlbrd_asid),
        .op_tlbwr(wb_tlbwr_commit),
        .op_tlbfill(wb_tlbfill_commit),
        .op_invtlb(wb_invtlb_commit),
        .invtlb_op(ws_invtlb_op),
        .invtlb_asid(ws_invtlb_asid),
        .invtlb_va(ws_invtlb_va)
    );

    wire [31:0] trans_pa;
    wire        trans_exc;
    wire [5:0]  trans_ecode;
    wire [8:0]  trans_esubcode;
    wire        trans_tlbr;

    la32_translator u_translator(
        .va(trans_va),
        .is_fetch(trans_is_fetch),
        .is_store(trans_is_store),
        .csr_crmd(csr_crmd),
        .csr_dmw0(csr_dmw0),
        .csr_dmw1(csr_dmw1),
        .tlb_hit(tlb_trans_hit),
        .tlb_ps(tlb_trans_ps),
        .tlb_elo(tlb_trans_elo),
        .pa(trans_pa),
        .exc_valid(trans_exc),
        .exc_ecode(trans_ecode),
        .exc_esubcode(trans_esubcode),
        .exc_tlbr(trans_tlbr)
    );

    wire lsu_align_error;
    wire [3:0] lsu_store_we;
    wire [31:0] lsu_store_wdata;
    wire [31:0] lsu_load_result;

    la32_lsu u_lsu(
        .check_addr(es_mem_va),
        .check_ld_h(es_inst_ld_h),
        .check_ld_w(es_inst_ld_w),
        .check_ld_hu(es_inst_ld_hu),
        .check_st_h(es_inst_st_h),
        .check_st_w(es_inst_st_w),
        .addr(ms_mem_va),
        .store_data(ms_store_data),
        .load_data(data_sram_rdata),
        .op_ld_b(ms_op_ld_b),
        .op_ld_h(ms_op_ld_h),
        .op_ld_w(ms_op_ld_w),
        .op_ld_bu(ms_op_ld_bu),
        .op_ld_hu(ms_op_ld_hu),
        .op_st_b(ms_op_st_b),
        .op_st_h(ms_op_st_h),
        .op_st_w(ms_op_st_w),
        .align_error(lsu_align_error),
        .store_we(lsu_store_we),
        .store_wdata(lsu_store_wdata),
        .load_result(lsu_load_result)
    );

    wire es_muldiv_op = es_inst_mul_w | es_inst_mulh_w | es_inst_mulh_wu |
                        es_inst_div_w | es_inst_div_wu | es_inst_mod_w |
                        es_inst_mod_wu;
    wire        muldiv_busy;
    wire        muldiv_done;
    wire [31:0] muldiv_result;
    wire        muldiv_start;
    wire        muldiv_clear;

    wire [31:0] es_alu_src1 = es_inst_lu12i_w ? 32'b0 :
                              es_inst_pcaddu12i ? es_pc : es_rj_value;
    wire [31:0] es_alu_src2 = (es_inst_slli_w | es_inst_srli_w |
                               es_inst_srai_w) ? {27'b0, es_rk} :
                              (es_inst_addi_w | es_inst_slti |
                               es_inst_sltui) ? es_si12 :
                              (es_inst_andi | es_inst_ori |
                               es_inst_xori) ? es_ui12 :
                              (es_inst_lu12i_w | es_inst_pcaddu12i) ?
                               es_si20_shift : es_rk_value;
    wire [3:0] es_alu_op = es_inst_sub_w ? ALU_SUB :
                           (es_inst_slt | es_inst_slti) ? ALU_SLT :
                           (es_inst_sltu | es_inst_sltui) ? ALU_SLTU :
                           (es_inst_sll_w | es_inst_slli_w) ? ALU_SLL :
                           (es_inst_srl_w | es_inst_srli_w) ? ALU_SRL :
                           (es_inst_sra_w | es_inst_srai_w) ? ALU_SRA :
                           (es_inst_and | es_inst_andi) ? ALU_AND :
                           es_inst_nor ? ALU_NOR :
                           (es_inst_or | es_inst_ori) ? ALU_OR :
                           (es_inst_xor | es_inst_xori) ? ALU_XOR : ALU_ADD;
    wire [31:0] es_alu_result;

    reg        ex_rf_we;
    reg [ 4:0] ex_rf_waddr;
    reg [31:0] ex_rf_wdata;
    reg        ex_exc;
    reg [ 5:0] ex_ecode;
    reg [ 8:0] ex_esubcode;
    reg [31:0] ex_badv;
    reg        ex_tlbr;
    reg        ex_ertn;
    reg        ex_flush_after;
    reg        ex_mem_load;
    reg        ex_mem_store;
    reg [31:0] ex_mem_pa;
    reg        ex_csr_we;
    reg [13:0] ex_csr_waddr;
    reg [31:0] ex_csr_wmask;
    reg [31:0] ex_csr_wdata;
    reg        ex_tlbidx_we;
    reg [31:0] ex_tlbidx_wdata;
    reg        ex_tlbehi_we;
    reg [31:0] ex_tlbehi_wdata;
    reg        ex_tlbelo0_we;
    reg [31:0] ex_tlbelo0_wdata;
    reg        ex_tlbelo1_we;
    reg [31:0] ex_tlbelo1_wdata;
    reg        ex_asid_we;
    reg [31:0] ex_asid_wdata;
    reg        ex_op_tlbwr;
    reg        ex_op_tlbfill;
    reg        ex_op_invtlb;
    reg [31:0] ex_result;

    wire es_branch_redirect;
    wire [31:0] es_branch_target;

    always @(*) begin
        ex_rf_we         = 1'b0;
        ex_rf_waddr      = es_dest;
        ex_rf_wdata      = 32'b0;
        ex_exc           = es_exc;
        ex_ecode         = es_ecode;
        ex_esubcode      = es_esubcode;
        ex_badv          = es_badv;
        ex_tlbr          = es_tlbr;
        ex_ertn          = 1'b0;
        ex_flush_after   = 1'b0;
        ex_mem_load      = 1'b0;
        ex_mem_store     = 1'b0;
        ex_mem_pa        = trans_pa;
        ex_csr_we        = 1'b0;
        ex_csr_waddr     = 14'b0;
        ex_csr_wmask     = 32'b0;
        ex_csr_wdata     = 32'b0;
        ex_tlbidx_we     = 1'b0;
        ex_tlbidx_wdata  = 32'b0;
        ex_tlbehi_we     = 1'b0;
        ex_tlbehi_wdata  = 32'b0;
        ex_tlbelo0_we    = 1'b0;
        ex_tlbelo0_wdata = 32'b0;
        ex_tlbelo1_we    = 1'b0;
        ex_tlbelo1_wdata = 32'b0;
        ex_asid_we       = 1'b0;
        ex_asid_wdata    = 32'b0;
        ex_op_tlbwr      = 1'b0;
        ex_op_tlbfill    = 1'b0;
        ex_op_invtlb     = 1'b0;
        ex_result        = 32'b0;

        if (!es_exc) begin
            if (!es_inst_valid) begin
                ex_exc   = 1'b1;
                ex_ecode = ECODE_INE;
            end
            else if (es_inst_syscall) begin
                ex_exc   = 1'b1;
                ex_ecode = ECODE_SYS;
            end
            else if (es_inst_break) begin
                ex_exc   = 1'b1;
                ex_ecode = ECODE_BRK;
            end
            else if (es_inst_ertn) begin
                ex_ertn = 1'b1;
            end
            else if (es_inst_invtlb && es_invtlb_op > 5'h6) begin
                ex_exc   = 1'b1;
                ex_ecode = ECODE_INE;
            end
            else if (es_inst_load | es_inst_store | es_inst_cacop) begin
                if (lsu_align_error && !es_inst_cacop) begin
                    ex_exc  = 1'b1;
                    ex_ecode = ECODE_ALE;
                    ex_badv = es_mem_va;
                end
                else if (trans_exc) begin
                    ex_exc      = 1'b1;
                    ex_ecode    = trans_ecode;
                    ex_esubcode = trans_esubcode;
                    ex_badv     = es_mem_va;
                    ex_tlbr     = trans_tlbr;
                end
                else if (es_inst_cacop) begin
                    ex_flush_after = 1'b1;
                end
                else begin
                    ex_mem_load  = es_inst_load;
                    ex_mem_store = es_inst_store;
                    ex_rf_we     = es_inst_load;
                    ex_rf_waddr  = es_dest;
                end
            end
            else if (es_inst_csrrd | es_inst_csrwr | es_inst_csrxchg) begin
                ex_rf_we     = 1'b1;
                ex_rf_waddr  = es_dest;
                ex_rf_wdata  = csr_read_data;
                ex_csr_we    = es_inst_csrwr | es_inst_csrxchg;
                ex_csr_waddr = es_csr_num;
                ex_csr_wmask = es_inst_csrwr ? 32'hffffffff : es_rj_value;
                ex_csr_wdata = es_rd_value;
                ex_flush_after = es_inst_csrwr | es_inst_csrxchg;
            end
            else if (es_inst_tlbsrch | es_inst_tlbrd | es_inst_tlbwr |
                     es_inst_tlbfill | es_inst_invtlb) begin
                ex_flush_after = 1'b1;
                if (es_inst_tlbsrch) begin
                    ex_tlbidx_we    = 1'b1;
                    ex_tlbidx_wdata = tlb_srch_hit ? {28'b0, tlb_srch_index} : 32'h80000000;
                end
                else if (es_inst_tlbrd) begin
                    ex_tlbidx_we     = 1'b1;
                    ex_tlbidx_wdata  = tlbrd_tlbidx;
                    ex_tlbehi_we     = 1'b1;
                    ex_tlbehi_wdata  = tlbrd_tlbehi;
                    ex_tlbelo0_we    = 1'b1;
                    ex_tlbelo0_wdata = tlbrd_tlbelo0;
                    ex_tlbelo1_we    = 1'b1;
                    ex_tlbelo1_wdata = tlbrd_tlbelo1;
                    ex_asid_we       = 1'b1;
                    ex_asid_wdata    = tlbrd_asid;
                end
                else if (es_inst_tlbwr) begin
                    ex_op_tlbwr = 1'b1;
                end
                else if (es_inst_tlbfill) begin
                    ex_op_tlbfill = 1'b1;
                end
                else begin
                    ex_op_invtlb = 1'b1;
                end
            end
            else begin
                if (es_inst_add_w | es_inst_sub_w | es_inst_slt |
                    es_inst_sltu | es_inst_nor | es_inst_and |
                    es_inst_or | es_inst_xor | es_inst_sll_w |
                    es_inst_srl_w | es_inst_sra_w | es_inst_slli_w |
                    es_inst_srli_w | es_inst_srai_w | es_inst_addi_w |
                    es_inst_slti | es_inst_sltui | es_inst_andi |
                    es_inst_ori | es_inst_xori | es_inst_lu12i_w |
                    es_inst_pcaddu12i) begin
                    ex_result = es_alu_result;
                end
                else if (es_inst_mul_w | es_inst_mulh_w | es_inst_mulh_wu |
                         es_inst_div_w | es_inst_div_wu | es_inst_mod_w | es_inst_mod_wu) begin
                    ex_result = muldiv_result;
                end
                else if (es_inst_rdcntvl_w) begin
                    ex_result = stable_counter[31:0];
                end
                else if (es_inst_rdcntvh_w) begin
                    ex_result = stable_counter[63:32];
                end
                else if (es_inst_rdcntid_w) begin
                    ex_result = csr_read_data;
                end
                else if (es_inst_bl | es_inst_jirl) begin
                    ex_result = es_pc_plus4;
                end

                ex_rf_we = es_inst_add_w | es_inst_sub_w | es_inst_slt | es_inst_sltu |
                           es_inst_nor | es_inst_and | es_inst_or | es_inst_xor |
                           es_inst_sll_w | es_inst_srl_w | es_inst_sra_w |
                           es_inst_mul_w | es_inst_mulh_w | es_inst_mulh_wu |
                           es_inst_div_w | es_inst_div_wu | es_inst_mod_w | es_inst_mod_wu |
                           es_inst_slli_w | es_inst_srli_w | es_inst_srai_w |
                           es_inst_addi_w | es_inst_slti | es_inst_sltui |
                           es_inst_andi | es_inst_ori | es_inst_xori |
                           es_inst_lu12i_w | es_inst_pcaddu12i |
                           es_inst_rdcntvl_w | es_inst_rdcntvh_w | es_inst_rdcntid_w |
                           es_inst_bl | es_inst_jirl;
                ex_rf_waddr = es_dest;
                ex_rf_wdata = ex_result;
            end
        end
    end

    wire        es_will_load = es_valid & !es_exc & es_dec_is_load;
    wire        es_will_rf_we = es_valid & !es_exc & es_dec_rf_we;
    wire [4:0] es_will_waddr = es_dest;
    wire       es_forward_valid = es_will_rf_we & !es_will_load &
                                  (!es_muldiv_op | muldiv_done) &
                                  (es_will_waddr != 5'b0);
    wire [31:0] es_forward_data = ex_rf_wdata;

    wire       ms_forward_valid = ms_valid & !ms_exc & ms_rf_we &
                                  !ms_mem_load & (ms_rf_waddr != 5'b0);
    wire       ws_forward_valid = ws_valid & !ws_exc & ws_rf_we &
                                  (ws_rf_waddr != 5'b0);


    // No decoded instruction consumes rk and rd in the same cycle, so the
    // second architectural read port is selected between those addresses.
    wire [4:0] rf_raddr2 = ds_use_rd ? ds_rd : ds_rk;
    wire [31:0] rf_rj_data;
    wire [31:0] rf_rk_or_rd_data;

    regfile u_regfile(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .wen(rf_we_final),
        .waddr(ws_rf_waddr),
        .wdata(ws_rf_wdata),
        .raddr1(ds_rj),
        .rdata1(rf_rj_data),
        .raddr2(rf_raddr2),
        .rdata2(rf_rk_or_rd_data)
    );

    wire ds_load_hazard;
    wire [31:0] ds_rf_rj_value;
    wire [31:0] ds_rf_rk_value;
    wire [31:0] ds_rf_rd_value;

    la32_forward_unit u_forward_unit(
        .ds_valid(ds_valid),
        .use_rj(ds_use_rj),
        .use_rk(ds_use_rk),
        .use_rd(ds_use_rd),
        .rj(ds_rj),
        .rk(ds_rk),
        .rd(ds_rd),
        .raw_rj(rf_rj_data),
        .raw_rk(ds_use_rk ? rf_rk_or_rd_data : 32'b0),
        .raw_rd(ds_use_rd ? rf_rk_or_rd_data : 32'b0),
        .es_load(es_will_load),
        .es_forward_valid(es_forward_valid),
        .es_waddr(es_will_waddr),
        .es_wdata(es_forward_data),
        .ms_valid(ms_valid),
        .ms_load(ms_mem_load),
        .ms_rf_we(ms_rf_we),
        .ms_forward_valid(ms_forward_valid),
        .ms_waddr(ms_rf_waddr),
        .ms_wdata(ms_rf_wdata),
        .ws_forward_valid(ws_forward_valid),
        .ws_waddr(ws_rf_waddr),
        .ws_wdata(ws_rf_wdata),
        .load_hazard(ds_load_hazard),
        .rj_value(ds_rf_rj_value),
        .rk_value(ds_rf_rk_value),
        .rd_value(ds_rf_rd_value)
    );

    wire older_serial = (es_valid & es_serial) | (ms_valid & ms_serial) |
                        (ws_valid & ws_serial);

    wire ws_redirect;
    wire [31:0] ws_redirect_pc;

    wire es_muldiv_wait = es_valid & !es_exc & es_inst_valid & es_muldiv_op &
                          !muldiv_done;
    wire ms_ready_go;
    wire ms_allowin;
    wire es_ready_go;
    wire es_allowin;
    wire ds_ready_go;
    wire ds_allowin;
    wire fs_allowin;

    la32_pipeline_control u_pipeline_control(
        .fs_valid(fs_valid),
        .ds_valid(ds_valid),
        .es_valid(es_valid),
        .ms_valid(ms_valid),
        .ws_valid(ws_valid),
        .ds_load_hazard(ds_load_hazard),
        .ds_serial(ds_serial),
        .older_serial(older_serial),
        .ms_exception(ms_exc),
        .ms_mem_op(ms_mem_load | ms_mem_store),
        .ms_mem_req_sent(ms_mem_req_sent),
        .es_muldiv_wait(es_muldiv_wait),
        .ms_ready_go(ms_ready_go),
        .ms_allowin(ms_allowin),
        .es_ready_go(es_ready_go),
        .es_allowin(es_allowin),
        .ds_ready_go(ds_ready_go),
        .ds_allowin(ds_allowin),
        .fs_allowin(fs_allowin)
    );

    assign muldiv_start = cpu_en & es_valid & !es_exc & es_inst_valid &
                           es_muldiv_op & !muldiv_busy & !muldiv_done;
    assign muldiv_clear = cpu_en & ((es_valid & es_muldiv_op & muldiv_done &
                                     es_allowin) | ws_redirect);

    la32_exu u_exu(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .alu_src1(es_alu_src1),
        .alu_src2(es_alu_src2),
        .alu_op(es_alu_op),
        .alu_result(es_alu_result),
        .valid(es_valid),
        .exception(es_exc),
        .inst_valid(es_inst_valid),
        .op_beq(es_inst_beq),
        .op_bne(es_inst_bne),
        .op_blt(es_inst_blt),
        .op_bge(es_inst_bge),
        .op_bltu(es_inst_bltu),
        .op_bgeu(es_inst_bgeu),
        .op_b(es_inst_b),
        .op_bl(es_inst_bl),
        .op_jirl(es_inst_jirl),
        .pc(es_pc),
        .rj_value(es_rj_value),
        .rk_value(es_rk_value),
        .rd_value(es_rd_value),
        .offs16(es_si16_shift),
        .offs26(es_si26_shift),
        .branch_taken(es_branch_redirect),
        .branch_target(es_branch_target),
        .muldiv_start(muldiv_start),
        .muldiv_clear(muldiv_clear),
        .muldiv_kill(ws_redirect),
        .op_mul_w(es_inst_mul_w),
        .op_mulh_w(es_inst_mulh_w),
        .op_mulh_wu(es_inst_mulh_wu),
        .op_div_w(es_inst_div_w),
        .op_div_wu(es_inst_div_wu),
        .op_mod_w(es_inst_mod_w),
        .op_mod_wu(es_inst_mod_wu),
        .muldiv_busy(muldiv_busy),
        .muldiv_done(muldiv_done),
        .muldiv_result(muldiv_result)
    );

    wire ex_redirect = !ws_redirect & es_branch_redirect & ms_allowin;
    wire [31:0] ex_redirect_pc = es_branch_target;

    wire pipe_empty = !fetch_pending & !fs_valid & !ds_valid &
                      !es_valid & !ms_valid & !ws_valid;
    wire fetch_take_int;

    la32_exception_control u_exception_control(
        .ws_valid(ws_valid),
        .ws_exception(ws_exc),
        .ws_tlbr(ws_tlbr),
        .ws_ertn(ws_ertn),
        .ws_flush_after(ws_flush_after),
        .ws_pc(ws_pc),
        .csr_eentry(csr_eentry),
        .csr_tlbrentry(csr_tlbrentry),
        .csr_era(csr_era),
        .pipe_empty(pipe_empty),
        .has_interrupt(csr_has_int),
        .exception_commit(wb_exc_commit),
        .ertn_commit(wb_ertn_commit),
        .redirect(ws_redirect),
        .redirect_pc(ws_redirect_pc),
        .fetch_interrupt(fetch_take_int)
    );
    wire fetch_block = es_mem_op | ds_serial | older_serial |
                       (csr_has_int & !pipe_empty);
    wire fetch_can_accept = !fetch_pending & fs_allowin & !fetch_block &
                            !ws_redirect & !ex_redirect;
    wire fetch_exc_fire = fetch_take_int | (!es_mem_op & trans_exc);
    wire fetch_fire = cpu_en & fetch_can_accept;

    // Fetch is blocked while an EX-stage memory operation uses the shared
    // translator. Keep that inactive data-translation result away from the
    // instruction RAM address port, so implementation does not time a false
    // ID/EX -> TLB -> instruction RAM single-cycle path.
    wire [31:0] inst_sram_pa = trans_is_fetch ? trans_pa : fetch_pc;

    assign inst_sram_en    = fetch_fire & !fetch_exc_fire;
    assign inst_sram_we    = 4'b0000;
    assign inst_sram_addr  = inst_sram_pa;
    assign inst_sram_wdata = 32'b0;

    wire data_req_fire = cpu_en & ms_valid & !ms_exc &
                         (ms_mem_load | ms_mem_store) & !ms_mem_req_sent &
                         !ws_redirect;
    assign data_sram_en    = data_req_fire;
    assign data_sram_we    = (data_req_fire & ms_mem_store) ? lsu_store_we : 4'b0000;
    assign data_sram_addr  = ms_mem_pa;
    assign data_sram_wdata = lsu_store_wdata;

    la32_fetch_unit u_fetch_unit(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .wb_redirect(ws_redirect),
        .wb_redirect_pc(ws_redirect_pc),
        .ex_redirect(ex_redirect),
        .ex_redirect_pc(ex_redirect_pc),
        .fetch_fire(fetch_fire),
        .fetch_exception(fetch_exc_fire),
        .fetch_interrupt(fetch_take_int),
        .trans_ecode(trans_ecode),
        .trans_esubcode(trans_esubcode),
        .trans_tlbr(trans_tlbr),
        .fs_allowin(fs_allowin),
        .inst_rdata(inst_sram_rdata),
        .pc(fetch_pc),
        .pending(fetch_pending),
        .fs_valid(fs_valid),
        .fs_pc(fs_pc),
        .fs_inst(fs_inst),
        .fs_exc(fs_exc),
        .fs_ecode(fs_ecode),
        .fs_esubcode(fs_esubcode),
        .fs_badv(fs_badv),
        .fs_tlbr(fs_tlbr)
    );

    wire [127:0] ifid_in_payload = {fs_pc, fs_inst, fs_exc, fs_ecode,
                                    fs_esubcode, fs_badv, fs_tlbr};
    wire [127:0] ifid_out_payload;
    assign {ds_pc, ds_inst, ds_exc, ds_ecode, ds_esubcode, ds_badv,
            ds_tlbr} = ifid_out_payload;

    la32_if_id_reg #(.PAYLOAD_WIDTH(128)) u_if_id_reg(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .flush(ws_redirect | ex_redirect),
        .allowin(ds_allowin),
        .in_valid(fs_valid),
        .in_payload(ifid_in_payload),
        .out_valid(ds_valid),
        .out_payload(ifid_out_payload)
    );

    wire [511:0] idex_in_payload = {
        ds_pc, ds_inst, ds_exc, ds_ecode, ds_esubcode, ds_badv, ds_tlbr,
        ds_rf_rj_value, ds_rf_rk_value, ds_rf_rd_value,
        ds_rd, ds_rj, ds_rk, ds_csr_num, ds_invtlb_op, ds_serial,
        ds_dest, ds_dec_is_load, ds_dec_rf_we,
        ds_inst_add_w, ds_inst_sub_w, ds_inst_slt, ds_inst_sltu,
        ds_inst_nor, ds_inst_and, ds_inst_or, ds_inst_xor,
        ds_inst_sll_w, ds_inst_srl_w, ds_inst_sra_w,
        ds_inst_mul_w, ds_inst_mulh_w, ds_inst_mulh_wu,
        ds_inst_div_w, ds_inst_div_wu, ds_inst_mod_w, ds_inst_mod_wu,
        ds_inst_slli_w, ds_inst_srli_w, ds_inst_srai_w,
        ds_inst_addi_w, ds_inst_slti, ds_inst_sltui,
        ds_inst_andi, ds_inst_ori, ds_inst_xori,
        ds_inst_lu12i_w, ds_inst_pcaddu12i,
        ds_inst_ld_b, ds_inst_ld_h, ds_inst_ld_w,
        ds_inst_ld_bu, ds_inst_ld_hu,
        ds_inst_st_b, ds_inst_st_h, ds_inst_st_w,
        ds_inst_beq, ds_inst_bne, ds_inst_blt, ds_inst_bge,
        ds_inst_bltu, ds_inst_bgeu, ds_inst_jirl, ds_inst_b, ds_inst_bl,
        ds_inst_csrrd, ds_inst_csrwr, ds_inst_csrxchg,
        ds_inst_syscall, ds_inst_break, ds_inst_ertn,
        ds_inst_rdcntvl_w, ds_inst_rdcntvh_w, ds_inst_rdcntid_w,
        ds_inst_tlbsrch, ds_inst_tlbrd, ds_inst_tlbwr,
        ds_inst_tlbfill, ds_inst_invtlb, ds_inst_cacop, ds_inst_valid
    };
    wire [511:0] idex_out_payload;
    assign {
        es_pc, es_inst, es_exc, es_ecode, es_esubcode, es_badv, es_tlbr,
        es_rj_value, es_rk_value, es_rd_value,
        es_rd, es_rj, es_rk, es_csr_num, es_invtlb_op, es_serial,
        es_dest, es_dec_is_load, es_dec_rf_we,
        es_inst_add_w, es_inst_sub_w, es_inst_slt, es_inst_sltu,
        es_inst_nor, es_inst_and, es_inst_or, es_inst_xor,
        es_inst_sll_w, es_inst_srl_w, es_inst_sra_w,
        es_inst_mul_w, es_inst_mulh_w, es_inst_mulh_wu,
        es_inst_div_w, es_inst_div_wu, es_inst_mod_w, es_inst_mod_wu,
        es_inst_slli_w, es_inst_srli_w, es_inst_srai_w,
        es_inst_addi_w, es_inst_slti, es_inst_sltui,
        es_inst_andi, es_inst_ori, es_inst_xori,
        es_inst_lu12i_w, es_inst_pcaddu12i,
        es_inst_ld_b, es_inst_ld_h, es_inst_ld_w,
        es_inst_ld_bu, es_inst_ld_hu,
        es_inst_st_b, es_inst_st_h, es_inst_st_w,
        es_inst_beq, es_inst_bne, es_inst_blt, es_inst_bge,
        es_inst_bltu, es_inst_bgeu, es_inst_jirl, es_inst_b, es_inst_bl,
        es_inst_csrrd, es_inst_csrwr, es_inst_csrxchg,
        es_inst_syscall, es_inst_break, es_inst_ertn,
        es_inst_rdcntvl_w, es_inst_rdcntvh_w, es_inst_rdcntid_w,
        es_inst_tlbsrch, es_inst_tlbrd, es_inst_tlbwr,
        es_inst_tlbfill, es_inst_invtlb, es_inst_cacop, es_inst_valid
    } = idex_out_payload;

    la32_id_ex_reg #(.PAYLOAD_WIDTH(512)) u_id_ex_reg(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .flush(ws_redirect | ex_redirect),
        .allowin(es_allowin),
        .in_valid(ds_valid & ds_ready_go),
        .in_payload(idex_in_payload),
        .out_valid(es_valid),
        .out_payload(idex_out_payload)
    );

    wire [639:0] exmem_in_payload = {
        es_pc, es_inst, ex_exc, ex_ecode, ex_esubcode, ex_badv, ex_tlbr,
        ex_ertn, es_serial, ex_flush_after,
        ex_rf_we, ex_rf_waddr, ex_rf_wdata, ex_mem_load, ex_mem_store,
        es_mem_va, ex_mem_pa, es_rd_value,
        es_inst_ld_b, es_inst_ld_h, es_inst_ld_w,
        es_inst_ld_bu, es_inst_ld_hu,
        es_inst_st_b, es_inst_st_h, es_inst_st_w,
        ex_csr_we, ex_csr_waddr, ex_csr_wmask, ex_csr_wdata,
        ex_tlbidx_we, ex_tlbidx_wdata,
        ex_tlbehi_we, ex_tlbehi_wdata,
        ex_tlbelo0_we, ex_tlbelo0_wdata,
        ex_tlbelo1_we, ex_tlbelo1_wdata,
        ex_asid_we, ex_asid_wdata,
        ex_op_tlbwr, ex_op_tlbfill, ex_op_invtlb,
        es_invtlb_op, es_rj_value, es_rk_value
    };
    wire [639:0] exmem_out_payload;
    assign {
        ms_pc, ms_inst, ms_exc, ms_ecode, ms_esubcode, ms_badv, ms_tlbr,
        ms_ertn, ms_serial, ms_flush_after,
        ms_rf_we, ms_rf_waddr, ms_rf_wdata, ms_mem_load, ms_mem_store,
        ms_mem_va, ms_mem_pa, ms_store_data,
        ms_op_ld_b, ms_op_ld_h, ms_op_ld_w,
        ms_op_ld_bu, ms_op_ld_hu,
        ms_op_st_b, ms_op_st_h, ms_op_st_w,
        ms_csr_we, ms_csr_waddr, ms_csr_wmask, ms_csr_wdata,
        ms_tlbidx_we, ms_tlbidx_wdata,
        ms_tlbehi_we, ms_tlbehi_wdata,
        ms_tlbelo0_we, ms_tlbelo0_wdata,
        ms_tlbelo1_we, ms_tlbelo1_wdata,
        ms_asid_we, ms_asid_wdata,
        ms_op_tlbwr, ms_op_tlbfill, ms_op_invtlb,
        ms_invtlb_op, ms_invtlb_asid, ms_invtlb_va
    } = exmem_out_payload;

    la32_ex_mem_reg #(.PAYLOAD_WIDTH(640)) u_ex_mem_reg(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .flush(ws_redirect),
        .allowin(ms_allowin),
        .in_valid(es_valid & es_ready_go),
        .in_payload(exmem_in_payload),
        .request_fire(data_req_fire),
        .out_valid(ms_valid),
        .out_payload(exmem_out_payload),
        .request_sent(ms_mem_req_sent)
    );

    wire [31:0] wb_selected_data;
    la32_wb_select u_wb_select(
        .select_load(ms_mem_load),
        .ex_result(ms_rf_wdata),
        .load_result(lsu_load_result),
        .wb_data(wb_selected_data)
    );

    wire [511:0] memwb_in_payload = {
        ms_pc, ms_inst, ms_exc, ms_ecode, ms_esubcode, ms_badv, ms_tlbr,
        ms_ertn, ms_serial, ms_flush_after,
        ms_rf_we, ms_rf_waddr, wb_selected_data,
        ms_csr_we, ms_csr_waddr, ms_csr_wmask, ms_csr_wdata,
        ms_tlbidx_we, ms_tlbidx_wdata,
        ms_tlbehi_we, ms_tlbehi_wdata,
        ms_tlbelo0_we, ms_tlbelo0_wdata,
        ms_tlbelo1_we, ms_tlbelo1_wdata,
        ms_asid_we, ms_asid_wdata,
        ms_op_tlbwr, ms_op_tlbfill, ms_op_invtlb,
        ms_invtlb_op, ms_invtlb_asid, ms_invtlb_va
    };
    wire [511:0] memwb_out_payload;
    assign {
        ws_pc, ws_inst, ws_exc, ws_ecode, ws_esubcode, ws_badv, ws_tlbr,
        ws_ertn, ws_serial, ws_flush_after,
        ws_rf_we, ws_rf_waddr, ws_rf_wdata,
        ws_csr_we, ws_csr_waddr, ws_csr_wmask, ws_csr_wdata,
        ws_tlbidx_we, ws_tlbidx_wdata,
        ws_tlbehi_we, ws_tlbehi_wdata,
        ws_tlbelo0_we, ws_tlbelo0_wdata,
        ws_tlbelo1_we, ws_tlbelo1_wdata,
        ws_asid_we, ws_asid_wdata,
        ws_op_tlbwr, ws_op_tlbfill, ws_op_invtlb,
        ws_invtlb_op, ws_invtlb_asid, ws_invtlb_va
    } = memwb_out_payload;

    la32_mem_wb_reg #(.PAYLOAD_WIDTH(512)) u_mem_wb_reg(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .flush(ws_redirect),
        .in_valid(ms_valid & ms_ready_go),
        .in_payload(memwb_in_payload),
        .out_valid(ws_valid),
        .out_payload(memwb_out_payload)
    );

    assign debug_fetch_pc = fetch_pc;
    assign debug_pipe_valid = {ws_valid | ms_valid, es_valid, ds_valid, fs_valid | fetch_pending};
    assign debug_pipe_hazard = {ds_load_hazard, older_serial, fetch_block};

    always @(posedge clk) begin
        if (!resetn) begin

            debug_wb_pc <= 32'b0;
            debug_wb_rf_we <= 4'b0;
            debug_wb_rf_wnum <= 5'b0;
            debug_wb_rf_wdata <= 32'b0;
            debug_last_wb_valid <= 1'b0;
            debug_last_wb_pc <= 32'b0;
            debug_last_wb_wnum <= 5'b0;
            debug_last_wb_wdata <= 32'b0;
            debug_commit_valid <= 1'b0;
            debug_commit_pc <= 32'b0;
            debug_commit_inst <= 32'b0;

        end
        else if (cpu_en) begin
            debug_commit_valid <= 1'b0;
            debug_wb_rf_we <= 4'b0;
            debug_wb_rf_wnum <= 5'b0;
            debug_wb_rf_wdata <= 32'b0;

            if (ws_valid) begin
                debug_commit_valid <= 1'b1;
                debug_commit_pc    <= ws_pc;
                debug_commit_inst  <= ws_inst;
                debug_wb_pc        <= ws_pc;
            end

            if (ws_valid && ws_rf_we && ws_rf_waddr != 5'b0 && !ws_exc) begin
                debug_wb_rf_we <= 4'hf;
                debug_wb_rf_wnum <= ws_rf_waddr;
                debug_wb_rf_wdata <= ws_rf_wdata;
                debug_last_wb_valid <= 1'b1;
                debug_last_wb_pc <= ws_pc;
                debug_last_wb_wnum <= ws_rf_waddr;
                debug_last_wb_wdata <= ws_rf_wdata;
            end

        end
    end

endmodule
