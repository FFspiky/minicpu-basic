`timescale 1ns / 1ps

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,

    output wire        inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    output wire        data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    output reg  [31:0] debug_wb_pc,
    output reg  [ 3:0] debug_wb_rf_we,
    output reg  [ 4:0] debug_wb_rf_wnum,
    output reg  [31:0] debug_wb_rf_wdata
);

    localparam RESET_PC = 32'h1bfffffc;

    reg         valid;
    reg  [31:0] pc;

    wire [31:0] seq_pc;
    wire [31:0] next_pc;
    wire [31:0] inst;

    assign seq_pc = pc + 32'd4;
    assign inst   = inst_sram_rdata;

    always @(posedge clk) begin
        if (!resetn) begin
            valid <= 1'b0;
            pc    <= RESET_PC;
        end
        else if (cpu_en) begin
            valid <= 1'b1;
            pc    <= next_pc;
        end
    end

    assign inst_sram_we    = 1'b0;
    assign inst_sram_addr  = pc;
    assign inst_sram_wdata = 32'b0;

    wire [4:0]  rd;
    wire [4:0]  rj;
    wire [4:0]  rk;
    wire [11:0] imm12;
    wire [15:0] offs16;
    wire [4:0]  ui5;
    wire [19:0] si20;
    wire [25:0] offs26;

    wire inst_add_w;
    wire inst_addi_w;
    wire inst_ld_w;
    wire inst_st_w;
    wire inst_bne;
    wire inst_sub_w;
    wire inst_and;
    wire inst_or;
    wire inst_beq;
    wire inst_b;
    wire inst_bl;
    wire inst_jirl;
    wire inst_slt;
    wire inst_sltu;
    wire inst_slli_w;
    wire inst_srli_w;
    wire inst_srai_w;
    wire inst_lu12i_w;
    wire inst_nor;
    wire inst_xor;

    inst_decode u_inst_decode(
        .inst         (inst),
        .rd           (rd),
        .rj           (rj),
        .rk           (rk),
        .imm12        (imm12),
        .offs16       (offs16),
        .ui5          (ui5),
        .si20         (si20),
        .offs26       (offs26),
        .inst_add_w   (inst_add_w),
        .inst_addi_w  (inst_addi_w),
        .inst_ld_w    (inst_ld_w),
        .inst_st_w    (inst_st_w),
        .inst_bne     (inst_bne),
        .inst_sub_w   (inst_sub_w),
        .inst_and     (inst_and),
        .inst_or      (inst_or),
        .inst_beq     (inst_beq),
        .inst_b       (inst_b),
        .inst_bl      (inst_bl),
        .inst_jirl    (inst_jirl),
        .inst_slt     (inst_slt),
        .inst_sltu    (inst_sltu),
        .inst_slli_w  (inst_slli_w),
        .inst_srli_w  (inst_srli_w),
        .inst_srai_w  (inst_srai_w),
        .inst_lu12i_w (inst_lu12i_w),
        .inst_nor     (inst_nor),
        .inst_xor     (inst_xor)
    );

    wire       sel_rf_ra2;
    wire       sel_alu_src2;
    wire       data_ram_we;
    wire       rf_we;
    wire [2:0] ext_op;
    wire [1:0] sel_rf_res;
    wire       sel_rf_dst;
    wire [3:0] alu_op;
    wire       br_en;
    wire       br_op;
    wire       sel_nextpc;
    wire       inst_ram_we_unused;
    wire       inst_ram_ce_unused;
    wire       data_ram_ce;
    wire       jirl_sel;

    cpu_control u_cpu_control(
        .inst_add_w   (inst_add_w),
        .inst_addi_w  (inst_addi_w),
        .inst_ld_w    (inst_ld_w),
        .inst_st_w    (inst_st_w),
        .inst_bne     (inst_bne),
        .inst_sub_w   (inst_sub_w),
        .inst_and     (inst_and),
        .inst_or      (inst_or),
        .inst_beq     (inst_beq),
        .inst_b       (inst_b),
        .inst_bl      (inst_bl),
        .inst_jirl    (inst_jirl),
        .inst_slt     (inst_slt),
        .inst_sltu    (inst_sltu),
        .inst_slli_w  (inst_slli_w),
        .inst_srli_w  (inst_srli_w),
        .inst_srai_w  (inst_srai_w),
        .inst_lu12i_w (inst_lu12i_w),
        .inst_nor     (inst_nor),
        .inst_xor     (inst_xor),
        .sel_rf_ra2   (sel_rf_ra2),
        .sel_alu_src2 (sel_alu_src2),
        .data_ram_we  (data_ram_we),
        .rf_we        (rf_we),
        .ext_op       (ext_op),
        .sel_rf_res   (sel_rf_res),
        .sel_rf_dst   (sel_rf_dst),
        .alu_op       (alu_op),
        .br_en        (br_en),
        .br_op        (br_op),
        .sel_nextpc   (sel_nextpc),
        .inst_ram_we  (inst_ram_we_unused),
        .inst_ram_ce  (inst_ram_ce_unused),
        .data_ram_ce  (data_ram_ce),
        .jirl_sel     (jirl_sel)
    );

    wire [31:0] ext_imm;

    imm_extend u_imm_extend(
        .ext_op  (ext_op),
        .imm12   (imm12),
        .offs16  (offs16),
        .offs26  (offs26),
        .ui5     (ui5),
        .si20    (si20),
        .ext_imm (ext_imm)
    );

    wire [4:0]  rf_raddr1;
    wire [4:0]  rf_raddr2;
    wire [4:0]  rf_waddr;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire [31:0] rf_wdata;
    wire        rf_we_valid;

    assign rf_raddr1   = rj;
    assign rf_raddr2   = sel_rf_ra2 ? rk : rd;
    assign rf_waddr    = sel_rf_dst ? rd : 5'd1;
    assign rf_we_valid = cpu_en & rf_we & valid;

    regfile u_regfile(
        .clk    (clk),
        .resetn (resetn),
        .wen    (rf_we_valid),
        .waddr  (rf_waddr),
        .wdata  (rf_wdata),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2)
    );

    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0] alu_result;

    assign alu_src1 = rf_rdata1;
    assign alu_src2 = sel_alu_src2 ? ext_imm : rf_rdata2;

    alu u_alu(
        .alu_src1   (alu_src1),
        .alu_src2   (alu_src2),
        .alu_op     (alu_op),
        .alu_result (alu_result)
    );

    assign data_sram_we    = cpu_en & valid & data_ram_we & data_ram_ce;
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = rf_rdata2;

    assign rf_wdata = (sel_rf_res == 2'b00) ? data_sram_rdata :
                      (sel_rf_res == 2'b10) ? ext_imm :
                      (sel_rf_res == 2'b11) ? seq_pc :
                                               alu_result;

    branch_unit u_branch_unit(
        .br_en       (br_en & valid),
        .br_op       (br_op),
        .sel_nextpc  (sel_nextpc),
        .jirl_sel    (jirl_sel),
        .pc          (pc),
        .seq_pc      (seq_pc),
        .branch_offs (ext_imm),
        .rdata1      (rf_rdata1),
        .rdata2      (rf_rdata2),
        .next_pc     (next_pc),
        .br_taken    ()
    );

    always @(posedge clk) begin
        if (!resetn) begin
            debug_wb_pc       <= 32'b0;
            debug_wb_rf_we    <= 4'b0;
            debug_wb_rf_wnum  <= 5'b0;
            debug_wb_rf_wdata <= 32'b0;
        end
        else if (cpu_en) begin
            debug_wb_pc       <= pc;
            debug_wb_rf_we    <= {4{rf_we_valid}};
            debug_wb_rf_wnum  <= rf_we_valid ? rf_waddr : 5'b0;
            debug_wb_rf_wdata <= rf_we_valid ? rf_wdata : 32'b0;
        end
    end

endmodule
