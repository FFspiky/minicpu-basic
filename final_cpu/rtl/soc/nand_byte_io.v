`timescale 1ns / 1ps
`default_nettype none

// One NAND asynchronous byte transaction.  At 50 MHz each state lasts 20 ns.
// Reads wait an extra cycle before sampling so the 20 ns maximum tREA is not
// sampled exactly on its worst-case boundary.
module nand_byte_io(
    input wire clk, input wire resetn,
    input wire start_write, input wire start_read,
    input wire write_cle, input wire write_ale,
    input wire [7:0] write_data,
    output reg [7:0] read_data, output reg busy, output reg done,
    inout wire [7:0] nand_io,
    output reg nand_cle, output reg nand_ale,
    output wire nand_ce_n, output reg nand_re_n, output reg nand_we_n
);
    localparam IDLE=0, WRITE_LOW=1, WRITE_HIGH=2,
               READ_LOW=3, READ_WAIT=4, READ_SAMPLE=5, READ_HIGH=6;
    reg [2:0] state;
    reg [7:0] io_out;
    reg io_oe;
    assign nand_io = io_oe ? io_out : 8'bz;
    assign nand_ce_n = 1'b0;

    always @(posedge clk)
    begin
        if(!resetn)
        begin
            state<=IDLE; busy<=0; done<=0; read_data<=0;
            nand_cle<=0; nand_ale<=0; nand_re_n<=1; nand_we_n<=1;
            io_out<=0; io_oe<=0;
        end
        else
        begin
            done<=0;
            case(state)
                IDLE:
                begin
                    busy<=0; nand_re_n<=1; nand_we_n<=1; io_oe<=0;
                    if(start_write)
                    begin
                        busy<=1; nand_cle<=write_cle; nand_ale<=write_ale;
                        io_out<=write_data; io_oe<=1; state<=WRITE_LOW;
                    end
                    else if(start_read)
                    begin
                        busy<=1; nand_cle<=0; nand_ale<=0; state<=READ_LOW;
                    end
                end
                WRITE_LOW: begin nand_we_n<=0; state<=WRITE_HIGH; end
                WRITE_HIGH:
                begin
                    nand_we_n<=1; nand_cle<=0; nand_ale<=0; io_oe<=0;
                    busy<=0; done<=1; state<=IDLE;
                end
                READ_LOW: begin nand_re_n<=0; state<=READ_WAIT; end
                READ_WAIT: begin state<=READ_SAMPLE; end
                READ_SAMPLE: begin read_data<=nand_io; state<=READ_HIGH; end
                READ_HIGH:
                begin nand_re_n<=1; busy<=0; done<=1; state<=IDLE; end
                default: state<=IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
