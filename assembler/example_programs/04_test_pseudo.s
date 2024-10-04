# PQR5 CPU Test Program - 04_test_psuedo.s
# To test all pseudo instructions
# Please refer to PQR5 ASM Instruction Manual for list of all supported pseudo instructions

.section .text
.org 0x00000000               # Base address of the .text section

START:
MVI x8, 0x008   # x8 = 0x00000008
JR x8
MVI x1, 0x002   # x1 = 0x00000002
MV  x2, x1      # x2 = x1
NOT x3, x2      # x3 = !x2 = 0xFFFFFFFD
MV  x8, x3      # x8 = x3
INV x3          # x3 = !x3 = 0x00000002
SEQZ x4, x0     # x4 = (x0 == 0)? = 0x1
SNEZ x5, x0     # x4 = (x0 != 0)? = 0x0
SEQZ x6, x1     # x6 = (x1 == 0)? = 0x0 
SNEZ x7, x1     # x7 = (x1 != 0)? = 0x1
BEQZ x0, OVR1   # (x0 == 0)?
MV x10, x3      # This should not get executed
OVR1:
BNEZ x0, OVR2   # (x0 != 0)?
LI x11, 0xdeadbeef
LA x12, OVR2
J END1
OVR2:
MV x9, x1       # This should not get executed

END1: 
#NOP
MVI x31, 0x00F
JA x31, END2
MVI x31, 0x00E  # This should not get executed
END2:
mvi x0, 0xEEE