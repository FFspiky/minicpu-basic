`timescale 1ns / 1ps
`default_nettype none

module tb_racing_pixel_renderer;
    reg  [9:0]  x;
    reg  [8:0]  y;
    wire [15:0] pixel;

    racing_pixel_renderer dut (
        .x            (x),
        .y            (y),
        .bg_scroll    (10'd0),
        .car_lane     (2'd1),
        .obs_lane     (2'd0),
        .obs_x        (10'd799),
        .obs_active   (1'b1),
        .bonus_lane   (2'd1),
        .bonus_x      (10'd799),
        .bonus_active (1'b0),
        .game_enable  (1'b1),
        .paused       (1'b0),
        .game_over    (1'b1),
        .bg_enable    (1'b1),
        .score        (16'd0),
        .speed_level  (16'd0),
        .pixel        (pixel)
    );

    initial
    begin
        x = 10'd212;
        y = 9'd217;
        #1;
        if (pixel !== 16'hF800)
        begin
            $display("FAIL: GAME OVER text pixel is not red, pixel=%h", pixel);
            $fatal;
        end

        x = 10'd400;
        y = 9'd240;
        #1;
        if (pixel === 16'hF800)
        begin
            $display("FAIL: GAME OVER spacing pixel should not be red");
            $fatal;
        end

        $display("PASS: racing_pixel_renderer GAME OVER text checked");
        $finish;
    end
endmodule

`default_nettype wire

