.ORIGIN 0x0         

# PQR5ASM Test Program - 06_test_branch.s
# To test Branch instructions and looping
# if x1 = 0x111 & x2 is a no. in range [x3, x4), multiply x2 by 16 using a loop
# Expected result is x6 = x7 = 0x0000_0020 because x6 = 0x0000_0002

START:
mvi x1, 0x111  # Enable
mvi x2, 0x002  
mvi x3, 0x001
mvi x4, 0xFFF
mvi x5, 0x00F  # Loop index
mvi x6, 0x000  # Result register
mvi x15, 0xFFF
bne x1, x0, VALIDAT1 
mvi x31, 0xFFF

VALIDAT1:
bltu x2, x4, VALIDAT2
mvi x30, 0xFFF

VALIDAT2:
bgeu x2, x3, EXEC
mvi x29, 0xFFF

EXEC:
blt x5, x0, STOP
add x6, x6, x2
addi x5, x5, -1
j EXEC 

STOP:
beq x1, x0, END
bge x6, x15, NXT
mvi x28, 0xFFF

NXT:
j RES
mvi x27, 0xFFF

RES:
mv x7, x6  # Store x6 to x7 only if x6 >= -1

END: 
#NOP
mvi x0, 0xEEE
j END