bits 64
default rel

extern malloc
extern free
extern rand
extern printf
extern clock
extern exit
extern calc_distance_asm

section .data
    fmt_header      db 10, "==================================================", 10, \
                       " Running Benchmark for Vector Size N = 2^%d (%llu elements)", 10, \
                       "==================================================", 10, 0
    fmt_mem_err     db "Memory allocation failed for N = 2^%d.", 10, 0
    fmt_c_head      db 10, "First 10 elements of Vector Z (C Reference Kernel):", 10, 0
    fmt_asm_head    db 10, "First 10 elements of Vector Z (x86-64 NASM Kernel):", 10, 0
    fmt_float_elem  db "%.6f ", 0
    fmt_newline     db 10, 0
    fmt_match       db 10, "[SUCCESS] x86-64 Assembly output correctly matches C reference.", 10, 0
    fmt_mismatch    db 10, "[FAILURE] Mismatch detected between C and x86-64 outputs.", 10, 0
    fmt_timing      db "Average Execution Time over 30 runs:", 10, \
                       " - C Kernel   : %.6f seconds", 10, \
                       " - ASM Kernel : %.6f seconds", 10, 0

    rand_max_inv    dq 0x3ee4f8b588e368f1
    scale_factor    dq 100.0
    clocks_per_sec  dq 1000000.0
    diff_threshold  dd 0.001

    powers          dq 20, 24, 28
    num_powers      dq 3

section .bss
    n               resq 1
    bytes_needed    resq 1
    
    ptr_X1          resq 1
    ptr_X2          resq 1
    ptr_Y1          resq 1
    ptr_Y2          resq 1
    ptr_Z_c         resq 1
    ptr_Z_asm       resq 1

    time_c_total    resq 1
    time_asm_total  resq 1
    start_time      resq 1

section .text
global main

main:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov r12, 0

.test_loop:
    cmp r12, [num_powers]
    jge .benchmark_complete

    mov rcx, [powers + r12*8]
    mov rbx, 1
    shl rbx, cl
    mov [n], rbx

    shl rbx, 2
    mov [bytes_needed], rbx

    lea rcx, [fmt_header]
    mov rdx, [powers + r12*8]
    mov r8, [n]
    call printf

    mov rcx, [bytes_needed]
    call malloc
    mov [ptr_X1], rax

    mov rcx, [bytes_needed]
    call malloc
    mov [ptr_X2], rax

    mov rcx, [bytes_needed]
    call malloc
    mov [ptr_Y1], rax

    mov rcx, [bytes_needed]
    call malloc
    mov [ptr_Y2], rax

    mov rcx, [bytes_needed]
    call malloc
    mov [ptr_Z_c], rax

    mov rcx, [bytes_needed]
    call malloc
    mov [ptr_Z_asm], rax

    cmp qword [ptr_X1], 0
    je .alloc_error
    cmp qword [ptr_X2], 0
    je .alloc_error
    cmp qword [ptr_Y1], 0
    je .alloc_error
    cmp qword [ptr_Y2], 0
    je .alloc_error
    cmp qword [ptr_Z_c], 0
    je .alloc_error
    cmp qword [ptr_Z_asm], 0
    je .alloc_error

    xor r13, r13
.init_loop:
    cmp r13, [n]
    jge .init_done

    call generate_rand_float
    mov rbx, [ptr_X1]
    movss [rbx + r13*4], xmm0

    call generate_rand_float
    mov rbx, [ptr_X2]
    movss [rbx + r13*4], xmm0

    call generate_rand_float
    mov rbx, [ptr_Y1]
    movss [rbx + r13*4], xmm0

    call generate_rand_float
    mov rbx, [ptr_Y2]
    movss [rbx + r13*4], xmm0

    inc r13
    jmp .init_loop

.init_done:

    pxor xmm0, xmm0
    movsd [time_c_total], xmm0
    mov r14, 0

.c_benchmark_loop:
    cmp r14, 30
    jge .c_benchmark_done

    call clock
    mov [start_time], rax

    call calc_distance_c_kernel

    call clock
    sub rax, [start_time]

    cvtsi2sd xmm0, rax
    addsd xmm0, [time_c_total]
    movsd [time_c_total], xmm0

    inc r14
    jmp .c_benchmark_loop

.c_benchmark_done:

    pxor xmm0, xmm0
    movsd [time_asm_total], xmm0
    mov r14, 0

.asm_benchmark_loop:
    cmp r14, 30
    jge .asm_benchmark_done

    call clock
    mov [start_time], rax

    sub rsp, 48

    mov rcx, [n]
    mov rdx, [ptr_X1]
    mov r8,  [ptr_X2]
    mov r9,  [ptr_Y1]
    
    mov rax, [ptr_Y2]
    mov [rsp + 32], rax
    
    mov rax, [ptr_Z_asm]
    mov [rsp + 40], rax

    call calc_distance_asm

    add rsp, 48

    call clock
    sub rax, [start_time]

    cvtsi2sd xmm0, rax
    addsd xmm0, [time_asm_total]
    movsd [time_asm_total], xmm0

    inc r14
    jmp .asm_benchmark_loop

.asm_benchmark_done:

    lea rcx, [fmt_c_head]
    call printf
    mov r13, 0
.print_c_loop:
    cmp r13, 10
    jge .print_c_done
    mov rbx, [ptr_Z_c]
    cvtss2sd xmm0, [rbx + r13*4]
    movq rdx, xmm0
    lea rcx, [fmt_float_elem]
    call printf
    inc r13
    jmp .print_c_loop
.print_c_done:
    lea rcx, [fmt_newline]
    call printf

    lea rcx, [fmt_asm_head]
    call printf
    mov r13, 0
.print_asm_loop:
    cmp r13, 10
    jge .print_asm_done
    mov rbx, [ptr_Z_asm]
    cvtss2sd xmm0, [rbx + r13*4]
    movq rdx, xmm0
    lea rcx, [fmt_float_elem]
    call printf
    inc r13
    jmp .print_asm_loop
.print_asm_done:
    lea rcx, [fmt_newline]
    call printf

    call verify_correctness
    cmp rax, 1
    je .print_success
    lea rcx, [fmt_mismatch]
    call printf
    jmp .print_times

.print_success:
    lea rcx, [fmt_match]
    call printf

.print_times:
    lea rcx, [fmt_newline]
    call printf

    movsd xmm0, [time_c_total]
    mov rax, 30
    cvtsi2sd xmm1, rax
    divsd xmm0, xmm1
    divsd xmm0, [clocks_per_sec]
    movsd xmm5, xmm0

    movsd xmm0, [time_asm_total]
    divsd xmm0, xmm1
    divsd xmm0, [clocks_per_sec]
    movsd xmm6, xmm0

    lea rcx, [fmt_timing]
    movq rdx, xmm5
    movq r8, xmm6
    call printf

    mov rcx, [ptr_X1]
    call free
    mov rcx, [ptr_X2]
    call free
    mov rcx, [ptr_Y1]
    call free
    mov rcx, [ptr_Y2]
    call free
    mov rcx, [ptr_Z_c]
    call free
    mov rcx, [ptr_Z_asm]
    call free

    inc r12
    jmp .test_loop

.alloc_error:
    lea rcx, [fmt_mem_err]
    mov rdx, [powers + r12*8]
    call printf
    inc r12
    jmp .test_loop

.benchmark_complete:
    xor rax, rax
    add rsp, 32
    pop rbp
    ret

calc_distance_c_kernel:
    push rbp
    mov rbp, rsp

    mov r8, [ptr_X1]
    mov r9, [ptr_X2]
    mov r10, [ptr_Y1]
    mov r11, [ptr_Y2]
    mov rbx, [ptr_Z_c]
    mov rcx, [n]
    xor rax, rax

.c_loop:
    cmp rax, rcx
    jge .c_done

    movss xmm0, [r9 + rax*4]
    subss xmm0, [r8 + rax*4]
    mulss xmm0, xmm0

    movss xmm1, [r11 + rax*4]
    subss xmm1, [r10 + rax*4]
    mulss xmm1, xmm1

    addss xmm0, xmm1
    sqrtss xmm0, xmm0

    movss [rbx + rax*4], xmm0

    inc rax
    jmp .c_loop

.c_done:
    pop rbp
    ret

generate_rand_float:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    call rand
    cvtsi2sd xmm0, eax
    mulsd xmm0, [rand_max_inv]
    mulsd xmm0, [scale_factor]
    cvtsd2ss xmm0, xmm0

    add rsp, 32
    pop rbp
    ret

verify_correctness:
    push rbp
    mov rbp, rsp

    mov r8, [ptr_Z_c]
    mov r9, [ptr_Z_asm]
    mov rcx, [n]
    xor rax, rax

.check_loop:
    cmp rax, rcx
    jge .all_correct

    movss xmm0, [r8 + rax*4]
    subss xmm0, [r9 + rax*4]
    
    movss xmm1, [diff_threshold]
    pxor xmm2, xmm2
    subss xmm2, xmm1

    comiss xmm0, xmm1
    ja .mismatch
    comiss xmm0, xmm2
    jb .mismatch

    inc rax
    jmp .check_loop

.all_correct:
    mov rax, 1
    pop rbp
    ret

.mismatch:
    xor rax, rax
    pop rbp
    ret