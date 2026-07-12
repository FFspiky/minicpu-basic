`timescale 1ns / 1ps
`default_nettype none

module lcd_init_engine #(
    parameter SIMULATION = 1'b0,
    parameter integer LCD_CONTROLLER = 0
)(
    input  wire        clk,
    input  wire        resetn,

    output reg         lcd_rst,
    output wire        bus_valid,
    input  wire        bus_ready,
    output wire        bus_rs,
    output wire [15:0] bus_data,

    output reg         done,
    output wire        active,
    output wire [7:0]  step
);

    localparam integer PWR_DELAY_CYCLES   = SIMULATION ? 20 : 500_000;
    localparam integer RESET_LOW_CYCLES   = SIMULATION ? 20 : 200_000;
    localparam integer POST_RESET_CYCLES  = SIMULATION ? 20 : 2_000_000;
    localparam integer SLEEP_OUT_CYCLES   = SIMULATION ? 40 : 12_000_000;

    localparam [1:0] OP_CMD   = 2'd0;
    localparam [1:0] OP_DATA  = 2'd1;
    localparam [1:0] OP_DELAY = 2'd2;
    localparam [1:0] OP_END   = 2'd3;

    localparam [2:0] S_POWER      = 3'd0;
    localparam [2:0] S_RESET_LOW  = 3'd1;
    localparam [2:0] S_RESET_HIGH = 3'd2;
    localparam [2:0] S_TABLE      = 3'd3;
    localparam [2:0] S_DONE       = 3'd4;

    reg [2:0]  state;
    reg [7:0]  init_idx;
    reg [31:0] delay_cnt;

    reg [1:0]  entry_op;
    reg [15:0] entry_data;
    reg [31:0] entry_delay;

    assign active    = (state != S_DONE);
    assign step      = init_idx;
    assign bus_valid = (state == S_TABLE) && (entry_op == OP_CMD || entry_op == OP_DATA);
    assign bus_rs    = (entry_op == OP_DATA);
    assign bus_data  = entry_data;

    always @(*)
    begin
        entry_op    = OP_END;
        entry_data  = 16'h0000;
        entry_delay = 32'd0;

        case (init_idx)
            8'd0:  begin entry_op = OP_CMD;  entry_data = 16'hF000; end
            8'd1:  begin entry_op = OP_DATA; entry_data = 16'h0055; end
            8'd2:  begin entry_op = OP_CMD;  entry_data = 16'hF001; end
            8'd3:  begin entry_op = OP_DATA; entry_data = 16'h00AA; end
            8'd4:  begin entry_op = OP_CMD;  entry_data = 16'hF002; end
            8'd5:  begin entry_op = OP_DATA; entry_data = 16'h0052; end
            8'd6:  begin entry_op = OP_CMD;  entry_data = 16'hF003; end
            8'd7:  begin entry_op = OP_DATA; entry_data = 16'h0008; end
            8'd8:  begin entry_op = OP_CMD;  entry_data = 16'hF004; end
            8'd9:  begin entry_op = OP_DATA; entry_data = 16'h0001; end

            8'd10: begin entry_op = OP_CMD;  entry_data = 16'hB000; end
            8'd11: begin entry_op = OP_DATA; entry_data = 16'h000D; end
            8'd12: begin entry_op = OP_CMD;  entry_data = 16'hB001; end
            8'd13: begin entry_op = OP_DATA; entry_data = 16'h000D; end
            8'd14: begin entry_op = OP_CMD;  entry_data = 16'hB002; end
            8'd15: begin entry_op = OP_DATA; entry_data = 16'h000D; end
            8'd16: begin entry_op = OP_CMD;  entry_data = 16'hB600; end
            8'd17: begin entry_op = OP_DATA; entry_data = 16'h0024; end
            8'd18: begin entry_op = OP_CMD;  entry_data = 16'hB601; end
            8'd19: begin entry_op = OP_DATA; entry_data = 16'h0024; end
            8'd20: begin entry_op = OP_CMD;  entry_data = 16'hB602; end
            8'd21: begin entry_op = OP_DATA; entry_data = 16'h0024; end
            8'd22: begin entry_op = OP_CMD;  entry_data = 16'hB700; end
            8'd23: begin entry_op = OP_DATA; entry_data = 16'h0024; end
            8'd24: begin entry_op = OP_CMD;  entry_data = 16'hB701; end
            8'd25: begin entry_op = OP_DATA; entry_data = 16'h0024; end
            8'd26: begin entry_op = OP_CMD;  entry_data = 16'hB702; end
            8'd27: begin entry_op = OP_DATA; entry_data = 16'h0024; end

            8'd28: begin entry_op = OP_CMD;  entry_data = 16'h1100; end
            8'd29: begin entry_op = OP_DELAY; entry_delay = SLEEP_OUT_CYCLES; end

            8'd30: begin entry_op = OP_CMD;  entry_data = 16'hF000; end
            8'd31: begin entry_op = OP_DATA; entry_data = 16'h0055; end
            8'd32: begin entry_op = OP_CMD;  entry_data = 16'hF001; end
            8'd33: begin entry_op = OP_DATA; entry_data = 16'h00AA; end
            8'd34: begin entry_op = OP_CMD;  entry_data = 16'hF002; end
            8'd35: begin entry_op = OP_DATA; entry_data = 16'h0052; end
            8'd36: begin entry_op = OP_CMD;  entry_data = 16'hF003; end
            8'd37: begin entry_op = OP_DATA; entry_data = 16'h0008; end
            8'd38: begin entry_op = OP_CMD;  entry_data = 16'hF004; end
            8'd39: begin entry_op = OP_DATA; entry_data = 16'h0000; end

            8'd40: begin entry_op = OP_CMD;  entry_data = 16'h3600; end
            8'd41: begin entry_op = OP_DATA; entry_data = 16'h00A0; end
            8'd42: begin entry_op = OP_CMD;  entry_data = 16'h3A00; end
            8'd43: begin entry_op = OP_DATA; entry_data = 16'h0055; end

            8'd44: begin entry_op = OP_CMD;  entry_data = 16'h2A00; end
            8'd45: begin entry_op = OP_DATA; entry_data = 16'h0000; end
            8'd46: begin entry_op = OP_CMD;  entry_data = 16'h2A01; end
            8'd47: begin entry_op = OP_DATA; entry_data = 16'h0000; end
            8'd48: begin entry_op = OP_CMD;  entry_data = 16'h2A02; end
            8'd49: begin entry_op = OP_DATA; entry_data = 16'h0003; end
            8'd50: begin entry_op = OP_CMD;  entry_data = 16'h2A03; end
            8'd51: begin entry_op = OP_DATA; entry_data = 16'h001F; end

            8'd52: begin entry_op = OP_CMD;  entry_data = 16'h2B00; end
            8'd53: begin entry_op = OP_DATA; entry_data = 16'h0000; end
            8'd54: begin entry_op = OP_CMD;  entry_data = 16'h2B01; end
            8'd55: begin entry_op = OP_DATA; entry_data = 16'h0000; end
            8'd56: begin entry_op = OP_CMD;  entry_data = 16'h2B02; end
            8'd57: begin entry_op = OP_DATA; entry_data = 16'h0001; end
            8'd58: begin entry_op = OP_CMD;  entry_data = 16'h2B03; end
            8'd59: begin entry_op = OP_DATA; entry_data = 16'h00DF; end

            8'd60: begin entry_op = OP_CMD;  entry_data = 16'h2900; end
            default: begin entry_op = OP_END; entry_data = 16'h0000; end
        endcase
    end

    always @(posedge clk or negedge resetn)
    begin
        if (!resetn)
        begin
            state     <= S_POWER;
            lcd_rst   <= 1'b1;
            init_idx  <= 8'd0;
            delay_cnt <= 32'd0;
            done      <= 1'b0;
        end
        else
        begin
            case (state)
                S_POWER:
                begin
                    lcd_rst <= 1'b1;
                    if (delay_cnt == PWR_DELAY_CYCLES - 1)
                    begin
                        delay_cnt <= 32'd0;
                        state     <= S_RESET_LOW;
                    end
                    else
                    begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end
                end

                S_RESET_LOW:
                begin
                    lcd_rst <= 1'b0;
                    if (delay_cnt == RESET_LOW_CYCLES - 1)
                    begin
                        delay_cnt <= 32'd0;
                        state     <= S_RESET_HIGH;
                    end
                    else
                    begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end
                end

                S_RESET_HIGH:
                begin
                    lcd_rst <= 1'b1;
                    if (delay_cnt == POST_RESET_CYCLES - 1)
                    begin
                        delay_cnt <= 32'd0;
                        init_idx  <= 8'd0;
                        state     <= S_TABLE;
                    end
                    else
                    begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end
                end

                S_TABLE:
                begin
                    if (entry_op == OP_END)
                    begin
                        done  <= 1'b1;
                        state <= S_DONE;
                    end
                    else if (entry_op == OP_DELAY)
                    begin
                        if (delay_cnt == entry_delay - 1)
                        begin
                            delay_cnt <= 32'd0;
                            init_idx  <= init_idx + 8'd1;
                        end
                        else
                        begin
                            delay_cnt <= delay_cnt + 32'd1;
                        end
                    end
                    else if (bus_ready)
                    begin
                        init_idx <= init_idx + 8'd1;
                    end
                end

                default:
                begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
