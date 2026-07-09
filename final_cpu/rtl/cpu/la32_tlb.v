`timescale 1ns / 1ps

module la32_tlb(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,

    input  wire [31:0] csr_tlbidx,
    input  wire [31:0] csr_tlbehi,
    input  wire [31:0] csr_tlbelo0,
    input  wire [31:0] csr_tlbelo1,
    input  wire [31:0] csr_asid,

    input  wire [31:0] trans_va,
    output reg         trans_hit,
    output reg  [ 3:0] trans_index,
    output reg  [ 5:0] trans_ps,
    output reg  [31:0] trans_elo,

    output reg         srch_hit,
    output reg  [ 3:0] srch_index,

    output wire [31:0] tlbrd_tlbidx,
    output wire [31:0] tlbrd_tlbehi,
    output wire [31:0] tlbrd_tlbelo0,
    output wire [31:0] tlbrd_tlbelo1,
    output wire [31:0] tlbrd_asid,

    input  wire        op_tlbwr,
    input  wire        op_tlbfill,
    input  wire        op_invtlb,
    input  wire [ 4:0] invtlb_op,
    input  wire [31:0] invtlb_asid,
    input  wire [31:0] invtlb_va
);

    integer i;

    reg        tlb_e    [0:15];
    reg [18:0] tlb_vppn [0:15];
    reg [ 5:0] tlb_ps   [0:15];
    reg [ 9:0] tlb_asid [0:15];
    reg [31:0] tlb_elo0 [0:15];
    reg [31:0] tlb_elo1 [0:15];
    reg [ 3:0] fill_idx;

    wire [3:0] rd_idx = csr_tlbidx[3:0];
    wire       rd_valid = tlb_e[rd_idx];
    wire [5:0] wr_ps = (csr_tlbidx[29:24] == 6'b0) ? 6'd12 : csr_tlbidx[29:24];

    assign tlbrd_tlbidx  = rd_valid ? {2'b00, tlb_ps[rd_idx], 20'b0, rd_idx} :
                            (32'h80000000 | {28'b0, rd_idx});
    assign tlbrd_tlbehi  = rd_valid ? {tlb_vppn[rd_idx], 13'b0} : 32'b0;
    assign tlbrd_tlbelo0 = rd_valid ? tlb_elo0[rd_idx] : 32'b0;
    assign tlbrd_tlbelo1 = rd_valid ? tlb_elo1[rd_idx] : 32'b0;
    assign tlbrd_asid    = rd_valid ? {22'b0, tlb_asid[rd_idx]} : 32'b0;

    function match_vppn;
        input [31:0] va;
        input [18:0] entry_vppn;
        input [5:0]  entry_ps;
        begin
            if (entry_ps == 6'd22) begin
                match_vppn = va[31:22] == entry_vppn[18:9];
            end
            else begin
                match_vppn = va[31:13] == entry_vppn;
            end
        end
    endfunction

    function match_asid;
        input [31:0] elo0;
        input [31:0] elo1;
        input [9:0]  entry_asid;
        input [9:0]  use_asid;
        begin
            match_asid = (elo0[6] & elo1[6]) | (entry_asid == use_asid);
        end
    endfunction

    wire [9:0] use_asid = csr_asid[9:0];

    always @(*) begin
        trans_hit   = 1'b0;
        trans_index = 4'b0;
        trans_ps    = 6'd12;
        trans_elo   = 32'b0;
        for (i = 0; i < 16; i = i + 1) begin
            if (!trans_hit && tlb_e[i] &&
                match_vppn(trans_va, tlb_vppn[i], tlb_ps[i]) &&
                match_asid(tlb_elo0[i], tlb_elo1[i], tlb_asid[i], use_asid)) begin
                trans_hit   = 1'b1;
                trans_index = i[3:0];
                trans_ps    = tlb_ps[i];
                trans_elo   = ((tlb_ps[i] == 6'd22) ? trans_va[21] : trans_va[12]) ?
                              tlb_elo1[i] : tlb_elo0[i];
            end
        end
    end

    always @(*) begin
        srch_hit   = 1'b0;
        srch_index = 4'b0;
        for (i = 0; i < 16; i = i + 1) begin
            if (!srch_hit && tlb_e[i] &&
                match_vppn(csr_tlbehi, tlb_vppn[i], tlb_ps[i]) &&
                match_asid(tlb_elo0[i], tlb_elo1[i], tlb_asid[i], use_asid)) begin
                srch_hit   = 1'b1;
                srch_index = i[3:0];
            end
        end
    end

    task write_entry;
        input [3:0] index;
        begin
            if (csr_tlbidx[31]) begin
                tlb_e[index] <= 1'b0;
            end
            else begin
                tlb_e[index]    <= 1'b1;
                tlb_vppn[index] <= csr_tlbehi[31:13];
                tlb_ps[index]   <= wr_ps;
                tlb_asid[index] <= csr_asid[9:0];
                tlb_elo0[index] <= csr_tlbelo0;
                tlb_elo1[index] <= csr_tlbelo1;
            end
        end
    endtask

    function inv_match;
        input [4:0]  op;
        input [31:0] va;
        input [31:0] asid_v;
        input [3:0]  index;
        reg          g;
        reg          vpn_hit;
        reg          asid_hit;
        begin
            g        = tlb_elo0[index][6] & tlb_elo1[index][6];
            vpn_hit  = match_vppn(va, tlb_vppn[index], tlb_ps[index]);
            asid_hit = tlb_asid[index] == asid_v[9:0];
            case (op)
                5'h0: inv_match = 1'b1;
                5'h1: inv_match = 1'b1;
                5'h2: inv_match = g;
                5'h3: inv_match = ~g;
                5'h4: inv_match = ~g & asid_hit;
                5'h5: inv_match = ~g & asid_hit & vpn_hit;
                5'h6: inv_match = (g | asid_hit) & vpn_hit;
                default: inv_match = 1'b0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (!resetn) begin
            fill_idx <= 4'b0;
            for (i = 0; i < 16; i = i + 1) begin
                tlb_e[i]    <= 1'b0;
                tlb_vppn[i] <= 19'b0;
                tlb_ps[i]   <= 6'd12;
                tlb_asid[i] <= 10'b0;
                tlb_elo0[i] <= 32'b0;
                tlb_elo1[i] <= 32'b0;
            end
        end
        else if (cpu_en) begin
            if (op_tlbwr) begin
                write_entry(csr_tlbidx[3:0]);
            end
            if (op_tlbfill) begin
                write_entry(fill_idx);
                fill_idx <= fill_idx + 4'd1;
            end
            if (op_invtlb) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (tlb_e[i] && inv_match(invtlb_op, invtlb_va, invtlb_asid, i[3:0])) begin
                        tlb_e[i] <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
