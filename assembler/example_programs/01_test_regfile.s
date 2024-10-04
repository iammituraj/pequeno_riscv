# PQR5 CPU Test Program - 01_test_regfile.s
# Register test: write to x0-x31 and read back

.section .text
.org 0x00000000               # Base address of the .text section

START:
# Write to registers
mvi x0,  0x00000001
mvi x1,  0x00000002
mvi x2,  0x00000004
mvi x3,  0x00000008
mvi x4,  0x00000010
mvi x5,  0x00000020    # Signed extension should happen, should copy 0xFFFFF800
mvi x6,  0x00000040
mvi x7,  0x00000080
mvi x8,  0x00000100
mvi x9,  0x00000200
mvi x10, 0x00000400
mvi x11, 0x00000800    # Signed extension should happen, should copy 0xFFFFF800   
mvi x12, 0x00000001
mvi x13, 0x00000002
mvi x14, 0x00000004
mvi x15, 0x00000008
mvi x16, 0x00000010
mvi x17, 0x00000020
mvi x18, 0x00000040
mvi x19, 0x00000080
mvi x20, 0x00000100
mvi x21, 0x00000200
mvi x22, 0x00000400
mvi x23, 0x00000800    # Signed extension should happen, should copy 0xFFFFF800
mvi x24, 0x00000001
mvi x25, 0x00000002
mvi x26, 0x00000004
mvi x27, 0x00000008
mvi x28, 0x00000010
mvi x29, 0x00000020
mvi x30, 0x00000040
mvi x31, 0x00000080

# Read registers & add
add x0, x1, x2
add x1, x3, x4
add x2, x5, x6
add x3, x7, x8
add x4, x9, x10
add x5, x11, x12
add x6, x13, x14
add x7, x15, x16
add x8, x17, x18
add x9, x19, x20
add x10, x21, x22
add x11, x23, x24
add x12, x25, x26
add x13, x27, x28
add x14, x29, x30
add x15, x31, x0

END: 
#NOP
mvi x0, 0xEEE
j END