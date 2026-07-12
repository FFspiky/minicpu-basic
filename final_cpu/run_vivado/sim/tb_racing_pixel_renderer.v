`timescale 1ns / 1ps
`default_nettype none

module tb_racing_pixel_renderer;
    reg  [9:0] x;
    reg  [8:0] y;
    reg        waiting_start;
    reg        paused;
    reg        game_over;
    wire [15:0] pixel;

    racing_pixel_renderer dut (
        .x(x), .y(y), .bg_scroll(10'd0),
        .car_lane(2'd1), .car_y(9'd100),
        .obs_lane(2'd0), .obs_x(10'd300), .obs_active(1'b1),
        .obs1_lane(2'd1), .obs1_x(10'd400), .obs1_active(1'b1),
        .obs2_lane(2'd2), .obs2_x(10'd500), .obs2_active(1'b1),
        .bonus_lane(2'd1), .bonus_x(10'd700), .bonus_active(1'b0),
        .game_enable(1'b1), .paused(paused), .game_over(game_over),
        .waiting_start(waiting_start), .bg_enable(1'b1),
        .score(16'd0), .speed_q8(16'd768), .difficulty_level(5'd0),
        .pixel(pixel)
    );

    task expect_pixel;
        input [9:0] tx;
        input [8:0] ty;
        input [15:0] expected;
        begin
            x = tx;
            y = ty;
            #1;
            if (pixel !== expected)
            begin
                $display("FAIL: pixel (%0d,%0d)=%h expected=%h", tx, ty, pixel, expected);
                $fatal;
            end
        end
    endtask

    initial
    begin
        waiting_start = 1'b0;
        paused = 1'b0;
        game_over = 1'b0;

        expect_pixel(10'd120, 9'd110, 16'hFCA0);
        expect_pixel(10'd310, 9'd70, 16'h001F);
        expect_pixel(10'd410, 9'd230, 16'h001F);
        expect_pixel(10'd510, 9'd390, 16'h001F);

        waiting_start = 1'b1;
        expect_pixel(10'd410, 9'd96, 16'h07E0);

        waiting_start = 1'b0;
        paused = 1'b1;
        expect_pixel(10'd410, 9'd160, 16'hFFE0);

        paused = 1'b0;
        game_over = 1'b1;
        expect_pixel(10'd410, 9'd100, 16'hF800);
        expect_pixel(10'd360, 9'd112, 16'h2104);

        $display("PASS: renderer objects and rotated messages checked");
        $finish;
    end
endmodule

`default_nettype wire
