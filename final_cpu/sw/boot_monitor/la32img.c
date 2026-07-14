#include "la32img.h"
#include "checksum.h"

static void memory_move(u8 *dst,const u8 *src,u32 n)
{
    u32 i;
    if(dst<src)for(i=0;i<n;i++)dst[i]=src[i];
    else if(dst>src)for(i=n;i;i--)dst[i-1]=src[i-1];
}
static void memory_zero(u8 *dst,u32 n){while(n--)*dst++=0;}
static int ranges_overlap(u32 a,u32 an,u32 b,u32 bn)
{
    return an!=0 && bn!=0 && a<b+bn && b<a+an;
}

int image_validate(const void *raw,u32 size)
{
    const u8 *blob=(const u8 *)raw;
    const struct la32img_header *h=(const struct la32img_header *)raw;
    const struct la32img_segment *s;
    u32 i,j,header_crc,image_crc,entry_ok=0;
    struct la32img_header copy;
    if(size<sizeof(*h) || *(const u32 *)&h->magic[0]!=LA32IMG_MAGIC0 ||
       *(const u32 *)&h->magic[4]!=LA32IMG_MAGIC1 || h->version!=1) return -1;
    if(h->segment_count==0 || h->segment_count>8 ||
       h->header_size!=sizeof(*h)+h->segment_count*sizeof(*s) ||
       h->header_size+h->payload_size!=size) return -2;
    if((h->entry&3) || h->stack_top<STACK_START || h->stack_top>STACK_TOP ||
       h->ram_required>APP_END-APP_START || h->type>2) return -2;
    copy=*h; copy.header_crc=0; copy.image_crc=0;
    header_crc=crc32_update(0,&copy,sizeof(copy));
    header_crc=crc32_update(header_crc,blob+sizeof(copy),h->header_size-sizeof(copy));
    if(header_crc!=h->header_crc)return -3;
    image_crc=crc32_update(0,&copy,sizeof(copy));
    image_crc=crc32_update(image_crc,blob+sizeof(copy),size-sizeof(copy));
    if(image_crc!=h->image_crc)return -4;
    s=(const struct la32img_segment *)(blob+sizeof(*h));
    for(i=0;i<h->segment_count;i++) {
        u32 start=s[i].load_address,end=start+s[i].memory_size;
        if((start&3)||start<APP_START||end>APP_END||s[i].file_size>s[i].memory_size||
           s[i].payload_offset+s[i].file_size>h->payload_size)return -5;
        if(crc32_update(0,blob+h->header_size+s[i].payload_offset,s[i].file_size)!=s[i].crc32)return -6;
        if((s[i].flags&4) && h->entry>=start && h->entry<end)entry_ok=1;
        for(j=0;j<i;j++)if(start<s[j].load_address+s[j].memory_size&&s[j].load_address<end)return -7;
    }
    return entry_ok?0:-8;
}

int image_load_and_start(void *raw,u32 size,u32 slot)
{
    u8 *blob=(u8 *)raw;
    struct la32img_header *h=(struct la32img_header *)raw;
    struct la32img_segment *s,segments[8];
    u8 moved[8];
    u32 i,j,remaining,progress,header_size,segment_count;
    u32 entry,end_pc,type,stack_top,system_mode;
    if(image_validate(raw,size))return -1;
    s=(struct la32img_segment *)(blob+sizeof(*h));
    entry=h->entry; end_pc=h->end_pc; type=h->type; stack_top=h->stack_top;
    header_size=h->header_size; segment_count=h->segment_count;
    for(i=0;i<segment_count;i++){segments[i]=s[i];moved[i]=0;}
    system_mode=(type==0)?3:type;

    /*
     * The container itself occupies application RAM.  Select a relocation
     * whose destination does not overlap any other segment's source payload;
     * copying it cannot destroy data that is still needed.  Segment metadata
     * is kept on the monitor stack because the first relocation may overwrite
     * the image header and segment table.
     */
    remaining=segment_count;
    while(remaining) {
        progress=0;
        for(i=0;i<segment_count;i++) {
            u32 dst;
            if(moved[i])continue;
            dst=segments[i].load_address;
            for(j=0;j<segment_count;j++) {
                u32 src;
                if(i==j||moved[j])continue;
                src=(u32)(blob+header_size+segments[j].payload_offset);
                if(ranges_overlap(dst,segments[i].file_size,
                                  src,segments[j].file_size))break;
            }
            if(j!=segment_count)continue;
            memory_move((u8 *)dst,
                        blob+header_size+segments[i].payload_offset,
                        segments[i].file_size);
            moved[i]=1;remaining--;progress=1;break;
        }
        if(!progress)return -2;
    }

    /* No payload source remains live, so BSS clearing cannot corrupt it. */
    for(i=0;i<segment_count;i++)
        memory_zero((u8 *)(segments[i].load_address+segments[i].file_size),
                    segments[i].memory_size-segments[i].file_size);
    MMIO32(ACTIVE_SLOT)=slot; MMIO32(DYNAMIC_END_PC)=end_pc; MMIO32(SYSTEM_MODE)=system_mode;
    __asm__ volatile("or $sp,%0,$r0\n\tjirl $r0,%1,0"::"r"(stack_top),"r"(entry):"memory");
    return 0;
}
