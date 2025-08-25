# PQR5ASM Test Program - 21_bpredict_test4.s
# To test Branch instructions and JAL instruction predictions and Branch prediction flushes (BP flush)
# and Branch unit flushes after branch resolution (BU flush)

.section .text
.org 0x00000000               # Base address of the .text section

INIT:
mvi x3, 0x0
mvi x4, 99    # 100 iterations 

START:
mvi x1, 0x2
mvi x2, 0x2        

CHECK:
blt x1, x2, SKIP2  # Should be predicted as "not taken" on first entry, no BP flush or BU flush, as it should be resolved correctly...
j SKIP1            # Should generate BP flush, should update GHR on first entry, but not update GHR on second entry 

ERR:
mvi x31, 0xEEE     # Should never get executed
j END

SKIP1:
addi x2, x2, 1
j CHECK            # BP flush and jump
j ERR              # Should never get executed
mvi x31, 0xEEE     # Should never get executed

SKIP2:
mvi x30, 0xFFF

LOOP:
addi x3, x3, 1
blt x3, x4, START  # Iterate... This should ve predicted as taken on first entry by Static BP...
j DONE

mvi x31, 0xEEE     # Should never get executed

DONE:
mvi x29, 0xFFF

END: 
#NOP
mvi x0, 0xEEE
j END