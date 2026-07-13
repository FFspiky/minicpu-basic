`timescale 1ns / 1ps
`include "la32_defs.vh"

module la32_decoder(
    input  wire [31:0] inst,
    input  wire        valid,
    input  wire        if_exc_valid,
    input  wire [ 5:0] if_ecode,
    input  wire [ 8:0] if_esubcode,
    input  wire [31:0] if_badv,
    output wire [ 4:0] src1,
    output wire [ 4:0] src2,
    output wire        src1_used,
    output wire        src2_used,
    output wire [ 4:0] dest,
    output wire [25:0] imm,
    output reg  [ 2:0] EXTOP,
    output reg  [ 4:0] alu_op,
    output reg  [ 1:0] src1_sel,
    output reg         src2_sel,
    output reg  [ 3:0] br_op,
    output reg  [ 3:0] mem_op,
    output reg  [ 2:0] wb_sel,
    output reg  [ 1:0] csr_op,
    output reg  [ 1:0] counter_sel,
    output wire [13:0] csr_num,
    output wire        rf_we,
    output wire        is_load,
    output wire        is_csr,
    output wire        is_counter,
    output wire        is_muldiv,
    output wire        ertn,
    output wire        inst_valid,
    output wire        id_exc_valid,
    output wire [ 5:0] id_ecode,
    output wire [ 8:0] id_esubcode,
    output wire [31:0] id_badv
);
    wire [5:0] op_31_26 = inst[31:26];
    wire [3:0] op_25_22 = inst[25:22];
    wire [1:0] op_21_20 = inst[21:20];
    wire [4:0] op_19_15 = inst[19:15];
    wire [10:0] func11 = inst[25:15];
    wire [9:0] op_31_22 = inst[31:22];
    wire [7:0] op_31_24 = inst[31:24];
    wire [21:0] op_31_10 = inst[31:10];
    wire [4:0] rd = inst[4:0];
    wire [4:0] rj = inst[9:5];
    wire [4:0] rk = inst[14:10];

    wire i_add   = op_31_26 == 6'b000000 && func11 == 11'h020;
    wire i_sub   = op_31_26 == 6'b000000 && func11 == 11'h022;
    wire i_slt   = op_31_26 == 6'b000000 && func11 == 11'h024;
    wire i_sltu  = op_31_26 == 6'b000000 && func11 == 11'h025;
    wire i_nor   = op_31_26 == 6'b000000 && func11 == 11'h028;
    wire i_and   = op_31_26 == 6'b000000 && func11 == 11'h029;
    wire i_or    = op_31_26 == 6'b000000 && func11 == 11'h02a;
    wire i_xor   = op_31_26 == 6'b000000 && func11 == 11'h02b;
    wire i_sll   = op_31_26 == 6'b000000 && func11 == 11'h02e;
    wire i_srl   = op_31_26 == 6'b000000 && func11 == 11'h02f;
    wire i_sra   = op_31_26 == 6'b000000 && func11 == 11'h030;
    wire i_mul   = op_31_26 == 6'b000000 && func11 == 11'h038;
    wire i_mulh  = op_31_26 == 6'b000000 && func11 == 11'h039;
    wire i_mulhu = op_31_26 == 6'b000000 && func11 == 11'h03a;
    wire i_div   = op_31_26 == 6'b000000 && func11 == 11'h040;
    wire i_mod   = op_31_26 == 6'b000000 && func11 == 11'h041;
    wire i_divu  = op_31_26 == 6'b000000 && func11 == 11'h042;
    wire i_modu  = op_31_26 == 6'b000000 && func11 == 11'h043;
    wire i_slli  = op_31_26 == 6'b000000 && op_25_22 == 4'b0001 &&
                   op_21_20 == 2'b00 && op_19_15 == 5'b00001;
    wire i_srli  = op_31_26 == 6'b000000 && op_25_22 == 4'b0001 &&
                   op_21_20 == 2'b00 && op_19_15 == 5'b01001;
    wire i_srai  = op_31_26 == 6'b000000 && op_25_22 == 4'b0001 &&
                   op_21_20 == 2'b00 && op_19_15 == 5'b10001;
    wire i_addi  = op_31_22 == 10'b0000001010;
    wire i_slti  = op_31_22 == 10'b0000001000;
    wire i_sltui = op_31_22 == 10'b0000001001;
    wire i_andi  = op_31_22 == 10'b0000001101;
    wire i_ori   = op_31_22 == 10'b0000001110;
    wire i_xori  = op_31_22 == 10'b0000001111;
    wire i_lu12  = inst[31:25] == 7'b0001010;
    wire i_pcaddu = inst[31:25] == 7'b0001110;

    wire i_ldb  = op_31_22 == 10'b0010100000;
    wire i_ldh  = op_31_22 == 10'b0010100001;
    wire i_ldw  = op_31_22 == 10'b0010100010;
    wire i_stb  = op_31_22 == 10'b0010100100;
    wire i_sth  = op_31_22 == 10'b0010100101;
    wire i_stw  = op_31_22 == 10'b0010100110;
    wire i_ldbu = op_31_22 == 10'b0010101000;
    wire i_ldhu = op_31_22 == 10'b0010101001;

    wire i_beq  = op_31_26 == 6'b010110;
    wire i_bne  = op_31_26 == 6'b010111;
    wire i_blt  = op_31_26 == 6'b011000;
    wire i_bge  = op_31_26 == 6'b011001;
    wire i_bltu = op_31_26 == 6'b011010;
    wire i_bgeu = op_31_26 == 6'b011011;
    wire i_jirl = op_31_26 == 6'b010011;
    wire i_b    = op_31_26 == 6'b010100;
    wire i_bl   = op_31_26 == 6'b010101;

    wire i_csrrd = op_31_24 == 8'h04 && rj == 5'd0;
    wire i_csrwr = op_31_24 == 8'h04 && rj == 5'd1;
    wire i_csrx  = op_31_24 == 8'h04 && rj != 5'd0 && rj != 5'd1;
    wire i_sys   = inst == 32'h002b0000;
    wire i_brk   = inst == 32'h002a0000;
    wire i_ertn  = inst == 32'h06483800;
    wire i_cntl  = op_31_10 == 22'h000018 && rd != 5'd0;
    wire i_cntid = op_31_10 == 22'h000018 && rd == 5'd0;
    wire i_cnth  = op_31_10 == 22'h000019;

    wire reg_rr = i_add | i_sub | i_slt | i_sltu | i_nor | i_and |
                  i_or | i_xor | i_sll | i_srl | i_sra | i_mul |
                  i_mulh | i_mulhu | i_div | i_divu | i_mod | i_modu;
    wire imm_alu = i_slli | i_srli | i_srai | i_addi | i_slti |
                   i_sltui | i_andi | i_ori | i_xori;
    wire load = i_ldb | i_ldh | i_ldw | i_ldbu | i_ldhu;
    wire store = i_stb | i_sth | i_stw;
    wire cond_br = i_beq | i_bne | i_blt | i_bge | i_bltu | i_bgeu;

    assign inst_valid = reg_rr | imm_alu | i_lu12 | i_pcaddu | load |
                        store | cond_br | i_jirl | i_b | i_bl |
                        i_csrrd | i_csrwr | i_csrx | i_sys | i_brk |
                        i_ertn | i_cntl | i_cnth | i_cntid;
    assign src1_used = reg_rr | imm_alu | load | store | cond_br |
                       i_jirl | i_csrx;
    assign src2_used = reg_rr | store | cond_br | i_csrwr | i_csrx;
    assign src1 = rj;
    assign src2 = (store | cond_br | i_csrwr | i_csrx) ? rd : rk;
    assign dest = i_bl ? 5'd1 : i_cntid ? rj :
                  (store | cond_br | i_b | i_sys | i_brk | i_ertn) ?
                  5'd0 : rd;
    assign imm = inst[25:0];
    assign csr_num = i_cntid ? 14'h040 : inst[23:10];
    assign is_load = load;
    assign is_csr = i_csrrd | i_csrwr | i_csrx;
    assign is_counter = i_cntl | i_cnth | i_cntid;
    assign is_muldiv = i_mul | i_mulh | i_mulhu | i_div | i_divu |
                       i_mod | i_modu;
    assign ertn = i_ertn;
    assign rf_we = valid & !if_exc_valid & (reg_rr | imm_alu | i_lu12 |
                   i_pcaddu | load | is_csr | is_counter | i_bl | i_jirl);

    wire local_ine = valid & !if_exc_valid & !inst_valid;
    wire local_sys = valid & !if_exc_valid & i_sys;
    wire local_brk = valid & !if_exc_valid & i_brk;
    assign id_exc_valid = if_exc_valid | local_ine | local_sys | local_brk;
    assign id_ecode = if_exc_valid ? if_ecode : local_sys ? `ECODE_SYS :
                      local_brk ? `ECODE_BRK : local_ine ? `ECODE_INE : 6'b0;
    assign id_esubcode = if_exc_valid ? if_esubcode : 9'b0;
    assign id_badv = if_exc_valid ? if_badv : 32'b0;

    always @(*) begin
        alu_op = `ALU_ADD;
        if (i_sub) alu_op = `ALU_SUB;
        else if (i_slt | i_slti) alu_op = `ALU_SLT;
        else if (i_sltu | i_sltui) alu_op = `ALU_SLTU;
        else if (i_sll | i_slli) alu_op = `ALU_SLL;
        else if (i_srl | i_srli) alu_op = `ALU_SRL;
        else if (i_sra | i_srai) alu_op = `ALU_SRA;
        else if (i_and | i_andi) alu_op = `ALU_AND;
        else if (i_nor) alu_op = `ALU_NOR;
        else if (i_or | i_ori) alu_op = `ALU_OR;
        else if (i_xor | i_xori) alu_op = `ALU_XOR;
        else if (i_mul) alu_op = `ALU_MUL;
        else if (i_mulh) alu_op = `ALU_MULH;
        else if (i_mulhu) alu_op = `ALU_MULHU;
        else if (i_div) alu_op = `ALU_DIV;
        else if (i_divu) alu_op = `ALU_DIVU;
        else if (i_mod) alu_op = `ALU_MOD;
        else if (i_modu) alu_op = `ALU_MODU;

        src1_sel = i_lu12 ? `SRC1_ZERO : i_pcaddu ? `SRC1_PC : `SRC1_REG;
        src2_sel = (imm_alu | i_lu12 | i_pcaddu | load | store) ?
                   `SRC2_IMM : `SRC2_REG;
        EXTOP = (i_andi | i_ori | i_xori) ? `EXTOP_UI12 :
                (i_slli | i_srli | i_srai) ? `EXTOP_UI5 :
                (i_lu12 | i_pcaddu) ? `EXTOP_SI20 :
                (cond_br | i_jirl) ? `EXTOP_OFFS16 :
                (i_b | i_bl) ? `EXTOP_OFFS26 : `EXTOP_SI12;

        br_op = i_beq ? `BR_BEQ : i_bne ? `BR_BNE : i_blt ? `BR_BLT :
                i_bge ? `BR_BGE : i_bltu ? `BR_BLTU : i_bgeu ? `BR_BGEU :
                i_b ? `BR_B : i_bl ? `BR_BL : i_jirl ? `BR_JIRL : `BR_NONE;
        mem_op = i_ldb ? `MEM_LDB : i_ldh ? `MEM_LDH : i_ldw ? `MEM_LDW :
                 i_ldbu ? `MEM_LDBU : i_ldhu ? `MEM_LDHU :
                 i_stb ? `MEM_STB : i_sth ? `MEM_STH : i_stw ? `MEM_STW :
                 `MEM_NONE;
        csr_op = i_csrrd ? `CSR_READ : i_csrwr ? `CSR_WRITE :
                 i_csrx ? `CSR_XCHG : `CSR_NONE;
        counter_sel = i_cnth ? 2'd1 : i_cntid ? 2'd2 : 2'd0;
        wb_sel = load ? `WB_LOAD : (i_bl | i_jirl) ? `WB_PC4 :
                 is_csr ? `WB_CSR : i_cntl ? `WB_CNT_LOW :
                 i_cnth ? `WB_CNT_HIGH : i_cntid ? `WB_TID : `WB_EX;
    end
endmodule
