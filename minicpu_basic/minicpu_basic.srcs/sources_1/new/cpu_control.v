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

    output sel_rf_ra2,
    output sel_alu_src2,
    output data_ram_we,
    output rf_we,
    output sel_rf_res,
    output [2:0] alu_op
);

    assign sel_rf_ra2   = inst_st_w | inst_bne;
    assign sel_alu_src2 = inst_addi_w | inst_ld_w | inst_st_w;
    assign data_ram_we  = inst_st_w;

    assign rf_we = inst_add_w  |
                   inst_addi_w |
                   inst_ld_w   |
                   inst_sub_w  |
                   inst_and    |
                   inst_or;

    assign sel_rf_res = inst_ld_w;

    assign alu_op = inst_sub_w ? 3'b001 :
                    inst_and   ? 3'b100 :
                    inst_or    ? 3'b101 :
                                  3'b000;

endmodule
