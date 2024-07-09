.ORIGIN 0x0         

START:
mvi x1, 0xAAA
li a0, 0x00000000  # Base address 
li t0, 'H'         
sb t0, 0(a0)       # Store 'H' at 0x0
li t1, 0           # t1 will hold the offset
add a4, a0, t1     # Calculate the absolute address from index
lb t3, 0(a4)
beqz t3, RESET_INDEX   # If t3 (current character) is zero, reset index
j SKIP
mvi x1, 0xDDD
SKIP:
mvi x2, 0xEEE
RESET_INDEX:
mvi x3, 0xEEE
lw t2, 0(a0)
sw t2, 4(a0)
mvi x0, 0xEEE  # End instruction