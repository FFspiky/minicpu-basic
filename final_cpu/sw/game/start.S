    .section .text.entry, "ax"
    .globl _start
    .globl start
    .globl __main

_start:
start:
__main:
    li.w    $sp, 0x1c100000
    bl      main

1:
    b       1b
    nop
