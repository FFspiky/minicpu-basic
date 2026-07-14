    .section .text.entry, "ax"
    .globl _start
    .globl start

_start:
start:
    li.w    $sp, 0x1c100000
    bl      main
    bl      la32_program_exit

1:
    b       1b
    nop
