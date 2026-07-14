#ifndef BOOT_LA32IMG_H
#define BOOT_LA32IMG_H
#include "platform.h"

#define LA32IMG_MAGIC0 0x3233414cu
#define LA32IMG_MAGIC1 0x00474d49u

struct __attribute__((packed)) la32img_header {
    u8 magic[8]; u16 version; u16 header_size;
    u32 type, flags, entry, end_pc, stack_top, ram_required;
    u32 segment_count, payload_size; u8 name[32];
    u32 build_id, header_crc, image_crc;
};
struct __attribute__((packed)) la32img_segment {
    u32 flags, load_address, file_size, memory_size, payload_offset, crc32;
};

int image_validate(const void *blob, u32 blob_size);
int image_load_and_start(void *blob, u32 blob_size, u32 slot);
#endif
