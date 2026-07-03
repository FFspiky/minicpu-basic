`timescale 1ns / 1ps

module mini_cpu_display(
    input             clk,
    input             resetn,
    input             step_key,

    // LCD / 触摸屏接口
    output            lcd_rst,
    output            lcd_cs,
    output            lcd_rs,
    output            lcd_wr,
    output            lcd_rd,
    inout      [15:0] lcd_data_io,
    output            lcd_bl_ctr,
    inout             ct_int,
    inout             ct_sda,
    output            ct_scl,
    output            ct_rstn
);

    //==================================================
    // 1. step_key 同步 + 消抖 + 单步脉冲
    //==================================================

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

    reg [19:0] debounce_cnt;
    reg        stable_key;

    always @(posedge clk) begin
        if (!resetn) begin
            debounce_cnt <= 20'd0;
            stable_key   <= 1'b0;
        end
        else begin
            if (step_sync_1 == stable_key) begin
                debounce_cnt <= 20'd0;
            end
            else begin
                debounce_cnt <= debounce_cnt + 20'd1;

                // 100MHz 下约 10ms
                if (debounce_cnt == 20'd999_999) begin
                    stable_key   <= step_sync_1;
                    debounce_cnt <= 20'd0;
                end
            end
        end
    end

    reg stable_key_d;

    always @(posedge clk) begin
        if (!resetn) begin
            stable_key_d <= 1'b0;
        end
        else begin
            stable_key_d <= stable_key;
        end
    end

    wire cpu_en;
    assign cpu_en = stable_key & ~stable_key_d;

    //==================================================
    // 2. 单步计数器
    //==================================================

    reg [31:0] step_count;

    always @(posedge clk) begin
        if (!resetn) begin
            step_count <= 32'd0;
        end
        else if (cpu_en) begin
            step_count <= step_count + 32'd1;
        end
    end

    //==================================================
    // 3. LCD 接口信号
    //==================================================

    reg         display_valid;
    reg  [39:0] display_name;
    reg  [31:0] display_value;

    wire [5:0]  display_number;
    wire        input_valid;
    wire [31:0] input_value;

    //==================================================
    // 4. MiniCPU 精简调试信号
    //==================================================

    wire [31:0] debug_pc;
    wire [31:0] debug_inst;

    wire        debug_done;
    wire [31:0] debug_store_count;
    wire [15:0] debug_last_store_addr;
    wire [31:0] debug_last_store_data;

    //==================================================
    // 5. 实例化 MiniCPU
    //==================================================

    mini_cpu u_mini_cpu(
        .clk                   (clk),
        .resetn                (resetn),
        .cpu_en                (cpu_en),

        .debug_pc              (debug_pc),
        .debug_inst            (debug_inst),

        .debug_done            (debug_done),
        .debug_store_count     (debug_store_count),
        .debug_last_store_addr (debug_last_store_addr),
        .debug_last_store_data (debug_last_store_data)
    );

    //==================================================
    // 6. 实例化 LCD 模块
    //==================================================

    lcd_module u_lcd_module(
        .clk            (clk),
        .resetn         (resetn),

        .display_valid  (display_valid),
        .display_name   (display_name),
        .display_value  (display_value),
        .display_number (display_number),

        .input_valid    (input_valid),
        .input_value    (input_value),

        .lcd_rst        (lcd_rst),
        .lcd_cs         (lcd_cs),
        .lcd_rs         (lcd_rs),
        .lcd_wr         (lcd_wr),
        .lcd_rd         (lcd_rd),
        .lcd_data_io    (lcd_data_io),
        .lcd_bl_ctr     (lcd_bl_ctr),

        .ct_int         (ct_int),
        .ct_sda         (ct_sda),
        .ct_scl         (ct_scl),
        .ct_rstn        (ct_rstn)
    );

    //==================================================
    // 7. 精简 LCD 显示页面
    //==================================================
    //
    // 1: PC    当前 PC
    // 2: INST  当前指令
    // 3: STEP  单步次数
    // 4: DONE  是否执行过 st.w
    // 5: STCNT store 次数
    // 6: LSTA  最后一次 store 地址
    // 7: LSTD  最后一次 store 数据
    // 8: CPUE  当前 cpu_en 脉冲
    //
    //==================================================

    always @(*) begin
        case (display_number)
            6'd1: begin
                display_valid = 1'b1;
                display_name  = " PC  ";
                display_value = debug_pc;
            end

            6'd2: begin
                display_valid = 1'b1;
                display_name  = "INST ";
                display_value = debug_inst;
            end

            6'd3: begin
                display_valid = 1'b1;
                display_name  = "STEP ";
                display_value = step_count;
            end

            6'd4: begin
                display_valid = 1'b1;
                display_name  = "DONE ";
                display_value = {31'd0, debug_done};
            end

            6'd5: begin
                display_valid = 1'b1;
                display_name  = "STCNT";
                display_value = debug_store_count;
            end

            6'd6: begin
                display_valid = 1'b1;
                display_name  = "LSTA ";
                display_value = {16'd0, debug_last_store_addr};
            end

            6'd7: begin
                display_valid = 1'b1;
                display_name  = "LSTD ";
                display_value = debug_last_store_data;
            end

            6'd8: begin
                display_valid = 1'b1;
                display_name  = "CPUE ";
                display_value = {31'd0, cpu_en};
            end

            default: begin
                display_valid = 1'b0;
                display_name  = 40'd0;
                display_value = 32'd0;
            end
        endcase
    end

endmodule