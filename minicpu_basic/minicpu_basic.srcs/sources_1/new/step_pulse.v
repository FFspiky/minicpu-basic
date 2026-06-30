`timescale 1ns / 1ps

//==================================================
// 单步脉冲产生模块
// 输入 step_key 可以来自按钮或拨码开关
// 每次检测到 step_key 从 0 到 1，输出一个 clk 周期宽度的 step_pulse
//==================================================
module step_pulse(
    input  clk,
    input  resetn,
    input  step_key,
    output step_pulse
);

    // 两级同步，防止异步输入亚稳态
    reg step_sync_0;
    reg step_sync_1;

    always @(posedge clk) begin
        if (!resetn) begin
            step_sync_0 <= 1'b0;
            step_sync_1 <= 1'b0;
        end
        else begin
            step_sync_0 <= step_key;
            step_sync_1 <= step_sync_0;
        end
    end

    // 简单消抖
    reg [19:0] cnt;
    reg        stable_key;

    always @(posedge clk) begin
        if (!resetn) begin
            cnt        <= 20'd0;
            stable_key <= 1'b0;
        end
        else begin
            if (step_sync_1 == stable_key) begin
                cnt <= 20'd0;
            end
            else begin
                cnt <= cnt + 20'd1;

                // 100MHz 下约 10ms
                if (cnt == 20'd999_999) begin
                    stable_key <= step_sync_1;
                    cnt        <= 20'd0;
                end
            end
        end
    end

    // 上升沿检测
    reg stable_key_d;

    always @(posedge clk) begin
        if (!resetn) begin
            stable_key_d <= 1'b0;
        end
        else begin
            stable_key_d <= stable_key;
        end
    end

    assign step_pulse = stable_key & ~stable_key_d;

endmodule