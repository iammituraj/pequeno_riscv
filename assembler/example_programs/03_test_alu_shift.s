.ORIGIN 0x0           

# PQR5 CPU Test Program - 03_test_alu_shift.s
# To test all ALU shift instructions

START:
# Loading 32-bit immediate 0x3456789A to x1; special case where bit[11] = 1'b1
LUI x2, 0x34568     # x1 = 0x34568000                
ADDI x1, x2, 0x89A  # x1 = x2 + 0xFFFFF89A = 0x3456789A

# Loading 32-bit immediate 0x12345678 to x3
LUI x4, 0x12345     # x4 = 0x12345000                
ADDI x3, x4, 0x678  # x3 = x4 + 0x00000678 = 0x12345678

# Loading 32-bit immediate 0x82345678 to x31
LUI x31, 0x82345      # x31 = 0x82345000                
ADDI x31, x31, 0x678  # x31 = x31 + 0x00000678 = 0x82345678

# SLLX                # x1  = 0x3456789A
SLLI x5, x1, 0x10     # x5  = x1 << 16      = 0x789A0000
SLLI x6, x1, 0x1F     # x6  = x1 << 31      = 0x00000000
SLL  x7, x1, x2       # x7  = x1 << x2[4:0] = 0x3456789A
SLL  x16, x1, x3      # x16 = x1 << x3[4:0] = 0x9A000000

# SRXX                # x3  = 0x12345678, x31 = 0x82345678         
SRLI x8, x3, 0x10     # x8  = x3 >> 16   = 0x00001234  
SRAI x9, x3, 0x10     # x9  = x3 >>> 16  = 0x00001234
SRLI x10, x3, 0x1F    # x10 = x3 >> 31   = 0x00000000 
SRAI x11, x3, 0x1F    # x11 = x3 >>> 31  = 0x00000000
SRLI x12, x31, 0x10   # x12 = x31 >> 16  = 0x00008234  
SRAI x13, x31, 0x10   # x13 = x31 >>> 16 = 0xFFFF8234
SRLI x14, x31, 0x1F   # x14 = x31 >> 31  = 0x00000001 
SRAI x15, x31, 0x1F   # x15 = x31 >>> 31 = 0xFFFFFFFF

SRL  x17, x3, x2      # x17 = x3  >>  x2[4:0] = 0x12345678   
SRL  x18, x3, x3      # x18 = x3  >>  x3[4:0] = 0x00000012
SRA  x19, x3, x2      # x19 = x3  >>> x2[4:0] = 0x12345678
SRA  x20, x3, x3      # x20 = x3  >>> x3[4:0] = 0x00000012
SRL  x21, x31, x2     # x21 = x31 >>  x2[4:0] = 0x82345678 
SRL  x22, x31, x3     # x22 = x31 >>  x3[4:0] = 0x00000082
SRA  x23, x31, x2     # x23 = x31 >>> x2[4:0] = 0x82345678 
SRA  x24, x31, x3     # x24 = x31 >>> x3[4:0] = 0xFFFFFF82

END: 
#NOP
mvi x0, 0xEEE
j END