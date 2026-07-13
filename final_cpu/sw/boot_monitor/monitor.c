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

struct frame { u8 type; u16 sequence,length; u8 payload[520]; };
static u32 expected_size,receive_operation,receive_slot;
static u16 previous_keys;

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
    u8 head[5];u16 i;u32 got,crc;
    if(uart_getc()!=SOF)return -1;
    for(i=0;i<5;i++)head[i]=uart_getc();
    f->type=head[0];f->sequence=read_u16(head+1);f->length=read_u16(head+3);
    if(f->length>sizeof(f->payload))return -2;
    for(i=0;i<f->length;i++)f->payload[i]=uart_getc();
    got=(u32)uart_getc();got|=(u32)uart_getc()<<8;got|=(u32)uart_getc()<<16;got|=(u32)uart_getc()<<24;
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
            else reply(FT_ACK,f->sequence,0);
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
            crc=read_u32(f->payload);MMIO32(MENU_STATUS)=2;result=finish_receive(crc);
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
            send_frame(FT_DONE,f->sequence,(const u8 *)d,sizeof(*d));break;
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
    put_text("LA32BOOT 1\r\n");store=nand_store_init();
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
            if(receive_frame(&frame))MMIO32(MENU_STATUS)=0xff;
            else handle_frame(&frame);
        }
    }
}
