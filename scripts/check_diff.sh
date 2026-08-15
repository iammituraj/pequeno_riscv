#############################################################################################################
##   _______   _                      __     __             _
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/          ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/
##           /_/                                    /___/
#############################################################################################################
# Script           : Dump diff / PASS-FAIL checker
# Developer        : Mitu Raj, chip@chipmunklogic.com
# Vendor           : Chipmunk Logic (TM), https://chipmunklogic.com
#
# Description      : Diffs the DMEM/IMEM/Register file dumps produced by the last simulation run (dump/) against
#                    the golden reference dumps already staged by the Makefile's "diff" target (dump/ref/).
#                    Prints a per-dump PASS/FAIL breakdown plus a large banner for the overall verdict, and
#                    writes the verdict to dump/test_result.txt. Never lets a genuine mismatch (diff's exit
#                    code 1) abort the script, so all three dumps are always checked and reported, and always
#                    exits 0 itself -- callers must check test_result.txt for the actual verdict.
#
# Usage            : bash scripts/check_diff.sh   (run from the repo root; dump/ and dump/ref/ must exist)
#
# Copyright        : Open-source license, see LICENSE.
#############################################################################################################
#!/bin/bash

DUMP_DIR=./dump

rm -f "$DUMP_DIR"/diff_*.txt

overall_result="PASS"

check_one() {
    local label="$1" file="$2" ref="$3" diffout="$4"
    if diff "$file" "$ref" > "$diffout"; then
        echo "| DIFF_CHECKER:   [PASS] $label"
        rm -f "$diffout"
    else
        echo "| DIFF_CHECKER:   [FAIL] $label -- differences logged to $diffout"
        overall_result="FAIL"
    fi
}

check_one "DMEM dump   " "$DUMP_DIR/pqr5_dmem_dump.txt"    "$DUMP_DIR/ref/pqr5_dmem_dump.txt"    "$DUMP_DIR/diff_dmem_dump.txt"
check_one "IMEM dump   " "$DUMP_DIR/pqr5_imem_dump.txt"    "$DUMP_DIR/ref/pqr5_imem_dump.txt"    "$DUMP_DIR/diff_imem_dump.txt"
check_one "Regfile dump" "$DUMP_DIR/pqr5_regfile_dump.txt" "$DUMP_DIR/ref/pqr5_regfile_dump.txt" "$DUMP_DIR/diff_regfile_dump.txt"

echo ""
if [ "$overall_result" = "PASS" ]; then
    echo "| DIFF_CHECKER: SUCCESS!! No differences found!"
else
    echo "| DIFF_CHECKER: OOPS... ERRORS FOUND!! See dump/diff_*.txt for details..."
fi
echo "$overall_result" > "$DUMP_DIR/test_result.txt"

echo ""
if [ "$overall_result" = "FAIL" ]; then
    cat <<'FAIL_ART'
7MM"""YMM  db      `7MMF'`7MMF'
  MM    `7 ;MM:       MM    MM
  MM   d  ,V^MM.      MM    MM
  MM""MM ,M  `MM      MM    MM
  MM   Y AbmmmqMA     MM    MM      ,
  MM    A'     VML    MM    MM     ,M
.JMML..AMA.   .AMMA..JMML..JMMmmmmMMM
FAIL_ART
else
    cat <<'PASS_ART'
7MM"""Mq.   db       .M"""bgd  .M"""bgd
  MM   `MM. ;MM:     ,MI    "Y ,MI    "Y
  MM   ,M9 ,V^MM.    `MMb.     `MMb.
  MMmmdM9 ,M  `MM      `YMMNq.   `YMMNq.
  MM      AbmmmqMA   .     `MM .     `MM
  MM     A'     VML  Mb     dM Mb     dM
.JMML. .AMA.   .AMMA.P"Ybmmd"  P"Ybmmd"
PASS_ART
fi
echo ""

exit 0
