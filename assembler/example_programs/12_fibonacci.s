# PQR5ASM Test Program
# Fibonacci series for a range and store it in memory as array

.section .text
.org 0x00000000               # Base address of the .text section

START:
# Clear registers
mvi x5, 0             # Third number in the series
mvi x7, 0             # Sum

# Initialize registers
mvi x1, 0x00          # Set base address to store elements in array [= addi x1, x0, 0x0]
mvi x2, 6             # Set number of terms required in the series
mvi x3, 0             # Set first element in the series
mvi x4, 1             # Set second element in the series
mvi x6, 1             # Initializing loop index
sb x3, x1, 0          # Store first number in memory (first word location)
sb x4, x1, 1          # Store second number in memory (second word location)
mvi x1, 0x01          # Sets address for result [= addi x1, x1, 1]

LOOP: 
blt x2, x6, END       # Condition to control number of iterations x2<x6? ==> END
add x5, x3, x4        # Add terms in n and (n-1), store in register

add x7, x1, x6
sb x5, x7, 0          # Store result to Array in memory

mv x3, x4             # Move x4 to x3 [= addi x3, x4, 0]
mv x4, x5             # Move x5 to x4 [= addi x4, x5, 0]

addi x6, x6, 1        # Increment index by 1
j LOOP                # Iterate [= jal x0, LOOP]

END: 
#NOP
mvi x0, 0xEEE
j END                 # End of program [= jal x0, END]