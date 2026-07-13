`timescale 1ns/1ps
`default_nettype none

module tb_nand_raw_controller;
    reg clk=0, resetn=0, mmio_en=0;
    reg [3:0] mmio_we=0;
    reg [15:0] mmio_addr=0;
    reg [31:0] mmio_wdata=0;
    wire [31:0] mmio_rdata;
    tri [7:0] nand_io;
    reg [7:0] nand_out=8'hff;
    wire cle,ale,ce_n,re_n,we_n;
    reg rb_n=1;
    reg [7:0] page[0:2111];
    reg [7:0] command=0;
    integer address_count=0, program_index=0, read_index=0, i;

    assign nand_io=!re_n?nand_out:8'bz;
    always #10 clk=~clk;

    nand_raw_controller #(.TIMEOUT_CYCLES(1000)) dut(
        .clk(clk),.resetn(resetn),.mmio_en(mmio_en),.mmio_we(mmio_we),
        .mmio_addr(mmio_addr),.mmio_wdata(mmio_wdata),.mmio_rdata(mmio_rdata),
        .nand_io(nand_io),.nand_rb_n(rb_n),.nand_cle(cle),.nand_ale(ale),
        .nand_ce_n(ce_n),.nand_re_n(re_n),.nand_we_n(we_n));

    // Capture at the beginning of the modeled write pulse to avoid a zero-delay
    // race with the controller deasserting CLE/ALE on the rising edge.
    always @(negedge we_n) begin
        if(cle) begin
            command=nand_io;
            if(nand_io==8'h80) begin address_count=0; program_index=0; end
            if(nand_io==8'h00) begin address_count=0; read_index=0; end
            if(nand_io==8'h60) address_count=0;
            if(nand_io==8'h90) begin address_count=0; read_index=0; end
            if(nand_io==8'hd0) for(i=0;i<2112;i=i+1) page[i]=8'hff;
        end else if(ale) begin
            address_count=address_count+1;
        end else if(command==8'h80 && address_count>=4) begin
            page[program_index]=nand_io;
            program_index=program_index+1;
        end
    end

    always @(*) begin
        if(command==8'h90) begin
            case(read_index)
                0:nand_out=8'hec; 1:nand_out=8'hf1; 2:nand_out=8'h00;
                3:nand_out=8'h95; default:nand_out=8'h40;
            endcase
        end else if(command==8'h70) nand_out=8'h40;
        else nand_out=page[read_index];
    end
    always @(posedge re_n) read_index=read_index+1;

    task write_reg(input [15:0] a,input [31:0] d);
    begin
        @(negedge clk); mmio_en=1;mmio_we=4'hf;mmio_addr=a;mmio_wdata=d;
        @(negedge clk); mmio_en=0;mmio_we=0;
    end endtask
    task read_reg(input [15:0] a,output [31:0] d);
    begin
        @(negedge clk);mmio_en=1;mmio_addr=a;#1 d=mmio_rdata;
        @(negedge clk);mmio_en=0;
    end endtask
    task wait_done;
        reg [31:0] s; integer n;
    begin
        s=0;n=0;
        while(!s[1] && n<20000) begin read_reg(16'hb010,s);n=n+1;end
        if(!s[1]||s[3:2]!=0) begin $display("FAIL status %h",s);$fatal;end
        write_reg(16'hb010,1);
    end endtask

    reg [31:0] value;
    initial begin
        for(i=0;i<2112;i=i+1)page[i]=8'hff;
        repeat(5)@(negedge clk);resetn=1;
        write_reg(16'hb000,2);wait_done();read_reg(16'hb014,value);
        if(value!==32'h9500f1ec)begin $display("FAIL ID %h",value);$fatal;end
        write_reg(16'hc000,32'h44332211);write_reg(16'hb00c,4);write_reg(16'hb000,4);wait_done();
        if({page[3],page[2],page[1],page[0]}!==32'h44332211)begin $display("FAIL PROGRAM data=%h count=%0d addr=%0d",{page[3],page[2],page[1],page[0]},program_index,address_count);$fatal;end
        write_reg(16'hc000,0);write_reg(16'hb000,3);wait_done();read_reg(16'hc000,value);
        if(value!==32'h44332211)begin $display("FAIL READ %h",value);$fatal;end
        write_reg(16'hb000,5);wait_done();
        if(page[0]!==8'hff)begin $display("FAIL ERASE");$fatal;end
        $display("PASS NAND RAW");$finish;
    end
endmodule
`default_nettype wire
