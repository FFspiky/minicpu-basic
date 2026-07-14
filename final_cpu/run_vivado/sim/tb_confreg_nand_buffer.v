`timescale 1ns/1ps
`default_nettype none

module tb_confreg_nand_buffer;
    reg clk=0,resetn=0,conf_en=0;
    reg [3:0] conf_we=0;
    reg [31:0] conf_addr=0,conf_wdata=0;
    wire [31:0] conf_rdata;
    tri [7:0] nand_io;
    wire nand_cle,nand_ale,nand_ce_n,nand_re_n,nand_we_n;
    wire [3:0] btn_key_col;

    always #10 clk=~clk;

    confreg #(.SIMULATION(1'b1)) dut(
        .clk(clk),.timer_clk(clk),.resetn(resetn),
        .conf_en(conf_en),.conf_we(conf_we),.conf_addr(conf_addr),
        .conf_wdata(conf_wdata),.conf_rdata(conf_rdata),
        .lcd_status(32'd0),.switch(8'hff),.btn_key_col(btn_key_col),
        .btn_key_row(4'hf),.btn_step(2'b11),.external_key_state(16'd0),
        .uart_rx_i(1'b1),.nand_io(nand_io),.nand_rb_n(1'b1),
        .nand_cle(nand_cle),.nand_ale(nand_ale),.nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),.nand_we_n(nand_we_n));

    task write_mask;
        input [31:0] address; input [31:0] value; input [3:0] mask;
    begin
        @(negedge clk);conf_en=1;conf_we=mask;conf_addr=address;conf_wdata=value;
        @(negedge clk);conf_en=0;conf_we=0;
    end endtask

    task read_word;
        input [31:0] address; output [31:0] value;
    begin
        @(negedge clk);conf_en=1;conf_we=0;conf_addr=address;
        @(posedge clk);#1 value=conf_rdata;
        @(negedge clk);conf_en=0;
    end endtask

    reg [31:0] value;
    initial begin
        repeat(5)@(negedge clk);resetn=1;
        write_mask(32'hbfafc000,32'h11223344,4'hf);
        write_mask(32'hbfafc000,32'haa00cc00,4'b1010);
        read_word(32'hbfafc000,value);
        if(value!==32'haa22cc44)begin
            $display("FAIL CONFREG NAND BRAM read latency/data %h",value);$fatal;
        end
        write_mask(32'hbfafc83c,32'hdeadc0de,4'hf);
        read_word(32'hbfafc83c,value);
        if(value!==32'hdeadc0de)begin
            $display("FAIL CONFREG NAND BRAM last word %h",value);$fatal;
        end
        read_word(32'hbfafc840,value);
        if(value!==0)begin
            $display("FAIL CONFREG NAND BRAM range guard %h",value);$fatal;
        end
        read_word(32'hbfafff50,value);
        if(value!==0)begin
            $display("FAIL CONFREG normal read latency %h",value);$fatal;
        end
        $display("PASS CONFREG NAND synchronous BRAM response");$finish;
    end
endmodule

`default_nettype wire
