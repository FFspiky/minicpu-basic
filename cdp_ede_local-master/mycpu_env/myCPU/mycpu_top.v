`timescale 1ns / 1ps

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,

    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    output reg  [31:0] debug_wb_pc,
    output reg  [ 3:0] debug_wb_rf_we,
    output reg  [ 4:0] debug_wb_rf_wnum,
    output reg  [31:0] debug_wb_rf_wdata,

    output reg         debug_last_wb_valid,
    output reg  [31:0] debug_last_wb_pc,
    output reg  [ 4:0] debug_last_wb_wnum,
    output reg  [31:0] debug_last_wb_wdata,

    output wire        debug_commit_valid,
    output wire [31:0] debug_commit_pc,
    output wire [31:0] debug_commit_inst,
    output wire [31:0] debug_fetch_pc,
    output wire [ 3:0] debug_pipe_valid,
    output wire [ 2:0] debug_pipe_hazard
);

    localparam RESET_PC = 32'h1bfffffc;

    reg         valid;
    reg  [31:0] pc;
    reg         load_wait;
    reg  [31:0] load_pc_r;
    reg  [31:0] load_inst_r;
    reg  [ 4:0] load_waddr_r;

    wire        inst_ld_w;
    wire [ 4:0] rf_waddr;
    wire [31:0] seq_pc;
    wire [31:0] next_pc;
    wire [31:0] inst;
    wire [31:0] fetch_addr;
    wire        normal_execute;
    wire        load_complete;

    assign seq_pc         = pc + 32'd4;
    assign inst           = inst_sram_rdata;
    assign fetch_addr     = valid ? next_pc : (RESET_PC + 32'd4);
    assign normal_execute = cpu_en & valid & !load_wait;
    assign load_complete  = cpu_en & load_wait;

    always @(posedge clk) begin
        if (!resetn) begin
            valid        <= 1'b0;
            pc           <= RESET_PC;
            load_wait    <= 1'b0;
            load_pc_r    <= 32'b0;
            load_inst_r  <= 32'b0;
            load_waddr_r <= 5'b0;
        end
        else if (cpu_en) begin
            if (load_wait) begin
                load_wait <= 1'b0;
            end
            else begin
                valid <= 1'b1;
                pc    <= fetch_addr;

                if (valid & inst_ld_w) begin
                    load_wait    <= 1'b1;
                    load_pc_r    <= pc;
                    load_inst_r  <= inst;
                    load_waddr_r <= rf_waddr;
                end
            end
        end
    end

    assign inst_sram_en    = cpu_en & !load_wait;
    assign inst_sram_we    = 4'b0000;
    assign inst_sram_addr  = fetch_addr;
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
    wire [4:0]  rf_waddr_final;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire [31:0] rf_wdata_normal;
    wire [31:0] rf_wdata_final;
    wire        normal_rf_we_valid;
    wire        rf_we_valid;
    wire        rf_last_wb_valid;

    assign rf_raddr1          = rj;
    assign rf_raddr2          = sel_rf_ra2 ? rk : rd;
    assign rf_waddr           = sel_rf_dst ? rd : 5'd1;
    assign normal_rf_we_valid = normal_execute & rf_we & !inst_ld_w;
    assign rf_we_valid        = normal_rf_we_valid | load_complete;
    assign rf_waddr_final     = load_wait ? load_waddr_r : rf_waddr;
    assign rf_wdata_final     = load_wait ? data_sram_rdata : rf_wdata_normal;
    assign rf_last_wb_valid   = rf_we_valid & (rf_waddr_final != 5'd0);

    regfile u_regfile(
        .clk    (clk),
        .resetn (resetn),
        .wen    (rf_we_valid),
        .waddr  (rf_waddr_final),
        .wdata  (rf_wdata_final),
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

    assign data_sram_en    = normal_execute & data_ram_ce;
    assign data_sram_we    = {4{normal_execute & data_ram_we & data_ram_ce}};
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = rf_rdata2;

    assign rf_wdata_normal = (sel_rf_res == 2'b00) ? data_sram_rdata :
                             (sel_rf_res == 2'b10) ? ext_imm :
                             (sel_rf_res == 2'b11) ? seq_pc :
                                                      alu_result;

    branch_unit u_branch_unit(
        .br_en       (br_en & valid & !load_wait),
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

    wire        commit_valid;
    wire [31:0] commit_pc;
    wire [31:0] commit_inst;

    assign commit_valid       = load_complete | (normal_execute & !inst_ld_w);
    assign commit_pc          = load_wait ? load_pc_r : pc;
    assign commit_inst        = load_wait ? load_inst_r : inst;
    assign debug_commit_valid = commit_valid;
    assign debug_commit_pc    = commit_pc;
    assign debug_commit_inst  = commit_inst;
    assign debug_fetch_pc     = inst_sram_addr;
    assign debug_pipe_valid   = {2'b00, load_wait, valid & !load_wait};
    assign debug_pipe_hazard  = {2'b00, load_wait};

    always @(posedge clk) begin
        if (!resetn) begin
            debug_wb_pc          <= 32'b0;
            debug_wb_rf_we       <= 4'b0;
            debug_wb_rf_wnum     <= 5'b0;
            debug_wb_rf_wdata    <= 32'b0;
            debug_last_wb_valid  <= 1'b0;
            debug_last_wb_pc     <= 32'b0;
            debug_last_wb_wnum   <= 5'b0;
            debug_last_wb_wdata  <= 32'b0;
        end
        else if (cpu_en) begin
            debug_wb_pc       <= commit_pc;
            debug_wb_rf_we    <= {4{rf_we_valid}};
            debug_wb_rf_wnum  <= rf_we_valid ? rf_waddr_final : 5'b0;
            debug_wb_rf_wdata <= rf_we_valid ? rf_wdata_final : 32'b0;

            if (rf_last_wb_valid) begin
                debug_last_wb_valid <= 1'b1;
                debug_last_wb_pc    <= commit_pc;
                debug_last_wb_wnum  <= rf_waddr_final;
                debug_last_wb_wdata <= rf_wdata_final;
            end
        end
    end

endmodule
