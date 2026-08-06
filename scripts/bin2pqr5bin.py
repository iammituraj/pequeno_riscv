#############################################################################################################
##   _______   _                      __     __             _    
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/          ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/ 
##           /_/                                    /___/              
#############################################################################################################
# Script           : PQR5 Binary Converter
# Developer        : Mitu Raj, chip@chipmunklogic.com
# Vendor           : Chipmunk Logic™, https://chipmunklogic.com
#
# Description      : This python script generates PQR5 binary from standard GCC objdump binaries.
#                    The generated binaries are ready-to-flash into the Pequeno via peqFlash.
#
#                    COMMAND LINE USAGE: 
#                    python bin2pqr5bin.py -binfile <binfile> -offsetaddr <offset address>
#
#                    Offset address is where the binary is placed in the memory space of the Pequeno.
#
# Last modified on : Apr-2025
# Compatiblility   : Python 3.9 tested
#
# Copyright        : Open-source license, see LICENSE.
#############################################################################################################

# Import libs
import sys
import struct
import os

# Function to validate offset address
def validate_offsetaddr(offsetaddr):
    """Validate that offset address is 4-byte aligned."""
    if offsetaddr % 4 != 0:
        print(f"Error: Offset address {hex(offsetaddr)} is not 4-byte aligned.")
        sys.exit(1)

# Function to validate input binary files
def validate_binfile(binfile):
    """Validate if the input binary file exists."""
    if not os.path.isfile(binfile):
        print(f"Error: File '{binfile}' not found.")
        sys.exit(1)

# Function to parse args
def parse_args():
    """Parse command-line arguments without enforcing order."""
    args = sys.argv[1:]
    binfile = None
    outfile = None
    offsetaddr = None

    # Iterate through arguments and find -binfile and -offsetaddr
    for i in range(len(args)):
        if args[i] == "-binfile" and i + 1 < len(args):
            binfile = args[i + 1]
        elif args[i] == "-outfile" and i + 1 < len(args):
            outfile = args[i + 1]
        elif args[i] == "-offsetaddr" and i + 1 < len(args):
            try:
                offsetaddr = int(args[i + 1], 0)  # Convert from hex or decimal
            except ValueError:
                print("Error: Invalid offset address format. Use hex (0x..) or integer.")
                sys.exit(1)

    # Validate presence of required arguments
    if binfile is None or offsetaddr is None:
        print("Usage: bin2pqr5bin -binfile <input.bin> -offsetaddr <offset address in hex or integer>")
        sys.exit(1)
    if outfile is None:
        outfile = "output_pqr5.bin"

    validate_binfile(binfile)
    validate_offsetaddr(offsetaddr)

    return binfile, outfile, offsetaddr

# Function to dump pqr5 binary files after processing...
def process_bin_file(input_file, offsetaddr, output_file):
    """Read binary file, group into 4-byte chunks, swap endianness, and write to output."""
    
    with open(input_file, "rb") as f:
        data = f.read()

    # Pad data to make it a multiple of 4 bytes
    padded_data = data.ljust((len(data) + 3) & ~3, b'\x00')

    with open(output_file, "wb") as f:
        # Write preamble (0xC0C0C0C0) - big-endian
        f.write(struct.pack(">I", 0xC0C0C0C0))

        # Write number of converted bytes (big-endian)
        f.write(struct.pack(">I", len(padded_data)))

        # Write offset address (big-endian)
        f.write(struct.pack(">I", offsetaddr))

        # Process data in 4-byte chunks, reversing endianness
        for i in range(0, len(padded_data), 4):
            chunk = padded_data[i:i+4]  # Read 4 bytes
            swapped_chunk = chunk[::-1]  # Reverse byte order (little-endian to big-endian)
            f.write(swapped_chunk)

        # Write postamble (0xE0E0E0E0) - big-endian
        f.write(struct.pack(">I", 0xE0E0E0E0))
        return 1

if __name__ == "__main__":
    binfile, outfile, offsetaddr = parse_args()
    rflag = process_bin_file(binfile, offsetaddr, outfile)
    if rflag == 1:
        print("| BIN2PQR5BIN: Successfully created the PQR5-compatible binary - ", outfile)
