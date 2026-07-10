`timescale 1ns / 1ps

// EXP16 control decoder.  The one-hot instruction decode remains in
// la32_decoder; this block only produces datapath select/control signals.
module cpu_control(
    input wire inst_add_w, input wire inst_sub_w, input wire inst_slt, input wire inst_sltu,
    input wire inst_nor, input wire inst_and, input wire inst_or, input wire inst_xor,
    input wire inst_sll_w, input wire inst_srl_w, input wire inst_sra_w,
    input wire inst_mul_w, input wire inst_mulh_w, input wire inst_mulh_wu,
    input wire inst_div_w, input wire inst_div_wu, input wire inst_mod_w, input wire inst_mod_wu,

    input wire inst_slli_w, input wire inst_srli_w, input wire inst_srai_w,
    input wire inst_addi_w, input wire inst_slti, input wire inst_sltui,
    input wire inst_andi, input wire inst_ori, input wire inst_xori,
    input wire inst_lu12i_w, input wire inst_pcaddu12i,

    input wire inst_ld_b, input wire inst_ld_h, input wire inst_ld_w,
    input wire inst_ld_bu, input wire inst_ld_hu,
    input wire inst_st_b, input wire inst_st_h, input wire inst_st_w,

    input wire inst_beq, input wire inst_bne, input wire inst_blt, input wire inst_bge,
    input wire inst_bltu, input wire inst_bgeu,
    input wire inst_jirl, input wire inst_b, input wire inst_bl,

    input wire inst_csrrd, input wire inst_csrwr, input wire inst_csrxchg,
    input wire inst_rdcntvl_w, input wire inst_rdcntvh_w, input wire inst_rdcntid_w,

    output wire       sel_rf_ra2,
    output wire       sel_alu_src1,
    output wire       sel_alu_src2,
    output wire [2:0] ext_op,
    output wire [3:0] alu_op,
    output wire       rf_we,
    output wire       sel_rf_dst,
    output wire [2:0] sel_rf_res,
    output wire       data_ram_ce,
    output wire       data_ram_we,
    output wire       br_en,
    output wire [2:0] br_op,
    output wire       sel_nextpc,
    output wire       jirl_sel,
    output wire       csr_we,
    output wire       csr_xchg
);
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

    localparam EXT_NONE = 3'b000;
    localparam EXT_SI12 = 3'b001;
    localparam EXT_UI5  = 3'b010;
    localparam EXT_BR16 = 3'b011;
    localparam EXT_BR26 = 3'b100;
    localparam EXT_SI20 = 3'b101;
    localparam EXT_UI12 = 3'b110;

    localparam WB_MEM     = 3'b000;
    localparam WB_ALU     = 3'b001;
    localparam WB_IMM     = 3'b010;
    localparam WB_PC4     = 3'b011;
    localparam WB_CSR     = 3'b100;
    localparam WB_CNT_LO  = 3'b101;
    localparam WB_CNT_HI  = 3'b110;
    localparam WB_CNT_ID  = 3'b111;

    localparam BR_EQ  = 3'b000;
    localparam BR_NE  = 3'b001;
    localparam BR_LT  = 3'b010;
    localparam BR_GE  = 3'b011;
    localparam BR_LTU = 3'b100;
    localparam BR_GEU = 3'b101;

    wire inst_alu_reg = inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                        inst_nor | inst_and | inst_or | inst_xor |
                        inst_sll_w | inst_srl_w | inst_sra_w;
    wire inst_muldiv = inst_mul_w | inst_mulh_w | inst_mulh_wu |
                       inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu;
    wire inst_shift_imm = inst_slli_w | inst_srli_w | inst_srai_w;
    wire inst_si12_alu = inst_addi_w | inst_slti | inst_sltui;
    wire inst_ui12_alu = inst_andi | inst_ori | inst_xori;
    wire inst_load = inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu;
    wire inst_store = inst_st_b | inst_st_h | inst_st_w;
    wire inst_cond_branch = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    wire inst_csr = inst_csrrd | inst_csrwr | inst_csrxchg;
    wire inst_counter = inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid_w;

    // Read port 2 selects rk only when the instruction really consumes rk.
    assign sel_rf_ra2 = inst_alu_reg | inst_muldiv;

    assign sel_alu_src1 = inst_pcaddu12i;
    assign sel_alu_src2 = inst_shift_imm | inst_si12_alu | inst_ui12_alu |
                          inst_pcaddu12i | inst_load | inst_store;

    assign ext_op = inst_shift_imm ? EXT_UI5 :
                    inst_ui12_alu ? EXT_UI12 :
                    (inst_si12_alu | inst_load | inst_store) ? EXT_SI12 :
                    (inst_jirl | inst_cond_branch) ? EXT_BR16 :
                    (inst_b | inst_bl) ? EXT_BR26 :
                    (inst_lu12i_w | inst_pcaddu12i) ? EXT_SI20 :
                    EXT_NONE;

    assign alu_op = inst_sub_w ? ALU_SUB :
                    (inst_slt | inst_slti) ? ALU_SLT :
                    (inst_sltu | inst_sltui) ? ALU_SLTU :
                    (inst_sll_w | inst_slli_w) ? ALU_SLL :
                    (inst_srl_w | inst_srli_w) ? ALU_SRL :
                    (inst_sra_w | inst_srai_w) ? ALU_SRA :
                    (inst_and | inst_andi) ? ALU_AND :
                    inst_nor ? ALU_NOR :
                    (inst_or | inst_ori) ? ALU_OR :
                    (inst_xor | inst_xori) ? ALU_XOR :
                    ALU_ADD;

    assign rf_we = inst_alu_reg | inst_muldiv | inst_shift_imm | inst_si12_alu |
                   inst_ui12_alu | inst_lu12i_w | inst_pcaddu12i | inst_load |
                   inst_bl | inst_jirl | inst_csr | inst_counter;

    // 0 selects the fixed link register r1; 1 selects the decoded destination.
    assign sel_rf_dst = ~inst_bl;

    assign sel_rf_res = inst_load ? WB_MEM :
                        inst_lu12i_w ? WB_IMM :
                        (inst_bl | inst_jirl) ? WB_PC4 :
                        inst_csr ? WB_CSR :
                        inst_rdcntvl_w ? WB_CNT_LO :
                        inst_rdcntvh_w ? WB_CNT_HI :
                        inst_rdcntid_w ? WB_CNT_ID :
                        WB_ALU;

    assign data_ram_ce = inst_load | inst_store;
    assign data_ram_we = inst_store;

    assign br_en = inst_cond_branch | inst_b | inst_bl | inst_jirl;
    assign br_op = inst_bne  ? BR_NE :
                   inst_blt  ? BR_LT :
                   inst_bge  ? BR_GE :
                   inst_bltu ? BR_LTU :
                   inst_bgeu ? BR_GEU :
                   BR_EQ;
    assign sel_nextpc = inst_cond_branch;
    assign jirl_sel = ~inst_jirl;

    assign csr_we = inst_csrwr | inst_csrxchg;
    assign csr_xchg = inst_csrxchg;
endmodule
