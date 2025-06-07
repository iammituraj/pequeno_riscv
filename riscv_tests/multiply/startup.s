.section .text
.align 2
.global _start
.extern main

_start:
    # Set stack pointer
    la sp, _stack_top

    # Zero out .bss section
    la a0, _sbss
    la a1, _ebss
_init_bss:
    bgeu a0, a1, _init_reg   # If _sbss >= _ebss, stop
    sw zero, 0(a0)           # Clear the word at _sbss = 0
    addi a0, a0, 4           # Move to the next word
    j _init_bss
_init_reg:
    # Clear all the CPU registers; not mandatory though...
    li  x1, 0
    li  x3, 0  # x2 avoided cz its the stack pointer...
    li  x4, 0
    li  x5, 0
    li  x6, 0
    li  x7, 0
    li  x8, 0
    li  x9, 0
    li  x10,0
    li  x11,0
    li  x12,0
    li  x13,0
    li  x14,0
    li  x15,0
    li  x16,0
    li  x17,0
    li  x18,0
    li  x19,0
    li  x20,0
    li  x21,0
    li  x22,0
    li  x23,0
    li  x24,0
    li  x25,0
    li  x26,0
    li  x27,0
    li  x28,0
    li  x29,0
    li  x30,0
    li  x31,0
_call_main:
    # Call main()
    call main
    
    # Debug purpose, Log 0xFFFFFFFF in x31 and add pseudo END instruction recogned by pqr5 subsystem sim env to finish simulation.
    li x31, 0xFFFFFFFF
    addi x0, x0, -274

    # Infinite loop after main()
    j .
