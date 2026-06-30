`timescale 1ns / 1ps

module mini_cpu(
    input clk,
    input resetn,
    input cpu_en,

    output [31:0] debug_pc,
    output [31:0] debug_inst,

    output        debug_done,
    output [31:0] debug_store_count,
    output [15:0] debug_last_store_addr,
    output [31:0] debug_last_store_data
);

    // =========================================================
    // 1. PC and instruction fetch
    // =========================================================

    wire [31:0] pc;
    wire [31:0] seq_pc;
    wire [31:0] next_pc;
    wire [31:0] inst;

    ifetch_unit u_ifetch_unit(
        .clk     (clk),
        .resetn  (resetn),
        .cpu_en  (cpu_en),
        .next_pc (next_pc),
        .pc      (pc),
        .seq_pc  (seq_pc),
        .inst (inst)
    );

    // =========================================================
    // 2. Instruction decode
    // =========================================================

    wire [4:0]  rd;
    wire [4:0]  rj;
    wire [4:0]  rk;
    wire [11:0] imm12;
    wire [15:0] offs16;
    wire [4:0]  ui5;
    wire [19:0] si20;
    wire [25:0] offs26;

    wire inst_add_w;
    wire inst_addi_w;
    wire inst_ld_w;
    wire inst_st_w;
    wire inst_bne;
    wire inst_sub_w;
    wire inst_and;
    wire inst_or;
    wire inst_beq;
    wire inst_b;
    wire inst_bl;
    wire inst_jirl;
    wire inst_slt;
    wire inst_sltu;
    wire inst_slli_w;
    wire inst_srli_w;
    wire inst_srai_w;
    wire inst_lu12i_w;
    wire inst_nor;
    wire inst_xor;

    inst_decode u_inst_decode(
        .inst        (inst),
        .rd          (rd),
        .rj          (rj),
        .rk          (rk),
        .imm12       (imm12),
        .offs16      (offs16),
        .ui5         (ui5),
        .si20        (si20),
        .offs26      (offs26),
        .inst_add_w  (inst_add_w),
        .inst_addi_w (inst_addi_w),
        .inst_ld_w   (inst_ld_w),
        .inst_st_w   (inst_st_w),
        .inst_bne    (inst_bne),
        .inst_sub_w  (inst_sub_w),
        .inst_and    (inst_and),
        .inst_or     (inst_or),
        .inst_beq    (inst_beq),
        .inst_b      (inst_b),
        .inst_bl     (inst_bl),
        .inst_jirl   (inst_jirl),
        .inst_slt    (inst_slt),
        .inst_sltu   (inst_sltu),
        .inst_slli_w (inst_slli_w),
        .inst_srli_w (inst_srli_w),
        .inst_srai_w (inst_srai_w),
        .inst_lu12i_w(inst_lu12i_w),
        .inst_nor    (inst_nor),
        .inst_xor    (inst_xor)
    );

    // =========================================================
    // 3. Control unit
    // =========================================================

    wire sel_rf_ra2;
    wire sel_alu_src1;
    wire [2:0] sel_alu_src2;
    wire data_ram_we;
    wire rf_we;
    wire [1:0] sel_rf_res;
    wire sel_rf_dst;
    wire [11:0] alu_op;

    cpu_control u_cpu_control(
        .inst_add_w   (inst_add_w),
        .inst_addi_w  (inst_addi_w),
        .inst_ld_w    (inst_ld_w),
        .inst_st_w    (inst_st_w),
        .inst_bne     (inst_bne),
        .inst_sub_w   (inst_sub_w),
        .inst_and     (inst_and),
        .inst_or      (inst_or),
        .inst_beq     (inst_beq),
        .inst_bl      (inst_bl),
        .inst_jirl    (inst_jirl),
        .inst_slt     (inst_slt),
        .inst_sltu    (inst_sltu),
        .inst_slli_w  (inst_slli_w),
        .inst_srli_w  (inst_srli_w),
        .inst_srai_w  (inst_srai_w),
        .inst_lu12i_w (inst_lu12i_w),
        .inst_nor     (inst_nor),
        .inst_xor     (inst_xor),
        .sel_rf_ra2   (sel_rf_ra2),
        .sel_alu_src1 (sel_alu_src1),
        .sel_alu_src2 (sel_alu_src2),
        .data_ram_we  (data_ram_we),
        .rf_we        (rf_we),
        .sel_rf_res   (sel_rf_res),
        .sel_rf_dst   (sel_rf_dst),
        .alu_op       (alu_op)
    );

    // =========================================================
    // 4. Immediate extension
    // =========================================================

    wire [31:0] imm12_sext;
    wire [31:0] br_offs16;
    wire [31:0] br_offs26;
    wire [31:0] ui5_zext;
    wire [31:0] lu12i_imm;

    imm_extend u_imm_extend(
        .imm12      (imm12),
        .offs16     (offs16),
        .offs26     (offs26),
        .ui5        (ui5),
        .si20       (si20),
        .imm12_sext (imm12_sext),
        .br_offs16  (br_offs16),
        .br_offs26  (br_offs26),
        .ui5_zext   (ui5_zext),
        .lu12i_imm  (lu12i_imm)
    );

    // =========================================================
    // 5. Register file
    // =========================================================

    wire [4:0] rf_raddr1;
    wire [4:0] rf_raddr2;
    wire [4:0] rf_waddr;

    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire [31:0] rf_wdata;

    assign rf_raddr1 = rj;
    assign rf_raddr2 = sel_rf_ra2 ? rd : rk;
    assign rf_waddr  = sel_rf_dst ? 5'd1 : rd;

    regfile u_regfile(
        .clk    (clk),
        .resetn (resetn),
        .wen    (rf_we & cpu_en),
        .waddr  (rf_waddr),
        .wdata  (rf_wdata),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2)
    );

    // =========================================================
    // 6. ALU
    // =========================================================

    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0] alu_result;

    assign alu_src1 = sel_alu_src1 ? pc : rf_rdata1;
    assign alu_src2 = (sel_alu_src2 == 3'b001) ? imm12_sext :
                      (sel_alu_src2 == 3'b010) ? ui5_zext :
                      (sel_alu_src2 == 3'b011) ? 32'd4 :
                      (sel_alu_src2 == 3'b100) ? lu12i_imm :
                                                  rf_rdata2;

    alu u_alu(
        .alu_src1   (alu_src1),
        .alu_src2   (alu_src2),
        .alu_op     (alu_op),
        .alu_result (alu_result)
    );

    // =========================================================
    // 7. Data RAM
    // =========================================================

    wire [15:0] data_ram_addr;
    wire [31:0] data_ram_rdata;

    data_addr_gen u_data_addr_gen(
        .byte_addr (alu_result[17:2]),
        .word_addr (data_ram_addr)
    );

    data_ram u_data_ram(
        .clk (clk),
        .we  (data_ram_we & cpu_en),
        .a   (data_ram_addr),
        .d   (rf_rdata2),
        .spo (data_ram_rdata)
    );

    // =========================================================
    // 8. Write back and branch
    // =========================================================

    assign rf_wdata = (sel_rf_res == 2'b01) ? data_ram_rdata :
                      (sel_rf_res == 2'b10) ? seq_pc :
                                              alu_result;

    branch_unit u_branch_unit(
        .inst_beq  (inst_beq),
        .inst_bne  (inst_bne),
        .inst_b    (inst_b),
        .inst_bl   (inst_bl),
        .inst_jirl (inst_jirl),
        .pc        (pc),
        .seq_pc    (seq_pc),
        .br_offs16 (br_offs16),
        .br_offs26 (br_offs26),
        .rdata1    (rf_rdata1),
        .rdata2    (rf_rdata2),
        .next_pc   (next_pc),
        .br_taken  ()
    );

    // =========================================================
    // 9. Debug state
    // =========================================================

    store_debug u_store_debug(
        .clk                   (clk),
        .resetn                (resetn),
        .cpu_en                (cpu_en),
        .data_ram_we           (data_ram_we),
        .data_ram_addr         (data_ram_addr),
        .store_data            (rf_rdata2),
        .debug_done            (debug_done),
        .debug_store_count     (debug_store_count),
        .debug_last_store_addr (debug_last_store_addr),
        .debug_last_store_data (debug_last_store_data)
    );

    assign debug_pc   = pc;
    assign debug_inst = inst;

endmodule
