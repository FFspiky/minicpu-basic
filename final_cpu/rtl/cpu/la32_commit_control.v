`timescale 1ns / 1ps

module la32_commit_control(
    input  wire ws_valid,
    input  wire ws_exception,
    input  wire ws_ertn,
    input  wire ws_rf_we,
    input  wire [4:0] ws_rf_waddr,
    input  wire ws_csr_we,
    input  wire ws_tlbidx_we,
    input  wire ws_tlbehi_we,
    input  wire ws_tlbelo0_we,
    input  wire ws_tlbelo1_we,
    input  wire ws_asid_we,
    input  wire ws_tlbwr,
    input  wire ws_tlbfill,
    input  wire ws_invtlb,
    output wire rf_we,
    output wire csr_we,
    output wire tlbidx_we,
    output wire tlbehi_we,
    output wire tlbelo0_we,
    output wire tlbelo1_we,
    output wire asid_we,
    output wire tlbwr,
    output wire tlbfill,
    output wire invtlb
);

    wire normal_commit = ws_valid & !ws_exception & !ws_ertn;
    assign rf_we     = normal_commit & ws_rf_we & (ws_rf_waddr != 5'b0);
    assign csr_we    = normal_commit & ws_csr_we;
    assign tlbidx_we = normal_commit & ws_tlbidx_we;
    assign tlbehi_we = normal_commit & ws_tlbehi_we;
    assign tlbelo0_we = normal_commit & ws_tlbelo0_we;
    assign tlbelo1_we = normal_commit & ws_tlbelo1_we;
    assign asid_we   = normal_commit & ws_asid_we;
    assign tlbwr     = normal_commit & ws_tlbwr;
    assign tlbfill   = normal_commit & ws_tlbfill;
    assign invtlb    = normal_commit & ws_invtlb;

endmodule
