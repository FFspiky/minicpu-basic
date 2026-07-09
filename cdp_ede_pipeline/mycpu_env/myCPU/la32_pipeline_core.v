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

    localparam ST_IF_REQ   = 3'd0;
    localparam ST_IF_RESP  = 3'd1;
    localparam ST_ID       = 3'd2;
    localparam ST_EX       = 3'd3;
    localparam ST_MEM_REQ  = 3'd4;
    localparam ST_MEM_RESP = 3'd5;
    localparam ST_WB       = 3'd6;

    localparam ECODE_INT  = 6'h00;
    localparam ECODE_ADE  = 6'h08;
    localparam ECODE_ALE  = 6'h09;
    localparam ECODE_SYS  = 6'h0b;
    localparam ECODE_BRK  = 6'h0c;
    localparam ECODE_INE  = 6'h0d;

    integer i;

    reg [2:0]  state;
    reg [31:0] pc;
    reg [31:0] cur_pc;
    reg [31:0] ir;
    reg [31:0] rj_value;
    reg [31:0] rk_value;
    reg [31:0] rd_value;
    reg [31:0] rf [0:31];

    reg        wb_we_r;
    reg [4:0]  wb_waddr_r;
    reg [31:0] wb_wdata_r;
    reg [31:0] next_pc_r;

    reg        exc_pending_r;
    reg [5:0]  exc_ecode_r;
    reg [8:0]  exc_esubcode_r;
    reg [31:0] exc_badv_r;
    reg        exc_tlbr_r;
    reg        ertn_pending_r;

    reg        mem_is_load_r;
    reg        mem_is_store_r;
    reg [31:0] mem_va_r;
    reg [31:0] mem_pa_r;

    reg        csr_we_r;
    reg [13:0] csr_waddr_r;
    reg [31:0] csr_wmask_r;
    reg [31:0] csr_wdata_r;
    reg        tlbidx_we_r;
    reg [31:0] tlbidx_wdata_r;
    reg        tlbehi_we_r;
    reg [31:0] tlbehi_wdata_r;
    reg        tlbelo0_we_r;
    reg [31:0] tlbelo0_wdata_r;
    reg        tlbelo1_we_r;
    reg [31:0] tlbelo1_wdata_r;
    reg        asid_we_r;
    reg [31:0] asid_wdata_r;
    reg        op_tlbwr_r;
    reg        op_tlbfill_r;
    reg        op_invtlb_r;

    wire [4:0] rd;
    wire [4:0] rj;
    wire [4:0] rk;
    wire [11:0] imm12;
    wire [13:0] csr_num;
    wire [4:0] cacop_code;
    wire [4:0] invtlb_op;
    wire inst_add_w;
    wire inst_sub_w;
    wire inst_slt;
    wire inst_sltu;
    wire inst_nor;
    wire inst_and;
    wire inst_or;
    wire inst_xor;
    wire inst_sll_w;
    wire inst_srl_w;
    wire inst_sra_w;
    wire inst_mul_w;
    wire inst_mulh_w;
    wire inst_mulh_wu;
    wire inst_div_w;
    wire inst_div_wu;
    wire inst_mod_w;
    wire inst_mod_wu;
    wire inst_slli_w;
    wire inst_srli_w;
    wire inst_srai_w;
    wire inst_addi_w;
    wire inst_slti;
    wire inst_sltui;
    wire inst_andi;
    wire inst_ori;
    wire inst_xori;
    wire inst_lu12i_w;
    wire inst_pcaddu12i;
    wire inst_ld_b;
    wire inst_ld_h;
    wire inst_ld_w;
    wire inst_ld_bu;
    wire inst_ld_hu;
    wire inst_st_b;
    wire inst_st_h;
    wire inst_st_w;
    wire inst_beq;
    wire inst_bne;
    wire inst_blt;
    wire inst_bge;
    wire inst_bltu;
    wire inst_bgeu;
    wire inst_jirl;
    wire inst_b;
    wire inst_bl;
    wire inst_csrrd;
    wire inst_csrwr;
    wire inst_csrxchg;
    wire inst_syscall;
    wire inst_break;
    wire inst_ertn;
    wire inst_rdcntvl_w;
    wire inst_rdcntvh_w;
    wire inst_rdcntid_w;
    wire inst_tlbsrch;
    wire inst_tlbrd;
    wire inst_tlbwr;
    wire inst_tlbfill;
    wire inst_invtlb;
    wire inst_cacop;
    wire inst_valid;

    la32_decoder u_decoder(
        .inst(ir),
        .rd(rd),
        .rj(rj),
        .rk(rk),
        .imm12(imm12),
        .csr_num(csr_num),
        .cacop_code(cacop_code),
        .invtlb_op(invtlb_op),
        .inst_add_w(inst_add_w),
        .inst_sub_w(inst_sub_w),
        .inst_slt(inst_slt),
        .inst_sltu(inst_sltu),
        .inst_nor(inst_nor),
        .inst_and(inst_and),
        .inst_or(inst_or),
        .inst_xor(inst_xor),
        .inst_sll_w(inst_sll_w),
        .inst_srl_w(inst_srl_w),
        .inst_sra_w(inst_sra_w),
        .inst_mul_w(inst_mul_w),
        .inst_mulh_w(inst_mulh_w),
        .inst_mulh_wu(inst_mulh_wu),
        .inst_div_w(inst_div_w),
        .inst_div_wu(inst_div_wu),
        .inst_mod_w(inst_mod_w),
        .inst_mod_wu(inst_mod_wu),
        .inst_slli_w(inst_slli_w),
        .inst_srli_w(inst_srli_w),
        .inst_srai_w(inst_srai_w),
        .inst_addi_w(inst_addi_w),
        .inst_slti(inst_slti),
        .inst_sltui(inst_sltui),
        .inst_andi(inst_andi),
        .inst_ori(inst_ori),
        .inst_xori(inst_xori),
        .inst_lu12i_w(inst_lu12i_w),
        .inst_pcaddu12i(inst_pcaddu12i),
        .inst_ld_b(inst_ld_b),
        .inst_ld_h(inst_ld_h),
        .inst_ld_w(inst_ld_w),
        .inst_ld_bu(inst_ld_bu),
        .inst_ld_hu(inst_ld_hu),
        .inst_st_b(inst_st_b),
        .inst_st_h(inst_st_h),
        .inst_st_w(inst_st_w),
        .inst_beq(inst_beq),
        .inst_bne(inst_bne),
        .inst_blt(inst_blt),
        .inst_bge(inst_bge),
        .inst_bltu(inst_bltu),
        .inst_bgeu(inst_bgeu),
        .inst_jirl(inst_jirl),
        .inst_b(inst_b),
        .inst_bl(inst_bl),
        .inst_csrrd(inst_csrrd),
        .inst_csrwr(inst_csrwr),
        .inst_csrxchg(inst_csrxchg),
        .inst_syscall(inst_syscall),
        .inst_break(inst_break),
        .inst_ertn(inst_ertn),
        .inst_rdcntvl_w(inst_rdcntvl_w),
        .inst_rdcntvh_w(inst_rdcntvh_w),
        .inst_rdcntid_w(inst_rdcntid_w),
        .inst_tlbsrch(inst_tlbsrch),
        .inst_tlbrd(inst_tlbrd),
        .inst_tlbwr(inst_tlbwr),
        .inst_tlbfill(inst_tlbfill),
        .inst_invtlb(inst_invtlb),
        .inst_cacop(inst_cacop),
        .inst_valid(inst_valid)
    );

    wire [13:0] csr_read_addr = inst_rdcntid_w ? 14'h040 : csr_num;
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

    la32_csr u_csr(
        .clk(clk),
        .resetn(resetn),
        .cpu_en(cpu_en),
        .read_addr(csr_read_addr),
        .read_data(csr_read_data),
        .csr_we(csr_we_r),
        .csr_waddr(csr_waddr_r),
        .csr_wmask(csr_wmask_r),
        .csr_wdata(csr_wdata_r),
        .exc_valid(exc_pending_r & (state == ST_WB)),
        .exc_pc(cur_pc),
        .exc_badv(exc_badv_r),
        .exc_ecode(exc_ecode_r),
        .exc_esubcode(exc_esubcode_r),
        .exc_tlbr(exc_tlbr_r),
        .ertn_flush(ertn_pending_r & (state == ST_WB)),
        .tlbidx_we(tlbidx_we_r),
        .tlbidx_wdata(tlbidx_wdata_r),
        .tlbehi_we(tlbehi_we_r),
        .tlbehi_wdata(tlbehi_wdata_r),
        .tlbelo0_we(tlbelo0_we_r),
        .tlbelo0_wdata(tlbelo0_wdata_r),
        .tlbelo1_we(tlbelo1_we_r),
        .tlbelo1_wdata(tlbelo1_wdata_r),
        .asid_we(asid_we_r),
        .asid_wdata(asid_wdata_r),
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

    wire [31:0] si12 = {{20{ir[21]}}, ir[21:10]};
    wire [31:0] ui12 = {20'b0, ir[21:10]};
    wire [31:0] si16_shift = {{14{ir[25]}}, ir[25:10], 2'b0};
    wire [31:0] si26_shift = {{4{ir[9]}}, ir[9:0], ir[25:10], 2'b0};
    wire [31:0] si20_shift = {ir[24:5], 12'b0};
    wire [31:0] pc_plus4 = cur_pc + 32'd4;

    wire [31:0] mem_va_calc = rj_value + si12;
    wire        ex_mem_op = inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu |
                            inst_ld_hu | inst_st_b | inst_st_h | inst_st_w | inst_cacop;
    wire        ex_mem_store = inst_st_b | inst_st_h | inst_st_w;
    wire        ex_align_error = ((inst_ld_h | inst_ld_hu | inst_st_h) & mem_va_calc[0]) |
                                 ((inst_ld_w | inst_st_w) & |mem_va_calc[1:0]);

    wire [31:0] trans_va = (state == ST_IF_REQ) ? pc : mem_va_calc;
    wire        trans_is_fetch = state == ST_IF_REQ;
    wire        trans_is_store = (state == ST_EX) && ex_mem_store;

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
        .op_tlbwr(op_tlbwr_r),
        .op_tlbfill(op_tlbfill_r),
        .op_invtlb(op_invtlb_r),
        .invtlb_op(invtlb_op),
        .invtlb_asid(rj_value),
        .invtlb_va(rk_value)
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
        .addr(mem_va_r),
        .store_data(rd_value),
        .load_data(data_sram_rdata),
        .op_ld_b(inst_ld_b),
        .op_ld_h(inst_ld_h),
        .op_ld_w(inst_ld_w),
        .op_ld_bu(inst_ld_bu),
        .op_ld_hu(inst_ld_hu),
        .op_st_b(inst_st_b),
        .op_st_h(inst_st_h),
        .op_st_w(inst_st_w),
        .align_error(lsu_align_error),
        .store_we(lsu_store_we),
        .store_wdata(lsu_store_wdata),
        .load_result(lsu_load_result)
    );

    wire [31:0] muldiv_result;
    la32_muldiv u_muldiv(
        .src1(rj_value),
        .src2(rk_value),
        .op_mul_w(inst_mul_w),
        .op_mulh_w(inst_mulh_w),
        .op_mulh_wu(inst_mulh_wu),
        .op_div_w(inst_div_w),
        .op_div_wu(inst_div_wu),
        .op_mod_w(inst_mod_w),
        .op_mod_wu(inst_mod_wu),
        .result(muldiv_result)
    );

    wire signed [31:0] s_rj = rj_value;
    wire signed [31:0] s_rd = rd_value;
    wire branch_taken = (inst_beq  & (rj_value == rd_value)) |
                        (inst_bne  & (rj_value != rd_value)) |
                        (inst_blt  & (s_rj < s_rd)) |
                        (inst_bge  & (s_rj >= s_rd)) |
                        (inst_bltu & (rj_value < rd_value)) |
                        (inst_bgeu & (rj_value >= rd_value)) |
                        inst_b | inst_bl | inst_jirl;

    assign inst_sram_en    = cpu_en & (state == ST_IF_REQ) & !csr_has_int & !trans_exc;
    assign inst_sram_we    = 4'b0000;
    assign inst_sram_addr  = trans_pa;
    assign inst_sram_wdata = 32'b0;

    assign data_sram_en    = cpu_en & (state == ST_MEM_REQ) & (mem_is_load_r | mem_is_store_r);
    assign data_sram_we    = mem_is_store_r ? lsu_store_we : 4'b0000;
    assign data_sram_addr  = mem_pa_r;
    assign data_sram_wdata = lsu_store_wdata;

    assign debug_fetch_pc = pc;
    assign debug_pipe_valid = {state == ST_MEM_RESP || state == ST_WB,
                               state == ST_EX || state == ST_MEM_REQ,
                               state == ST_ID,
                               state == ST_IF_REQ || state == ST_IF_RESP};
    assign debug_pipe_hazard = 3'b0;

    task clear_side_effects;
        begin
            csr_we_r       <= 1'b0;
            csr_waddr_r    <= 14'b0;
            csr_wmask_r    <= 32'b0;
            csr_wdata_r    <= 32'b0;
            tlbidx_we_r    <= 1'b0;
            tlbidx_wdata_r <= 32'b0;
            tlbehi_we_r    <= 1'b0;
            tlbehi_wdata_r <= 32'b0;
            tlbelo0_we_r   <= 1'b0;
            tlbelo0_wdata_r <= 32'b0;
            tlbelo1_we_r   <= 1'b0;
            tlbelo1_wdata_r <= 32'b0;
            asid_we_r      <= 1'b0;
            asid_wdata_r   <= 32'b0;
            op_tlbwr_r     <= 1'b0;
            op_tlbfill_r   <= 1'b0;
            op_invtlb_r    <= 1'b0;
        end
    endtask

    task set_exception;
        input [5:0] ecode;
        input [8:0] esubcode;
        input [31:0] badv_v;
        input tlbr_v;
        begin
            exc_pending_r  <= 1'b1;
            exc_ecode_r    <= ecode;
            exc_esubcode_r <= esubcode;
            exc_badv_r     <= badv_v;
            exc_tlbr_r     <= tlbr_v;
            wb_we_r        <= 1'b0;
            mem_is_load_r  <= 1'b0;
            mem_is_store_r <= 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (!resetn) begin
            state               <= ST_IF_REQ;
            pc                  <= 32'h1c000000;
            cur_pc              <= 32'b0;
            ir                  <= 32'b0;
            rj_value            <= 32'b0;
            rk_value            <= 32'b0;
            rd_value            <= 32'b0;
            wb_we_r             <= 1'b0;
            wb_waddr_r          <= 5'b0;
            wb_wdata_r          <= 32'b0;
            next_pc_r           <= 32'h1c000000;
            exc_pending_r       <= 1'b0;
            exc_ecode_r         <= 6'b0;
            exc_esubcode_r      <= 9'b0;
            exc_badv_r          <= 32'b0;
            exc_tlbr_r          <= 1'b0;
            ertn_pending_r      <= 1'b0;
            mem_is_load_r       <= 1'b0;
            mem_is_store_r      <= 1'b0;
            mem_va_r            <= 32'b0;
            mem_pa_r            <= 32'b0;
            debug_wb_pc         <= 32'b0;
            debug_wb_rf_we      <= 4'b0;
            debug_wb_rf_wnum    <= 5'b0;
            debug_wb_rf_wdata   <= 32'b0;
            debug_last_wb_valid <= 1'b0;
            debug_last_wb_pc    <= 32'b0;
            debug_last_wb_wnum  <= 5'b0;
            debug_last_wb_wdata <= 32'b0;
            debug_commit_valid  <= 1'b0;
            debug_commit_pc     <= 32'b0;
            debug_commit_inst   <= 32'b0;
            clear_side_effects();
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'b0;
            end
        end
        else if (cpu_en) begin
            debug_commit_valid <= 1'b0;
            debug_wb_rf_we     <= 4'b0;
            debug_wb_rf_wnum   <= 5'b0;
            debug_wb_rf_wdata  <= 32'b0;
            clear_side_effects();
            rf[0] <= 32'b0;

            case (state)
                ST_IF_REQ: begin
                    cur_pc         <= pc;
                    ir             <= 32'b0;
                    wb_we_r        <= 1'b0;
                    wb_waddr_r     <= 5'b0;
                    wb_wdata_r     <= 32'b0;
                    next_pc_r      <= pc + 32'd4;
                    exc_pending_r  <= 1'b0;
                    ertn_pending_r <= 1'b0;
                    mem_is_load_r  <= 1'b0;
                    mem_is_store_r <= 1'b0;

                    if (csr_has_int) begin
                        set_exception(ECODE_INT, 9'b0, 32'b0, 1'b0);
                        state <= ST_WB;
                    end
                    else if (trans_exc) begin
                        set_exception(trans_ecode, trans_esubcode, pc, trans_tlbr);
                        state <= ST_WB;
                    end
                    else begin
                        state <= ST_IF_RESP;
                    end
                end

                ST_IF_RESP: begin
                    ir    <= inst_sram_rdata;
                    state <= ST_ID;
                end

                ST_ID: begin
                    rj_value <= rf[rj];
                    rk_value <= rf[rk];
                    rd_value <= rf[rd];
                    state    <= ST_EX;
                end

                ST_EX: begin
                    wb_we_r        <= 1'b0;
                    wb_waddr_r     <= rd;
                    wb_wdata_r     <= 32'b0;
                    next_pc_r      <= pc_plus4;
                    exc_pending_r  <= 1'b0;
                    ertn_pending_r <= 1'b0;
                    mem_is_load_r  <= 1'b0;
                    mem_is_store_r <= 1'b0;
                    mem_va_r       <= mem_va_calc;
                    mem_pa_r       <= trans_pa;

                    if (!inst_valid) begin
                        set_exception(ECODE_INE, 9'b0, 32'b0, 1'b0);
                        state <= ST_WB;
                    end
                    else if (inst_syscall) begin
                        set_exception(ECODE_SYS, 9'b0, 32'b0, 1'b0);
                        state <= ST_WB;
                    end
                    else if (inst_break) begin
                        set_exception(ECODE_BRK, 9'b0, 32'b0, 1'b0);
                        state <= ST_WB;
                    end
                    else if (inst_ertn) begin
                        ertn_pending_r <= 1'b1;
                        next_pc_r      <= csr_era;
                        state          <= ST_WB;
                    end
                    else if (inst_invtlb && invtlb_op > 5'h6) begin
                        set_exception(ECODE_INE, 9'b0, 32'b0, 1'b0);
                        state <= ST_WB;
                    end
                    else if (inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                             inst_nor | inst_and | inst_or | inst_xor |
                             inst_sll_w | inst_srl_w | inst_sra_w |
                             inst_mul_w | inst_mulh_w | inst_mulh_wu |
                             inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu |
                             inst_slli_w | inst_srli_w | inst_srai_w |
                             inst_addi_w | inst_slti | inst_sltui |
                             inst_andi | inst_ori | inst_xori |
                             inst_lu12i_w | inst_pcaddu12i |
                             inst_csrrd | inst_csrwr | inst_csrxchg |
                             inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid_w |
                             inst_jirl | inst_bl) begin
                        wb_we_r <= 1'b1;
                        wb_waddr_r <= inst_bl ? 5'd1 :
                                      inst_rdcntid_w ? rj : rd;

                        if (inst_add_w)       wb_wdata_r <= rj_value + rk_value;
                        else if (inst_sub_w)  wb_wdata_r <= rj_value - rk_value;
                        else if (inst_slt)    wb_wdata_r <= {31'b0, s_rj < $signed(rk_value)};
                        else if (inst_sltu)   wb_wdata_r <= {31'b0, rj_value < rk_value};
                        else if (inst_nor)    wb_wdata_r <= ~(rj_value | rk_value);
                        else if (inst_and)    wb_wdata_r <= rj_value & rk_value;
                        else if (inst_or)     wb_wdata_r <= rj_value | rk_value;
                        else if (inst_xor)    wb_wdata_r <= rj_value ^ rk_value;
                        else if (inst_sll_w)  wb_wdata_r <= rj_value << rk_value[4:0];
                        else if (inst_srl_w)  wb_wdata_r <= rj_value >> rk_value[4:0];
                        else if (inst_sra_w)  wb_wdata_r <= s_rj >>> rk_value[4:0];
                        else if (inst_slli_w) wb_wdata_r <= rj_value << rk[4:0];
                        else if (inst_srli_w) wb_wdata_r <= rj_value >> rk[4:0];
                        else if (inst_srai_w) wb_wdata_r <= s_rj >>> rk[4:0];
                        else if (inst_addi_w) wb_wdata_r <= rj_value + si12;
                        else if (inst_slti)   wb_wdata_r <= {31'b0, s_rj < $signed(si12)};
                        else if (inst_sltui)  wb_wdata_r <= {31'b0, rj_value < si12};
                        else if (inst_andi)   wb_wdata_r <= rj_value & ui12;
                        else if (inst_ori)    wb_wdata_r <= rj_value | ui12;
                        else if (inst_xori)   wb_wdata_r <= rj_value ^ ui12;
                        else if (inst_lu12i_w) wb_wdata_r <= si20_shift;
                        else if (inst_pcaddu12i) wb_wdata_r <= cur_pc + si20_shift;
                        else if (inst_mul_w | inst_mulh_w | inst_mulh_wu |
                                 inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu) begin
                            wb_wdata_r <= muldiv_result;
                        end
                        else if (inst_csrrd | inst_csrwr | inst_csrxchg) begin
                            wb_wdata_r  <= csr_read_data;
                            csr_we_r    <= inst_csrwr | inst_csrxchg;
                            csr_waddr_r <= csr_num;
                            csr_wmask_r <= inst_csrwr ? 32'hffffffff : rj_value;
                            csr_wdata_r <= rd_value;
                        end
                        else if (inst_rdcntvl_w) begin
                            wb_wdata_r <= stable_counter[31:0];
                        end
                        else if (inst_rdcntvh_w) begin
                            wb_wdata_r <= stable_counter[63:32];
                        end
                        else if (inst_rdcntid_w) begin
                            wb_wdata_r <= csr_read_data;
                        end
                        else begin
                            wb_wdata_r <= pc_plus4;
                        end

                        if (inst_jirl) begin
                            next_pc_r <= rj_value + si16_shift;
                        end
                        else if (inst_bl) begin
                            next_pc_r <= cur_pc + si26_shift;
                        end
                        state <= ST_WB;
                    end
                    else if (inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu |
                             inst_bgeu | inst_b | inst_bl) begin
                        next_pc_r <= branch_taken ? (cur_pc + (inst_b | inst_bl ? si26_shift : si16_shift)) : pc_plus4;
                        state <= ST_WB;
                    end
                    else if (inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu |
                             inst_ld_hu | inst_st_b | inst_st_h | inst_st_w | inst_cacop) begin
                        if (ex_align_error && !inst_cacop) begin
                            set_exception(ECODE_ALE, 9'b0, mem_va_calc, 1'b0);
                            state <= ST_WB;
                        end
                        else if (trans_exc) begin
                            set_exception(trans_ecode, trans_esubcode, mem_va_calc, trans_tlbr);
                            state <= ST_WB;
                        end
                        else if (inst_cacop) begin
                            state <= ST_WB;
                        end
                        else begin
                            mem_is_load_r  <= inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu;
                            mem_is_store_r <= inst_st_b | inst_st_h | inst_st_w;
                            state <= ST_MEM_REQ;
                        end
                    end
                    else if (inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb) begin
                        if (inst_tlbsrch) begin
                            tlbidx_we_r    <= 1'b1;
                            tlbidx_wdata_r <= tlb_srch_hit ? {28'b0, tlb_srch_index} : 32'h80000000;
                        end
                        else if (inst_tlbrd) begin
                            tlbidx_we_r     <= 1'b1;
                            tlbidx_wdata_r  <= tlbrd_tlbidx;
                            tlbehi_we_r     <= 1'b1;
                            tlbehi_wdata_r  <= tlbrd_tlbehi;
                            tlbelo0_we_r    <= 1'b1;
                            tlbelo0_wdata_r <= tlbrd_tlbelo0;
                            tlbelo1_we_r    <= 1'b1;
                            tlbelo1_wdata_r <= tlbrd_tlbelo1;
                            asid_we_r       <= 1'b1;
                            asid_wdata_r    <= tlbrd_asid;
                        end
                        else if (inst_tlbwr) begin
                            op_tlbwr_r <= 1'b1;
                        end
                        else if (inst_tlbfill) begin
                            op_tlbfill_r <= 1'b1;
                        end
                        else begin
                            op_invtlb_r <= 1'b1;
                        end
                        state <= ST_WB;
                    end
                    else begin
                        state <= ST_WB;
                    end
                end

                ST_MEM_REQ: begin
                    state <= mem_is_load_r ? ST_MEM_RESP : ST_WB;
                end

                ST_MEM_RESP: begin
                    wb_we_r    <= mem_is_load_r;
                    wb_waddr_r <= rd;
                    wb_wdata_r <= lsu_load_result;
                    state      <= ST_WB;
                end

                ST_WB: begin
                    debug_commit_valid <= 1'b1;
                    debug_commit_pc    <= cur_pc;
                    debug_commit_inst  <= ir;
                    debug_wb_pc        <= cur_pc;

                    if (wb_we_r && wb_waddr_r != 5'b0 && !exc_pending_r) begin
                        rf[wb_waddr_r]       <= wb_wdata_r;
                        debug_wb_rf_we       <= 4'hf;
                        debug_wb_rf_wnum     <= wb_waddr_r;
                        debug_wb_rf_wdata    <= wb_wdata_r;
                        debug_last_wb_valid  <= 1'b1;
                        debug_last_wb_pc     <= cur_pc;
                        debug_last_wb_wnum   <= wb_waddr_r;
                        debug_last_wb_wdata  <= wb_wdata_r;
                    end

                    if (exc_pending_r) begin
                        pc <= exc_tlbr_r ? csr_tlbrentry : csr_eentry;
                    end
                    else begin
                        pc <= next_pc_r;
                    end
                    state <= ST_IF_REQ;
                end

                default: begin
                    state <= ST_IF_REQ;
                end
            endcase
        end
    end

endmodule
