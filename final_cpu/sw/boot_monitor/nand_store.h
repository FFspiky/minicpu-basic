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

/* Read-only boot diagnostics returned by the protocol DIAGNOSTICS command. */
struct __attribute__((packed)) nand_store_diagnostics {
    u32 version;
    u32 nand_id0, nand_id1;
    u32 scan_read_errors, first_scan_error_block;
    u32 bad_block_count;
    u32 directory_block0, directory_block1;
    u32 directory_result0, directory_result1;
    u32 selected_generation, selected_valid_mask;
    u32 init_result;
};

int nand_store_init(void);
int nand_store_format(void);
const struct program_directory *nand_directory(void);
const struct nand_store_diagnostics *nand_diagnostics(void);
int nand_install(u32 slot,const void *image,u32 size);
int nand_remove(u32 slot);
int nand_verify(u32 slot);
int nand_load(u32 slot,void *destination,u32 capacity);
u32 nand_bad_block_count(void);

#endif
