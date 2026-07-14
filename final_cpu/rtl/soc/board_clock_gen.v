`timescale 1ns / 1ps
`default_nettype none

// Board clocking for the A7 experiment box. AC19 is a clock-capable SRCC pin.
module board_clock_gen(
    input  wire clk_in,
    input  wire resetn,
    output wire cpu_clk,
    output wire timer_clk,
    output wire locked
);
    wire clk_in_ibuf;
    wire clkfb;
    wire clkfb_buf;
    wire cpu_clk_raw;
    wire timer_clk_raw;
    wire locked_int;

    IBUF u_clk_ibuf(.I(clk_in), .O(clk_in_ibuf));

    PLLE2_ADV #(
        .BANDWIDTH("OPTIMIZED"),
        .COMPENSATION("ZHOLD"),
        .STARTUP_WAIT("FALSE"),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT(8),
        .CLKFBOUT_PHASE(0.000),
        // Keep the 100 MHz peripheral/VGA clock unchanged.  The refactored
        // pipeline targets 50 MHz, using the exact 1:2 relationship
        // 800/16 = 50 MHz and 800/8 = 100 MHz.
        .CLKOUT0_DIVIDE(16),
        .CLKOUT0_PHASE(0.000),
        .CLKOUT0_DUTY_CYCLE(0.500),
        .CLKOUT1_DIVIDE(8),
        .CLKOUT1_PHASE(0.000),
        .CLKOUT1_DUTY_CYCLE(0.500),
        .CLKIN1_PERIOD(10.000)
    ) u_pll (
        .CLKFBOUT(clkfb),
        .CLKOUT0(cpu_clk_raw),
        .CLKOUT1(timer_clk_raw),
        .CLKOUT2(), .CLKOUT3(), .CLKOUT4(), .CLKOUT5(),
        .CLKFBIN(clkfb_buf),
        .CLKIN1(clk_in_ibuf), .CLKIN2(1'b0), .CLKINSEL(1'b1),
        .DADDR(7'd0), .DCLK(1'b0), .DEN(1'b0), .DI(16'd0),
        .DO(), .DRDY(), .DWE(1'b0),
        .LOCKED(locked_int), .PWRDWN(1'b0), .RST(~resetn)
    );

    BUFG u_feedback_buf(.I(clkfb), .O(clkfb_buf));
    BUFG u_cpu_buf(.I(cpu_clk_raw), .O(cpu_clk));
    BUFG u_timer_buf(.I(timer_clk_raw), .O(timer_clk));
    assign locked = locked_int;
endmodule

`default_nettype wire
