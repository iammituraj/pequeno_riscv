# PQR5 CPU Test Program - 07_test_loadstore.s
# Load-Store instructions test: tests byte/half-word/word transfers
# Expected memdump:
# 0x0000_0000   : 0x 21 78 21 78
# 0x0000_0004   : 0x 83 21 83 21
# 0x0000_0008   : 0x 12 34 56 78
# 0x0000_000C   : 0x 83 21 21 21
# 0x0000_0010   : 0x 87 65 83 21

.section .text
.org 0x00000000               # Base address of the .text section

START:
# Loading 32-bit immediate 0x12345678 to x1
LI x1, 0x12345678

# Loading 32-bit immediate 0x87658321 to x2
#LI x2, 0x87658321
LUI x2, %hi(0x87658321)
ADDI x2, x2, %lo(0x87658321)

sb x2, 0(x0)        
sb x1, 0(x0)        # Stores 0x78 to 0x00000000
sb x1, 1(x0)
sb x2, 1(x0)        # Stores 0x21 to 0x00000001
sb x2, 2(x0)
sb x1, 2(x0)        # Stores 0x78 to 0x00000002
sb x1, 3(x0)
sb x2, 3(x0)        # Stores 0x21 to 0x00000003

sw x1, 4(x0)        # Stores 0x12345678 to 0x00000004-7
sw x1, 8(x0)        # Stores 0x12345678 to 0x00000008-B
sh x2, 6(x0)        # Stores 0x8321 to 0x00000006-7
sh x2, 4(x0)        # Stores 0x8321 to 0x00000004-5

sb x2, 12(x0)       # Stores 0x21 to 0x0000000C
lb x3, 12(x0)       # Loads byte at 0x0000000C to x3 and sign-extend = 0x000000021
lbu x4, 12(x0)      # Loads byte at 0x0000000C to x4 and zero-extend = 0x000000021
sb x2, 13(x0)       # Stores 0x21 to 0x0000000D
lb x5, 13(x0)       # Loads byte at 0x0000000D to x5 and sign-extend = 0x000000021
lbu x6, 13(x0)      # Loads byte at 0x0000000D to x6 and zero-extend = 0x000000021
sh x2, 14(x0)       # Stores 0x8321 at 0x0000000E-F 
lh x7, 14(x0)       # Loads hword at 0x0000000E-F to x7 and sign-extend = 0xFFFF8321 
lhu x8, 14(x0)      # Loads hword at 0x0000000E-F to x8 and zero-extend = 0x00008321  
sw x2, 16(x0)       # Stores 0x87654321 at 0x000000010-13
lw x9, 16(x0)       # Loads word at 0x000000010-13 to x9 = 0x87658321
lw x10, 16(x0)      # Loads word at 0x000000010-13 to x10 = 0x87658321
lh x10, 18(x0)      # Loads hword at 0x000000012-13 to x10 and sign-extend = 0xFFFF8765

END: 
#NOP
mvi x0, 0xEEE
j END