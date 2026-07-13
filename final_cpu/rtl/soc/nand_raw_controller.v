`timescale 1ns / 1ps
`default_nettype none

module nand_raw_controller #(
    parameter integer TIMEOUT_CYCLES=2_500_000
)(
    input wire clk, input wire resetn,
    input wire mmio_en, input wire [3:0] mmio_we,
    input wire [15:0] mmio_addr, input wire [31:0] mmio_wdata,
    output reg [31:0] mmio_rdata,
    inout wire [7:0] nand_io, input wire nand_rb_n,
    output wire nand_cle, output wire nand_ale, output wire nand_ce_n,
    output wire nand_re_n, output wire nand_we_n
);
    localparam OP_RESET=1, OP_READ_ID=2, OP_READ_PAGE=3,
               OP_PROGRAM_PAGE=4, OP_ERASE_BLOCK=5;
    localparam S_IDLE=0, S_ISSUE=1, S_WAIT_BYTE=2, S_WAIT_RB=3,
               S_READ_START=4, S_READ_WAIT=5, S_WRITE_START=6,
               S_WRITE_WAIT=7, S_STATUS_START=8, S_STATUS_WAIT=9,
               S_DONE=10, S_ERROR=11, S_WRITE_DELAY=12,
               S_BUFFER_PREFETCH=13;
    localparam A_DONE=0, A_READ_ID=1, A_WAIT_READ=2,
               A_WRITE_DATA=3, A_WAIT_STATUS=4, A_STATUS_READ=5,
               A_WAIT_DONE=6;
    localparam integer BUFFER_WORDS=528;

    reg [3:0] state;
    reg [2:0] after_sequence;
    reg [2:0] after_ready;
    reg [7:0] operation;
    reg [7:0] sequence_data[0:6];
    reg [1:0] sequence_kind[0:6]; // 0 command, 1 address
    reg [2:0] sequence_length, sequence_index;
    reg [31:0] page_address;
    reg [15:0] column_address;
    reg [11:0] transfer_length, byte_index;
    reg [31:0] timeout_count;
    reg [1:0] program_delay_count;
    reg [39:0] id_data;
    reg [7:0] status_byte;
    reg operation_done, operation_error, operation_timeout;
    (* ASYNC_REG = "TRUE" *) reg [1:0] nand_rb_sync;
    wire nand_ready = nand_rb_sync[1];

    // 2112 bytes map to 528 32-bit words.  The two clocked access processes
    // intentionally match Vivado's true-dual-port block-RAM inference style:
    // port A is the CPU/MMIO port and port B belongs to the NAND sequencer.
    // The memory itself is not reset; transfer_length defines valid contents.
    (* ram_style = "block" *) reg [31:0] page_buffer[0:BUFFER_WORDS-1];
    reg [31:0] buffer_cpu_rdata;
    reg [31:0] buffer_nand_rdata;
    reg        buffer_read_response;

    reg byte_start_write, byte_start_read;
    wire byte_done, byte_busy;
    wire [7:0] byte_read_data;
    wire register_select=mmio_addr[15:8]==8'hb0;
    wire buffer_select=mmio_addr[15:12]==4'hc;
    wire mmio_write=mmio_en && |mmio_we;
    wire [9:0] buffer_word=mmio_addr[11:2];
    wire buffer_word_valid=buffer_word<BUFFER_WORDS;
    wire controller_busy=state!=S_IDLE && state!=S_DONE && state!=S_ERROR;
    wire data_write_phase=(state==S_WRITE_START)||(state==S_WRITE_WAIT);

    wire [9:0] nand_buffer_word=byte_index[11:2];
    wire [1:0] nand_buffer_lane=byte_index[1:0];
    reg [7:0] nand_program_data;
    always @(*)
    begin
        case(nand_buffer_lane)
            2'd0:nand_program_data=buffer_nand_rdata[7:0];
            2'd1:nand_program_data=buffer_nand_rdata[15:8];
            2'd2:nand_program_data=buffer_nand_rdata[23:16];
            default:nand_program_data=buffer_nand_rdata[31:24];
        endcase
    end

    // Port A: synchronous MMIO read and four independent byte write enables.
    // Software only accesses the page buffer while the controller is idle.
    always @(posedge clk)
    begin
        if(mmio_en && buffer_select && buffer_word_valid && state==S_IDLE)
        begin
            if(mmio_we[0])page_buffer[buffer_word][7:0]<=mmio_wdata[7:0];
            if(mmio_we[1])page_buffer[buffer_word][15:8]<=mmio_wdata[15:8];
            if(mmio_we[2])page_buffer[buffer_word][23:16]<=mmio_wdata[23:16];
            if(mmio_we[3])page_buffer[buffer_word][31:24]<=mmio_wdata[31:24];
            if(!(mmio_we[0]||mmio_we[1]||mmio_we[2]||mmio_we[3]))
                buffer_cpu_rdata<=page_buffer[buffer_word];
        end
    end

    // Port B: a synchronous read supplies program bytes.  Page reads write a
    // single byte lane without a read/modify/write mux.
    always @(posedge clk)
    begin
        buffer_nand_rdata<=page_buffer[nand_buffer_word];
        if(state==S_READ_WAIT && byte_done && operation==OP_READ_PAGE)
        begin
            case(nand_buffer_lane)
                2'd0:page_buffer[nand_buffer_word][7:0]<=byte_read_data;
                2'd1:page_buffer[nand_buffer_word][15:8]<=byte_read_data;
                2'd2:page_buffer[nand_buffer_word][23:16]<=byte_read_data;
                2'd3:page_buffer[nand_buffer_word][31:24]<=byte_read_data;
            endcase
        end
    end

    nand_byte_io u_byte(
        .clk(clk),.resetn(resetn),
        .start_write(byte_start_write),.start_read(byte_start_read),
        .write_cle(!data_write_phase && sequence_kind[sequence_index]==0),
        .write_ale(!data_write_phase && sequence_kind[sequence_index]==1),
        .write_data(data_write_phase?nand_program_data:sequence_data[sequence_index]),
        .read_data(byte_read_data),.busy(byte_busy),.done(byte_done),
        .nand_io(nand_io),.nand_cle(nand_cle),.nand_ale(nand_ale),
        .nand_ce_n(nand_ce_n),.nand_re_n(nand_re_n),
        .nand_we_n(nand_we_n)
    );

    // Register/status reads remain combinational.  A page-buffer read is
    // returned during the cycle after its request; confreg has a matching
    // one-cycle bypass so the CPU-visible latency remains unchanged.
    always @(*)
    begin
        mmio_rdata=0;
        if(buffer_read_response)
            mmio_rdata=buffer_cpu_rdata;
        else if(register_select)
            case(mmio_addr[7:0])
                8'h04:mmio_rdata=page_address;
                8'h08:mmio_rdata={16'd0,column_address};
                8'h0c:mmio_rdata={20'd0,transfer_length};
                8'h10:mmio_rdata={16'd0,status_byte,2'd0,nand_ready,
                                   operation_timeout,operation_error,
                                   operation_done,controller_busy};
                8'h14:mmio_rdata=id_data[31:0];
                8'h18:mmio_rdata={24'd0,id_data[39:32]};
                default:mmio_rdata=0;
            endcase
    end

    task begin_sequence;
        input [2:0] length;
        input [2:0] action;
        begin
            sequence_length<=length; sequence_index<=0;
            after_sequence<=action; state<=S_ISSUE;
        end
    endtask

    always @(posedge clk)
    begin
        if(!resetn)
        begin
            state<=S_IDLE; operation<=0; after_sequence<=0; after_ready<=0;
            sequence_length<=0; sequence_index<=0; page_address<=0;
            column_address<=0; transfer_length<=12'd2112; byte_index<=0;
            timeout_count<=0; id_data<=0; status_byte<=0;
            program_delay_count<=0; nand_rb_sync<=2'b00;
            operation_done<=0; operation_error<=0; operation_timeout<=0;
            byte_start_write<=0; byte_start_read<=0;
            buffer_read_response<=0;
        end
        else
        begin
            nand_rb_sync<={nand_rb_sync[0],nand_rb_n};
            byte_start_write<=0; byte_start_read<=0;
            buffer_read_response<=mmio_en && !mmio_write && buffer_select &&
                                  buffer_word_valid && state==S_IDLE;

            if(mmio_write && register_select && state==S_IDLE)
            begin
                if(mmio_addr[7:0]==8'h04)page_address<=mmio_wdata;
                if(mmio_addr[7:0]==8'h08)column_address<=mmio_wdata[15:0];
                if(mmio_addr[7:0]==8'h0c)
                    transfer_length<=mmio_wdata[11:0]>2112 ?
                                     12'd2112:mmio_wdata[11:0];
            end

            case(state)
                S_IDLE:
                begin
                    if(mmio_write && register_select && mmio_addr[7:0]==8'h00)
                    begin
                        operation<=mmio_wdata[7:0]; operation_done<=0;
                        operation_error<=0; operation_timeout<=0;
                        timeout_count<=0; byte_index<=0;
                        case(mmio_wdata[7:0])
                            OP_RESET:
                            begin
                                sequence_data[0]<=8'hff;sequence_kind[0]<=0;
                                begin_sequence(1,A_WAIT_DONE);
                            end
                            OP_READ_ID:
                            begin
                                sequence_data[0]<=8'h90;sequence_kind[0]<=0;
                                sequence_data[1]<=8'h00;sequence_kind[1]<=1;
                                begin_sequence(2,A_READ_ID);
                            end
                            OP_READ_PAGE,OP_PROGRAM_PAGE:
                            begin
                                sequence_data[0]<=mmio_wdata[7:0]==OP_READ_PAGE ?
                                                  8'h00:8'h80;
                                sequence_kind[0]<=0;
                                sequence_data[1]<=column_address[7:0];sequence_kind[1]<=1;
                                sequence_data[2]<={4'd0,column_address[11:8]};sequence_kind[2]<=1;
                                sequence_data[3]<=page_address[7:0];sequence_kind[3]<=1;
                                sequence_data[4]<=page_address[15:8];sequence_kind[4]<=1;
                                sequence_data[5]<=page_address[23:16];sequence_kind[5]<=1;
                                if(mmio_wdata[7:0]==OP_READ_PAGE)
                                begin
                                    sequence_data[6]<=8'h30;sequence_kind[6]<=0;
                                    begin_sequence(7,A_WAIT_READ);
                                end
                                else begin_sequence(6,A_WRITE_DATA);
                            end
                            OP_ERASE_BLOCK:
                            begin
                                sequence_data[0]<=8'h60;sequence_kind[0]<=0;
                                sequence_data[1]<=page_address[7:0];sequence_kind[1]<=1;
                                sequence_data[2]<=page_address[15:8];sequence_kind[2]<=1;
                                sequence_data[3]<=page_address[23:16];sequence_kind[3]<=1;
                                sequence_data[4]<=8'hd0;sequence_kind[4]<=0;
                                begin_sequence(5,A_WAIT_STATUS);
                            end
                            default:begin operation_error<=1;state<=S_ERROR;end
                        endcase
                    end
                end
                S_ISSUE:begin byte_start_write<=1;state<=S_WAIT_BYTE;end
                S_WAIT_BYTE:
                    if(byte_done)
                    begin
                        if(sequence_index+1<sequence_length)
                        begin sequence_index<=sequence_index+1'b1;state<=S_ISSUE;end
                        else case(after_sequence)
                            A_DONE:begin operation_done<=1;state<=S_DONE;end
                            A_READ_ID:begin byte_index<=0;state<=S_READ_START;end
                            A_WAIT_READ:begin timeout_count<=0;after_ready<=A_WAIT_READ;state<=S_WAIT_RB;end
                            A_WRITE_DATA:begin byte_index<=0;program_delay_count<=0;state<=S_WRITE_DELAY;end
                            A_WAIT_STATUS:begin timeout_count<=0;after_ready<=A_WAIT_STATUS;state<=S_WAIT_RB;end
                            A_WAIT_DONE:begin timeout_count<=0;after_ready<=A_WAIT_DONE;state<=S_WAIT_RB;end
                            A_STATUS_READ:begin operation<=8'hfe;byte_index<=0;state<=S_READ_START;end
                            default:state<=S_ERROR;
                        endcase
                    end
                S_WAIT_RB:
                begin
                    if(nand_ready && timeout_count>8)
                    begin
                        if(after_ready==A_WAIT_READ)
                        begin byte_index<=0;state<=S_READ_START;end
                        else if(after_ready==A_WAIT_DONE)
                        begin operation_done<=1;state<=S_DONE;end
                        else
                        begin
                            sequence_data[0]<=8'h70;sequence_kind[0]<=0;
                            begin_sequence(1,A_STATUS_READ);
                        end
                    end
                    else if(timeout_count>=TIMEOUT_CYCLES)
                    begin operation_timeout<=1;operation_error<=1;state<=S_ERROR;end
                    else timeout_count<=timeout_count+1'b1;
                end
                S_WRITE_DELAY:
                begin
                    // tADL is 100 ns minimum.  Leave margin before fetching
                    // and issuing the first program byte.
                    if(program_delay_count==2)
                        state<=S_BUFFER_PREFETCH;
                    else
                        program_delay_count<=program_delay_count+1'b1;
                end
                S_BUFFER_PREFETCH:
                begin
                    // Port B is synchronous.  This state supplies a full
                    // cycle after the first word and every word boundary.
                    state<=S_WRITE_START;
                end
                S_READ_START:begin byte_start_read<=1;state<=S_READ_WAIT;end
                S_READ_WAIT:
                    if(byte_done)
                    begin
                        if(operation==OP_READ_ID)
                            id_data[byte_index*8 +: 8]<=byte_read_data;
                        else if(operation==8'hfe)
                        begin
                            status_byte<=byte_read_data;
                            operation_error<=byte_read_data[0];
                        end
                        if(operation==8'hfe ||
                           (operation==OP_READ_ID && byte_index==4) ||
                           (operation==OP_READ_PAGE && byte_index+1>=transfer_length))
                        begin operation_done<=1;state<=S_DONE;end
                        else
                        begin byte_index<=byte_index+1'b1;state<=S_READ_START;end
                    end
                S_WRITE_START:
                begin
                    byte_start_write<=1;state<=S_WRITE_WAIT;
                end
                S_WRITE_WAIT:
                    if(byte_done)
                    begin
                        if(byte_index+1>=transfer_length)
                        begin
                            sequence_data[0]<=8'h10;sequence_kind[0]<=0;
                            begin_sequence(1,A_WAIT_STATUS);
                        end
                        else
                        begin
                            byte_index<=byte_index+1'b1;
                            state<=byte_index[1:0]==2'd3 ?
                                   S_BUFFER_PREFETCH:S_WRITE_START;
                        end
                    end
                S_DONE:
                begin
                    if(mmio_write && register_select && mmio_addr[7:0]==8'h10)
                    begin
                        operation_done<=0;operation_error<=0;
                        operation_timeout<=0;status_byte<=0;state<=S_IDLE;
                    end
                end
                S_ERROR:
                begin
                    operation_done<=1;
                    if(mmio_write && register_select && mmio_addr[7:0]==8'h10)
                    begin
                        operation_done<=0;operation_error<=0;
                        operation_timeout<=0;status_byte<=0;state<=S_IDLE;
                    end
                end
                default:state<=S_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
