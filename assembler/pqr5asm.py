#############################################################################################################
# ╔═╦╗╔╗─────────╔╗─╔╗────╔╗
# ║╔╣╚╬╬═╦══╦╦╦═╦╣╠╗║║╔═╦═╬╬═╗
# ║╚╣║║║╬║║║║║║║║║═╣║╚╣╬║╬║║═╣ /////////////// O P E N S O U R C E
# ╚═╩╩╩╣╔╩╩╩╩═╩╩═╩╩╝╚═╩═╬╗╠╩═╝
# ─────╚╝───────────────╚═╝
#############################################################################################################
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
#                    -- Supports ABI acronyms (ref. pqr5asm Instruction Manual for more details)
#                    -- Input = assembly code file, Output = binary/hex code files (.txt/.bin)
#                       // .bin file format (byte sequence in BIG ENDIAN):
#                          <0xF0F0F0F0>  // pre-amble
#                          <Program size in bytes (= no. of instructions * 4 bytes)>
#                          <PC base address[3][2][1][0]>
#                          <instruction[0] byte[3][2][1][0]>
#                          <instruction[1] byte[3][2][1][0]>
#                          <...>
#                          <0xE0E0E0E0>  // post-amble
#                       // bin and hex code files are also dumped as ASCII .txt files
#                    -- One instruction per line, semicolon optional.
#                    -- Base address of program (PC of first instruction) can be defined in the first line of program.
#                       for eg: .ORIGIN 0x4000 
#                       If not provided, overridden to 0x00000000
#                       Binary file will be generated to target this address on the instr. memory to store instructions
#                    -- Supports <space>, <comma>, and <linebreak> as delimiters for eg:
#                                                                              LUI x5 255 <linebreak>
#                                                                              LUI x5, 255 <linebreak>
#                    -- Use '#' for inline/newline comments for eg: LUI x5 255  # This is a sample comment
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
#                    -- Supports labels for jump/branch instructions
#                       -- Label is recommended to be of max. 8 ASCII characters
#                       -- Label should be stand-alone in new line for eg: fibonacc:
#                                                                          ADD x1, x1, x2
#                       -- Label is case-sensitive
#                       -- Pre-processor will assign pc-relative address to label
#                    -- Immediate value supports ascii characters for instructions like MVI, LI
#                       For eg: LI r0, 'A'  # Loads 0x41 to r0 register
#                       Supports '\n', '\r', and all 7-bit ascii characters from 0x20 to 0x7E.
#                    -- Invoking the script from terminal:
#                       python pqr5asm.py '<source file path>'
#                       // Binary/Hex code files are generated in same path
#                       // If no arguments provided, source file = sample.s in current directory
#
# Last modified on : June-2024
# Compatiblility   : Python 3.9 tested
#
# Copyright        : Open-source license, see developer.txt.
#############################################################################################################

# Import Libraries
import numpy as np
import sys
import re

# --------------------------- Global Vars ----------------------------------- #
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
# Function to print welcome message
def print_welcome():
    print('+===================================+')
    print('|      Chipmunk Logic (TM) 2024     |')
    print('+===================================+')
    print('|~~~~~~~~ RISC-V Assembler ~~~~~~~~~|')
    print('|/////// O P E N S O U R C E ///////|')
    print('+===================================+')


# Function to dump .bin file
def write2bin(pgmsize, baddr, dbytearray, binfile):
    # Insert pre-amble 0xF0F0F0F0
    dbytearray.insert(0, int("11110000", 2))
    dbytearray.insert(1, int("11110000", 2))
    dbytearray.insert(2, int("11110000", 2))
    dbytearray.insert(3, int("11110000", 2))
    # Insert program size
    pgmsize_bytearray = pgmsize.to_bytes(4, 'big')
    dbytearray.insert(4, pgmsize_bytearray[0])
    dbytearray.insert(5, pgmsize_bytearray[1])
    dbytearray.insert(6, pgmsize_bytearray[2])
    dbytearray.insert(7, pgmsize_bytearray[3])
    # Insert PC base address
    baddr_bytearray = baddr.to_bytes(4, 'big')
    dbytearray.insert(8, baddr_bytearray[0])
    dbytearray.insert(9, baddr_bytearray[1])
    dbytearray.insert(10, baddr_bytearray[2])
    dbytearray.insert(11, baddr_bytearray[3])
    # Insert post-amble 0xE0E0E0E0
    dbytearray.append(int("11100000", 2))
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
def print_label_table(labelcnt, label_list, label_addr_list):
    print('')
    print('+-----------------------------')
    print('| Label    | Address Mapping')
    print('+-----------------------------')
    for i in range(labelcnt[0]):
        print('| %+-8s' % label_list[i], ": 0x{:08x}".format(label_addr_list[i]))
    print('+-----------------------------')


# Function to parse string arguments and convert to hex
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
    else:
        return '#ERR'


# Function to parse string arguments and convert to hex
def parseascii(arg):
    if arg:
        s = arg[0]
        parts = s.split("'")
        if ((len(parts) == 3 and len(parts[1]) == 1) or
            ((len(parts) == 3 and len(parts[1]) == 2) and (parts[1] == '\\n' or parts[1] == '\\r'))):
            arghex = char2hex(parts[1])
            parseascii_succ[0] = True
            if arghex != "#ERR":
                modified_expr = parts[0] + arghex + parts[2]
                arg[0] = modified_expr
            else:
                arg[0] = arg


# Function to generate hex instructions from binary instructions
def gen_instr_hex(instr_bin, instr_hex):
    for line in instr_bin:
        instr_hex.append("{:08x}".format(int(line, 2)))  # 32-bit hex from binary string


# Function to return address of label
def addr_of_label(idd):
    for i in range(labelcnt[0]):
        if idd == label_list[i]:
            return label_addr_list[i]
    return idd


# Function to check if a register operand is valid or not
def is_invalid_reg(reg):
    if reg not in reglist:
        return 1
    else:
        return 0


# Function to check if a label is valid or not
def is_valid_label(lbl):
    if lbl in label_list:
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


# Function validate .ORIGIN and return base address
def validate_origin(firstline):
    origin = firstline.split()
    try:
        # First word
        if origin[0] == '.ORIGIN' or origin[0] == '.origin':
            addr_pre = origin[1]
            if addr_pre[0:2] == '0x' or addr_pre[0:2] == '0X':
                addr = (int(addr_pre, base=16) >> 2) * 4
            else:
                addr = (int(addr_pre) >> 2) * 4
            print('| INFO: Base address of program set to', "0x{:08x}".format(addr))
            return addr
        else:
            print('| WARNG: .ORIGIN not set in first line. Base address of program overridden to 0x00000000')
            return 0
    except:
        print('| WARNG: .ORIGIN not set in first line. Base address of program overridden to 0x00000000')
        return 0


# Function to define label address mapping
def define_label(baseaddr, line, instrcnt, exp_instrcnt, labelcnt, label_list, label_addr_list):
    words = line.split()
    # Check if blank line or comment or origin
    try:
        if words[0][0] == '#':
            # Ignore comment and move on
            return 0
        elif words[0] == '.ORIGIN' or words[0] == '.origin':
            # Ignore origin
            return 0
    except:
        # Ignore blank line and move on
        return 0

    # Valid label?
    if len(words) == 1 and line[-1] == ':':  # Decode labels like 'mylabel:'
        label = line.split(':')[0]
        labelcnt[0] = labelcnt[0] + 1
        label_list.append(label)
        label_addr_list.append(baseaddr + int(exp_instrcnt[0]) * 4)
    elif len(words) > 1 and words[0][-1] == ':' and words[1][0] == '#':  # Decodes labels with comments
        label = line.split(':')[0]
        labelcnt[0] = labelcnt[0] + 1
        label_list.append(label)
        label_addr_list.append(baseaddr + int(exp_instrcnt[0]) * 4)
    else:
        # It is an instruction
        instrcnt[0] = instrcnt[0] + 1
        if words[0] == 'LI' or words[0] == 'li' or words[0] == 'LA' or words[0] == 'la':
            offset = 2  # Because LI = expands to two instructions
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
def imm2bin(immval, linenum, errsts, jbflag, laflag):
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
            elif jbflag == 1 and is_valid_label(immval.rstrip(':')):
                addr_of_label_int = addr_of_label(immval)
                pc_reltv_addr_int = addr_of_label_int - pc[0]  # pc relative addr
                if pc_reltv_addr_int < 0:
                    pc_reltv_addr_int = 0xffffffff + 1 + pc_reltv_addr_int  # pc relative addr 2's complement
                immval_bin = '{:032b}'.format(pc_reltv_addr_int, base=16)  # pc relative addr signed 32-bit
                return immval_bin
            # Label --> translation --> absolute address for la instruction
            elif laflag == 1 and is_valid_label(immval.rstrip(':')):
                addr_of_label_int = addr_of_label(immval)
                abs_addr_int = addr_of_label_int
                immval_bin = '{:032b}'.format(abs_addr_int, base=16)  # pc relative addr signed 32-bit
                return immval_bin
            else:
                print("| ERROR: Invalid immediate/offset value or label at line no: ", linenum)
                errsts[0] = 1
                return 0
        except:
            print("| ERROR: Invalid immediate/offset value or label at line no: ", linenum)
            errsts[0] = 1
            return 0


# Function to parse assembly code line to binary
def asm2bin(pc, line, linenum, error_flag, error_cnt, instr_bin):
    instr_error_flag = 0
    # Split the instruction to word-by-word
    element = line.split()

    # Check if blank line or comment or origin
    try:
        if element[0][0] == '#':
            # Ignore comment and move on
            return 0
        elif element[0] == '.ORIGIN' or element[0] == '.origin':
            # Ignore origin
            return 0
        elif is_valid_label(element[0].rstrip(':')):
            # Ignore valid labels
            return 0
    except:
        # Ignore blank line and move on
        return 0

    # Validate opcode existence
    try:
        opcode = element[0]
    except:
        print("| FATAL: Instruction at line no: ", linenum, " is missing opcode!\n")
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
    ps_not_type_flag = 0
    ps_inv_type_flag = 0
    ps_seqz_type_flag = 0
    ps_snez_type_flag = 0
    ps_beqz_type_flag = 0
    ps_bnez_type_flag = 0
    ps_li_type_flag = 0
    ps_la_type_flag = 0
    ps_jr_type_flag = 0

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
    elif opcode == 'J' or opcode == 'j':
        ps_j_type_flag = 1
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
        opcode_binarr.append('0110111')  # LUI
        opcode_binarr.append('0010011')  # ADDI
    elif opcode == 'JR' or opcode == 'jr':
        ps_jr_type_flag = 1
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

    # Validate pseudo instruction: J
    if ps_j_type_flag == 1:
        try:
            j_type_flag = 1  # Derived from j-type
            rdt = 'x0'
            imm = element[1]
            if len(element) > 2 and element[2][0] != '#':  # Integrity check; ignore if inline comment
                print("| ERROR: Invalid no. of operands at line no: ", linenum)
                instr_error_flag = 1
                error_flag[0] = 1
        except:
            print("| FATAL: Instruction at line no: ", linenum, " is missing one or more operands!\n")
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
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Validate pseudo instruction: LI/LA
    if ps_li_type_flag or ps_la_type_flag:
        try:
            rs1 = element[1]  # For ADDI
            rdt = element[1]  # For LUI, ADDI
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
            error_cnt[0] = error_cnt[0] + 1
            return 2

    # Convert all instr fields to binary codes
    rs1_bin = reg2bin(rs1)
    rs2_bin = reg2bin(rs2)
    rdt_bin = reg2bin(rdt)

    # Decode immediate/offset
    errsts = [0]
    if r_type_flag == 0:  # Ignore only if r-type instruction
        imm_bin = imm2bin(imm, linenum, errsts, (j_type_flag or b_type_flag), ps_la_type_flag)

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
    elif instr_error_flag == 0 and (ps_li_type_flag or ps_la_type_flag):  # = LUI + ADDI
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
    elif instr_error_flag == 0 and (ps_jr_type_flag):  # = JALR
        imm_bin_11_0 = imm_bin[20:32]  # imm[11:0]
        funct3 = '000'
        instr_bin.append(imm_bin_11_0 + rs1_bin + funct3 + rdt_bin + opcode_bin)
    else:
        funct3 = 'XXX'  # Do nothing

    # Update pc
    if ps_li_type_flag or ps_la_type_flag:
        pc[0] = pc[0] + 8  # Because LI = expands to two instructions
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


# ----------------------- Main Code --------------------------- #
# Welcome message
print_welcome()

# Source and Destination file paths
# Decode from command line arguments
try:
    f_src_path = sys.argv[1]
    f_des_path_bintext = sys.argv[1].rstrip('.s') + '_bin.txt'
    f_des_path_hextext = sys.argv[1].rstrip('.s') + '_hex.txt'
    f_des_path_bin = sys.argv[1].rstrip('.s') + '.bin'
except:
    # Default parameters
    print('| INFO : No arguments/unsupported arguments, proceeding with default files...')
    f_src_path = './sample.s'
    f_des_path_bintext = './sample_bin.txt'
    f_des_path_hextext = './sample_hex.txt'
    f_des_path_bin = './sample.bin'

# Open assembly file in read mode and store as 2D string array (list [line][char])
try:
    f_src = open(f_src_path, "r")
    code_text_unformatted = f_src.read().splitlines()
    print("\n| INFO : Assembly code source file opened successfully...\n")
except:
    print("| FATAL: Assembly code source file cannot be opened! Please check the path/permissions...")
    exit(1)

# ---------------------- Pre-processor ------------------------- #
print('=============')
print('Pre-processor')
print('=============')
# Pre-process code line-by-line: INITIAL FORMATTING
code_text = []  # list of strings
for l in code_text_unformatted:
    l_fmt_ws = " ".join(l.split())                # Trim all extra whitespaces
    l_fmt_cm = " #".join(l_fmt_ws.split('#', 2))  # Separate comments from instructions
    l_fmt_init = l_fmt_cm.lstrip()                # Remove all leading spaces
    code_text.append(l_fmt_init)

# Pre-process code line-by-line: STEP1: Re-format immediate expressions
code_text_pre1 = []
for l in code_text:
    words = l.split(',')
    # Check if blank line or comment or origin
    try:
        if words[0][0] == '#':
            code_text_pre1.append(l)
            # Ignore comment and move on
            continue
        elif words[0] == '.ORIGIN' or words[0] == '.origin':
            code_text_pre1.append(l)
            # Ignore origin
            continue
    except:
        code_text_pre1.append(l)
        # Ignore blank line and move on
        continue
    # Could be valid instruction, check if second argument has immediate expression 'x(y)', replace it by: 'y x'
    # Also check if ascii char exists, parse and replace it with equivalent hex
    parseascii_succ = [False]
    try:
        arg2wc = words[1]
        arg2wc = arg2wc.split('#', 2)  # Separate inline comment if any
        len_arg2wc = len(arg2wc)
        arg2 = [arg2wc[0]]
        parseascii(arg2)
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


# Pre-process code line-by-line: STEP2: Remove all commas, re-format with single space
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

# Check for .ORIGIN header
baseaddr = validate_origin(code_text_pre2[0])

# Identify all labels and assign addresses
label_list = []
label_addr_list = []
instrcnt = [0]
exp_instrcnt = [0]
labelcnt = [0]
for line in code_text:
    label_state = define_label(baseaddr, line, instrcnt, exp_instrcnt, labelcnt, label_list, label_addr_list)
print_label_table(labelcnt, label_list, label_addr_list)

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
pc = [0]
pc[0] = baseaddr

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
    print('Total no. of lines of code parsed     = ', lines_of_code)
    print('Total no. of instructions parsed      = ', instrcnt[0])
    print('Total no. of instructions with ERRORS = ', error_cnt[0])
    print('\n|| SUCCESS ||\nSuccessfully parsed the assembly code and converted to binary code...')
    gen_instr_hex(instr_bin, instr_hex)
    try:
        # Binary text file write
        f_des = open(f_des_path_bintext, "w")
        f_desbin = open(f_des_path_bin, "wb")
        binary_data = bytearray()
        for line in instr_bin:
            f_des.write(line + '\n')
            dbyte3 = line[0:8]
            dbyte2 = line[8:16]
            dbyte1 = line[16:24]
            dbyte0 = line[24:32]
            binary_data.append(int(dbyte3, 2))
            binary_data.append(int(dbyte2, 2))
            binary_data.append(int(dbyte1, 2))
            binary_data.append(int(dbyte0, 2))
        # Dump .bin file
        instr_totalsize_bytes = instrcnt[0] * 4
        write2bin(instr_totalsize_bytes, baseaddr, binary_data, f_desbin)
        print('\n|| SUCCESS ||\nSuccessfully written to Binary code file...')
        f_des.close()
        f_desbin.close()

        # Hex text file write
        f_des = open(f_des_path_hextext, "w")
        for line in instr_hex:
            f_des.write(line + '\n')
        print('\n|| SUCCESS ||\nSuccessfully written to Hex code file...')
        f_des.close()
    except:
        print('| FATAL: Unable to create Binary/Hex code file! Please check the path/permissions...')
else:
    print('Total no. of lines of code parsed     = ', lines_of_code)
    print('Total no. of instructions parsed      = ', instrcnt[0])
    print('Total no. of instructions with ERRORS = ', error_cnt[0])
    print('\n|| FAIL ||\nFailed to parse the assembly code due to errors...')
    exit(2)


#############################################################################################################
