`timescale 1ns / 1ps

module tb_la32_pipeline_smoke;
    reg clk = 1'b0;
    reg resetn = 1'b0;
    always #5 clk = ~clk;

    wire inst_en;
    wire [3:0] inst_we;
    wire [31:0] inst_addr;
    wire [31:0] inst_wdata;
    reg [31:0] inst_rdata;
    wire data_en;
    wire [3:0] data_we;
    wire [31:0] data_addr;
    wire [31:0] data_wdata;
    reg [31:0] data_rdata;
    wire [31:0] debug_wb_pc;
    wire [3:0] debug_wb_rf_we;
    wire [4:0] debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata;

    reg [31:0] imem [0:31];
    reg [31:0] dmem [0:31];
    integer i;
    integer cycles;
    reg seen_r1;
    reg seen_r2;
    reg seen_r3;
    reg seen_r4;
    reg seen_r5;

    mycpu_top dut(
        .clk(clk), .resetn(resetn), .cpu_en(1'b1), .hw_int(8'b0),
        .inst_sram_en(inst_en), .inst_sram_we(inst_we),
        .inst_sram_addr(inst_addr), .inst_sram_wdata(inst_wdata),
        .inst_sram_rdata(inst_rdata),
        .data_sram_en(data_en), .data_sram_we(data_we),
        .data_sram_addr(data_addr), .data_sram_wdata(data_wdata),
        .data_sram_rdata(data_rdata),
        .debug_wb_pc(debug_wb_pc), .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),
        .debug_last_wb_valid(), .debug_last_wb_pc(),
        .debug_last_wb_wnum(), .debug_last_wb_wdata(),
        .debug_commit_valid(), .debug_commit_pc(), .debug_commit_inst(),
        .debug_fetch_pc(), .debug_pipe_valid(), .debug_pipe_hazard()
    );

    always @(posedge clk) begin
        if (inst_en) begin
            inst_rdata <= imem[(inst_addr - 32'h1c000000) >> 2];
        end
        if (data_en) begin
            data_rdata <= dmem[data_addr[6:2]];
            if (data_we[0]) dmem[data_addr[6:2]][7:0]   <= data_wdata[7:0];
            if (data_we[1]) dmem[data_addr[6:2]][15:8]  <= data_wdata[15:8];
            if (data_we[2]) dmem[data_addr[6:2]][23:16] <= data_wdata[23:16];
            if (data_we[3]) dmem[data_addr[6:2]][31:24] <= data_wdata[31:24];
        end

        if (debug_wb_rf_we == 4'hf) begin
            case (debug_wb_rf_wnum)
                5'd1: begin
                    if (debug_wb_rf_wdata !== 32'd5) $fatal;
                    if (debug_wb_pc !== 32'h1c000000) $fatal;
                    seen_r1 <= 1'b1;
                end
                5'd2: begin
                    if (debug_wb_rf_wdata !== 32'd7) $fatal;
                    if (debug_wb_pc !== 32'h1c000004) $fatal;
                    seen_r2 <= 1'b1;
                end
                5'd3: begin
                    if (debug_wb_rf_wdata !== 32'd12) $fatal;
                    if (debug_wb_pc !== 32'h1c000008) $fatal;
                    seen_r3 <= 1'b1;
                end
                5'd4: begin
                    if (debug_wb_rf_wdata !== 32'd12) $fatal;
                    if (debug_wb_pc !== 32'h1c000010) $fatal;
                    seen_r4 <= 1'b1;
                end
                5'd5: begin
                    if (debug_wb_rf_wdata !== 32'd17) $fatal;
                    if (debug_wb_pc !== 32'h1c000014) $fatal;
                    seen_r5 <= 1'b1;
                end
                default: begin end
            endcase
        end
    end

    initial begin
        inst_rdata = 32'b0;
        data_rdata = 32'b0;
        seen_r1 = 1'b0;
        seen_r2 = 1'b0;
        seen_r3 = 1'b0;
        seen_r4 = 1'b0;
        seen_r5 = 1'b0;
        for (i = 0; i < 32; i = i + 1) begin
            imem[i] = 32'h50000000;
            dmem[i] = 32'b0;
        end

        imem[0] = 32'h02801401; // addi.w r1, r0, 5
        imem[1] = 32'h02801c02; // addi.w r2, r0, 7
        imem[2] = 32'h00100823; // add.w  r3, r1, r2
        imem[3] = 32'h29800003; // st.w   r3, r0, 0
        imem[4] = 32'h28800004; // ld.w   r4, r0, 0
        imem[5] = 32'h00100485; // add.w  r5, r4, r1
        imem[6] = 32'h50000000; // b      0

        repeat (3) @(posedge clk);
        #1 resetn = 1'b1;

        cycles = 0;
        while (!(seen_r1 && seen_r2 && seen_r3 && seen_r4 && seen_r5) &&
               cycles < 200) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (!(seen_r1 && seen_r2 && seen_r3 && seen_r4 && seen_r5)) begin
            $display("FAIL: pipeline commits missing r1=%b r2=%b r3=%b r4=%b r5=%b",
                     seen_r1, seen_r2, seen_r3, seen_r4, seen_r5);
            $fatal;
        end
        if (dmem[0] !== 32'd12) begin
            $display("FAIL: store/load datapath result=%h", dmem[0]);
            $fatal;
        end

        $display("PASS: modular LA32 pipeline instruction flow");
        $finish;
    end
endmodule
