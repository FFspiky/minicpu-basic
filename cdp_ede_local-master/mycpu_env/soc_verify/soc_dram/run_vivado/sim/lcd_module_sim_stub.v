`timescale 1ns / 1ps
`default_nettype none

module lcd_module(
    input  wire        clk,
    input  wire        resetn,

    input  wire        display_valid,
    input  wire [39:0] display_name,
    input  wire [31:0] display_value,
    output reg  [5 :0] display_number,

    output reg         input_valid,
    output reg  [31:0] input_value,

    output wire        lcd_rst,
    output wire        lcd_cs,
    output wire        lcd_rs,
    output wire        lcd_wr,
    output wire        lcd_rd,
    inout  wire [15:0] lcd_data_io,
    output wire        lcd_bl_ctr,

    inout  wire        ct_int,
    inout  wire        ct_sda,
    output wire        ct_scl,
    output wire        ct_rstn
);

    reg [7:0] page_timer;

    always @(posedge clk)
    begin
        if (!resetn)
        begin
            display_number <= 6'd1;
            input_valid    <= 1'b0;
            input_value    <= 32'd0;
            page_timer     <= 8'd0;
        end
        else
        begin
            input_valid <= 1'b0;
            page_timer  <= page_timer + 8'd1;

            if (page_timer == 8'hff)
            begin
                display_number <= (display_number == 6'd10) ? 6'd1 : display_number + 6'd1;
            end
        end
    end

    assign lcd_rst     = resetn;
    assign lcd_cs      = 1'b1;
    assign lcd_rs      = display_valid;
    assign lcd_wr      = 1'b1;
    assign lcd_rd      = 1'b1;
    assign lcd_bl_ctr  = 1'b1;
    assign lcd_data_io = 16'hzzzz;
    assign ct_int      = 1'bz;
    assign ct_sda      = 1'bz;
    assign ct_scl      = 1'b1;
    assign ct_rstn     = resetn;

    wire unused_display = &{1'b0, display_name, display_value};

endmodule

`default_nettype wire
