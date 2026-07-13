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

    // Minimal K9F1G08 model used to validate command ordering and every byte
    // moving through the page buffer.  NAND timings themselves are covered by
    // nand_byte_io; this model deliberately responds without extra delay.
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
            if(program_index<2112)page[program_index]=nand_io;
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
        else if(read_index<2112) nand_out=page[read_index];
        else nand_out=8'hff;
    end
    always @(posedge re_n) read_index=read_index+1;

    function [7:0] pattern_byte;
        input integer byte_number;
    begin
        pattern_byte=byte_number[7:0]^8'ha5;
    end endfunction

    task write_mask;
        input [15:0] a; input [31:0] d; input [3:0] w;
    begin
        @(negedge clk); mmio_en=1;mmio_we=w;mmio_addr=a;mmio_wdata=d;
        @(negedge clk); mmio_en=0;mmio_we=0;
    end endtask

    task write_reg;
        input [15:0] a; input [31:0] d;
    begin
        write_mask(a,d,4'hf);
    end endtask

    // Buffer reads are synchronous after BRAM inference.  Waiting for the
    // following rising edge also remains valid for combinational registers.
    task read_reg;
        input [15:0] a; output [31:0] d;
    begin
        @(negedge clk);mmio_en=1;mmio_we=0;mmio_addr=a;
        @(posedge clk);#1 d=mmio_rdata;
        @(negedge clk);mmio_en=0;
    end endtask

    task wait_done;
        reg [31:0] s; integer n;
    begin
        s=0;n=0;
        while(!s[1] && n<100000) begin read_reg(16'hb010,s);n=n+1;end
        if(!s[1]||s[3:2]!=0) begin
            $display("FAIL status %h after %0d polls",s,n);$fatal;
        end
        write_reg(16'hb010,1);
    end endtask

    task erase_page;
    begin
        write_reg(16'hb000,5);wait_done();
    end endtask

    task fill_buffer;
        input integer length;
        integer word_index; reg [31:0] pattern;
    begin
        for(word_index=0;word_index<(length+3)/4;word_index=word_index+1)
        begin
            pattern={pattern_byte(word_index*4+3),
                     pattern_byte(word_index*4+2),
                     pattern_byte(word_index*4+1),
                     pattern_byte(word_index*4+0)};
            write_reg(16'hc000+word_index*4,pattern);
        end
    end endtask

    task check_page_pattern;
        input integer length; integer byte_number;
    begin
        for(byte_number=0;byte_number<length;byte_number=byte_number+1)
            if(page[byte_number]!==pattern_byte(byte_number)) begin
                $display("FAIL PROGRAM length=%0d byte=%0d got=%h expected=%h",
                         length,byte_number,page[byte_number],
                         pattern_byte(byte_number));
                $fatal;
            end
    end endtask

    task clear_buffer_words;
        input integer length; integer word_index;
    begin
        for(word_index=0;word_index<(length+3)/4;word_index=word_index+1)
            write_reg(16'hc000+word_index*4,0);
    end endtask

    task check_buffer_pattern;
        input integer length;
        integer word_index, lane, byte_number; reg [31:0] word_value;
    begin
        for(word_index=0;word_index<(length+3)/4;word_index=word_index+1)
        begin
            read_reg(16'hc000+word_index*4,word_value);
            for(lane=0;lane<4;lane=lane+1)
            begin
                byte_number=word_index*4+lane;
                if(byte_number<length &&
                   word_value[lane*8 +: 8]!==pattern_byte(byte_number)) begin
                    $display("FAIL READ length=%0d byte=%0d got=%h expected=%h",
                             length,byte_number,word_value[lane*8 +: 8],
                             pattern_byte(byte_number));
                    $fatal;
                end
            end
        end
    end endtask

    task round_trip;
        input integer length;
    begin
        erase_page();
        fill_buffer(length);
        write_reg(16'hb00c,length);
        write_reg(16'hb000,4);
        wait_done();
        if(program_index!==length)begin
            $display("FAIL PROGRAM count length=%0d count=%0d",length,program_index);
            $fatal;
        end
        check_page_pattern(length);
        clear_buffer_words(length);
        write_reg(16'hb000,3);
        wait_done();
        check_buffer_pattern(length);
        $display("PASS NAND round trip length=%0d",length);
    end endtask

    reg [31:0] value;
    integer timeout_polls;
    initial begin
        for(i=0;i<2112;i=i+1)page[i]=8'hff;
        repeat(5)@(negedge clk);resetn=1;

        write_reg(16'hb000,2);wait_done();read_reg(16'hb014,value);
        if(value!==32'h9500f1ec)begin $display("FAIL ID %h",value);$fatal;end

        // Four independent byte enables and first/cross-word/last-word MMIO.
        write_reg(16'hc000,32'h11223344);
        write_mask(16'hc000,32'haa00cc00,4'b1010);
        read_reg(16'hc000,value);
        if(value!==32'haa22cc44)begin $display("FAIL byte enables %h",value);$fatal;end
        write_reg(16'hc004,32'h88776655);
        read_reg(16'hc004,value);
        if(value!==32'h88776655)begin $display("FAIL word boundary %h",value);$fatal;end
        write_reg(16'hc83c,32'hdeadc0de);
        read_reg(16'hc83c,value);
        if(value!==32'hdeadc0de)begin $display("FAIL last word %h",value);$fatal;end
        read_reg(16'hc840,value);
        if(value!==0)begin $display("FAIL out-of-range read %h",value);$fatal;end

        round_trip(1);
        round_trip(4);
        round_trip(2048);
        round_trip(2112);

        // Ready/Busy timeout, error reporting and W1C/status-clear behavior.
        rb_n=0;
        write_reg(16'hb000,1);
        value=0;timeout_polls=0;
        while(!value[1] && timeout_polls<3000) begin
            read_reg(16'hb010,value);timeout_polls=timeout_polls+1;
        end
        if(value[3:2]!==2'b11)begin
            $display("FAIL timeout status %h",value);$fatal;
        end
        write_reg(16'hb010,1);
        rb_n=1;
        read_reg(16'hb010,value);
        if(value[3:0]!==0)begin $display("FAIL status clear %h",value);$fatal;end

        $display("PASS NAND RAW BRAM");$finish;
    end
endmodule
`default_nettype wire
