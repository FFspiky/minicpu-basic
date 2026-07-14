#ifndef BOOT_CHECKSUM_H
#define BOOT_CHECKSUM_H
#include "platform.h"
u32 crc32_update(u32 crc, const void *data, u32 size);
u16 ecc512_encode(const u8 data[512]);
int ecc512_correct(u8 data[512], u16 stored);
#endif
