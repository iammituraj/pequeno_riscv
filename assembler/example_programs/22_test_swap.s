# PQR5 CPU Test Program - 22_test_swap.s
# Test swapping of arrays read from memory
# Expected memdump:
# 0x0000_0100   : 0x 00 00 00 14
# 0x0000_0104   : 0x 00 00 00 0A
# 0x0000_0108   : 0x 00 00 00 37

.section .text
.org 0x00000000               # Base address of the .text section

# Program begins at address 0x00000000
# Swap contents of 0x100 and 0x104 (normal swap)
# Swap contents of 0x108 and 0x108 (swap aliasing)

START:
    # Initialize arr[0] = 10 at address 0x100
    li   x1, 0x100       # x1 = base address
    li   x2, 10
    sw   x2, 0(x1)       # store 10 to 0x100

    # Initialize arr[1] = 20 at address 0x104
    li   x2, 20
    sw   x2, 4(x1)       # store 20 to 0x104

    # Load arr[0] -> x3
    lw   x3, 0(x1)

    # Load arr[1] -> x4
    lw   x4, 4(x1)

    # Store arr[1] to arr[0]
    sw   x4, 0(x1)

    # Store arr[0] (saved in x3) to arr[1]
    sw   x3, 4(x1)

    # Initialize arr[0] = 55 at address 0x108
    li   x1, 0x108        # x1 = base address
    li   x2, 55
    sw   x2, 0(x1)        # store 55 to 0x100

    # Simulate alias: use same address for both arr[i] and arr[j]
    # Load arr[i]
    lw   x3, 0(x1)        # x3 = arr[0] = 55

    # Load arr[j] (same address)
    lw   x4, 0(x1)        # x4 = arr[0] = 55 again

    # Store arr[j] to arr[i]
    sw   x4, 0(x1)        # arr[0] = 55

    # Store arr[i] (x3) to arr[j] (same location)
    sw   x3, 0(x1)        # arr[0] = 55 again

END: 
NOP
NOP
NOP
NOP
mvi x0, 0xEEE
j END
