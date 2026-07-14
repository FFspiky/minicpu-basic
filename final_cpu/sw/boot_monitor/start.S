    .section .text.entry, "ax"
    .globl _start
_start:
    li.w $sp, 0x1c100000

    # BRAM contents survive a warm reset.  Re-establish the C language BSS
    # invariant on every monitor entry without touching application or stack.
    la.local $r12, __bss_start
    la.local $r13, __bss_end
1:
    beq $r12, $r13, 2f
    st.w $r0, $r12, 0
    addi.w $r12, $r12, 4
    b 1b
2:
    bl main
3:  b 3b
    nop
