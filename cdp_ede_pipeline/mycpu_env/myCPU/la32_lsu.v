`timescale 1ns / 1ps
`include "la32_defs.vh"

module la32_lsu(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_en,
    input  wire        global_flush,
    input  wire        stage_advance,
    input  wire        mem_valid,
    input  wire        mem_exc_valid,
    input  wire [ 3:0] mem_op,
    input  wire [31:0] addr,
    input  wire [31:0] store_data,
    input  wire [31:0] data_sram_rdata,
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire        mem_wait,
    output wire        mem_complete,
    output wire        load_result_valid,
    output reg  [31:0] load_result,
    output wire        ale,
    output wire [31:0] ale_badv,
    output wire        load_req_fire,
    output wire        store_req_fire,
    output wire        store_complete
);
    wire is_load = mem_op == `MEM_LDB || mem_op == `MEM_LDH ||
                   mem_op == `MEM_LDW || mem_op == `MEM_LDBU ||
                   mem_op == `MEM_LDHU;
    wire is_store = mem_op == `MEM_STB || mem_op == `MEM_STH ||
                    mem_op == `MEM_STW;
    wire half_op = mem_op == `MEM_LDH || mem_op == `MEM_LDHU ||
                   mem_op == `MEM_STH;
    wire word_op = mem_op == `MEM_LDW || mem_op == `MEM_STW;
    assign ale = mem_valid && !mem_exc_valid &&
                 ((half_op && addr[0]) || (word_op && |addr[1:0]));
    assign ale_badv = addr;
    wire mem_exception = mem_exc_valid || ale;

    reg data_req_pending;
    reg store_req_sent;
    wire data_response_valid = data_req_pending;
    assign load_result_valid = data_response_valid;
    assign store_complete = store_req_sent;

    assign load_req_fire = cpu_en && !global_flush && mem_valid && is_load && !mem_exception &&
                           !data_req_pending;
    assign store_req_fire = cpu_en && !global_flush && mem_valid && is_store && !mem_exception &&
                            !store_req_sent;

    reg [3:0] store_mask;
    reg [31:0] store_wdata;
    always @(*) begin
        store_mask = 4'b0;
        store_wdata = store_data;
        case (mem_op)
            `MEM_STB: begin
                store_mask = 4'b0001 << addr[1:0];
                store_wdata = {4{store_data[7:0]}};
            end
            `MEM_STH: begin
                store_mask = addr[1] ? 4'b1100 : 4'b0011;
                store_wdata = {2{store_data[15:0]}};
            end
            `MEM_STW: begin
                store_mask = 4'b1111;
                store_wdata = store_data;
            end
            default: begin store_mask = 4'b0; store_wdata = store_data; end
        endcase
    end

    assign data_sram_en = load_req_fire || store_req_fire;
    assign data_sram_we = store_req_fire ? store_mask : 4'b0;
    assign data_sram_addr = addr;
    assign data_sram_wdata = store_wdata;

    always @(*) begin
        case (mem_op)
            `MEM_LDB: begin
                case (addr[1:0])
                    2'd0: load_result = {{24{data_sram_rdata[7]}},data_sram_rdata[7:0]};
                    2'd1: load_result = {{24{data_sram_rdata[15]}},data_sram_rdata[15:8]};
                    2'd2: load_result = {{24{data_sram_rdata[23]}},data_sram_rdata[23:16]};
                    default: load_result = {{24{data_sram_rdata[31]}},data_sram_rdata[31:24]};
                endcase
            end
            `MEM_LDBU: begin
                case (addr[1:0])
                    2'd0: load_result = {24'b0,data_sram_rdata[7:0]};
                    2'd1: load_result = {24'b0,data_sram_rdata[15:8]};
                    2'd2: load_result = {24'b0,data_sram_rdata[23:16]};
                    default: load_result = {24'b0,data_sram_rdata[31:24]};
                endcase
            end
            `MEM_LDH: load_result = addr[1] ?
                {{16{data_sram_rdata[31]}},data_sram_rdata[31:16]} :
                {{16{data_sram_rdata[15]}},data_sram_rdata[15:0]};
            `MEM_LDHU: load_result = addr[1] ?
                {16'b0,data_sram_rdata[31:16]} : {16'b0,data_sram_rdata[15:0]};
            default: load_result = data_sram_rdata;
        endcase
    end

    assign mem_complete = mem_exception || (mem_op == `MEM_NONE) ||
                          (is_load && load_result_valid) ||
                          (is_store && store_complete);
    assign mem_wait = mem_valid && (mem_op != `MEM_NONE) &&
                      !mem_exception && !mem_complete;

    always @(posedge clk) begin
        if (!resetn) begin
            data_req_pending <= 1'b0;
            store_req_sent <= 1'b0;
        end else if (cpu_en) begin
            if (global_flush || stage_advance) begin
                data_req_pending <= 1'b0;
                store_req_sent <= 1'b0;
            end else begin
                if (load_req_fire) data_req_pending <= 1'b1;
                if (store_req_fire) store_req_sent <= 1'b1;
            end
        end
    end
endmodule
