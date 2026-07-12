`timescale 1ns / 1ps

module imm_extend(
    input  [2:0]  ext_op,
    input  [11:0] imm12,
    input  [15:0] offs16,
    input  [25:0] offs26,
    input  [4:0]  ui5,
    input  [19:0] si20,
    output reg [31:0] ext_imm
);

    localparam EXT_NONE = 3'b000;
    localparam EXT_SI12 = 3'b001;
    localparam EXT_UI5  = 3'b010;
    localparam EXT_BR16 = 3'b011;
    localparam EXT_BR26 = 3'b100;
    localparam EXT_SI20 = 3'b101;
    localparam EXT_UI12 = 3'b110;

    always @(*) begin
        case (ext_op)
            EXT_SI12: ext_imm = {{20{imm12[11]}}, imm12};
            EXT_UI5 : ext_imm = {27'b0, ui5};
            EXT_BR16: ext_imm = {{14{offs16[15]}}, offs16, 2'b00};
            EXT_BR26: ext_imm = {{4{offs26[25]}}, offs26, 2'b00};
            EXT_SI20: ext_imm = {si20, 12'b0};
            EXT_UI12: ext_imm = {20'b0, imm12};
            EXT_NONE: ext_imm = 32'b0;
            default : ext_imm = 32'b0;
        endcase
    end

endmodule
