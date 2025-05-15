# PQR5ASM Test Program
# Stresses Branch predictor with mixed branching patterns like in a real world application
# This test program is written by ChatGPT under my guidance :D

.section .text
.org 0x00000000               # Base address of the .text section

start:
    li   x2, 0x400         # sp = 0x400 (top of 1KB DRAM stack)

    li   x9, 1000          # total iterations
    addi x10, x0, 0        # iteration counter

    li   x11, 5            # event interval
    li   x12, 3            # service interval
    li   x13, 0            # event counter
    li   x14, 0            # service counter

main_loop:
    addi x10, x10, 1
    bge  x10, x9, done     # stop after x9 iterations

    # increment counters
    addi x13, x13, 1       # event counter++
    addi x14, x14, 1       # service counter++

    # check event interval
    bge  x13, x11, call_event_handler

    # check service interval
    bge  x14, x12, call_service_task

    # poll sensors
    jal  x1, poll_sensor_func
    jal  x0, main_loop

call_event_handler:
    jal  x1, handle_event_func
    addi x13, x0, 0        # reset event counter
    jal  x0, main_loop

call_service_task:
    jal  x1, service_task_func
    addi x14, x0, 0        # reset service counter
    jal  x0, main_loop

#===============================
# POLL SENSOR FUNCTION
poll_sensor_func:
    addi sp, sp, -4
    sw   x1, 0(sp)

    # simulate reading sensor
    addi x5, x5, 1

    # conditional check (simulate sensor threshold)
    blt  x5, x12, skip_sensor_action
    addi x6, x0, 1          # simulate sensor action
skip_sensor_action:

    lw   x1, 0(sp)
    addi sp, sp, 4
    jalr x0, 0(x1)

#===============================
# HANDLE EVENT FUNCTION
handle_event_func:
    addi sp, sp, -4
    sw   x1, 0(sp)

    # simulate event handling
    addi x7, x7, 1

    # nested function call (simulate deep event processing)
    jal  x1, deep_event_func

    lw   x1, 0(sp)
    addi sp, sp, 4
    jalr x0, 0(x1)

#===============================
# DEEP EVENT FUNCTION
deep_event_func:
    addi sp, sp, -4
    sw   x1, 0(sp)

    addi x8, x0, 1         # simulate deep event flag

    lw   x1, 0(sp)
    addi sp, sp, 4
    jalr x0, 0(x1)

#===============================
# SERVICE TASK FUNCTION
service_task_func:
    addi sp, sp, -4
    sw   x1, 0(sp)

    # simulate service routine
    addi x4, x4, 1

    lw   x1, 0(sp)
    addi sp, sp, 4
    jalr x0, 0(x1)

#===============================
done:
    mvi x0, 0xEEE
    j done
