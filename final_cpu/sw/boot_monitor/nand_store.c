#include "nand_store.h"
#include "checksum.h"
#include "la32img.h"

#define DIR_MAGIC 0x5244334cu /* L3DR */
#define PAGE_MAGIC 0xa5u
#define NAND_OP_RESET 1
#define NAND_OP_READ_ID 2
#define NAND_OP_READ_PAGE 3
#define NAND_OP_PROGRAM_PAGE 4
#define NAND_OP_ERASE_BLOCK 5

static u8 bad_blocks[NAND_BLOCKS/8];
static u8 checked_blocks[NAND_BLOCKS/8];
static struct program_directory directory;
static u16 directory_blocks[2];
static u8 page[NAND_PAGE_TOTAL];
static struct nand_store_diagnostics diagnostics;
static struct nand_directory_scan directory_scan;

static void copy(void *d,const void *s,u32 n){u8 *x=d;const u8 *y=s;while(n--)*x++=*y++;}
static void fill(void *d,u8 v,u32 n){u8 *x=d;while(n--)*x++=v;}
static int bad(u32 block){return (bad_blocks[block>>3]>>(block&7))&1;}
static void mark_bad(u32 block){bad_blocks[block>>3]|=(u8)(1u<<(block&7));}
static void retire_block(u32 block)
{
    mark_bad(block);
    directory.runtime_bad[block>>3]|=(u8)(1u<<(block&7));
}
u32 nand_bad_block_count(void){u32 i,n=0;for(i=0;i<NAND_BLOCKS;i++)n+=bad(i);return n;}

static int controller_wait(void)
{
    u32 timeout=0x2000000u,status;
    do { status=MMIO32(NAND_STATUS); if(status&2u)break; } while(--timeout);
    if(!timeout || (status&(4u|8u)))return -1;
    MMIO32(NAND_STATUS)=1;
    return 0;
}
static int command(u32 op,u32 page_addr,u32 column,u32 length)
{
    MMIO32(NAND_PAGE)=page_addr;MMIO32(NAND_COLUMN)=column;MMIO32(NAND_LENGTH)=length;
    MMIO32(NAND_CMD)=op;return controller_wait();
}
static void buffer_write(const u8 *src,u32 length)
{
    u32 i;for(i=0;i<length;i+=4)MMIO32(NAND_BUFFER+i)=
        (u32)src[i]|((u32)src[i+1]<<8)|((u32)src[i+2]<<16)|((u32)src[i+3]<<24);
}
static void buffer_read(u8 *dst,u32 length)
{
    u32 i,w;for(i=0;i<length;i+=4){w=MMIO32(NAND_BUFFER+i);dst[i]=w;dst[i+1]=w>>8;dst[i+2]=w>>16;dst[i+3]=w>>24;}
}
static int raw_read(u32 page_addr,u32 column,u8 *dst,u32 length)
{
    if(command(NAND_OP_READ_PAGE,page_addr,column,length))return -1;
    buffer_read(dst,(length+3)&~3u);return 0;
}
static int raw_program(u32 page_addr,const u8 *src,u32 length)
{
    buffer_write(src,(length+3)&~3u);
    return command(NAND_OP_PROGRAM_PAGE,page_addr,0,length);
}
static int erase_block(u32 block){return command(NAND_OP_ERASE_BLOCK,block*NAND_PAGES_PER_BLOCK,0,0);}

static void make_ecc(u8 *p)
{
    u32 i;u16 e;
    p[2048]=0xff;p[2049]=PAGE_MAGIC;
    for(i=0;i<4;i++){e=ecc512_encode(p+i*512);p[2056+i*2]=(u8)e;p[2057+i*2]=(u8)(e>>8);}
    {u32 crc=crc32_update(0,p,2048);p[2064]=crc;p[2065]=crc>>8;p[2066]=crc>>16;p[2067]=crc>>24;}
}
static int check_ecc(u8 *p)
{
    u32 i,stored_crc;int fixed=0,r;
    if(p[2049]!=PAGE_MAGIC)return -1;
    for(i=0;i<4;i++){u16 e=(u16)p[2056+i*2]|((u16)p[2057+i*2]<<8);r=ecc512_correct(p+i*512,e);if(r<0)return -2;fixed+=r;}
    stored_crc=(u32)p[2064]|((u32)p[2065]<<8)|((u32)p[2066]<<16)|((u32)p[2067]<<24);
    if(crc32_update(0,p,2048)!=stored_crc)return -3;
    return fixed;
}
static int read_data_page(u32 page_addr,u8 *dst)
{
    if(raw_read(page_addr,0,page,NAND_PAGE_TOTAL))return -1;
    if(check_ecc(page)<0)return -2;
    copy(dst,page,NAND_PAGE_DATA);
    return 0;
}
static int write_data_page(u32 page_addr,const u8 *src,u32 length,u32 slot,u32 index)
{
    u32 expected_crc;
    fill(page,0xff,sizeof(page));copy(page,src,length);page[2050]=(u8)slot;
    page[2051]=(u8)index;page[2052]=(u8)(index>>8);page[2053]=(u8)(index>>16);page[2054]=(u8)(index>>24);
    make_ecc(page);expected_crc=crc32_update(0,page,NAND_PAGE_TOTAL);
    if(raw_program(page_addr,page,NAND_PAGE_TOTAL))return -1;
    if(raw_read(page_addr,0,page,NAND_PAGE_TOTAL)||check_ecc(page)<0)return -2;
    /* ECC/CRC only proves that the page is internally consistent.  It may be
       an old valid page if erase/program targeted the wrong row.  Compare the
       complete readback with the exact page image prepared above. */
    return crc32_update(0,page,NAND_PAGE_TOTAL)==expected_crc?0:-3;
}

static u32 directory_crc(const struct program_directory *d)
{return crc32_update(0,d,sizeof(*d)-sizeof(d->crc));}
static int read_directory_block(u32 block,struct program_directory *out)
{
    int result;
    if(raw_read(block*NAND_PAGES_PER_BLOCK,0,page,NAND_PAGE_TOTAL))return -1;
    result=check_ecc(page);
    if(result<0)return result-1; /* -2 page magic, -3 ECC, -4 page CRC */
    copy(out,page,sizeof(*out));
    if(out->magic!=DIR_MAGIC)return -5;
    return out->crc==directory_crc(out)?0:-6;
}
static int write_directory_block(u32 block,const struct program_directory *d)
{
    if(erase_block(block))return -1;
    return write_data_page(block*NAND_PAGES_PER_BLOCK,(const u8 *)d,sizeof(*d),0xff,0);
}
static int commit_directory(void)
{
    struct program_directory next=directory;
    u32 target=(directory.generation+1)&1u;
    next.generation++;next.crc=directory_crc(&next);
    if(write_directory_block(directory_blocks[target],&next))return -1;
    directory=next;return 0;
}

static int factory_bad(u32 block)
{
    u8 marker[4];int result;
    if(block>=NAND_BLOCKS||bad(block))return 1;
    if((checked_blocks[block>>3]>>(block&7))&1)return 0;
    checked_blocks[block>>3]|=(u8)(1u<<(block&7));
    result=raw_read(block*64,2048,marker,1);
    if(!result&&marker[0]==0xff)result=raw_read(block*64+1,2048,marker,1);
    if(result) {
        if(!diagnostics.scan_read_errors)diagnostics.first_scan_error_block=block;
        diagnostics.scan_read_errors++;mark_bad(block);return 1;
    }
    if(marker[0]!=0xff){mark_bad(block);return 1;}
    return 0;
}
static int choose_directory_blocks(void)
{
    u32 block,n=0;for(block=0;block<NAND_BLOCKS&&n<2;block++)if(!factory_bad(block))directory_blocks[n++]=(u16)block;
    return n==2?0:-1;
}

const struct program_directory *nand_directory(void){return &directory;}
const struct nand_store_diagnostics *nand_diagnostics(void){return &diagnostics;}
const struct nand_directory_scan *nand_scan_directories(u32 start_block,u32 block_count)
{
    static struct program_directory candidate;
    u32 block,end_block,index;int result;
    fill(&directory_scan,0,sizeof(directory_scan));directory_scan.version=2;
    if(start_block>NAND_BLOCKS)start_block=NAND_BLOCKS;
    if(block_count>64)block_count=64;
    end_block=start_block+block_count;
    if(end_block>NAND_BLOCKS)end_block=NAND_BLOCKS;
    directory_scan.start_block=start_block;
    for(block=start_block;block<end_block;block++) {
        if(factory_bad(block))continue;
        directory_scan.scanned_blocks++;
        result=read_directory_block(block,&candidate);
        if(result==0) {
            index=directory_scan.stored_candidates;
            directory_scan.valid_candidates++;
            if(index<NAND_DIRECTORY_SCAN_MAX) {
                directory_scan.candidates[index].block=block;
                directory_scan.candidates[index].generation=candidate.generation;
                directory_scan.candidates[index].valid_mask=candidate.valid_mask;
                directory_scan.stored_candidates++;
            }
        } else if(result==-1)directory_scan.raw_read_failures++;
        else if(result==-2)directory_scan.page_magic_failures++;
        else if(result==-3)directory_scan.ecc_failures++;
        else if(result==-4)directory_scan.page_crc_failures++;
        else if(result==-5)directory_scan.directory_magic_failures++;
        else if(result==-6)directory_scan.directory_crc_failures++;
    }
    return &directory_scan;
}
int nand_store_init(void)
{
    struct program_directory a,b;int va,vb;
    fill(&diagnostics,0,sizeof(diagnostics));diagnostics.version=1;
    diagnostics.first_scan_error_block=0xffffffffu;
    MMIO32(NAND_CMD)=NAND_OP_RESET;
    if(controller_wait()){diagnostics.init_result=(u32)-1;return -1;}
    MMIO32(NAND_CMD)=NAND_OP_READ_ID;
    if(controller_wait()){diagnostics.init_result=(u32)-2;return -2;}
    diagnostics.nand_id0=MMIO32(NAND_ID0);diagnostics.nand_id1=MMIO32(NAND_ID1);
    if((diagnostics.nand_id0&0xffffu)!=0xf1ecu){diagnostics.init_result=(u32)-3;return -3;}
    fill(bad_blocks,0,sizeof(bad_blocks));fill(checked_blocks,0,sizeof(checked_blocks));
    if(choose_directory_blocks()){diagnostics.init_result=(u32)-4;return -4;}
    diagnostics.bad_block_count=nand_bad_block_count();
    diagnostics.directory_block0=directory_blocks[0];diagnostics.directory_block1=directory_blocks[1];
    va=read_directory_block(directory_blocks[0],&a);vb=read_directory_block(directory_blocks[1],&b);
    diagnostics.directory_result0=(u32)va;diagnostics.directory_result1=(u32)vb;
    if(va&&vb){
        /* Keep an empty directory immediately installable.  Leaving magic at
           zero makes the first commit look successful in RAM, but the next
           boot rejects that persisted page and all slots appear empty. */
        fill(&directory,0,sizeof(directory));directory.magic=DIR_MAGIC;
        directory.crc=directory_crc(&directory);diagnostics.init_result=1;return 1;
    }
    directory=(!va&&(vb||a.generation>=b.generation))?a:b;
    {u32 i;for(i=0;i<sizeof(bad_blocks);i++)bad_blocks[i]|=directory.runtime_bad[i];}
    diagnostics.selected_generation=directory.generation;
    diagnostics.selected_valid_mask=directory.valid_mask;
    diagnostics.init_result=0;
    return 0;
}
int nand_store_format(void)
{
    fill(&directory,0,sizeof(directory));directory.magic=DIR_MAGIC;directory.generation=0;directory.crc=directory_crc(&directory);
    if(write_directory_block(directory_blocks[0],&directory))return -1;
    directory.generation=1;directory.crc=directory_crc(&directory);
    return write_directory_block(directory_blocks[1],&directory);
}

static int block_in_use(u32 block,int ignore_slot)
{
    u32 s,i;if(block==directory_blocks[0]||block==directory_blocks[1])return 1;
    for(s=0;s<PROGRAM_SLOTS;s++)if((int)s!=ignore_slot&&(directory.valid_mask&(1u<<s)))
        for(i=0;i<directory.slots[s].block_count;i++)if(directory.slots[s].blocks[i]==block)return 1;
    return 0;
}
static int allocate_blocks(u16 *out,u32 count)
{
    u32 block,n=0;for(block=0;block<NAND_BLOCKS&&n<count;block++)
        if(!factory_bad(block)&&!block_in_use(block,-1))out[n++]=(u16)block;
    return n==count?0:-1;
}

int nand_install(u32 slot,const void *raw,u32 size)
{
    const u8 *image=raw;struct program_slot record;u32 blocks,pages,i,remain,offset=0;
    if(slot>=PROGRAM_SLOTS||size>APP_END-APP_START||image_validate(raw,size))return -1;
    blocks=(size+128*1024-1)/(128*1024);if(blocks>NAND_MAX_SLOT_BLOCKS)return -2;
    fill(&record,0,sizeof(record));if(allocate_blocks(record.blocks,blocks))return -3;
    record.block_count=(u8)blocks;record.image_size=size;record.image_crc=crc32_update(0,raw,size);
    record.image_type=((const struct la32img_header *)raw)->type;
    copy(record.name,((const struct la32img_header *)raw)->name,32);
    pages=(size+2047)/2048;remain=size;
    for(i=0;i<pages;i++) {
        u32 block=record.blocks[i/64],page_in_block=i%64,n=remain>2048?2048:remain;
        if(page_in_block==0&&erase_block(block)){retire_block(block);commit_directory();return -4;}
        if(write_data_page(block*64+page_in_block,image+offset,n,slot,i)){retire_block(block);commit_directory();return -5;}
        offset+=n;remain-=n;
    }
    directory.slots[slot]=record;directory.valid_mask|=(u16)(1u<<slot);
    return commit_directory();
}
int nand_remove(u32 slot)
{
    if(slot>=PROGRAM_SLOTS||!(directory.valid_mask&(1u<<slot)))return -1;
    directory.valid_mask&=(u16)~(1u<<slot);fill(&directory.slots[slot],0,sizeof(directory.slots[slot]));
    return commit_directory();
}
int nand_load(u32 slot,void *dst,u32 capacity)
{
    struct program_slot *s;u8 *out=dst;u32 pages,i,remain,offset=0;
    if(slot>=PROGRAM_SLOTS||!(directory.valid_mask&(1u<<slot)))return -1;
    s=&directory.slots[slot];
    if(s->image_size>capacity)return -2;
    pages=(s->image_size+2047)/2048;remain=s->image_size;
    for(i=0;i<pages;i++){u32 n=remain>2048?2048:remain;if(read_data_page(s->blocks[i/64]*64+i%64,page))return -3;copy(out+offset,page,n);offset+=n;remain-=n;}
    return crc32_update(0,dst,s->image_size)==s->image_crc?(int)s->image_size:-4;
}
int nand_verify(u32 slot){return nand_load(slot,(void *)APP_START,APP_END-APP_START)<0?-1:0;}
