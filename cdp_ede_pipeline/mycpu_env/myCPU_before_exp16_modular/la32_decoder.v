`timescale 1ns / 1ps

module la32_decoder(
    input  wire [31:0] inst,

    output wire [ 4:0] rd,
    output wire [ 4:0] rj,
    output wire [ 4:0] rk,
    output wire [11:0] imm12,
    output wire [13:0] csr_num,

    output wire inst_add_w,
    output wire inst_sub_w,
    output wire inst_slt,
    output wire inst_sltu,
    output wire inst_nor,
    output wire inst_and,
    output wire inst_or,
    output wire inst_xor,
    output wire inst_sll_w,
    output wire inst_srl_w,
    output wire inst_sra_w,
    output wire inst_mul_w,
    output wire inst_mulh_w,
    output wire inst_mulh_wu,
    output wire inst_div_w,
    output wire inst_div_wu,
    output wire inst_mod_w,
    output wire inst_mod_wu,

    output wire inst_slli_w,
    output wire inst_srli_w,
    output wire inst_srai_w,
    output wire inst_addi_w,
    output wire inst_slti,
    output wire inst_sltui,
    output wire inst_andi,
    output wire inst_ori,
    output wire inst_xori,
    output wire inst_lu12i_w,
    output wire inst_pcaddu12i,

    output wire inst_ld_b,
    output wire inst_ld_h,
    output wire inst_ld_w,
    output wire inst_ld_bu,
    output wire inst_ld_hu,
    output wire inst_st_b,
    output wire inst_st_h,
    output wire inst_st_w,

    output wire inst_beq,
    output wire inst_bne,
    output wire inst_blt,
    output wire inst_bge,
    output wire inst_bltu,
    output wire inst_bgeu,
    output wire inst_jirl,
    output wire inst_b,
    output wire inst_bl,

    output wire inst_csrrd,
    output wire inst_csrwr,
    output wire inst_csrxchg,
    output wire inst_syscall,
    output wire inst_break,
    output wire inst_ertn,
    output wire inst_rdcntvl_w,
    output wire inst_rdcntvh_w,
    output wire inst_rdcntid_w,

    output wire inst_valid
);

    wire [5:0]  op_31_26 = inst[31:26];
    wire [3:0]  op_25_22 = inst[25:22];
    wire [1:0]  op_21_20 = inst[21:20];
    wire [4:0]  op_19_15 = inst[19:15];
    wire [10:0] func11   = inst[25:15];
    wire [9:0]  op_31_22 = inst[31:22];
    wire [7:0]  op_31_24 = inst[31:24];
    wire [21:0] op_31_10 = inst[31:10];

    assign rd         = inst[4:0];
    assign rj         = inst[9:5];
    assign rk         = inst[14:10];
    assign imm12      = inst[21:10];
    assign csr_num    = inst[23:10];

    assign inst_add_w   = op_31_26 == 6'b000000 && func11 == 11'h020;
    assign inst_sub_w   = op_31_26 == 6'b000000 && func11 == 11'h022;
    assign inst_slt     = op_31_26 == 6'b000000 && func11 == 11'h024;
    assign inst_sltu    = op_31_26 == 6'b000000 && func11 == 11'h025;
    assign inst_nor     = op_31_26 == 6'b000000 && func11 == 11'h028;
    assign inst_and     = op_31_26 == 6'b000000 && func11 == 11'h029;
    assign inst_or      = op_31_26 == 6'b000000 && func11 == 11'h02a;
    assign inst_xor     = op_31_26 == 6'b000000 && func11 == 11'h02b;
    assign inst_sll_w   = op_31_26 == 6'b000000 && func11 == 11'h02e;
    assign inst_srl_w   = op_31_26 == 6'b000000 && func11 == 11'h02f;
    assign inst_sra_w   = op_31_26 == 6'b000000 && func11 == 11'h030;
    assign inst_mul_w   = op_31_26 == 6'b000000 && func11 == 11'h038;
    assign inst_mulh_w  = op_31_26 == 6'b000000 && func11 == 11'h039;
    assign inst_mulh_wu = op_31_26 == 6'b000000 && func11 == 11'h03a;
    assign inst_div_w   = op_31_26 == 6'b000000 && func11 == 11'h040;
    assign inst_mod_w   = op_31_26 == 6'b000000 && func11 == 11'h041;
    assign inst_div_wu  = op_31_26 == 6'b000000 && func11 == 11'h042;
    assign inst_mod_wu  = op_31_26 == 6'b000000 && func11 == 11'h043;

    assign inst_slli_w  = op_31_26 == 6'b000000 && op_25_22 == 4'b0001 &&
                          op_21_20 == 2'b00 && op_19_15 == 5'b00001;
    assign inst_srli_w  = op_31_26 == 6'b000000 && op_25_22 == 4'b0001 &&
                          op_21_20 == 2'b00 && op_19_15 == 5'b01001;
    assign inst_srai_w  = op_31_26 == 6'b000000 && op_25_22 == 4'b0001 &&
                          op_21_20 == 2'b00 && op_19_15 == 5'b10001;
    assign inst_addi_w  = op_31_22 == 10'b0000001010;
    assign inst_slti    = op_31_22 == 10'b0000001000;
    assign inst_sltui   = op_31_22 == 10'b0000001001;
    assign inst_andi    = op_31_22 == 10'b0000001101;
    assign inst_ori     = op_31_22 == 10'b0000001110;
    assign inst_xori    = op_31_22 == 10'b0000001111;
    assign inst_lu12i_w = inst[31:25] == 7'b0001010;
    assign inst_pcaddu12i = inst[31:25] == 7'b0001110;

    assign inst_ld_b  = op_31_22 == 10'b0010100000;
    assign inst_ld_h  = op_31_22 == 10'b0010100001;
    assign inst_ld_w  = op_31_22 == 10'b0010100010;
    assign inst_st_b  = op_31_22 == 10'b0010100100;
    assign inst_st_h  = op_31_22 == 10'b0010100101;
    assign inst_st_w  = op_31_22 == 10'b0010100110;
    assign inst_ld_bu = op_31_22 == 10'b0010101000;
    assign inst_ld_hu = op_31_22 == 10'b0010101001;

    assign inst_beq  = op_31_26 == 6'b010110;
    assign inst_bne  = op_31_26 == 6'b010111;
    assign inst_blt  = op_31_26 == 6'b011000;
    assign inst_bge  = op_31_26 == 6'b011001;
    assign inst_bltu = op_31_26 == 6'b011010;
    assign inst_bgeu = op_31_26 == 6'b011011;
    assign inst_jirl = op_31_26 == 6'b010011;
    assign inst_b    = op_31_26 == 6'b010100;
    assign inst_bl   = op_31_26 == 6'b010101;

    assign inst_csrrd   = op_31_24 == 8'h04 && rj == 5'd0;
    assign inst_csrwr   = op_31_24 == 8'h04 && rj == 5'd1;
    assign inst_csrxchg = op_31_24 == 8'h04 && rj != 5'd0 && rj != 5'd1;
    assign inst_syscall = inst == 32'h002b0000;
    assign inst_break   = inst == 32'h002a0000;
    assign inst_ertn    = inst == 32'h06483800;

    assign inst_rdcntvl_w = op_31_10 == 22'h000018 && rd != 5'd0;
    assign inst_rdcntid_w = op_31_10 == 22'h000018 && rd == 5'd0;
    assign inst_rdcntvh_w = op_31_10 == 22'h000019;

    assign inst_valid = inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                        inst_nor | inst_and | inst_or | inst_xor |
                        inst_sll_w | inst_srl_w | inst_sra_w |
                        inst_mul_w | inst_mulh_w | inst_mulh_wu |
                        inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu |
                        inst_slli_w | inst_srli_w | inst_srai_w |
                        inst_addi_w | inst_slti | inst_sltui |
                        inst_andi | inst_ori | inst_xori |
                        inst_lu12i_w | inst_pcaddu12i |
                        inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu |
                        inst_st_b | inst_st_h | inst_st_w |
                        inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu |
                        inst_jirl | inst_b | inst_bl |
                        inst_csrrd | inst_csrwr | inst_csrxchg |
                        inst_syscall | inst_break | inst_ertn |
                        inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid_w;

endmodule
