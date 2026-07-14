/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of
its contributors may be used to endorse or promote products derived from this
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

//*************************************************************************
//   > File Name   : confreg.v
//   > Description : Control module of
//                   16 red leds, 2 green/red leds,
//                   7-segment display,
//                   switchs,
//                   key board,
//                   bottom STEP,
//                   timer.
//
//   > Author      : LOONGSON
//   > Date        : 2017-08-04
//*************************************************************************
`define RANDOM_SEED {7'b1010101,16'h01FF}

`define CR0_ADDR       16'h8000   //32'hbfaf_8000
`define CR1_ADDR       16'h8010   //32'hbfaf_8010
`define CR2_ADDR       16'h8020   //32'hbfaf_8020
`define CR3_ADDR       16'h8030   //32'hbfaf_8030
`define CR4_ADDR       16'h8040   //32'hbfaf_8040
`define CR5_ADDR       16'h8050   //32'hbfaf_8050
`define CR6_ADDR       16'h8060   //32'hbfaf_8060
`define CR7_ADDR       16'h8070   //32'hbfaf_8070

`define GAME_CAR_ADDR    16'h9000   //32'hbfaf_9000
`define GAME_OBS_ADDR    16'h9010   //32'hbfaf_9010
`define GAME_BONUS_ADDR  16'h9020   //32'hbfaf_9020
`define GAME_FLAGS_ADDR  16'h9030   //32'hbfaf_9030
`define GAME_SCORE_ADDR  16'h9040   //32'hbfaf_9040
`define GAME_COMMIT_ADDR 16'h9050   //32'hbfaf_9050
`define LCD_STATUS_ADDR  16'h9060   //32'hbfaf_9060
`define GAME_OBS1_ADDR   16'h9070   //32'hbfaf_9070
`define GAME_OBS2_ADDR   16'h9080   //32'hbfaf_9080

`define LED_ADDR       16'hf020   //32'hbfaf_f020
`define LED_RG0_ADDR   16'hf030   //32'hbfaf_f030
`define LED_RG1_ADDR   16'hf040   //32'hbfaf_f040
`define NUM_ADDR       16'hf050   //32'hbfaf_f050
`define SWITCH_ADDR    16'hf060   //32'hbfaf_f060
`define BTN_KEY_ADDR   16'hf070   //32'hbfaf_f070
`define BTN_STEP_ADDR  16'hf080   //32'hbfaf_f080
`define SW_INTER_ADDR  16'hf090   //32'hbfaf_f090
`define TIMER_ADDR     16'he000   //32'hbfaf_e000

`define IO_SIMU_ADDR      16'hff00  //32'hbfaf_ff00
`define VIRTUAL_UART_ADDR 16'hff10  //32'hbfaf_ff10
`define UART_STATUS_ADDR  16'hff14  //32'hbfaf_ff14
`define UART_CTRL_ADDR    16'hff18  //32'hbfaf_ff18
`define SIMU_FLAG_ADDR    16'hff20  //32'hbfaf_ff20
`define OPEN_TRACE_ADDR   16'hff30  //32'hbfaf_ff30
`define NUM_MONITOR_ADDR  16'hff40  //32'hbfaf_ff40
`define SYSTEM_MODE_ADDR  16'hff50  //32'hbfaf_ff50
`define DYNAMIC_END_ADDR  16'hff54  //32'hbfaf_ff54
`define ACTIVE_SLOT_ADDR  16'hff58  //32'hbfaf_ff58
`define MENU_SELECT_ADDR  16'hff5c  //32'hbfaf_ff5c
`define SLOT_VALID_ADDR   16'hff60  //32'hbfaf_ff60
`define MENU_STATUS_ADDR  16'hff64  //32'hbfaf_ff64

module confreg
#(
    parameter SIMULATION=1'b0,
    parameter integer CPU_CLOCK_HZ=50_000_000
)
(
    input  wire        clk,
    input  wire        timer_clk,
    input  wire        resetn,
    // read and write from cpu
    input  wire        conf_en,
    input  wire [3 :0] conf_we,
    input  wire [31:0] conf_addr,
    input  wire [31:0] conf_wdata,
    output wire [31:0] conf_rdata,
    // game/LCD MMIO state
    output wire [31:0] game_car,
    output wire [31:0] game_obs,
    output wire [31:0] game_obs1,
    output wire [31:0] game_obs2,
    output wire [31:0] game_bonus,
    output wire [31:0] game_flags,
    output wire [31:0] game_score,
    output wire        game_commit_toggle,
    input  wire [31:0] lcd_status,
    // read and write to device on board
    output wire [15:0] led,
    output wire [1 :0] led_rg0,
    output wire [1 :0] led_rg1,
    output reg  [7 :0] num_csn,
    output reg  [6 :0] num_a_g,
    output reg  [31:0] num_data,
    input  wire [7 :0] switch,
    output wire [3 :0] btn_key_col,
    input  wire [3 :0] btn_key_row,
    input  wire [1 :0] btn_step,
    input  wire [15:0] external_key_state,
    input  wire        uart_rx_i,
    output wire        uart_tx_o,
    output wire [1:0]  system_mode,
    output wire [31:0] dynamic_end_pc,
    output wire [3:0]  active_slot,
    output wire [3:0]  menu_selected_slot,
    output wire [15:0] menu_slot_valid,
    output wire [7:0]  menu_status,
    inout  wire [7:0]  nand_io,
    input  wire        nand_rb_n,
    output wire        nand_cle,
    output wire        nand_ale,
    output wire        nand_ce_n,
    output wire        nand_re_n,
    output wire        nand_we_n
);
    reg  [31:0] cr0;
    reg  [31:0] cr1;
    reg  [31:0] cr2;
    reg  [31:0] cr3;
    reg  [31:0] cr4;
    reg  [31:0] cr5;
    reg  [31:0] cr6;
    reg  [31:0] cr7;

    reg  [31:0] game_car_data;
    reg  [31:0] game_obs_data;
    reg  [31:0] game_obs1_data;
    reg  [31:0] game_obs2_data;
    reg  [31:0] game_bonus_data;
    reg  [31:0] game_flags_data;
    reg  [31:0] game_score_data;
    reg  [31:0] game_commit_data;
    reg         game_commit_toggle_r;

    reg  [31:0] led_data;
    reg  [31:0] led_rg0_data;
    reg  [31:0] led_rg1_data;
    wire [31:0] switch_data;
    wire [31:0] sw_inter_data; //switch interleave
    wire [31:0] btn_key_data;
    wire [31:0] btn_step_data;
    reg  [7 :0] confreg_uart_data;
    reg         confreg_uart_valid;
    reg  [31:0] timer_r2;
    reg  [31:0] simu_flag;
    reg  [31:0] io_simu;
    reg  [7 :0] virtual_uart_data;
    reg         open_trace;
    reg         num_monitor;
    reg  [31:0] uart_ctrl;
    reg  [1:0]  system_mode_r;
    reg  [31:0] dynamic_end_pc_r;
    reg  [3:0]  active_slot_r;
    reg  [3:0]  menu_selected_slot_r;
    reg  [15:0] menu_slot_valid_r;
    reg  [7:0]  menu_status_r;
wire [7:0] uart_rx_data;
wire       uart_rx_valid;
wire       uart_rx_frame_error;
wire [7:0] uart_rx_front;
wire       uart_rx_empty;
wire       uart_rx_full;
wire       uart_rx_overflow;
wire [7:0] uart_tx_front;
wire       uart_tx_fifo_empty;
wire       uart_tx_fifo_full;
wire       uart_tx_fifo_overflow;
wire       uart_tx_start;
    wire       uart_tx_ready;
    wire       uart_tx_busy;
    wire [31:0] uart_status;

    assign system_mode   = system_mode_r;
    assign dynamic_end_pc = dynamic_end_pc_r;
    assign active_slot   = active_slot_r;
    assign menu_selected_slot = menu_selected_slot_r;
    assign menu_slot_valid = menu_slot_valid_r;
    assign menu_status = menu_status_r;
    wire nand_mmio_select = (conf_addr[15:8] == 8'hb0) || (conf_addr[15:12] == 4'hc);
    wire [31:0] nand_mmio_rdata;

    nand_raw_controller u_nand_controller(
        .clk(clk), .resetn(resetn), .mmio_en(conf_en && nand_mmio_select),
        .mmio_we(conf_we), .mmio_addr(conf_addr[15:0]), .mmio_wdata(conf_wdata),
        .mmio_rdata(nand_mmio_rdata), .nand_io(nand_io), .nand_rb_n(nand_rb_n),
        .nand_cle(nand_cle), .nand_ale(nand_ale), .nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n), .nand_we_n(nand_we_n)
    );

    assign game_car           = game_car_data;
    assign game_obs           = game_obs_data;
    assign game_obs1          = game_obs1_data;
    assign game_obs2          = game_obs2_data;
    assign game_bonus         = game_bonus_data;
    assign game_flags         = game_flags_data;
    assign game_score         = game_score_data;
    assign game_commit_toggle = game_commit_toggle_r;

    // Read data has one cycle delay.  NAND page-buffer storage is a
    // synchronous BRAM, so its controller produces the word one cycle after
    // the request.  Select that response directly instead of registering it
    // for a second cycle here.
    reg [31:0] conf_rdata_reg;
    reg        nand_buffer_read_pending;
    wire       nand_buffer_read_request = conf_en && !(|conf_we) &&
                                             nand_mmio_select &&
                                             conf_addr[15:12]==4'hc &&
                                             conf_addr[11:2]<10'd528;
    assign conf_rdata = nand_buffer_read_pending ? nand_mmio_rdata :
                                                   conf_rdata_reg;
    always @(posedge clk)
    begin
        if(~resetn)
        begin
            conf_rdata_reg <= 32'd0;
            nand_buffer_read_pending <= 1'b0;
        end
        else
        begin
            nand_buffer_read_pending <= nand_buffer_read_request;
            if(conf_en)
            begin
              case (conf_addr[15:0])
                `CR0_ADDR      : conf_rdata_reg <= cr0          ;
                `CR1_ADDR      : conf_rdata_reg <= cr1          ;
                `CR2_ADDR      : conf_rdata_reg <= cr2          ;
                `CR3_ADDR      : conf_rdata_reg <= cr3          ;
                `CR4_ADDR      : conf_rdata_reg <= cr4          ;
                `CR5_ADDR      : conf_rdata_reg <= cr5          ;
                `CR6_ADDR      : conf_rdata_reg <= cr6          ;
                `CR7_ADDR      : conf_rdata_reg <= cr7          ;
                `GAME_CAR_ADDR    : conf_rdata_reg <= game_car_data;
                `GAME_OBS_ADDR    : conf_rdata_reg <= game_obs_data;
                `GAME_BONUS_ADDR  : conf_rdata_reg <= game_bonus_data;
                `GAME_FLAGS_ADDR  : conf_rdata_reg <= game_flags_data;
                `GAME_SCORE_ADDR  : conf_rdata_reg <= game_score_data;
                `GAME_COMMIT_ADDR : conf_rdata_reg <= game_commit_data;
                `LCD_STATUS_ADDR  : conf_rdata_reg <= lcd_status;
                `GAME_OBS1_ADDR   : conf_rdata_reg <= game_obs1_data;
                `GAME_OBS2_ADDR   : conf_rdata_reg <= game_obs2_data;
                `LED_ADDR      : conf_rdata_reg <= led_data     ;
                `LED_RG0_ADDR  : conf_rdata_reg <= led_rg0_data ;
                `LED_RG1_ADDR  : conf_rdata_reg <= led_rg1_data ;
                `NUM_ADDR      : conf_rdata_reg <= num_data     ;
                `SWITCH_ADDR   : conf_rdata_reg <= switch_data  ;
                `BTN_KEY_ADDR  : conf_rdata_reg <= btn_key_data ;
                `BTN_STEP_ADDR : conf_rdata_reg <= btn_step_data;
                `SW_INTER_ADDR : conf_rdata_reg <= sw_inter_data;
                `TIMER_ADDR    : conf_rdata_reg <= timer_r2     ;
                `SIMU_FLAG_ADDR: conf_rdata_reg <= simu_flag    ;
                `IO_SIMU_ADDR  : conf_rdata_reg <= io_simu      ;
                `VIRTUAL_UART_ADDR : conf_rdata_reg <= {24'd0,uart_rx_front} ;
                `UART_STATUS_ADDR  : conf_rdata_reg <= uart_status;
                `UART_CTRL_ADDR    : conf_rdata_reg <= uart_ctrl;
                `OPEN_TRACE_ADDR : conf_rdata_reg <= {31'd0,open_trace} ;
                `NUM_MONITOR_ADDR: conf_rdata_reg <= {31'd0,num_monitor} ;
                `SYSTEM_MODE_ADDR: conf_rdata_reg <= {30'd0,system_mode_r};
                `DYNAMIC_END_ADDR: conf_rdata_reg <= dynamic_end_pc_r;
                `ACTIVE_SLOT_ADDR: conf_rdata_reg <= {28'd0,active_slot_r};
                `MENU_SELECT_ADDR: conf_rdata_reg <= {28'd0,menu_selected_slot_r};
                `SLOT_VALID_ADDR : conf_rdata_reg <= {16'd0,menu_slot_valid_r};
                `MENU_STATUS_ADDR: conf_rdata_reg <= {24'd0,menu_status_r};
                  default        : conf_rdata_reg <= nand_mmio_select ? nand_mmio_rdata : 32'd0;
              endcase
            end
        end
    end

//conf write, only support a word write
wire conf_write = conf_en & (|conf_we);

//-------------------------{confreg register}begin-----------------------//
wire write_cr0 = conf_write & (conf_addr[15:0]==`CR0_ADDR);
wire write_cr1 = conf_write & (conf_addr[15:0]==`CR1_ADDR);
wire write_cr2 = conf_write & (conf_addr[15:0]==`CR2_ADDR);
wire write_cr3 = conf_write & (conf_addr[15:0]==`CR3_ADDR);
wire write_cr4 = conf_write & (conf_addr[15:0]==`CR4_ADDR);
wire write_cr5 = conf_write & (conf_addr[15:0]==`CR5_ADDR);
wire write_cr6 = conf_write & (conf_addr[15:0]==`CR6_ADDR);
wire write_cr7 = conf_write & (conf_addr[15:0]==`CR7_ADDR);
wire write_game_car    = conf_write & (conf_addr[15:0]==`GAME_CAR_ADDR);
wire write_game_obs    = conf_write & (conf_addr[15:0]==`GAME_OBS_ADDR);
wire write_game_obs1   = conf_write & (conf_addr[15:0]==`GAME_OBS1_ADDR);
wire write_game_obs2   = conf_write & (conf_addr[15:0]==`GAME_OBS2_ADDR);
wire write_game_bonus  = conf_write & (conf_addr[15:0]==`GAME_BONUS_ADDR);
wire write_game_flags  = conf_write & (conf_addr[15:0]==`GAME_FLAGS_ADDR);
wire write_game_score  = conf_write & (conf_addr[15:0]==`GAME_SCORE_ADDR);
wire write_game_commit = conf_write & (conf_addr[15:0]==`GAME_COMMIT_ADDR);
wire write_system_mode = conf_write & (conf_addr[15:0]==`SYSTEM_MODE_ADDR);
wire write_dynamic_end = conf_write & (conf_addr[15:0]==`DYNAMIC_END_ADDR);
wire write_active_slot = conf_write & (conf_addr[15:0]==`ACTIVE_SLOT_ADDR);
wire write_menu_select = conf_write & (conf_addr[15:0]==`MENU_SELECT_ADDR);
wire write_slot_valid = conf_write & (conf_addr[15:0]==`SLOT_VALID_ADDR);
wire write_menu_status = conf_write & (conf_addr[15:0]==`MENU_STATUS_ADDR);

always @(posedge clk)
begin
    if (!resetn)
    begin
        system_mode_r   <= 2'd0;
        dynamic_end_pc_r <= 32'd0;
        active_slot_r   <= 4'd0;
        menu_selected_slot_r <= 4'd0;
        menu_slot_valid_r <= 16'd0;
        menu_status_r <= 8'd0;
    end
    else
    begin
        // Leaving MENU is a one-way transition.  Only a warm/physical reset
        // may restore MENU, so application software cannot remove boot-window
        // write protection by writing SYSTEM_MODE.
        if (write_system_mode && system_mode_r == 2'd0 && conf_wdata[1:0] != 2'd0)
            system_mode_r <= conf_wdata[1:0];
        if (write_dynamic_end)
            dynamic_end_pc_r <= conf_wdata;
        if (write_active_slot)
            active_slot_r <= conf_wdata[3:0];
        if (write_menu_select)
            menu_selected_slot_r <= conf_wdata[3:0];
        if (write_slot_valid)
            menu_slot_valid_r <= conf_wdata[15:0];
        if (write_menu_status)
            menu_status_r <= conf_wdata[7:0];
    end
end
always @(posedge clk)
begin
    cr0 <= !resetn    ? 32'd0      :
           write_cr0 ? conf_wdata : cr0;
    cr1 <= !resetn    ? 32'd0      :
           write_cr1 ? conf_wdata : cr1;
    cr2 <= !resetn    ? 32'd0      :
           write_cr2 ? conf_wdata : cr2;
    cr3 <= !resetn    ? 32'd0      :
           write_cr3 ? conf_wdata : cr3;
    cr4 <= !resetn    ? 32'd0      :
           write_cr4 ? conf_wdata : cr4;
    cr5 <= !resetn    ? 32'd0      :
           write_cr5 ? conf_wdata : cr5;
    cr6 <= !resetn    ? 32'd0      :
           write_cr6 ? conf_wdata : cr6;
    cr7 <= !resetn    ? 32'd0      :
           write_cr7 ? conf_wdata : cr7;
end
//--------------------------{confreg register}end------------------------//

//---------------------------{game register}begin------------------------//
always @(posedge clk)
begin
    if(!resetn)
    begin
        game_car_data       <= 32'h0000_0d21;
        game_obs_data       <= 32'h0000_31f0;
        game_obs1_data      <= 32'h0000_31f1;
        game_obs2_data      <= 32'h0000_31f2;
        game_bonus_data     <= 32'h0000_31f1;
        game_flags_data     <= 32'h0000_0039;
        game_score_data     <= 32'h0000_0000;
        game_commit_data    <= 32'h0000_0000;
        game_commit_toggle_r <= 1'b0;
    end
    else
    begin
        if(write_game_car)
        begin
            game_car_data <= conf_wdata;
        end
        if(write_game_obs)
        begin
            game_obs_data <= conf_wdata;
        end
        if(write_game_obs1)
        begin
            game_obs1_data <= conf_wdata;
        end
        if(write_game_obs2)
        begin
            game_obs2_data <= conf_wdata;
        end
        if(write_game_bonus)
        begin
            game_bonus_data <= conf_wdata;
        end
        if(write_game_flags)
        begin
            game_flags_data <= conf_wdata;
        end
        if(write_game_score)
        begin
            game_score_data <= conf_wdata;
        end
        if(write_game_commit)
        begin
            game_commit_data     <= conf_wdata;
            game_commit_toggle_r <= ~game_commit_toggle_r;
        end
    end
end
//----------------------------{game register}end-------------------------//

//-------------------------------{timer}begin----------------------------//
reg         write_timer_begin,write_timer_begin_r1, write_timer_begin_r2,write_timer_begin_r3;
reg         write_timer_end_r1, write_timer_end_r2;
reg  [31:0] conf_wdata_r, conf_wdata_r1,conf_wdata_r2;

reg  [31:0] timer_r1;
reg  [31:0] timer;

wire write_timer = conf_write & (conf_addr[15:0]==`TIMER_ADDR);
always @(posedge clk)
begin
    if (!resetn)
    begin
        write_timer_begin <= 1'b0;
    end
    else if (write_timer)
    begin
        write_timer_begin <= 1'b1;
        conf_wdata_r      <= conf_wdata;
    end
    else if (write_timer_end_r2)
    begin
        write_timer_begin <= 1'b0;
    end

    write_timer_end_r1 <= write_timer_begin_r2;
    write_timer_end_r2 <= write_timer_end_r1;
end

always @(posedge timer_clk)
begin
    write_timer_begin_r1 <= write_timer_begin;
    write_timer_begin_r2 <= write_timer_begin_r1;
    write_timer_begin_r3 <= write_timer_begin_r2;
    conf_wdata_r1        <= conf_wdata_r;
    conf_wdata_r2        <= conf_wdata_r1;

    if(!resetn)
    begin
        timer <= 32'd0;
    end
    else if (write_timer_begin_r2 && !write_timer_begin_r3)
    begin
        timer <= conf_wdata_r2[31:0];
    end
    else
    begin
        timer <= timer + 1'b1;
    end
end

always @(posedge clk)
begin
    timer_r1 <= timer;
    timer_r2 <= timer_r1;
end
//--------------------------------{timer}end-----------------------------//

//--------------------------{simulation flag}begin-----------------------//
always @(posedge clk)
begin
    if(!resetn)
    begin
        simu_flag <= {32{SIMULATION}};
    end
end
//---------------------------{simulation flag}end------------------------//

//---------------------------{io simulation}begin------------------------//
wire write_io_simu = conf_write & (conf_addr[15:0]==`IO_SIMU_ADDR);
always @(posedge clk)
begin
    if(!resetn)
    begin
        io_simu <= 32'd0;
    end
    else if(write_io_simu)
    begin
        io_simu <= {conf_wdata[15:0],conf_wdata[31:16]};
    end
end
//----------------------------{io simulation}end-------------------------//

//-----------------------------{open trace}begin-------------------------//
wire write_open_trace = conf_write & (conf_addr[15:0]==`OPEN_TRACE_ADDR);
always @(posedge clk)
begin
    if(!resetn)
    begin
        open_trace <= 1'b1;
    end
    else if(write_open_trace)
    begin
        open_trace <= |conf_wdata;
    end
end
//-----------------------------{open trace}end---------------------------//

//----------------------------{num monitor}begin-------------------------//
wire write_num_monitor = conf_write & (conf_addr[15:0]==`NUM_MONITOR_ADDR);
always @(posedge clk)
begin
    if(!resetn)
    begin
        num_monitor <= 1'b1;
    end
    else if(write_num_monitor)
    begin
        num_monitor <= conf_wdata[0];
    end
end
//----------------------------{num monitor}end---------------------------//

//---------------------------{virtual uart}begin-------------------------//
wire [7:0] write_uart_data;
wire write_uart_valid  = conf_write & (conf_addr[15:0]==`VIRTUAL_UART_ADDR);
wire read_uart_valid = conf_en & !(|conf_we) & (conf_addr[15:0]==`VIRTUAL_UART_ADDR);
wire write_uart_status = conf_write & (conf_addr[15:0]==`UART_STATUS_ADDR);
wire write_uart_ctrl = conf_write & (conf_addr[15:0]==`UART_CTRL_ADDR);
assign write_uart_data = conf_wdata[7:0];

wire       uart_fifo_clear = write_uart_ctrl & conf_wdata[8];
wire       uart_overflow_clear = write_uart_status & conf_wdata[1];
wire       uart_frame_error_clear = write_uart_status & conf_wdata[10];
assign uart_status = {21'd0, uart_rx_frame_error,
                      uart_tx_busy || !uart_tx_fifo_empty,
                      !uart_tx_fifo_full, 6'd0,
                      uart_rx_overflow, !uart_rx_empty};

uart_rx #(.CLOCK_HZ(CPU_CLOCK_HZ), .BAUD(115_200)) u_uart_rx (
    .clk(clk), .resetn(resetn), .enable(uart_ctrl[0]),
    .clear_error(uart_frame_error_clear), .rx(uart_rx_i),
    .data(uart_rx_data), .valid(uart_rx_valid), .frame_error(uart_rx_frame_error)
);

uart_fifo #(.DEPTH(16), .ADDR_WIDTH(4)) u_uart_rx_fifo (
    .clk(clk), .resetn(resetn), .clear(uart_fifo_clear),
    .clear_overflow(uart_overflow_clear), .push_data(uart_rx_data),
    .push(uart_rx_valid), .pop(read_uart_valid && !uart_rx_empty),
    .front(uart_rx_front), .empty(uart_rx_empty), .full(uart_rx_full),
    .overflow(uart_rx_overflow)
);

assign uart_tx_start = !uart_tx_fifo_empty && uart_tx_ready;

uart_fifo #(.DEPTH(16), .ADDR_WIDTH(4)) u_uart_tx_fifo (
    .clk(clk), .resetn(resetn), .clear(1'b0),
    .clear_overflow(1'b0), .push_data(write_uart_data),
    .push(write_uart_valid), .pop(uart_tx_start),
    .front(uart_tx_front), .empty(uart_tx_fifo_empty),
    .full(uart_tx_fifo_full), .overflow(uart_tx_fifo_overflow)
);

uart_tx #(.CLOCK_HZ(CPU_CLOCK_HZ), .BAUD(115_200)) u_uart_tx (
    .clk(clk), .resetn(resetn), .enable(uart_ctrl[1]),
    .data(uart_tx_front), .valid(uart_tx_start),
    .tx(uart_tx_o), .ready(uart_tx_ready), .busy(uart_tx_busy)
);

always @(posedge clk)
begin
    if(!resetn)
    begin
        virtual_uart_data <= 8'd0;
        confreg_uart_data <= 8'd0;
        confreg_uart_valid <= 1'd0;
        uart_ctrl <= 32'h0000_0003;
    end
    else
    begin
        confreg_uart_valid <= 1'b0;
        if(write_uart_valid)
        begin
            virtual_uart_data <= write_uart_data;
            confreg_uart_data <= write_uart_data;
            confreg_uart_valid <= 1'b1;
        end
        if(write_uart_ctrl)
            uart_ctrl <= {conf_wdata[31:9], 1'b0, conf_wdata[7:0]};
    end
end
//----------------------------{virtual uart}end--------------------------//

//--------------------------------{led}begin-----------------------------//
//led display
//led_data[31:0]
wire write_led = conf_write & (conf_addr[15:0]==`LED_ADDR);
// The board's 16 monochrome LEDs are active low.
assign led = ~led_data[15:0];
always @(posedge clk)
begin
    if(!resetn)
    begin
        led_data <= 32'h0;
    end
    else if(write_led)
    begin
        led_data <= conf_wdata[31:0];
    end
end
//---------------------------------{led}end------------------------------//

//-------------------------------{switch}begin---------------------------//
//switch data
//switch_data[7:0]
assign switch_data   = {24'd0,switch};
assign sw_inter_data = {16'd0,
                        switch[7],1'b0,switch[6],1'b0,
                        switch[5],1'b0,switch[4],1'b0,
                        switch[3],1'b0,switch[2],1'b0,
                        switch[1],1'b0,switch[0],1'b0};
//--------------------------------{switch}end----------------------------//

//------------------------------{btn key}begin---------------------------//
//btn key data
reg [15:0] btn_key_r;
(* ASYNC_REG = "TRUE" *) reg [15:0] external_key_sync0;
(* ASYNC_REG = "TRUE" *) reg [15:0] external_key_sync1;
assign btn_key_data = {16'd0, (btn_key_r | external_key_sync1)};

always @(posedge clk)
begin
    if (!resetn)
    begin
        external_key_sync0 <= 16'd0;
        external_key_sync1 <= 16'd0;
    end
    else
    begin
        external_key_sync0 <= external_key_state;
        external_key_sync1 <= external_key_sync0;
    end
end

//state machine
reg  [2:0] state;
wire [2:0] next_state;

//eliminate jitter
reg        key_flag;
reg [19:0] key_count;
reg [ 3:0] state_count;
wire key_start = (state==3'b000) && !(&btn_key_row);
wire key_end   = (state==3'b111) &&  (&btn_key_row);
wire key_sample= key_count[19];
always @(posedge clk)
begin
    if(!resetn)
    begin
        key_flag <= 1'd0;
    end
    else if (key_sample && state_count[3])
    begin
        key_flag <= 1'b0;
    end
    else if( key_start || key_end )
    begin
        key_flag <= 1'b1;
    end

    if(!resetn || !key_flag)
    begin
        key_count <= 20'd0;
    end
    else
    begin
        key_count <= key_count + 1'b1;
    end
end

always @(posedge clk)
begin
    if(!resetn || state_count[3])
    begin
        state_count <= 4'd0;
    end
    else
    begin
        state_count <= state_count + 1'b1;
    end
end

always @(posedge clk)
begin
    if(!resetn)
    begin
        state <= 3'b000;
    end
    else if (state_count[3])
    begin
        state <= next_state;
    end
end

assign next_state = (state == 3'b000) ? ( (key_sample && !(&btn_key_row)) ? 3'b001 : 3'b000 ) :
                    (state == 3'b001) ? (                !(&btn_key_row)  ? 3'b111 : 3'b010 ) :
                    (state == 3'b010) ? (                !(&btn_key_row)  ? 3'b111 : 3'b011 ) :
                    (state == 3'b011) ? (                !(&btn_key_row)  ? 3'b111 : 3'b100 ) :
                    (state == 3'b100) ? (                !(&btn_key_row)  ? 3'b111 : 3'b000 ) :
                    (state == 3'b111) ? ( (key_sample &&  (&btn_key_row)) ? 3'b000 : 3'b111 ) :
                                                                                        3'b000;
assign btn_key_col = (state == 3'b000) ? 4'b0000:
                     (state == 3'b001) ? 4'b1110:
                     (state == 3'b010) ? 4'b1101:
                     (state == 3'b011) ? 4'b1011:
                     (state == 3'b100) ? 4'b0111:
                                         4'b0000;
wire [15:0] btn_key_tmp;
always @(posedge clk) begin
    if(!resetn) begin
        btn_key_r   <= 16'd0;
    end
    else if(next_state==3'b000)
    begin
        btn_key_r   <=16'd0;
    end
    else if(next_state == 3'b111 && state != 3'b111 && state_count[3]) begin
        btn_key_r   <= btn_key_tmp;
    end
end

assign btn_key_tmp = (state == 3'b001)&(btn_key_row == 4'b1110) ? 16'h0001:
                     (state == 3'b001)&(btn_key_row == 4'b1101) ? 16'h0010:
                     (state == 3'b001)&(btn_key_row == 4'b1011) ? 16'h0100:
                     (state == 3'b001)&(btn_key_row == 4'b0111) ? 16'h1000:
                     (state == 3'b010)&(btn_key_row == 4'b1110) ? 16'h0002:
                     (state == 3'b010)&(btn_key_row == 4'b1101) ? 16'h0020:
                     (state == 3'b010)&(btn_key_row == 4'b1011) ? 16'h0200:
                     (state == 3'b010)&(btn_key_row == 4'b0111) ? 16'h2000:
                     (state == 3'b011)&(btn_key_row == 4'b1110) ? 16'h0004:
                     (state == 3'b011)&(btn_key_row == 4'b1101) ? 16'h0040:
                     (state == 3'b011)&(btn_key_row == 4'b1011) ? 16'h0400:
                     (state == 3'b011)&(btn_key_row == 4'b0111) ? 16'h4000:
                     (state == 3'b100)&(btn_key_row == 4'b1110) ? 16'h0008:
                     (state == 3'b100)&(btn_key_row == 4'b1101) ? 16'h0080:
                     (state == 3'b100)&(btn_key_row == 4'b1011) ? 16'h0800:
                     (state == 3'b100)&(btn_key_row == 4'b0111) ? 16'h8000:16'h0000;
//-------------------------------{btn key}end----------------------------//

//-----------------------------{btn step}begin---------------------------//
//btn step data
reg btn_step0_r; //0:press
reg btn_step1_r; //0:press
assign btn_step_data = {30'd0,~btn_step0_r,~btn_step1_r}; //1:press

//-----step0
//eliminate jitter
reg        step0_flag;
reg [19:0] step0_count;
wire step0_start = btn_step0_r && !btn_step[0];
wire step0_end   = !btn_step0_r && btn_step[0];
wire step0_sample= step0_count[19];
always @(posedge clk)
begin
    if(!resetn)
    begin
        step0_flag <= 1'd0;
    end
    else if (step0_sample)
    begin
        step0_flag <= 1'b0;
    end
    else if( step0_start || step0_end )
    begin
        step0_flag <= 1'b1;
    end

    if(!resetn || !step0_flag)
    begin
        step0_count <= 20'd0;
    end
    else
    begin
        step0_count <= step0_count + 1'b1;
    end

    if(!resetn)
    begin
        btn_step0_r <= 1'b1;
    end
    else if(step0_sample)
    begin
        btn_step0_r <= btn_step[0];
    end
end

//-----step1
//eliminate jitter
reg        step1_flag;
reg [19:0] step1_count;
wire step1_start = btn_step1_r && !btn_step[1];
wire step1_end   = !btn_step1_r && btn_step[1];
wire step1_sample= step1_count[19];
always @(posedge clk)
begin
    if(!resetn)
    begin
        step1_flag <= 1'd0;
    end
    else if (step1_sample)
    begin
        step1_flag <= 1'b0;
    end
    else if( step1_start || step1_end )
    begin
        step1_flag <= 1'b1;
    end

    if(!resetn || !step1_flag)
    begin
        step1_count <= 20'd0;
    end
    else
    begin
        step1_count <= step1_count + 1'b1;
    end

    if(!resetn)
    begin
        btn_step1_r <= 1'b1;
    end
    else if(step1_sample)
    begin
        btn_step1_r <= btn_step[1];
    end
end
//------------------------------{btn step}end----------------------------//

//-------------------------------{led rg}begin---------------------------//
//led_rg0_data[31:0]  led_rg0_data[31:0]
//bfd0_f010           bfd0_f014
wire write_led_rg0 = conf_write & (conf_addr[15:0]==`LED_RG0_ADDR);
wire write_led_rg1 = conf_write & (conf_addr[15:0]==`LED_RG1_ADDR);
assign led_rg0 = led_rg0_data[1:0];
assign led_rg1 = led_rg1_data[1:0];
always @(posedge clk)
begin
    if(!resetn)
    begin
        led_rg0_data <= 32'h0;
    end
    else if(write_led_rg0)
    begin
        led_rg0_data <= conf_wdata[31:0];
    end

    if(!resetn)
    begin
        led_rg1_data <= 32'h0;
    end
    else if(write_led_rg1)
    begin
        led_rg1_data <= conf_wdata[31:0];
    end
end
//--------------------------------{led rg}end----------------------------//

//---------------------------{digital number}begin-----------------------//
//digital number display
//num_data[31:0]
wire write_num = conf_write & (conf_addr[15:0]==`NUM_ADDR);
always @(posedge clk)
begin
    if(!resetn)
    begin
        num_data <= 32'h0;
    end
    else if(write_num)
    begin
        num_data <= conf_wdata[31:0];
    end
end


reg [19:0] count;
always @(posedge clk)
begin
    if(!resetn)
    begin
        count <= 20'd0;
    end
    else
    begin
        count <= count + 1'b1;
    end
end
//scan data
reg [3:0] scan_data;
always @ ( posedge clk )
begin
    if ( !resetn )
    begin
        scan_data <= 32'd0;
        num_csn   <= 8'b1111_1111;
    end
    else
    begin
        case(count[19:17])
            3'b000 : scan_data <= num_data[31:28];
            3'b001 : scan_data <= num_data[27:24];
            3'b010 : scan_data <= num_data[23:20];
            3'b011 : scan_data <= num_data[19:16];
            3'b100 : scan_data <= num_data[15:12];
            3'b101 : scan_data <= num_data[11: 8];
            3'b110 : scan_data <= num_data[7 : 4];
            3'b111 : scan_data <= num_data[3 : 0];
        endcase

        case(count[19:17])
            3'b000 : num_csn <= 8'b0111_1111;
            3'b001 : num_csn <= 8'b1011_1111;
            3'b010 : num_csn <= 8'b1101_1111;
            3'b011 : num_csn <= 8'b1110_1111;
            3'b100 : num_csn <= 8'b1111_0111;
            3'b101 : num_csn <= 8'b1111_1011;
            3'b110 : num_csn <= 8'b1111_1101;
            3'b111 : num_csn <= 8'b1111_1110;
        endcase
    end
end

always @(posedge clk)
begin
    if ( !resetn )
    begin
        num_a_g <= 7'b0000000;
    end
    else
    begin
        case ( scan_data )
            4'd0 : num_a_g <= 7'b1111110;   //0
            4'd1 : num_a_g <= 7'b0110000;   //1
            4'd2 : num_a_g <= 7'b1101101;   //2
            4'd3 : num_a_g <= 7'b1111001;   //3
            4'd4 : num_a_g <= 7'b0110011;   //4
            4'd5 : num_a_g <= 7'b1011011;   //5
            4'd6 : num_a_g <= 7'b1011111;   //6
            4'd7 : num_a_g <= 7'b1110000;   //7
            4'd8 : num_a_g <= 7'b1111111;   //8
            4'd9 : num_a_g <= 7'b1111011;   //9
            4'd10: num_a_g <= 7'b1110111;   //a
            4'd11: num_a_g <= 7'b0011111;   //b
            4'd12: num_a_g <= 7'b1001110;   //c
            4'd13: num_a_g <= 7'b0111101;   //d
            4'd14: num_a_g <= 7'b1001111;   //e
            4'd15: num_a_g <= 7'b1000111;   //f
        endcase
    end
end
//----------------------------{digital number}end------------------------//
endmodule
