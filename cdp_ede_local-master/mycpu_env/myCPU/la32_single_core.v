`timescale 1ns / 1ps

// EXP16 in-order core. Ordinary instructions retire in one clock; synchronous
// loads and the iterative multiply/divide unit explicitly hold the core.
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
    localparam RESET_PC  = 32'h1bfffffc;
    localparam ECODE_INT = 6'h00;
    localparam ECODE_ADE = 6'h08;
    localparam ECODE_ALE = 6'h09;
    localparam ECODE_SYS = 6'h0b;
    localparam ECODE_BRK = 6'h0c;
    localparam ECODE_INE = 6'h0d;

    reg         valid;
    reg [31:0]  pc;
    reg         load_wait;
    reg [31:0]  load_pc;
    reg [31:0]  load_inst;
    reg [ 4:0]  load_rd;
    reg [31:0]  load_addr;
    reg         load_ld_b, load_ld_h, load_ld_w, load_ld_bu, load_ld_hu;
    reg         muldiv_wait;
    reg [31:0]  muldiv_pc;
    reg [31:0]  muldiv_inst;
    reg [ 4:0]  muldiv_rd;
    reg [31:0]  rf [0:31];
    integer i;

    wire [31:0] inst = inst_sram_rdata;
    wire [4:0] rd, rj, rk;
    wire [11:0] imm12;
    wire [13:0] csr_num;
    wire [4:0] unused_cacop_code, unused_invtlb_op;
    wire inst_add_w, inst_sub_w, inst_slt, inst_sltu, inst_nor, inst_and, inst_or, inst_xor;
    wire inst_sll_w, inst_srl_w, inst_sra_w, inst_mul_w, inst_mulh_w, inst_mulh_wu;
    wire inst_div_w, inst_div_wu, inst_mod_w, inst_mod_wu;
    wire inst_slli_w, inst_srli_w, inst_srai_w, inst_addi_w, inst_slti, inst_sltui;
    wire inst_andi, inst_ori, inst_xori, inst_lu12i_w, inst_pcaddu12i;
    wire inst_ld_b, inst_ld_h, inst_ld_w, inst_ld_bu, inst_ld_hu;
    wire inst_st_b, inst_st_h, inst_st_w;
    wire inst_beq, inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu, inst_jirl, inst_b, inst_bl;
    wire inst_csrrd, inst_csrwr, inst_csrxchg, inst_syscall, inst_break, inst_ertn;
    wire inst_rdcntvl_w, inst_rdcntvh_w, inst_rdcntid_w;
    wire unused_tlbsrch, unused_tlbrd, unused_tlbwr, unused_tlbfill, unused_invtlb, unused_cacop;
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
        .inst_bltu(inst_bltu), .inst_bgeu(inst_bgeu), .inst_jirl(inst_jirl), .inst_b(inst_b), .inst_bl(inst_bl),
        .inst_csrrd(inst_csrrd), .inst_csrwr(inst_csrwr), .inst_csrxchg(inst_csrxchg),
        .inst_syscall(inst_syscall), .inst_break(inst_break), .inst_ertn(inst_ertn),
        .inst_rdcntvl_w(inst_rdcntvl_w), .inst_rdcntvh_w(inst_rdcntvh_w), .inst_rdcntid_w(inst_rdcntid_w),
        .inst_tlbsrch(unused_tlbsrch), .inst_tlbrd(unused_tlbrd), .inst_tlbwr(unused_tlbwr),
        .inst_tlbfill(unused_tlbfill), .inst_invtlb(unused_invtlb), .inst_cacop(unused_cacop),
        .inst_valid(inst_valid)
    );

    wire [31:0] rj_value = rj == 5'b0 ? 32'b0 : rf[rj];
    wire [31:0] rk_value = rk == 5'b0 ? 32'b0 : rf[rk];
    wire [31:0] rd_value = rd == 5'b0 ? 32'b0 : rf[rd];
    wire signed [31:0] srj_value = rj_value;
    wire signed [31:0] srk_value = rk_value;
    wire [31:0] si12 = {{20{imm12[11]}}, imm12};
    wire [31:0] ui12 = {20'b0, imm12};
    wire [31:0] si16_shift = {{14{inst[25]}}, inst[25:10], 2'b0};
    wire [31:0] si26_shift = {{4{inst[9]}}, inst[9:0], inst[25:10], 2'b0};
    wire [31:0] si20_shift = {inst[24:5], 12'b0};
    wire [31:0] mem_addr = rj_value + si12;

    wire is_load = inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu;
    wire is_store = inst_st_b | inst_st_h | inst_st_w;
    wire is_muldiv = inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu;
    wire normal_execute = cpu_en & valid & !load_wait & !muldiv_wait;

    wire [13:0] csr_read_addr = inst_rdcntid_w ? 14'h040 : csr_num;
    wire [31:0] csr_read_data;
    wire [63:0] stable_counter;
    wire csr_has_int;
    wire [31:0] csr_era, csr_eentry;
    wire lsu_align_error;
    wire [3:0] lsu_store_we;
    wire [31:0] lsu_store_wdata, lsu_load_result;
    wire csr_write = normal_execute & !inst_syscall & !inst_break &
                     (inst_csrwr | inst_csrxchg);
    wire [31:0] csr_wmask = inst_csrwr ? 32'hffffffff : rj_value;
    wire [31:0] csr_wdata = rd_value;

    reg         exception_now;
    reg [5:0]   exception_ecode;
    reg [31:0]  exception_badv;
    always @(*) begin
        exception_now = 1'b0;
        exception_ecode = ECODE_INE;
        exception_badv = 32'b0;
        if (csr_has_int) begin
            exception_now = 1'b1;
            exception_ecode = ECODE_INT;
        end else if (pc[1:0] != 2'b0) begin
            exception_now = 1'b1;
            exception_ecode = ECODE_ADE;
            exception_badv = pc;
        end else if (!inst_valid) begin
            exception_now = 1'b1;
            exception_ecode = ECODE_INE;
        end else if (inst_syscall) begin
            exception_now = 1'b1;
            exception_ecode = ECODE_SYS;
        end else if (inst_break) begin
            exception_now = 1'b1;
            exception_ecode = ECODE_BRK;
        end else if ((is_load | is_store) & lsu_align_error) begin
            exception_now = 1'b1;
            exception_ecode = ECODE_ALE;
            exception_badv = mem_addr;
        end
    end
    wire execute_exception = normal_execute & exception_now;
    wire execute_ertn = normal_execute & !exception_now & inst_ertn;

    la32_csr u_csr(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .read_addr(csr_read_addr), .read_data(csr_read_data),
        .csr_we(csr_write & !exception_now), .csr_waddr(csr_num), .csr_wmask(csr_wmask), .csr_wdata(csr_wdata),
        .exc_valid(execute_exception), .exc_pc(pc), .exc_badv(exception_badv),
        .exc_ecode(exception_ecode), .exc_esubcode(9'b0), .exc_tlbr(1'b0), .ertn_flush(execute_ertn),
        .tlbidx_we(1'b0), .tlbidx_wdata(32'b0), .tlbehi_we(1'b0), .tlbehi_wdata(32'b0),
        .tlbelo0_we(1'b0), .tlbelo0_wdata(32'b0), .tlbelo1_we(1'b0), .tlbelo1_wdata(32'b0),
        .asid_we(1'b0), .asid_wdata(32'b0), .has_int(csr_has_int), .stable_counter(stable_counter),
        .ertn_pc(), .exc_entry(), .csr_crmd(), .csr_prmd(), .csr_ecfg(), .csr_estat(), .csr_era(csr_era),
        .csr_badv(), .csr_eentry(csr_eentry), .csr_tlbidx(), .csr_tlbehi(), .csr_tlbelo0(), .csr_tlbelo1(),
        .csr_asid(), .csr_tlbrentry(), .csr_dmw0(), .csr_dmw1()
    );

    la32_lsu u_lsu(
        .addr(load_wait ? load_addr : mem_addr), .store_data(rd_value), .load_data(data_sram_rdata),
        .op_ld_b(load_wait ? load_ld_b : inst_ld_b), .op_ld_h(load_wait ? load_ld_h : inst_ld_h),
        .op_ld_w(load_wait ? load_ld_w : inst_ld_w), .op_ld_bu(load_wait ? load_ld_bu : inst_ld_bu),
        .op_ld_hu(load_wait ? load_ld_hu : inst_ld_hu), .op_st_b(inst_st_b), .op_st_h(inst_st_h), .op_st_w(inst_st_w),
        .align_error(lsu_align_error), .store_we(lsu_store_we), .store_wdata(lsu_store_wdata), .load_result(lsu_load_result)
    );

    wire muldiv_busy, muldiv_done;
    wire [31:0] muldiv_result;
    wire muldiv_start = normal_execute & !exception_now & is_muldiv;
    wire muldiv_clear = cpu_en & muldiv_wait & muldiv_done;
    la32_muldiv u_muldiv(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .start(muldiv_start), .clear(muldiv_clear), .kill(1'b0),
        .src1(rj_value), .src2(rk_value), .op_mul_w(inst_mul_w), .op_mulh_w(inst_mulh_w), .op_mulh_wu(inst_mulh_wu),
        .op_div_w(inst_div_w), .op_div_wu(inst_div_wu), .op_mod_w(inst_mod_w), .op_mod_wu(inst_mod_wu),
        .busy(muldiv_busy), .done(muldiv_done), .result(muldiv_result)
    );

    wire branch_cond = (inst_beq & (rj_value == rd_value)) |
                       (inst_bne & (rj_value != rd_value)) |
                       (inst_blt & (srj_value < $signed(rd_value))) |
                       (inst_bge & (srj_value >= $signed(rd_value))) |
                       (inst_bltu & (rj_value < rd_value)) |
                       (inst_bgeu & (rj_value >= rd_value));
    wire is_cond_branch = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    wire branch_taken = normal_execute & !exception_now &
                        (inst_b | inst_bl | inst_jirl | (is_cond_branch & branch_cond));
    wire [31:0] branch_target = inst_jirl ? (rj_value + si16_shift) :
                                (inst_b | inst_bl) ? (pc + si26_shift) : (pc + si16_shift);
    wire [31:0] normal_next_pc = branch_taken ? branch_target : pc + 32'd4;
    wire redirect_now = normal_execute & (exception_now | execute_ertn);
    wire [31:0] redirect_pc = exception_now ? csr_eentry : csr_era;
    wire [31:0] fetch_addr = !valid ? 32'h1c000000 : (redirect_now ? redirect_pc : normal_next_pc);

    assign inst_sram_en = cpu_en & !load_wait & !muldiv_wait;
    assign inst_sram_we = 4'b0;
    assign inst_sram_addr = fetch_addr;
    assign inst_sram_wdata = 32'b0;
    assign data_sram_en = normal_execute & !exception_now & (is_load | is_store);
    assign data_sram_we = (normal_execute & !exception_now & is_store) ? lsu_store_we : 4'b0;
    assign data_sram_addr = mem_addr;
    assign data_sram_wdata = lsu_store_wdata;

    reg [31:0] execute_result;
    always @(*) begin
        execute_result = 32'b0;
        if (inst_add_w) execute_result = rj_value + rk_value;
        else if (inst_sub_w) execute_result = rj_value - rk_value;
        else if (inst_slt) execute_result = {31'b0, srj_value < srk_value};
        else if (inst_sltu) execute_result = {31'b0, rj_value < rk_value};
        else if (inst_nor) execute_result = ~(rj_value | rk_value);
        else if (inst_and) execute_result = rj_value & rk_value;
        else if (inst_or) execute_result = rj_value | rk_value;
        else if (inst_xor) execute_result = rj_value ^ rk_value;
        else if (inst_sll_w) execute_result = rj_value << rk_value[4:0];
        else if (inst_srl_w) execute_result = rj_value >> rk_value[4:0];
        else if (inst_sra_w) execute_result = srj_value >>> rk_value[4:0];
        else if (inst_slli_w) execute_result = rj_value << rk;
        else if (inst_srli_w) execute_result = rj_value >> rk;
        else if (inst_srai_w) execute_result = srj_value >>> rk;
        else if (inst_addi_w) execute_result = rj_value + si12;
        else if (inst_slti) execute_result = {31'b0, srj_value < $signed(si12)};
        else if (inst_sltui) execute_result = {31'b0, rj_value < si12};
        else if (inst_andi) execute_result = rj_value & ui12;
        else if (inst_ori) execute_result = rj_value | ui12;
        else if (inst_xori) execute_result = rj_value ^ ui12;
        else if (inst_lu12i_w) execute_result = si20_shift;
        else if (inst_pcaddu12i) execute_result = pc + si20_shift;
        else if (inst_rdcntvl_w) execute_result = stable_counter[31:0];
        else if (inst_rdcntvh_w) execute_result = stable_counter[63:32];
        else if (inst_rdcntid_w) execute_result = csr_read_data;
        else if (inst_csrrd | inst_csrwr | inst_csrxchg) execute_result = csr_read_data;
        else if (inst_bl | inst_jirl) execute_result = pc + 32'd4;
    end

    wire execute_rf_result = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor |
                             inst_sll_w | inst_srl_w | inst_sra_w | inst_slli_w | inst_srli_w | inst_srai_w |
                             inst_addi_w | inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori |
                             inst_lu12i_w | inst_pcaddu12i | inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid_w |
                             inst_csrrd | inst_csrwr | inst_csrxchg | inst_bl | inst_jirl;
    wire execute_rf_we = normal_execute & !exception_now & !is_muldiv & !is_load & execute_rf_result;
    wire [4:0] execute_rf_waddr = inst_bl ? 5'd1 : (inst_rdcntid_w ? rj : rd);
    wire load_complete = cpu_en & load_wait;
    wire muldiv_complete = cpu_en & muldiv_wait & muldiv_done;
    wire [31:0] commit_pc = load_complete ? load_pc : (muldiv_complete ? muldiv_pc : pc);
    wire [31:0] commit_inst = load_complete ? load_inst : (muldiv_complete ? muldiv_inst : inst);
    wire commit_rf_we = load_complete ? (load_rd != 5'b0) :
                        (muldiv_complete ? (muldiv_rd != 5'b0) : (execute_rf_we & (execute_rf_waddr != 5'b0)));
    wire [4:0] commit_rf_waddr = load_complete ? load_rd : (muldiv_complete ? muldiv_rd : execute_rf_waddr);
    wire [31:0] commit_rf_wdata = load_complete ? lsu_load_result :
                                  (muldiv_complete ? muldiv_result : execute_result);
    wire commit_fire = load_complete | muldiv_complete | (normal_execute & !is_muldiv);

    assign debug_fetch_pc = inst_sram_addr;
    assign debug_pipe_valid = {2'b00, load_wait | muldiv_wait, valid & !load_wait & !muldiv_wait};
    assign debug_pipe_hazard = {1'b0, muldiv_wait, load_wait};

    always @(posedge clk) begin
        if (!resetn) begin
            valid <= 1'b0;
            pc <= RESET_PC;
            load_wait <= 1'b0;
            muldiv_wait <= 1'b0;
            load_pc <= 32'b0; load_inst <= 32'b0; load_rd <= 5'b0; load_addr <= 32'b0;
            load_ld_b <= 1'b0; load_ld_h <= 1'b0; load_ld_w <= 1'b0; load_ld_bu <= 1'b0; load_ld_hu <= 1'b0;
            muldiv_pc <= 32'b0; muldiv_inst <= 32'b0; muldiv_rd <= 5'b0;
            debug_wb_pc <= 32'b0; debug_wb_rf_we <= 4'b0; debug_wb_rf_wnum <= 5'b0; debug_wb_rf_wdata <= 32'b0;
            debug_last_wb_valid <= 1'b0; debug_last_wb_pc <= 32'b0; debug_last_wb_wnum <= 5'b0; debug_last_wb_wdata <= 32'b0;
            debug_commit_valid <= 1'b0; debug_commit_pc <= 32'b0; debug_commit_inst <= 32'b0;
            for (i = 0; i < 32; i = i + 1) rf[i] <= 32'b0;
        end else if (cpu_en) begin
            debug_commit_valid <= commit_fire;
            debug_commit_pc <= commit_pc;
            debug_commit_inst <= commit_inst;
            debug_wb_pc <= commit_pc;
            debug_wb_rf_we <= {4{commit_rf_we}};
            debug_wb_rf_wnum <= commit_rf_we ? commit_rf_waddr : 5'b0;
            debug_wb_rf_wdata <= commit_rf_we ? commit_rf_wdata : 32'b0;
            if (commit_rf_we) begin
                rf[commit_rf_waddr] <= commit_rf_wdata;
                debug_last_wb_valid <= 1'b1;
                debug_last_wb_pc <= commit_pc;
                debug_last_wb_wnum <= commit_rf_waddr;
                debug_last_wb_wdata <= commit_rf_wdata;
            end
            rf[0] <= 32'b0;

            if (load_wait) begin
                load_wait <= 1'b0;
            end else if (muldiv_wait) begin
                if (muldiv_done) muldiv_wait <= 1'b0;
            end else begin
                valid <= 1'b1;
                pc <= fetch_addr;
                if (normal_execute & !exception_now & is_load) begin
                    load_wait <= 1'b1;
                    load_pc <= pc; load_inst <= inst; load_rd <= rd; load_addr <= mem_addr;
                    load_ld_b <= inst_ld_b; load_ld_h <= inst_ld_h; load_ld_w <= inst_ld_w;
                    load_ld_bu <= inst_ld_bu; load_ld_hu <= inst_ld_hu;
                end
                if (normal_execute & !exception_now & is_muldiv) begin
                    muldiv_wait <= 1'b1;
                    muldiv_pc <= pc; muldiv_inst <= inst; muldiv_rd <= rd;
                end
            end
        end
    end
endmodule
