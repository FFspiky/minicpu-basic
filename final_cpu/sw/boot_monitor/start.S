    .section .text.entry, "ax"
    .globl _start
_start:
    li.w $sp, 0x1c100000
    bl main
1:  b 1b
    nop
