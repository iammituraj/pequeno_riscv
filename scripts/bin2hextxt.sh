#############################################################################################################
##   _______   _                      __     __             _    
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/          ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/ 
##           /_/                                    /___/              
#############################################################################################################
# Script           : bin2hextxt.sh
# Developer        : Mitu Raj, chip@chipmunklogic.com
# Vendor           : Chipmunk Logic™, https://chipmunklogic.com
#
# Description      : This bash script converts bin file (little-endian) to Hex Text file. 
#
#                    COMMAND LINE USAGE: 
#                    bash bin2hextxt.sh <binfile>
#
#                    Base address is where the binary is placed in the memory space of the Pequeno.
#
# Last modified on : Apr-2025
# Compatiblility   : Linux/Unix
#
# Copyright        : Open-source license, see LICENSE.
#############################################################################################################

#!/bin/bash

# Check if input file argument is given
if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_file> <outfile>"
    exit 1
fi

input_file="$1"
output_file="$2"

# Validate file existence
if [ ! -f "$input_file" ]; then
    echo "**ERROR** File '$input_file' not found."
    exit 2
fi
echo "File $input_file opened successfully."

# Extract base file name without extension
#base_name="${input_file%.*}"
#output_file="${base_name}_hex.txt"

# Get file size in bytes
file_size=$(stat -c%s "$input_file")
pad_needed=$((file_size % 4))

# Create a temporary padded copy if zero-padding is needed
if [ "$pad_needed" -ne 0 ]; then
    pad_bytes=$((4 - pad_needed))
    echo "Binary file is not 4-byte aligned."
    echo "Padding $pad_bytes byte(s) to align to 4 bytes..."

    # Create a temporary padded file in the current directory with _temp suffix
    temp_file="${base_name}_temp.bin"
    cp "$input_file" "$temp_file"

    # Append zero bytes to the temporary file
    printf '\x00' | head -c $pad_bytes >> "$temp_file"

    processed_file="$temp_file"
else
    processed_file="$input_file"
fi

# Generate the Hex Text file
xxd -g1 -c4 -p "$processed_file" | awk '{print substr($0,7,2) substr($0,5,2) substr($0,3,2) substr($0,1,2)}' > "$output_file"

# Clean up if temp file was created
if [ "$processed_file" != "$input_file" ]; then
    rm -f "$processed_file"
fi

echo "Hex Text file created - $output_file"
