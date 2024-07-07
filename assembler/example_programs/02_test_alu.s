.ORIGIN 0x0           

# PQR5 CPU Test Program - 02_test_alu.s
# To test all ALU (Integer Computation) instructions + LUI + AUIPC

START:
# Loading 32-bit immediate 0x3456789A to x1; special case where bit[11] = 1'b1
LUI x2, 0x34568     # x2 = 0x34568000                
ADDI x1, x2, 0x89A  # x1 = x2 + 0xFFFFF89A = 0x3456789A

# Loading 32-bit immediate 0x12345678 to x3
LUI x3, 0x12345     # x3 = 0x12345000                
ADDI x3, x3, 0x678  # x3 = x3 + 0x00000678 = 0x12345678

# ADD and SUB              
ADD x5, x1, x3      # x5 = x1 + x3 = 0x468ACF12
SUB x6, x1, x3      # x6 = x1 - x3 = 0x22222222

# XORI, ORI, ANDI     # x1  = 0x3456789A
XORI x7, x1, 0x8AA    # x7  = 0xCBA98030
XORI x8, x1, 0x7AA    # x8  = 0x34567F30
ORI  x9, x1, 0x8AA    # x9  = 0xFFFFF8BA
ORI  x10, x1, 0x7AA   # x10 = 0x34567FBA
ANDI x11, x1, 0x8AA   # x11 = 0x3456788A
ANDI x12, x1, 0x7AA   # x12 = 0x0000008A

# XOR, OR, AND        # x1  = 0x3456789A                      
					  # x3  = 0x12345678
XOR x13, x1, x3       # x13 = 0x26622EE2
OR  x14, x1, x3       # x14 = 0x36767EFA
AND x15, x1, x3       # x15 = 0x10145018

# Loading 32-bit immediate 0x82345678 to x31
LUI x31, 0x82345      # x31 = 0x82345000               
ADDI x31, x31, 0x678  # x31 = x31 + 0x00000678 = 0x82345678

# SLTX and SLTXU        # x3 = 0x12345678, x31 = 0x82345678
SLT  x16, x3, x31       # x16 = 0x0 cz x3 > x31 when signed comparison 
SLTU x17, x3, x31       # x17 = 0x1 cz x3 < x31 when unsigned comparison 
SLT  x18, x31, x3       # x18 = 0x1 cz x31 < x3 when signed comparison
SLTU x19, x31, x3       # x19 = 0x0 cz x31 > x3 when unsigned comparison
SLTI x20, x31, 0xFFF    # x20 = 0x1 cz x31 < 0xFFFFFFFF when signed comparison
SLTI x21, x31, 0x7FF    # x21 = 0x1 cz x31 < 0x000007FF when signed comparison
SLTI x22, x3, 0xFFF     # x22 = 0x0 cz x3 > 0xFFFFFFFF when signed comparison
SLTI x23, x3, 0x7FF     # x23 = 0x0 cz x3 > 0x000007FF when signed comparison
SLTIU x24, x31, 0xFFF   # x24 = 0x1 cz x31 < 0xFFFFFFFF when unsigned comparison
SLTIU x25, x31, 0x7FF   # x25 = 0x0 cz x31 > 0x000007FF when unsigned comparison
SLTIU x26, x3, 0xFFF    # x26 = 0x1 cz x3 < 0xFFFFFFFF when unsigned comparison
SLTIU x27, x3, 0x7FF    # x27 = 0x0 cz x3 > 0x000007FF when unsigned comparison

END: 
#NOP
mvi x0, 0xEEE
j END