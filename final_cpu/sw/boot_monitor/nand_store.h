#ifndef BOOT_NAND_STORE_H
#define BOOT_NAND_STORE_H
#include "platform.h"

#define NAND_BLOCKS 1024
#define NAND_PAGES_PER_BLOCK 64
#define NAND_PAGE_DATA 2048
#define NAND_PAGE_TOTAL 2112
#define NAND_MAX_SLOT_BLOCKS 7
#define PROGRAM_SLOTS 16

struct __attribute__((packed)) program_slot {
    u8 name[32]; u32 image_size; u32 image_crc;
    u8 image_type, block_count; u16 reserved;
    u16 blocks[NAND_MAX_SLOT_BLOCKS];
};
struct __attribute__((packed)) program_directory {
    u32 magic, generation; u16 valid_mask, reserved;
    struct program_slot slots[PROGRAM_SLOTS];
    u8 runtime_bad[NAND_BLOCKS/8];
    u32 crc;
};

int nand_store_init(void);
int nand_store_format(void);
const struct program_directory *nand_directory(void);
int nand_install(u32 slot,const void *image,u32 size);
int nand_remove(u32 slot);
int nand_verify(u32 slot);
int nand_load(u32 slot,void *destination,u32 capacity);
u32 nand_bad_block_count(void);

#endif
