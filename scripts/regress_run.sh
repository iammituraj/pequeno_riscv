#############################################################################################################
##   _______   _                      __     __             _    
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/          ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/ 
##           /_/                                    /___/              
#############################################################################################################
# Script           : Regression run
# Developer        : Mitu Raj, chip@chipmunklogic.com
# Vendor           : Chipmunk Logic™, https://chipmunklogic.com
#
# Description      : This script runs regression on the PQR5 CPU. Builds and runs all ASM example programs
#                    & dump results. The test results are available in dump/regression_dump at the end of
#                    successful run. 
#
# Last modified on : Aug-2026
# Compatiblility   : Linux/Windows bash terminal
#
# Copyright        : Open-source license, see LICENSE.
#############################################################################################################
#!/bin/bash

# IRAM/DRAM sizes (bytes), forwarded to `make build`; defaults to 1024/1024 if not passed in
ISZ=${1:-1024}
DSZ=${2:-1024}

# CONFIGURATION
en_run01=1
en_run02=1
en_run03=1
en_run04=1
en_run05=1
en_run06=1
en_run07=1
en_run08=1
en_run09=1
en_run10=1
en_run11=1
en_run12=1
en_run13=1
en_run14=1
en_run15=1
en_run16=1
en_run17=1
en_run18=1
en_run19=1
en_run20=1
en_run21=1
en_run22=1

# TESTS
total_tests=22

run01=01_test_regfile
run02=02_test_alu
run03=03_test_alu_shift
run04=04_test_pseudo
run05=05_test_jump
run06=06_test_branch
run07=07_test_loadstore
run08=08_test_ldstall
run09=09_test_rawhzd
run10=10_test_pipeinlock
run11=11_adder
run12=12_fibonacci
run13=13_multiplier
run14=14_adder_func
run15=15_datacopy
run16=18_bpredict_test1
run17=19_bpredict_test2
run18=20_bpredict_test3
run19=21_bpredict_test4
run20=22_test_swap
run21=23_test_recursive
run22=24_multdiv

# Auto-skip capability-gated tests whose required RTL macro isn't enabled, regardless of the
# en_run* toggle above -- no point running a test that's guaranteed to fail/misbehave on RTL
# that doesn't support it. Currently just RUN 22 (24_multdiv), which needs MULTDIV enabled.
CORE_MACROS=./src/include/pqr5_core_macros.svh
if [ "$en_run22" -eq 1 ] && ! grep -qE '^`define[[:space:]]+MULTDIV\b' "$CORE_MACROS"; then
  echo ""
  echo "| PQR5: RUN 22 ($run22) skipped -- MULTDIV is disabled in $CORE_MACROS."
  echo ""
  en_run22=0
fi

# Set Error capturing
set -e

# VALIDATION
if [ "$en_run01" -eq 0 ] && [ "$en_run02" -eq 0 ] && \
   [ "$en_run03" -eq 0 ] && [ "$en_run04" -eq 0 ] && \
   [ "$en_run05" -eq 0 ] && [ "$en_run06" -eq 0 ] && \
   [ "$en_run07" -eq 0 ] && [ "$en_run08" -eq 0 ] && \
   [ "$en_run09" -eq 0 ] && [ "$en_run10" -eq 0 ] && \
   [ "$en_run11" -eq 0 ] && [ "$en_run12" -eq 0 ] && \
   [ "$en_run13" -eq 0 ] && [ "$en_run14" -eq 0 ] && \
   [ "$en_run15" -eq 0 ] && [ "$en_run16" -eq 0 ] && \
   [ "$en_run17" -eq 0 ] && [ "$en_run18" -eq 0 ] && \
   [ "$en_run19" -eq 0 ] && [ "$en_run20" -eq 0 ] && \
   [ "$en_run21" -eq 0 ] && [ "$en_run22" -eq 0 ]; then
   echo ""
   echo "| PQR5: No tests enabled! REGRESSION RUN ABORTED..."
   echo ""
   exit 1
fi

# INITIALIZATION
echo ""
echo "| PQR5: REGRESSION RUN initiated..."
echo ""

rm -rf ./regress_run_dump
rm -rf ./dump/regress_run_dump
mkdir -v ./regress_run_dump

echo "RUN|TEST|RESULT|CPI|HitRate(J/B)|HitRate(B)" > ./regress_run_dump/regress_result.txt

# RUN ALL ENABLED TESTS
for i in $(seq -w 01 $total_tests); do
  en_var="en_run$i"
  run_var="run$i"
  if [ "${!en_var}" -eq 1 ]; then
    echo ""
    echo "| PQR5: RUN $i initiated..."
    echo ""
    run_name=${!run_var}
    [ -d ./regress_run_dump ] || mkdir ./regress_run_dump
    mkdir -p ./regress_run_dump/$run_name
    make -C ./ build_clean
    make -C ./ build ASM="$run_name.s" ISZ="$ISZ" DSZ="$DSZ"
    # make -C ./ compile
    make -C ./ sim
    echo "## RUN $i: $run_name" >> ./regress_run_dump/checker.log
    make -C ./ diff | tee -a ./regress_run_dump/checker.log
    echo "" >> ./regress_run_dump/checker.log

    # Pull CPI & branch hit rate figures out of the DBG summary block that the core dumps
    # at end of sim (./sim/vsim.log), so they can be surfaced alongside PASS/FAIL per test.
    summary_block=$(awk '/SUMMARY STARTS/{f=1} f{print} /SUMMARY ENDS/{f=0}' ./sim/vsim.log)
    cpi=$(echo "$summary_block" | grep -m1 '| CPI    = ' | sed -E 's/.*CPI    = ([^ ]+).*/\1/')
    hitrate_jb=$(echo "$summary_block" | grep '| Hit rate    = ' | sed -n 1p | sed -E 's/.*Hit rate    = ([^ ]+( %)?).*/\1/')
    hitrate_b=$(echo "$summary_block" | grep '| Hit rate    = ' | sed -n 2p | sed -E 's/.*Hit rate    = ([^ ]+( %)?).*/\1/')
    cpi=${cpi:-NA}
    hitrate_jb=${hitrate_jb:-NA}
    hitrate_b=${hitrate_b:-NA}

    grep -q '^PASS$' ./dump/test_result.txt && test_status="PASS" || test_status="FAIL"
    printf '%s|%s|%s|%s|%s|%s\n' "$i" "$run_name" "$test_status" "$cpi" "$hitrate_jb" "$hitrate_b" >> ./regress_run_dump/regress_result.txt
    cp -rf ./dump/* ./regress_run_dump/$run_name
    cp -f ./sim/*.log ./regress_run_dump/$run_name
    echo ""
    echo "| PQR5: RUN $i completed..."
    echo ""
  fi
done

# POST RUN
# Pretty-print the pipe-delimited result table into aligned columns.
column -t -s'|' ./regress_run_dump/regress_result.txt > ./regress_run_dump/regress_result.txt.tmp
mv ./regress_run_dump/regress_result.txt.tmp ./regress_run_dump/regress_result.txt
mv ./regress_run_dump ./dump/
echo ""
echo "| PQR5: REGRESSION RUN completed!!"
echo ""
