`timescale 1ns/1ps
`default_nettype none

module tb_boot_monitor_runtime;
    reg clk=0, resetn=0;
    reg warm_reset_request=0;
    wire uart_dtr;
    reg [15:0] external_keys=0;
    reg test_passed=0;
    wire board_uart_tx;
    tri [7:0] nand_io;
    wire nand_cle,nand_ale,nand_ce_n,nand_re_n,nand_we_n;
    wire [3:0] menu_selected;
    wire [1:0] system_mode;

    reg [7:0] host_tx_data=0;
    reg host_tx_valid=0;
    wire host_tx_ready,host_tx_busy,host_uart_to_board;
    wire [7:0] board_rx_data;
    wire board_rx_valid,board_rx_frame_error;

    always #5 clk=~clk;

    soc_lite_top #(.SIMULATION(1'b1),.SINGLE_STEP(1'b0)) dut(
        .resetn(resetn),.clk(clk),.uart_rx(host_uart_to_board),
        .uart_tx(board_uart_tx),.uart_dtr(uart_dtr),
        .warm_reset_request(warm_reset_request),
        .nand_io(nand_io),.nand_rb_n(1'b1),
        .nand_cle(nand_cle),.nand_ale(nand_ale),.nand_ce_n(nand_ce_n),
        .nand_re_n(nand_re_n),.nand_we_n(nand_we_n),
        .switch(8'hff),.btn_key_row(4'hf),.btn_step(2'b11),
        .external_key_state(external_keys),.lcd_status(32'd0),
        .menu_selected_slot(menu_selected),.debug_system_mode(system_mode));

    uart_tx #(.CLOCK_HZ(50_000_000),.BAUD(115_200)) host_tx(
        .clk(clk),.resetn(resetn),.enable(1'b1),.data(host_tx_data),
        .valid(host_tx_valid),.tx(host_uart_to_board),
        .ready(host_tx_ready),.busy(host_tx_busy));
    uart_rx #(.CLOCK_HZ(50_000_000),.BAUD(115_200)) board_tx_decoder(
        .clk(clk),.resetn(resetn),.enable(1'b1),.clear_error(1'b0),
        .rx(board_uart_tx),.data(board_rx_data),.valid(board_rx_valid),
        .frame_error(board_rx_frame_error));

    function [31:0] crc32_byte;
        input [31:0] crc_in; input [7:0] data; integer bit_number;
        reg [31:0] value;
    begin
        value=crc_in^data;
        for(bit_number=0;bit_number<8;bit_number=bit_number+1)
            value=(value>>1)^((0-(value&1))&32'hedb88320);
        crc32_byte=value;
    end endfunction

    task send_uart_byte;
        input [7:0] value;
    begin
        while(!host_tx_ready)@(posedge clk);
        @(negedge clk);
        host_tx_data=value;host_tx_valid=1;
        @(negedge clk);host_tx_valid=0;
    end endtask

    task send_body_byte;
        input [7:0] value; inout [31:0] crc;
    begin
        send_uart_byte(value);crc=crc32_byte(crc,value);
    end endtask

    task send_frame5;
        input [7:0] frame_type; input [15:0] sequence;
        input [15:0] length;
        input [7:0] p0,p1,p2,p3,p4;
        reg [31:0] crc;
    begin
        send_uart_byte(8'h7e);crc=32'hffffffff;
        send_body_byte(frame_type,crc);
        send_body_byte(sequence[7:0],crc);send_body_byte(sequence[15:8],crc);
        send_body_byte(length[7:0],crc);send_body_byte(length[15:8],crc);
        if(length>0)send_body_byte(p0,crc);
        if(length>1)send_body_byte(p1,crc);
        if(length>2)send_body_byte(p2,crc);
        if(length>3)send_body_byte(p3,crc);
        if(length>4)send_body_byte(p4,crc);
        crc=~crc;
        send_uart_byte(crc[7:0]);send_uart_byte(crc[15:8]);
        send_uart_byte(crc[23:16]);send_uart_byte(crc[31:24]);
    end endtask

    task receive_uart_byte;
        output [7:0] value;
    begin
        wait(board_rx_valid===1'b1);#1;
        if(board_rx_frame_error)begin $display("FAIL BOOT UART frame error");$fatal;end
        value=board_rx_data;
        wait(board_rx_valid===1'b0);
    end endtask

    task receive_frame;
        output [7:0] frame_type; output [15:0] sequence;
        output [15:0] length; output [7:0] first_payload;
        reg [7:0] value; integer payload_index;
    begin
        value=0;
        while(value!=8'h7e)receive_uart_byte(value);
        receive_uart_byte(frame_type);
        receive_uart_byte(value);sequence[7:0]=value;
        receive_uart_byte(value);sequence[15:8]=value;
        receive_uart_byte(value);length[7:0]=value;
        receive_uart_byte(value);length[15:8]=value;
        first_payload=0;
        for(payload_index=0;payload_index<length;payload_index=payload_index+1)
        begin
            receive_uart_byte(value);
            if(payload_index==0)first_payload=value;
        end
        // CRC is already tested by the boot software; consume its four bytes.
        repeat(4)receive_uart_byte(value);
    end endtask

    task expect_reply;
        input [7:0] expected_type; input [15:0] expected_sequence;
        input [7:0] expected_code;
        reg [7:0] actual_type,code;reg [15:0] actual_sequence,length;
    begin
        receive_frame(actual_type,actual_sequence,length,code);
        if(actual_type!==expected_type || actual_sequence!==expected_sequence ||
           length!==1 || code!==expected_code)begin
            $display("FAIL BOOT reply type=%0d seq=%0d len=%0d code=%02h",
                     actual_type,actual_sequence,length,code);$fatal;
        end
    end endtask

    task force_ram_write;
        input [31:0] address; input [31:0] value;
    begin
        @(negedge clk);
        force dut.data_sram_en=1'b1;force dut.data_sram_we=4'hf;
        force dut.data_sram_addr=address;force dut.data_sram_wdata=value;
        @(posedge clk);#1;
        release dut.data_sram_en;release dut.data_sram_we;
        release dut.data_sram_addr;release dut.data_sram_wdata;
        @(negedge clk);
    end endtask

    task force_conf_write;
        input [31:0] address; input [31:0] value;
    begin
        @(negedge clk);
        force dut.conf_en=1'b1;force dut.conf_we=4'hf;
        force dut.conf_addr=address;force dut.conf_wdata=value;
        @(posedge clk);#1;
        release dut.conf_en;release dut.conf_we;
        release dut.conf_addr;release dut.conf_wdata;
        @(negedge clk);
    end endtask

    reg [7:0] frame_type,code;
    reg [15:0] frame_sequence,frame_length;
    reg [31:0] protected_before;
    initial begin
        #250_000_000;
        $display("FAIL BOOT watchdog pc=%h mode=%0d slot=%0d status=%h uart_status=%h",
                 dut.debug_fetch_pc,system_mode,menu_selected,
                 dut.menu_status,dut.u_confreg.uart_status);
        $fatal;
    end
    initial begin
        repeat(20)@(negedge clk);resetn=1;

        // Skip the text banner and wait for the framed READY notification.
        frame_type=0;
        while(frame_type!=1)
            receive_frame(frame_type,frame_sequence,frame_length,code);
        if(frame_sequence!==0)begin $display("FAIL BOOT READY sequence");$fatal;end
        $display("PASS BOOT READY");

        // Software edge detection must report one event while a key is held.
        external_keys=16'h4000;
        repeat(3000)@(negedge clk);
        if(menu_selected!==4'd1)begin
            $display("FAIL BOOT held key first selection=%0d",menu_selected);$fatal;
        end
        repeat(3000)@(negedge clk);
        if(menu_selected!==4'd1)begin
            $display("FAIL BOOT held key repeated selection=%0d",menu_selected);$fatal;
        end
        external_keys=0;repeat(500)@(negedge clk);
        external_keys=16'h4000;repeat(1000)@(negedge clk);external_keys=0;
        if(menu_selected!==4'd2)begin
            $display("FAIL BOOT second key selection=%0d",menu_selected);$fatal;
        end
        $display("PASS BOOT held-key edge detection");

        // Reproduce the previously failing sequence.  DATA is frame 2 and
        // must be ACKed now that expected_size can be stored in monitor BSS.
        send_frame5(8'd12,16'd0,16'd5,8'd15,8'd16,8'd0,8'd0,8'd0);
        expect_reply(8'd5,16'd0,8'd0);
        send_frame5(8'd2,16'd1,16'd0,0,0,0,0,0);
        expect_reply(8'd5,16'd1,8'd0);
        send_frame5(8'd3,16'd2,16'd5,0,0,0,0,8'h42);
        expect_reply(8'd5,16'd2,8'd0);
        $display("PASS BOOT frame 2 DATA ACK");

        // Training bytes are not frames.  A truncated frame must time out,
        // clear stale FIFO state and allow the next PC retry to resynchronize.
        repeat(20)send_uart_byte(8'h55);
        send_uart_byte(8'h7e);send_uart_byte(8'd11);send_uart_byte(8'd4);
        // Advance the free-running timer instead of simulating all 500,000
        // real timeout ticks in this full-CPU behavioral regression.
        repeat(2000)@(negedge clk);
        force dut.u_confreg.timer=32'hf0000000;
        repeat(2000)@(negedge clk);
        release dut.u_confreg.timer;
        repeat(2000)@(negedge clk);
        send_frame5(8'd11,16'd4,16'd1,8'hff,0,0,0,0);
        expect_reply(8'd6,16'd4,8'd8);
        $display("PASS BOOT UART preamble and truncated-frame recovery");

        // LIST is the largest monitor reply: 5-byte header, 1072-byte
        // directory payload and CRC.  Checking the complete frame catches
        // TX writes lost at the registered TX_READY/busy boundary; short ACK
        // frames alone do not expose that failure.
        send_frame5(8'd8,16'd5,16'd0,0,0,0,0,0);
        receive_frame(frame_type,frame_sequence,frame_length,code);
        if(frame_type!==8'd7 || frame_sequence!==16'd5 || frame_length!==16'd1072)
        begin
            $display("FAIL BOOT LIST type=%0d seq=%0d len=%0d",
                     frame_type,frame_sequence,frame_length);$fatal;
        end
        $display("PASS BOOT complete 1072-byte LIST reply");

        // MENU may write monitor state.  Application modes protect the whole
        // boot window and cannot write SYSTEM_MODE back to MENU themselves.
        force_ram_write(32'h1c003000,32'h12345678);
        if(dut.sim_unified_ram.ram[18'h00c00]!==32'h12345678)begin
            $display("FAIL BOOT menu write blocked");$fatal;
        end
        force_conf_write(32'hbfafff50,32'd1);
        if(system_mode!==2'd1)begin $display("FAIL BOOT mode transition");$fatal;end
        protected_before=dut.sim_unified_ram.ram[18'h00c00];
        force_ram_write(32'h1c003000,32'hdeadbeef);
        if(dut.sim_unified_ram.ram[18'h00c00]!==protected_before)begin
            $display("FAIL BOOT application overwrote monitor");$fatal;
        end
        force_ram_write(32'h1c010000,32'hcafef00d);
        if(dut.sim_unified_ram.ram[18'h04000]!==32'hcafef00d)begin
            $display("FAIL BOOT application RAM write blocked");$fatal;
        end
        force_conf_write(32'hbfafff50,32'd0);
        if(system_mode!==2'd1)begin $display("FAIL BOOT application returned to MENU");$fatal;end

        // F25 is a physical transmitter input and must be driven as an output.
        if(uart_dtr!==1'b1)begin $display("FAIL BOOT DTR not deasserted");$fatal;end

        // A host BREAK on RX must restore MENU without using the output-only
        // DTR net.  Keep the line low beyond the simulation threshold.
        force host_uart_to_board=1'b0;
        repeat(8100)@(negedge clk);
        if(dut.cpu_resetn!==1'b0)begin $display("FAIL BOOT BREAK did not reset CPU");$fatal;end
        release host_uart_to_board;
        repeat(50)@(negedge clk);
        if(system_mode!==2'd0)begin $display("FAIL BOOT reset did not restore MENU");$fatal;end
        $display("PASS BOOT monitor BSS, key edge, frame 2 ACK, write protection and BREAK reset");
        test_passed=1'b1;
        $finish;
    end
endmodule

`default_nettype wire
