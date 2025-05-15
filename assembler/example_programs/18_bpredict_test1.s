# PQR5ASM Test Program
# Stresses Branch predictor with dynamic branching patterns, aliasing,...
# This test program is written by ChatGPT under my guidance :D

.section .text
.org 0x00000000               # Base address of the .text section

start:
    addi x1, x0, 0          # x1 = 0 (main counter)
    addi x2, x0, 1          # x2 = 1
    addi x3, x0, 5          # threshold A
    addi x4, x0, 10         # threshold B
    addi x5, x0, 15         # threshold C
    addi x6, x0, 20         # threshold D
    addi x7, x0, 25         # threshold reset
    addi x8, x0, 0          # x8 = inner loop counter
    li   x9, 1000           # x9 = 1000 iterations
    addi x10, x0, 0         # x10 = 0 (iteration counter)

main_loop:
    jal x28, init
    addi x10, x10, 1        # increment iteration count
    bge  x10, x9, done      # check iteration count

    beq  x1, x3, branch_a   
    beq  x1, x4, branch_b
    beq  x1, x5, branch_c
    beq  x1, x6, branch_d
    bge  x1, x7, reset

    jal  x0, update

branch_a:
    addi x1, x1, 3
    jal  x0, main_loop

branch_b:
    addi x8, x0, 0
inner_loop:
    blt  x8, x3, inner_body
    jal  x0, main_loop

inner_body:
    addi x8, x8, 1
    jal  x0, inner_loop

branch_c:
    addi x1, x1, 4
    jal  x0, main_loop

branch_d:
    addi x1, x1, -1
    jal  x0, main_loop

init:
    addi x27, x27, 1     # dummy work
    jalr x0, 0(x28)    # return to main_loop

reset:
    addi x1, x0, 0
    jal  x0, main_loop

update:
    addi x1, x1, 1
    jal  x0, main_loop

done:
    mvi x0, 0xEEE
    j done