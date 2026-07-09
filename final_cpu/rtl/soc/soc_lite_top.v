`default_nettype none

`define SIMU_USE_PLL 0

module soc_lite_top #(
    parameter SIMULATION  = 1'b0,
    parameter SINGLE_STEP = 1'b0,
    parameter [31:0] END_PC = 32'h1c000100
)
(
    input  wire        resetn,
    input  wire        clk,

    output wire [15:0] led,
    output wire [1 :0] led_rg0,
    output wire [1 :0] led_rg1,
    output wire [7 :0] num_csn,
    output wire [6 :0] num_a_g,
    output wire [31:0] num_data,
    input  wire [7 :0] switch,
    output wire [3 :0] btn_key_col,
    input  wire [3 :0] btn_key_row,
    input  wire [1 :0] btn_step,

    output wire [31:0] game_car,
    output wire [31:0] game_obs,
    output wire [31:0] game_bonus,
    output wire [31:0] game_flags,
    output wire [31:0] game_score,
    output wire        game_commit_toggle,
    input  wire [31:0] lcd_status,

    output wire [31:0] debug_wb_pc,
    output wire [3 :0] debug_wb_rf_we,
    output wire [4 :0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    output wire [31:0] debug_inst,
    output wire        debug_cpu_en,
    output wire [31:0] debug_step_count,
    output wire [31:0] debug_cycle_count,
    output wire        debug_commit_valid,
    output wire [31:0] debug_commit_pc,
    output wire [31:0] debug_commit_inst,
    output wire [31:0] debug_fetch_pc,
    output wire [3 :0] debug_pipe_valid,
    output wire [2 :0] debug_pipe_hazard,
    output wire        debug_last_wb_valid,
    output wire [31:0] debug_last_wb_pc,
    output wire [4 :0] debug_last_wb_wnum,
    output wire [31:0] debug_last_wb_wdata,
    output wire        debug_mode_run,
    output wire        debug_run_active,
    output wire        debug_run_done
);

wire cpu_clk;
wire timer_clk;
reg  cpu_resetn;

always @(posedge cpu_clk)
begin
    cpu_resetn <= resetn;
end

generate if (SIMULATION && `SIMU_USE_PLL == 0)
begin: speedup_simulation
    assign cpu_clk   = clk;
    assign timer_clk = clk;
end
else
begin: pll
    clk_pll clk_pll
    (
        .clk_in1   (clk),
        .cpu_clk   (cpu_clk),
        .timer_clk (timer_clk)
    );
end
endgenerate

wire        cpu_inst_en;
wire [3 :0] cpu_inst_we;
wire [31:0] cpu_inst_addr;
wire [31:0] cpu_inst_wdata;
wire [31:0] cpu_inst_rdata;

wire        cpu_data_en;
wire [3 :0] cpu_data_we;
wire [31:0] cpu_data_addr;
wire [31:0] cpu_data_wdata;
wire [31:0] cpu_data_rdata;

wire        data_sram_en;
wire [3 :0] data_sram_we;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire [31:0] data_sram_rdata;

wire        conf_en;
wire [3 :0] conf_we;
wire [31:0] conf_addr;
wire [31:0] conf_wdata;
wire [31:0] conf_rdata;

wire        cpu_en;
wire [31:0] step_count;
wire [31:0] cycle_count;
wire        mode_run;
wire        run_active;
wire        run_done;
reg  [31:0] debug_inst_r;
wire        cpu_debug_commit_valid;
wire [31:0] cpu_debug_commit_pc;
wire [31:0] cpu_debug_commit_inst;
wire [31:0] cpu_debug_fetch_pc;
wire [3 :0] cpu_debug_pipe_valid;
wire [2 :0] cpu_debug_pipe_hazard;
wire        commit_fire;
reg         debug_commit_valid_r;
reg  [31:0] debug_commit_pc_r;
reg  [31:0] debug_commit_inst_r;

assign debug_cpu_en        = cpu_en;
assign debug_step_count    = step_count;
assign debug_cycle_count   = cycle_count;
assign debug_inst          = debug_inst_r;
assign debug_commit_valid  = debug_commit_valid_r;
assign debug_commit_pc     = debug_commit_pc_r;
assign debug_commit_inst   = debug_commit_inst_r;
assign debug_fetch_pc      = cpu_debug_fetch_pc;
assign debug_pipe_valid    = cpu_debug_pipe_valid;
assign debug_pipe_hazard   = cpu_debug_pipe_hazard;
assign debug_mode_run      = mode_run;
assign debug_run_active    = run_active;
assign debug_run_done      = run_done;
assign commit_fire         = cpu_en & cpu_debug_commit_valid;

generate if (SINGLE_STEP)
begin: run_step_control
    localparam [19:0] CTRL_DEBOUNCE_MAX = SIMULATION ? 20'd3 : 20'd999_999;

    reg        mode_sync0;
    reg        mode_sync1;
    reg        mode_stable;
    reg [19:0] mode_cnt;
    reg        step_btn_sync0;
    reg        step_btn_sync1;
    reg        step_btn_stable;
    reg [19:0] step_btn_cnt;
    reg        run_btn_sync0;
    reg        run_btn_sync1;
    reg        run_btn_stable;
    reg [19:0] run_btn_cnt;
    reg        step_start_pulse_r;
    reg        step_active_r;
    reg        run_start_pulse_r;
    reg        run_active_r;
    reg        run_done_r;
    reg [31:0] step_count_r;
    reg [31:0] cycle_count_r;

    assign cpu_en      = !run_done_r && (mode_stable ? run_active_r : step_active_r);
    assign step_count  = step_count_r;
    assign cycle_count = cycle_count_r;
    assign mode_run    = mode_stable;
    assign run_active  = run_active_r;
    assign run_done    = run_done_r;

    always @(posedge cpu_clk)
    begin
        if (!cpu_resetn)
        begin
            mode_sync0         <= 1'b0;
            mode_sync1         <= 1'b0;
            mode_stable        <= 1'b0;
            mode_cnt           <= 20'd0;
            step_btn_sync0     <= 1'b0;
            step_btn_sync1     <= 1'b0;
            step_btn_stable    <= 1'b0;
            step_btn_cnt       <= 20'd0;
            run_btn_sync0      <= 1'b0;
            run_btn_sync1      <= 1'b0;
            run_btn_stable     <= 1'b0;
            run_btn_cnt        <= 20'd0;
            step_start_pulse_r <= 1'b0;
            step_active_r      <= 1'b0;
            run_start_pulse_r  <= 1'b0;
            run_active_r       <= 1'b0;
            run_done_r         <= 1'b0;
            step_count_r       <= 32'd0;
            cycle_count_r      <= 32'd0;
        end
        else
        begin
            mode_sync0     <= switch[7];
            mode_sync1     <= mode_sync0;
            step_btn_sync0 <= ~btn_step[0];
            step_btn_sync1 <= step_btn_sync0;
            run_btn_sync0  <= ~btn_step[1];
            run_btn_sync1  <= run_btn_sync0;

            step_start_pulse_r <= 1'b0;
            run_start_pulse_r  <= 1'b0;

            if (cpu_en)
            begin
                cycle_count_r <= cycle_count_r + 32'd1;
            end

            if (commit_fire)
            begin
                step_count_r <= step_count_r + 32'd1;
            end

            if (commit_fire && cpu_debug_commit_pc == END_PC)
            begin
                run_done_r    <= 1'b1;
                run_active_r  <= 1'b0;
                step_active_r <= 1'b0;
            end
            else if (!run_done_r)
            begin
                if (mode_stable)
                begin
                    step_active_r <= 1'b0;
                    if (run_start_pulse_r)
                    begin
                        run_active_r <= 1'b1;
                    end
                end
                else
                begin
                    run_active_r <= 1'b0;
                    if (step_start_pulse_r)
                    begin
                        step_active_r <= 1'b1;
                    end
                    else if (commit_fire)
                    begin
                        step_active_r <= 1'b0;
                    end
                end
            end

            if (mode_sync1 == mode_stable)
            begin
                mode_cnt <= 20'd0;
            end
            else if (mode_cnt == CTRL_DEBOUNCE_MAX)
            begin
                mode_stable <= mode_sync1;
                mode_cnt    <= 20'd0;
            end
            else
            begin
                mode_cnt <= mode_cnt + 20'd1;
            end

            if (step_btn_sync1 == step_btn_stable)
            begin
                step_btn_cnt <= 20'd0;
            end
            else if (step_btn_cnt == CTRL_DEBOUNCE_MAX)
            begin
                step_btn_stable <= step_btn_sync1;
                step_btn_cnt    <= 20'd0;
                if (step_btn_sync1)
                begin
                    step_start_pulse_r <= 1'b1;
                end
            end
            else
            begin
                step_btn_cnt <= step_btn_cnt + 20'd1;
            end

            if (run_btn_sync1 == run_btn_stable)
            begin
                run_btn_cnt <= 20'd0;
            end
            else if (run_btn_cnt == CTRL_DEBOUNCE_MAX)
            begin
                run_btn_stable <= run_btn_sync1;
                run_btn_cnt    <= 20'd0;
                if (run_btn_sync1)
                begin
                    run_start_pulse_r <= 1'b1;
                end
            end
            else
            begin
                run_btn_cnt <= run_btn_cnt + 20'd1;
            end
        end
    end
end
else
begin: continuous_control
    assign cpu_en      = 1'b1;
    assign step_count  = 32'd0;
    assign cycle_count = 32'd0;
    assign mode_run    = 1'b0;
    assign run_active  = 1'b1;
    assign run_done    = 1'b0;
end
endgenerate

mycpu_top cpu(
    .clk                  (cpu_clk),
    .resetn               (cpu_resetn),
    .cpu_en               (cpu_en),

    .inst_sram_en         (cpu_inst_en),
    .inst_sram_we         (cpu_inst_we),
    .inst_sram_addr       (cpu_inst_addr),
    .inst_sram_wdata      (cpu_inst_wdata),
    .inst_sram_rdata      (cpu_inst_rdata),

    .data_sram_en         (cpu_data_en),
    .data_sram_we         (cpu_data_we),
    .data_sram_addr       (cpu_data_addr),
    .data_sram_wdata      (cpu_data_wdata),
    .data_sram_rdata      (cpu_data_rdata),

    .debug_wb_pc          (debug_wb_pc),
    .debug_wb_rf_we       (debug_wb_rf_we),
    .debug_wb_rf_wnum     (debug_wb_rf_wnum),
    .debug_wb_rf_wdata    (debug_wb_rf_wdata),
    .debug_last_wb_valid  (debug_last_wb_valid),
    .debug_last_wb_pc     (debug_last_wb_pc),
    .debug_last_wb_wnum   (debug_last_wb_wnum),
    .debug_last_wb_wdata  (debug_last_wb_wdata),
    .debug_commit_valid   (cpu_debug_commit_valid),
    .debug_commit_pc      (cpu_debug_commit_pc),
    .debug_commit_inst    (cpu_debug_commit_inst),
    .debug_fetch_pc       (cpu_debug_fetch_pc),
    .debug_pipe_valid     (cpu_debug_pipe_valid),
    .debug_pipe_hazard    (cpu_debug_pipe_hazard)
);

always @(posedge cpu_clk)
begin
    if (!cpu_resetn)
    begin
        debug_inst_r         <= 32'b0;
        debug_commit_valid_r <= 1'b0;
        debug_commit_pc_r    <= 32'b0;
        debug_commit_inst_r  <= 32'b0;
    end
    else
    begin
        debug_commit_valid_r <= 1'b0;
        if (commit_fire)
        begin
            debug_inst_r         <= cpu_debug_commit_inst;
            debug_commit_valid_r <= 1'b1;
            debug_commit_pc_r    <= cpu_debug_commit_pc;
            debug_commit_inst_r  <= cpu_debug_commit_inst;
        end
    end
end

bridge_1x2 bridge_1x2(
    .clk             (cpu_clk),
    .resetn          (cpu_resetn),

    .cpu_data_en     (cpu_data_en),
    .cpu_data_we     (cpu_data_we),
    .cpu_data_addr   (cpu_data_addr),
    .cpu_data_wdata  (cpu_data_wdata),
    .cpu_data_rdata  (cpu_data_rdata),

    .data_sram_en    (data_sram_en),
    .data_sram_we    (data_sram_we),
    .data_sram_addr  (data_sram_addr),
    .data_sram_wdata (data_sram_wdata),
    .data_sram_rdata (data_sram_rdata),

    .conf_en         (conf_en),
    .conf_we         (conf_we),
    .conf_addr       (conf_addr),
    .conf_wdata      (conf_wdata),
    .conf_rdata      (conf_rdata)
);

generate if (SIMULATION)
begin: sim_unified_ram
    (* ram_style = "block" *) reg [31:0] ram [0:262143];
    reg  [31:0] inst_rdata_r;
    reg  [31:0] data_rdata_r;
    integer     ram_i;

    wire        inst_addr_need_highest_4bits;
    wire [31:0] inst_addr_mapped;
    wire        data_addr_need_highest_4bits;
    wire [31:0] data_addr_mapped;
    wire [17:0] inst_word_addr;
    wire [17:0] data_word_addr;

    assign inst_addr_need_highest_4bits = cpu_inst_addr[31:28] != 4'h0 &&
                                          cpu_inst_addr[31:28] != 4'h1 &&
                                          cpu_inst_addr[31:28] != 4'h7 &&
                                          cpu_inst_addr[31:28] != 4'hb;
    assign inst_addr_mapped = inst_addr_need_highest_4bits ?
                              {12'b0, 4'hf, cpu_inst_addr[31:28], cpu_inst_addr[11:0]} :
                              cpu_inst_addr;
    assign inst_word_addr = inst_addr_mapped[19:2];

    assign data_addr_need_highest_4bits = data_sram_addr[31:28] != 4'h0 &&
                                          data_sram_addr[31:28] != 4'h1 &&
                                          data_sram_addr[31:28] != 4'h7 &&
                                          data_sram_addr[31:28] != 4'hb;
    assign data_addr_mapped = data_addr_need_highest_4bits ?
                              {12'b0, 4'hf, data_sram_addr[31:28], data_sram_addr[11:0]} :
                              data_sram_addr;
    assign data_word_addr = data_addr_mapped[19:2];

    assign cpu_inst_rdata  = inst_rdata_r;
    assign data_sram_rdata = data_rdata_r;

    initial
    begin
        for (ram_i = 0; ram_i < 262144; ram_i = ram_i + 1)
        begin
            ram[ram_i] = 32'b0;
        end
        $readmemb("../../../../../../mem/exp23/inst_ram.mif", ram);
    end

    always @(posedge cpu_clk)
    begin
        if (cpu_inst_en)
        begin
            inst_rdata_r <= ram[inst_word_addr];
        end

        if (data_sram_en)
        begin
            data_rdata_r <= ram[data_word_addr];
            if (data_sram_we[0])
            begin
                ram[data_word_addr][ 7: 0] <= data_sram_wdata[ 7: 0];
            end
            if (data_sram_we[1])
            begin
                ram[data_word_addr][15: 8] <= data_sram_wdata[15: 8];
            end
            if (data_sram_we[2])
            begin
                ram[data_word_addr][23:16] <= data_sram_wdata[23:16];
            end
            if (data_sram_we[3])
            begin
                ram[data_word_addr][31:24] <= data_sram_wdata[31:24];
            end
        end
    end
end
else
begin: board_unified_ram
    (* ram_style = "block" *) reg [31:0] ram [0:262143];
    reg  [31:0] inst_rdata_r;
    reg  [31:0] data_rdata_r;

    wire        inst_addr_need_highest_4bits;
    wire [31:0] inst_addr_mapped;
    wire        data_addr_need_highest_4bits;
    wire [31:0] data_addr_mapped;
    wire [17:0] inst_word_addr;
    wire [17:0] data_word_addr;

    assign inst_addr_need_highest_4bits = cpu_inst_addr[31:28] != 4'h0 &&
                                          cpu_inst_addr[31:28] != 4'h1 &&
                                          cpu_inst_addr[31:28] != 4'h7 &&
                                          cpu_inst_addr[31:28] != 4'hb;
    assign inst_addr_mapped = inst_addr_need_highest_4bits ?
                              {12'b0, 4'hf, cpu_inst_addr[31:28], cpu_inst_addr[11:0]} :
                              cpu_inst_addr;
    assign inst_word_addr = inst_addr_mapped[19:2];

    assign data_addr_need_highest_4bits = data_sram_addr[31:28] != 4'h0 &&
                                          data_sram_addr[31:28] != 4'h1 &&
                                          data_sram_addr[31:28] != 4'h7 &&
                                          data_sram_addr[31:28] != 4'hb;
    assign data_addr_mapped = data_addr_need_highest_4bits ?
                              {12'b0, 4'hf, data_sram_addr[31:28], data_sram_addr[11:0]} :
                              data_sram_addr;
    assign data_word_addr = data_addr_mapped[19:2];

    assign cpu_inst_rdata  = inst_rdata_r;
    assign data_sram_rdata = data_rdata_r;

    initial
    begin
        $readmemb("../../../../mem/exp23/inst_ram.mif", ram);
    end

    always @(posedge cpu_clk)
    begin
        if (cpu_inst_en)
        begin
            inst_rdata_r <= ram[inst_word_addr];
        end

        if (data_sram_en)
        begin
            data_rdata_r <= ram[data_word_addr];
            if (data_sram_we[0])
            begin
                ram[data_word_addr][ 7: 0] <= data_sram_wdata[ 7: 0];
            end
            if (data_sram_we[1])
            begin
                ram[data_word_addr][15: 8] <= data_sram_wdata[15: 8];
            end
            if (data_sram_we[2])
            begin
                ram[data_word_addr][23:16] <= data_sram_wdata[23:16];
            end
            if (data_sram_we[3])
            begin
                ram[data_word_addr][31:24] <= data_sram_wdata[31:24];
            end
        end
    end
end
endgenerate

confreg #(.SIMULATION(SIMULATION)) u_confreg
(
    .clk         (cpu_clk),
    .timer_clk   (timer_clk),
    .resetn      (cpu_resetn),
    .conf_en     (conf_en),
    .conf_we     (conf_we),
    .conf_addr   (conf_addr),
    .conf_wdata  (conf_wdata),
    .conf_rdata  (conf_rdata),
    .game_car    (game_car),
    .game_obs    (game_obs),
    .game_bonus  (game_bonus),
    .game_flags  (game_flags),
    .game_score  (game_score),
    .game_commit_toggle(game_commit_toggle),
    .lcd_status  (lcd_status),
    .led         (led),
    .led_rg0     (led_rg0),
    .led_rg1     (led_rg1),
    .num_csn     (num_csn),
    .num_a_g     (num_a_g),
    .num_data    (num_data),
    .switch      (switch),
    .btn_key_col (btn_key_col),
    .btn_key_row (btn_key_row),
    .btn_step    (btn_step)
);

endmodule

`default_nettype wire
