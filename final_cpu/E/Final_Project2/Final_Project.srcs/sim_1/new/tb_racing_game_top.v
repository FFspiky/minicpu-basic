`timescale 1ns/1ps

module tb_racing_game_top;

    // =========================================================
    // DUT IO
    // =========================================================
    reg         clk;
    reg         rst_n;

    wire [3:0]  key_col;
    reg  [3:0]  key_row;

    wire [15:0] lcd_db;
    wire        lcd_wr;
    wire        lcd_rs;
    wire        lcd_cs;
    wire        lcd_rd;
    wire        lcd_rst;
    wire        lcd_bl_ctr;

    wire [15:0] leds;
    wire [7:0]  seg_an;
    wire [7:0]  seg_cat;

    // =========================================================
    // Instantiate DUT
    // =========================================================
    racing_game_top dut (
        .clk      (clk),
        .rst_n    (rst_n),

        .key_col  (key_col),
        .key_row  (key_row),

        .lcd_db   (lcd_db),
        .lcd_wr   (lcd_wr),
        .lcd_rs   (lcd_rs),
        .lcd_cs   (lcd_cs),
        .lcd_rd   (lcd_rd),
        .lcd_rst  (lcd_rst),
        .lcd_bl_ctr(lcd_bl_ctr),

        .leds     (leds),
        .seg_an   (seg_an),
        .seg_cat  (seg_cat)
    );

    // =========================================================
    // Optional: speed up simulation by reducing LCD resolution
    // (Your lcd_nt35510_driver has parameters H_RES/V_RES)
    // =========================================================
    // 注意：这会让"画面逻辑仍在"，但像素循环更快跑完，仿真速度大幅提升
    defparam dut.u_lcd.H_RES = 80;
    defparam dut.u_lcd.V_RES = 48;

    // =========================================================
    // Clock: 100MHz => 10ns period
    // =========================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // =========================================================
    // Reset
    // =========================================================
    initial begin
        rst_n   = 1'b0;
        key_row = 4'b1111;   // row is pulled-up (inactive high)
        #200;
        rst_n = 1'b1;
    end

    // =========================================================
    // Matrix keypad press emulation
    //
    // Your scanner mapping (from your code):
    //  UP   : (col_out[2]==0 && row_in[2]==0)  // Col3, Row3
    //  LEFT : (col_out[1]==0 && row_in[3]==0)  // Col2, Row4
    //  DOWN : (col_out[2]==0 && row_in[3]==0)  // Col3, Row4
    //  RIGHT: (col_out[3]==0 && row_in[3]==0)  // Col4, Row4
    //
    // In simulation we "press" a key by pulling the correct row low
    // only when the corresponding column is currently active low.
    // =========================================================
    localparam KEY_NONE  = 3'd0;
    localparam KEY_UP    = 3'd1;
    localparam KEY_LEFT  = 3'd2;
    localparam KEY_DOWN  = 3'd3;
    localparam KEY_RIGHT = 3'd4;

    reg [2:0] key_req;   // which key we want to press now

    always @(*) begin
        // default: no press
        key_row = 4'b1111;

        case (key_req)
            KEY_UP: begin
                if (key_col[2] == 1'b0) key_row[2] = 1'b0;
            end
            KEY_LEFT: begin
                if (key_col[1] == 1'b0) key_row[3] = 1'b0;
            end
            KEY_DOWN: begin
                if (key_col[2] == 1'b0) key_row[3] = 1'b0;
            end
            KEY_RIGHT: begin
                if (key_col[3] == 1'b0) key_row[3] = 1'b0;
            end
            default: begin
                // none
            end
        endcase
    end

    // =========================================================
    // Helpers: press for a duration (in ns)
    // =========================================================
    task automatic press_key(input [2:0] k, input integer duration_ns);
        begin
            key_req = k;
            #(duration_ns);
            key_req = KEY_NONE;
        end
    endtask

    // =========================================================
    // Main stimulus sequence
    // =========================================================
    initial begin
        key_req = KEY_NONE;

        // waveform dump (Vivado xsim supports $dumpfile/$dumpvars)
        // 如果你用 Vivado GUI，也可以不需要 dump
        $dumpfile("tb_racing_game_top.vcd");
        $dumpvars(0, tb_racing_game_top);

        // wait reset release
        @(posedge rst_n);

        // 给 LCD 初始化留一点时间（仿真分辨率已降，仍建议等一会）
        #2_000_000; // 2ms

        // 1) 任意键开始：按 UP 50ms
        press_key(KEY_UP, 50_000_000);

        // 2) 换道：右、右、左（每次按 30ms，中间隔 40ms）
        #40_000_000; press_key(KEY_RIGHT, 30_000_000);
        #40_000_000; press_key(KEY_RIGHT, 30_000_000);
        #40_000_000; press_key(KEY_LEFT,  30_000_000);

        // 3) 暂停：按 DOWN 30ms，再等 200ms
        #50_000_000; press_key(KEY_DOWN, 30_000_000);
        #200_000_000;

        // 4) 恢复：再按 DOWN 30ms
        press_key(KEY_DOWN, 30_000_000);

        // 5) 按住加速：UP 300ms
        #50_000_000; press_key(KEY_UP, 300_000_000);

        // 再跑一段时间观察 game_over/score/paused 等信号
        #1_000_000_000; // 1s

        $finish;
    end

endmodule
