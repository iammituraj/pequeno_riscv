# PQR5 CPU Test Program - 22_test_recursive.s
# Purpose: Compute power(n) = 2^n recursively, store result at 0x00000000

.section .text
.org 0x00000000

START:
   mvi x2, 0x800003F0        # x2 = sp (stack pointer)
   mvi x10, 8                # x10 = n (input), choose n = 8 ==> 2^8 = 256 is the result
   jal x1, power             # call power(n)

   # After return, result is in x10
   mvi x11, 0x00000000       # store result at address 0x00000000
   sw  x10, 0(x11)

END:
   mvi x0, 0xEEE             # End of Simulation
   j END

# -----------------------------
# Recursive power(n)
# Returns 2^n in x10
# Stack used to save x1 and x10
# -----------------------------
power:
   addi x11, x10, -1         # x11 = n - 1
   addi x12, x0, 1           # x12 = 1
   blt  x10, x12, base_case  # if n < 1, return 1

   # Save x1 (return addr) and x10 (n)
   addi x2, x2, -8
   sw   x1, 4(x2)
   sw   x10, 0(x2)

   mv   x10, x11             # x10 = n - 1
   jal  x1, power            # recursive call

   # x10 now holds 2^(n-1)
   mv   x13, x10             # copy x10 to x13
   add  x10, x10, x13        # x10 = x10 + x13 → x10 = 2 * 2^(n-1)

   # Restore from stack
   lw   x1, 4(x2)
   addi x2, x2, 8
   jalr x0, 0(x1)            # return

base_case:
   addi x10, x0, 1           # return 1 for power(0)
   jalr x0, 0(x1)