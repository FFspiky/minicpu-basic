`timescale 1ns / 1ps
`default_nettype none

module tb_game_peripherals;
    reg clk;
    reg resetn;
    reg ps2_clk;
    reg ps2_data;
    wire [15:0] game_keys;
    wire [7:0] last_scan_code;
    wire scan_valid;

    reg [31:0] game_car;
    reg [31:0] game_obs;
    reg [31:0] game_obs1;
    reg [31:0] game_obs2;
    reg [31:0] game_bonus;
    reg [31:0] game_flags;
    reg [31:0] game_score;
    reg game_commit_toggle;
    wire [127:0] scores_packed;
    wire [159:0] scores_bcd_packed;
    wire [3:0] score_count;
    wire vga_hsync;
    wire vga_vsync;
    wire [3:0] vga_r;
    wire [3:0] vga_g;
    wire [3:0] vga_b;
    reg  [9:0] leaderboard_x;
    reg  [8:0] leaderboard_y;
    wire [15:0] leaderboard_pixel;

    ps2_game_keyboard u_keyboard(
        .clk(clk), .resetn(resetn), .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .game_keys(game_keys), .last_scan_code(last_scan_code), .scan_valid(scan_valid)
    );

    game_leaderboard u_leaderboard(
        .clk(clk), .resetn(resetn), .game_flags(game_flags), .game_score(game_score),
        .game_score_bcd(game_score),
        .game_commit_toggle(game_commit_toggle),
        .scores_packed(scores_packed), .scores_bcd_packed(scores_bcd_packed),
        .score_count(score_count)
    );

    vga_game_top u_vga(
        .clk(clk), .resetn(resetn), .game_car(game_car), .game_obs(game_obs),
        .game_obs1(game_obs1), .game_obs2(game_obs2), .game_bonus(game_bonus),
        .game_flags(game_flags), .game_score(game_score),
        .game_commit_toggle(game_commit_toggle),
        .current_score_bcd(game_score[19:0]),
        .leaderboard_bcd_scores(scores_bcd_packed),
        .leaderboard_count(score_count),
        .vga_hsync(vga_hsync), .vga_vsync(vga_vsync),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    leaderboard_pixel_renderer u_leaderboard_renderer(
        .clk(clk), .resetn(resetn),
        .x(leaderboard_x), .y(leaderboard_y),
        .scores_bcd_packed(160'h0000000000000000000000000000000000000300),
        .score_count(4'd1), .pixel(leaderboard_pixel)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task send_ps2_bit;
        input value;
        begin
            ps2_data = value;
            #80;
            ps2_clk = 1'b0;
            #80;
            ps2_clk = 1'b1;
            #80;
        end
    endtask

    task send_ps2_byte;
        input [7:0] value;
        integer i;
        reg parity;
        begin
            parity = ~(^value);
            send_ps2_bit(1'b0);
            for (i = 0; i < 8; i = i + 1) send_ps2_bit(value[i]);
            send_ps2_bit(parity);
            send_ps2_bit(1'b1);
            #200;
        end
    endtask

    task commit_game;
        input [31:0] flags;
        input [15:0] score;
        begin
            game_flags = flags;
            game_score = {16'd0, score};
            #40;
            game_commit_toggle = ~game_commit_toggle;
            #300;
        end
    endtask

    initial begin
        resetn = 1'b0;
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        game_car = 32'h0000_0d21;
        game_obs = 32'd0;
        game_obs1 = 32'd0;
        game_obs2 = 32'd0;
        game_bonus = 32'd0;
        game_flags = 32'd0;
        game_score = 32'd0;
        game_commit_toggle = 1'b0;
        leaderboard_x = 10'd0;
        leaderboard_y = 9'd0;
        #100;
        resetn = 1'b1;
        #100;

        send_ps2_byte(8'he0);
        send_ps2_byte(8'h75);
        if (!game_keys[10]) begin $display("FAIL: PS/2 Up make"); $fatal; end
        send_ps2_byte(8'he0);
        send_ps2_byte(8'hf0);
        send_ps2_byte(8'h75);
        if (game_keys[10]) begin $display("FAIL: PS/2 Up break"); $fatal; end

        send_ps2_byte(8'h29);
        if (!game_keys[12]) begin $display("FAIL: PS/2 Space make"); $fatal; end
        send_ps2_byte(8'hf0);
        send_ps2_byte(8'h29);
        if (game_keys[12]) begin $display("FAIL: PS/2 Space break"); $fatal; end

        commit_game(32'd0, 16'd0);
        commit_game(32'h0000_0004, 16'd100);
        commit_game(32'd0, 16'd0);
        commit_game(32'h0000_0004, 16'd300);
        commit_game(32'd0, 16'd0);
        commit_game(32'h0000_0004, 16'd200);
        #200;
        if (score_count != 3 || scores_packed[15:0] != 300 ||
            scores_packed[31:16] != 200 || scores_packed[47:32] != 100)
        begin
            $display("FAIL: leaderboard count=%0d scores=%0d,%0d,%0d",
                     score_count, scores_packed[15:0], scores_packed[31:16],
                     scores_packed[47:32]);
            $fatal;
        end

        leaderboard_x = 10'd190;
        leaderboard_y = 9'd100;
        #50;
        if (leaderboard_pixel != 16'h4a69) begin
            $display("FAIL: pipelined leaderboard border pixel=%h", leaderboard_pixel);
            $fatal;
        end
        leaderboard_x = 10'd0;
        leaderboard_y = 9'd0;
        #50;
        if (leaderboard_pixel != 16'h0000) begin
            $display("FAIL: pipelined leaderboard background pixel=%h", leaderboard_pixel);
            $fatal;
        end
        leaderboard_x = 10'd228;
        leaderboard_y = 9'd40;
        #50;
        if (leaderboard_pixel != 16'hfec0) begin
            $display("FAIL: pipelined leaderboard title pixel=%h", leaderboard_pixel);
            $fatal;
        end

        force u_vga.h_count = 10'd655;
        #1;
        if (!vga_hsync) begin $display("FAIL: VGA hsync front porch"); $fatal; end
        force u_vga.h_count = 10'd656;
        #1;
        if (vga_hsync) begin $display("FAIL: VGA hsync start"); $fatal; end
        force u_vga.h_count = 10'd751;
        #1;
        if (vga_hsync) begin $display("FAIL: VGA hsync width"); $fatal; end
        force u_vga.h_count = 10'd752;
        #1;
        if (!vga_hsync) begin $display("FAIL: VGA hsync end"); $fatal; end
        force u_vga.v_count = 10'd489;
        #1;
        if (!vga_vsync) begin $display("FAIL: VGA vsync front porch"); $fatal; end
        force u_vga.v_count = 10'd490;
        #1;
        if (vga_vsync) begin $display("FAIL: VGA vsync start"); $fatal; end
        force u_vga.v_count = 10'd491;
        #1;
        if (vga_vsync) begin $display("FAIL: VGA vsync width"); $fatal; end
        force u_vga.v_count = 10'd492;
        #1;
        if (!vga_vsync) begin $display("FAIL: VGA vsync end"); $fatal; end
        release u_vga.h_count;
        release u_vga.v_count;

        force u_vga.h_count = 10'd799;
        force u_vga.v_count = 10'd0;
        force u_vga.pixel_div = 2'd3;
        u_vga.rotated_game_x = 10'd799;
        u_vga.rotated_x_phase = 2'd0;
        @(posedge clk); #1;
        if (u_vga.rotated_game_x != 10'd798 || u_vga.rotated_x_phase != 2'd2) begin
            $display("FAIL: VGA CCW row 1 mapping x=%0d phase=%0d",
                     u_vga.rotated_game_x, u_vga.rotated_x_phase);
            $fatal;
        end
        force u_vga.v_count = 10'd1;
        @(posedge clk); #1;
        if (u_vga.rotated_game_x != 10'd796 || u_vga.rotated_x_phase != 2'd1) begin
            $display("FAIL: VGA CCW row 2 mapping x=%0d phase=%0d",
                     u_vga.rotated_game_x, u_vga.rotated_x_phase);
            $fatal;
        end
        force u_vga.v_count = 10'd2;
        @(posedge clk); #1;
        if (u_vga.rotated_game_x != 10'd794 || u_vga.rotated_x_phase != 2'd0) begin
            $display("FAIL: VGA CCW row 3 mapping x=%0d phase=%0d",
                     u_vga.rotated_game_x, u_vga.rotated_x_phase);
            $fatal;
        end
        force u_vga.h_count = 10'd0;
        #1;
        if (u_vga.game_y != 9'd0) begin $display("FAIL: VGA CCW left edge"); $fatal; end
        force u_vga.h_count = 10'd343;
        #1;
        if (u_vga.game_y != 9'd479) begin $display("FAIL: VGA CCW right edge"); $fatal; end
        if (!u_vga.game_region) begin $display("FAIL: VGA game right edge not active"); $fatal; end
        force u_vga.h_count = 10'd344;
        #1;
        if (u_vga.game_region || u_vga.sidebar_region || u_vga.pixel_color != 16'h0000) begin
            $display("FAIL: VGA gutter is not black"); $fatal;
        end
        force u_vga.h_count = 10'd352;
        #1;
        if (!u_vga.sidebar_region) begin $display("FAIL: VGA sidebar start"); $fatal; end

        // Sidebar text colors and placement use the frame-latched snapshots.
        force u_vga.render_current_score_bcd = 20'h12345;
        force u_vga.render_leaderboard_bcd_scores =
            160'h00000000000000000000000000000000000054321;
        force u_vga.render_leaderboard_count = 4'd1;
        force u_vga.h_count = 10'd454;
        force u_vga.v_count = 10'd34;
        #1;
        if (u_vga.sidebar_pixel_color != 16'h07ff) begin
            $display("FAIL: VGA SCORE title pixel=%h", u_vga.sidebar_pixel_color); $fatal;
        end
        force u_vga.h_count = 10'd418;
        force u_vga.v_count = 10'd78;
        #1;
        if (u_vga.sidebar_pixel_color != 16'hfec0) begin
            $display("FAIL: VGA current score pixel=%h", u_vga.sidebar_pixel_color); $fatal;
        end
        force u_vga.h_count = 10'd430;
        force u_vga.v_count = 10'd210;
        #1;
        if (u_vga.sidebar_pixel_color != 16'hffff) begin
            $display("FAIL: VGA leaderboard row pixel=%h", u_vga.sidebar_pixel_color); $fatal;
        end

        // Empty entries use dashes, while a full table renders the eighth score.
        force u_vga.render_leaderboard_count = 4'd0;
        force u_vga.h_count = 10'd499;
        force u_vga.v_count = 10'd219;
        #1;
        if (u_vga.sidebar_pixel_color != 16'hffff) begin
            $display("FAIL: VGA empty leaderboard placeholder pixel=%h", u_vga.sidebar_pixel_color); $fatal;
        end
        force u_vga.render_leaderboard_bcd_scores =
            160'h9876500000000000000000000000000000000000;
        force u_vga.render_leaderboard_count = 4'd8;
        force u_vga.h_count = 10'd481;
        force u_vga.v_count = 10'd427;
        #1;
        if (u_vga.sidebar_pixel_color != 16'hffff) begin
            $display("FAIL: VGA eighth leaderboard score pixel=%h", u_vga.sidebar_pixel_color); $fatal;
        end

        // The board-facing sidebar pixel changes only at a pixel boundary.
        force u_vga.h_count = 10'd454;
        force u_vga.v_count = 10'd34;
        force u_vga.pixel_div = 2'd3;
        @(posedge clk); #1;
        if (u_vga.sidebar_pixel_latched != 16'h07ff) begin
            $display("FAIL: VGA sidebar pixel was not latched"); $fatal;
        end
        force u_vga.h_count = 10'd344;
        force u_vga.pixel_div = 2'd0;
        @(posedge clk); #1;
        if (u_vga.sidebar_pixel_latched != 16'h07ff) begin
            $display("FAIL: VGA sidebar pixel changed between pixel boundaries"); $fatal;
        end
        release u_vga.render_current_score_bcd;
        release u_vga.render_leaderboard_bcd_scores;
        release u_vga.render_leaderboard_count;

        // Inputs remain pending until the VGA frame boundary.
        game_score = 32'h0005_4321;
        #20;
        if (u_vga.render_current_score_bcd != 20'h12345) begin
            $display("FAIL: VGA score changed in the middle of a frame"); $fatal;
        end
        force u_vga.h_count = 10'd799;
        force u_vga.v_count = 10'd524;
        force u_vga.pixel_div = 2'd3;
        @(posedge clk); #1;
        if (u_vga.render_current_score_bcd != 20'h54321) begin
            $display("FAIL: VGA score did not latch at frame boundary"); $fatal;
        end
        release u_vga.h_count;
        release u_vga.v_count;
        release u_vga.pixel_div;

        $display("PASS: PS/2 keys, leaderboard, VGA timing, and CCW mapping checked");
        $finish;
    end
endmodule

`default_nettype wire
