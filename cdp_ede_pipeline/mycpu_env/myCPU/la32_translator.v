`timescale 1ns / 1ps

module la32_translator(
    input  wire [31:0] va,
    input  wire        is_fetch,
    input  wire        is_store,
    input  wire [31:0] csr_crmd,
    input  wire [31:0] csr_dmw0,
    input  wire [31:0] csr_dmw1,
    input  wire        tlb_hit,
    input  wire [ 5:0] tlb_ps,
    input  wire [31:0] tlb_elo,
    output reg  [31:0] pa,
    output reg         exc_valid,
    output reg  [ 5:0] exc_ecode,
    output reg  [ 8:0] exc_esubcode,
    output reg         exc_tlbr
);

    localparam ECODE_PIL  = 6'h01;
    localparam ECODE_PIS  = 6'h02;
    localparam ECODE_PIF  = 6'h03;
    localparam ECODE_PME  = 6'h04;
    localparam ECODE_PPI  = 6'h07;
    localparam ECODE_ADE  = 6'h08;
    localparam ECODE_TLBR = 6'h3f;

    wire [1:0] plv = csr_crmd[1:0];
    wire       da  = csr_crmd[3];
    wire       pg  = csr_crmd[4];

    wire dmw0_plv_ok = (plv == 2'd0 && csr_dmw0[0]) || (plv == 2'd3 && csr_dmw0[3]);
    wire dmw1_plv_ok = (plv == 2'd0 && csr_dmw1[0]) || (plv == 2'd3 && csr_dmw1[3]);
    wire dmw0_hit = pg && dmw0_plv_ok && va[31:29] == csr_dmw0[31:29];
    wire dmw1_hit = pg && dmw1_plv_ok && va[31:29] == csr_dmw1[31:29];

    always @(*) begin
        pa           = va;
        exc_valid    = 1'b0;
        exc_ecode    = 6'b0;
        exc_esubcode = 9'b0;
        exc_tlbr     = 1'b0;

        if (is_fetch && |va[1:0]) begin
            exc_valid    = 1'b1;
            exc_ecode    = ECODE_ADE;
            exc_esubcode = 9'b0;
        end
        else if (da && !pg) begin
            pa = va;
        end
        else if (dmw0_hit) begin
            pa = {csr_dmw0[27:25], va[28:0]};
        end
        else if (dmw1_hit) begin
            pa = {csr_dmw1[27:25], va[28:0]};
        end
        else if (!tlb_hit) begin
            exc_valid = 1'b1;
            exc_ecode = ECODE_TLBR;
            exc_tlbr  = 1'b1;
        end
        else if (!tlb_elo[0]) begin
            exc_valid = 1'b1;
            exc_ecode = is_fetch ? ECODE_PIF : (is_store ? ECODE_PIS : ECODE_PIL);
        end
        else if (plv > tlb_elo[3:2]) begin
            exc_valid = 1'b1;
            exc_ecode = ECODE_PPI;
        end
        else if (is_store && !tlb_elo[1]) begin
            exc_valid = 1'b1;
            exc_ecode = ECODE_PME;
        end
        else if (tlb_ps == 6'd22) begin
            pa = {tlb_elo[27:18], va[21:0]};
        end
        else begin
            pa = {tlb_elo[27:8], va[11:0]};
        end
    end

endmodule
