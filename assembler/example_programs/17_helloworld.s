# PQR5ASM Test Program
# Sends the string "Hello World! from Pequeno :)" through the debug UART port
# UART I/F specs are configured during the Pequeno subsystem generation...
# This test program is written by ChatGPT under my guidance :D

.section .text
.org 0x00000000               # Base address of the .text section

START:
    # Base addresses in memory (DMEM)
    li a0, 0x00000000         # To store the string
    li a1, 0x00010000         # UART control register
    li a2, 0x00010004         # UART data register
    li a3, 0x00010008         # UART status register

    # Initialize and enable UART
    li t0, 0x1         
    sb t0, 0(a1)       # Write 0x1 to UART control register

    # Load string "Hello World! from Pequeno :)" to memory
    # Load characters into registers and store them in memory 
    li t0, 'H'
    li t1, 'e'
    li t2, 'l'
    li t3, 'l'
    li t4, 'o'
    li t5, ' '
    li t6, 'W'
    sb t0, 0(a0)       # Store 'H' at 0x0
    sb t1, 1(a0)       # Store 'e' at 0x1
    sb t2, 2(a0)       # Store 'l' at 0x2
    sb t3, 3(a0)       # Store 'l' at 0x3
    sb t4, 4(a0)       # Store 'o' at 0x4
    sb t5, 5(a0)       # Store ' ' at 0x5
    sb t6, 6(a0)       # Store 'W' at 0x6

    li t0, 'o'
    li t1, 'r'
    li t2, 'l'
    li t3, 'd'
    li t4, '!'
    li t5, ' '
    li t6, 'f'
    sb t0, 7(a0)       # Store 'o' at 0x7
    sb t1, 8(a0)       # Store 'r' at 0x8
    sb t2, 9(a0)       # Store 'l' at 0x9
    sb t3, 10(a0)      # Store 'd' at 0xA
    sb t4, 11(a0)      # Store '!' at 0xB
    sb t5, 12(a0)      # Store ' ' at 0xC
    sb t6, 13(a0)      # Store 'f' at 0xD

    li t0, 'r'
    li t1, 'o'
    li t2, 'm'
    li t3, ' '
    li t4, 'P'
    li t5, 'e'
    li t6, 'q'
    sb t0, 14(a0)      # Store 'r' at 0xE
    sb t1, 15(a0)      # Store 'o' at 0xF
    sb t2, 16(a0)      # Store 'm' at 0x10
    sb t3, 17(a0)      # Store ' ' at 0x11
    sb t4, 18(a0)      # Store 'P' at 0x12
    sb t5, 19(a0)      # Store 'e' at 0x13
    sb t6, 20(a0)      # Store 'q' at 0x14

    li t0, 'u'
    li t1, 'e'
    li t2, 'n'
    li t3, 'o'
    li t4, ' '
    li t5, ':'
    li t6, ')'
    sb t0, 21(a0)      # Store 'u' at 0x15
    sb t1, 22(a0)      # Store 'e' at 0x16
    sb t2, 23(a0)      # Store 'n' at 0x17
    sb t3, 24(a0)      # Store 'o' at 0x18
    sb t4, 25(a0)      # Store ' ' at 0x19
    sb t5, 26(a0)      # Store ':' at 0x1A
    sb t6, 27(a0)      # Store ')' at 0x1B

    # Add newline and carriage return characters
    li t0, 10          # Load newline character '\n' (ASCII 10) into t0
    li t1, 13          # Load carriage return character '\r' (ASCII 13) into t1
    sb t0, 28(a0)      # Store '\n' at 0x1C
    sb t1, 29(a0)      # Store '\r' at 0x1D

    # Add null terminator
    li t2, 0           # Load null terminator '\0' (ASCII 0) into t2
    sb t2, 30(a0)      # Store '\0' at 0x1E

    # Initialize index and loop counter
    li t1, 0           # t1 will hold the index for accessing the string

READ_LOOP:
    # Calculate address of current character
    add a4, a0, t1     # Calculate address of current character
    lb t3, 0(a4)       # Load character from memory

    # Check if end of string (null terminator)
    beqz t3, RESET_INDEX   # If t3 (current character) is zero, reset index
    
    # Wait until UART is ready
UART_READY_LOOP:
    lbu t4, 0(a3)             # Load value of UART ready from UART status register
    beqz t4, UART_READY_LOOP  # Loop until UART is ready
    
    # UART is ready, write character to UART data register
    sb t3, 0(a2)       # Write character to UART data register
    
    # Increment index
    addi t1, t1, 1     # Increment index  
    
    j READ_LOOP        # Jump back to read next character

RESET_INDEX:
    # Reset index to start over
    li t1, 0           # Reset index to 0

    li t5, 0x002DC6C0  # Counter value for 1 second delay if core clock = 10 MHz

    # Delay loop before streaming the string again...
DELAY_LOOP_INNER:
    addi t5, t5, -1            # Decrement delay counter
    bnez t5, DELAY_LOOP_INNER  # Loop until delay counter is zero
    
    j READ_LOOP       # Jump back to read next character
