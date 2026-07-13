`timescale 1ns / 1ps
`include "la32_defs.vh"

module la32_wb_select(
    input wire valid, input wire exception, input wire ertn,
    input wire rf_we_in, input wire [4:0] dest, input wire [2:0] wb_sel,
    input wire [31:0] ex_result, input wire [31:0] load_result,
    input wire [31:0] pc_plus4, input wire [31:0] csr_old_value,
    input wire [63:0] stable_counter, input wire [31:0] csr_tid,
    input wire csr_we_in,
    output reg [31:0] wb_data, output wire rf_we_final,
    output wire csr_we_final, output wire wb_forward_valid
);
    always @(*) begin
        case (wb_sel)
            `WB_LOAD: wb_data = load_result;
            `WB_PC4: wb_data = pc_plus4;
            `WB_CSR: wb_data = csr_old_value;
            `WB_CNT_LOW: wb_data = stable_counter[31:0];
            `WB_CNT_HIGH: wb_data = stable_counter[63:32];
            `WB_TID: wb_data = csr_tid;
            default: wb_data = ex_result;
        endcase
    end
    wire commit = valid && !exception && !ertn;
    assign rf_we_final = commit && rf_we_in && (dest != 0);
    assign csr_we_final = commit && csr_we_in;
    assign wb_forward_valid = rf_we_final;
endmodule
