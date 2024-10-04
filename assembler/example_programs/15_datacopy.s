# PQR5ASM Test Program
# To copy a data structure from one memory location to another

.section .data
.org 0x00000008           # Base address of the .data section

stud_details_src:          # Source structure: roll_number, score, and name
    .byte 1                   # roll_number = 1 (1 byte)
    .word 95                  # score = 95 (4 bytes)
    .string "John Doe"        # name = "John Doe" (null-terminated)

stud_details_dst:          # Destination structure
	.p2align 2
    .zero 32                  # Reserve space for destination (aligned with source)

.section .text
.org 0x00000004               # Base address of the .text section

# Main code to copy student_details from source to destination
start:
    la a0, stud_details_src   # Load address of the source structure
    la a1, stud_details_dst   # Load address of the destination structure

    # Copy roll_number (1 byte)
    lb t0, 0(a0)                 # Load byte for roll_number from source
    sb t0, 0(a1)                 # Store byte for roll_number to destination

    # Copy score (4 bytes)
    lw t0, 4(a0)                 # Load word for score from source
    sw t0, 4(a1)                 # Store word for score to destination

    # Copy name (string)
    addi a2, 8(a0)               # Set address for string source (8-byte offset)
    addi a3, 8(a1)               # Set address for string destination (8-byte offset)

copy_name_loop:
    lb t1, 0(a2)                 # Load byte from source string
    sb t1, 0(a3)                 # Store byte to destination string
    beq t1, zero, end            # If null terminator is reached, exit loop
    addi a2, a2, 1               # Increment source address
    addi a3, a3, 1               # Increment destination address
    j copy_name_loop             # Repeat the loop

end:
    mvi x0, 0xEEE                # END command