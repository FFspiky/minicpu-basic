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
    parameter SINGLE_STEP = 1'b0
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
    output wire [31:0] debug_step_count
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

//single-step control
wire        cpu_en;
wire [31:0] step_count;
reg  [31:0] debug_inst_r;

assign debug_cpu_en     = cpu_en;
assign debug_step_count = step_count;
assign debug_inst       = debug_inst_r;

generate if (SINGLE_STEP)
begin: single_step_control
    localparam [19:0] STEP_DEBOUNCE_MAX = 20'd999_999;

    reg        step_sync0;
    reg        step_sync1;
    reg        stable_step;
    reg [19:0] debounce_cnt;
    reg        cpu_en_r;
    reg [31:0] step_count_r;

    assign cpu_en     = cpu_en_r;
    assign step_count = step_count_r;

    always @(posedge cpu_clk)
    begin
        if (!cpu_resetn)
        begin
            step_sync0    <= 1'b0;
            step_sync1    <= 1'b0;
            stable_step   <= 1'b0;
            debounce_cnt  <= 20'd0;
            cpu_en_r      <= 1'b0;
            step_count_r  <= 32'd0;
        end
        else
        begin
            step_sync0 <= switch[7];
            step_sync1 <= step_sync0;
            cpu_en_r   <= 1'b0;

            if (step_sync1 == stable_step)
            begin
                debounce_cnt <= 20'd0;
            end
            else if (debounce_cnt == STEP_DEBOUNCE_MAX)
            begin
                stable_step  <= step_sync1;
                debounce_cnt <= 20'd0;

                if (step_sync1)
                begin
                    cpu_en_r     <= 1'b1;
                    step_count_r <= step_count_r + 32'd1;
                end
            end
            else
            begin
                debounce_cnt <= debounce_cnt + 20'd1;
            end
        end
    end
end
else
begin: continuous_control
    assign cpu_en     = 1'b1;
    assign step_count = 32'd0;
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

//cpu
mycpu_top cpu(
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
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
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
inst_ram inst_ram
(
    .clk   (cpu_clk            ),   
    .we    (cpu_inst_we        ),   
    .a     (cpu_inst_addr[17:2]),   
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
data_ram data_ram
(
    .clk   (cpu_clk            ),   
    .we    (data_sram_we & data_sram_en),   
    .a     (data_sram_addr[17:2]),   
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
