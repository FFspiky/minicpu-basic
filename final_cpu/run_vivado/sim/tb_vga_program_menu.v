`timescale 1ns / 1ps
`default_nettype none

module tb_vga_program_menu;
    reg clk = 1'b0;
    reg resetn = 1'b1;
    reg [1:0] led_rg0 = 2'd0;
    reg [1:0] led_rg1 = 2'd0;
    wire hsync, vsync;
    wire [3:0] r, g, b;

    vga_program_menu dut (
        .clk(clk), .resetn(resetn), .selected_slot(4'd0),
        .slot_valid(16'd0), .status(8'd0), .system_mode(2'd2),
        .led_rg0(led_rg0), .led_rg1(led_rg1),
        .vga_hsync(hsync), .vga_vsync(vsync),
        .vga_r(r), .vga_g(g), .vga_b(b)
    );

    always #5 clk = ~clk;

    task expect_first_character;
        input [7:0] expected;
        begin
            // Self-test status starts at character column 12, row 10.
            force dut.h_count = 10'd192;
            force dut.v_count = 10'd160;
            #1;
            if (dut.character !== expected) begin
                $display("FAIL led0=%0d led1=%0d character=%c expected=%c",
                         led_rg0, led_rg1, dut.character, expected);
                $fatal(1);
            end
            release dut.h_count;
            release dut.v_count;
        end
    endtask

    initial begin
        led_rg0 = 2'd1; led_rg1 = 2'd2; #1;
        expect_first_character("R");
        led_rg0 = 2'd2; led_rg1 = 2'd1; #1;
        expect_first_character("R");
        led_rg0 = 2'd1; led_rg1 = 2'd1; #1;
        expect_first_character("P");
        led_rg0 = 2'd2; led_rg1 = 2'd2; #1;
        expect_first_character("F");
        $display("PASS: EXP16 status is RUNNING until both LEDs agree");
        $finish;
    end
endmodule

`default_nettype wire
