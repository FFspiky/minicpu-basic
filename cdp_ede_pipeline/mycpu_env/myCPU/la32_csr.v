`timescale 1ns / 1ps

module la32_csr(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    input  wire [ 7:0] hw_int,

    input  wire [13:0] read_addr,
    output reg  [31:0] read_data,

    input  wire        csr_we,
    input  wire [13:0] csr_waddr,
    input  wire [31:0] csr_wmask,
    input  wire [31:0] csr_wdata,

    input  wire        exc_valid,
    input  wire [31:0] exc_pc,
    input  wire [31:0] exc_badv,
    input  wire [ 5:0] exc_ecode,
    input  wire [ 8:0] exc_esubcode,
    input  wire        exc_tlbr,

    input  wire        ertn_flush,

    input  wire        tlbidx_we,
    input  wire [31:0] tlbidx_wdata,
    input  wire        tlbehi_we,
    input  wire [31:0] tlbehi_wdata,
    input  wire        tlbelo0_we,
    input  wire [31:0] tlbelo0_wdata,
    input  wire        tlbelo1_we,
    input  wire [31:0] tlbelo1_wdata,
    input  wire        asid_we,
    input  wire [31:0] asid_wdata,

    output wire        has_int,
    input  wire [63:0] stable_counter,
    output wire [31:0] ertn_pc,
    output wire [31:0] exc_entry,

    output wire [31:0] csr_crmd,
    output wire [31:0] csr_prmd,
    output wire [31:0] csr_ecfg,
    output wire [31:0] csr_estat,
    output wire [31:0] csr_era,
    output wire [31:0] csr_badv,
    output wire [31:0] csr_eentry,
    output wire [31:0] csr_tlbidx,
    output wire [31:0] csr_tlbehi,
    output wire [31:0] csr_tlbelo0,
    output wire [31:0] csr_tlbelo1,
    output wire [31:0] csr_asid,
    output wire [31:0] csr_tlbrentry,
    output wire [31:0] csr_dmw0,
    output wire [31:0] csr_dmw1
);

    localparam CSR_CRMD      = 14'h000;
    localparam CSR_PRMD      = 14'h001;
    localparam CSR_ECFG      = 14'h004;
    localparam CSR_ESTAT     = 14'h005;
    localparam CSR_ERA       = 14'h006;
    localparam CSR_BADV      = 14'h007;
    localparam CSR_EENTRY    = 14'h00c;
    localparam CSR_TLBIDX    = 14'h010;
    localparam CSR_TLBEHI    = 14'h011;
    localparam CSR_TLBELO0   = 14'h012;
    localparam CSR_TLBELO1   = 14'h013;
    localparam CSR_ASID      = 14'h018;
    localparam CSR_PGDL      = 14'h019;
    localparam CSR_PGDH      = 14'h01a;
    localparam CSR_PGD       = 14'h01b;
    localparam CSR_CPUID     = 14'h020;
    localparam CSR_SAVE0     = 14'h030;
    localparam CSR_SAVE1     = 14'h031;
    localparam CSR_SAVE2     = 14'h032;
    localparam CSR_SAVE3     = 14'h033;
    localparam CSR_TID       = 14'h040;
    localparam CSR_TCFG      = 14'h041;
    localparam CSR_TVAL      = 14'h042;
    localparam CSR_TICLR     = 14'h044;
    localparam CSR_TLBRENTRY = 14'h088;
    localparam CSR_DMW0      = 14'h180;
    localparam CSR_DMW1      = 14'h181;

    localparam ECODE_PIL  = 6'h01;
    localparam ECODE_PIS  = 6'h02;
    localparam ECODE_PIF  = 6'h03;
    localparam ECODE_PME  = 6'h04;
    localparam ECODE_PPI  = 6'h07;
    localparam ECODE_ADE  = 6'h08;
    localparam ECODE_ALE  = 6'h09;
    localparam ECODE_TLBR = 6'h3f;

    reg [31:0] crmd;
    reg [31:0] prmd;
    reg [31:0] ecfg;
    reg [31:0] estat;
    reg [31:0] era;
    reg [31:0] badv;
    reg [31:0] eentry;
    reg [31:0] tlbidx;
    reg [31:0] tlbehi;
    reg [31:0] tlbelo0;
    reg [31:0] tlbelo1;
    reg [31:0] asid;
    reg [31:0] pgdl;
    reg [31:0] pgdh;
    reg [31:0] save0;
    reg [31:0] save1;
    reg [31:0] save2;
    reg [31:0] save3;
    reg [31:0] tid;
    reg [31:0] tcfg;
    reg [31:0] tval;
    reg        timer_fired;
    reg [31:0] tlbrentry;
    reg [31:0] dmw0;
    reg [31:0] dmw1;

    wire timer_en       = tcfg[0];
    wire timer_periodic = tcfg[1];
    wire [31:0] timer_init = {tcfg[31:2], 2'b0};
    wire [12:0] int_vec = estat[12:0] & ecfg[12:0];

    assign has_int = crmd[2] & (|int_vec);
    assign ertn_pc = era;
    assign exc_entry = exc_tlbr ? tlbrentry : eentry;

    assign csr_crmd      = crmd;
    assign csr_prmd      = prmd;
    assign csr_ecfg      = ecfg;
    assign csr_estat     = estat;
    assign csr_era       = era;
    assign csr_badv      = badv;
    assign csr_eentry    = eentry;
    assign csr_tlbidx    = tlbidx;
    assign csr_tlbehi    = tlbehi;
    assign csr_tlbelo0   = tlbelo0;
    assign csr_tlbelo1   = tlbelo1;
    assign csr_asid      = asid;
    assign csr_tlbrentry = tlbrentry;
    assign csr_dmw0      = dmw0;
    assign csr_dmw1      = dmw1;

    function [31:0] masked_write;
        input [31:0] old_v;
        input [31:0] mask_v;
        input [31:0] new_v;
        begin
            masked_write = (old_v & ~mask_v) | (new_v & mask_v);
        end
    endfunction

    wire [31:0] estat_sw_next = masked_write({30'b0, estat[1:0]}, csr_wmask, csr_wdata);
    wire [31:0] tcfg_next     = masked_write(tcfg, csr_wmask, csr_wdata);

    always @(*) begin
        case (read_addr)
            CSR_CRMD:      read_data = crmd;
            CSR_PRMD:      read_data = prmd;
            CSR_ECFG:      read_data = ecfg;
            CSR_ESTAT:     read_data = estat;
            CSR_ERA:       read_data = era;
            CSR_BADV:      read_data = badv;
            CSR_EENTRY:    read_data = eentry;
            CSR_TLBIDX:    read_data = tlbidx;
            CSR_TLBEHI:    read_data = tlbehi;
            CSR_TLBELO0:   read_data = tlbelo0;
            CSR_TLBELO1:   read_data = tlbelo1;
            CSR_ASID:      read_data = asid;
            CSR_PGDL:      read_data = pgdl;
            CSR_PGDH:      read_data = pgdh;
            CSR_PGD:       read_data = badv[31] ? pgdh : pgdl;
            CSR_CPUID:     read_data = 32'b0;
            CSR_SAVE0:     read_data = save0;
            CSR_SAVE1:     read_data = save1;
            CSR_SAVE2:     read_data = save2;
            CSR_SAVE3:     read_data = save3;
            CSR_TID:       read_data = tid;
            CSR_TCFG:      read_data = tcfg;
            CSR_TVAL:      read_data = tval;
            CSR_TICLR:     read_data = 32'b0;
            CSR_TLBRENTRY: read_data = tlbrentry;
            CSR_DMW0:      read_data = dmw0;
            CSR_DMW1:      read_data = dmw1;
            default:       read_data = 32'b0;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            crmd           <= 32'h00000008;
            prmd           <= 32'b0;
            ecfg           <= 32'b0;
            estat          <= 32'b0;
            era            <= 32'b0;
            badv           <= 32'b0;
            eentry         <= 32'b0;
            tlbidx         <= 32'h80000000;
            tlbehi         <= 32'b0;
            tlbelo0        <= 32'b0;
            tlbelo1        <= 32'b0;
            asid           <= 32'h000a0000;
            pgdl           <= 32'b0;
            pgdh           <= 32'b0;
            save0          <= 32'b0;
            save1          <= 32'b0;
            save2          <= 32'b0;
            save3          <= 32'b0;
            tid            <= 32'b0;
            tcfg           <= 32'b0;
            tval           <= 32'b0;
            timer_fired    <= 1'b0;
            tlbrentry      <= 32'b0;
            dmw0           <= 32'b0;
            dmw1           <= 32'b0;
        end
        else if (cpu_en) begin
            estat[9:2] <= hw_int;

            if (timer_en && !timer_fired) begin
                if (tval == 32'b0) begin
                    estat[11] <= 1'b1;
                    if (timer_periodic) begin
                        tval <= timer_init;
                    end
                    else begin
                        timer_fired <= 1'b1;
                    end
                end
                else begin
                    tval <= tval - 32'd1;
                end
            end

            if (csr_we) begin
                case (csr_waddr)
                    CSR_CRMD:      crmd <= masked_write(crmd, csr_wmask, csr_wdata);
                    CSR_PRMD:      prmd <= masked_write(prmd, csr_wmask, csr_wdata);
                    CSR_ECFG:      ecfg <= masked_write(ecfg, csr_wmask, csr_wdata) & 32'h00001bff;
                    CSR_ESTAT: begin
                        estat[1:0] <= estat_sw_next[1:0];
                    end
                    CSR_ERA:       era <= masked_write(era, csr_wmask, csr_wdata);
                    CSR_BADV:      badv <= masked_write(badv, csr_wmask, csr_wdata);
                    CSR_EENTRY:    eentry <= masked_write(eentry, csr_wmask, csr_wdata);
                    CSR_TLBIDX:    tlbidx <= masked_write(tlbidx, csr_wmask, csr_wdata);
                    CSR_TLBEHI:    tlbehi <= masked_write(tlbehi, csr_wmask, csr_wdata) & 32'hffffe000;
                    CSR_TLBELO0:   tlbelo0 <= masked_write(tlbelo0, csr_wmask, csr_wdata);
                    CSR_TLBELO1:   tlbelo1 <= masked_write(tlbelo1, csr_wmask, csr_wdata);
                    CSR_ASID:      asid <= (masked_write(asid, csr_wmask & 32'h000003ff, csr_wdata) & 32'h000003ff) |
                                           32'h000a0000;
                    CSR_PGDL:      pgdl <= masked_write(pgdl, csr_wmask, csr_wdata);
                    CSR_PGDH:      pgdh <= masked_write(pgdh, csr_wmask, csr_wdata);
                    CSR_SAVE0:     save0 <= masked_write(save0, csr_wmask, csr_wdata);
                    CSR_SAVE1:     save1 <= masked_write(save1, csr_wmask, csr_wdata);
                    CSR_SAVE2:     save2 <= masked_write(save2, csr_wmask, csr_wdata);
                    CSR_SAVE3:     save3 <= masked_write(save3, csr_wmask, csr_wdata);
                    CSR_TID:       tid <= masked_write(tid, csr_wmask, csr_wdata);
                    CSR_TCFG: begin
                        tcfg <= tcfg_next;
                        timer_fired <= 1'b0;
                        if (csr_wmask[0]) begin
                            tval <= {tcfg_next[31:2], 2'b0};
                        end
                    end
                    CSR_TICLR: begin
                        if (csr_wdata[0]) begin
                            estat[11] <= 1'b0;
                        end
                    end
                    CSR_TLBRENTRY: tlbrentry <= masked_write(tlbrentry, csr_wmask, csr_wdata);
                    CSR_DMW0:      dmw0 <= masked_write(dmw0, csr_wmask, csr_wdata);
                    CSR_DMW1:      dmw1 <= masked_write(dmw1, csr_wmask, csr_wdata);
                    default: begin end
                endcase
            end

            if (tlbidx_we) begin
                tlbidx <= tlbidx_wdata;
            end
            if (tlbehi_we) begin
                tlbehi <= tlbehi_wdata & 32'hffffe000;
            end
            if (tlbelo0_we) begin
                tlbelo0 <= tlbelo0_wdata;
            end
            if (tlbelo1_we) begin
                tlbelo1 <= tlbelo1_wdata;
            end
            if (asid_we) begin
                asid <= (asid_wdata & 32'h000003ff) | 32'h000a0000;
            end

            if (ertn_flush) begin
                crmd[1:0] <= prmd[1:0];
                crmd[2]   <= prmd[2];
                if (estat[21:16] == ECODE_TLBR) begin
                    crmd[3] <= 1'b0;
                    crmd[4] <= 1'b1;
                end
            end

            if (exc_valid) begin
                era          <= exc_pc;
                estat[21:16] <= exc_ecode;
                estat[30:22] <= exc_esubcode;
                prmd[1:0]    <= crmd[1:0];
                prmd[2]      <= crmd[2];
                crmd[1:0]    <= 2'b0;
                crmd[2]      <= 1'b0;
                if (exc_tlbr) begin
                    crmd[3] <= 1'b1;
                    crmd[4] <= 1'b0;
                end
                if (exc_ecode == ECODE_TLBR || exc_ecode == ECODE_PIL ||
                    exc_ecode == ECODE_PIS || exc_ecode == ECODE_PIF ||
                    exc_ecode == ECODE_PME || exc_ecode == ECODE_PPI ||
                    exc_ecode == ECODE_ADE || exc_ecode == ECODE_ALE) begin
                    badv <= exc_badv;
                end
                if (exc_ecode == ECODE_TLBR || exc_ecode == ECODE_PIL ||
                    exc_ecode == ECODE_PIS || exc_ecode == ECODE_PIF ||
                    exc_ecode == ECODE_PME || exc_ecode == ECODE_PPI) begin
                    tlbehi[31:13] <= exc_badv[31:13];
                    tlbehi[12:0]  <= 13'b0;
                end
            end
        end
    end

endmodule
