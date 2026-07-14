#include "platform.h"
#include "checksum.h"
#include "la32img.h"
#include "nand_store.h"

#define SOF 0x7e
#define FT_READY 1
#define FT_HEADER 2
#define FT_DATA 3
#define FT_END 4
#define FT_ACK 5
#define FT_NACK 6
#define FT_DONE 7
#define FT_LIST 8
#define FT_INSTALL 9
#define FT_REMOVE 10
#define FT_VERIFY 11
#define FT_RUN_TEMP 12
#define FT_FORMAT 13
#define FT_DIAGNOSTICS 14
#define FT_SCAN_DIRECTORIES 15

struct frame { u8 type; u16 sequence,length; u8 payload[520]; };
struct __attribute__((packed)) directory_slot_response {
    u32 magic,generation;u16 valid_mask,slot_index;
    struct program_slot slot;
};
static u32 expected_size,receive_operation,receive_slot;
static u16 previous_keys;
static u16 completed_end_sequence;
static u32 completed_end_crc;
static int completed_end_result;
static u8 completed_end_valid;

static void put_text(const char *s){while(*s)uart_putc((u8)*s++);}
static u16 read_u16(const u8 *p){return (u16)p[0]|((u16)p[1]<<8);}
static u32 read_u32(const u8 *p){return (u32)p[0]|((u32)p[1]<<8)|((u32)p[2]<<16)|((u32)p[3]<<24);}
static void send_u32(u32 v){uart_putc(v);uart_putc(v>>8);uart_putc(v>>16);uart_putc(v>>24);}

static void send_frame(u8 type,u16 sequence,const u8 *payload,u16 length)
{
    u8 head[5];u32 crc;u16 i;
    head[0]=type;head[1]=(u8)sequence;head[2]=(u8)(sequence>>8);head[3]=(u8)length;head[4]=(u8)(length>>8);
    crc=crc32_update(0,head,5);crc=crc32_update(crc,payload,length);
    uart_putc(SOF);for(i=0;i<5;i++)uart_putc(head[i]);for(i=0;i<length;i++)uart_putc(payload[i]);send_u32(crc);
}
static void reply(u8 type,u16 sequence,u8 code){send_frame(type,sequence,&code,1);}

static int receive_frame(struct frame *f)
{
    u8 byte,head[5];u16 i;u32 got,crc;
    /*
     * A damaged byte must not leave the monitor blocked inside a partial
     * frame indefinitely.  Ignore the 0x55 training preamble, seek the next
     * SOF, and place a finite deadline on every byte after it.  The PC can
     * then retransmit the same idempotent frame after a line error.
     */
    do {
        if(uart_getc_timeout(&byte,UART_BYTE_TIMEOUT_TICKS))return -4;
    } while(byte!=SOF);
    for(i=0;i<5;i++)if(uart_getc_timeout(&head[i],UART_BYTE_TIMEOUT_TICKS))return -4;
    f->type=head[0];f->sequence=read_u16(head+1);f->length=read_u16(head+3);
    if(f->length>sizeof(f->payload))return -2;
    for(i=0;i<f->length;i++)if(uart_getc_timeout(&f->payload[i],UART_BYTE_TIMEOUT_TICKS))return -4;
    if(uart_getc_timeout(&byte,UART_BYTE_TIMEOUT_TICKS))return -4;
    got=(u32)byte;
    if(uart_getc_timeout(&byte,UART_BYTE_TIMEOUT_TICKS))return -4;
    got|=(u32)byte<<8;
    if(uart_getc_timeout(&byte,UART_BYTE_TIMEOUT_TICKS))return -4;
    got|=(u32)byte<<16;
    if(uart_getc_timeout(&byte,UART_BYTE_TIMEOUT_TICKS))return -4;
    got|=(u32)byte<<24;
    crc=crc32_update(0,head,5);crc=crc32_update(crc,f->payload,f->length);
    return crc==got?0:-3;
}

static void update_menu(void)
{
    const struct program_directory *d=nand_directory();
    MMIO32(SLOT_VALID)=d->valid_mask;
}
static int finish_receive(u32 transmitted_crc)
{
    u32 crc=crc32_update(0,(void *)APP_START,expected_size);
    if(crc!=transmitted_crc||image_validate((void *)APP_START,expected_size))return -1;
    if(receive_operation==FT_INSTALL)return nand_install(receive_slot,(void *)APP_START,expected_size);
    return 0;
}
static void handle_frame(struct frame *f)
{
    u32 offset,crc;int result;
    switch(f->type)
    {
        case FT_INSTALL:case FT_RUN_TEMP:
            if(f->length<5){reply(FT_NACK,f->sequence,1);break;}
            receive_operation=f->type;receive_slot=f->payload[0];expected_size=read_u32(f->payload+1);
            if(expected_size>APP_END-APP_START||receive_slot>=PROGRAM_SLOTS)reply(FT_NACK,f->sequence,2);
            else {completed_end_valid=0;reply(FT_ACK,f->sequence,0);}
            break;
        case FT_HEADER: reply(FT_ACK,f->sequence,0);break;
        case FT_DATA:
            if(f->length<4){reply(FT_NACK,f->sequence,3);break;}
            offset=read_u32(f->payload);
            if(offset+f->length-4>expected_size){reply(FT_NACK,f->sequence,4);break;}
            {u32 i;u8 *dst=(u8 *)(APP_START+offset);for(i=4;i<f->length;i++)dst[i-4]=f->payload[i];}
            reply(FT_ACK,f->sequence,0);break;
        case FT_END:
            if(f->length!=4){reply(FT_NACK,f->sequence,5);break;}
            crc=read_u32(f->payload);
            if(completed_end_valid&&f->sequence==completed_end_sequence&&crc==completed_end_crc) {
                reply(completed_end_result?FT_NACK:FT_DONE,f->sequence,completed_end_result?6:0);break;
            }
            MMIO32(MENU_STATUS)=2;result=finish_receive(crc);
            completed_end_sequence=f->sequence;completed_end_crc=crc;
            completed_end_result=result;completed_end_valid=1;
            if(result){MMIO32(MENU_STATUS)=0xff;reply(FT_NACK,f->sequence,6);}
            else {
                update_menu();MMIO32(MENU_STATUS)=0;reply(FT_DONE,f->sequence,0);
                if(receive_operation==FT_RUN_TEMP)image_load_and_start((void *)APP_START,expected_size,15);
            }
            break;
        case FT_REMOVE:
            result=f->length==1?nand_remove(f->payload[0]):-1;update_menu();reply(result?FT_NACK:FT_ACK,f->sequence,result?7:0);break;
        case FT_VERIFY:
            result=f->length==1?nand_verify(f->payload[0]):-1;reply(result?FT_NACK:FT_ACK,f->sequence,result?8:0);break;
        case FT_FORMAT:
            result=nand_store_format();update_menu();reply(result?FT_NACK:FT_ACK,f->sequence,result?9:0);break;
        case FT_LIST:
        {
            const struct program_directory *d=nand_directory();
            if(f->length==0) {
                /* Keep the original full-directory reply for old tools. */
                send_frame(FT_DONE,f->sequence,(const u8 *)d,sizeof(*d));
            } else if(f->length==1&&f->payload[0]<PROGRAM_SLOTS) {
                static struct directory_slot_response response;
                u32 slot=f->payload[0];
                response.magic=d->magic;response.generation=d->generation;
                response.valid_mask=d->valid_mask;response.slot_index=(u16)slot;
                response.slot=d->slots[slot];
                send_frame(FT_DONE,f->sequence,(const u8 *)&response,sizeof(response));
            } else reply(FT_NACK,f->sequence,11);
            break;
        }
        case FT_DIAGNOSTICS:
        {
            const struct nand_store_diagnostics *d=nand_diagnostics();
            send_frame(FT_DONE,f->sequence,(const u8 *)d,sizeof(*d));break;
        }
        case FT_SCAN_DIRECTORIES:
        {
            const struct nand_directory_scan *s;
            if(f->length!=4){reply(FT_NACK,f->sequence,10);break;}
            s=nand_scan_directories(read_u16(f->payload),read_u16(f->payload+2));
            send_frame(FT_DONE,f->sequence,(const u8 *)s,sizeof(*s));break;
        }
        default:reply(FT_NACK,f->sequence,0xff);break;
    }
}

static void run_slot(u32 slot)
{
    const struct program_directory *d=nand_directory();int size;
    if(!(d->valid_mask&(1u<<slot)))return;
    MMIO32(MENU_STATUS)=1;size=nand_load(slot,(void *)APP_START,APP_END-APP_START);
    if(size<0){MMIO32(MENU_STATUS)=0xff;return;}
    MMIO32(MENU_STATUS)=3;
    if(image_load_and_start((void *)APP_START,(u32)size,slot))MMIO32(MENU_STATUS)=0xff;
}

int main(void)
{
    int store;u32 selected=0;struct frame frame;
    MMIO32(SYSTEM_MODE)=0;MMIO32(MENU_SELECTED)=0;MMIO32(MENU_STATUS)=1;
    uart_reset_receiver();put_text("LA32BOOT 1\r\n");store=nand_store_init();
    if(store<0)MMIO32(MENU_STATUS)=0xff;else {MMIO32(MENU_STATUS)=store?0xfe:0;update_menu();}
    send_frame(FT_READY,0,0,0);
    for(;;)
    {
        u16 keys=(u16)MMIO32(BTN_KEY),pressed=(u16)(keys&~previous_keys);previous_keys=keys;
        if(pressed&KEY_UP){selected=(selected+15)&15;MMIO32(MENU_SELECTED)=selected;}
        if(pressed&KEY_DOWN){selected=(selected+1)&15;MMIO32(MENU_SELECTED)=selected;}
        if(pressed&KEY_ENTER)run_slot(selected);
        if((pressed&KEY_R)&&store==0){MMIO32(MENU_STATUS)=nand_verify(selected)?0xff:0;}
        if(uart_available())
        {
            if(receive_frame(&frame)){uart_reset_receiver();MMIO32(MENU_STATUS)=0xff;}
            else handle_frame(&frame);
        }
    }
}
