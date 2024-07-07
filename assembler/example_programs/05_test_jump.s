.ORIGIN 0x0           

# PQR5 CPU Test Program - 05_test_jump.s
# To test J/JALR instructions
# Expected output in Register File: x3 = 0x00000111, x7 = 0x00000111, x10 = 0x00000010, x31 = 0x00000111, others = XXX

START:
j B0
mvi x1, 0xFFF
mvi x2, 0xFFF
jalr x10, 16(x0)  # x10 = addr of next instr ie., 16
mvi x31, 0x111    # Must be executed
j END

B0:
mvi x3, 0x111     # Must be executed
j B1
mvi x4, 0xFFF

B1:
j B5
j END
mvi x5, 0xFFF

B2:
j B6
mvi x9, 0xFFF

B3:
mvi x7, 0xFFF
j END

B4:
j B2
mvi x8, 0xFFF

B5:
j B4
mvi x6, 0xFFF

B6:
mvi x7, 0x111      # Must be executed
jalr x10, 12(x0)   # x10 = PC+4 = 0x010, but will be overwritten after jump
j B7
mvi x11, 0xFFF
mvi x12, 0xFFF

B7:
mvi x13, 0xFFF

END: 
#NOP
mvi x0, 0xEEE
j END