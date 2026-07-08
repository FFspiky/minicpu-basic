`timescale 1ns / 1ps

module mycpu_pipeline(
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

    localparam WB_FROM_MEM = 2'b00;
    localparam WB_FROM_ALU = 2'b01;
    localparam WB_FROM_IMM = 2'b10;
    localparam WB_FROM_PC4 = 2'b11;

    // =========================================================
    // IF stage
    // =========================================================

    reg  [31:0] pc;
    reg         fetch_valid;
    reg         fetch_resp_valid;
    reg  [31:0] fetch_resp_pc;
    reg  [31:0] fetch_resp_pc_plus4;

    wire [31:0] if_pc_plus4;
    wire [31:0] if_next_pc;
    wire        load_use_stall;

    assign if_pc_plus4    = pc + 32'd4;
    assign inst_sram_en   = cpu_en & !load_use_stall;
    assign inst_sram_we   = 4'b0000;
    assign inst_sram_addr = pc;
    assign inst_sram_wdata = 32'b0;

    // =========================================================
    // Pipeline registers
    // =========================================================

    reg         if_id_valid;
    reg  [31:0] if_id_pc;
    reg  [31:0] if_id_pc_plus4;
    reg  [31:0] if_id_inst;

    reg         id_ex_valid;
    reg  [31:0] id_ex_pc;
    reg  [31:0] id_ex_pc_plus4;
    reg  [31:0] id_ex_inst;
    reg  [31:0] id_ex_ext_imm;
    reg  [31:0] id_ex_rdata1;
    reg  [31:0] id_ex_rdata2;
    reg  [ 4:0] id_ex_raddr1;
    reg  [ 4:0] id_ex_raddr2;
    reg  [ 4:0] id_ex_waddr;
    reg         id_ex_src1_valid;
    reg         id_ex_src2_valid;
    reg         id_ex_sel_alu_src2;
    reg         id_ex_data_ram_we;
    reg         id_ex_rf_we;
    reg  [ 1:0] id_ex_sel_rf_res;
    reg  [ 3:0] id_ex_alu_op;
    reg         id_ex_br_en;
    reg         id_ex_br_op;
    reg         id_ex_sel_nextpc;
    reg         id_ex_data_ram_ce;
    reg         id_ex_jirl_sel;

    reg         ex_mem_valid;
    reg  [31:0] ex_mem_pc;
    reg  [31:0] ex_mem_pc_plus4;
    reg  [31:0] ex_mem_inst;
    reg  [31:0] ex_mem_alu_result;
    reg  [31:0] ex_mem_ext_imm;
    reg  [31:0] ex_mem_store_data;
    reg  [ 4:0] ex_mem_waddr;
    reg         ex_mem_data_ram_we;
    reg         ex_mem_rf_we;
    reg  [ 1:0] ex_mem_sel_rf_res;
    reg         ex_mem_data_ram_ce;

    reg         mem_wb_valid;
    reg  [31:0] mem_wb_pc;
    reg  [31:0] mem_wb_pc_plus4;
    reg  [31:0] mem_wb_inst;
    reg  [31:0] mem_wb_alu_result;
    reg  [31:0] mem_wb_ext_imm;
    reg  [31:0] mem_wb_mem_rdata;
    reg  [ 4:0] mem_wb_waddr;
    reg         mem_wb_rf_we;
    reg  [ 1:0] mem_wb_sel_rf_res;

    // =========================================================
    // WB stage and register file
    // =========================================================

    wire        wb_rf_we;
    wire        wb_rf_we_valid;
    wire [31:0] wb_rf_wdata;

    assign wb_rf_we = mem_wb_valid & mem_wb_rf_we;
    assign wb_rf_we_valid = wb_rf_we & (mem_wb_waddr != 5'd0);
    assign wb_rf_wdata = (mem_wb_sel_rf_res == WB_FROM_MEM) ? mem_wb_mem_rdata :
                         (mem_wb_sel_rf_res == WB_FROM_IMM) ? mem_wb_ext_imm :
                         (mem_wb_sel_rf_res == WB_FROM_PC4) ? mem_wb_pc_plus4 :
                                                              mem_wb_alu_result;

    wire [4:0]  id_rd;
    wire [4:0]  id_rj;
    wire [4:0]  id_rk;
    wire [11:0] id_imm12;
    wire [15:0] id_offs16;
    wire [4:0]  id_ui5;
    wire [19:0] id_si20;
    wire [25:0] id_offs26;

    wire id_inst_add_w;
    wire id_inst_addi_w;
    wire id_inst_ld_w;
    wire id_inst_st_w;
    wire id_inst_bne;
    wire id_inst_sub_w;
    wire id_inst_and;
    wire id_inst_or;
    wire id_inst_beq;
    wire id_inst_b;
    wire id_inst_bl;
    wire id_inst_jirl;
    wire id_inst_slt;
    wire id_inst_sltu;
    wire id_inst_slli_w;
    wire id_inst_srli_w;
    wire id_inst_srai_w;
    wire id_inst_lu12i_w;
    wire id_inst_nor;
    wire id_inst_xor;

    inst_decode u_inst_decode(
        .inst         (if_id_inst),
        .rd           (id_rd),
        .rj           (id_rj),
        .rk           (id_rk),
        .imm12        (id_imm12),
        .offs16       (id_offs16),
        .ui5          (id_ui5),
        .si20         (id_si20),
        .offs26       (id_offs26),
        .inst_add_w   (id_inst_add_w),
        .inst_addi_w  (id_inst_addi_w),
        .inst_ld_w    (id_inst_ld_w),
        .inst_st_w    (id_inst_st_w),
        .inst_bne     (id_inst_bne),
        .inst_sub_w   (id_inst_sub_w),
        .inst_and     (id_inst_and),
        .inst_or      (id_inst_or),
        .inst_beq     (id_inst_beq),
        .inst_b       (id_inst_b),
        .inst_bl      (id_inst_bl),
        .inst_jirl    (id_inst_jirl),
        .inst_slt     (id_inst_slt),
        .inst_sltu    (id_inst_sltu),
        .inst_slli_w  (id_inst_slli_w),
        .inst_srli_w  (id_inst_srli_w),
        .inst_srai_w  (id_inst_srai_w),
        .inst_lu12i_w (id_inst_lu12i_w),
        .inst_nor     (id_inst_nor),
        .inst_xor     (id_inst_xor)
    );

    wire       id_sel_rf_ra2;
    wire       id_sel_alu_src2;
    wire       id_data_ram_we;
    wire       id_rf_we;
    wire [2:0] id_ext_op;
    wire [1:0] id_sel_rf_res;
    wire       id_sel_rf_dst;
    wire [3:0] id_alu_op;
    wire       id_br_en;
    wire       id_br_op;
    wire       id_sel_nextpc;
    wire       id_inst_ram_we_unused;
    wire       id_inst_ram_ce_unused;
    wire       id_data_ram_ce;
    wire       id_jirl_sel;

    cpu_control u_cpu_control(
        .inst_add_w   (id_inst_add_w),
        .inst_addi_w  (id_inst_addi_w),
        .inst_ld_w    (id_inst_ld_w),
        .inst_st_w    (id_inst_st_w),
        .inst_bne     (id_inst_bne),
        .inst_sub_w   (id_inst_sub_w),
        .inst_and     (id_inst_and),
        .inst_or      (id_inst_or),
        .inst_beq     (id_inst_beq),
        .inst_b       (id_inst_b),
        .inst_bl      (id_inst_bl),
        .inst_jirl    (id_inst_jirl),
        .inst_slt     (id_inst_slt),
        .inst_sltu    (id_inst_sltu),
        .inst_slli_w  (id_inst_slli_w),
        .inst_srli_w  (id_inst_srli_w),
        .inst_srai_w  (id_inst_srai_w),
        .inst_lu12i_w (id_inst_lu12i_w),
        .inst_nor     (id_inst_nor),
        .inst_xor     (id_inst_xor),
        .sel_rf_ra2   (id_sel_rf_ra2),
        .sel_alu_src2 (id_sel_alu_src2),
        .data_ram_we  (id_data_ram_we),
        .rf_we        (id_rf_we),
        .ext_op       (id_ext_op),
        .sel_rf_res   (id_sel_rf_res),
        .sel_rf_dst   (id_sel_rf_dst),
        .alu_op       (id_alu_op),
        .br_en        (id_br_en),
        .br_op        (id_br_op),
        .sel_nextpc   (id_sel_nextpc),
        .inst_ram_we  (id_inst_ram_we_unused),
        .inst_ram_ce  (id_inst_ram_ce_unused),
        .data_ram_ce  (id_data_ram_ce),
        .jirl_sel     (id_jirl_sel)
    );

    wire [31:0] id_ext_imm;

    imm_extend u_imm_extend(
        .ext_op  (id_ext_op),
        .imm12   (id_imm12),
        .offs16  (id_offs16),
        .offs26  (id_offs26),
        .ui5     (id_ui5),
        .si20    (id_si20),
        .ext_imm (id_ext_imm)
    );

    wire [4:0]  id_rf_raddr1;
    wire [4:0]  id_rf_raddr2;
    wire [4:0]  id_rf_waddr;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire [31:0] id_rdata1;
    wire [31:0] id_rdata2;

    assign id_rf_raddr1 = id_rj;
    assign id_rf_raddr2 = id_sel_rf_ra2 ? id_rk : id_rd;
    assign id_rf_waddr  = id_sel_rf_dst ? id_rd : 5'd1;

    regfile u_regfile(
        .clk    (clk),
        .resetn (resetn),
        .wen    (cpu_en & wb_rf_we),
        .waddr  (mem_wb_waddr),
        .wdata  (wb_rf_wdata),
        .raddr1 (id_rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (id_rf_raddr2),
        .rdata2 (rf_rdata2)
    );

    assign id_rdata1 = (wb_rf_we_valid && (mem_wb_waddr == id_rf_raddr1)) ? wb_rf_wdata : rf_rdata1;
    assign id_rdata2 = (wb_rf_we_valid && (mem_wb_waddr == id_rf_raddr2)) ? wb_rf_wdata : rf_rdata2;

    wire id_src1_used;
    wire id_src2_used;
    wire id_src1_valid;
    wire id_src2_valid;

    assign id_src1_used = id_inst_add_w   |
                          id_inst_addi_w  |
                          id_inst_ld_w    |
                          id_inst_st_w    |
                          id_inst_bne     |
                          id_inst_sub_w   |
                          id_inst_and     |
                          id_inst_or      |
                          id_inst_beq     |
                          id_inst_jirl    |
                          id_inst_slt     |
                          id_inst_sltu    |
                          id_inst_slli_w  |
                          id_inst_srli_w  |
                          id_inst_srai_w  |
                          id_inst_nor     |
                          id_inst_xor;

    assign id_src2_used = id_inst_add_w |
                          id_inst_st_w  |
                          id_inst_bne   |
                          id_inst_sub_w |
                          id_inst_and   |
                          id_inst_or    |
                          id_inst_beq   |
                          id_inst_slt   |
                          id_inst_sltu  |
                          id_inst_nor   |
                          id_inst_xor;

    assign id_src1_valid = if_id_valid & id_src1_used;
    assign id_src2_valid = if_id_valid & id_src2_used;

    // =========================================================
    // Hazard detection
    // =========================================================

    wire id_ex_is_load;

    assign id_ex_is_load = id_ex_valid & id_ex_rf_we & (id_ex_sel_rf_res == WB_FROM_MEM);
    assign load_use_stall =
        id_ex_is_load & (id_ex_waddr != 5'd0) &
        ((id_src1_valid & (id_rf_raddr1 == id_ex_waddr)) |
         (id_src2_valid & (id_rf_raddr2 == id_ex_waddr)));

    // =========================================================
    // EX stage forwarding and execution
    // =========================================================

    wire        ex_mem_is_load;
    wire        ex_mem_forward_valid;
    wire [31:0] ex_mem_forward_data;
    wire        mem_wb_forward_valid;

    assign ex_mem_is_load = ex_mem_valid & ex_mem_rf_we & (ex_mem_sel_rf_res == WB_FROM_MEM);
    assign ex_mem_forward_valid = ex_mem_valid & ex_mem_rf_we &
                                  (ex_mem_waddr != 5'd0) & ~ex_mem_is_load;
    assign ex_mem_forward_data = (ex_mem_sel_rf_res == WB_FROM_IMM) ? ex_mem_ext_imm :
                                 (ex_mem_sel_rf_res == WB_FROM_PC4) ? ex_mem_pc_plus4 :
                                                                      ex_mem_alu_result;
    assign mem_wb_forward_valid = wb_rf_we_valid;

    wire [31:0] ex_rdata1_forwarded;
    wire [31:0] ex_rdata2_forwarded;

    assign ex_rdata1_forwarded =
        (id_ex_src1_valid && ex_mem_forward_valid && (ex_mem_waddr == id_ex_raddr1)) ? ex_mem_forward_data :
        (id_ex_src1_valid && mem_wb_forward_valid && (mem_wb_waddr == id_ex_raddr1)) ? wb_rf_wdata :
                                                                                       id_ex_rdata1;

    assign ex_rdata2_forwarded =
        (id_ex_src2_valid && ex_mem_forward_valid && (ex_mem_waddr == id_ex_raddr2)) ? ex_mem_forward_data :
        (id_ex_src2_valid && mem_wb_forward_valid && (mem_wb_waddr == id_ex_raddr2)) ? wb_rf_wdata :
                                                                                       id_ex_rdata2;

    wire [31:0] ex_alu_src1;
    wire [31:0] ex_alu_src2;
    wire [31:0] ex_alu_result;

    assign ex_alu_src1 = ex_rdata1_forwarded;
    assign ex_alu_src2 = id_ex_sel_alu_src2 ? id_ex_ext_imm : ex_rdata2_forwarded;

    alu u_alu(
        .alu_src1   (ex_alu_src1),
        .alu_src2   (ex_alu_src2),
        .alu_op     (id_ex_alu_op),
        .alu_result (ex_alu_result)
    );

    wire [31:0] ex_branch_next_pc;
    wire        ex_branch_taken;

    branch_unit u_branch_unit(
        .br_en       (id_ex_br_en & id_ex_valid),
        .br_op       (id_ex_br_op),
        .sel_nextpc  (id_ex_sel_nextpc),
        .jirl_sel    (id_ex_jirl_sel),
        .pc          (id_ex_pc),
        .seq_pc      (id_ex_pc_plus4),
        .branch_offs (id_ex_ext_imm),
        .rdata1      (ex_rdata1_forwarded),
        .rdata2      (ex_rdata2_forwarded),
        .next_pc     (ex_branch_next_pc),
        .br_taken    (ex_branch_taken)
    );

    assign if_next_pc = ex_branch_taken ? ex_branch_next_pc : if_pc_plus4;

    assign debug_commit_valid = mem_wb_valid;
    assign debug_commit_pc    = mem_wb_pc;
    assign debug_commit_inst  = mem_wb_inst;
    assign debug_fetch_pc     = pc;
    assign debug_pipe_valid   = {if_id_valid, id_ex_valid, ex_mem_valid, mem_wb_valid};
    assign debug_pipe_hazard  = {load_use_stall, ex_branch_taken, id_ex_br_en & id_ex_valid};

    // =========================================================
    // MEM stage
    // =========================================================

    assign data_sram_en    = cpu_en & id_ex_valid & id_ex_data_ram_ce;
    assign data_sram_we    = {4{cpu_en & id_ex_valid & id_ex_data_ram_we & id_ex_data_ram_ce}};
    assign data_sram_addr  = ex_alu_result;
    assign data_sram_wdata = ex_rdata2_forwarded;

    // =========================================================
    // Pipeline register updates
    // =========================================================

    always @(posedge clk) begin
        if (!resetn) begin
            pc                  <= RESET_PC;
            fetch_valid         <= 1'b0;
            fetch_resp_valid    <= 1'b0;
            fetch_resp_pc       <= 32'b0;
            fetch_resp_pc_plus4 <= 32'b0;
        end
        else if (cpu_en) begin
            if (ex_branch_taken) begin
                pc                  <= ex_branch_next_pc;
                fetch_valid         <= 1'b1;
                fetch_resp_valid    <= 1'b0;
                fetch_resp_pc       <= 32'b0;
                fetch_resp_pc_plus4 <= 32'b0;
            end
            else if (!load_use_stall) begin
                pc                  <= if_next_pc;
                fetch_valid         <= 1'b1;
                fetch_resp_valid    <= fetch_valid;
                fetch_resp_pc       <= pc;
                fetch_resp_pc_plus4 <= if_pc_plus4;
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            if_id_valid    <= 1'b0;
            if_id_pc       <= 32'b0;
            if_id_pc_plus4 <= 32'b0;
            if_id_inst     <= 32'b0;
        end
        else if (cpu_en) begin
            if (ex_branch_taken) begin
                if_id_valid <= 1'b0;
            end
            else if (!load_use_stall) begin
                if_id_valid    <= fetch_resp_valid;
                if_id_pc       <= fetch_resp_pc;
                if_id_pc_plus4 <= fetch_resp_pc_plus4;
                if_id_inst     <= inst_sram_rdata;
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            id_ex_valid        <= 1'b0;
            id_ex_pc           <= 32'b0;
            id_ex_pc_plus4     <= 32'b0;
            id_ex_inst         <= 32'b0;
            id_ex_ext_imm      <= 32'b0;
            id_ex_rdata1       <= 32'b0;
            id_ex_rdata2       <= 32'b0;
            id_ex_raddr1       <= 5'b0;
            id_ex_raddr2       <= 5'b0;
            id_ex_waddr        <= 5'b0;
            id_ex_src1_valid   <= 1'b0;
            id_ex_src2_valid   <= 1'b0;
            id_ex_sel_alu_src2 <= 1'b0;
            id_ex_data_ram_we  <= 1'b0;
            id_ex_rf_we        <= 1'b0;
            id_ex_sel_rf_res   <= WB_FROM_ALU;
            id_ex_alu_op       <= 4'b0;
            id_ex_br_en        <= 1'b0;
            id_ex_br_op        <= 1'b0;
            id_ex_sel_nextpc   <= 1'b0;
            id_ex_data_ram_ce  <= 1'b0;
            id_ex_jirl_sel     <= 1'b1;
        end
        else if (cpu_en) begin
            if (ex_branch_taken || load_use_stall) begin
                id_ex_valid        <= 1'b0;
                id_ex_inst         <= 32'b0;
                id_ex_src1_valid   <= 1'b0;
                id_ex_src2_valid   <= 1'b0;
                id_ex_data_ram_we  <= 1'b0;
                id_ex_rf_we        <= 1'b0;
                id_ex_br_en        <= 1'b0;
                id_ex_data_ram_ce  <= 1'b0;
            end
            else begin
                id_ex_valid        <= if_id_valid;
                id_ex_pc           <= if_id_pc;
                id_ex_pc_plus4     <= if_id_pc_plus4;
                id_ex_inst         <= if_id_inst;
                id_ex_ext_imm      <= id_ext_imm;
                id_ex_rdata1       <= id_rdata1;
                id_ex_rdata2       <= id_rdata2;
                id_ex_raddr1       <= id_rf_raddr1;
                id_ex_raddr2       <= id_rf_raddr2;
                id_ex_waddr        <= id_rf_waddr;
                id_ex_src1_valid   <= id_src1_valid;
                id_ex_src2_valid   <= id_src2_valid;
                id_ex_sel_alu_src2 <= id_sel_alu_src2;
                id_ex_data_ram_we  <= if_id_valid & id_data_ram_we;
                id_ex_rf_we        <= if_id_valid & id_rf_we;
                id_ex_sel_rf_res   <= id_sel_rf_res;
                id_ex_alu_op       <= id_alu_op;
                id_ex_br_en        <= if_id_valid & id_br_en;
                id_ex_br_op        <= id_br_op;
                id_ex_sel_nextpc   <= id_sel_nextpc;
                id_ex_data_ram_ce  <= if_id_valid & id_data_ram_ce;
                id_ex_jirl_sel     <= id_jirl_sel;
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            ex_mem_valid       <= 1'b0;
            ex_mem_pc          <= 32'b0;
            ex_mem_pc_plus4    <= 32'b0;
            ex_mem_inst        <= 32'b0;
            ex_mem_alu_result  <= 32'b0;
            ex_mem_ext_imm     <= 32'b0;
            ex_mem_store_data  <= 32'b0;
            ex_mem_waddr       <= 5'b0;
            ex_mem_data_ram_we <= 1'b0;
            ex_mem_rf_we       <= 1'b0;
            ex_mem_sel_rf_res  <= WB_FROM_ALU;
            ex_mem_data_ram_ce <= 1'b0;
        end
        else if (cpu_en) begin
            ex_mem_valid       <= id_ex_valid;
            ex_mem_pc          <= id_ex_pc;
            ex_mem_pc_plus4    <= id_ex_pc_plus4;
            ex_mem_inst        <= id_ex_inst;
            ex_mem_alu_result  <= ex_alu_result;
            ex_mem_ext_imm     <= id_ex_ext_imm;
            ex_mem_store_data  <= ex_rdata2_forwarded;
            ex_mem_waddr       <= id_ex_waddr;
            ex_mem_data_ram_we <= id_ex_valid & id_ex_data_ram_we;
            ex_mem_rf_we       <= id_ex_valid & id_ex_rf_we;
            ex_mem_sel_rf_res  <= id_ex_sel_rf_res;
            ex_mem_data_ram_ce <= id_ex_valid & id_ex_data_ram_ce;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            mem_wb_valid      <= 1'b0;
            mem_wb_pc         <= 32'b0;
            mem_wb_pc_plus4   <= 32'b0;
            mem_wb_inst       <= 32'b0;
            mem_wb_alu_result <= 32'b0;
            mem_wb_ext_imm    <= 32'b0;
            mem_wb_mem_rdata  <= 32'b0;
            mem_wb_waddr      <= 5'b0;
            mem_wb_rf_we      <= 1'b0;
            mem_wb_sel_rf_res <= WB_FROM_ALU;
        end
        else if (cpu_en) begin
            mem_wb_valid      <= ex_mem_valid;
            mem_wb_pc         <= ex_mem_pc;
            mem_wb_pc_plus4   <= ex_mem_pc_plus4;
            mem_wb_inst       <= ex_mem_inst;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_ext_imm    <= ex_mem_ext_imm;
            mem_wb_mem_rdata  <= data_sram_rdata;
            mem_wb_waddr      <= ex_mem_waddr;
            mem_wb_rf_we      <= ex_mem_valid & ex_mem_rf_we;
            mem_wb_sel_rf_res <= ex_mem_sel_rf_res;
        end
    end

    // =========================================================
    // Debug write-back trace
    // =========================================================

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
            debug_wb_pc       <= mem_wb_pc;
            debug_wb_rf_we    <= {4{wb_rf_we_valid}};
            debug_wb_rf_wnum  <= wb_rf_we_valid ? mem_wb_waddr : 5'b0;
            debug_wb_rf_wdata <= wb_rf_we_valid ? wb_rf_wdata : 32'b0;

            if (wb_rf_we_valid) begin
                debug_last_wb_valid <= 1'b1;
                debug_last_wb_pc    <= mem_wb_pc;
                debug_last_wb_wnum  <= mem_wb_waddr;
                debug_last_wb_wdata <= wb_rf_wdata;
            end
        end
    end

endmodule
