`timescale 1ns / 1ps

module la32_forward_unit(
    input  wire        ds_valid,
    input  wire        use_rj,
    input  wire        use_rk,
    input  wire        use_rd,
    input  wire [ 4:0] rj,
    input  wire [ 4:0] rk,
    input  wire [ 4:0] rd,
    input  wire [31:0] raw_rj,
    input  wire [31:0] raw_rk,
    input  wire [31:0] raw_rd,
    input  wire        es_load,
    input  wire        es_forward_valid,
    input  wire [ 4:0] es_waddr,
    input  wire [31:0] es_wdata,
    input  wire        ms_valid,
    input  wire        ms_load,
    input  wire        ms_rf_we,
    input  wire        ms_forward_valid,
    input  wire [ 4:0] ms_waddr,
    input  wire [31:0] ms_wdata,
    input  wire        ws_forward_valid,
    input  wire [ 4:0] ws_waddr,
    input  wire [31:0] ws_wdata,
    output wire        load_hazard,
    output wire [31:0] rj_value,
    output wire [31:0] rk_value,
    output wire [31:0] rd_value
);

    wire rj_wait_load = use_rj & (rj != 5'b0) &
                        ((es_load & (es_waddr == rj)) |
                         (ms_valid & ms_load & ms_rf_we & (ms_waddr == rj)));
    wire rk_wait_load = use_rk & (rk != 5'b0) &
                        ((es_load & (es_waddr == rk)) |
                         (ms_valid & ms_load & ms_rf_we & (ms_waddr == rk)));
    wire rd_wait_load = use_rd & (rd != 5'b0) &
                        ((es_load & (es_waddr == rd)) |
                         (ms_valid & ms_load & ms_rf_we & (ms_waddr == rd)));

    assign load_hazard = ds_valid & (rj_wait_load | rk_wait_load |
                                     rd_wait_load);

    assign rj_value = (rj == 5'b0) ? 32'b0 :
                      (es_forward_valid & (es_waddr == rj)) ? es_wdata :
                      (ms_forward_valid & (ms_waddr == rj)) ? ms_wdata :
                      (ws_forward_valid & (ws_waddr == rj)) ? ws_wdata : raw_rj;
    assign rk_value = (rk == 5'b0) ? 32'b0 :
                      (es_forward_valid & (es_waddr == rk)) ? es_wdata :
                      (ms_forward_valid & (ms_waddr == rk)) ? ms_wdata :
                      (ws_forward_valid & (ws_waddr == rk)) ? ws_wdata : raw_rk;
    assign rd_value = (rd == 5'b0) ? 32'b0 :
                      (es_forward_valid & (es_waddr == rd)) ? es_wdata :
                      (ms_forward_valid & (ms_waddr == rd)) ? ms_wdata :
                      (ws_forward_valid & (ws_waddr == rd)) ? ws_wdata : raw_rd;

endmodule
