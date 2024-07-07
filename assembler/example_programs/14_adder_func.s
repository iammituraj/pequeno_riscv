.ORIGIN 0x0         

# PQR5ASM Test Program
# Multiplier using function to multiply two numbers in registers and store product in register
# Using traditional ABI mneumonics

START:
mvi sp, 0x100      # Stack pointer initialization, x2 = 0x100
mvi t1, 16         # x6 = 16
mvi t2, 4          # x7 = 4
mv a0, t1          # Set argument-1 ahead of fn call
mv a1, t2          # Set argument-2 ahead of fn call
jal ra, MUL        # mul(): Store next PC to ra and jump to MUL subroutine
mv t3, a0          # a0 contains the returned val from MUL, store it to x28
sw t3, 0(x0)       # Store result to mem[0]

END: 
#NOP
mvi x0, 0xEEE
j END              # End of program    

# Function mul(a0, a1)
MUL:
addi sp, sp, -12   # Make space for 3 words in the stack
sw ra, 0(sp)       # Push return addr to stack @sp  \
sw t1, 4(sp)       # Push t1 to stack @sp+4          |--> Saving the context
sw t2, 8(sp)       # Push t2 to stack @sp+8         /

mvi t1, 0          # t1 stores partial sums, initialize to 0
mv t2, a1          # t2 is used as index, initialize to a1

LOOP:
beq t2, x0, BRK_LOOP  # t2 == 0? 
add t1, t1, a0        # t1 = t1 + a0
addi t2, t2, -1       # Decrement index by 1, t2--
j LOOP

BRK_LOOP:
mv a0, t1             # Store return val ie., result         
lw ra, 0(sp)          # Pop return addr from stack @sp  \
lw t1, 4(sp)          # Pop t1 from stack @sp+4          |--> Restoring the context
lw t2, 8(sp)          # Pop t2 from stack @sp+8         /
addi sp, sp, 12       # Free space for 3 words in the stack
jr ra                 # Return to the caller