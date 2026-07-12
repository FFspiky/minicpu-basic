`timescale 1ns / 1ps

module cpu_control(
    input  inst_add_w,
    input  inst_addi_w,
    input  inst_ld_w,
    input  inst_st_w,
    input  inst_bne,
    input  inst_sub_w,
    input  inst_and,
    input  inst_or,
    input  inst_beq,
    input  inst_b,
    input  inst_bl,
    input  inst_jirl,
    input  inst_slt,
    input  inst_sltu,
    input  inst_slli_w,
    input  inst_srli_w,
    input  inst_srai_w,
    input  inst_lu12i_w,
    input  inst_nor,
    input  inst_xor,

    output sel_rf_ra2,
    output sel_alu_src2,
    output data_ram_we,
    output rf_we,
    output [2:0] ext_op,
    output [1:0] sel_rf_res,
    output sel_rf_dst,
    output [3:0] alu_op,
    output br_en,
    output br_op,
    output sel_nextpc,
    output inst_ram_we,
    output inst_ram_ce,
    output data_ram_ce,
    output jirl_sel
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

    wire inst_r2_from_rk;

    assign inst_r2_from_rk = inst_add_w |
                             inst_addi_w |
                             inst_sub_w |
                             inst_slt   |
                             inst_sltu  |
                             inst_and   |
                             inst_or    |
                             inst_nor   |
                             inst_xor;

    assign sel_rf_ra2   = inst_r2_from_rk;
    assign sel_alu_src2 = inst_addi_w |
                          inst_ld_w   |
                          inst_st_w   |
                          inst_slli_w |
                          inst_srli_w |
                          inst_srai_w;
    assign data_ram_we  = inst_st_w;

    assign rf_we = inst_add_w  |
                   inst_addi_w |
                   inst_ld_w   |
                   inst_sub_w  |
                   inst_and    |
                   inst_or     |
                   inst_slt    |
                   inst_sltu   |
                   inst_slli_w |
                   inst_srli_w |
                   inst_srai_w |
                   inst_lu12i_w|
                   inst_nor    |
                   inst_xor    |
                   inst_bl     |
                   inst_jirl;

    assign ext_op = (inst_addi_w | inst_ld_w | inst_st_w) ? EXT_SI12 :
                    (inst_slli_w | inst_srli_w | inst_srai_w) ? EXT_UI5 :
                    (inst_beq | inst_bne | inst_jirl) ? EXT_BR16 :
                    (inst_b | inst_bl) ? EXT_BR26 :
                    inst_lu12i_w ? EXT_SI20 :
                    EXT_NONE;

    assign sel_rf_res = inst_ld_w ? 2'b00 :
                        inst_lu12i_w ? 2'b10 :
                        (inst_bl | inst_jirl) ? 2'b11 :
                        2'b01;

    assign sel_rf_dst = ~inst_bl;

    assign alu_op = (inst_sub_w | inst_beq | inst_bne) ? ALU_SUB  :
                    inst_slt    ? ALU_SLT  :
                    inst_sltu   ? ALU_SLTU :
                    inst_slli_w ? ALU_SLL  :
                    inst_srli_w ? ALU_SRL  :
                    inst_srai_w ? ALU_SRA  :
                    inst_and    ? ALU_AND  :
                    inst_nor    ? ALU_NOR  :
                    inst_or     ? ALU_OR   :
                    inst_xor    ? ALU_XOR  :
                    ALU_ADD;

    assign br_en      = inst_beq | inst_bne | inst_b | inst_bl | inst_jirl;
    assign br_op      = inst_bne;
    assign sel_nextpc = inst_beq | inst_bne;
    assign jirl_sel   = ~inst_jirl;

    assign inst_ram_we = 1'b0;
    assign inst_ram_ce = 1'b1;
    assign data_ram_ce = inst_ld_w | inst_st_w;

endmodule
