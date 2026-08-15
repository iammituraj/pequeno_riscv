#############################################################################################################
##   _______   _                      __     __             _
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/          ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/
##           /_/                                    /___/
#############################################################################################################
# Script           : IRAM/DRAM size sync checker
# Developer        : Mitu Raj, chip@chipmunklogic.com
# Vendor           : Chipmunk Logic (TM), https://chipmunklogic.com
#
# Description      : Warns (never fails the build) if the IRAM_SIZE/DRAM_SIZE macros currently in
#                    src/include/pqr5_subsystem_macros.svh are smaller than the ISZ/DSZ actually used to
#                    generate the RAMs for this build. The IRAM/DRAM I/F size (those macros) must always be
#                    >= the generated RAM size -- the I/F can be larger than what's generated (that's just
#                    unused address space headroom, harmless), but if it's smaller, the generated RAM
#                    extends beyond what the I/F can address, which is a real problem.
#
# Usage            : bash scripts/check_iram_dram_sync.sh <ISZ bytes> <DSZ bytes>   (run from the repo root)
#
# Copyright        : Open-source license, see LICENSE.
#############################################################################################################
#!/bin/bash

ISZ_USED="$1"
DSZ_USED="$2"
MACROS_FILE="./src/include/pqr5_subsystem_macros.svh"

iram_if_sz=$(grep -E '^`define[[:space:]]+IRAM_SIZE[[:space:]]+[0-9]+' "$MACROS_FILE" | awk '{print $3}')
dram_if_sz=$(grep -E '^`define[[:space:]]+DRAM_SIZE[[:space:]]+[0-9]+' "$MACROS_FILE" | awk '{print $3}')

warn=0
if [ -n "$iram_if_sz" ] && [ "$iram_if_sz" -lt "$ISZ_USED" ]; then warn=1; fi
if [ -n "$dram_if_sz" ] && [ "$dram_if_sz" -lt "$DSZ_USED" ]; then warn=1; fi

if [ "$warn" -eq 1 ]; then
    echo ""
    echo "| MAKE_PQR5: **WARNING** IRAM_SIZE/DRAM_SIZE in $MACROS_FILE are smaller"
    echo "             than the ISZ/DSZ used to generate the RAMs for this build. The IRAM/DRAM I/F size"
    echo "             must be >= the generated RAM size, else the RTL can't address the full RAM."
    echo "             Used for this build: ISZ=$ISZ_USED DSZ=$DSZ_USED."
    echo "             In subsystem macros: IRAM_SIZE=$iram_if_sz DRAM_SIZE=$dram_if_sz."
    echo "             Run make configurator, or manually update IRAM_SIZE/DRAM_SIZE, to fix this."
    echo ""
fi

exit 0
