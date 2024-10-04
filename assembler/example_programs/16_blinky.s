# PQR5ASM Test Program
# Implements software counter to invert a bit in x31

.section .data
.org 0x00000004
timeout_val:
.word 0x002DC6C0  # Assuming 10 MHz clock, so approx toggles x31 bit every 1s: 0x01C9C380 if 100 MHz, 0x002DC6C0  if 10 MHz

.section .text
.org 0x00000000       # Base address of the .text section

START:
la x2, timeout_val    # Store timeout_val location
lw x1, 0(x2)          # Load counter
mvi x31, 0xFFFFFFFF   # Load all 1s

LOOP:
beqz x1, INVERT
addi x1, x1, -1
j LOOP

INVERT:
inv x31              # Invert
lw x1, 0(x2)         # Reload counter
j LOOP
