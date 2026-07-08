`timescale 1ns / 1ps

module data_addr_gen(
    input  [17:2] byte_addr,
    output [15:0] word_addr
);

    assign word_addr = byte_addr;

endmodule
