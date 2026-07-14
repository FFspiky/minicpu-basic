`timescale 1ns / 1ps

module la32_pipeline_control(
    input wire if_id_valid, input wire id_ex_valid, input wire ex_mem_valid,
    input wire mem_wb_valid,
    input wire [4:0] id_src1, input wire [4:0] id_src2,
    input wire id_src1_used, input wire id_src2_used,
    input wire id_is_csr, input wire id_reads_tid, input wire [13:0] id_csr_num,
    input wire [4:0] ex_src1, input wire [4:0] ex_src2,
    input wire ex_src1_used, input wire ex_src2_used,
    input wire [4:0] ex_dest, input wire ex_rf_we, input wire ex_is_load,
    input wire ex_is_csr, input wire ex_is_counter,
    input wire ex_csr_we, input wire [13:0] ex_csr_num,
    input wire [4:0] mem_dest, input wire mem_rf_we, input wire mem_is_load,
    input wire mem_is_csr, input wire mem_is_counter,
    input wire mem_csr_we, input wire [13:0] mem_csr_num,
    input wire [4:0] wb_dest, input wire wb_rf_we,
    input wire wb_csr_we, input wire [13:0] wb_csr_num,
    input wire mem_wait, input wire div_stall,
    input wire exception_enter, input wire ertn_taken,
    input wire branch_redirect_pulse, input wire interrupt_block_fetch,
    output reg [1:0] forward_src1_sel, output reg [1:0] forward_src2_sel,
    output reg [1:0] forward_store_sel,
    output wire pc_hold, output wire fetch_hold, output wire fetch_flush,
    output wire if_id_hold, output wire if_id_flush, output wire if_id_bubble,
    output wire id_ex_hold, output wire id_ex_flush, output wire id_ex_bubble,
    output wire ex_mem_hold, output wire ex_mem_flush, output wire ex_mem_bubble,
    output wire mem_wb_hold, output wire mem_wb_flush, output wire mem_wb_bubble,
    output wire global_flush, output wire kill_write, output wire pipe_empty,
    output wire data_hazard
);
    wire id_dep_ex = id_ex_valid && ex_rf_we && (ex_dest != 0) &&
                     ((id_src1_used && id_src1 == ex_dest) ||
                      (id_src2_used && id_src2 == ex_dest));
    wire id_dep_mem = ex_mem_valid && mem_rf_we && (mem_dest != 0) &&
                      ((id_src1_used && id_src1 == mem_dest) ||
                       (id_src2_used && id_src2 == mem_dest));
    wire late_ex = ex_is_load || ex_is_csr || ex_is_counter;
    wire late_mem = mem_is_load || mem_is_csr || mem_is_counter;
    wire late_hazard = (id_dep_ex && late_ex) || (id_dep_mem && late_mem);

    wire id_csr_like = id_is_csr || id_reads_tid;
    wire csr_hazard = id_csr_like &&
        ((id_ex_valid && ex_csr_we && ex_csr_num == id_csr_num) ||
         (ex_mem_valid && mem_csr_we && mem_csr_num == id_csr_num) ||
         (mem_wb_valid && wb_csr_we && wb_csr_num == id_csr_num));
    assign data_hazard = if_id_valid && (late_hazard || csr_hazard);

    wire mem_forward_valid = ex_mem_valid && mem_rf_we && (mem_dest != 0) &&
                             !mem_is_load && !mem_is_csr && !mem_is_counter;
    wire wb_forward_valid = mem_wb_valid && wb_rf_we && (wb_dest != 0);
    always @(*) begin
        forward_src1_sel = 2'd0;
        forward_src2_sel = 2'd0;
        forward_store_sel = 2'd0;
        if (ex_src1_used && mem_forward_valid && ex_src1 == mem_dest)
            forward_src1_sel = 2'd1;
        else if (ex_src1_used && wb_forward_valid && ex_src1 == wb_dest)
            forward_src1_sel = 2'd2;
        if (ex_src2_used && mem_forward_valid && ex_src2 == mem_dest)
            forward_src2_sel = 2'd1;
        else if (ex_src2_used && wb_forward_valid && ex_src2 == wb_dest)
            forward_src2_sel = 2'd2;
        forward_store_sel = forward_src2_sel;
    end

    assign global_flush = exception_enter || ertn_taken;
    assign kill_write = global_flush;
    assign pc_hold = interrupt_block_fetch || mem_wait || div_stall || data_hazard;
    assign fetch_hold = pc_hold;
    assign fetch_flush = global_flush || branch_redirect_pulse || interrupt_block_fetch;

    assign if_id_hold = mem_wait || div_stall || data_hazard;
    assign if_id_flush = global_flush || branch_redirect_pulse;
    assign if_id_bubble = 1'b0;

    assign id_ex_hold = mem_wait || div_stall;
    assign id_ex_flush = global_flush;
    assign id_ex_bubble = (branch_redirect_pulse && !mem_wait) || data_hazard;

    assign ex_mem_hold = mem_wait;
    assign ex_mem_flush = global_flush;
    assign ex_mem_bubble = div_stall && !mem_wait;

    assign mem_wb_hold = 1'b0;
    assign mem_wb_flush = global_flush;
    assign mem_wb_bubble = mem_wait;
    assign pipe_empty = !if_id_valid && !id_ex_valid &&
                        !ex_mem_valid && !mem_wb_valid;
endmodule
