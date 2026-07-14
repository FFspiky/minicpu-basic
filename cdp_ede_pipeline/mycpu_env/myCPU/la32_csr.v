`timescale 1ns / 1ps

// CSR register set required by the EXP16 instruction and exception table.
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
    input  wire        ertn_flush,

    output wire        has_int,
    output wire [31:0] ertn_pc,
    output wire [31:0] exc_entry,
    output wire [31:0] csr_crmd,
    output wire [31:0] csr_prmd,
    output wire [31:0] csr_ecfg,
    output wire [31:0] csr_estat,
    output wire [31:0] csr_era,
    output wire [31:0] csr_badv,
    output wire [31:0] csr_eentry
);

    localparam CSR_CRMD   = 14'h000;
    localparam CSR_PRMD   = 14'h001;
    localparam CSR_ECFG   = 14'h004;
    localparam CSR_ESTAT  = 14'h005;
    localparam CSR_ERA    = 14'h006;
    localparam CSR_BADV   = 14'h007;
    localparam CSR_EENTRY = 14'h00c;
    localparam CSR_SAVE0  = 14'h030;
    localparam CSR_SAVE1  = 14'h031;
    localparam CSR_SAVE2  = 14'h032;
    localparam CSR_SAVE3  = 14'h033;
    localparam CSR_TID    = 14'h040;
    localparam CSR_TCFG   = 14'h041;
    localparam CSR_TVAL   = 14'h042;
    localparam CSR_TICLR  = 14'h044;

    localparam ECODE_ADE = 6'h08;
    localparam ECODE_ALE = 6'h09;

    reg [31:0] crmd;
    reg [31:0] prmd;
    reg [31:0] ecfg;
    reg [31:0] estat;
    reg [31:0] era;
    reg [31:0] badv;
    reg [31:0] eentry;
    reg [31:0] save0;
    reg [31:0] save1;
    reg [31:0] save2;
    reg [31:0] save3;
    reg [31:0] tid;
    reg [31:0] tcfg;
    reg [31:0] tval;
    reg        timer_fired;

    function [31:0] masked_write;
        input [31:0] old_v;
        input [31:0] mask_v;
        input [31:0] new_v;
        begin
            masked_write = (old_v & ~mask_v) | (new_v & mask_v);
        end
    endfunction

    wire [31:0] crmd_next = masked_write(crmd, csr_wmask, csr_wdata);
    wire [31:0] prmd_next = masked_write(prmd, csr_wmask, csr_wdata);
    wire [31:0] estat_next = masked_write(estat, csr_wmask, csr_wdata);
    wire [31:0] tcfg_next = masked_write(tcfg, csr_wmask, csr_wdata);
    wire [12:0] pending_int = estat[12:0] & ecfg[12:0];

    assign has_int    = crmd[2] & (|pending_int);
    assign ertn_pc    = era;
    assign exc_entry  = eentry;
    assign csr_crmd   = crmd;
    assign csr_prmd   = prmd;
    assign csr_ecfg   = ecfg;
    assign csr_estat  = estat;
    assign csr_era    = era;
    assign csr_badv   = badv;
    assign csr_eentry = eentry;

    always @(*) begin
        case (read_addr)
            CSR_CRMD:   read_data = crmd;
            CSR_PRMD:   read_data = prmd;
            CSR_ECFG:   read_data = ecfg;
            CSR_ESTAT:  read_data = estat;
            CSR_ERA:    read_data = era;
            CSR_BADV:   read_data = badv;
            CSR_EENTRY: read_data = eentry;
            CSR_SAVE0:  read_data = save0;
            CSR_SAVE1:  read_data = save1;
            CSR_SAVE2:  read_data = save2;
            CSR_SAVE3:  read_data = save3;
            CSR_TID:    read_data = tid;
            CSR_TCFG:   read_data = tcfg;
            CSR_TVAL:   read_data = tval;
            CSR_TICLR:  read_data = 32'b0;
            default:    read_data = 32'b0;
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            crmd        <= 32'h00000008; // direct-address mode, PLV0, IE=0
            prmd        <= 32'b0;
            ecfg        <= 32'b0;
            estat       <= 32'b0;
            era         <= 32'b0;
            badv        <= 32'b0;
            eentry      <= 32'b0;
            save0       <= 32'b0;
            save1       <= 32'b0;
            save2       <= 32'b0;
            save3       <= 32'b0;
            tid         <= 32'b0;
            tcfg        <= 32'b0;
            tval        <= 32'b0;
            timer_fired <= 1'b0;
        end
        else if (cpu_en) begin
            estat[9:2] <= hw_int;

            if (tcfg[0] && !timer_fired) begin
                if (tval == 32'b0) begin
                    estat[11] <= 1'b1;
                    if (tcfg[1])
                        tval <= {tcfg[31:2], 2'b0};
                    else
                        timer_fired <= 1'b1;
                end
                else begin
                    tval <= tval - 32'd1;
                end
            end

            if (csr_we) begin
                case (csr_waddr)
                    CSR_CRMD: begin
                        crmd[2:0] <= crmd_next[2:0];
                        crmd[3]   <= 1'b1;
                    end
                    CSR_PRMD:   prmd[2:0] <= prmd_next[2:0];
                    CSR_ECFG:   ecfg <= masked_write(ecfg, csr_wmask, csr_wdata) & 32'h00001bff;
                    CSR_ESTAT:  estat[1:0] <= estat_next[1:0];
                    CSR_ERA:    era <= masked_write(era, csr_wmask, csr_wdata);
                    CSR_BADV:   badv <= masked_write(badv, csr_wmask, csr_wdata);
                    CSR_EENTRY: eentry <= masked_write(eentry, csr_wmask, csr_wdata) & 32'hffffffc0;
                    CSR_SAVE0:  save0 <= masked_write(save0, csr_wmask, csr_wdata);
                    CSR_SAVE1:  save1 <= masked_write(save1, csr_wmask, csr_wdata);
                    CSR_SAVE2:  save2 <= masked_write(save2, csr_wmask, csr_wdata);
                    CSR_SAVE3:  save3 <= masked_write(save3, csr_wmask, csr_wdata);
                    CSR_TID:    tid <= masked_write(tid, csr_wmask, csr_wdata);
                    CSR_TCFG: begin
                        tcfg <= tcfg_next;
                        if (tcfg_next[0]) begin
                            tval        <= {tcfg_next[31:2], 2'b0};
                            timer_fired <= 1'b0;
                        end
                    end
                    CSR_TICLR: begin
                        if (csr_wmask[0] && csr_wdata[0])
                            estat[11] <= 1'b0;
                    end
                    default: begin end
                endcase
            end

            if (exc_valid) begin
                prmd[1:0]    <= crmd[1:0];
                prmd[2]      <= crmd[2];
                crmd[1:0]    <= 2'b0;
                crmd[2]      <= 1'b0;
                crmd[3]      <= 1'b1;
                estat[21:16] <= exc_ecode;
                estat[30:22] <= exc_esubcode;
                era          <= exc_pc;
                if (exc_ecode == ECODE_ADE || exc_ecode == ECODE_ALE)
                    badv <= exc_badv;
            end
            else if (ertn_flush) begin
                crmd[1:0] <= prmd[1:0];
                crmd[2]   <= prmd[2];
                crmd[3]   <= 1'b1;
            end
        end
    end

endmodule
