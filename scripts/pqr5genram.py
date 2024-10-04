#############################################################################################################
##   _______   _                      __     __             _    
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/          ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/ 
##           /_/                                    /___/              
#############################################################################################################
# Script           : pqr5 generate RAM
# Developer        : Mitu Raj, chip@chipmunklogic.com
# Vendor           : Chipmunk Logic™, https://chipmunklogic.com
#
# Description      : This script generates Single-port RAM in SV which is initialized with hex values
#                    on power-on on FPGA Block RAMs. The scripts reads two source files: 
#                    -- Hex/Bin code file in ASCII text format: *_hex.txt or *_bin.txt
#                    -- Reference RAM file in SV
#                    And outputs:
#                    -- Generated RAM (IRAM & DRAM) with initialized binary in SV
#                    Invoking the script from terminal:
#                       python pqr5genram.py '<arg1> <arg2> <arg3> <arg4> <arg5>'
#                       <arg1> = Hex/Bin code file path
#                       <arg2> = Reference RAM file path
#                       <arg3> = Generated RAM module's name
#                       <arg4> = Generated RAM's depth
#                       <arg5> = Generated RAM's data width
#                       <arg6> = Offset address where first data is initialized
#                       <arg7> = Type (0=IRAM, 1=DRAM)
#                       // If no arguments provided, source files = ./sample_hex.txt, ./ram.sv, assumes IRAM
#
# Last modified on : Aug-2024
# Compatiblility   : Python 3.9 tested
#
# Copyright        : Open-source license, see developer.txt.
#############################################################################################################

# Import Libraries
import sys

# Function to print welcome message
def print_welcome():
    print('+===================================+')
    print('|      Chipmunk Logic (TM) 2024     |')
    print('+===================================+')
    print('|~~~~~~ GENRAM: RAM Generator ~~~~~~|')
    print('|/////// O P E N S O U R C E ///////|')
    print('+===================================+')


# Source and Destination file paths
# Decode from command line arguments
print_welcome()
try:
    # No. of arguments = len(sys.argv)-1
    f_hex_src_path = sys.argv[1]  # Source file 1: Hex/Bin code file
    f_ram_src_path = sys.argv[2]  # Source file 2: Reference RAM file in SV
    gen_module = sys.argv[3]      # Generated RAM module's name
    ram_depth = sys.argv[4]       # Generated RAM's depth
    ram_width = sys.argv[5]       # Generated RAM's data width
    offset = sys.argv[6]          # Offset address where first data is initialized
    type = sys.argv[7]            # Type; 0=IRAM or 1=DRAM

    # Module name array
    if type == "0":
        module = [gen_module]
        banks = 1
        if int(ram_width, 0) % 8 != 0:
            print("| ERROR: Instruction RAM width must be a multiple of 8...")
            exit(1)
        bwidth = int(int(ram_width, 0)/4)  # Bank data width in nibbles
        # Calculate the alignment step
        alignment = int(ram_width, 0) // 8
        # Round offset up to the next multiple of alignment
        offset = int((int(offset, 0) + alignment - 1) // alignment)
        print(f"| INFO : Offset address of Instruction RAM set = 0x{(offset * 4):08X}")
    elif type == "1":        
        module = [gen_module+'_b0', gen_module+'_b1', gen_module+'_b2', gen_module+'_b3']  # 4 banks
        banks = 4
        if int(ram_width, 0) % 8 != 0:
            print("| ERROR: Data RAM width must be a multiple of 8...")
            exit(1)
        bwidth = int((int(ram_width, 0)/4)/banks)  # Bank data width in nibbles        
        # Calculate the alignment step
        alignment = int(ram_width, 0) // 8        
        # Round offset up to the next multiple of alignment
        offset = int((int(offset, 0) + alignment - 1) // alignment)        
        print(f"| INFO : Offset address of Data RAM set = 0x{(offset * 4):08X}")
    else:
        print('| ERROR: Unsupported memory type argument...')
        exit(1)
    # Destination file(s): Generated RAM in SV
    f_des_path_pp = f_ram_src_path.replace('\\', '/')
    f_des_path_l = list(f_des_path_pp.split('/'))
    f_des_path_l[-1] = ''
    if type == "0":
        f_des_path = ["/".join(f_des_path_l) + f"{gen_module}.sv" for i in range(banks)]   
    else:
        f_des_path = ["/".join(f_des_path_l) + f"{gen_module}_b{i}.sv" for i in range(banks)]
except:
    # Default parameters
    print('| INFO : No arguments/unsupported arguments, proceeding with default files...')
    f_hex_src_path = './sample_imem_hex.txt'
    f_ram_src_path = './ram.sv'    
    gen_module = 'genram'
    ram_depth = 1024
    ram_width = 32
    offset = 0
    type = 0
    module = [gen_module]
    banks = 1
    bwidth = 8
    f_des_path = './genram.sv'

# Open all files
try:    
    f_hex_src = open(f_hex_src_path, "r", encoding="utf8")
    f_ram_src = open(f_ram_src_path, "r", encoding="utf8")     
    if type == "1":
        f_temp_path_pp = f_ram_src_path.replace('\\', '/')
        f_temp_path_l = list(f_temp_path_pp.split('/'))
        src_module = f_temp_path_l[-1].rsplit('.', 1)[0]     
        f_temp_path_l[-1] = '' 
        f_ram_4x8_src_path = "/".join(f_temp_path_l) + src_module + "_4x8.sv"
        print(f_ram_4x8_src_path)
        f_ram_4x8_src = open(f_ram_4x8_src_path, "r", encoding="utf8")    
        # Destination file: Generated banked DRAM in SV    
        f_des_4x8_path = "/".join(f_temp_path_l) + gen_module + "_4x8.sv"
        f_des_4x8 = open(f_des_4x8_path, "w")     
    f_des = [open(f_des_path[i], "w") for i in range(banks)]
except:
    print("| FATAL: Files cannot be opened! Please check the path/permissions...")
    exit(1)

if (f_hex_src_path.endswith('_hex.txt') or f_hex_src_path.endswith('_bin.txt')) and \
   (f_ram_src_path.endswith('.sv') or f_ram_src_path.endswith('.v')):
    print('\n| INFO : Opened all files successfully...')
    if f_hex_src_path.endswith('_hex.txt'):
        is_hex = 1
        slicewidth = bwidth
        mfact = 4
        suffix = "'h"
    else:
        is_hex = 0
        slicewidth = bwidth * 4
        mfact = 1
        suffix = "'b"
else:
    print('| ERROR: Unsupported files or files have errors!')
    exit(1)

# Read and store contents of files (data), and calculate data size
hex_src = f_hex_src.read().splitlines()
ram_src = f_ram_src.read().splitlines()
if type == "1":
    ram_4x8_src = f_ram_4x8_src.read().splitlines()       
    f_ram_4x8_src.close()

f_hex_src.close()
f_ram_src.close()

data_size = len(hex_src)

if (data_size > int(ram_depth, 0)) or (data_size > (int(ram_depth, 0)-offset)):
    print('| WARNG: Hex/Bin file contains more data than the RAM could accomodate...')
if offset >= int(ram_depth, 0):
    print('| FATAL: Offset address is beyond the addressing range of generated ram...')
    exit(2)

# Form the destination file content data array
for b in range(banks):
    des = []
    d = 0
    for line in ram_src:    
        if line.startswith('module'):
            des.append('module ' + module[b] + ' #(')
        elif line.startswith('endmodule'):
            des.append('//**AUTOGENERATED**//')
            des.append('// Supported for initialization by most FPGA Block RAMs')
            des.append('initial begin')
            for addr in range(data_size):
                maddr = addr + offset
                try:
                    data_raw = hex_src[addr]                    
                    datalen = len(data_raw)*mfact
                    if datalen != int(ram_width, 0):
                        print('| ERROR: Verify data width!')
                        exit(1)
                    # Calculate the start and end indices for slicing
                    idx_start = -slicewidth * (b + 1)
                    idx_end = -slicewidth * b if b > 0 else None                         
                    # Extract the data chunk based on bwidth
                    data = data_raw[idx_start:idx_end]
                except:
                    print('| ERROR: Verify data width, data parsing failed!')
                    exit(1)              
                des.append("   ram" + "[" + str(maddr) + "] = " + str(bwidth*4) + suffix + data + " ;")
                # Loop breaker to avoid data assignment to invalid addr locations
                d = d + 1           
                if (d == int(ram_depth, 0)) or (maddr == int(ram_depth, 0)-1):                    
                    break                
            des.append('end')
            des.append('//**AUTOGENERATED**//')
            des.append('')
            des.append('endmodule')
        elif len(line.split()) > 0 and line.split()[0] == 'parameter' and line.split()[1] == 'DEPTH':
            des.append('   parameter  DEPTH  = ' + str(ram_depth) + ' ,    // Depth of RAM //**AUTOGENERATED**//')            
        elif len(line.split()) > 0 and line.split()[0] == 'parameter' and line.split()[1] == 'DATA_W':
            des.append('   parameter  DATA_W = ' + str(bwidth*4) + ' ,    // Data width //**AUTOGENERATED**//')
        else:
            des.append(line)     

    # Write to destination RAM file
    for line in des:
        #print(line)
        f_des[b].write(line + '\n')  # Because string list doesn't contain '\n' characters, all trimmed by  splitline()
    
# RAM 4x8
if type == "1":        
    des = []    
    # Form the destination file content data array for RAM 4x8;
    for line in ram_4x8_src:
        if line.startswith('module'):
            des.append('module ' + gen_module + '_4x8' + ' #(')         
        elif len(line.split()) > 0 and line.split()[0] == 'parameter' and line.split()[1] == 'DEPTH':
            des.append('   parameter  DEPTH  = ' + str(ram_depth) + ' ,    // Depth of RAM //**AUTOGENERATED**//')        
        else:
            des.append(line)
    # Write to destination RAM 4x8 file
    for line in des:
        #print(line)
        f_des_4x8.write(line + '\n')  # Because string list doesn't contain '\n' characters, all trimmed by  splitline()

print('| INFO : Generated the RAM in SV files successfully...')
if type == "0":
    print('\n|| Success ||\n Generated I-RAM of ', ram_depth, 'x', ram_width, ' bit with binary initiated @offset addr = 0x{:08X}'.format(offset * 4))
else:
    print('\n|| Success ||\n Generated D-RAM of ', ram_depth, 'x', ram_width, ' bit with binary initiated @offset addr = 0x{:08X}'.format(offset * 4))