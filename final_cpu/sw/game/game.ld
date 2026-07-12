OUTPUT_ARCH(loongarch)
ENTRY(_start)

SECTIONS
{
    . = 0x1c000000;

    .text :
    {
        *(.text.entry)
        *(.text*)
        *(.rodata*)
        *(.srodata*)
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        __bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } = 0
}

