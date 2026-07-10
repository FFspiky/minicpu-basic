`timescale 1ns / 1ps

// EXP16 single-issue datapath. Ordinary instructions retire in one clock.
// Synchronous loads and the iterative multiply/divide unit explicitly hold
// the core while preserving the diagram's combinational datapath boundaries.
module la32_single_core(
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
    localparam RESET_PC = 32'h1bfffffc;

    localparam WB_MEM     = 3'b000;
    localparam WB_ALU     = 3'b001;
    localparam WB_IMM     = 3'b010;
    localparam WB_PC4     = 3'b011;
    localparam WB_CSR     = 3'b100;
    localparam WB_CNT_LO  = 3'b101;
    localparam WB_CNT_HI  = 3'b110;
    localparam WB_CNT_ID  = 3'b111;

    reg        valid;
    reg [31:0] pc;

    reg        load_wait;
    reg [31:0] load_pc;
    reg [31:0] load_inst;
    reg [ 4:0] load_rd;
    reg [31:0] load_addr;
    reg        load_ld_b;
    reg        load_ld_h;
    reg        load_ld_w;
    reg        load_ld_bu;
    reg        load_ld_hu;

    reg        muldiv_wait;
    reg [31:0] muldiv_pc;
    reg [31:0] muldiv_inst;
    reg [ 4:0] muldiv_rd;

    wire [31:0] inst = inst_sram_rdata;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] imm12;
    wire [13:0] csr_num;
    wire [ 4:0] unused_cacop_code;
    wire [ 4:0] unused_invtlb_op;

    wire inst_add_w, inst_sub_w, inst_slt, inst_sltu;
    wire inst_nor, inst_and, inst_or, inst_xor;
    wire inst_sll_w, inst_srl_w, inst_sra_w;
    wire inst_mul_w, inst_mulh_w, inst_mulh_wu;
    wire inst_div_w, inst_div_wu, inst_mod_w, inst_mod_wu;
    wire inst_slli_w, inst_srli_w, inst_srai_w;
    wire inst_addi_w, inst_slti, inst_sltui;
    wire inst_andi, inst_ori, inst_xori;
    wire inst_lu12i_w, inst_pcaddu12i;
    wire inst_ld_b, inst_ld_h, inst_ld_w, inst_ld_bu, inst_ld_hu;
    wire inst_st_b, inst_st_h, inst_st_w;
    wire inst_beq, inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu;
    wire inst_jirl, inst_b, inst_bl;
    wire inst_csrrd, inst_csrwr, inst_csrxchg;
    wire inst_syscall, inst_break, inst_ertn;
    wire inst_rdcntvl_w, inst_rdcntvh_w, inst_rdcntid_w;
    wire unused_tlbsrch, unused_tlbrd, unused_tlbwr, unused_tlbfill;
    wire unused_invtlb, unused_cacop;
    wire inst_valid;

    la32_decoder u_decoder(
        .inst(inst), .rd(rd), .rj(rj), .rk(rk), .imm12(imm12), .csr_num(csr_num),
        .cacop_code(unused_cacop_code), .invtlb_op(unused_invtlb_op),
        .inst_add_w(inst_add_w), .inst_sub_w(inst_sub_w), .inst_slt(inst_slt), .inst_sltu(inst_sltu),
        .inst_nor(inst_nor), .inst_and(inst_and), .inst_or(inst_or), .inst_xor(inst_xor),
        .inst_sll_w(inst_sll_w), .inst_srl_w(inst_srl_w), .inst_sra_w(inst_sra_w),
        .inst_mul_w(inst_mul_w), .inst_mulh_w(inst_mulh_w), .inst_mulh_wu(inst_mulh_wu),
        .inst_div_w(inst_div_w), .inst_div_wu(inst_div_wu), .inst_mod_w(inst_mod_w), .inst_mod_wu(inst_mod_wu),
        .inst_slli_w(inst_slli_w), .inst_srli_w(inst_srli_w), .inst_srai_w(inst_srai_w),
        .inst_addi_w(inst_addi_w), .inst_slti(inst_slti), .inst_sltui(inst_sltui),
        .inst_andi(inst_andi), .inst_ori(inst_ori), .inst_xori(inst_xori),
        .inst_lu12i_w(inst_lu12i_w), .inst_pcaddu12i(inst_pcaddu12i),
        .inst_ld_b(inst_ld_b), .inst_ld_h(inst_ld_h), .inst_ld_w(inst_ld_w),
        .inst_ld_bu(inst_ld_bu), .inst_ld_hu(inst_ld_hu),
        .inst_st_b(inst_st_b), .inst_st_h(inst_st_h), .inst_st_w(inst_st_w),
        .inst_beq(inst_beq), .inst_bne(inst_bne), .inst_blt(inst_blt), .inst_bge(inst_bge),
        .inst_bltu(inst_bltu), .inst_bgeu(inst_bgeu),
        .inst_jirl(inst_jirl), .inst_b(inst_b), .inst_bl(inst_bl),
        .inst_csrrd(inst_csrrd), .inst_csrwr(inst_csrwr), .inst_csrxchg(inst_csrxchg),
        .inst_syscall(inst_syscall), .inst_break(inst_break), .inst_ertn(inst_ertn),
        .inst_rdcntvl_w(inst_rdcntvl_w), .inst_rdcntvh_w(inst_rdcntvh_w), .inst_rdcntid_w(inst_rdcntid_w),
        .inst_tlbsrch(unused_tlbsrch), .inst_tlbrd(unused_tlbrd), .inst_tlbwr(unused_tlbwr),
        .inst_tlbfill(unused_tlbfill), .inst_invtlb(unused_invtlb), .inst_cacop(unused_cacop),
        .inst_valid(inst_valid)
    );

    wire       sel_rf_ra2;
    wire       sel_alu_src1;
    wire       sel_alu_src2;
    wire [2:0] ext_op;
    wire [3:0] alu_op;
    wire       ctrl_rf_we;
    wire       sel_rf_dst;
    wire [2:0] sel_rf_res;
    wire       ctrl_data_ram_ce;
    wire       ctrl_data_ram_we;
    wire       br_en;
    wire [2:0] br_op;
    wire       sel_nextpc;
    wire       jirl_sel;
    wire       ctrl_csr_we;
    wire       ctrl_csr_xchg;

    cpu_control u_control(
        .inst_add_w(inst_add_w), .inst_sub_w(inst_sub_w), .inst_slt(inst_slt), .inst_sltu(inst_sltu),
        .inst_nor(inst_nor), .inst_and(inst_and), .inst_or(inst_or), .inst_xor(inst_xor),
        .inst_sll_w(inst_sll_w), .inst_srl_w(inst_srl_w), .inst_sra_w(inst_sra_w),
        .inst_mul_w(inst_mul_w), .inst_mulh_w(inst_mulh_w), .inst_mulh_wu(inst_mulh_wu),
        .inst_div_w(inst_div_w), .inst_div_wu(inst_div_wu), .inst_mod_w(inst_mod_w), .inst_mod_wu(inst_mod_wu),
        .inst_slli_w(inst_slli_w), .inst_srli_w(inst_srli_w), .inst_srai_w(inst_srai_w),
        .inst_addi_w(inst_addi_w), .inst_slti(inst_slti), .inst_sltui(inst_sltui),
        .inst_andi(inst_andi), .inst_ori(inst_ori), .inst_xori(inst_xori),
        .inst_lu12i_w(inst_lu12i_w), .inst_pcaddu12i(inst_pcaddu12i),
        .inst_ld_b(inst_ld_b), .inst_ld_h(inst_ld_h), .inst_ld_w(inst_ld_w),
        .inst_ld_bu(inst_ld_bu), .inst_ld_hu(inst_ld_hu),
        .inst_st_b(inst_st_b), .inst_st_h(inst_st_h), .inst_st_w(inst_st_w),
        .inst_beq(inst_beq), .inst_bne(inst_bne), .inst_blt(inst_blt), .inst_bge(inst_bge),
        .inst_bltu(inst_bltu), .inst_bgeu(inst_bgeu),
        .inst_jirl(inst_jirl), .inst_b(inst_b), .inst_bl(inst_bl),
        .inst_csrrd(inst_csrrd), .inst_csrwr(inst_csrwr), .inst_csrxchg(inst_csrxchg),
        .inst_rdcntvl_w(inst_rdcntvl_w), .inst_rdcntvh_w(inst_rdcntvh_w), .inst_rdcntid_w(inst_rdcntid_w),
        .sel_rf_ra2(sel_rf_ra2), .sel_alu_src1(sel_alu_src1), .sel_alu_src2(sel_alu_src2),
        .ext_op(ext_op), .alu_op(alu_op), .rf_we(ctrl_rf_we), .sel_rf_dst(sel_rf_dst),
        .sel_rf_res(sel_rf_res), .data_ram_ce(ctrl_data_ram_ce), .data_ram_we(ctrl_data_ram_we),
        .br_en(br_en), .br_op(br_op), .sel_nextpc(sel_nextpc), .jirl_sel(jirl_sel),
        .csr_we(ctrl_csr_we), .csr_xchg(ctrl_csr_xchg)
    );

    wire load_complete;
    wire muldiv_complete;
    wire execute_rf_we;
    wire [4:0] execute_rf_waddr;
    wire [31:0] execute_wb_data;
    wire commit_rf_we;
    wire [4:0] commit_rf_waddr;
    wire [31:0] commit_rf_wdata;

    wire [4:0] rf_raddr2 = sel_rf_ra2 ? rk : rd;
    wire [31:0] rj_value;
    wire [31:0] rf_rdata2;

    regfile u_regfile(
        .clk(clk), .resetn(resetn),
        .wen(commit_rf_we), .waddr(commit_rf_waddr), .wdata(commit_rf_wdata),
        .raddr1(rj), .rdata1(rj_value),
        .raddr2(rf_raddr2), .rdata2(rf_rdata2)
    );

    wire [31:0] ext_imm;
    imm_extend u_imm_extend(
        .ext_op(ext_op), .imm12(imm12), .offs16(inst[25:10]),
        .offs26({inst[9:0], inst[25:10]}), .ui5(rk), .si20(inst[24:5]),
        .ext_imm(ext_imm)
    );

    wire [31:0] alu_src1 = sel_alu_src1 ? pc : rj_value;
    wire [31:0] alu_src2 = sel_alu_src2 ? ext_imm : rf_rdata2;
    wire [31:0] alu_result;

    alu u_alu(
        .alu_src1(alu_src1), .alu_src2(alu_src2),
        .alu_op(alu_op), .alu_result(alu_result)
    );

    wire [31:0] seq_pc = pc + 32'd4;
    wire [31:0] normal_next_pc;
    wire branch_taken;

    branch_unit u_branch(
        .br_en(br_en), .br_op(br_op), .sel_nextpc(sel_nextpc), .jirl_sel(jirl_sel),
        .pc(pc), .seq_pc(seq_pc), .branch_offs(ext_imm),
        .rdata1(rj_value), .rdata2(rf_rdata2),
        .next_pc(normal_next_pc), .br_taken(branch_taken)
    );

    wire is_load = inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu;
    wire is_store = inst_st_b | inst_st_h | inst_st_w;
    wire is_muldiv = inst_mul_w | inst_mulh_w | inst_mulh_wu |
                     inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu;
    wire normal_execute = cpu_en & valid & !load_wait & !muldiv_wait;
    wire [31:0] mem_addr = alu_result;

    wire lsu_align_error;
    wire [3:0] lsu_store_we;
    wire [31:0] lsu_store_wdata;
    wire [31:0] lsu_load_result;

    la32_lsu u_lsu(
        .addr(load_wait ? load_addr : mem_addr),
        .store_data(rf_rdata2), .load_data(data_sram_rdata),
        .op_ld_b(load_wait ? load_ld_b : inst_ld_b),
        .op_ld_h(load_wait ? load_ld_h : inst_ld_h),
        .op_ld_w(load_wait ? load_ld_w : inst_ld_w),
        .op_ld_bu(load_wait ? load_ld_bu : inst_ld_bu),
        .op_ld_hu(load_wait ? load_ld_hu : inst_ld_hu),
        .op_st_b(inst_st_b), .op_st_h(inst_st_h), .op_st_w(inst_st_w),
        .align_error(lsu_align_error), .store_we(lsu_store_we),
        .store_wdata(lsu_store_wdata), .load_result(lsu_load_result)
    );

    wire [13:0] csr_read_addr = inst_rdcntid_w ? 14'h040 : csr_num;
    wire [31:0] csr_read_data;
    wire [63:0] stable_counter;
    wire csr_has_int;
    wire [31:0] csr_era;
    wire [31:0] csr_eentry;

    wire exception_now;
    wire [5:0] exception_ecode;
    wire [31:0] exception_badv;

    la32_exception_ctrl u_exception_ctrl(
        .interrupt_pending(csr_has_int), .pc(pc), .inst_valid(inst_valid),
        .inst_syscall(inst_syscall), .inst_break(inst_break),
        .mem_access(is_load | is_store), .mem_align_error(lsu_align_error),
        .mem_addr(mem_addr), .exception_valid(exception_now),
        .exception_ecode(exception_ecode), .exception_badv(exception_badv)
    );

    wire execute_exception = normal_execute & exception_now;
    wire execute_ertn = normal_execute & !exception_now & inst_ertn;
    wire csr_write = normal_execute & !exception_now & ctrl_csr_we;
    wire [31:0] csr_wmask = ctrl_csr_xchg ? rj_value : 32'hffffffff;
    wire [31:0] csr_wdata = rf_rdata2;

    la32_csr u_csr(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en),
        .read_addr(csr_read_addr), .read_data(csr_read_data),
        .csr_we(csr_write), .csr_waddr(csr_num), .csr_wmask(csr_wmask), .csr_wdata(csr_wdata),
        .exc_valid(execute_exception), .exc_pc(pc), .exc_badv(exception_badv),
        .exc_ecode(exception_ecode), .exc_esubcode(9'b0), .exc_tlbr(1'b0),
        .ertn_flush(execute_ertn),
        .tlbidx_we(1'b0), .tlbidx_wdata(32'b0),
        .tlbehi_we(1'b0), .tlbehi_wdata(32'b0),
        .tlbelo0_we(1'b0), .tlbelo0_wdata(32'b0),
        .tlbelo1_we(1'b0), .tlbelo1_wdata(32'b0),
        .asid_we(1'b0), .asid_wdata(32'b0),
        .has_int(csr_has_int), .stable_counter(stable_counter),
        .ertn_pc(), .exc_entry(), .csr_crmd(), .csr_prmd(), .csr_ecfg(), .csr_estat(),
        .csr_era(csr_era), .csr_badv(), .csr_eentry(csr_eentry),
        .csr_tlbidx(), .csr_tlbehi(), .csr_tlbelo0(), .csr_tlbelo1(),
        .csr_asid(), .csr_tlbrentry(), .csr_dmw0(), .csr_dmw1()
    );

    wire muldiv_busy;
    wire muldiv_done;
    wire [31:0] muldiv_result;
    wire muldiv_start = normal_execute & !exception_now & is_muldiv;
    wire muldiv_clear = cpu_en & muldiv_wait & muldiv_done;

    la32_muldiv u_muldiv(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en),
        .start(muldiv_start), .clear(muldiv_clear), .kill(1'b0),
        .src1(rj_value), .src2(rf_rdata2),
        .op_mul_w(inst_mul_w), .op_mulh_w(inst_mulh_w), .op_mulh_wu(inst_mulh_wu),
        .op_div_w(inst_div_w), .op_div_wu(inst_div_wu),
        .op_mod_w(inst_mod_w), .op_mod_wu(inst_mod_wu),
        .busy(muldiv_busy), .done(muldiv_done), .result(muldiv_result)
    );

    reg [31:0] selected_wb_data;
    always @(*) begin
        case (sel_rf_res)
            WB_MEM   : selected_wb_data = lsu_load_result;
            WB_ALU   : selected_wb_data = alu_result;
            WB_IMM   : selected_wb_data = ext_imm;
            WB_PC4   : selected_wb_data = seq_pc;
            WB_CSR   : selected_wb_data = csr_read_data;
            WB_CNT_LO: selected_wb_data = stable_counter[31:0];
            WB_CNT_HI: selected_wb_data = stable_counter[63:32];
            WB_CNT_ID: selected_wb_data = csr_read_data;
            default  : selected_wb_data = 32'b0;
        endcase
    end

    assign execute_wb_data = selected_wb_data;
    assign execute_rf_waddr = !sel_rf_dst ? 5'd1 :
                              (inst_rdcntid_w ? rj : rd);
    assign execute_rf_we = normal_execute & !exception_now & !is_muldiv &
                           !is_load & ctrl_rf_we;

    assign load_complete = cpu_en & load_wait;
    assign muldiv_complete = cpu_en & muldiv_wait & muldiv_done;

    assign commit_rf_we = load_complete ? (load_rd != 5'b0) :
                          muldiv_complete ? (muldiv_rd != 5'b0) :
                          (execute_rf_we & (execute_rf_waddr != 5'b0));
    assign commit_rf_waddr = load_complete ? load_rd :
                             muldiv_complete ? muldiv_rd : execute_rf_waddr;
    assign commit_rf_wdata = load_complete ? lsu_load_result :
                             muldiv_complete ? muldiv_result : execute_wb_data;

    wire [31:0] commit_pc = load_complete ? load_pc :
                            muldiv_complete ? muldiv_pc : pc;
    wire [31:0] commit_inst = load_complete ? load_inst :
                              muldiv_complete ? muldiv_inst : inst;
    wire commit_fire = load_complete | muldiv_complete |
                       (normal_execute & (exception_now | (!is_load & !is_muldiv)));

    wire redirect_now = normal_execute & (exception_now | execute_ertn);
    wire [31:0] redirect_pc = exception_now ? csr_eentry : csr_era;
    wire [31:0] fetch_addr = !valid ? 32'h1c000000 :
                             redirect_now ? redirect_pc : normal_next_pc;

    assign inst_sram_en = cpu_en & !load_wait & !muldiv_wait;
    assign inst_sram_we = 4'b0000;
    assign inst_sram_addr = fetch_addr;
    assign inst_sram_wdata = 32'b0;

    assign data_sram_en = normal_execute & !exception_now & ctrl_data_ram_ce;
    assign data_sram_we = (normal_execute & !exception_now & ctrl_data_ram_we) ?
                          lsu_store_we : 4'b0000;
    assign data_sram_addr = mem_addr;
    assign data_sram_wdata = lsu_store_wdata;

    assign debug_fetch_pc = inst_sram_addr;
    assign debug_pipe_valid = {2'b00, load_wait | muldiv_wait,
                               valid & !load_wait & !muldiv_wait};
    assign debug_pipe_hazard = {1'b0, muldiv_wait, load_wait};

    always @(posedge clk) begin
        if (!resetn) begin
            valid <= 1'b0;
            pc <= RESET_PC;
            load_wait <= 1'b0;
            load_pc <= 32'b0;
            load_inst <= 32'b0;
            load_rd <= 5'b0;
            load_addr <= 32'b0;
            load_ld_b <= 1'b0;
            load_ld_h <= 1'b0;
            load_ld_w <= 1'b0;
            load_ld_bu <= 1'b0;
            load_ld_hu <= 1'b0;
            muldiv_wait <= 1'b0;
            muldiv_pc <= 32'b0;
            muldiv_inst <= 32'b0;
            muldiv_rd <= 5'b0;
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
        end else if (cpu_en) begin
            debug_commit_valid <= commit_fire;
            debug_commit_pc <= commit_pc;
            debug_commit_inst <= commit_inst;
            debug_wb_pc <= commit_pc;
            debug_wb_rf_we <= {4{commit_rf_we}};
            debug_wb_rf_wnum <= commit_rf_we ? commit_rf_waddr : 5'b0;
            debug_wb_rf_wdata <= commit_rf_we ? commit_rf_wdata : 32'b0;

            if (commit_rf_we) begin
                debug_last_wb_valid <= 1'b1;
                debug_last_wb_pc <= commit_pc;
                debug_last_wb_wnum <= commit_rf_waddr;
                debug_last_wb_wdata <= commit_rf_wdata;
            end

            if (load_wait) begin
                load_wait <= 1'b0;
            end else if (muldiv_wait) begin
                if (muldiv_done) begin
                    muldiv_wait <= 1'b0;
                end
            end else begin
                valid <= 1'b1;
                pc <= fetch_addr;

                if (normal_execute & !exception_now & is_load) begin
                    load_wait <= 1'b1;
                    load_pc <= pc;
                    load_inst <= inst;
                    load_rd <= rd;
                    load_addr <= mem_addr;
                    load_ld_b <= inst_ld_b;
                    load_ld_h <= inst_ld_h;
                    load_ld_w <= inst_ld_w;
                    load_ld_bu <= inst_ld_bu;
                    load_ld_hu <= inst_ld_hu;
                end

                if (normal_execute & !exception_now & is_muldiv) begin
                    muldiv_wait <= 1'b1;
                    muldiv_pc <= pc;
                    muldiv_inst <= inst;
                    muldiv_rd <= rd;
                end
            end
        end
    end
endmodule
