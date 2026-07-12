`timescale 1ns / 1ps

module la32_wb_select(
    input  wire        select_load,
    input  wire [31:0] ex_result,
    input  wire [31:0] load_result,
    output wire [31:0] wb_data
);
    assign wb_data = select_load ? load_result : ex_result;
endmodule
