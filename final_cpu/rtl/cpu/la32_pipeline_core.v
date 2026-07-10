`timescale 1ns / 1ps

module la32_pipeline_core(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,

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

    integer i;

    reg [31:0] rf [0:31];

    reg [31:0] fetch_pc;
    reg        fetch_pending;
    reg [31:0] fetch_pending_pc;
    reg        fetch_pending_exc;
    reg [ 5:0] fetch_pending_ecode;
    reg [ 8:0] fetch_pending_esubcode;
    reg [31:0] fetch_pending_badv;
    reg        fetch_pending_tlbr;
    reg        fetch_pending_from_mem;

    reg        fs_valid;
    reg [31:0] fs_pc;
    reg [31:0] fs_inst;
    reg        fs_exc;
    reg [ 5:0] fs_ecode;
    reg [ 8:0] fs_esubcode;
    reg [31:0] fs_badv;
    reg        fs_tlbr;

    reg        ds_valid;
    reg [31:0] ds_pc;
    reg [31:0] ds_inst;
    reg        ds_exc;
    reg [ 5:0] ds_ecode;
    reg [ 8:0] ds_esubcode;
    reg [31:0] ds_badv;
    reg        ds_tlbr;

    reg        es_valid;
    reg [31:0] es_pc;
    reg [31:0] es_inst;
    reg        es_exc;
    reg [ 5:0] es_ecode;
    reg [ 8:0] es_esubcode;
    reg [31:0] es_badv;
    reg        es_tlbr;
    reg [31:0] es_rj_value;
    reg [31:0] es_rk_value;
    reg [31:0] es_rd_value;
    reg [ 4:0] es_rd;
    reg [ 4:0] es_rj;
    reg [ 4:0] es_rk;
    reg [13:0] es_csr_num;
    reg [ 4:0] es_invtlb_op;
    reg        es_serial;

    reg es_inst_add_w;
    reg es_inst_sub_w;
    reg es_inst_slt;
    reg es_inst_sltu;
    reg es_inst_nor;
    reg es_inst_and;
    reg es_inst_or;
    reg es_inst_xor;
    reg es_inst_sll_w;
    reg es_inst_srl_w;
    reg es_inst_sra_w;
    reg es_inst_mul_w;
    reg es_inst_mulh_w;
    reg es_inst_mulh_wu;
    reg es_inst_div_w;
    reg es_inst_div_wu;
    reg es_inst_mod_w;
    reg es_inst_mod_wu;
    reg es_inst_slli_w;
    reg es_inst_srli_w;
    reg es_inst_srai_w;
    reg es_inst_addi_w;
    reg es_inst_slti;
    reg es_inst_sltui;
    reg es_inst_andi;
    reg es_inst_ori;
    reg es_inst_xori;
    reg es_inst_lu12i_w;
    reg es_inst_pcaddu12i;
    reg es_inst_ld_b;
    reg es_inst_ld_h;
    reg es_inst_ld_w;
    reg es_inst_ld_bu;
    reg es_inst_ld_hu;
    reg es_inst_st_b;
    reg es_inst_st_h;
    reg es_inst_st_w;
    reg es_inst_beq;
    reg es_inst_bne;
    reg es_inst_blt;
    reg es_inst_bge;
    reg es_inst_bltu;
    reg es_inst_bgeu;
    reg es_inst_jirl;
    reg es_inst_b;
    reg es_inst_bl;
    reg es_inst_csrrd;
    reg es_inst_csrwr;
    reg es_inst_csrxchg;
    reg es_inst_syscall;
    reg es_inst_break;
    reg es_inst_ertn;
    reg es_inst_rdcntvl_w;
    reg es_inst_rdcntvh_w;
    reg es_inst_rdcntid_w;
    reg es_inst_tlbsrch;
    reg es_inst_tlbrd;
    reg es_inst_tlbwr;
    reg es_inst_tlbfill;
    reg es_inst_invtlb;
    reg es_inst_cacop;
    reg es_inst_valid;
    reg es_muldiv_started;

    reg        ms_valid;
    reg [31:0] ms_pc;
    reg [31:0] ms_inst;
    reg        ms_exc;
    reg [ 5:0] ms_ecode;
    reg [ 8:0] ms_esubcode;
    reg [31:0] ms_badv;
    reg        ms_tlbr;
    reg        ms_ertn;
    reg        ms_serial;
    reg        ms_flush_after;
    reg        ms_rf_we;
    reg [ 4:0] ms_rf_waddr;
    reg [31:0] ms_rf_wdata;
    reg        ms_mem_load;
    reg        ms_mem_store;
    reg        ms_mem_req_sent;
    reg [31:0] ms_mem_va;
    reg [31:0] ms_mem_pa;
    reg [31:0] ms_store_data;
    reg        ms_op_ld_b;
    reg        ms_op_ld_h;
    reg        ms_op_ld_w;
    reg        ms_op_ld_bu;
    reg        ms_op_ld_hu;
    reg        ms_op_st_b;
    reg        ms_op_st_h;
    reg        ms_op_st_w;
    reg        ms_csr_we;
    reg [13:0] ms_csr_waddr;
    reg [31:0] ms_csr_wmask;
    reg [31:0] ms_csr_wdata;
    reg        ms_tlbidx_we;
    reg [31:0] ms_tlbidx_wdata;
    reg        ms_tlbehi_we;
    reg [31:0] ms_tlbehi_wdata;
    reg        ms_tlbelo0_we;
    reg [31:0] ms_tlbelo0_wdata;
    reg        ms_tlbelo1_we;
    reg [31:0] ms_tlbelo1_wdata;
    reg        ms_asid_we;
    reg [31:0] ms_asid_wdata;
    reg        ms_op_tlbwr;
    reg        ms_op_tlbfill;
    reg        ms_op_invtlb;
    reg [ 4:0] ms_invtlb_op;
    reg [31:0] ms_invtlb_asid;
    reg [31:0] ms_invtlb_va;

    reg        ws_valid;
    reg [31:0] ws_pc;
    reg [31:0] ws_inst;
    reg        ws_exc;
    reg [ 5:0] ws_ecode;
    reg [ 8:0] ws_esubcode;
    reg [31:0] ws_badv;
    reg        ws_tlbr;
    reg        ws_ertn;
    reg        ws_serial;
    reg        ws_flush_after;
    reg        ws_rf_we;
    reg [ 4:0] ws_rf_waddr;
    reg [31:0] ws_rf_wdata;
    reg        ws_csr_we;
    reg [13:0] ws_csr_waddr;
    reg [31:0] ws_csr_wmask;
    reg [31:0] ws_csr_wdata;
    reg        ws_tlbidx_we;
    reg [31:0] ws_tlbidx_wdata;
    reg        ws_tlbehi_we;
    reg [31:0] ws_tlbehi_wdata;
    reg        ws_tlbelo0_we;
    reg [31:0] ws_tlbelo0_wdata;
    reg        ws_tlbelo1_we;
    reg [31:0] ws_tlbelo1_wdata;
    reg        ws_asid_we;
    reg [31:0] ws_asid_wdata;
    reg        ws_op_tlbwr;
    reg        ws_op_tlbfill;
    reg        ws_op_invtlb;
    reg [ 4:0] ws_invtlb_op;
    reg [31:0] ws_invtlb_asid;
    reg [31:0] ws_invtlb_va;

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

    la32_decoder u_decoder_ds(
        .inst(ds_inst),
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
        .inst_valid(ds_inst_valid)
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

    wire wb_exc_commit      = ws_valid & ws_exc;
    wire wb_ertn_commit     = ws_valid & !ws_exc & ws_ertn;
    wire wb_csr_commit      = ws_valid & !ws_exc & !ws_ertn & ws_csr_we;
    wire wb_tlbidx_commit   = ws_valid & !ws_exc & !ws_ertn & ws_tlbidx_we;
    wire wb_tlbehi_commit   = ws_valid & !ws_exc & !ws_ertn & ws_tlbehi_we;
    wire wb_tlbelo0_commit  = ws_valid & !ws_exc & !ws_ertn & ws_tlbelo0_we;
    wire wb_tlbelo1_commit  = ws_valid & !ws_exc & !ws_ertn & ws_tlbelo1_we;
    wire wb_asid_commit     = ws_valid & !ws_exc & !ws_ertn & ws_asid_we;
    wire wb_tlbwr_commit    = ws_valid & !ws_exc & !ws_ertn & ws_op_tlbwr;
    wire wb_tlbfill_commit  = ws_valid & !ws_exc & !ws_ertn & ws_op_tlbfill;
    wire wb_invtlb_commit   = ws_valid & !ws_exc & !ws_ertn & ws_op_invtlb;

    la32_csr u_csr(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
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

    wire [31:0] es_si12       = {{20{es_inst[21]}}, es_inst[21:10]};
    wire [31:0] es_ui12       = {20'b0, es_inst[21:10]};
    wire [31:0] es_si16_shift = {{14{es_inst[25]}}, es_inst[25:10], 2'b0};
    wire [31:0] es_si26_shift = {{4{es_inst[9]}}, es_inst[9:0], es_inst[25:10], 2'b0};
    wire [31:0] es_si20_shift = {es_inst[24:5], 12'b0};
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

    wire signed [31:0] es_s_rj = es_rj_value;
    wire signed [31:0] es_s_rk = es_rk_value;
    wire signed [31:0] es_s_rd = es_rd_value;

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

    wire es_align_error = ((es_inst_ld_h | es_inst_ld_hu | es_inst_st_h) & es_mem_va[0]) |
                          ((es_inst_ld_w | es_inst_st_w) & |es_mem_va[1:0]);
    wire es_branch_cond_taken =
        (es_inst_beq  & (es_rj_value == es_rd_value)) |
        (es_inst_bne  & (es_rj_value != es_rd_value)) |
        (es_inst_blt  & (es_s_rj < es_s_rd)) |
        (es_inst_bge  & (es_s_rj >= es_s_rd)) |
        (es_inst_bltu & (es_rj_value < es_rd_value)) |
        (es_inst_bgeu & (es_rj_value >= es_rd_value));
    wire es_is_cond_branch = es_inst_beq | es_inst_bne | es_inst_blt |
                             es_inst_bge | es_inst_bltu | es_inst_bgeu;
    wire es_branch_redirect = es_valid & !es_exc & es_inst_valid &
                              (es_inst_b | es_inst_bl | es_inst_jirl |
                               (es_is_cond_branch & es_branch_cond_taken));
    wire [31:0] es_branch_target = es_inst_jirl ? (es_rj_value + es_si16_shift) :
                                   (es_inst_b | es_inst_bl) ? (es_pc + es_si26_shift) :
                                   (es_pc + es_si16_shift);

    always @(*) begin
        ex_rf_we         = 1'b0;
        ex_rf_waddr      = es_rd;
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
                if (es_align_error && !es_inst_cacop) begin
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
                    ex_rf_waddr  = es_rd;
                end
            end
            else if (es_inst_csrrd | es_inst_csrwr | es_inst_csrxchg) begin
                ex_rf_we     = 1'b1;
                ex_rf_waddr  = es_rd;
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
                if (es_inst_add_w) begin
                    ex_result = es_rj_value + es_rk_value;
                end
                else if (es_inst_sub_w) begin
                    ex_result = es_rj_value - es_rk_value;
                end
                else if (es_inst_slt) begin
                    ex_result = {31'b0, es_s_rj < es_s_rk};
                end
                else if (es_inst_sltu) begin
                    ex_result = {31'b0, es_rj_value < es_rk_value};
                end
                else if (es_inst_nor) begin
                    ex_result = ~(es_rj_value | es_rk_value);
                end
                else if (es_inst_and) begin
                    ex_result = es_rj_value & es_rk_value;
                end
                else if (es_inst_or) begin
                    ex_result = es_rj_value | es_rk_value;
                end
                else if (es_inst_xor) begin
                    ex_result = es_rj_value ^ es_rk_value;
                end
                else if (es_inst_sll_w) begin
                    ex_result = es_rj_value << es_rk_value[4:0];
                end
                else if (es_inst_srl_w) begin
                    ex_result = es_rj_value >> es_rk_value[4:0];
                end
                else if (es_inst_sra_w) begin
                    ex_result = es_s_rj >>> es_rk_value[4:0];
                end
                else if (es_inst_slli_w) begin
                    ex_result = es_rj_value << es_rk;
                end
                else if (es_inst_srli_w) begin
                    ex_result = es_rj_value >> es_rk;
                end
                else if (es_inst_srai_w) begin
                    ex_result = es_s_rj >>> es_rk;
                end
                else if (es_inst_addi_w) begin
                    ex_result = es_rj_value + es_si12;
                end
                else if (es_inst_slti) begin
                    ex_result = {31'b0, es_s_rj < $signed(es_si12)};
                end
                else if (es_inst_sltui) begin
                    ex_result = {31'b0, es_rj_value < es_si12};
                end
                else if (es_inst_andi) begin
                    ex_result = es_rj_value & es_ui12;
                end
                else if (es_inst_ori) begin
                    ex_result = es_rj_value | es_ui12;
                end
                else if (es_inst_xori) begin
                    ex_result = es_rj_value ^ es_ui12;
                end
                else if (es_inst_lu12i_w) begin
                    ex_result = es_si20_shift;
                end
                else if (es_inst_pcaddu12i) begin
                    ex_result = es_pc + es_si20_shift;
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
                ex_rf_waddr = es_inst_bl ? 5'd1 :
                               es_inst_rdcntid_w ? es_rj : es_rd;
                ex_rf_wdata = ex_result;
            end
        end
    end

    wire        es_will_load = es_valid & !es_exc & es_inst_load;
    wire        es_will_rf_we = es_valid & !es_exc &
        (es_inst_add_w | es_inst_sub_w | es_inst_slt | es_inst_sltu |
         es_inst_nor | es_inst_and | es_inst_or | es_inst_xor |
         es_inst_sll_w | es_inst_srl_w | es_inst_sra_w |
         es_inst_mul_w | es_inst_mulh_w | es_inst_mulh_wu |
         es_inst_div_w | es_inst_div_wu | es_inst_mod_w | es_inst_mod_wu |
         es_inst_slli_w | es_inst_srli_w | es_inst_srai_w |
         es_inst_addi_w | es_inst_slti | es_inst_sltui |
         es_inst_andi | es_inst_ori | es_inst_xori |
         es_inst_lu12i_w | es_inst_pcaddu12i |
         es_inst_ld_b | es_inst_ld_h | es_inst_ld_w | es_inst_ld_bu | es_inst_ld_hu |
         es_inst_csrrd | es_inst_csrwr | es_inst_csrxchg |
         es_inst_rdcntvl_w | es_inst_rdcntvh_w | es_inst_rdcntid_w |
         es_inst_bl | es_inst_jirl);
    wire [4:0] es_will_waddr = es_inst_bl ? 5'd1 :
                                es_inst_rdcntid_w ? es_rj : es_rd;
    wire       es_forward_valid = es_will_rf_we & !es_will_load &
                                  (!es_muldiv_op | muldiv_done) &
                                  (es_will_waddr != 5'b0);
    wire [31:0] es_forward_data = ex_rf_wdata;

    wire       ms_forward_valid = ms_valid & !ms_exc & ms_rf_we &
                                  !ms_mem_load & (ms_rf_waddr != 5'b0);
    wire       ws_forward_valid = ws_valid & !ws_exc & ws_rf_we &
                                  (ws_rf_waddr != 5'b0);

    wire ds_use_rj = ds_inst_add_w | ds_inst_sub_w | ds_inst_slt | ds_inst_sltu |
                     ds_inst_nor | ds_inst_and | ds_inst_or | ds_inst_xor |
                     ds_inst_sll_w | ds_inst_srl_w | ds_inst_sra_w |
                     ds_inst_mul_w | ds_inst_mulh_w | ds_inst_mulh_wu |
                     ds_inst_div_w | ds_inst_div_wu | ds_inst_mod_w | ds_inst_mod_wu |
                     ds_inst_slli_w | ds_inst_srli_w | ds_inst_srai_w |
                     ds_inst_addi_w | ds_inst_slti | ds_inst_sltui |
                     ds_inst_andi | ds_inst_ori | ds_inst_xori |
                     ds_inst_ld_b | ds_inst_ld_h | ds_inst_ld_w |
                     ds_inst_ld_bu | ds_inst_ld_hu |
                     ds_inst_st_b | ds_inst_st_h | ds_inst_st_w |
                     ds_inst_beq | ds_inst_bne | ds_inst_blt | ds_inst_bge |
                     ds_inst_bltu | ds_inst_bgeu | ds_inst_jirl |
                     ds_inst_csrxchg | ds_inst_invtlb | ds_inst_cacop;
    wire ds_use_rk = ds_inst_add_w | ds_inst_sub_w | ds_inst_slt | ds_inst_sltu |
                     ds_inst_nor | ds_inst_and | ds_inst_or | ds_inst_xor |
                     ds_inst_sll_w | ds_inst_srl_w | ds_inst_sra_w |
                     ds_inst_mul_w | ds_inst_mulh_w | ds_inst_mulh_wu |
                     ds_inst_div_w | ds_inst_div_wu | ds_inst_mod_w | ds_inst_mod_wu |
                     ds_inst_invtlb;
    wire ds_use_rd = ds_inst_st_b | ds_inst_st_h | ds_inst_st_w |
                     ds_inst_beq | ds_inst_bne | ds_inst_blt | ds_inst_bge |
                     ds_inst_bltu | ds_inst_bgeu |
                     ds_inst_csrwr | ds_inst_csrxchg;

    wire ds_rj_wait_load = ds_use_rj & (ds_rj != 5'b0) &
                           ((es_will_load & (es_will_waddr == ds_rj)) |
                            (ms_valid & ms_mem_load & ms_rf_we & (ms_rf_waddr == ds_rj)));
    wire ds_rk_wait_load = ds_use_rk & (ds_rk != 5'b0) &
                           ((es_will_load & (es_will_waddr == ds_rk)) |
                            (ms_valid & ms_mem_load & ms_rf_we & (ms_rf_waddr == ds_rk)));
    wire ds_rd_wait_load = ds_use_rd & (ds_rd != 5'b0) &
                           ((es_will_load & (es_will_waddr == ds_rd)) |
                            (ms_valid & ms_mem_load & ms_rf_we & (ms_rf_waddr == ds_rd)));
    wire ds_load_hazard = ds_valid & (ds_rj_wait_load | ds_rk_wait_load | ds_rd_wait_load);

    wire [31:0] ds_rf_rj_value = (ds_rj == 5'b0) ? 32'b0 :
                                 (es_forward_valid & (es_will_waddr == ds_rj)) ? es_forward_data :
                                 (ms_forward_valid & (ms_rf_waddr == ds_rj)) ? ms_rf_wdata :
                                 (ws_forward_valid & (ws_rf_waddr == ds_rj)) ? ws_rf_wdata :
                                 rf[ds_rj];
    wire [31:0] ds_rf_rk_value = (ds_rk == 5'b0) ? 32'b0 :
                                 (es_forward_valid & (es_will_waddr == ds_rk)) ? es_forward_data :
                                 (ms_forward_valid & (ms_rf_waddr == ds_rk)) ? ms_rf_wdata :
                                 (ws_forward_valid & (ws_rf_waddr == ds_rk)) ? ws_rf_wdata :
                                 rf[ds_rk];
    wire [31:0] ds_rf_rd_value = (ds_rd == 5'b0) ? 32'b0 :
                                 (es_forward_valid & (es_will_waddr == ds_rd)) ? es_forward_data :
                                 (ms_forward_valid & (ms_rf_waddr == ds_rd)) ? ms_rf_wdata :
                                 (ws_forward_valid & (ws_rf_waddr == ds_rd)) ? ws_rf_wdata :
                                 rf[ds_rd];

    wire ds_serial = ds_valid & (ds_exc | !ds_inst_valid | ds_inst_syscall |
                     ds_inst_break | ds_inst_ertn |
                     ds_inst_csrrd | ds_inst_csrwr | ds_inst_csrxchg |
                     ds_inst_tlbsrch | ds_inst_tlbrd | ds_inst_tlbwr |
                     ds_inst_tlbfill | ds_inst_invtlb | ds_inst_cacop);
    wire older_serial = (es_valid & es_serial) | (ms_valid & ms_serial) |
                        (ws_valid & ws_serial);

    wire ws_redirect = ws_valid & (ws_exc | ws_ertn | ws_flush_after);
    wire [31:0] ws_redirect_pc = ws_exc ? (ws_tlbr ? csr_tlbrentry : csr_eentry) :
                                  ws_ertn ? csr_era : (ws_pc + 32'd4);

    wire ms_ready_go = !ms_valid | ms_exc | !(ms_mem_load | ms_mem_store) |
                       ms_mem_req_sent;
    wire ws_allowin = 1'b1;
    wire ms_allowin = !ms_valid | (ms_ready_go & ws_allowin);
    wire es_muldiv_wait = es_valid & !es_exc & es_inst_valid & es_muldiv_op &
                          !muldiv_done;
    wire es_ready_go = !es_muldiv_wait;
    wire es_allowin = !es_valid | (es_ready_go & ms_allowin);
    wire ds_ready_go = !ds_load_hazard & !older_serial &
                       (!ds_serial | (!es_valid & !ms_valid & !ws_valid));
    wire ds_allowin = !ds_valid | (ds_ready_go & es_allowin);
    wire fs_allowin = !fs_valid | ds_allowin;

    assign muldiv_start = cpu_en & es_valid & !es_exc & es_inst_valid &
                           es_muldiv_op & !es_muldiv_started &
                           !muldiv_busy & !muldiv_done;
    assign muldiv_clear = cpu_en & ((es_valid & es_muldiv_op & muldiv_done &
                                     es_allowin) | ws_redirect);

    la32_muldiv u_muldiv(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .start(muldiv_start),
        .clear(muldiv_clear),
        .kill(ws_redirect),
        .src1(es_rj_value),
        .src2(es_rk_value),
        .op_mul_w(es_inst_mul_w),
        .op_mulh_w(es_inst_mulh_w),
        .op_mulh_wu(es_inst_mulh_wu),
        .op_div_w(es_inst_div_w),
        .op_div_wu(es_inst_div_wu),
        .op_mod_w(es_inst_mod_w),
        .op_mod_wu(es_inst_mod_wu),
        .busy(muldiv_busy),
        .done(muldiv_done),
        .result(muldiv_result)
    );

    wire ex_redirect = !ws_redirect & es_branch_redirect & ms_allowin;
    wire [31:0] ex_redirect_pc = es_branch_target;

    wire pipe_empty = !fetch_pending & !fs_valid & !ds_valid &
                      !es_valid & !ms_valid & !ws_valid;
    wire fetch_take_int = pipe_empty & csr_has_int;
    wire fetch_block = es_mem_op | ds_serial | older_serial |
                       (csr_has_int & !pipe_empty);
    wire fetch_can_accept = !fetch_pending & fs_allowin & !fetch_block &
                            !ws_redirect & !ex_redirect;
    wire fetch_exc_fire = fetch_take_int | (!es_mem_op & trans_exc);
    wire fetch_fire = cpu_en & fetch_can_accept;

    assign inst_sram_en    = fetch_fire & !fetch_exc_fire;
    assign inst_sram_we    = 4'b0000;
    assign inst_sram_addr  = trans_pa;
    assign inst_sram_wdata = 32'b0;

    wire data_req_fire = cpu_en & ms_valid & !ms_exc &
                         (ms_mem_load | ms_mem_store) & !ms_mem_req_sent &
                         !ws_redirect;
    assign data_sram_en    = data_req_fire;
    assign data_sram_we    = (data_req_fire & ms_mem_store) ? lsu_store_we : 4'b0000;
    assign data_sram_addr  = ms_mem_pa;
    assign data_sram_wdata = lsu_store_wdata;

    assign debug_fetch_pc = fetch_pc;
    assign debug_pipe_valid = {ws_valid | ms_valid, es_valid, ds_valid, fs_valid | fetch_pending};
    assign debug_pipe_hazard = {ds_load_hazard, older_serial, fetch_block};

    always @(posedge clk) begin
        if (!resetn) begin
            fetch_pc              <= 32'h1c000000;
            fetch_pending         <= 1'b0;
            fetch_pending_pc      <= 32'b0;
            fetch_pending_exc     <= 1'b0;
            fetch_pending_ecode   <= 6'b0;
            fetch_pending_esubcode <= 9'b0;
            fetch_pending_badv    <= 32'b0;
            fetch_pending_tlbr    <= 1'b0;
            fetch_pending_from_mem <= 1'b0;

            fs_valid <= 1'b0;
            fs_pc    <= 32'b0;
            fs_inst  <= 32'b0;
            fs_exc   <= 1'b0;
            fs_ecode <= 6'b0;
            fs_esubcode <= 9'b0;
            fs_badv  <= 32'b0;
            fs_tlbr  <= 1'b0;

            ds_valid <= 1'b0;
            ds_pc    <= 32'b0;
            ds_inst  <= 32'b0;
            ds_exc   <= 1'b0;
            ds_ecode <= 6'b0;
            ds_esubcode <= 9'b0;
            ds_badv  <= 32'b0;
            ds_tlbr  <= 1'b0;

            es_valid <= 1'b0;
            es_pc    <= 32'b0;
            es_inst  <= 32'b0;
            es_exc   <= 1'b0;
            es_ecode <= 6'b0;
            es_esubcode <= 9'b0;
            es_badv  <= 32'b0;
            es_tlbr  <= 1'b0;
            es_rj_value <= 32'b0;
            es_rk_value <= 32'b0;
            es_rd_value <= 32'b0;
            es_rd <= 5'b0;
            es_rj <= 5'b0;
            es_rk <= 5'b0;
            es_csr_num <= 14'b0;
            es_invtlb_op <= 5'b0;
            es_serial <= 1'b0;

            es_inst_add_w <= 1'b0;
            es_inst_sub_w <= 1'b0;
            es_inst_slt <= 1'b0;
            es_inst_sltu <= 1'b0;
            es_inst_nor <= 1'b0;
            es_inst_and <= 1'b0;
            es_inst_or <= 1'b0;
            es_inst_xor <= 1'b0;
            es_inst_sll_w <= 1'b0;
            es_inst_srl_w <= 1'b0;
            es_inst_sra_w <= 1'b0;
            es_inst_mul_w <= 1'b0;
            es_inst_mulh_w <= 1'b0;
            es_inst_mulh_wu <= 1'b0;
            es_inst_div_w <= 1'b0;
            es_inst_div_wu <= 1'b0;
            es_inst_mod_w <= 1'b0;
            es_inst_mod_wu <= 1'b0;
            es_inst_slli_w <= 1'b0;
            es_inst_srli_w <= 1'b0;
            es_inst_srai_w <= 1'b0;
            es_inst_addi_w <= 1'b0;
            es_inst_slti <= 1'b0;
            es_inst_sltui <= 1'b0;
            es_inst_andi <= 1'b0;
            es_inst_ori <= 1'b0;
            es_inst_xori <= 1'b0;
            es_inst_lu12i_w <= 1'b0;
            es_inst_pcaddu12i <= 1'b0;
            es_inst_ld_b <= 1'b0;
            es_inst_ld_h <= 1'b0;
            es_inst_ld_w <= 1'b0;
            es_inst_ld_bu <= 1'b0;
            es_inst_ld_hu <= 1'b0;
            es_inst_st_b <= 1'b0;
            es_inst_st_h <= 1'b0;
            es_inst_st_w <= 1'b0;
            es_inst_beq <= 1'b0;
            es_inst_bne <= 1'b0;
            es_inst_blt <= 1'b0;
            es_inst_bge <= 1'b0;
            es_inst_bltu <= 1'b0;
            es_inst_bgeu <= 1'b0;
            es_inst_jirl <= 1'b0;
            es_inst_b <= 1'b0;
            es_inst_bl <= 1'b0;
            es_inst_csrrd <= 1'b0;
            es_inst_csrwr <= 1'b0;
            es_inst_csrxchg <= 1'b0;
            es_inst_syscall <= 1'b0;
            es_inst_break <= 1'b0;
            es_inst_ertn <= 1'b0;
            es_inst_rdcntvl_w <= 1'b0;
            es_inst_rdcntvh_w <= 1'b0;
            es_inst_rdcntid_w <= 1'b0;
            es_inst_tlbsrch <= 1'b0;
            es_inst_tlbrd <= 1'b0;
            es_inst_tlbwr <= 1'b0;
            es_inst_tlbfill <= 1'b0;
            es_inst_invtlb <= 1'b0;
            es_inst_cacop <= 1'b0;
            es_inst_valid <= 1'b0;
            es_muldiv_started <= 1'b0;

            ms_valid <= 1'b0;
            ms_pc <= 32'b0;
            ms_inst <= 32'b0;
            ms_exc <= 1'b0;
            ms_ecode <= 6'b0;
            ms_esubcode <= 9'b0;
            ms_badv <= 32'b0;
            ms_tlbr <= 1'b0;
            ms_ertn <= 1'b0;
            ms_serial <= 1'b0;
            ms_flush_after <= 1'b0;
            ms_rf_we <= 1'b0;
            ms_rf_waddr <= 5'b0;
            ms_rf_wdata <= 32'b0;
            ms_mem_load <= 1'b0;
            ms_mem_store <= 1'b0;
            ms_mem_req_sent <= 1'b0;
            ms_mem_va <= 32'b0;
            ms_mem_pa <= 32'b0;
            ms_store_data <= 32'b0;
            ms_op_ld_b <= 1'b0;
            ms_op_ld_h <= 1'b0;
            ms_op_ld_w <= 1'b0;
            ms_op_ld_bu <= 1'b0;
            ms_op_ld_hu <= 1'b0;
            ms_op_st_b <= 1'b0;
            ms_op_st_h <= 1'b0;
            ms_op_st_w <= 1'b0;
            ms_csr_we <= 1'b0;
            ms_csr_waddr <= 14'b0;
            ms_csr_wmask <= 32'b0;
            ms_csr_wdata <= 32'b0;
            ms_tlbidx_we <= 1'b0;
            ms_tlbidx_wdata <= 32'b0;
            ms_tlbehi_we <= 1'b0;
            ms_tlbehi_wdata <= 32'b0;
            ms_tlbelo0_we <= 1'b0;
            ms_tlbelo0_wdata <= 32'b0;
            ms_tlbelo1_we <= 1'b0;
            ms_tlbelo1_wdata <= 32'b0;
            ms_asid_we <= 1'b0;
            ms_asid_wdata <= 32'b0;
            ms_op_tlbwr <= 1'b0;
            ms_op_tlbfill <= 1'b0;
            ms_op_invtlb <= 1'b0;
            ms_invtlb_op <= 5'b0;
            ms_invtlb_asid <= 32'b0;
            ms_invtlb_va <= 32'b0;

            ws_valid <= 1'b0;
            ws_pc <= 32'b0;
            ws_inst <= 32'b0;
            ws_exc <= 1'b0;
            ws_ecode <= 6'b0;
            ws_esubcode <= 9'b0;
            ws_badv <= 32'b0;
            ws_tlbr <= 1'b0;
            ws_ertn <= 1'b0;
            ws_serial <= 1'b0;
            ws_flush_after <= 1'b0;
            ws_rf_we <= 1'b0;
            ws_rf_waddr <= 5'b0;
            ws_rf_wdata <= 32'b0;
            ws_csr_we <= 1'b0;
            ws_csr_waddr <= 14'b0;
            ws_csr_wmask <= 32'b0;
            ws_csr_wdata <= 32'b0;
            ws_tlbidx_we <= 1'b0;
            ws_tlbidx_wdata <= 32'b0;
            ws_tlbehi_we <= 1'b0;
            ws_tlbehi_wdata <= 32'b0;
            ws_tlbelo0_we <= 1'b0;
            ws_tlbelo0_wdata <= 32'b0;
            ws_tlbelo1_we <= 1'b0;
            ws_tlbelo1_wdata <= 32'b0;
            ws_asid_we <= 1'b0;
            ws_asid_wdata <= 32'b0;
            ws_op_tlbwr <= 1'b0;
            ws_op_tlbfill <= 1'b0;
            ws_op_invtlb <= 1'b0;
            ws_invtlb_op <= 5'b0;
            ws_invtlb_asid <= 32'b0;
            ws_invtlb_va <= 32'b0;

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

            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'b0;
            end
        end
        else if (cpu_en) begin
            debug_commit_valid <= 1'b0;
            debug_wb_rf_we <= 4'b0;
            debug_wb_rf_wnum <= 5'b0;
            debug_wb_rf_wdata <= 32'b0;
            rf[0] <= 32'b0;

            if (ws_valid) begin
                debug_commit_valid <= 1'b1;
                debug_commit_pc    <= ws_pc;
                debug_commit_inst  <= ws_inst;
                debug_wb_pc        <= ws_pc;
            end

            if (ws_valid && ws_rf_we && ws_rf_waddr != 5'b0 && !ws_exc) begin
                rf[ws_rf_waddr] <= ws_rf_wdata;
                debug_wb_rf_we <= 4'hf;
                debug_wb_rf_wnum <= ws_rf_waddr;
                debug_wb_rf_wdata <= ws_rf_wdata;
                debug_last_wb_valid <= 1'b1;
                debug_last_wb_pc <= ws_pc;
                debug_last_wb_wnum <= ws_rf_waddr;
                debug_last_wb_wdata <= ws_rf_wdata;
            end

            if (ws_redirect) begin
                fetch_pc <= ws_redirect_pc;
            end
            else if (ex_redirect) begin
                fetch_pc <= ex_redirect_pc;
            end
            else if (fetch_fire) begin
                fetch_pc <= fetch_pc + 32'd4;
            end

            if (ws_redirect | ex_redirect) begin
                fetch_pending <= 1'b0;
            end
            else begin
                fetch_pending <= fetch_fire;
                if (fetch_fire) begin
                    fetch_pending_pc <= fetch_pc;
                    fetch_pending_exc <= fetch_exc_fire;
                    fetch_pending_ecode <= fetch_take_int ? ECODE_INT : trans_ecode;
                    fetch_pending_esubcode <= fetch_take_int ? 9'b0 : trans_esubcode;
                    fetch_pending_badv <= fetch_take_int ? 32'b0 : fetch_pc;
                    fetch_pending_tlbr <= fetch_take_int ? 1'b0 : trans_tlbr;
                    fetch_pending_from_mem <= !fetch_exc_fire;
                end
            end

            if (ws_redirect | ex_redirect) begin
                fs_valid <= 1'b0;
            end
            else if (fs_allowin) begin
                fs_valid <= fetch_pending;
                fs_pc <= fetch_pending_pc;
                fs_inst <= fetch_pending_from_mem ? inst_sram_rdata : 32'b0;
                fs_exc <= fetch_pending_exc;
                fs_ecode <= fetch_pending_ecode;
                fs_esubcode <= fetch_pending_esubcode;
                fs_badv <= fetch_pending_badv;
                fs_tlbr <= fetch_pending_tlbr;
            end

            if (ws_redirect | ex_redirect) begin
                ds_valid <= 1'b0;
            end
            else if (ds_allowin) begin
                ds_valid <= fs_valid;
                ds_pc <= fs_pc;
                ds_inst <= fs_inst;
                ds_exc <= fs_exc;
                ds_ecode <= fs_ecode;
                ds_esubcode <= fs_esubcode;
                ds_badv <= fs_badv;
                ds_tlbr <= fs_tlbr;
            end

            if (ws_redirect | ex_redirect) begin
                es_valid <= 1'b0;
            end
            else if (es_allowin) begin
                es_valid <= ds_valid & ds_ready_go;
                es_pc <= ds_pc;
                es_inst <= ds_inst;
                es_exc <= ds_exc;
                es_ecode <= ds_ecode;
                es_esubcode <= ds_esubcode;
                es_badv <= ds_badv;
                es_tlbr <= ds_tlbr;
                es_rj_value <= ds_rf_rj_value;
                es_rk_value <= ds_rf_rk_value;
                es_rd_value <= ds_rf_rd_value;
                es_rd <= ds_rd;
                es_rj <= ds_rj;
                es_rk <= ds_rk;
                es_csr_num <= ds_csr_num;
                es_invtlb_op <= ds_invtlb_op;
                es_serial <= ds_serial;

                es_inst_add_w <= ds_inst_add_w;
                es_inst_sub_w <= ds_inst_sub_w;
                es_inst_slt <= ds_inst_slt;
                es_inst_sltu <= ds_inst_sltu;
                es_inst_nor <= ds_inst_nor;
                es_inst_and <= ds_inst_and;
                es_inst_or <= ds_inst_or;
                es_inst_xor <= ds_inst_xor;
                es_inst_sll_w <= ds_inst_sll_w;
                es_inst_srl_w <= ds_inst_srl_w;
                es_inst_sra_w <= ds_inst_sra_w;
                es_inst_mul_w <= ds_inst_mul_w;
                es_inst_mulh_w <= ds_inst_mulh_w;
                es_inst_mulh_wu <= ds_inst_mulh_wu;
                es_inst_div_w <= ds_inst_div_w;
                es_inst_div_wu <= ds_inst_div_wu;
                es_inst_mod_w <= ds_inst_mod_w;
                es_inst_mod_wu <= ds_inst_mod_wu;
                es_inst_slli_w <= ds_inst_slli_w;
                es_inst_srli_w <= ds_inst_srli_w;
                es_inst_srai_w <= ds_inst_srai_w;
                es_inst_addi_w <= ds_inst_addi_w;
                es_inst_slti <= ds_inst_slti;
                es_inst_sltui <= ds_inst_sltui;
                es_inst_andi <= ds_inst_andi;
                es_inst_ori <= ds_inst_ori;
                es_inst_xori <= ds_inst_xori;
                es_inst_lu12i_w <= ds_inst_lu12i_w;
                es_inst_pcaddu12i <= ds_inst_pcaddu12i;
                es_inst_ld_b <= ds_inst_ld_b;
                es_inst_ld_h <= ds_inst_ld_h;
                es_inst_ld_w <= ds_inst_ld_w;
                es_inst_ld_bu <= ds_inst_ld_bu;
                es_inst_ld_hu <= ds_inst_ld_hu;
                es_inst_st_b <= ds_inst_st_b;
                es_inst_st_h <= ds_inst_st_h;
                es_inst_st_w <= ds_inst_st_w;
                es_inst_beq <= ds_inst_beq;
                es_inst_bne <= ds_inst_bne;
                es_inst_blt <= ds_inst_blt;
                es_inst_bge <= ds_inst_bge;
                es_inst_bltu <= ds_inst_bltu;
                es_inst_bgeu <= ds_inst_bgeu;
                es_inst_jirl <= ds_inst_jirl;
                es_inst_b <= ds_inst_b;
                es_inst_bl <= ds_inst_bl;
                es_inst_csrrd <= ds_inst_csrrd;
                es_inst_csrwr <= ds_inst_csrwr;
                es_inst_csrxchg <= ds_inst_csrxchg;
                es_inst_syscall <= ds_inst_syscall;
                es_inst_break <= ds_inst_break;
                es_inst_ertn <= ds_inst_ertn;
                es_inst_rdcntvl_w <= ds_inst_rdcntvl_w;
                es_inst_rdcntvh_w <= ds_inst_rdcntvh_w;
                es_inst_rdcntid_w <= ds_inst_rdcntid_w;
                es_inst_tlbsrch <= ds_inst_tlbsrch;
                es_inst_tlbrd <= ds_inst_tlbrd;
                es_inst_tlbwr <= ds_inst_tlbwr;
                es_inst_tlbfill <= ds_inst_tlbfill;
                es_inst_invtlb <= ds_inst_invtlb;
                es_inst_cacop <= ds_inst_cacop;
                es_inst_valid <= ds_inst_valid;
            end

            if (ws_redirect | ex_redirect) begin
                es_muldiv_started <= 1'b0;
            end
            else if (es_allowin) begin
                es_muldiv_started <= 1'b0;
            end
            else if (muldiv_start) begin
                es_muldiv_started <= 1'b1;
            end

            if (ws_redirect) begin
                ms_valid <= 1'b0;
                ms_mem_req_sent <= 1'b0;
            end
            else if (ms_allowin) begin
                ms_valid <= es_valid & es_ready_go;
                ms_pc <= es_pc;
                ms_inst <= es_inst;
                ms_exc <= ex_exc;
                ms_ecode <= ex_ecode;
                ms_esubcode <= ex_esubcode;
                ms_badv <= ex_badv;
                ms_tlbr <= ex_tlbr;
                ms_ertn <= ex_ertn;
                ms_serial <= es_serial;
                ms_flush_after <= ex_flush_after;
                ms_rf_we <= ex_rf_we;
                ms_rf_waddr <= ex_rf_waddr;
                ms_rf_wdata <= ex_rf_wdata;
                ms_mem_load <= ex_mem_load;
                ms_mem_store <= ex_mem_store;
                ms_mem_req_sent <= 1'b0;
                ms_mem_va <= es_mem_va;
                ms_mem_pa <= ex_mem_pa;
                ms_store_data <= es_rd_value;
                ms_op_ld_b <= es_inst_ld_b;
                ms_op_ld_h <= es_inst_ld_h;
                ms_op_ld_w <= es_inst_ld_w;
                ms_op_ld_bu <= es_inst_ld_bu;
                ms_op_ld_hu <= es_inst_ld_hu;
                ms_op_st_b <= es_inst_st_b;
                ms_op_st_h <= es_inst_st_h;
                ms_op_st_w <= es_inst_st_w;
                ms_csr_we <= ex_csr_we;
                ms_csr_waddr <= ex_csr_waddr;
                ms_csr_wmask <= ex_csr_wmask;
                ms_csr_wdata <= ex_csr_wdata;
                ms_tlbidx_we <= ex_tlbidx_we;
                ms_tlbidx_wdata <= ex_tlbidx_wdata;
                ms_tlbehi_we <= ex_tlbehi_we;
                ms_tlbehi_wdata <= ex_tlbehi_wdata;
                ms_tlbelo0_we <= ex_tlbelo0_we;
                ms_tlbelo0_wdata <= ex_tlbelo0_wdata;
                ms_tlbelo1_we <= ex_tlbelo1_we;
                ms_tlbelo1_wdata <= ex_tlbelo1_wdata;
                ms_asid_we <= ex_asid_we;
                ms_asid_wdata <= ex_asid_wdata;
                ms_op_tlbwr <= ex_op_tlbwr;
                ms_op_tlbfill <= ex_op_tlbfill;
                ms_op_invtlb <= ex_op_invtlb;
                ms_invtlb_op <= es_invtlb_op;
                ms_invtlb_asid <= es_rj_value;
                ms_invtlb_va <= es_rk_value;
            end
            else if (data_req_fire) begin
                ms_mem_req_sent <= 1'b1;
            end

            if (ws_redirect) begin
                ws_valid <= 1'b0;
            end
            else begin
                ws_valid <= ms_valid & ms_ready_go;
                ws_pc <= ms_pc;
                ws_inst <= ms_inst;
                ws_exc <= ms_exc;
                ws_ecode <= ms_ecode;
                ws_esubcode <= ms_esubcode;
                ws_badv <= ms_badv;
                ws_tlbr <= ms_tlbr;
                ws_ertn <= ms_ertn;
                ws_serial <= ms_serial;
                ws_flush_after <= ms_flush_after;
                ws_rf_we <= ms_rf_we;
                ws_rf_waddr <= ms_rf_waddr;
                ws_rf_wdata <= ms_mem_load ? lsu_load_result : ms_rf_wdata;
                ws_csr_we <= ms_csr_we;
                ws_csr_waddr <= ms_csr_waddr;
                ws_csr_wmask <= ms_csr_wmask;
                ws_csr_wdata <= ms_csr_wdata;
                ws_tlbidx_we <= ms_tlbidx_we;
                ws_tlbidx_wdata <= ms_tlbidx_wdata;
                ws_tlbehi_we <= ms_tlbehi_we;
                ws_tlbehi_wdata <= ms_tlbehi_wdata;
                ws_tlbelo0_we <= ms_tlbelo0_we;
                ws_tlbelo0_wdata <= ms_tlbelo0_wdata;
                ws_tlbelo1_we <= ms_tlbelo1_we;
                ws_tlbelo1_wdata <= ms_tlbelo1_wdata;
                ws_asid_we <= ms_asid_we;
                ws_asid_wdata <= ms_asid_wdata;
                ws_op_tlbwr <= ms_op_tlbwr;
                ws_op_tlbfill <= ms_op_tlbfill;
                ws_op_invtlb <= ms_op_invtlb;
                ws_invtlb_op <= ms_invtlb_op;
                ws_invtlb_asid <= ms_invtlb_asid;
                ws_invtlb_va <= ms_invtlb_va;
            end
        end
    end

endmodule
