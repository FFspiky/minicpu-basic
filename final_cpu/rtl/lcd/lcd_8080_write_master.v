`timescale 1ns / 1ps
`default_nettype none

module lcd_8080_write_master #(
    parameter integer SETUP_CYCLES = 1,
    parameter integer WR_LOW_CYCLES = 2,
    parameter integer WR_HIGH_CYCLES = 1
)(
    input  wire        clk,
    input  wire        resetn,

    input  wire        wr_valid,
    output wire        wr_ready,
    input  wire        wr_rs,
    input  wire [15:0] wr_data,
    output reg         write_fire,

    output reg  [15:0] lcd_db,
    output reg         lcd_wr,
    output reg         lcd_rs
);

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_SETUP = 2'd1;
    localparam [1:0] S_LOW   = 2'd2;
    localparam [1:0] S_HIGH  = 2'd3;

    reg [1:0] state;
    reg [7:0] cycle_cnt;

    assign wr_ready = (state == S_IDLE);

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            state      <= S_IDLE;
            cycle_cnt  <= 8'd0;
            write_fire <= 1'b0;
            lcd_db     <= 16'h0000;
            lcd_wr     <= 1'b1;
            lcd_rs     <= 1'b0;
        end
        else
        begin
            write_fire <= 1'b0;

            case (state)
                S_IDLE:
                begin
                    lcd_wr    <= 1'b1;
                    cycle_cnt <= 8'd0;
                    if (wr_valid)
                    begin
                        lcd_db <= wr_data;
                        lcd_rs <= wr_rs;
                        state  <= S_SETUP;
                    end
                end

                S_SETUP:
                begin
                    if (cycle_cnt == SETUP_CYCLES - 1)
                    begin
                        cycle_cnt  <= 8'd0;
                        lcd_wr     <= 1'b0;
                        write_fire <= 1'b1;
                        state      <= S_LOW;
                    end
                    else
                    begin
                        cycle_cnt <= cycle_cnt + 8'd1;
                    end
                end

                S_LOW:
                begin
                    if (cycle_cnt == WR_LOW_CYCLES - 1)
                    begin
                        cycle_cnt <= 8'd0;
                        lcd_wr    <= 1'b1;
                        state     <= S_HIGH;
                    end
                    else
                    begin
                        cycle_cnt <= cycle_cnt + 8'd1;
                    end
                end

                default:
                begin
                    if (cycle_cnt == WR_HIGH_CYCLES - 1)
                    begin
                        cycle_cnt <= 8'd0;
                        state     <= S_IDLE;
                    end
                    else
                    begin
                        cycle_cnt <= cycle_cnt + 8'd1;
                    end
                end
            endcase
        end
    end

endmodule

`default_nettype wire
