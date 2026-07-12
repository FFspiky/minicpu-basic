`timescale 1ns / 1ps

module la32_pipeline_control(
    input  wire fs_valid,
    input  wire ds_valid,
    input  wire es_valid,
    input  wire ms_valid,
    input  wire ws_valid,
    input  wire ds_load_hazard,
    input  wire ds_serial,
    input  wire older_serial,
    input  wire ms_exception,
    input  wire ms_mem_op,
    input  wire ms_mem_req_sent,
    input  wire es_muldiv_wait,
    output wire ms_ready_go,
    output wire ms_allowin,
    output wire es_ready_go,
    output wire es_allowin,
    output wire ds_ready_go,
    output wire ds_allowin,
    output wire fs_allowin
);

    assign ms_ready_go = !ms_valid | ms_exception | !ms_mem_op |
                         ms_mem_req_sent;
    assign ms_allowin  = !ms_valid | ms_ready_go;
    assign es_ready_go = !es_muldiv_wait;
    assign es_allowin  = !es_valid | (es_ready_go & ms_allowin);
    assign ds_ready_go = !ds_load_hazard & !older_serial &
                         (!ds_serial | (!es_valid & !ms_valid & !ws_valid));
    assign ds_allowin  = !ds_valid | (ds_ready_go & es_allowin);
    assign fs_allowin  = !fs_valid | ds_allowin;

endmodule
