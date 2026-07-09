TOOLPREFIX ?= /opt/loongarch32r/bin/loongarch32r-linux-gnusf-
CC         := $(TOOLPREFIX)gcc
AS         := $(TOOLPREFIX)as
LD         := $(TOOLPREFIX)ld
OBJCOPY    := $(TOOLPREFIX)objcopy
OBJDUMP    := $(TOOLPREFIX)objdump
PYTHON     ?= python3

OBJ_DIR    := obj
RAM_WORDS  ?= 262144
ROOT_DIR   := ../..
MEM_DIR    := $(ROOT_DIR)/mem/exp23

CFLAGS     := -march=loongarch32r -mabi=ilp32s -msoft-float \
              -ffreestanding -fno-builtin -fno-pic -fno-pie \
              -fno-asynchronous-unwind-tables -fno-unwind-tables \
              -fno-stack-protector -Os -Wall -Wextra
ASFLAGS    := -mabi=ilp32
LDFLAGS    := -T game.ld -nostdlib

.PHONY: all clean install

all: $(OBJ_DIR)/inst_ram.mif $(OBJ_DIR)/inst_ram.coe $(OBJ_DIR)/racing_game.dump

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

$(OBJ_DIR)/start.o: start.S | $(OBJ_DIR)
	$(AS) $(ASFLAGS) $< -o $@

$(OBJ_DIR)/racing_game.o: racing_game.c racing_game_mmio.h | $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/racing_game.elf: game.ld $(OBJ_DIR)/start.o $(OBJ_DIR)/racing_game.o
	$(LD) $(LDFLAGS) $(OBJ_DIR)/start.o $(OBJ_DIR)/racing_game.o -o $@

$(OBJ_DIR)/racing_game.bin: $(OBJ_DIR)/racing_game.elf
	$(OBJCOPY) -O binary $< $@

$(OBJ_DIR)/racing_game.dump: $(OBJ_DIR)/racing_game.elf
	$(OBJDUMP) -alD $< > $@

$(OBJ_DIR)/inst_ram.mif $(OBJ_DIR)/inst_ram.coe: $(OBJ_DIR)/racing_game.bin bin_to_mif.py
	$(PYTHON) bin_to_mif.py $(OBJ_DIR)/racing_game.bin --mif $(OBJ_DIR)/inst_ram.mif --coe $(OBJ_DIR)/inst_ram.coe --words $(RAM_WORDS)

install: all
	cp $(OBJ_DIR)/inst_ram.mif $(MEM_DIR)/inst_ram.mif
	cp $(OBJ_DIR)/inst_ram.coe $(MEM_DIR)/inst_ram.coe

clean:
	rm -rf $(OBJ_DIR)

