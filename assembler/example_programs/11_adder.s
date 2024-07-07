.ORIGIN 0x0         

# PQR5ASM Test Program
# Adder to add two registers and store sum in register

START:
mvi x1, 5             # x1 = 5 [= addi x1, x0, 5]
mvi x2, 6             # x2 = 6
add x3, x1, x2        # x3 = x1 + x2

END: 
#NOP
mvi x0, 0xEEE
j END                 # End of program [= jal x0, END]