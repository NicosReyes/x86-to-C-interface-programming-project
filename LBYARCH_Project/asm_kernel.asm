bits 64
default rel

global calc_distance_asm

section .text

calc_distance_asm:
    push rbp
    mov rbp, rsp

    mov r10, [rbp + 48]
    mov r11, [rbp + 56]

    xor rax, rax

.distance_loop:
    cmp rax, rcx
    jge .loop_done

    movss xmm0, [r8 + rax*4]
    subss xmm0, [rdx + rax*4]
    mulss xmm0, xmm0

    movss xmm1, [r10 + rax*4]
    subss xmm1, [r9 + rax*4]
    mulss xmm1, xmm1

    addss xmm0, xmm1
    sqrtss xmm0, xmm0

    movss [r11 + rax*4], xmm0

    inc rax
    jmp .distance_loop

.loop_done:
    pop rbp
    ret