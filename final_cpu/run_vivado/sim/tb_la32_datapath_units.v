`timescale 1ns / 1ps

module tb_la32_datapath_units;
    reg clk = 1'b0;
    reg resetn = 1'b0;
    reg cpu_en = 1'b1;
    always #5 clk = ~clk;

    reg rf_wen;
    reg [4:0] rf_waddr;
    reg [31:0] rf_wdata;
    reg [4:0] rf_raddr1;
    reg [4:0] rf_raddr2;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;

    regfile u_rf(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en),
        .wen(rf_wen), .waddr(rf_waddr), .wdata(rf_wdata),
        .raddr1(rf_raddr1), .rdata1(rf_rdata1),
        .raddr2(rf_raddr2), .rdata2(rf_rdata2)
    );

    reg [31:0] imm_inst;
    wire [31:0] imm_si12;
    wire [31:0] imm_ui12;
    wire [31:0] imm_offs16;
    wire [31:0] imm_offs26;
    wire [31:0] imm_si20;

    la32_imm_gen u_imm(
        .inst(imm_inst), .si12(imm_si12), .ui12(imm_ui12),
        .offs16(imm_offs16), .offs26(imm_offs26), .si20(imm_si20)
    );

    reg br_valid;
    reg br_exception;
    reg br_inst_valid;
    reg br_beq;
    reg br_bne;
    reg br_blt;
    reg br_bge;
    reg br_bltu;
    reg br_bgeu;
    reg br_b;
    reg br_bl;
    reg br_jirl;
    reg [31:0] br_pc;
    reg [31:0] br_rj;
    reg [31:0] br_rd;
    reg [31:0] br_offs16;
    reg [31:0] br_offs26;
    wire br_taken;
    wire [31:0] br_target;

    la32_branch u_branch(
        .valid(br_valid), .exception(br_exception),
        .inst_valid(br_inst_valid), .op_beq(br_beq), .op_bne(br_bne),
        .op_blt(br_blt), .op_bge(br_bge), .op_bltu(br_bltu),
        .op_bgeu(br_bgeu), .op_b(br_b), .op_bl(br_bl),
        .op_jirl(br_jirl), .pc(br_pc), .rj_value(br_rj),
        .rd_value(br_rd), .offs16(br_offs16), .offs26(br_offs26),
        .taken(br_taken), .target(br_target)
    );

    reg [31:0] lsu_check_addr;
    reg lsu_check_ld_h;
    reg lsu_check_ld_w;
    reg lsu_check_ld_hu;
    reg lsu_check_st_h;
    reg lsu_check_st_w;
    reg [31:0] lsu_addr;
    reg [31:0] lsu_store_data;
    reg [31:0] lsu_load_data;
    reg lsu_ld_b;
    reg lsu_ld_h;
    reg lsu_ld_w;
    reg lsu_ld_bu;
    reg lsu_ld_hu;
    reg lsu_st_b;
    reg lsu_st_h;
    reg lsu_st_w;
    wire lsu_align_error;
    wire [3:0] lsu_store_we;
    wire [31:0] lsu_store_wdata;
    wire [31:0] lsu_load_result;

    la32_lsu u_lsu(
        .check_addr(lsu_check_addr), .check_ld_h(lsu_check_ld_h),
        .check_ld_w(lsu_check_ld_w), .check_ld_hu(lsu_check_ld_hu),
        .check_st_h(lsu_check_st_h), .check_st_w(lsu_check_st_w),
        .addr(lsu_addr), .store_data(lsu_store_data),
        .load_data(lsu_load_data), .op_ld_b(lsu_ld_b),
        .op_ld_h(lsu_ld_h), .op_ld_w(lsu_ld_w),
        .op_ld_bu(lsu_ld_bu), .op_ld_hu(lsu_ld_hu),
        .op_st_b(lsu_st_b), .op_st_h(lsu_st_h), .op_st_w(lsu_st_w),
        .align_error(lsu_align_error), .store_we(lsu_store_we),
        .store_wdata(lsu_store_wdata), .load_result(lsu_load_result)
    );

    reg [7:0] hw_int;
    reg [13:0] csr_read_addr;
    wire [31:0] csr_read_data;
    reg csr_we;
    reg [13:0] csr_waddr;
    reg [31:0] csr_wmask;
    reg [31:0] csr_wdata;
    wire csr_has_int;
    wire [63:0] csr_stable_counter;

    la32_stable_counter u_counter(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en),
        .value(csr_stable_counter)
    );

    la32_csr u_csr(
        .clk(clk), .resetn(resetn), .cpu_en(cpu_en), .hw_int(hw_int),
        .read_addr(csr_read_addr), .read_data(csr_read_data),
        .csr_we(csr_we), .csr_waddr(csr_waddr),
        .csr_wmask(csr_wmask), .csr_wdata(csr_wdata),
        .exc_valid(1'b0), .exc_pc(32'b0), .exc_badv(32'b0),
        .exc_ecode(6'b0), .exc_esubcode(9'b0), .exc_tlbr(1'b0),
        .ertn_flush(1'b0), .tlbidx_we(1'b0), .tlbidx_wdata(32'b0),
        .tlbehi_we(1'b0), .tlbehi_wdata(32'b0),
        .tlbelo0_we(1'b0), .tlbelo0_wdata(32'b0),
        .tlbelo1_we(1'b0), .tlbelo1_wdata(32'b0),
        .asid_we(1'b0), .asid_wdata(32'b0), .has_int(csr_has_int),
        .stable_counter(csr_stable_counter), .ertn_pc(), .exc_entry(),
        .csr_crmd(), .csr_prmd(), .csr_ecfg(), .csr_estat(), .csr_era(),
        .csr_badv(), .csr_eentry(), .csr_tlbidx(), .csr_tlbehi(),
        .csr_tlbelo0(), .csr_tlbelo1(), .csr_asid(), .csr_tlbrentry(),
        .csr_dmw0(), .csr_dmw1()
    );

    task check;
        input condition;
        input [255:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %0s", message);
                $finish;
            end
        end
    endtask

    task csr_write;
        input [13:0] addr;
        input [31:0] mask;
        input [31:0] data;
        begin
            csr_waddr = addr;
            csr_wmask = mask;
            csr_wdata = data;
            csr_we = 1'b1;
            @(posedge clk);
            #1 csr_we = 1'b0;
        end
    endtask

    initial begin
        rf_wen = 1'b0;
        rf_waddr = 5'b0;
        rf_wdata = 32'b0;
        rf_raddr1 = 5'b0;
        rf_raddr2 = 5'b0;
        imm_inst = 32'b0;
        br_valid = 1'b1;
        br_exception = 1'b0;
        br_inst_valid = 1'b1;
        br_beq = 1'b0;
        br_bne = 1'b0;
        br_blt = 1'b0;
        br_bge = 1'b0;
        br_bltu = 1'b0;
        br_bgeu = 1'b0;
        br_b = 1'b0;
        br_bl = 1'b0;
        br_jirl = 1'b0;
        br_pc = 32'h1c000100;
        br_rj = 32'b0;
        br_rd = 32'b0;
        br_offs16 = 32'hfffffffc;
        br_offs26 = 32'h00000040;
        lsu_check_addr = 32'b0;
        lsu_check_ld_h = 1'b0;
        lsu_check_ld_w = 1'b0;
        lsu_check_ld_hu = 1'b0;
        lsu_check_st_h = 1'b0;
        lsu_check_st_w = 1'b0;
        lsu_addr = 32'b0;
        lsu_store_data = 32'h000000a5;
        lsu_load_data = 32'h80ff7f01;
        lsu_ld_b = 1'b0;
        lsu_ld_h = 1'b0;
        lsu_ld_w = 1'b0;
        lsu_ld_bu = 1'b0;
        lsu_ld_hu = 1'b0;
        lsu_st_b = 1'b0;
        lsu_st_h = 1'b0;
        lsu_st_w = 1'b0;
        hw_int = 8'b0;
        csr_read_addr = 14'h005;
        csr_we = 1'b0;
        csr_waddr = 14'b0;
        csr_wmask = 32'b0;
        csr_wdata = 32'b0;

        repeat (2) @(posedge clk);
        #1 resetn = 1'b1;

        rf_waddr = 5'd3;
        rf_wdata = 32'h12345678;
        rf_wen = 1'b1;
        @(posedge clk);
        #1 rf_wen = 1'b0;
        rf_raddr1 = 5'd3;
        rf_raddr2 = 5'd0;
        #1 check(rf_rdata1 == 32'h12345678, "register write/read");
        check(rf_rdata2 == 32'b0, "r0 remains zero");

        imm_inst[21:10] = 12'h800;
        #1 check(imm_si12 == 32'hfffff800, "si12 sign extension");
        check(imm_ui12 == 32'h00000800, "ui12 zero extension");

        br_beq = 1'b1;
        br_rj = 32'h55;
        br_rd = 32'h55;
        #1 check(br_taken && br_target == 32'h1c0000fc, "beq and target");
        br_beq = 1'b0;
        br_blt = 1'b1;
        br_rj = 32'hffffffff;
        br_rd = 32'h00000001;
        #1 check(br_taken, "signed blt");
        br_exception = 1'b1;
        #1 check(!br_taken, "exception suppresses branch");
        br_exception = 1'b0;
        br_blt = 1'b0;

        lsu_check_addr = 32'h00001002;
        lsu_check_ld_w = 1'b1;
        lsu_addr = 32'h00001001;
        lsu_st_b = 1'b1;
        #1 check(lsu_align_error, "word alignment error");
        check(lsu_store_we == 4'b0010, "byte store strobe");
        check((lsu_store_wdata & 32'h0000ff00) == 32'h0000a500,
              "byte store data alignment");

        csr_write(14'h004, 32'h00000004, 32'h00000004);
        csr_write(14'h000, 32'h00000004, 32'h00000004);
        hw_int = 8'b00000001;
        @(posedge clk);
        #1 check(csr_read_data[2], "hw_int reflected in ESTAT.IS");
        check(csr_has_int, "enabled hardware interrupt asserted");

        $display("PASS: LA32 datapath unit checks");
        $finish;
    end
endmodule
