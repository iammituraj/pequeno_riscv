# PQR5ASM Test Program
# Test program for HW multipliers and Dividers

.section .text
.org 0x00000000               # Base address of the .text section

START:
mvi x1, 0             # x1 = 0
mvi x2, 3             # x2 = 3
mvi x3, 5             # x3 = 5
mvi x4, 6             # x4 = 6
mvi x31, 12            # x31 = 12
mvi x6, -1             # x6 = -1 (0xFFFFFFFF), overwritten further down
sw x4, x0, 0           # MEM[0] = x4 = 6
sw x31, x0, 4           # MEM[4] = x31 = 12

beq x1, x0, SKIP        # x1 == 0, branch taken, next mul is skipped
mul x4, x2, x3          # NOT executed (branch above was taken)

SKIP:
mul x5, x4, x3          # x5 = x4 * x3 = 6 * 5 = 30
mul x6, x4, x0          # x6 = x4 * x0 = 6 * 0 = 0, immediately overwritten below
mul x6, x4, x3          # x6 = x4 * x3 = 6 * 5 = 30, overwrites x6
beq x5, x6, SKIP2       # x5 == x6 (30 == 30), branch taken, next mvi is skipped
mvi x30, -1             # NOT executed (branch above was taken), x30 stays don't-care

SKIP2:
div x7, x4, x0          # x7 = x4 / x0, divide by zero -> x7 = 0xFFFFFFFF (-1)
div x8, x4, x4          # x8 = x4 / x4 = 6 / 6 = 1
beq x8, x0, END         # x8 = 1, not equal to x0, branch NOT taken
rem x9, x4, x4          # x9 = x4 % x4 = 6 % 6 = 0
mulhsu x10, x7, x2      # x10 = upper 32 bits of signed(x7=-1) * unsigned(x2=3) = 0xFFFFFFFF
mul x11, x10, x7        # x11 = x10 * x7 = (-1) * (-1) = 1, x7 still 0xFFFFFFFF at this point
div x7, x7, x7          # x7 = x7 / x7 = (-1) / (-1) = 1, this overwrites x7
lw x12, x0, 0           # x12 = MEM[0] = 6
mul x13, x12, x2        # x13 = x12 * x2 = 6 * 3 = 18
lw x14, x0, 4           # x14 = MEM[4] = 12
nop                     # no operation
remu x15, x14, x2       # x15 = x14 % x2, unsigned = 12 % 3 = 0
lw x14, x0, 4           # x14 = MEM[4] = 12 again, value unchanged
rem x15, x12, x2        # x15 = x12 % x2, signed = 6 % 3 = 0, overwrites x15

li x16, 0x80000000     # x16 = -2147483648 (INT32_MIN, 0x80000000)
mvi x17, -1             # x17 = -1 (0xFFFFFFFF)
div x18, x16, x17       # x18 = INT32_MIN / -1, signed overflow case -> result = dividend = 0x80000000
rem x19, x16, x17       # x19 = INT32_MIN % -1, signed overflow case -> remainder = 0

END:
#NOP
mvi x0, 0xEEE          # write to x0 discarded (x0 hardwired to 0)
j END                 # End of program

# ---------------------------------------------------------------------------
# Expected final register state (golden reference), x20-x29 and x30 never
# written (mvi x30,-1 is skipped), so they retain power-on/reset don't-care
# values and should not be compared:
#   x0=0x00000000  x1=0x00000000  x2=0x00000003  x3=0x00000005
#   x4=0x00000006  x5=0x0000001E  x6=0x0000001E  x7=0x00000001
#   x8=0x00000001  x9=0x00000000  x10=0xFFFFFFFF x11=0x00000001
#   x12=0x00000006 x13=0x00000012 x14=0x0000000C x15=0x00000000
#   x16=0x80000000 x17=0xFFFFFFFF x18=0x80000000 x19=0x00000000
#   x31=0x0000000C
# Expected final memory: MEM[0]=0x00000006  MEM[4]=0x0000000C
# ---------------------------------------------------------------------------
