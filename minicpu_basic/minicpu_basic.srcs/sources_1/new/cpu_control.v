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
    output sel_alu_src1,
    output [2:0] sel_alu_src2,
    output data_ram_we,
    output rf_we,
    output [1:0] sel_rf_res,
    output sel_rf_dst,
    output [11:0] alu_op
);

    assign sel_rf_ra2   = inst_st_w | inst_bne | inst_beq;
    assign sel_alu_src1 = inst_bl | inst_jirl;
    assign sel_alu_src2 = (inst_addi_w | inst_ld_w | inst_st_w) ? 3'b001 :
                          (inst_slli_w | inst_srli_w | inst_srai_w) ? 3'b010 :
                          (inst_bl | inst_jirl) ? 3'b011 :
                          inst_lu12i_w ? 3'b100 :
                          3'b000;
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

    assign sel_rf_res = inst_ld_w ? 2'b01 :
                        (inst_bl | inst_jirl) ? 2'b10 :
                        2'b00;

    assign sel_rf_dst = inst_bl;

    assign alu_op[0]  = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_bl | inst_jirl;
    assign alu_op[1]  = inst_sub_w;
    assign alu_op[2]  = inst_slt;
    assign alu_op[3]  = inst_sltu;
    assign alu_op[4]  = inst_and;
    assign alu_op[5]  = inst_nor;
    assign alu_op[6]  = inst_or;
    assign alu_op[7]  = inst_xor;
    assign alu_op[8]  = inst_slli_w;
    assign alu_op[9]  = inst_srli_w;
    assign alu_op[10] = inst_srai_w;
    assign alu_op[11] = inst_lu12i_w;

endmodule
