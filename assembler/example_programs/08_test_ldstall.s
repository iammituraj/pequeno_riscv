.ORIGIN 0x0           

# PQR5 CPU Test Program - 08_test_ldstall.s
# Tests pipeline interlock generating stall on Load instructions causing RAW hazard
# Pipeline interlock stall is reqd for data forwarding on Load RAW hazards...

START:
j S1
lw x7, 4(x0)
bne x7, x5, FIN  # Should generate stall, due to x7 being loaded from mem 
FIN:
lw x7, 8(x0)
beq x5, x7, END  # Should generate stall, due to x7 being loaded from mem
S1:
mvi x1, 0x004
mvi x3, 0x00F
mvi x5, 0x0FF
mvi x6, 0x008
mvi x7, 0x00A
mvi x9, 0x00C
sw x0, 0(x0)
lw x0, 0(x1)
add x2, x0, x1   # Should NOT generate stall
sw x3, 4(x0)
lw x8, 4(x0)
lw x2, 0(x0)
add x3, x2, x0   # Should generate stall, due to x2 being loaded from mem
lw x3, 4(x0)
add x4, x0, x3   # Should generate stall, due to x3 being loaded from mem
lw x6, 0(x0)
add x6, x1, x5   # Should NOT generate stall
lw x5, 0(x0)
addi x6, 0(x5)   # Should generate stall, due to x5 being loaded from mem
lw x9, 0(x0)
sw x9, 8(x0)     # Should generate stall, due to x9 being loaded from mem
lw x9, 0(x0)
sw x0, 12(x9)     # Should generate stall, due to x9 being loaded from mem
lw x9, 4(x0)
mvi x9, 0x00C
lw x7, 0(x0)
jalr x0, 4(x7)   # Should generate stall, due to x7 being loaded from mem

END: 
#NOP
mvi x0, 0xEEE
j END