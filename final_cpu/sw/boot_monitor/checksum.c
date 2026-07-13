#include "checksum.h"

void *memcpy(void *destination,const void *source,u32 size)
{
    u8 *d=destination;const u8 *s=source;while(size--)*d++=*s++;return destination;
}

void *memset(void *destination,int value,u32 size)
{
    u8 *d=destination;while(size--)*d++=(u8)value;return destination;
}

u32 crc32_update(u32 crc, const void *raw, u32 size)
{
    const u8 *data=(const u8 *)raw;
    u32 i,j;
    crc=~crc;
    for(i=0;i<size;i++) {
        crc^=data[i];
        for(j=0;j<8;j++) crc=(crc>>1)^((0u-(crc&1u))&0xedb88320u);
    }
    return ~crc;
}

// Project-local SECDED code: 13-bit XOR syndrome over 4096 data bits plus
// one overall parity bit.  It corrects one data-bit error and detects two.
u16 ecc512_encode(const u8 data[512])
{
    u32 bit, syndrome=0, parity=0;
    for(bit=0;bit<4096;bit++) {
        if((data[bit>>3]>>(bit&7))&1u) { syndrome^=bit+1; parity^=1; }
    }
    return (u16)(syndrome | (parity<<13));
}

int ecc512_correct(u8 data[512], u16 stored)
{
    u16 diff=(u16)(ecc512_encode(data)^stored);
    u16 syndrome=diff&0x1fffu;
    u16 parity=(diff>>13)&1u;
    if(!syndrome && !parity) return 0;
    if(syndrome && parity) {
        if(syndrome<=4096) {
            u32 bit=(u32)syndrome-1u;
            data[bit>>3]^=(u8)(1u<<(bit&7));
            return 1;
        }
        return -1;
    }
    if(!syndrome && parity) return 1; // stored overall parity bit
    return -1; // double data error or stored syndrome-bit error
}
