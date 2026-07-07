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
//   > File Name   : soc_top.v
//   > Description : SoC, included cpu, 2 x 3 bridge,
//                   inst ram, confreg, data ram
// 
//           -------------------------
//           |           cpu         |
//           -------------------------
//         inst|                  | data
//             |                  | 
//             |        ---------------------
//             |        |    1 x 2 bridge   |
//             |        ---------------------
//             |             |            |           
//             |             |            |           
//      -------------   -----------   -----------
//      | inst ram  |   | data ram|   | confreg |
//      -------------   -----------   -----------
//
//   > Author      : LOONGSON
//   > Date        : 2017-08-04
//*************************************************************************

`default_nettype none

//for simulation:
//1. if define SIMU_USE_PLL = 1, will use clk_pll to generate cpu_clk/timer_clk,
//   and simulation will be very slow.
//2. usually, please define SIMU_USE_PLL=0 to speed up simulation by assign
//   cpu_clk/timer_clk = clk.
//   at this time, cpu_clk/timer_clk frequency are both 100MHz, same as clk.
`define SIMU_USE_PLL 0 //set 0 to speed up simulation

module soc_lite_top #(
    parameter SIMULATION  = 1'b0,
    parameter SINGLE_STEP = 1'b0,
    parameter CPU_USE_PIPELINE = 1'b1
)
(
    input  wire        resetn, 
    input  wire        clk,

    //------gpio-------
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

    output wire [31:0] debug_wb_pc,
    output wire [3 :0] debug_wb_rf_we,
    output wire [4 :0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    output wire [31:0] debug_inst,
    output wire        debug_cpu_en,
    output wire [31:0] debug_step_count,
    output wire        debug_last_wb_valid,
    output wire [31:0] debug_last_wb_pc,
    output wire [4 :0] debug_last_wb_wnum,
    output wire [31:0] debug_last_wb_wdata,
    output wire        debug_mode_run,
    output wire        debug_run_active,
    output wire        debug_run_done
);

//clk and resetn
wire cpu_clk;
wire timer_clk;
reg cpu_resetn;
always @(posedge cpu_clk)
begin
    cpu_resetn <= resetn;
end
generate if(SIMULATION && `SIMU_USE_PLL==0)
begin: speedup_simulation
    assign cpu_clk   = clk;
    assign timer_clk = clk;
end
else
begin: pll
    clk_pll clk_pll
    (
        .clk_in1 (clk),
        .cpu_clk (cpu_clk),
        .timer_clk (timer_clk)
    );
end
endgenerate

//cpu inst sram
wire        cpu_inst_we;
wire [31:0] cpu_inst_addr;
wire [31:0] cpu_inst_wdata;
wire [31:0] cpu_inst_rdata;
//cpu data sram
wire        cpu_data_we;
wire [31:0] cpu_data_addr;
wire [31:0] cpu_data_wdata;
wire [31:0] cpu_data_rdata;

//data sram
wire        data_sram_en;
wire        data_sram_we;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire [31:0] data_sram_rdata;

//conf
wire        conf_en;
wire        conf_we;
wire [31:0] conf_addr;
wire [31:0] conf_wdata;
wire [31:0] conf_rdata;

//single-step control
localparam [31:0] END_PC = 32'h1c000100;

wire        cpu_en;
wire [31:0] step_count;
wire        mode_run;
wire        run_active;
wire        run_done;
reg  [31:0] debug_inst_r;

assign debug_cpu_en     = cpu_en;
assign debug_step_count = step_count;
assign debug_inst       = debug_inst_r;
assign debug_mode_run   = mode_run;
assign debug_run_active = run_active;
assign debug_run_done   = run_done;

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
    reg        step_pulse_r;
    reg        run_start_pulse_r;
    reg        run_active_r;
    reg        run_done_r;
    reg [31:0] step_count_r;

    assign cpu_en     = !run_done_r && (mode_stable ? run_active_r : step_pulse_r);
    assign step_count = step_count_r;
    assign mode_run   = mode_stable;
    assign run_active = run_active_r;
    assign run_done   = run_done_r;

    always @(posedge cpu_clk)
    begin
        if (!cpu_resetn)
        begin
            mode_sync0        <= 1'b0;
            mode_sync1        <= 1'b0;
            mode_stable       <= 1'b0;
            mode_cnt          <= 20'd0;
            step_btn_sync0    <= 1'b0;
            step_btn_sync1    <= 1'b0;
            step_btn_stable   <= 1'b0;
            step_btn_cnt      <= 20'd0;
            run_btn_sync0     <= 1'b0;
            run_btn_sync1     <= 1'b0;
            run_btn_stable    <= 1'b0;
            run_btn_cnt       <= 20'd0;
            step_pulse_r      <= 1'b0;
            run_start_pulse_r <= 1'b0;
            run_active_r      <= 1'b0;
            run_done_r        <= 1'b0;
            step_count_r      <= 32'd0;
        end
        else
        begin
            mode_sync0     <= switch[7];
            mode_sync1     <= mode_sync0;
            step_btn_sync0 <= ~btn_step[0];
            step_btn_sync1 <= step_btn_sync0;
            run_btn_sync0  <= ~btn_step[1];
            run_btn_sync1  <= run_btn_sync0;

            step_pulse_r      <= 1'b0;
            run_start_pulse_r <= 1'b0;

            if (cpu_en)
            begin
                step_count_r <= step_count_r + 32'd1;
            end

            if (cpu_en && cpu_inst_addr == END_PC)
            begin
                run_done_r   <= 1'b1;
                run_active_r <= 1'b0;
            end
            else if (!run_done_r)
            begin
                if (mode_stable)
                begin
                    if (run_start_pulse_r)
                    begin
                        run_active_r <= 1'b1;
                    end
                end
                else
                begin
                    run_active_r <= 1'b0;
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
                    step_pulse_r <= 1'b1;
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
    assign cpu_en     = 1'b1;
    assign step_count = 32'd0;
    assign mode_run   = 1'b0;
    assign run_active = 1'b1;
    assign run_done   = 1'b0;
end
endgenerate

//cpu
mycpu_top #(
    .USE_PIPELINE    (CPU_USE_PIPELINE)
) cpu(
    .clk              (cpu_clk       ),
    .resetn           (cpu_resetn    ),  //low active
    .cpu_en           (cpu_en        ),

    .inst_sram_we     (cpu_inst_we   ),
    .inst_sram_addr   (cpu_inst_addr ),
    .inst_sram_wdata  (cpu_inst_wdata),
    .inst_sram_rdata  (cpu_inst_rdata),
   
    .data_sram_we     (cpu_data_we   ),
    .data_sram_addr   (cpu_data_addr ),
    .data_sram_wdata  (cpu_data_wdata),
    .data_sram_rdata  (cpu_data_rdata),

    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .debug_last_wb_valid(debug_last_wb_valid),
    .debug_last_wb_pc   (debug_last_wb_pc   ),
    .debug_last_wb_wnum (debug_last_wb_wnum ),
    .debug_last_wb_wdata(debug_last_wb_wdata)
);

always @(posedge cpu_clk)
begin
    if (!cpu_resetn)
    begin
        debug_inst_r <= 32'b0;
    end
    else if (cpu_en)
    begin
        debug_inst_r <= cpu_inst_rdata;
    end
end

//inst ram
inst_ram #(
    .ADDR_WIDTH(18),
    .DEPTH     (1 << 18)
) inst_ram
(
    .clk   (cpu_clk            ),   
    .we    (cpu_inst_we        ),   
    .a     (cpu_inst_addr[19:2]),
    .d     (cpu_inst_wdata     ),   
    .spo   (cpu_inst_rdata     )   
);

bridge_1x2 bridge_1x2(
    .clk             ( cpu_clk         ), // i, 1                 
    .resetn          ( cpu_resetn      ), // i, 1                 
	  
    .cpu_data_we     ( cpu_data_we     ), // i, 4                 
    .cpu_data_addr   ( cpu_data_addr   ), // i, 32                
    .cpu_data_wdata  ( cpu_data_wdata  ), // i, 32                
    .cpu_data_rdata  ( cpu_data_rdata  ), // o, 32                

    .data_sram_en    ( data_sram_en    ),			   
    .data_sram_we    ( data_sram_we    ), // o, 4                 
    .data_sram_addr  ( data_sram_addr  ), // o, `DATA_RAM_ADDR_LEN
    .data_sram_wdata ( data_sram_wdata ), // o, 32                
    .data_sram_rdata ( data_sram_rdata ), // i, 32                

    .conf_en         ( conf_en         ), // o, 1                 
    .conf_we         ( conf_we         ), // o, 4                 
    .conf_addr       ( conf_addr       ), // o, 32                
    .conf_wdata      ( conf_wdata      ), // o, 32                
    .conf_rdata      ( conf_rdata      )  // i, 32                
 );

//data ram
data_ram #(
    .ADDR_WIDTH(18),
    .DEPTH     (1 << 18)
) data_ram
(
    .clk   (cpu_clk            ),   
    .we    (data_sram_we & data_sram_en),   
    .a     (data_sram_addr[19:2]),
    .d     (data_sram_wdata    ),   
    .spo   (data_sram_rdata    )   
);

//confreg
confreg #(.SIMULATION(SIMULATION)) u_confreg
(
    .clk          ( cpu_clk    ),  // i, 1   
    .timer_clk    ( timer_clk  ),  // i, 1   
    .resetn       ( cpu_resetn ),  // i, 1    
    .conf_en      ( conf_en    ),  // i, 1      
    .conf_we      ( conf_we    ),  // i, 4      
    .conf_addr    ( conf_addr  ),  // i, 32        
    .conf_wdata   ( conf_wdata ),  // i, 32         
    .conf_rdata   ( conf_rdata ),  // o, 32         
    .led          ( led        ),  // o, 16   
    .led_rg0      ( led_rg0    ),  // o, 2      
    .led_rg1      ( led_rg1    ),  // o, 2      
    .num_csn      ( num_csn    ),  // o, 8      
    .num_a_g      ( num_a_g    ),  // o, 7      
    .num_data     ( num_data   ),  // o, 32
    .switch       ( switch     ),  // i, 8     
    .btn_key_col  ( btn_key_col),  // o, 4          
    .btn_key_row  ( btn_key_row),  // i, 4           
    .btn_step     ( btn_step   )   // i, 2   
);

endmodule
