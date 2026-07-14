#include <stdio.h>
#include "checksum.h"

int main(void)
{
    u8 data[512];
    u16 ecc;
    u32 i;
    for(i=0;i<512;i++) data[i]=(u8)(i*37u+11u);
    if(crc32_update(0,"123456789",9)!=0xcbf43926u) return 1;
    ecc=ecc512_encode(data);
    data[173]^=0x20;
    if(ecc512_correct(data,ecc)!=1 || data[173]!=(u8)(173u*37u+11u)) return 2;
    data[3]^=1;data[400]^=4;
    if(ecc512_correct(data,ecc)!=-1) return 3;
    puts("PASS CHECKSUM ECC");
    return 0;
}
