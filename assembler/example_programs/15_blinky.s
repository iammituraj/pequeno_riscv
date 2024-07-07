.ORIGIN 0x0         

# PQR5ASM Test Program
# Implements software counter to invert a bit in x31

START:
li x1, 0x002DC6C0    # Load counter; assuming 10 MHz clock, so approx toggles x31 bit every 1s: 0x01C9C380 if 100 MHz, 0x002DC6C0  if 10 MHz
mvi x31, 0xFFFFFFFF  # Load all 1s

LOOP:
beqz x1, INVERT
addi x1, x1, -1
j LOOP

INVERT:
inv x31              # Invert
li x1, 0x002DC6C0    # Reload counter
j LOOP
