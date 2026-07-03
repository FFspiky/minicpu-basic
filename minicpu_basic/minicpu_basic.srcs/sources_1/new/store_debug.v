`timescale 1ns / 1ps

module store_debug(
    input         clk,
    input         resetn,
    input         cpu_en,
    input         data_ram_we,
    input  [15:0] data_ram_addr,
    input  [31:0] store_data,
    output reg        debug_done,
    output reg [31:0] debug_store_count,
    output reg [15:0] debug_last_store_addr,
    output reg [31:0] debug_last_store_data
);

    always @(posedge clk) begin
        if (!resetn) begin
            debug_done            <= 1'b0;
            debug_store_count     <= 32'd0;
            debug_last_store_addr <= 16'd0;
            debug_last_store_data <= 32'd0;
        end
        else if (cpu_en && data_ram_we) begin
            debug_done            <= 1'b1;
            debug_store_count     <= debug_store_count + 32'd1;
            debug_last_store_addr <= data_ram_addr;
            debug_last_store_data <= store_data;
        end
    end

endmodule
