TOOLPREFIX ?= /opt/loongarch32r/bin/loongarch32r-linux-gnusf-
CC=$(TOOLPREFIX)gcc
AS=$(TOOLPREFIX)as
LD=$(TOOLPREFIX)ld
OBJCOPY=$(TOOLPREFIX)objcopy
PYTHON?=python3
CFLAGS=-march=loongarch32r -mabi=ilp32s -msoft-float -ffreestanding -fno-builtin -fno-pic -fno-pie -fno-stack-protector -Os -Wall -Wextra
OBJ=obj
OBJECTS=$(OBJ)/start.o $(OBJ)/monitor.o $(OBJ)/checksum.o $(OBJ)/la32img.o $(OBJ)/nand_store.o

.PHONY: all clean install test-host
all: $(OBJ)/images.stamp $(OBJ)/boot_monitor.elf
$(OBJ):
	mkdir -p $@
$(OBJ)/start.o: start.S | $(OBJ)
	$(AS) -mabi=ilp32 $< -o $@
$(OBJ)/%.o: %.c | $(OBJ)
	$(CC) $(CFLAGS) -c $< -o $@
$(OBJ)/boot_monitor.elf: boot.ld $(OBJECTS)
	$(LD) -T boot.ld -nostdlib $(OBJECTS) -o $@
$(OBJ)/boot_monitor.bin: $(OBJ)/boot_monitor.elf
	$(OBJCOPY) -O binary $< $@
$(OBJ)/images.stamp: $(OBJ)/boot_monitor.bin
	$(PYTHON) ../game/bin_to_mif.py $< --mif $(OBJ)/boot_monitor.mif --coe $(OBJ)/boot_monitor.coe --words 262144
	touch $@
clean:
	rm -rf $(OBJ)
install: all
	cp $(OBJ)/boot_monitor.mif ../../mem/exp23/inst_ram.mif
	cp $(OBJ)/boot_monitor.coe ../../mem/exp23/inst_ram.coe
test-host:
	gcc -std=c99 -Wall -Wextra -fno-builtin checksum.c test_checksum.c -o /tmp/la32_checksum_test
	/tmp/la32_checksum_test
