`timescale 1ns / 1ps

module tb_mini_cpu;

    reg clk;
    reg resetn;
    reg cpu_en;

    wire [31:0] debug_pc;
    wire [31:0] debug_inst;

    wire        debug_done;
    wire [31:0] debug_store_count;
    wire [15:0] debug_last_store_addr;
    wire [31:0] debug_last_store_data;

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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task cpu_step;
    begin
        @(negedge clk);
        cpu_en = 1'b1;

        @(negedge clk);
        cpu_en = 1'b0;
    end
    endtask

    integer i;

    initial begin
        resetn = 1'b0;
        cpu_en = 1'b0;

        #30;
        resetn = 1'b1;

        @(negedge clk);

        for (i = 0; i < 80; i = i + 1) begin
            cpu_step;
        end

        #200;
        $stop;
    end

    always @(posedge clk) begin
        if (resetn && cpu_en) begin
            $display(
                "PC=%h INST=%h DONE=%b STCNT=%0d LSTA=%h LSTD=%h",
                debug_pc,
                debug_inst,
                debug_done,
                debug_store_count,
                debug_last_store_addr,
                debug_last_store_data
            );
        end
    end

endmodule