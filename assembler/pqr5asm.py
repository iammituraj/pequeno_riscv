#################################################################################################################################
##   _______   _                      __     __             _    
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/                            ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/  
##           /_/                                    /___/                                              chipmunklogic.com
#################################################################################################################################
# Script           : pqr5asm RISC-V Assembler
# Developer        : Mitu Raj, chip@chipmunklogic.com
# Vendor           : Chipmunk Logic, https://chipmunklogic.com
#
# Description      : This script interprets, parses, and translates RISC-V RV32I assembly instructions to 
#                    32-bit binary instructions.
#                    -- Compliant with RISC-V User Level ISA v2.2.
#                    -- Supports RV32I:
#                       -- 37 base instructions (ref. pqr5asm Instruction Manual for full list)
#                       -- Custom/Pseudo instructions  (ref. pqr5asm Instruction Manual for full list)
#                    -- Doesn't support FENCE and CSR instructions.
#                    -- Input = assembly code file, Output = binary/hex code files (.txt/.bin)
#                    -- Supports ABI acronyms (ref. pqr5asm Instruction Manual for more details)
#                    -- Only one instruction per line.
#                    -- Supports .section .text for text (instructions) segment and .section .data for data/bss segment
#                       -- .section .text is mandatory.
#                       -- Base address of the section to be mentioned with linker directive .org <addr in hexa>
#                       -- .string, .ascii, .byte, .hword, .word types are supported for defining data symbols in memory
#                       -- BSS segment can be defined by explicitly defining variables with default value = 0
#                          or by defining .zero regions in the memory
#                    -- Base address of program (PC of first instruction) should be 4-byte aligned
#                       for eg: .org 0x00000004
#                       Binary file will be generated with this base address on the instr. memory to store instructions
#                       For relocatable binary code, the binary can be mapped to different base address from this
#                    -- Supports <space>, <comma>, and <linebreak> as delimiters for eg:
#                                                                              LUI x5 255 <linebreak>
#                                                                              LUI x5, 255 <linebreak>
#                    -- Use '#' for inline/newline comments, for eg: LUI x5 255  # This is a sample comment
#                    -- Supports 32-bit signed/unsigned integer, 0x hex literals for immediate.
#                       For eg: 255, 0xFF, -255
#                    -- Immediates support parenthesis format: addi x1, x0, 2 <=> addi x1, 2(x0)
#                    -- Immediates gets truncated to 20-bit or 12-bit based on instruction.
#                    -- U-type instr format: <OPCODE> <rdt> <imm>        // imm = 20-bit signed offset
#                    -- J-type instr format: <OPCODE> <rdt> <imm>        // imm = 20-bit signed offset
#                    -- I-type instr format: <OPCODE> <rdt> <rs1> <imm>  // imm = 12-bit signed offset
#                                                                                5-bit for SLLI/SRLI/SRAI                                                                                
#                    -- B-type instr format: <OPCODE> <rs1> <rs2> <imm>  // imm = 12-bit signed offset
#                    -- S-type instr format: <OPCODE> <rs2> <rs1> <imm>  // imm = 12-bit signed offset
#                    -- R-type instr format: <OPCODE> <rdt> <rs1> <rs2>
#                    -- Valid registers for operands rdt/rs1/rs2: x0 to x31 (or ABI acronyms)
#                    -- Supports labels for jump/branch/load/store instructions for addressing
#                       -- Label is recommended to be of max. 16 ASCII characters
#                       -- Label should be stand-alone in new line for eg: fibonacc:
#                                                                          ADD x1, x1, x2
#                       -- Label is case-sensitive
#                    -- %hi() and %lo() can be used to extract MS 20-bit & LS 12-bit from a 32-bit symbol. 
#                       This together can return the 32-bit absolute address of a symbol.
#                       This can be used to generate memory access offset for load/store operations. Or load 32-bit constant
#                       to a register.
#                       For eg:
#                       # myvar is a 32-bit symbol in memory, which has to be loaded to a register a4
#                       LUI a5, %hi(myvar)
#                       LW  a4, %lo(myvar)(a5)
#
#                       # myvar2 is a 32-bit symbol in memory, which has to be stored with a 32-bit word from register a4
#                       LUI a5, %hi(myvar2)
#                       SW  a4, %lo(myvar2)(a5)
#                       
#                       # Loading 32-bit constant to register
#                       LUI x1, %hi(0xdeadbeef)       # Load the upper 20 bits into x1
#                       ADDI x1, x1, %lo(0xdeadbeef)  # Add the lower 12 bits to x1
#                    -- %pcrel_hi() and %pcrel_lo() is similar to %hi() and %lo(), but the value returned is not absolute address
#                       But the value returned is the address relative to current PC.
#                    -- Immediate value supports ascii characters for instructions like MVI, LI
#                       For eg: LI r0, 'A'  # Loads 0x41 to r0 register
#                       Supports '\n', '\r', '\t' escape sequences and all 7-bit ascii characters from 0x20 to 0x7E.
#                    -- Invoking the script from terminal:
#                       python pqr5asm.py -file=<source file path> -pcrel
#                       -file  = Assembly source file <filepath/filename>.s
#                       -pcrel = Applying this flag uses PC relative addressing for instructions like LA, JA
#                                This flag hence directs assembler and linker to generate relocatable binary code.
#                                If this flag is not used, absolute address is loaded by the instructions.
#                                The generate binary code may not be relocatable.
#                       Binary/Hex code files are generated in same path
#                       If no arguments provided, source file = "./sample.s"
#
# Last modified on : Nov-2024
# Compatiblility   : Python 3.9 tested
#
# User Manual      : https://github.com/iammituraj/pqr5asm/blob/main/pqr5asm_imanual.pdf
#
# Copyright        : Open-source license.
#################################################################################################################################

# Import Libraries
import numpy as np
import sys
import re

# --------------------------- Global Vars ----------------------------------- #
DEBUG = True
# List of registers supported
reglist = ['x0', 'x1', 'x2', 'x3', 'x4', 'x5', 'x6',
           'x7', 'x8', 'x9', 'x10', 'x11', 'x12',
           'x13', 'x14', 'x15', 'x16', 'x17', 'x18',
           'x19', 'x20', 'x21', 'x22', 'x23', 'x24',
           'x25', 'x26', 'x27', 'x28', 'x29', 'x30', 'x31',
           'X0', 'X1', 'X2', 'X3', 'X4', 'X5', 'X6',
           'X7', 'X8', 'X9', 'X10', 'X11', 'X12',
           'X13', 'X14', 'X15', 'X16', 'X17', 'X18',
           'X19', 'X20', 'X21', 'X22', 'X23', 'X24',
           'X25', 'X26', 'X27', 'X28', 'X29', 'X30', 'X31',
           'zero', 'ZERO', 'ra', 'RA', 'sp', 'SP', 'gp', 'GP', 'tp', 'TP',
           't0', 'T0', 't1', 'T1', 't2', 'T2', 's0', 'S0',
           's1', 'S1', 'a0', 'A0', 'a1', 'A1', 'a2', 'A2',
           'a3', 'A3', 'a4', 'A4', 'a5', 'A5', 'a6', 'A6',
           'a7', 'A7', 's2', 'S2', 's3', 'S3', 's4', 'S4',
           's5', 'S5', 's6', 'S6', 's7', 'S7', 's8', 'S8',
           's9', 'S9', 's10', 'S10', 's11', 'S11', 't3', 'T3',
           't4', 'T4', 't5', 'T5', 't6', 'T6']


# ----------------------- User-defined functions ---------------------------- #
# Function to print debug message
def printdbg(s):
    if DEBUG:
        print(s)


# Function to print welcome message
def print_welcome():
    print('')    
    print("/////////////////////////////////////////////////////")
    #print("=====================================================")
    print("                       ______                   ")
    print("     ____  ____ ______/ ____/___ __________ ___  TM")
    print("    / __ \\/ __ `/ ___/___ \\/ __ `/ ___/ __ `__ \\")
    print("   / /_/ / /_/ / /  ____/ / /_/ (__  ) / / / / /")
    print("  / .___/\\__, /_/  /_____/\\__,_/____/_/ /_/ /_/ ")
    print(" /_/       /_/                                  ") 
    print("")
    print("                  - RV32I Assembler for RISC-V CPUs")                    
    print("=====================================================") 
    print('')
    print(' OPEN-SOURCE licensed')
    print('')
    print(" Chipmunk Logic (TM) 2024")    
    print(" Visit us: chipmunklogic.com")
    print('')
    print("=====================================================")
    print("/////////////////////////////////////////////////////")
    print('')


# Function to print PASS
def print_pass(): 
    print('') 
    print("==========================================")    
    print("'########:::::'###:::::'######:::'######::")
    print("'##.... ##:::'## ##:::'##... ##:'##... ##:")
    print("'##:::: ##::'##:. ##:: ##:::..:: ##:::..::")
    print("'########::'##:::. ##:. ######::. ######::")
    print("'##.....::: #########::..... ##::..... ##:")
    print("'##:::::::: ##.... ##:'##::: ##:'##::: ##:")
    print("'##:::::::: ##:::: ##:. ######::. ######::")
    print("..:::::::::..:::::..:::......::::......:::")
    print("==========================================") 
    print('')                                                   
                                                                                                        

# Function to print FAIL
def print_fail(): 
    print('')
    print("=====================================") 
    print("'########::::'###::::'####:'##:::::::")
    print("'##.....::::'## ##:::. ##:: ##:::::::")
    print("'##::::::::'##:. ##::: ##:: ##:::::::")
    print("'######:::'##:::. ##:: ##:: ##:::::::")
    print("'##...:::: #########:: ##:: ##:::::::")
    print("'##::::::: ##.... ##:: ##:: ##:::::::")
    print("'##::::::: ##:::: ##:'####: ########:")
    print("..::::::::..:::::..::....::........::")  
    print("=====================================")                                                                            
    print('')   


# Function to dump .bin file
def write2bin(datsize, baddr, dbytearray, binfile, memtype):
    # Insert pre-amble 0xC0C0C0C0 (IMEM) / 0xD0D0D0D0 (DMEM)
    if memtype == 1:  # DMEM
        dbytearray.insert(0, int("11010000", 2))  #MSB
        dbytearray.insert(1, int("11010000", 2))
        dbytearray.insert(2, int("11010000", 2))
        dbytearray.insert(3, int("11010000", 2))
    else:  # IMEM
        dbytearray.insert(0, int("11000000", 2))  #MSB
        dbytearray.insert(1, int("11000000", 2))
        dbytearray.insert(2, int("11000000", 2))
        dbytearray.insert(3, int("11000000", 2))
    # Insert program size
    datsize_bytearray = datsize.to_bytes(4, 'big')
    dbytearray.insert(4, datsize_bytearray[0])  #MSB
    dbytearray.insert(5, datsize_bytearray[1])
    dbytearray.insert(6, datsize_bytearray[2])
    dbytearray.insert(7, datsize_bytearray[3])
    # Insert PC base address
    baddr_bytearray = baddr.to_bytes(4, 'big')
    dbytearray.insert(8, baddr_bytearray[0])  #MSB
    dbytearray.insert(9, baddr_bytearray[1])
    dbytearray.insert(10, baddr_bytearray[2])
    dbytearray.insert(11, baddr_bytearray[3])
    # Insert post-amble 0xE0E0E0E0
    dbytearray.append(int("11100000", 2))  #MSB
    dbytearray.append(int("11100000", 2))
    dbytearray.append(int("11100000", 2))
    dbytearray.append(int("11100000", 2))
    # Write to bin file
    binfile.write(dbytearray)


# Function to print code in ascii
def print_code(mycode_text):
    ln = 1
    for line in mycode_text:
        print('%+3s' % ln, ". ", line)
        ln = ln + 1


# Function to print code in hex
def print_code_hex(mycode_text_bin):
    ln = 1
    for line in mycode_text_bin:
        print('%+3s' % ln, ". ", "{:08x}".format(int(line, 2)))  # "0x{:08x}" to display 0x in front
        ln = ln + 1


# Function to print label table
def print_label_table(secname, labelcnt, label_list, label_addr_list):
    if labelcnt[0] == 0:
        return 1
    print('')
    print('+------------------+----------+-----------------')
    print('| Label            | Section  | Address Mapping')
    print('+------------------+----------+-----------------')
    for i in range(labelcnt[0]):
        print('| %+-16s' % label_list[i], '| %+-8s' %secname, "| 0x{:08x}".format(label_addr_list[i]))
    print('+------------------+----------+-----------------')
    print('')


# Function to validate label names
def is_validname_label(label):
    # Check if label starts with a number
    if label and label[0].isdigit():
        return False

    # Check if label contains only allowed characters (alphabets, digits, underscores)
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', label):
        return False
    return True


# Function to validate assembly source file
def validate_assembly(file_handler):
    file_handler.seek(0)  # Ensure file pointer is at the start

    text_section_found = False
    data_section_found = False
    org_found = False
    org_address = None
    data_section_position = None
    text_section_position = None

    lines = file_handler.readlines()
    i = 0
    # Iterate thru each line
    while i < len(lines):
        line = lines[i].strip()

        # Parse .text
        if line.startswith(".section .text"):
            if text_section_found:
                print("| ERROR: Multiple occurrences of .section .text found.")
                print_fail()
                exit(1)
            text_section_found = True
            text_section_position = i

            # Move to the next line(s) to find the .org directive
            i += 1
            while i < len(lines):
                next_line = lines[i].strip()

                # Remove comments from the line
                next_line = next_line.split('#')[0].strip()

                # Skip empty lines and comment-only lines
                if not next_line:
                    i += 1
                    continue

                # Check if the next valid line is an .org directive
                if next_line.startswith(".org"):
                    org_parts = next_line.split()
                    if len(org_parts) != 2 or not (org_parts[1].startswith("0x") or org_parts[1].startswith("0X")):
                        print("| ERROR: Invalid format for .org directive in .section .text, only Hex supported!")
                        print_fail()
                        exit(1)

                    addr_str = org_parts[1]

                    try:
                        # Support only hexadecimal (0x or 0X) values
                        org_address = int(addr_str, 16)

                        # Round address to the next multiple of 4 if unaligned word addr
                        org_address = ((org_address + 3) // 4) * 4 if org_address % 4 != 0 else org_address

                        # Print the address in the desired format
                        print(f"| INFO : Parsed .text .org address: 0x{org_address:08x}")

                    except ValueError:
                        print("| ERROR: Invalid .org address format in .section .text")
                        print_fail()
                        exit(1)

                    org_found = True
                    break
                else:
                    print("| ERROR: .org directive missing after .section .text")
                    print_fail()
                    exit(1)

            if not org_found:
                print("| ERROR: .org directive missing after .section .text")
                print_fail()
                exit(1)

        # Parse .data
        elif line.startswith(".section .data"):
            if data_section_found:
                print("| ERROR: Multiple occurrences of .section .data found!")
                print_fail()
                exit(1)
            data_section_found = True
            data_section_position = i

            # Move to the next line(s) to find the .org directive
            i += 1
            while i < len(lines):
                next_line = lines[i].strip()

                # Remove comments from the line
                next_line = next_line.split('#')[0].strip()

                # Skip empty lines and comment-only lines
                if not next_line:
                    i += 1
                    continue

                # Check if the next valid line is an .org directive
                if next_line.startswith(".org"):
                    org_parts = next_line.split()
                    if len(org_parts) != 2 or not (org_parts[1].startswith("0x") or org_parts[1].startswith("0X")):
                        print("| ERROR: Invalid format for .org directive in .section .data, , only Hex supported!")
                        print_fail()
                        exit(1)

                    addr_str = org_parts[1]

                    try:
                        # Support only hexadecimal (0x or 0X) values
                        org_address = int(addr_str, 16)

                        # Round address to the next multiple of 4 if unaligned word addr
                        if org_address % 4 != 0:
                            print("| WARNG: .data .org address should be 4-byte aligned.. remapping the base address...")
                        org_address = ((org_address + 3) // 4) * 4 if org_address % 4 != 0 else org_address
                        data_baseaddr[0] = org_address

                        # Print the address in the desired format
                        print(f"| INFO : Parsed .data .org address: 0x{org_address:08x}")

                    except ValueError:
                        print("| ERROR: Invalid .org address format in .section .data")
                        print_fail()
                        exit(1)

                    org_found = True
                    break
                else:
                    print("| ERROR: .org directive missing after .section .data")
                    print_fail()
                    exit(1)

            if not org_found:
                print("| ERROR: .org directive missing after .section .data")
                print_fail()
                exit(1)

        i += 1

    # Check if .data section is defined before .text section
    if data_section_found and text_section_found and data_section_position > text_section_position:
        print("| ERROR: .section .data must be defined before .section .text")
        print_fail()
        exit(1)
    # Check if .text section exists at all!
    if not text_section_found:
        print("| ERROR: Missing .section .text")
        print_fail()
        exit(1)

    print("\n| INFO : Assembly code file validation successful!!\n")
    return org_address


# Function to parse ascii char arguments and convert to hex
def char2hex(char):
    if char == ' ':
        return '0x20'
    elif char == '!':
        return '0x21'
    elif char == '"':
        return '0x22'
    elif char == '#':
        return '0x23'
    elif char == '$':
        return '0x24'
    elif char == '%':
        return '0x25'
    elif char == '&':
        return '0x26'
    elif char == "'":
        return '0x27'
    elif char == '(':
        return '0x28'
    elif char == ')':
        return '0x29'
    elif char == '*':
        return '0x2A'
    elif char == '+':
        return '0x2B'
    elif char == ',':
        return '0x2C'
    elif char == '-':
        return '0x2D'
    elif char == '.':
        return '0x2E'
    elif char == '/':
        return '0x2F'
    elif char == '0':
        return '0x30'
    elif char == '1':
        return '0x31'
    elif char == '2':
        return '0x32'
    elif char == '3':
        return '0x33'
    elif char == '4':
        return '0x34'
    elif char == '5':
        return '0x35'
    elif char == '6':
        return '0x36'
    elif char == '7':
        return '0x37'
    elif char == '8':
        return '0x38'
    elif char == '9':
        return '0x39'
    elif char == ':':
        return '0x3A'
    elif char == ';':
        return '0x3B'
    elif char == '<':
        return '0x3C'
    elif char == '=':
        return '0x3D'
    elif char == '>':
        return '0x3E'
    elif char == '?':
        return '0x3F'
    elif char == '@':
        return '0x40'
    elif char == 'A':
        return '0x41'
    elif char == 'B':
        return '0x42'
    elif char == 'C':
        return '0x43'
    elif char == 'D':
        return '0x44'
    elif char == 'E':
        return '0x45'
    elif char == 'F':
        return '0x46'
    elif char == 'G':
        return '0x47'
    elif char == 'H':
        return '0x48'
    elif char == 'I':
        return '0x49'
    elif char == 'J':
        return '0x4A'
    elif char == 'K':
        return '0x4B'
    elif char == 'L':
        return '0x4C'
    elif char == 'M':
        return '0x4D'
    elif char == 'N':
        return '0x4E'
    elif char == 'O':
        return '0x4F'
    elif char == 'P':
        return '0x50'
    elif char == 'Q':
        return '0x51'
    elif char == 'R':
        return '0x52'
    elif char == 'S':
        return '0x53'
    elif char == 'T':
        return '0x54'
    elif char == 'U':
        return '0x55'
    elif char == 'V':
        return '0x56'
    elif char == 'W':
        return '0x57'
    elif char == 'X':
        return '0x58'
    elif char == 'Y':
        return '0x59'
    elif char == 'Z':
        return '0x5A'
    elif char == '[':
        return '0x5B'
    elif char == '\\':
        return '0x5C'
    elif char == ']':
        return '0x5D'
    elif char == '^':
        return '0x5E'
    elif char == '_':
        return '0x5F'
    elif char == '`':
        return '0x60'
    elif char == 'a':
        return '0x61'
    elif char == 'b':
        return '0x62'
    elif char == 'c':
        return '0x63'
    elif char == 'd':
        return '0x64'
    elif char == 'e':
        return '0x65'
    elif char == 'f':
        return '0x66'
    elif char == 'g':
        return '0x67'
    elif char == 'h':
        return '0x68'
    elif char == 'i':
        return '0x69'
    elif char == 'j':
        return '0x6A'
    elif char == 'k':
        return '0x6B'
    elif char == 'l':
        return '0x6C'
    elif char == 'm':
        return '0x6D'
    elif char == 'n':
        return '0x6E'
    elif char == 'o':
        return '0x6F'
    elif char == 'p':
        return '0x70'
    elif char == 'q':
        return '0x71'
    elif char == 'r':
        return '0x72'
    elif char == 's':
        return '0x73'
    elif char == 't':
        return '0x74'
    elif char == 'u':
        return '0x75'
    elif char == 'v':
        return '0x76'
    elif char == 'w':
        return '0x77'
    elif char == 'x':
        return '0x78'
    elif char == 'y':
        return '0x79'
    elif char == 'z':
        return '0x7A'
    elif char == '{':
        return '0x7B'
    elif char == '|':
        return '0x7C'
    elif char == '}':
        return '0x7D'
    elif char == '~':
        return '0x7E'
    elif char == '\\n':
        return '0x0A'
    elif char == '\\r':
        return '0x0D'
    elif char == '\\t':
        return '0x09'
    elif char == '':
        return '0x00'
    else:
        return '#ERR'


# Function to parse char/string argument and convert to hex
def parseascii(arg, psts):
    if arg:
        s = arg[0]
        parts = s.split("'")
        if ((len(parts) == 3 and len(parts[1]) == 1) or
            (len(parts) == 3 and len(parts[1]) == 0) or
            ((len(parts) == 3 and len(parts[1]) == 2) and (parts[1] == '\\n' or parts[1] == '\\r' or parts[1] == '\\t'))):
            arghex = char2hex(parts[1])
            psts[0] = True
            if arghex != "#ERR":
                modified_expr = parts[0] + arghex + parts[2]
                arg[0] = modified_expr
            else:
                arg[0] = arg
        elif ((len(parts) == 3 and len(parts[1]) == 2) and (parts[1] == '\\\\')):  # For backslash character: \\
            psts[0] = True
            arg[0] = "0x5C"
        elif ((len(parts) == 4 and len(parts[1]) == 1) and (parts[1] == '\\')):  # For single quote character: \'
            psts[0] = True
            arg[0] = "0x27"


# Function to generate hex instructions from binary instructions
def gen_instr_hex(instr_bin, instr_hex):
    for line in instr_bin:
        instr_hex.append("{:08x}".format(int(line, 2)))  # 32-bit hex from binary string


# Function to return address of label
def addr_of_label(labelname, labelid):
    for i in range(labelcnt[0]):
        if labelname == label_list[i]:
            labelid[0] = i
            return label_addr_list[i]
    for i in range(dlabelcnt[0]):
        if labelname == dlabel_list[i]:
            labelid[0] = i
            return dlabel_addr_list[i]
    return 0


# Function to check if a register operand is valid or not
def is_invalid_reg(reg):
    if reg not in reglist:
        return 1
    else:
        return 0


# Function to check if a label is valid or not
def is_valid_label(lbl, isjbinstr=False):
    if lbl in label_list:
        is_text_label[0] = True
    else:
        is_text_label[0] = False
    if lbl in dlabel_list:
        is_data_label[0] = True
    else:
        is_data_label[0] = False
    if not isjbinstr:  # Not Jump/Branch instruction's label
        if (lbl in label_list) or (lbl in dlabel_list):
            return 1
        else:
            return 0
    else:
        if (lbl in label_list):
            return 1
        else:
            return 0


# Function to convert register (x0-x31) to its binary code
def reg2bin(reg):
    if reg == 'x0' or reg == 'X0' or reg == 'zero' or reg == 'ZERO':
        return '00000'
    elif reg == 'x1' or reg == 'X1' or reg == 'ra' or reg == 'RA':
        return '00001'
    elif reg == 'x2' or reg == 'X2' or reg == 'sp' or reg == 'SP':
        return '00010'
    elif reg == 'x3' or reg == 'X3' or reg == 'gp' or reg == 'GP':
        return '00011'
    elif reg == 'x4' or reg == 'X4' or reg == 'tp' or reg == 'TP':
        return '00100'
    elif reg == 'x5' or reg == 'X5' or reg == 't0' or reg == 'T0':
        return '00101'
    elif reg == 'x6' or reg == 'X6' or reg == 't1' or reg == 'T1':
        return '00110'
    elif reg == 'x7' or reg == 'X7' or reg == 't2' or reg == 'T2':
        return '00111'
    elif reg == 'x8' or reg == 'X8' or reg == 'fp' or reg == 'FP' or reg == 's0' or reg == 'S0':
        return '01000'
    elif reg == 'x9' or reg == 'X9' or reg == 's1' or reg == 'S1':
        return '01001'
    elif reg == 'x10' or reg == 'X10' or reg == 'a0' or reg == 'A0':
        return '01010'
    elif reg == 'x11' or reg == 'X11' or reg == 'a1' or reg == 'A1':
        return '01011'
    elif reg == 'x12' or reg == 'X12' or reg == 'a2' or reg == 'A2':
        return '01100'
    elif reg == 'x13' or reg == 'X13' or reg == 'a3' or reg == 'A3':
        return '01101'
    elif reg == 'x14' or reg == 'X14' or reg == 'a4' or reg == 'A4':
        return '01110'
    elif reg == 'x15' or reg == 'X15' or reg == 'a5' or reg == 'A5':
        return '01111'
    elif reg == 'x16' or reg == 'X16' or reg == 'a6' or reg == 'A6':
        return '10000'
    elif reg == 'x17' or reg == 'X17' or reg == 'a7' or reg == 'A7':
        return '10001'
    elif reg == 'x18' or reg == 'X18' or reg == 's2' or reg == 'S2':
        return '10010'
    elif reg == 'x19' or reg == 'X19' or reg == 's3' or reg == 'S3':
        return '10011'
    elif reg == 'x20' or reg == 'X20' or reg == 's4' or reg == 'S4':
        return '10100'
    elif reg == 'x21' or reg == 'X21' or reg == 's5' or reg == 'S5':
        return '10101'
    elif reg == 'x22' or reg == 'X22' or reg == 's6' or reg == 'S6':
        return '10110'
    elif reg == 'x23' or reg == 'X23' or reg == 's7' or reg == 'S7':
        return '10111'
    elif reg == 'x24' or reg == 'X24' or reg == 's8' or reg == 'S8':
        return '11000'
    elif reg == 'x25' or reg == 'X25' or reg == 's9' or reg == 'S9':
        return '11001'
    elif reg == 'x26' or reg == 'X26' or reg == 's10' or reg == 'S10':
        return '11010'
    elif reg == 'x27' or reg == 'X27' or reg == 's11' or reg == 'S11':
        return '11011'
    elif reg == 'x28' or reg == 'X28' or reg == 't3' or reg == 'T3':
        return '11100'
    elif reg == 'x29' or reg == 'X29' or reg == 't4' or reg == 'T4':
        return '11101'
    elif reg == 'x30' or reg == 'X30' or reg == 't5' or reg == 'T5':
        return '11110'
    else:
        return '11111'


# Function to define .data labels address mapping
def define_dlabel(code_text, dlabel_list, dlabel_addr_list, dlabelcnt):
    valid_directives = {".p2align", ".zero", ".string", ".ascii", ".byte", ".hword", ".word"}
    current_label = None
    is_start_of_label = False
    # Iterate thru each line
    for i, line in enumerate(code_text):
        # Remove inline comments and strip whitespace
        stripped_line = line.split('#', 1)[0].strip()

        # Skip lines that are comments or blank
        if not stripped_line:
            continue

        # Check if the line contains .section .text directive
        if stripped_line.startswith('.section'):
            if '.text' in stripped_line:
                return

        # Check if the line ends with a colon (potential label)
        if stripped_line.endswith(':'):
            label = stripped_line.rstrip(':').strip()

            # Ensure the label does not contain whitespace
            if ' ' in label:
                print(f"| ERROR: Line {i + 1}: The label '{label}' is invalid due to spaces!")
                print_fail()
                exit(1)

            # Check if the label already exists in the list
            if label in dlabel_list:
                print(f"| ERROR: Line {i + 1}: The label '{label}' has multiple definitions!")
                print_fail()
                exit(1)
            elif not is_validname_label(label):
                print(f"| ERROR: Line {i + 1}: The label '{label}' has naming violations!")
                print_fail()
                exit(1)

            # Valid label, hence update the current label
            current_label = label
            dlabel_list.append(label)
            dlabel_addr_list.append(dptr[0])
            dlabelcnt[0] = dlabelcnt[0] + 1
            is_start_of_label = True
            #print("\nalignment override disabled")#dbg
            #print(current_label)#dbg
            #print(f"DPTR[0] --> 0x{dptr[0]:08x}")#dbg
            continue  # Move to the next line for processing directives

        # If there is no current label, skip processing
        if current_label is None:
            continue

        # Ensure proper format between directive and argument
        if ' ' in stripped_line:
            directive, _, argument = stripped_line.partition(' ')
            if directive not in valid_directives:
                print(f"| ERROR: Line {i + 1}: The directive '{directive}' is invalid!")
                print_fail()
                exit(1)

            if not argument:
                print(f"| ERROR: Line {i + 1}: No argument provided for the directive '{directive}'!")
                print_fail()
                exit(1)
        else:
            # No space between directive and argument
            print(f"| ERROR: Line {i + 1}: No argument provided for the directive '{stripped_line}'!")
            print_fail()
            exit(1)

        # Validate the argument based on the directive
        # .p2align <n> ==> 2^n align
        if directive == ".p2align" and is_start_of_label:
            if not is_valid_align_argument(argument):
                print(f"| ERROR: Line {i + 1}: Invalid argument for .p2align directive!")
                print_fail()
                exit(1)
            align_bound_override = 2**int(argument, 0)
            #print("alignment override active = ", align_bound_override, "bytes")#dbg
            dptr[0] = addr_of_label(current_label, labelid)
            #print(f"DPTR[0] original = 0x{dptr[0]:08x}")#dbg
            zsize = (align_bound_override - (dptr[0] % align_bound_override)) % align_bound_override
            #print("alignment zero-padding =", zsize, "bytes")#dbg
            dptr[0] = zsize + dptr[0]
            #print(f"DPTR[0] modified = 0x{dptr[0]:08x}")#dbg
            # Update data label addresses
            dlabel_addr_list[labelid[0]] = dptr[0]
            # Update dmem binary data
            upd_dmem_data("zero", zsize, 0, "0x00")

        # .zero <no. of zero-padding bytes>
        elif directive == ".zero":
            if not is_valid_zero_argument(argument):
                print(f"| ERROR: Line {i + 1}: Invalid argument for .zero directive!")
                print_fail()
                exit(1)
            # {Zero padding, data} size calculation
            is_start_of_label = False
            align_bound = 1
            zsize = int(argument, 0)
            dsize = 0
            tsize = zsize + dsize
            #print("ZERO, zero-padding =", zsize, "bytes, dsize =", dsize, "bytes")#dbg
            # Update data pointer
            dptr[0] = dptr[0] + tsize
            #print(f"DPTR[0] --> 0x{dptr[0]:08x}")#dbg
            # Update dmem binary data
            upd_dmem_data("zero", zsize, dsize, "0x00")

        # .string "<auto null terminated string>"
        elif directive == ".string":
            if not is_valid_string_argument(argument):
                print(f"| ERROR: Line {i + 1}: Invalid argument for .string directive!")
                print_fail()
                exit(1)
            # {Zero padding, data} size calculation
            is_start_of_label = False
            align_bound = 1
            zsize = (align_bound - (dptr[0] % align_bound)) % align_bound
            dsize = calculate_string_size(argument)
            tsize = zsize + dsize
            #print("STRING, zero-padding =", zsize, "bytes, dsize =", dsize, "bytes")#dbg
            # Update data pointer
            dptr[0] = dptr[0] + tsize
            #print(f"DPTR[0] --> 0x{dptr[0]:08x}")#dbg
            write_str2dmem(argument)

        # .ascii '<char>'
        elif directive == ".ascii":
            if not is_valid_ascii_argument(argument):
                print(f"| ERROR: Line {i + 1}: Invalid argument for .ascii directive!")
                print_fail()
                exit(1)
            # {Zero padding, data} size calculation
            is_start_of_label = False
            align_bound = 1
            zsize = (align_bound - (dptr[0] % align_bound)) % align_bound
            dsize = 1
            tsize = zsize + dsize
            #print("ASCII CHAR, zero-padding =", zsize, "bytes, dsize =", dsize, "bytes")#dbg
            # Update data pointer
            dptr[0] = dptr[0] + tsize
            #print(f"DPTR[0] --> 0x{dptr[0]:08x}")#dbg
            arghexval = [argument]
            parseascii(arghexval, [0])
            # Update dmem binary data
            upd_dmem_data("byte", 0, 1, arghexval[0])

        # .byte <byte>
        elif directive == ".byte":
            if not is_valid_byte_argument(argument):
                print(f"| ERROR: Line {i + 1}: Invalid argument for .byte directive!")
                print_fail()
                exit(1)
            # {Zero padding, data} size calculation
            is_start_of_label = False
            align_bound = 1
            zsize = (align_bound - (dptr[0] % align_bound)) % align_bound
            dsize = 1
            tsize = zsize + dsize
            #print("BYTE, zero-padding =", zsize, "bytes, dsize =", dsize, "bytes")#dbg
            # Update data pointer
            dptr[0] = dptr[0] + tsize
            #print(f"DPTR[0] --> 0x{dptr[0]:08x}")#dbg
            # Update dmem binary data
            upd_dmem_data("byte", zsize, dsize, argument)

        # .hword <naturally aligned half word of two bytes>
        elif directive == ".hword":
            if not is_valid_hword_argument(argument):
                print(f"| ERROR: Line {i + 1}: Invalid argument for .hword directive!")
                print_fail()
                exit(1)
            # {Zero padding, data} size calculation
            if is_start_of_label:
                align_bound_override = 2
                #print("Re-alignment active = ", align_bound_override, "bytes")#dbg
                dptr[0] = addr_of_label(current_label, labelid)
                #print(f"DPTR[0] original = 0x{dptr[0]:08x}")#dbg
                dptr[0] = (align_bound_override - (dptr[0] % align_bound_override)) % align_bound_override + dptr[0]
                #print(f"DPTR[0] modified = 0x{dptr[0]:08x}")#dbg
                dlabel_addr_list[labelid[0]] = dptr[0]
            is_start_of_label = False
            align_bound = 2
            zsize = (align_bound - (dptr[0] % align_bound)) % align_bound
            dsize = 2
            tsize = zsize + dsize
            #print("HWORD, zero-padding =", zsize, "bytes, dsize =", dsize, "bytes")#dbg
            # Update data pointer
            dptr[0] = dptr[0] + tsize
            #print(f"DPTR[0] --> 0x{dptr[0]:08x}")#dbg
            # Update dmem binary data
            upd_dmem_data("hword", zsize, dsize, argument)

        # .word <naturally aligned word of 4 bytes>
        elif directive == ".word":
            if not is_valid_word_argument(argument):
                print(f"| ERROR: Line {i + 1}: Invalid argument for .word directive!")
                print_fail()
                exit(1)
            # {Zero padding, data} size calculation
            if is_start_of_label:
                align_bound_override = 4
                #print("Re-alignment active = ", align_bound_override, "bytes")#dbg
                dptr[0] = addr_of_label(current_label, labelid)
                #print(f"DPTR[0] original = 0x{dptr[0]:08x}")#dbg
                dptr[0] = (align_bound_override - (dptr[0] % align_bound_override)) % align_bound_override + dptr[0]
                #print(f"DPTR[0] modified = 0x{dptr[0]:08x}")#dbg
                dlabel_addr_list[labelid[0]] = dptr[0]
            is_start_of_label = False
            align_bound = 4
            zsize = (align_bound - (dptr[0] % align_bound)) % align_bound
            dsize = 4
            tsize = zsize + dsize
            #print("WORD, zero-padding =", zsize, "bytes, dsize =", dsize, "bytes")#dbg
            # Update data pointer
            dptr[0] = dptr[0] + tsize
            #print(f"DPTR[0] --> 0x{dptr[0]:08x}")#dbg
            # Update dmem binary data
            upd_dmem_data("word", zsize, dsize, argument)

# Function to verify the align argument is valid
def is_valid_align_argument(argument):
    try:
        # Check if the argument allows alignment up to 4k bytes
        if argument.isdigit() and int(argument) >= 0 and int(argument) <= 12 :
            return 1
        # Check if the argument is a valid hexadecimal number with '0x' or '0X' prefix
        if argument.lower().startswith('0x'):
            int(argument, 16)  # Try to convert it to an integer using base 16
            return 1
    except ValueError:
        # Catch the exception if the conversion fails
        return 0

    # If neither condition is met, return 0
    return 0


# Function to verify if the zero argument is valid
def is_valid_zero_argument(argument):
    try:
        # Check if the argument is a positive integer (greater than 0)
        if argument.isdigit() and int(argument) > 0:
            return 1
        # Check if the argument is a valid hexadecimal number with '0x' or '0X' prefix
        if argument.lower().startswith('0x'):
            int(argument, 16)  # Try to convert it to an integer using base 16
            return 1
    except ValueError:
        # Catch the exception if the conversion fails
        return 0

    # If neither condition is met, return 0
    return 0


# Function to verify if the string argument is valid
def is_valid_string_argument(argument):
    # Ensure the argument is at least two characters long (to cover the missing quotes scenario)
    if len(argument) < 2:
        return False

    # Ensure the argument is enclosed in double quotes
    if not (argument.startswith('"') and argument.endswith('"')):
        return False

    # Remove leading and trailing double quotes
    argument = argument[1:-1]

    # Validate the content of the argument
    i = 0
    length = len(argument)
    while i < length:
        char = argument[i]
        if char == '\\':
            # Check if there's a next character to form a valid escape sequence
            if i + 1 < length:
                next_char = argument[i + 1]
                # Valid escape sequences: \\ (backslash), \" (double quote), \t (tab), \r (carriage return), \n (newline)
                if next_char in ['\\', '"', 't', 'r', 'n']:
                    # Skip the next character as it's part of the escape sequence
                    i += 2
                else:
                    # Invalid escape sequence
                    return False
            else:
                # Trailing backslash is invalid
                return False
        else:
            # Any non-escape character is allowed
            i += 1

    return True


# Function to calculate string size
def calculate_string_size(argument):
    # Remove leading and trailing quotes
    argument = argument.strip().strip('"')

    size = 0
    i = 0
    while i < len(argument):
        if argument[i] == '\\':
            # Add 1 to size for escape sequences and skip the next character
            size += 1
            i += 2
        else:
            size += 1
            i += 1

    # Add 1 for the null terminator
    return size + 1


# Function to verify if ascii argument is valid
def is_valid_ascii_argument(argument):
    # Ensure the argument is at least two characters long (to cover the missing quotes scenario)
    if len(argument) < 2:
        return False

    # Check if the argument starts and ends with single quotes
    if not (argument.startswith("'") and argument.endswith("'")):
        return False

    # Remove only the outermost pair of single quotes if present
    if argument.startswith("'") and argument.endswith("'"):
        argument = argument[1:-1]

    # If the argument is empty after stripping quotes, it's valid
    if not argument:
        return True

    # Validate the content of the argument
    i = 0
    length = len(argument)
    while i < length:
        char = argument[i]

        if char == '\\':
            # Check if there's a next character to form a valid escape sequence
            if i + 1 < length:
                next_char = argument[i + 1]
                # Valid escape sequences: \\ (backslash), \t (tab), \r (carriage return), \n (newline)
                if next_char in ['\\', "'", 't', 'r', 'n']:
                    # Skip the next character as it's part of the escape sequence
                    i += 2
                else:
                    # Invalid escape sequence
                    return False
            else:
                # Trailing backslash is invalid
                return False
        else:
            # Any non-escape character is allowed
            i += 1

    # Verify size: should be 1 character or 2 characters if an escape sequence is present
    return (length == 1) or (length == 2 and argument.startswith('\\'))


# Function to verify if byte argument is valid
def is_valid_byte_argument(argument):
    # Check if the argument is empty
    if not argument:
        return False
    # Check if the argument is a valid hexadecimal or integer
    hex_pattern = r'^0[xX][0-9a-fA-F]{1,2}$'
    int_pattern = r'^[+-]?\d+$'
    # Matches hex/int pattern?
    return re.fullmatch(hex_pattern, argument) is not None or re.fullmatch(int_pattern, argument) is not None


# Function to verify if hword argument is valid
def is_valid_hword_argument(argument):
    # Check if the argument is empty
    if not argument:
        return False
    # Check if the argument is a valid hexadecimal or integer
    hex_pattern = r'^0[xX][0-9a-fA-F]{1,4}$'
    int_pattern = r'^[+-]?\d+$'
    # Matches hex/int pattern?
    return re.fullmatch(hex_pattern, argument) is not None or re.fullmatch(int_pattern, argument) is not None


# Function to verify if word argument is valid
def is_valid_word_argument(argument):
    # Check if the argument is empty
    if not argument:
        return False
    # Check if the argument is a valid hexadecimal or integer
    hex_pattern = r'^0[xX][0-9a-fA-F]{1,8}$'
    int_pattern = r'^[+-]?\d+$'
    # Matches hex/int pattern?
    return re.fullmatch(hex_pattern, argument) is not None or re.fullmatch(int_pattern, argument) is not None


# Function to define .text labels address mapping
def define_label(baseaddr, line, instrcnt, exp_instrcnt, label_list, label_addr_list):
    words = line.split()    
    # Check if blank line or comment
    try:
        if words[0][0] == '#':
            # Ignore comment and move on
            return 0
        elif line.startswith("."):
            # Ignore .text .data section elements
            return 0
    except:
        # Ignore blank line and move on
        return 0

    # Valid label?
    if len(words) == 1 and line[-1] == ':':  # Decode labels like 'mylabel:'
        label = line.split(':')[0]
        if label in label_list:
            print(f"| ERROR: The label '{label}' has multiple definitions!")
            print_fail()
            exit(1)
        elif label in dlabel_list:
            print(f"| ERROR: The label '{label}' has multiple definitions!")
            print_fail()
            exit(1)
        elif not is_validname_label(label):
            print(f"| ERROR: The label '{label}' has naming violations!")
            print_fail()
            exit(1)
        else:
            label_list.append(label)
        label_addr_list.append(baseaddr + int(exp_instrcnt[0]) * 4)
    elif len(words) > 1 and words[0][-1] == ':' and words[1][0] == '#':  # Decodes labels with comments
        label = line.split(':')[0]
        if label in label_list:
            print(f"| ERROR: The label '{label}' has multiple definitions!")
            print_fail()
            exit(1)
        elif label in dlabel_list:
            print(f"| ERROR: The label '{label}' has multiple definitions!")
            print_fail()
            exit(1)
        elif not is_validname_label(label):
            print(f"| ERROR: The label '{label}' has naming violations!")
            print_fail()
            exit(1)
        else:
            label_list.append(label)
        label_addr_list.append(baseaddr + int(exp_instrcnt[0]) * 4)
    else:
        # It is an instruction
        instrcnt[0] = instrcnt[0] + 1
        if words[0] == 'LI' or words[0] == 'li' or words[0] == 'LA' or words[0] == 'la' or words[0] == 'CALL' or words[0] == 'call':
            offset = 2  # Because LI = expands to two instructions, PC increments by 8
        elif words[0] == 'JA' or words[0] == 'ja':
            offset = 3  # Because JA = expands to three instructions, PC increments by 12
        else:
            offset = 1        
        exp_instrcnt[0] = exp_instrcnt[0] + offset


# Function to convert int to 32-bit binary
def int2bin(num):
    intval = num
    if num < 0:
        intval = 0xffffffff + 1 + num  # 2's complement taken if -ve number
    binval = '{:032b}'.format(int(intval))  # Signed 32-bit binary
    return binval


# Function to convert an immediate/offset to 32 binary and return status
def imm2bin(immval, linenum, errsts, jbflag, laflag, jaflag, callflag):
    try:
        # Integer literal
        if int(immval) < 0:
            immval = 0xffffffff + 1 + int(immval)  # 2's complement taken if -ve number
        immval_bin = '{:032b}'.format(int(immval))  # Signed 32-bit binary
        return immval_bin
    except:
        try:
            # Hexadecimal literal
            if immval[0:2] == '0x' or immval[0:2] == '0X':
                if int(immval, base=16) < 0:
                    immval = 0xffffffff + 1 + int(immval, base=16)  # 2's complement taken if -ve number
                    immval_bin = '{:032b}'.format(int(immval))  # 2's complement 32-bit binary
                else:
                    immval_bin = '{:032b}'.format(int(immval, base=16))  # Signed 32-bit binary
                return immval_bin
            # Label --> translation --> pc relative addr for j/b-type instructions
            elif jbflag == 1 and is_valid_label(immval.rstrip(':'), True):
                addr_of_label_int = addr_of_label(immval, labelid)
                pc_reltv_addr_int = addr_of_label_int - pc[0]  # PC relative addr
                if pc_reltv_addr_int < 0:
                    pc_reltv_addr_int = 0xffffffff + 1 + pc_reltv_addr_int  # PC relative addr 2's complement
                immval_bin = '{:032b}'.format(pc_reltv_addr_int, base=16)  # PC relative addr signed 32-bit
                return immval_bin
            # Label --> translation --> la instruction
            elif laflag == 1 and is_valid_label(immval.rstrip(':')):
                if (pcrel_flag is True) and is_text_label[0]:  # PC relative address for la instruction
                    addr_of_label_int = addr_of_label(immval, labelid)
                    pc_reltv_addr_int = addr_of_label_int - pc[0]  # PC relative addr
                    if pc_reltv_addr_int < 0:
                        pc_reltv_addr_int = 0xffffffff + 1 + pc_reltv_addr_int  # PC relative addr 2's complement
                    immval_bin = '{:032b}'.format(pc_reltv_addr_int, base=16)  # PC relative addr signed 32-bit
                    return immval_bin
                else:    # Absolute address for la instruction if referring to data symbol or pcrel_flag not set
                    addr_of_label_int = addr_of_label(immval, labelid)
                    abs_addr_int = addr_of_label_int
                    immval_bin = '{:032b}'.format(abs_addr_int, base=16)  # Absolute addr signed 32-bit
                    return immval_bin            
            # Label --> translation --> absolute address for ja instruction
            elif jaflag == 1 and (pcrel_flag is False) and is_valid_label(immval.rstrip(':'), True):
                addr_of_label_int = addr_of_label(immval, labelid)
                abs_addr_int = addr_of_label_int
                immval_bin = '{:032b}'.format(abs_addr_int, base=16)  # Absolute addr signed 32-bit
                return immval_bin
            # Label --> translation --> PC relative address for ja instruction
            elif jaflag == 1 and (pcrel_flag is True) and is_valid_label(immval.rstrip(':'), True):
                addr_of_label_int = addr_of_label(immval, labelid)
                pc_reltv_addr_int = addr_of_label_int - pc[0]  # PC relative addr
                if pc_reltv_addr_int < 0:
                    pc_reltv_addr_int = 0xffffffff + 1 + pc_reltv_addr_int  # PC relative addr 2's complement
                immval_bin = '{:032b}'.format(pc_reltv_addr_int, base=16)  # PC relative addr signed 32-bit
                return immval_bin
            # Label --> translation --> PC relative address for call instruction
            elif callflag == 1 and is_valid_label(immval.rstrip(':'), True):
                addr_of_label_int = addr_of_label(immval, labelid)
                pc_reltv_addr_int = addr_of_label_int - pc[0]  # PC relative addr
                if pc_reltv_addr_int < 0:
                    pc_reltv_addr_int = 0xffffffff + 1 + pc_reltv_addr_int  # PC relative addr 2's complement
                immval_bin = '{:032b}'.format(pc_reltv_addr_int, base=16)  # PC relative addr signed 32-bit
                return immval_bin
            else:
                print("| ERROR: Invalid immediate/offset value or label at line no: ", linenum)
                errsts[0] = 1
                return 0
        except:
            print("| ERROR: Invalid immediate/offset value or label at line no: ", linenum)
            errsts[0] = 1
            return 0


# Function to parse %hi() and %lo()
def parse_hi_lo(line, linenum):
    def calculate_hi(value):
        hi_value = (value + 0x800) >> 12  # Correct rounding for upper bits
        return f'0x{hi_value:05x}'  # Return as 20-bit hexadecimal

    def calculate_lo(value):
        lo_value = value & 0xfff  # Extract lower 12 bits
        return f'0x{lo_value:03x}'  # Return as 12-bit hexadecimal

    # Check if the line contains a comment and split the code and comment
    if '#' in line:
        code_part, comment_part = line.split('#', 1)
    else:
        code_part, comment_part = line, ''

    # Strip the code part of leading/trailing spaces
    code_part = code_part.strip()
    modified_line = ""

    i = 0
    while i < len(code_part):
        # %hi() and %lo()
        if code_part[i:i + 3] == "%hi" or code_part[i:i + 3] == "%lo":
            # Find the parentheses
            start = code_part.find('(', i)
            end = code_part.find(')', i)
            if start != -1 and end != -1 and code_part[i + 3:start].strip() == '':
                arg = code_part[start + 1:end].strip()
                try:
                    if is_valid_label(arg):
                        value = addr_of_label(arg, labelid)  # Use label address if valid
                    else:
                        value = int(arg, 0)  # Convert argument to integer
                    if (code_part[i:i + 3] == "%hi"):
                        modified_line += calculate_hi(value)
                    else:
                        modified_line += calculate_lo(value)    
                    i = end + 1  # Move past the processed %hi()
                except ValueError:
                    return line  # Return original line on failure
            else:
                return line  # Return original line if format is invalid
        # %pcrel_hi() and %pcrel_lo()        
        elif code_part[i:i + 9] == "%pcrel_hi" or code_part[i:i + 9] == "%pcrel_lo":            
            start = code_part.find('(', i)
            end = code_part.find(')', i)
            if start != -1 and end != -1 and code_part[i + 9:start].strip() == '':
                arg = code_part[start + 1:end].strip()
                try:
                    if is_valid_label(arg, True):  # Only valid for text labels!
                        value = addr_of_label(arg, labelid)  # Use label address if valid
                        if (code_part[i:i + 9] == "%pcrel_hi"):                                                                       
                            value = value - textline2pc[linenum] # PC relative addr
                        elif pcrel_hi_found[0]:
                            value = value - pcrel_hi_pc[0]   # %pcrel_hi PC relative addr 
                        else:
                            value = value - textline2pc[linenum] # PC relative addr 
                            print('| WARNG: No counter-part %pcrel_hi() found at line no:', lnum, '... This may parse unintended PC relative address')
                            warng_cnt[0] = warng_cnt[0] + 1                                           
                        if value < 0:
                            value = 0xffffffff + 1 + value   # 2's compliment         
                    else:
                        value = int(arg, 0)  # Convert argument to integer
                    if (code_part[i:i + 9] == "%pcrel_hi"):
                        pcrel_hi_found[0] = True
                        pcrel_hi_pc[0] = textline2pc[linenum]
                        modified_line += calculate_hi(value)
                    else:                                         
                        modified_line += calculate_lo(value)    
                    i = end + 1  # Move past the processed %lo()
                except ValueError:
                    return line  # Return original line on failure
            else:
                return line  # Return original line if format is invalid
        else:
            modified_line += code_part[i]
            i += 1

    # Reattach the comment part if it exists
    return modified_line + (' #' + comment_part if comment_part else '')


# Function to parse assembly code line to binary
def asm2bin(pc, line, linenum, error_flag, error_cnt, instr_bin):
    # Reset global flags
    is_text_label[0] = False
    is_data_label[0] = False

    instr_error_flag = 0
    # Parse %hi() %lo() if any, and replace by equivalent 20-bit and 12-bit hexa immediate
    #line = parse_hi_lo(line)
    # Split the instruction to word-by-word
    element = line.split()

    # Check if blank line or comment
    try:
        if element[0][0] == '#':
            # Ignore comment and move on
            return 0
        elif is_valid_label(element[0].rstrip(':')):
            # Ignore valid labels
            return 0
        elif line.startswith("."):
            # Ignore .text .data section elements
            return 0
    except:
        # Ignore blank line and move on
        return 0

    # Validate opcode existence
    try:
        opcode = element[0]
    except:
        print("| FATAL: Instruction at line no: ", linenum, " is missing opcode!\n")
        instr_error_flag = 1
        error_flag[0] = 1
        error_cnt[0] = error_cnt[0] + 1
        return 2

    # Instruction type flags
    r_type_flag = 0
    i_type_flag = 0
    s_type_flag = 0
    b_type_flag = 0
    u_type_flag = 0
    j_type_flag = 0

    # Pseudo instruction type flags
    ps_mv_type_flag = 0
    ps_mvi_type_flag = 0
    ps_nop_type_flag = 0
    ps_j_type_flag = 0
    is_j1_type = 0
    ps_not_type_flag = 0
    ps_inv_type_flag = 0
    ps_seqz_type_flag = 0
    ps_snez_type_flag = 0
    ps_beqz_type_flag = 0
    ps_bnez_type_flag = 0
    ps_li_type_flag = 0
    ps_la_type_flag = 0
    ps_jr_type_flag = 0
    ps_ja_type_flag = 0
    ps_call_type_flag = 0
    ps_ret_type_flag = 0

    # Fields - default values
    rs1 = 'x0'
    rs2 = 'x0'
    rdt = 'x0'
    imm = 0

    # Opcode arrays (used by multi-line pseudo instructions)
    opcode_binarr = []

    # opcode decoding
    if opcode == 'LUI' or opcode == 'lui':
        u_type_flag = 1
        opcode_bin = '0110111'
    elif opcode == 'AUIPC' or opcode == 'auipc':
        u_type_flag = 1
        opcode_bin = '0010111'
    elif opcode == 'JAL' or opcode == 'jal':
        j_type_flag = 1
        opcode_bin = '1101111'
    elif opcode == 'JALR' or opcode == 'jalr':
        i_type_flag = 1
        opcode_bin = '1100111'
    elif opcode == 'BEQ' or opcode == 'beq' or opcode == 'BNE' or opcode == 'bne' or \
            opcode == 'BLT' or opcode == 'blt' or opcode == 'BGE' or opcode == 'bge' or \
            opcode == 'BLTU' or opcode == 'bltu' or opcode == 'BGEU' or opcode == 'bgeu':
        b_type_flag = 1
        opcode_bin = '1100011'
    elif opcode == 'LB' or opcode == 'lb' or opcode == 'LH' or opcode == 'lh' or \
            opcode == 'LW' or opcode == 'lw' or opcode == 'LBU' or opcode == 'lbu' or \
            opcode == 'LHU' or opcode == 'lhu':
        i_type_flag = 1
        opcode_bin = '0000011'
    elif opcode == 'SB' or opcode == 'sb' or opcode == 'SH' or opcode == 'sh' or \
            opcode == 'SW' or opcode == 'sw':
        s_type_flag = 1
        opcode_bin = '0100011'
    elif opcode == 'ADDI' or opcode == 'addi' or opcode == 'SLTI' or opcode == 'slti' or \
            opcode == 'SLTIU' or opcode == 'sltiu' or opcode == 'XORI' or opcode == 'xori' or \
            opcode == 'ORI' or opcode == 'ori' or opcode == 'ANDI' or opcode == 'andi' or \
            opcode == 'SLLI' or opcode == 'slli' or opcode == 'SRLI' or opcode == 'srli' or \
            opcode == 'SRAI' or opcode == 'srai':
        i_type_flag = 1
        opcode_bin = '0010011'
    elif opcode == 'ADD' or opcode == 'add' or opcode == 'SUB' or opcode == 'sub' or \
            opcode == 'SLL' or opcode == 'sll' or opcode == 'SLT' or opcode == 'slt' or \
            opcode == 'SLTU' or opcode == 'sltu' or opcode == 'XOR' or opcode == 'xor' or \
            opcode == 'SRL' or opcode == 'srl' or opcode == 'SRA' or opcode == 'sra' or \
            opcode == 'OR' or opcode == 'or' or opcode == 'AND' or opcode == 'and':
        r_type_flag = 1
        opcode_bin = '0110011'
    elif opcode == 'MV' or opcode == 'mv':
        ps_mv_type_flag = 1
        opcode_bin = '0010011'   # Pseudo instruction derived from ADDI
    elif opcode == 'MVI' or opcode == 'mvi':
        ps_mvi_type_flag = 1
        opcode_bin = '0010011'  # Pseudo instruction derived from ADDI
    elif opcode == 'NOP' or opcode == 'nop':
        ps_nop_type_flag = 1
        opcode_bin = '0010011'   # Pseudo instruction derived from ADDI
    elif opcode == 'J' or opcode == 'j' or opcode == 'J1' or opcode == 'j1':
        ps_j_type_flag = 1
        if opcode == 'J1' or opcode == 'j1':
            is_j1_type = 1
        opcode_bin = '1101111'   # Pseudo instruction derived from JAL
    elif opcode == 'NOT' or opcode == 'not':
        ps_not_type_flag = 1
        opcode_bin = '0010011'  # Pseudo instruction derived from XORI
    elif opcode == 'INV' or opcode == 'inv':
        ps_inv_type_flag = 1
        opcode_bin = '0010011'  # Pseudo instruction derived from XORI
    elif opcode == 'SEQZ' or opcode == 'seqz':
        ps_seqz_type_flag = 1
        opcode_bin = '0010011'  # Pseudo instruction derived from SLTIU
    elif opcode == 'SNEZ' or opcode == 'snez':
        ps_snez_type_flag = 1
        opcode_bin = '0110011'  # Pseudo instruction derived from SLTU
    elif opcode == 'BEQZ' or opcode == 'beqz':
        ps_beqz_type_flag = 1
        opcode_bin = '1100011'  # Pseudo instruction derived from BEQ
    elif opcode == 'BNEZ' or opcode == 'bnez':
        ps_bnez_type_flag = 1
        opcode_bin = '1100011'  # Pseudo instruction derived from BNE
    elif opcode == 'LI' or opcode == 'li':
        ps_li_type_flag = 1
        opcode_binarr.append('0110111')  # LUI
        opcode_binarr.append('0010011')  # ADDI
    elif opcode == 'LA' or opcode == 'la':
        ps_la_type_flag = 1
        if pcrel_flag:
            opcode_binarr.append('0010111')  # AUIPC
            opcode_binarr.append('0010011')  # ADDI
        else:
            opcode_binarr.append('0110111')  # LUI
            opcode_binarr.append('0010011')  # ADDI
    elif opcode == 'JA' or opcode == 'ja':
        ps_ja_type_flag = 1
        if pcrel_flag:
            opcode_binarr.append('0010111')  # AUIPC
            opcode_binarr.append('0010011')  # ADDI
            opcode_binarr.append('1100111')  # JALR
        else:
            opcode_binarr.append('0110111')  # LUI
            opcode_binarr.append('0010011')  # ADDI
            opcode_binarr.append('1100111')  # JALR
    elif opcode == 'JR' or opcode == 'jr':
        ps_jr_type_flag = 1
        opcode_bin = '1100111'  # Pseudo instruction derived from JALR
    elif opcode == 'CALL' or opcode == 'call':
        ps_call_type_flag = 1
        opcode_binarr.append('0010111')  # AUIPC
        opcode_binarr.append('1100111')  # JALR
    elif opcode == 'RET' or opcode == 'ret':
        ps_ret_type_flag = 1
        opcode_bin = '1100111'  # Pseudo instruction derived from JALR
    else:
        print("| ERROR: Invalid/unsupported opcode at line no: ", linenum)
        instr_error_flag = 1
        error_flag[0] = 1

    # Validate r-type instruction
    if r_type_flag == 1:
        try:
            rdt = element[1]
            rs1 = element[2]
            rs2 = element[3]
            if is_invalid_reg(rdt) or is_invalid_reg(rs1) or is_invalid_reg(rs2):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 4 and element[4][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate i-type instruction
    if i_type_flag == 1:
        try:
            rdt = element[1]
            rs1 = element[2]
            imm = element[3]
            if is_invalid_reg(rdt) or is_invalid_reg(rs1):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 4 and element[4][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate s-type instruction
    if s_type_flag == 1:
        try:
            rs2 = element[1]
            rs1 = element[2]
            imm = element[3]
            if is_invalid_reg(rs2) or is_invalid_reg(rs1):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 4 and element[4][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate b-type instruction
    if b_type_flag == 1:
        try:
            rs1 = element[1]
            rs2 = element[2]
            imm = element[3]
            if is_invalid_reg(rs1) or is_invalid_reg(rs2):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 4 and element[4][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate u-type/j-type instruction
    if u_type_flag == 1 or j_type_flag == 1:
        try:
            rdt = element[1]
            imm = element[2]
            if is_invalid_reg(rdt):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 3 and element[3][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: MV
    if ps_mv_type_flag == 1:
        try:
            i_type_flag = 1  # Derived from i-type
            rdt = element[1]
            rs1 = element[2]
            imm = 0
            if is_invalid_reg(rdt) or is_invalid_reg(rs1):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 3 and element[3][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: MVI
    if ps_mvi_type_flag == 1:
        try:
            i_type_flag = 1  # Derived from i-type
            rdt = element[1]
            rs1 = 'x0'
            imm = element[2]
            if is_invalid_reg(rdt):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 3 and element[3][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: NOP
    if ps_nop_type_flag == 1:
        i_type_flag = 1  # Derived from i-type
        rdt = 'x0'
        rs1 = 'x0'
        imm = 0
        if len(element) > 1 and element[1][0] != '#':  # Integrity check; ignore if inline comment
            print("| ERROR: Invalid no. of operands at line no: ", linenum)
            instr_error_flag = 1
            error_flag[0] = 1

    # Validate pseudo instruction: J/J1
    if ps_j_type_flag == 1:
        try:
            j_type_flag = 1  # Derived from j-type
            if is_j1_type:
                rdt = 'x1'
            else:
                rdt = 'x0'
            imm = element[1]
            if len(element) > 2 and element[2][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: NOT
    if ps_not_type_flag == 1:
        try:
            i_type_flag = 1  # Derived from i-type
            rdt = element[1]
            rs1 = element[2]
            imm = -1
            if is_invalid_reg(rdt) or is_invalid_reg(rs1):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 3 and element[3][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: INV
    if ps_inv_type_flag == 1:
        try:
            i_type_flag = 1  # Derived from i-type
            rdt = element[1]
            rs1 = element[1]
            imm = -1
            if is_invalid_reg(rdt):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 2 and element[2][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: SEQZ
    if ps_seqz_type_flag == 1:
        try:
            i_type_flag = 1  # Derived from i-type
            rdt = element[1]
            rs1 = element[2]
            imm = 1
            if is_invalid_reg(rdt) or is_invalid_reg(rs1):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 3 and element[3][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: SNEZ
    if ps_snez_type_flag == 1:
        try:
            r_type_flag = 1  # Derived from r-type
            rdt = element[1]
            rs1 = 'x0'
            rs2 = element[2]
            if is_invalid_reg(rdt) or is_invalid_reg(rs2):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 3 and element[3][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: BEQZ
    if ps_beqz_type_flag == 1:
        try:
            b_type_flag = 1  # Derived from b-type
            rs1 = element[1]
            rs2 = 'x0'
            imm = element[2]
            if is_invalid_reg(rs1):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 3 and element[3][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: BNEZ
    if ps_bnez_type_flag == 1:
        try:
            b_type_flag = 1  # Derived from b-type
            rs1 = element[1]
            rs2 = 'x0'
            imm = element[2]
            if is_invalid_reg(rs1):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 3 and element[3][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: LI/LA/JA
    if ps_li_type_flag or ps_la_type_flag or ps_ja_type_flag:
        try:
            rs1 = element[1]  # For ADDI
            rdt = element[1]  # For LUI/AUIPC, ADDI
            imm = element[2]
            if is_invalid_reg(rdt):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 3 and element[3][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: JR
    if ps_jr_type_flag:
        try:
            i_type_flag = 1  # Derived from i-type
            rdt = 'x0'
            rs1 = element[1]
            imm = 0
            if is_invalid_reg(rs1):
                print("| ERROR: Invalid/unsupported register at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
            elif len(element) > 2 and element[2][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2
    
    # Validate pseudo instruction: CALL
    if ps_call_type_flag:
        try:
            rs1 = 'x1'  # For JALR
            rdt = 'x1'  # For AUIPC, JALR
            imm = element[1]
            if len(element) > 2 and element[2][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2
        
    # Validate pseudo instruction: RET
    if ps_ret_type_flag:
        try:
            i_type_flag = 1  # Derived from i-type
            rdt = 'x0'
            rs1 = 'x1'
            imm = 0
            if len(element) > 1 and element[1][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
            instr_error_flag = 1
            error_flag[0] = 1
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Convert all instr fields to binary codes
    rs1_bin = reg2bin(rs1)
    rs2_bin = reg2bin(rs2)
    rdt_bin = reg2bin(rdt)

    # Decode immediate/offset
    errsts = [0]
    if r_type_flag == 0:  # Ignore only if r-type instruction
        imm_bin = imm2bin(imm, linenum, errsts, (j_type_flag or b_type_flag), ps_la_type_flag, ps_ja_type_flag, ps_call_type_flag)

    # Check if immediate values flagged error on parsing
    if errsts[0] == 1:
        instr_error_flag = 1
        error_flag[0] = 1

    # Decode funct3, funct3, imm from opcode and then form the 32-bit binary instruction
    if instr_error_flag == 0 and (opcode == 'ADD' or opcode == 'add'):
        funct3 = '000'
        funct7 = '0000000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SUB' or opcode == 'sub'):
        funct3 = '000'
        funct7 = '0100000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SLL' or opcode == 'sll'):
        funct3 = '001'
        funct7 = '0000000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SLT' or opcode == 'slt'):
        funct3 = '010'
        funct7 = '0000000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SLTU' or opcode == 'sltu'):
        funct3 = '011'
        funct7 = '0000000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'XOR' or opcode == 'xor'):
        funct3 = '100'
        funct7 = '0000000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SRL' or opcode == 'srl'):
        funct3 = '101'
        funct7 = '0000000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SRA' or opcode == 'sra'):
        funct3 = '101'
        funct7 = '0100000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'OR' or opcode == 'or'):
        funct3 = '110'
        funct7 = '0000000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'AND' or opcode == 'and'):
        funct3 = '111'
        funct7 = '0000000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'JALR' or opcode == 'jalr'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'LB' or opcode == 'lb'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'LH' or opcode == 'lh'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '001'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'LW' or opcode == 'lw'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '010'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'LBU' or opcode == 'lbu'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '100'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'LHU' or opcode == 'lhu'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '101'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'ADDI' or opcode == 'addi'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SLTI' or opcode == 'slti'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '010'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SLTIU' or opcode == 'sltiu'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '011'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'XORI' or opcode == 'xori'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '100'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'ORI' or opcode == 'ori'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '110'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'ANDI' or opcode == 'andi'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '111'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SLLI' or opcode == 'slli'):
        shamnt = imm_bin[27:32]  # imm[4:0]
        funct3 = '001'
        funct7 = '0000000'
        instr_bin.append(funct7 + shamnt + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SRLI' or opcode == 'srli'):
        shamnt = imm_bin[27:32]  # imm[4:0]
        funct3 = '101'
        funct7 = '0000000'
        instr_bin.append(funct7 + shamnt + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SRAI' or opcode == 'srai'):
        shamnt = imm_bin[27:32]  # imm[4:0]
        funct3 = '101'
        funct7 = '0100000'
        instr_bin.append(funct7 + shamnt + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SB' or opcode == 'sb'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0[0:7] + rs2_bin + rs1_bin + funct3 + imm_bin_11_0[7:12] + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SH' or opcode == 'sh'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '001'
        instr_bin.append(imm_bin_11_0[0:7] + rs2_bin + rs1_bin + funct3 + imm_bin_11_0[7:12] + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'SW' or opcode == 'sw'):
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '010'
        instr_bin.append(imm_bin_11_0[0:7] + rs2_bin + rs1_bin + funct3 + imm_bin_11_0[7:12] + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'BEQ' or opcode == 'beq'):
        imm_bin_12_1 = imm_bin[19:31]  # imm[12:1]
        funct3 = '000'
        instr_bin.append(imm_bin_12_1[0] + imm_bin_12_1[2:8] + rs2_bin + rs1_bin + funct3 + imm_bin_12_1[8:12] +
                         imm_bin_12_1[1] + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'BNE' or opcode == 'bne'):
        imm_bin_12_1 = imm_bin[19:31]  # imm[12:1]
        funct3 = '001'
        instr_bin.append(imm_bin_12_1[0] + imm_bin_12_1[2:8] + rs2_bin + rs1_bin + funct3 + imm_bin_12_1[8:12] +
                         imm_bin_12_1[1] + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'BLT' or opcode == 'blt'):
        imm_bin_12_1 = imm_bin[19:31]  # imm[12:1]
        funct3 = '100'
        instr_bin.append(imm_bin_12_1[0] + imm_bin_12_1[2:8] + rs2_bin + rs1_bin + funct3 + imm_bin_12_1[8:12] +
                         imm_bin_12_1[1] + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'BGE' or opcode == 'bge'):
        imm_bin_12_1 = imm_bin[19:31]  # imm[12:1]
        funct3 = '101'
        instr_bin.append(imm_bin_12_1[0] + imm_bin_12_1[2:8] + rs2_bin + rs1_bin + funct3 + imm_bin_12_1[8:12] +
                         imm_bin_12_1[1] + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'BLTU' or opcode == 'bltu'):
        imm_bin_12_1 = imm_bin[19:31]  # imm[12:1]
        funct3 = '110'
        instr_bin.append(imm_bin_12_1[0] + imm_bin_12_1[2:8] + rs2_bin + rs1_bin + funct3 + imm_bin_12_1[8:12] +
                         imm_bin_12_1[1] + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'BGEU' or opcode == 'bgeu'):
        imm_bin_12_1 = imm_bin[19:31]  # imm[12:1]
        funct3 = '111'
        instr_bin.append(imm_bin_12_1[0] + imm_bin_12_1[2:8] + rs2_bin + rs1_bin + funct3 + imm_bin_12_1[8:12] +
                         imm_bin_12_1[1] + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'LUI' or opcode == 'lui'):
        imm_bin_31_12 = imm_bin[12:32]  # Observed to be imm[19:0] in all implementations, not imm[31:12]
        instr_bin.append(imm_bin_31_12 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'AUIPC' or opcode == 'auipc'):
        imm_bin_31_12 = imm_bin[12:32]  # Observed to be imm[19:0] in all implementations, not imm[31:12]
        instr_bin.append(imm_bin_31_12 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (opcode == 'JAL' or opcode == 'jal'):
        imm_bin_20_1 = imm_bin[11:31]  # imm[20:1]
        instr_bin.append(imm_bin_20_1[0] + imm_bin_20_1[10:20] + imm_bin_20_1[9] + imm_bin_20_1[1:9] +
                         rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (ps_mv_type_flag or ps_mvi_type_flag or ps_nop_type_flag):  # = ADDI
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and ps_j_type_flag:  # = JAL
        imm_bin_20_1 = imm_bin[11:31]  # imm[20:1]
        instr_bin.append(imm_bin_20_1[0] + imm_bin_20_1[10:20] + imm_bin_20_1[9] + imm_bin_20_1[1:9] +
                         rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and (ps_not_type_flag or ps_inv_type_flag):  # = XORI
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '100'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and ps_seqz_type_flag:  # = SLTIU
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '011'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and ps_snez_type_flag:  # = SLTU
        funct3 = '011'
        funct7 = '0000000'
        instr_bin.append(funct7 + rs2_bin + rs1_bin + funct3 + rdt_bin + opcode_bin)
    elif instr_error_flag == 0 and ps_beqz_type_flag:  # = BEQ
        imm_bin_12_1 = imm_bin[19:31]  # imm[12:1]
        funct3 = '000'
        instr_bin.append(imm_bin_12_1[0] + imm_bin_12_1[2:8] + rs2_bin + rs1_bin + funct3 + imm_bin_12_1[8:12] +
                         imm_bin_12_1[1] + opcode_bin)
    elif instr_error_flag == 0 and ps_bnez_type_flag:  # = BNE
        imm_bin_12_1 = imm_bin[19:31]  # imm[12:1]
        funct3 = '001'
        instr_bin.append(imm_bin_12_1[0] + imm_bin_12_1[2:8] + rs2_bin + rs1_bin + funct3 + imm_bin_12_1[8:12] +
                         imm_bin_12_1[1] + opcode_bin)
    elif instr_error_flag == 0 and ps_li_type_flag:  # = LUI + ADDI
        # LUI
        if imm_bin[20] == '0':
            imm_bin_31_12 = imm_bin[0:20]  # imm[31:12]
        else:
            intval = int(imm_bin[0:20], base=2) + 1
            imm_bin_lui = int2bin(intval)
            imm_bin_31_12 = imm_bin_lui[12:32]  # imm[31:12] + 1
        instr_bin.append(imm_bin_31_12 + rdt_bin + opcode_binarr[0])  # Write LUI instruction
        # ADDI
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_binarr[1])  # Write ADDI instruction
    elif instr_error_flag == 0 and ps_la_type_flag:  # = LUI/AUIPC + ADDI
        if (pcrel_flag is True) and is_text_label[0]:
            opcode0 = opcode_binarr[0]  # No need to modify opcode, AUIPC
        else:
            opcode0 = '0110111'  # Modify opcode to LUI if referring to data symbol or pcrel_flag not set or immediate address
        # LUI or AUIPC
        if imm_bin[20] == '0':
            imm_bin_31_12 = imm_bin[0:20]  # imm[31:12]
        else:
            intval = int(imm_bin[0:20], base=2) + 1  # Add 1 to MSB 20-bits if 11th bit is set, otherwise sign extension @ADDI will cause erratic load
            imm_bin_lui_or_auipc = int2bin(intval)
            imm_bin_31_12 = imm_bin_lui_or_auipc[12:32]  # imm[31:12] + 1
        instr_bin.append(imm_bin_31_12 + rdt_bin + opcode0)  # Write LUI/AUIPC instruction
        # ADDI
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_binarr[1])  # Write ADDI instruction                 
    elif instr_error_flag == 0 and ps_ja_type_flag:  # = LUI/AUIPC + ADDI + JALR
        if (pcrel_flag is True) and is_text_label[0]:
            opcode0 = opcode_binarr[0]  # No need to modify opcode, AUIPC
        else:
            opcode0 = '0110111'  # Modify opcode to LUI if referring to data symbol or pcrel_flag not set or immediate address
        # LUI or AUIPC
        if imm_bin[20] == '0':
            imm_bin_31_12 = imm_bin[0:20]  # imm[31:12]
        else:
            intval = int(imm_bin[0:20], base=2) + 1  # Add 1 to MSB 20-bits if 11th bit is set, otherwise sign extension @ADDI will cause erratic load
            imm_bin_lui_or_auipc = int2bin(intval)
            imm_bin_31_12 = imm_bin_lui_or_auipc[12:32]  # imm[31:12] + 1
        instr_bin.append(imm_bin_31_12 + rdt_bin + opcode0)  # Write AUIPC instruction
        # ADDI
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_binarr[1])  # Write ADDI instruction        
        # JALR x0, rs1, 0
        imm_bin_11_0 = '000000000000'  # imm[11:0] = 0
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + '00000' + opcode_binarr[2])
    elif instr_error_flag == 0 and (ps_call_type_flag):  # = AUIPC + JALR
        # AUIPC
        if imm_bin[20] == '0':
            imm_bin_31_12 = imm_bin[0:20]  # imm[31:12]
        else:
            intval = int(imm_bin[0:20], base=2) + 1  # Add 1 to MSB 20-bits if 11th bit is set, otherwise sign extension @JALR will cause erratic load
            imm_bin_auipc = int2bin(intval)
            imm_bin_31_12 = imm_bin_auipc[12:32]  # imm[31:12] + 1
        instr_bin.append(imm_bin_31_12 + rdt_bin + opcode_binarr[0])  # Write AUIPC instruction 
        # JALR x1, x1, 0
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_binarr[1])   
    elif instr_error_flag == 0 and (ps_jr_type_flag or ps_ret_type_flag):  # = JALR
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)    
    else:
        funct3 = 'XXX'  # Do nothing

    # Update pc
    if ps_li_type_flag or ps_la_type_flag or ps_call_type_flag:
        pc[0] = pc[0] + 8  # Because LI, LA, CALL = expand to two instructions
    elif ps_ja_type_flag:
        pc[0] = pc[0] + 12 # Because JA expands to three instructions
    else:
        pc[0] = pc[0] + 4

    # Check for any errors logged in the instruction
    if instr_error_flag == 0:
        print("| INFO : Instruction at line no: ", linenum, " successfully parsed...\n")
        return 0
    else:
        error_cnt[0] = error_cnt[0] + 1
        print("| ERROR: Instruction at line no: ", linenum, " failed to parse due to errors...\n")
        return 1


# Function to write a string to dmem binary data
def write_str2dmem (argstr):
    i = 0
    argstr = argstr.strip('"')
    length = len(argstr)
    while i < length:
        char = argstr[i]
        if char == '\\':
            # Check if there's a next character to form a valid escape sequence
            if i + 1 < length:
                next_char = argstr[i+1]
                # Valid escape sequences: \\ (backslash), \" (double quote), \t (tab), \r (carriage return), \n (newline)
                if next_char in ['\\', '"', 't', 'r', 'n']:
                    if next_char == '\\':
                        char = '\\'
                    elif next_char == '"':
                        char = '"'
                    elif next_char == 't':
                        char = '\\t'
                    elif next_char == 'r':
                        char = '\\r'
                    elif next_char == 'n':
                        char = '\\n'
                    charhex = char2hex(char)
                    # Update dmem binary data
                    upd_dmem_data("byte", 0, 1, charhex)
                    # Skip the next character as it's part of the escape sequence
                    i += 2
                else:
                    # Trailing backslash is invalid
                    print('| FATAL: Error in parsing string and writing to dmem binary data!')
                    print_fail()
                    exit(2)
                    continue
            else:
                # Trailing backslash is invalid
                print('| FATAL: Error in parsing string and writing to dmem binary data!')
                print_fail()
                exit(2)
        else:
            # Any non-escape character is allowed
            charhex = char2hex(char)
            # Update dmem binary data
            upd_dmem_data("byte", 0, 1, charhex)
            i += 1
    upd_dmem_data("byte", 0, 1, "0x00")  # Write null character at the end of the string


# Function to update dmem binary data
def upd_dmem_data(dtype, zsize, dsize, dvalue):
    # Step 1: Add zsize bytes of zero-padding
    for _ in range(zsize):
        dmem_binary_data.append(0x00)
        dmem_bytecnt[0] = dmem_bytecnt[0] + 1

    # Step 2: Convert dvalue to integer
    dvalue = int(dvalue, 0)  # Automatically detects hex or decimal based on the string format

    # Step 3: Determine number of bytes based on dtype
    if dtype == 'zero':
        #print(dmem_binary_data)#dbg
        return 0  # Nothing more to do, zero padding finished already...
    elif dtype == 'byte':
        num_bytes = 1
    elif dtype == 'hword':
        num_bytes = 2
    elif dtype == 'word':
        num_bytes = 4

    # Convert the integer to bytes of length num_bytes in little-endian format   
    is_signed = dvalue < 0 
    dvalue_bytes = dvalue.to_bytes(num_bytes, 'little', signed=is_signed)

    # Step 4: Append each byte of dvalue_bytes to dmem_binary_data using append
    for byte in dvalue_bytes:
        dmem_binary_data.append(byte)
        dmem_bytecnt[0] = dmem_bytecnt[0] + 1
    #print(dmem_binary_data)#dbg


# Function to transform lil-endian bytearray of 32-bit chunks to big-endian
def trans2bigend(byte_arr):
    # Calculate padding needed to make the data binary 4-byte aligned
    padding_length = (4 - len(byte_arr) % 4) % 4

    # Append zero padding if necessary
    if padding_length > 0:
        byte_arr.extend([0] * padding_length)
        dmem_bytecnt[0] = dmem_bytecnt[0] + padding_length

    # Process each 4-byte chunk
    for i in range(0, len(byte_arr), 4):
        # Extract the 4-byte chunk
        little_endian_chunk = byte_arr[i:i + 4]
        # Reverse the byte order to convert to big-endian
        big_endian_chunk = little_endian_chunk[::-1]
        # Update the bytearray with the big-endian chunk
        byte_arr[i:i + 4] = big_endian_chunk
    #print(byte_arr) #dbg


# ----------------------- Main Code --------------------------- #
# Welcome message
print_welcome()

# Source and Destination file paths, other defaults
f_src_path = './sample.s'
f_des_path_imem_bintext = './sample_imem_bin.txt'
f_des_path_imem_hextext = './sample_imem_hex.txt'
f_des_path_imem_bin = './sample_imem.bin'
f_des_path_dmem_bintext = './sample_dmem_bin.txt'
f_des_path_dmem_hextext = './sample_dmem_hex.txt'
f_des_path_dmem_bin = './sample_dmem.bin'
pcrel_flag = False

# Process command-line arguments
file_argument = None
for arg in sys.argv[1:]:
    if arg.startswith('-file='):
        file_argument = arg        
    elif arg == '-pcrel':
        print ("| INFO : The assembler will map instructions (LA/JA) to use PC relative addressing for relocatable code...")
        pcrel_flag = True

if not pcrel_flag:
    print("| INFO : The assembler will map instructions (LA/JA) to use absolute addressing assuming non-relocatable code...")

# Process file argument
if file_argument and file_argument.startswith('-file='):
    filename = file_argument.split('-file=')[1]
    if filename.endswith('.s'):
        f_src_path = filename
        f_des_path_imem_bintext = filename.rstrip('.s') + '_imem_bin.txt'
        f_des_path_imem_hextext = filename.rstrip('.s') + '_imem_hex.txt'
        f_des_path_imem_bin = filename.rstrip('.s') + '_imem.bin'
        f_des_path_dmem_bintext = filename.rstrip('.s') + '_dmem_bin.txt'
        f_des_path_dmem_hextext = filename.rstrip('.s') + '_dmem_hex.txt'
        f_des_path_dmem_bin = filename.rstrip('.s') + '_dmem.bin'
    else:
        print("| WARNG: The source file does not have a '.s' extension. Using default file paths...")
else:
    print("| WARNG: No valid 'file' argument provided. Using default file paths...")

# Open the assembly source file in read mode and store as 2D string array (list [line][char])
try:
    f_src = open(f_src_path, "r")    
    code_text_unformatted = f_src.read().splitlines()
    print("\n| INFO : Assembly code source file opened successfully...\n")
except:
    print("| FATAL: Assembly code source file cannot be opened! Please check the path/permissions...")
    print_fail()
    exit(1)

# ------------------------- Validator --------------------------- #
# Validate .text and .data section and find base address of the program
baseaddr = 0  # Base address for .text section
data_baseaddr = [0]  # Base address for .data section
dptr = [0]
pc = [0]
baseaddr = validate_assembly(f_src)
dptr[0] = data_baseaddr[0]  # Data pointer points to base addr of .data
pc[0] = baseaddr  # PC points to base addr of .text

# ---------------------- Pre-processor ------------------------- #
print('=============')
print('Pre-processor')
print('=============')
# Pre-process code line-by-line: INITIAL FORMATTING
code_text = []  # list of strings
for l in code_text_unformatted:
    l_fmt_ws = " ".join(l.split())         # Trim all extra whitespaces
    l_fmt_cm = " #".join(l_fmt_ws.split('#', 2))  # Separate comments from instructions
    l_fmt_cl = l_fmt_cm.lstrip().rstrip()         # Remove all leading and leading and trailing spaces
    l_fmt_pp = l_fmt_cl.replace(" (", "(").replace("( ", "(").replace(" )", ")").replace(") ", ")")  # Remove spaces around parentheses
    code_text.append(l_fmt_pp)

# Pre-process code line-by-line: STEP1: Remove .org linker directives and replace by null
code_text = [line if not line.startswith(".org") else '' for line in code_text]

# Identify all labels and assign addresses
labelid = [0]
label_list = []
label_addr_list = []
instrcnt = [0]
exp_instrcnt = [0]
labelcnt = [0]
is_text_label = [False]
is_data_label = [False]

dlabel_list = []
dlabel_addr_list = []
dlabelcnt = [0]
dmem_binary_data = bytearray()
dmem_bytecnt = [0]

# .data labels decoder
dlabel_state = define_dlabel(code_text, dlabel_list, dlabel_addr_list, dlabelcnt)

# .text labels decoder, also appends .data labels to the label_list
textline2pc = []  # PC corresponding to each line of code_text
istext = False
for line in code_text:
    textline2pc.append(baseaddr + int(exp_instrcnt[0]) * 4)
    if line.startswith(".section .text"):
        istext = True
    if istext:
        label_state = define_label(baseaddr, line, instrcnt, exp_instrcnt, label_list, label_addr_list)
labelcnt[0] = len(label_list)

# Print label tables
print_label_table(".data", dlabelcnt, dlabel_list, dlabel_addr_list)
print_label_table(".text", labelcnt, label_list, label_addr_list)

# Pre-process code line-by-line: STEP2: Re-format immediate expressions
code_text_pre1 = []
lnum = 0
pcrel_hi_found =[0]
pcrel_hi_pc = [0]
warng_cnt = [0]
for l in code_text:  
    words = l.split(',')
    # Check if blank line or comment
    try:
        if words[0][0] == '#':
            code_text_pre1.append(l)
            lnum = lnum + 1
            # Ignore comment and move on
            continue
        elif l.startswith("."):
            # Ignore .text .data section elements and move on
            code_text_pre1.append(l)
            lnum = lnum + 1
            continue
    except:
        code_text_pre1.append(l)
        lnum = lnum + 1
        # Ignore blank line and move on
        continue

    # Parse %hi() %lo() if any, and replace by equivalent 20-bit and 12-bit hexa immediate
    l = parse_hi_lo(l, lnum)
    lnum = lnum + 1
    words = l.split(',')

    # Could be valid instruction, check if second argument has immediate expression 'x(y)', replace it by: 'y x'
    # Also check if ascii char exists, parse and replace it with equivalent hex
    parseascii_succ = [False]
    try:
        arg2wc = words[1]
        arg2wc = arg2wc.split('#', 2)  # Separate inline comment if any
        len_arg2wc = len(arg2wc)
        arg2 = [arg2wc[0]]
        parseascii(arg2, parseascii_succ)
        arg2pp = arg2[0].replace(')', '(')
        arg2pp = "".join(arg2pp.split())
        arg2list = arg2pp.split('(')
        if len_arg2wc == 2:  # If inline comment is there
            words[1] = ' ' + arg2list[1] + ', ' + arg2list[0] + ' ' + '#' + arg2wc[1]  # Modified expression
        else:  # No inline comment
            words[1] = ' ' + arg2list[1] + ', ' + arg2list[0]  # Modified expression
        code_text_pre1.append(",".join(words))  # Write line with modified expression
    except:
        if parseascii_succ[0]:  # Some ascii char was possibly parsed...
            if len_arg2wc == 2:  # If inline comment is there
                words[1] = arg2[0] + ' ' + '#' + arg2wc[1]  # Modified expression
            else:
                words[1] = arg2[0]  # Modified expression
            code_text_pre1.append(",".join(words))  # Write line with modified expression
        else:  # No ascii char was parsed...
            code_text_pre1.append(l)
        continue


# Pre-process code line-by-line: STEP3: Remove all commas, re-format with single space
code_text_pre2 = []
for l in code_text_pre1:
    l = l.replace(',', ' ')
    code_text_pre2.append(" ".join(l.split()))

# Print pre-processed assembly code
print('\nAssembly Code')
print('-------------')
print_code(code_text_pre2)
print('')
lines_of_code = len(code_text_pre2)
print('Lines of code pre-processed =', lines_of_code, '\n')


# ----------------- Start parsing line-by-line -------------------- #
print('')
print('================')
print('Checker & Parser')
print('================')
error_flag = [0]
error_cnt = [0]
instr_sts = 0
instr_bin = []
instr_hex = []
linenum = 1

# Parse each line
for line in code_text_pre2:
    instr_sts = asm2bin(pc, line, linenum, error_flag, error_cnt, instr_bin)
    linenum = linenum + 1

# Done processing the assembly code file
# Print the parsed binary/hex code
if error_flag[0] == 0:
    print('Binary/Hex Code')
    print('---------------')
    print_code_hex(instr_bin)

# Summary
print('\n==========================================================')
print('+                        Summary                         +')
print('==========================================================')
if error_flag[0] == 0:
    print('Total no. of lines of code parsed       = ', lines_of_code)
    print('Total no. of instructions parsed        = ', instrcnt[0])
    print('Total no. of instructions with ERRORS   = ', error_cnt[0])
    print('Total no. of instructions with WARNINGS = ', warng_cnt[0])
    print('\n|| SUCCESS ||\nSuccessfully parsed the assembly code and converted to binary code...')
    gen_instr_hex(instr_bin, instr_hex)
    try:
        #### IMEM and DMEM Binary/Hex text & Binary file write ####
        #### IMEM dumps
        f_des = open(f_des_path_imem_bintext, "w")
        imem_binary_data = bytearray()
        for line in instr_bin:
            # Write to Binary text file
            f_des.write(line + '\n')
            dbyte3 = line[0:8]
            dbyte2 = line[8:16]
            dbyte1 = line[16:24]
            dbyte0 = line[24:32]
            imem_binary_data.append(int(dbyte3, 2))
            imem_binary_data.append(int(dbyte2, 2))
            imem_binary_data.append(int(dbyte1, 2))
            imem_binary_data.append(int(dbyte0, 2))
        f_des.close()

        # Write to .bin file
        f_desbin = open(f_des_path_imem_bin, "wb")
        imem_bytecnt = exp_instrcnt[0] * 4
        write2bin(imem_bytecnt, baseaddr, imem_binary_data, f_desbin, 0)
        print('\n|| SUCCESS ||\nSuccessfully written to IMEM Binary code file...')        
        f_desbin.close()

        # Write to Hex text file
        f_des = open(f_des_path_imem_hextext, "w")
        for line in instr_hex:
            f_des.write(line + '\n')
        print('\n|| SUCCESS ||\nSuccessfully written to IMEM Hex code file...')
        f_des.close()

        #### DMEM dumps
        trans2bigend(dmem_binary_data)
        # Write to Binary text file
        f_des = open(f_des_path_dmem_bintext, "w")
        for i in range(0, len(dmem_binary_data), 4):  # Iterate through the bytearray in chunks of 4 bytes
            data32bit = dmem_binary_data[i:i + 4]  # Extract the 32-bit data
            bin_str = ''.join('{:08b}'.format(b) for b in data32bit)  # Convert data to a binary string and remove the '0b' prefix
            f_des.write(bin_str + '\n')
        f_des.close()

        # Write to .bin file
        f_desbin = open(f_des_path_dmem_bin, "wb")
        dmem_binary_data_temp = dmem_binary_data.copy()
        write2bin(dmem_bytecnt[0], data_baseaddr[0], dmem_binary_data_temp, f_desbin, 1)
        print('\n|| SUCCESS ||\nSuccessfully written to DMEM Binary code file...')
        f_desbin.close()

        # Write to Hex text file
        f_des = open(f_des_path_dmem_hextext, "w")
        for i in range(0, len(dmem_binary_data), 4):  # Iterate through the bytearray in chunks of 4 bytes
            data32bit = dmem_binary_data[i:i + 4]  # Extract the 32-bit data
            hex_str = ''.join('{:02x}'.format(b) for b in data32bit)  # Convert data to a hexa string and remove the '0x' prefix
            f_des.write(hex_str + '\n')
        print('\n|| SUCCESS ||\nSuccessfully written to DMEM Hex code file...')
        f_des.close()
        print('\n|| BINARY GENERATOR SUMMARY ||')
        print("IMEM binary size = {:>8} bytes @baseaddr = 0x{:08x}".format(imem_bytecnt+16, baseaddr))
        print("DMEM binary size = {:>8} bytes @baseaddr = 0x{:08x}\n".format(dmem_bytecnt[0]+16, data_baseaddr[0]))
        print_pass()
    except:
        print('| FATAL: Unable to create Binary/Hex code file! Please check the path/permissions...')
else:
    print('Total no. of lines of code parsed       = ', lines_of_code)
    print('Total no. of instructions parsed        = ', instrcnt[0])
    print('Total no. of instructions with ERRORS   = ', error_cnt[0])
    print('Total no. of instructions with WARNINGS = ', warng_cnt[0])
    print('\n|| FAIL ||\nFailed to parse the assembly code due to errors...')
    print_fail()
    exit(2)


#############################################################################################################
