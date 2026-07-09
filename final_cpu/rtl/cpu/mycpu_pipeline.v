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

    wire        core_inst_req_valid;
    wire [31:0] core_inst_req_addr;
    wire        core_data_req_valid;
    wire [ 3:0] core_data_req_wen;
    wire [31:0] core_data_req_addr;
    wire [31:0] core_data_req_wdata;
    wire        core_data_req_cacop;
    wire        core_data_req_preld;
    wire [31:0] core_debug_pc;
    wire [ 3:0] core_debug_wen;
    wire [ 4:0] core_debug_wnum;
    wire [31:0] core_debug_wdata;
    wire [31:0] core_debug_inst;

    reg         inst_resp_valid;
    reg         data_resp_valid;
    reg         inst_req_pending;
    reg         data_req_pending;
    reg  [31:0] inst_resp_data;
    reg  [31:0] data_resp_data;
    reg  [31:0] debug_wb_inst;

    assign inst_sram_en    = cpu_en & core_inst_req_valid;
    assign inst_sram_we    = 4'b0000;
    assign inst_sram_addr  = core_inst_req_addr;
    assign inst_sram_wdata = 32'b0;

    assign data_sram_en    = cpu_en & core_data_req_valid &
                              ~core_data_req_cacop & ~core_data_req_preld;
    assign data_sram_we    = core_data_req_wen;
    assign data_sram_addr  = core_data_req_addr;
    assign data_sram_wdata = core_data_req_wdata;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            inst_resp_valid <= 1'b0;
            data_resp_valid <= 1'b0;
            inst_req_pending <= 1'b0;
            data_req_pending <= 1'b0;
            inst_resp_data  <= 32'b0;
            data_resp_data  <= 32'b0;
        end
        else if (cpu_en)
        begin
            inst_resp_valid <= inst_req_pending;
            data_resp_valid <= data_req_pending;
            inst_req_pending <= core_inst_req_valid;
            data_req_pending <= core_data_req_valid;
            inst_resp_data  <= inst_sram_rdata;
            data_resp_data  <= data_sram_rdata;
        end
    end

    SimpleLACore u_core(
        .clock                 (clk),
        .reset                 (~resetn),
        .io_ipi                (1'b0),
        .io_interrupt          (8'b0),
        .io_inst_req_valid     (core_inst_req_valid),
        .io_inst_req_bits_addr (core_inst_req_addr),
        .io_inst_resp_valid    (inst_resp_valid),
        .io_inst_resp_bits     (inst_resp_data),
        .io_data_req_valid     (core_data_req_valid),
        .io_data_req_bits_wen  (core_data_req_wen),
        .io_data_req_bits_addr (core_data_req_addr),
        .io_data_req_bits_wdata(core_data_req_wdata),
        .io_data_req_bits_cacop(core_data_req_cacop),
        .io_data_req_bits_preld(core_data_req_preld),
        .io_data_resp_valid    (data_resp_valid),
        .io_data_resp_bits     (data_resp_data),
        .io_debug_pc           (core_debug_pc),
        .io_debug_wen          (core_debug_wen),
        .io_debug_wnum         (core_debug_wnum),
        .io_debug_wdata        (core_debug_wdata),
        .io_debug_inst         (core_debug_inst)
    );

    assign debug_commit_valid = |debug_wb_rf_we;
    assign debug_commit_pc    = debug_wb_pc;
    assign debug_commit_inst  = debug_wb_inst;
    assign debug_fetch_pc     = core_inst_req_addr;
    assign debug_pipe_valid   = cpu_en ? 4'b1111 : 4'b0000;
    assign debug_pipe_hazard  = 3'b000;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            debug_wb_pc          <= 32'b0;
            debug_wb_rf_we       <= 4'b0;
            debug_wb_rf_wnum     <= 5'b0;
            debug_wb_rf_wdata    <= 32'b0;
            debug_wb_inst        <= 32'b0;
            debug_last_wb_valid  <= 1'b0;
            debug_last_wb_pc     <= 32'b0;
            debug_last_wb_wnum   <= 5'b0;
            debug_last_wb_wdata  <= 32'b0;
        end
        else if (cpu_en)
        begin
            debug_wb_pc       <= core_debug_pc;
            debug_wb_rf_we    <= (core_debug_wnum == 5'b0) ? 4'b0 : core_debug_wen;
            debug_wb_rf_wnum  <= (core_debug_wen == 4'b0) ? 5'b0 : core_debug_wnum;
            debug_wb_rf_wdata <= (core_debug_wen == 4'b0) ? 32'b0 : core_debug_wdata;
            debug_wb_inst     <= core_debug_inst;

            if (core_debug_wen != 4'b0 && core_debug_wnum != 5'b0)
            begin
                debug_last_wb_valid <= 1'b1;
                debug_last_wb_pc    <= core_debug_pc;
                debug_last_wb_wnum  <= core_debug_wnum;
                debug_last_wb_wdata <= core_debug_wdata;
            end
        end
    end

endmodule
