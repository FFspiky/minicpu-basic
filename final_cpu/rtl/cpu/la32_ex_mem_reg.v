`timescale 1ns / 1ps

module la32_ex_mem_reg #(
    parameter PAYLOAD_WIDTH = 512
)(
    input  wire                     clk,
    input  wire                     resetn,
    input  wire                     cpu_en,
    input  wire                     flush,
    input  wire                     allowin,
    input  wire                     in_valid,
    input  wire [PAYLOAD_WIDTH-1:0] in_payload,
    input  wire                     request_fire,
    output reg                      out_valid,
    output reg  [PAYLOAD_WIDTH-1:0] out_payload,
    output reg                      request_sent
);
    always @(posedge clk) begin
        if (!resetn) begin
            out_valid    <= 1'b0;
            out_payload  <= {PAYLOAD_WIDTH{1'b0}};
            request_sent <= 1'b0;
        end
        else if (cpu_en) begin
            if (flush) begin
                out_valid    <= 1'b0;
                request_sent <= 1'b0;
            end
            else if (allowin) begin
                out_valid    <= in_valid;
                out_payload  <= in_payload;
                request_sent <= 1'b0;
            end
            else if (request_fire) begin
                request_sent <= 1'b1;
            end
        end
    end
endmodule
