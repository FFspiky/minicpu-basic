`timescale 1ns / 1ps
`default_nettype none

module game_leaderboard(
    input  wire         clk,
    input  wire         resetn,
    input  wire [31:0]  game_flags,
    input  wire [31:0]  game_score,
    input  wire [31:0]  game_score_bcd,
    input  wire         game_commit_toggle,
    output wire [127:0] scores_packed,
    output wire [159:0] scores_bcd_packed,
    output reg  [3:0]   score_count
);
    (* ASYNC_REG = "TRUE" *) reg commit_sync0;
    (* ASYNC_REG = "TRUE" *) reg commit_sync1;
    (* ASYNC_REG = "TRUE" *) reg commit_sync2;
    reg [2:0] capture_delay;
    reg       capture_pending;
    reg [31:0] sample_flags;
    reg [31:0] sample_score;
    reg [31:0] sample_score_bcd;
    reg        last_game_over;
    reg [15:0] scores [0:7];
    reg [19:0] bcd_scores [0:7];
    integer i;
    integer insert_pos;

    assign scores_packed = {scores[7], scores[6], scores[5], scores[4],
                            scores[3], scores[2], scores[1], scores[0]};
    assign scores_bcd_packed = {bcd_scores[7], bcd_scores[6], bcd_scores[5], bcd_scores[4],
                                bcd_scores[3], bcd_scores[2], bcd_scores[1], bcd_scores[0]};

    always @(*)
    begin
        insert_pos = 8;
        for (i = 0; i < 8; i = i + 1)
        begin
            if (insert_pos == 8 &&
                (i >= score_count || sample_score[15:0] > scores[i]))
            begin
                insert_pos = i;
            end
        end
    end

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            commit_sync0   <= 1'b0;
            commit_sync1   <= 1'b0;
            commit_sync2   <= 1'b0;
            capture_delay  <= 3'd0;
            capture_pending <= 1'b0;
            sample_flags   <= 32'd0;
            sample_score   <= 32'd0;
            sample_score_bcd <= 32'd0;
            last_game_over <= 1'b0;
            score_count    <= 4'd0;
            for (i = 0; i < 8; i = i + 1)
            begin
                scores[i] <= 16'd0;
                bcd_scores[i] <= 20'd0;
            end
        end
        else
        begin
            commit_sync0 <= game_commit_toggle;
            commit_sync1 <= commit_sync0;
            commit_sync2 <= commit_sync1;

            if (commit_sync1 ^ commit_sync2)
            begin
                capture_delay   <= 3'd4;
                capture_pending <= 1'b1;
            end
            else if (capture_pending && capture_delay != 0)
            begin
                capture_delay <= capture_delay - 1'b1;
            end
            else if (capture_pending)
            begin
                sample_flags <= game_flags;
                sample_score <= game_score;
                sample_score_bcd <= game_score_bcd;
                capture_pending <= 1'b0;
            end
            else if (sample_flags == game_flags && sample_score == game_score &&
                     sample_score_bcd == game_score_bcd)
            begin
                if (sample_flags[2] && !last_game_over && insert_pos < 8)
                begin
                    for (i = 7; i > 0; i = i - 1)
                    begin
                        if (i > insert_pos)
                        begin
                            scores[i] <= scores[i - 1];
                            bcd_scores[i] <= bcd_scores[i - 1];
                        end
                    end
                    scores[insert_pos] <= sample_score[15:0];
                    bcd_scores[insert_pos] <= sample_score_bcd[19:0];
                    if (score_count < 8)
                    begin
                        score_count <= score_count + 1'b1;
                    end
                end
                last_game_over <= sample_flags[2];
                sample_flags <= 32'hffff_ffff;
            end
        end
    end
endmodule

`default_nettype wire
