# PQR5 CPU Test Program - 09_test_rawhzd.s
# Tests to verify mitigation against RAW data hazards by data forwarding

.section .text
.org 0x00000000               # Base address of the .text section

mvi  x7, 0x000           # x7 = 0x0000_0000
mvi  x3, 0x000           
mvi  x0, 0x100
mv   x1, x0              # x1 = 0x0000_0000, x0 never causes hazard
mvi  x1, 0x100           # x1 = 0x0000_0100
mv   x2, x1              # EXU   -> EXU data fwd for x1, x2 = 0x0000_0100
addi x3, x1, 0x010       # MACCU -> EXU data fwd for x1, x3 = 0x0000_0110
sw   x1, 0(x0)           # WBU   -> EXU data fwd for x1, dmem[0] = 0x0000_0100
bnez x3, B1              # MACCU -> EXU data fwd for x3, branch hits
mvi  x1, 0x7FF           # Won't execute

B1:
add  x4, x3, x1          # WBU -> EXU data fwd for x1 if not flushed earlier, x4 = 0x0000_0210
sw   x4, 4(x0)           # EXU -> EXU data fwd for x4, dmem[1] = 0x0000_0210
li   x5, 0xDEADBEEF      # x5 = 0xDEAD_BEEF, pseudo instr to work by EXU -> EXU data fwd 
j B2
add  x6, x6, x6          # EXU -> EXU data fwd for x6, x6 = 0x0000_0088
j B3
B2:
jal  x6, -8              # x6 = PC+4 = 0x0000_0044

B3:
jal x7, 4                # x7 = PC+4 = 0x0000_0090  
beqz x7, END             # EXU   -> EXU data fwd for x7 if not flushed earlier, branch not hit 
add x31, x7, x0          # MACCU -> EXU data fwd for x7, x31 = x7 = 0x0000_004C 
mvi x8, 0x100
mvi x8, 0x200            # x8 = 0x0000_0200
mv  x9, x8               # EXU/MACCU hit for x8, EXU -> EXU data fwd for x8, x9 = 0x0000_0200
add x9, x8, x9           # EXU, MACCU/WBU hit for x9, x8, EXU -> EXU data fwd for x9, MACCU -> EXU data fwd for x8, x9 = 0x0000_0400
mv  x11, x8              # WBU -> EXU data fwd for x8, x11 = 0x0000_0200
add x12, x11, x11        # EXU -> EXU data fwd for x11, x12 = 0x0000_0400
mv  x13, x8              # x13 = 0x0000_0200 
add x12, x12, x8         # MACCU -> EXU data fwd for x12, x12 = 0x0000_0600
add x12, x12, x11        # EXU/WBU hit for x12, EXU -> EXU data fwd for x12, x12 = 0x0000_0800
mvi x16, 0x000
add x16, x8, x16
mvi x16, 0x400           # x16 = 0x0000_0400
add x15, x16, x16        # EXU/MACCU/WBU hit for x16, EXU -> EXU data fwd for x16, x15 = 0x0000_0800
bnez x16, END            # MACCU -> EXU data fwd for x16, branch hit
mvi x14, 0x7FF           # Won't execute

END: 
#NOP
mvi x0, 0xEEE
j END