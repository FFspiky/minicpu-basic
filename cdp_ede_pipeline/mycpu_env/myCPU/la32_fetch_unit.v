`timescale 1ns / 1ps
`include "la32_defs.vh"

module la32_fetch_unit(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    input  wire [31:0] pc,
    input  wire [31:0] pc_plus4,
    input  wire        fetch_hold,
    input  wire        fetch_flush,
    input  wire [31:0] inst_rdata,
    output wire        inst_sram_en,
    output wire [31:0] inst_sram_addr,
    output wire        fetch_issue_fire,
    output wire        inst_req_pending_o,
    output wire [31:0] fetch_resume_pc,
    output wire        if_valid,
    output wire [31:0] if_pc,
    output wire [31:0] if_pc_plus4,
    output wire [31:0] if_inst,
    output wire        if_exc_valid,
    output wire [ 5:0] if_ecode,
    output wire [ 8:0] if_esubcode,
    output wire [31:0] if_badv
);
    reg        inst_req_pending;
    reg [31:0] inst_req_pc;
    reg [31:0] inst_req_pc_plus4;
    reg        inst_req_from_mem;
    reg        inst_req_exc_valid;
    reg [ 5:0] inst_req_ecode;
    reg [ 8:0] inst_req_esubcode;
    reg [31:0] inst_req_badv;

    reg        inst_resp_buf_valid;
    reg [31:0] inst_resp_buf_data;
    reg [31:0] inst_resp_buf_pc;
    reg [31:0] inst_resp_buf_pc_plus4;
    reg        inst_resp_buf_exc_valid;
    reg [ 5:0] inst_resp_buf_ecode;
    reg [ 8:0] inst_resp_buf_esubcode;
    reg [31:0] inst_resp_buf_badv;
    reg        drop_pending_response;

    wire fetch_output_ready = !fetch_hold && !fetch_flush;
    wire inst_response_valid = inst_req_pending;
    wire response_slot_available = !inst_resp_buf_valid ||
                                   (fetch_output_ready && !inst_req_pending);
    wire can_issue_fetch = cpu_en && !fetch_hold && !fetch_flush &&
                           !drop_pending_response && response_slot_available;
    assign fetch_issue_fire = can_issue_fetch;

    wire fetch_adef = |pc[1:0];
    assign inst_sram_en = fetch_issue_fire && !fetch_adef;
    assign inst_sram_addr = pc;
    assign inst_req_pending_o = inst_req_pending;

    wire [31:0] response_inst = inst_req_from_mem ? inst_rdata : 32'b0;
    assign if_valid = inst_resp_buf_valid || inst_response_valid;
    assign if_pc = inst_resp_buf_valid ? inst_resp_buf_pc : inst_req_pc;
    assign if_pc_plus4 = inst_resp_buf_valid ? inst_resp_buf_pc_plus4 :
                         inst_req_pc_plus4;
    assign if_inst = inst_resp_buf_valid ? inst_resp_buf_data : response_inst;
    assign if_exc_valid = inst_resp_buf_valid ? inst_resp_buf_exc_valid :
                          inst_req_exc_valid;
    assign if_ecode = inst_resp_buf_valid ? inst_resp_buf_ecode : inst_req_ecode;
    assign if_esubcode = inst_resp_buf_valid ? inst_resp_buf_esubcode :
                         inst_req_esubcode;
    assign if_badv = inst_resp_buf_valid ? inst_resp_buf_badv : inst_req_badv;

    assign fetch_resume_pc = inst_resp_buf_valid ? inst_resp_buf_pc :
                             inst_req_pending ? inst_req_pc : pc;

    always @(posedge clk) begin
        if (!resetn) begin
            inst_req_pending <= 1'b0;
            inst_resp_buf_valid <= 1'b0;
            drop_pending_response <= 1'b0;
        end else if (cpu_en) begin
            if (fetch_flush) begin
                inst_resp_buf_valid <= 1'b0;
                drop_pending_response <= inst_req_pending;
                inst_req_pending <= 1'b0;
            end else begin
                if (drop_pending_response)
                    drop_pending_response <= 1'b0;

                if (inst_resp_buf_valid && fetch_output_ready) begin
                    if (inst_response_valid) begin
                        inst_resp_buf_valid <= 1'b1;
                        inst_resp_buf_data <= response_inst;
                        inst_resp_buf_pc <= inst_req_pc;
                        inst_resp_buf_pc_plus4 <= inst_req_pc_plus4;
                        inst_resp_buf_exc_valid <= inst_req_exc_valid;
                        inst_resp_buf_ecode <= inst_req_ecode;
                        inst_resp_buf_esubcode <= inst_req_esubcode;
                        inst_resp_buf_badv <= inst_req_badv;
                    end else begin
                        inst_resp_buf_valid <= 1'b0;
                    end
                end else if (!inst_resp_buf_valid && inst_response_valid &&
                             !fetch_output_ready) begin
                    inst_resp_buf_valid <= 1'b1;
                    inst_resp_buf_data <= response_inst;
                    inst_resp_buf_pc <= inst_req_pc;
                    inst_resp_buf_pc_plus4 <= inst_req_pc_plus4;
                    inst_resp_buf_exc_valid <= inst_req_exc_valid;
                    inst_resp_buf_ecode <= inst_req_ecode;
                    inst_resp_buf_esubcode <= inst_req_esubcode;
                    inst_resp_buf_badv <= inst_req_badv;
                end

                inst_req_pending <= fetch_issue_fire;
                if (fetch_issue_fire) begin
                    inst_req_pc <= pc;
                    inst_req_pc_plus4 <= pc_plus4;
                    inst_req_from_mem <= !fetch_adef;
                    inst_req_exc_valid <= fetch_adef;
                    inst_req_ecode <= fetch_adef ? `ECODE_ADE : 6'b0;
                    inst_req_esubcode <= 9'b0;
                    inst_req_badv <= fetch_adef ? pc : 32'b0;
                end
            end
        end
    end
endmodule
