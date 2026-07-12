`timescale 1ns / 1ps

module la32_lsu(
    input  wire [31:0] addr,
    input  wire [31:0] store_data,
    input  wire [31:0] load_data,
    input  wire        op_ld_b,
    input  wire        op_ld_h,
    input  wire        op_ld_w,
    input  wire        op_ld_bu,
    input  wire        op_ld_hu,
    input  wire        op_st_b,
    input  wire        op_st_h,
    input  wire        op_st_w,
    output wire        align_error,
    output reg  [ 3:0] store_we,
    output reg  [31:0] store_wdata,
    output reg  [31:0] load_result
);

    wire is_half = op_ld_h | op_ld_hu | op_st_h;
    wire is_word = op_ld_w | op_st_w;
    wire is_store = op_st_b | op_st_h | op_st_w;

    assign align_error = (is_half & addr[0]) | (is_word & |addr[1:0]);

    always @(*) begin
        store_we    = 4'b0000;
        store_wdata = 32'b0;
        if (is_store) begin
            if (op_st_b) begin
                store_we    = 4'b0001 << addr[1:0];
                store_wdata = {4{store_data[7:0]}} << {addr[1:0], 3'b000};
            end
            else if (op_st_h) begin
                store_we    = addr[1] ? 4'b1100 : 4'b0011;
                store_wdata = {2{store_data[15:0]}} << {addr[1], 4'b0000};
            end
            else begin
                store_we    = 4'b1111;
                store_wdata = store_data;
            end
        end
    end

    always @(*) begin
        case (addr[1:0])
            2'b00: load_result = {{24{load_data[ 7]}}, load_data[ 7: 0]};
            2'b01: load_result = {{24{load_data[15]}}, load_data[15: 8]};
            2'b10: load_result = {{24{load_data[23]}}, load_data[23:16]};
            default: load_result = {{24{load_data[31]}}, load_data[31:24]};
        endcase

        if (op_ld_bu) begin
            case (addr[1:0])
                2'b00: load_result = {24'b0, load_data[ 7: 0]};
                2'b01: load_result = {24'b0, load_data[15: 8]};
                2'b10: load_result = {24'b0, load_data[23:16]};
                default: load_result = {24'b0, load_data[31:24]};
            endcase
        end
        else if (op_ld_h) begin
            load_result = addr[1] ? {{16{load_data[31]}}, load_data[31:16]} :
                                    {{16{load_data[15]}}, load_data[15: 0]};
        end
        else if (op_ld_hu) begin
            load_result = addr[1] ? {16'b0, load_data[31:16]} :
                                    {16'b0, load_data[15: 0]};
        end
        else if (op_ld_w) begin
            load_result = load_data;
        end
    end

endmodule
