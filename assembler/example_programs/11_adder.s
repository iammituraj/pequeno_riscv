# PQR5ASM Test Program
# Adder to add two registers and store sum in register

.section .text
.org 0x00000000               # Base address of the .text section

START:
mvi x1, 5             # x1 = 5 [= addi x1, x0, 5]
mvi x2, 6             # x2 = 6
add x3, x1, x2        # x3 = x1 + x2

END: 
#NOP
mvi x0, 0xEEE
j END                 # End of program [= jal x0, END]