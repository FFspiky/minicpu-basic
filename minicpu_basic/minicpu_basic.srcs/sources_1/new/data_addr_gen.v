`timescale 1ns / 1ps

module data_addr_gen(
    input  [31:0] byte_addr,
    output [15:0] word_addr
);

    assign word_addr = byte_addr[17:2];

endmodule
