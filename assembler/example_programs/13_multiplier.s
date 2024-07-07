.ORIGIN 0x0         

# PQR5ASM Test Program
# Multiplier to multiply two registers and store product in register

START:
mvi x1, 4             # x1 = 4
mvi x2, 3             # x2 = 3
mvi x5, 0             # x5 stores x1*x2

mvi x3, 0             # x3 stores partial sums, initialize to 0
mv x4, x2             # x4 is used as index, initialize to x2

LOOP:
beq x4, x0, BRK_LOOP  # x4 == 0? 
add x3, x3, x1        # x3 = x3 + x1
addi x4, x4, -1       # Decrement index by 1
j LOOP

BRK_LOOP:
mv x5, x3

END: 
#NOP
mvi x0, 0xEEE
j END                 # End of program