# PQR5ASM Test Program
# Stresses Branch predictor with FSM biased to fwd branching
# This test program is written by ChatGPT under my guidance :D

.section .text
.org 0x00000000               # Base address of the .text section

start:
    li   x2, 0x400         # Initialize sp = 0x400 (top of 1KB DRAM)
    li   x9, 1000          # Max iterations
    addi x10, x0, 0        # Iteration counter

    addi x11, x0, 0        # start bit counter (%5)
    addi x12, x0, 0        # data bit counter
    addi x20, x0, 0        # error trigger counter (%7)

IDLE:
    addi x10, x10, 1
    bge  x10, x9, done     # if x10 >= 1000 → done

    addi x11, x11, 1
    li   x13, 5
    bge  x11, x13, call_start

    addi x20, x20, 1
    li   x21, 7
    bge  x20, x21, call_error

    jal  x0, IDLE          # loop back

call_start:
    addi x11, x0, 0
    jal  x1, START_FUNC
    jal  x0, IDLE

call_error:
    addi x20, x0, 0
    jal  x1, ERROR_FUNC
    jal  x0, IDLE

# START function
START_FUNC:
    addi sp, sp, -4
    sw   x1, 0(sp)
    jal  x1, VALIDATE_FUNC
    lw   x1, 0(sp)
    addi sp, sp, 4
    jalr x0, 0(x1)

# VALIDATE function
VALIDATE_FUNC:
    addi sp, sp, -4
    sw   x1, 0(sp)
    jal  x1, DATA_FUNC
    lw   x1, 0(sp)
    addi sp, sp, 4
    jalr x0, 0(x1)

# DATA function
DATA_FUNC:
    addi sp, sp, -4
    sw   x1, 0(sp)
data_loop:
    addi x12, x12, 1
    li   x14, 8
    blt  x12, x14, data_loop  # loop until x12 = 8
    addi x12, x0, 0           # reset counter

    jal  x1, STOP_FUNC
    lw   x1, 0(sp)
    addi sp, sp, 4
    jalr x0, 0(x1)

# STOP function
STOP_FUNC:
    addi sp, sp, -4
    sw   x1, 0(sp)
    jal  x1, CHECK_FUNC
    lw   x1, 0(sp)
    addi sp, sp, 4
    jalr x0, 0(x1)

# CHECK function
CHECK_FUNC:
    blt  x20, x21, RETRY_FUNC
    jalr x0, 0(x1)

RETRY_FUNC:
    jalr x0, 0(x1)

# ERROR function
ERROR_FUNC:
    jalr x0, 0(x1)

done:
    mvi x0, 0xEEE
    j done