#############################################################################################################
# ╔═╦╗╔╗─────────╔╗─╔╗────╔╗
# ║╔╣╚╬╬═╦══╦╦╦═╦╣╠╗║║╔═╦═╬╬═╗
# ║╚╣║║║╬║║║║║║║║║═╣║╚╣╬║╬║║═╣ /////////////// O P E N S O U R C E
# ╚═╩╩╩╣╔╩╩╩╩═╩╩═╩╩╝╚═╩═╬╗╠╩═╝
# ─────╚╝───────────────╚═╝
#############################################################################################################
# Script           : Regression run
# Developer        : Mitu Raj, chip@chipmunklogic.com
# Vendor           : Chipmunk Logic™, https://chipmunklogic.com
#
# Description      : This script runs regression on PQR5. Build and run all ASM example programs and
#                    dump results. The test results are available in dump/regression_dump at the end of
#                    successful run. 
#
# Last modified on : Jan-2024
# Compatiblility   : Linux/Windows bash terminal
#
# Copyright        : Open-source license, see developer.txt.
#############################################################################################################
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

# VALIDATION
if [ "$en_run01" -eq 0 ] && [ "$en_run02" -eq 0 ] && \
   [ "$en_run03" -eq 0 ] && [ "$en_run04" -eq 0 ] && \
   [ "$en_run05" -eq 0 ] && [ "$en_run06" -eq 0 ] && \
   [ "$en_run07" -eq 0 ] && [ "$en_run08" -eq 0 ] && \
   [ "$en_run09" -eq 0 ] && [ "$en_run10" -eq 0 ] && \
   [ "$en_run11" -eq 0 ] && [ "$en_run12" -eq 0 ] && \
   [ "$en_run13" -eq 0 ] && [ "$en_run14" -eq 0 ]; then
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

# RUN 01
if [ "$en_run01" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 01 initiated..."
   echo ""   
   mkdir -v ./regress_run_dump/01_test_regfile
   make -C ./ full_clean
   make -C ./ build ASM="01_test_regfile.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 01: 01_test_regfile" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 01: 01_test_regfile -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 01: 01_test_regfile -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/01_test_regfile
   cp -f ./sim/*.log ./regress_run_dump/01_test_regfile
   echo ""
   echo "| PQR5: RUN 01 completed..."
   echo ""
fi

# RUN 02
if [ "$en_run02" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 02 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/02_test_alu
   make -C ./ full_clean
   make -C ./ build ASM="02_test_alu.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 02: 02_test_alu" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 02: 02_test_alu -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 02: 02_test_alu -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/02_test_alu
   cp -f ./sim/*.log ./regress_run_dump/02_test_alu
   echo ""
   echo "| PQR5: RUN 02 completed..."
   echo ""
fi

# RUN 03
if [ "$en_run03" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 03 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/03_test_alu_shift
   make -C ./ full_clean
   make -C ./ build ASM="03_test_alu_shift.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 03: 03_test_alu_shift" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 03: 03_test_alu_shift -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 03: 03_test_alu_shift -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/03_test_alu_shift
   cp -f ./sim/*.log ./regress_run_dump/03_test_alu_shift
   echo ""
   echo "| PQR5: RUN 03 completed..."
   echo ""
fi

# RUN 04
if [ "$en_run04" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 04 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/04_test_pseudo
   make -C ./ full_clean
   make -C ./ build ASM="04_test_pseudo.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 04: 04_test_pseudo" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 04: 04_test_pseudo -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 04: 04_test_pseudo -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/04_test_pseudo
   cp -f ./sim/*.log ./regress_run_dump/04_test_pseudo
   echo ""
   echo "| PQR5: RUN 04 completed..."
   echo ""
fi

# RUN 05
if [ "$en_run05" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 05 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/05_test_jump
   make -C ./ full_clean
   make -C ./ build ASM="05_test_jump.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 05: 05_test_jump" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 05: 05_test_jump -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 05: 05_test_jump -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/05_test_jump
   cp -f ./sim/*.log ./regress_run_dump/05_test_jump
   echo ""
   echo "| PQR5: RUN 05 completed..."
   echo ""
fi

# RUN 06
if [ "$en_run06" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 06 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/06_test_branch
   make -C ./ full_clean
   make -C ./ build ASM="06_test_branch.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 06: 06_test_branch" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 06: 06_test_branch -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 06: 06_test_branch -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/06_test_branch
   cp -f ./sim/*.log ./regress_run_dump/06_test_branch
   echo ""
   echo "| PQR5: RUN 06 completed..."
   echo ""
fi

# RUN 07
if [ "$en_run07" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 07 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/07_test_loadstore
   make -C ./ full_clean
   make -C ./ build ASM="07_test_loadstore.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 07: 07_test_loadstore" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 07: 07_test_loadstore -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 07: 07_test_loadstore -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/07_test_loadstore
   cp -f ./sim/*.log ./regress_run_dump/07_test_loadstore
   echo ""
   echo "| PQR5: RUN 07 completed..."
   echo ""
fi

# RUN 08
if [ "$en_run08" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 08 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/08_test_ldstall
   make -C ./ full_clean
   make -C ./ build ASM="08_test_ldstall.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 08: 08_test_ldstall" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 08: 08_test_ldstall -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 08: 08_test_ldstall -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/08_test_ldstall
   cp -f ./sim/*.log ./regress_run_dump/08_test_ldstall
   echo ""
   echo "| PQR5: RUN 08 completed..."
   echo ""
fi

# RUN 09
if [ "$en_run09" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 09 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/09_test_rawhzd
   make -C ./ full_clean
   make -C ./ build ASM="09_test_rawhzd.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 09: 09_test_rawhzd" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 09: 09_test_rawhzd -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 09: 09_test_rawhzd -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/09_test_rawhzd
   cp -f ./sim/*.log ./regress_run_dump/09_test_rawhzd
   echo ""
   echo "| PQR5: RUN 09 completed..."
   echo ""
fi

# RUN 10
if [ "$en_run10" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 10 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/10_test_pipeinlock
   make -C ./ full_clean
   make -C ./ build ASM="10_test_pipeinlock.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 10: 10_test_pipeinlock" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 10: 10_test_pipeinlock -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 10: 10_test_pipeinlock -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/10_test_pipeinlock
   cp -f ./sim/*.log ./regress_run_dump/10_test_pipeinlock
   echo ""
   echo "| PQR5: RUN 10 completed..."
   echo ""
fi

# RUN 11
if [ "$en_run11" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 11 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/10_adder
   make -C ./ full_clean
   make -C ./ build ASM="11_adder.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 11: 11_adder" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 11: 11_adder -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 11: 11_adder -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/11_adder
   cp -f ./sim/*.log ./regress_run_dump/11_adder
   echo ""
   echo "| PQR5: RUN 11 completed..."
   echo ""
fi

# RUN 12
if [ "$en_run12" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 12 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/12_fibonacci
   make -C ./ full_clean
   make -C ./ build ASM="12_fibonacci.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 12: 12_fibonacci" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 12: 12_fibonacci -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 12: 12_fibonacci -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/12_fibonacci
   cp -f ./sim/*.log ./regress_run_dump/12_fibonacci
   echo ""
   echo "| PQR5: RUN 12 completed..."
   echo ""
fi

# RUN 13
if [ "$en_run13" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 13 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/13_multiplier
   make -C ./ full_clean
   make -C ./ build ASM="13_multiplier.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 13: 13_multiplier" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 13: 13_multiplier -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 13: 13_multiplier -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/13_multiplier
   cp -f ./sim/*.log ./regress_run_dump/13_multiplier
   echo ""
   echo "| PQR5: RUN 13 completed..."
   echo ""
fi

# RUN 14
if [ "$en_run14" -eq 1 ]; then
   echo ""
   echo "| PQR5: RUN 14 initiated..."
   echo ""
   mkdir -v ./regress_run_dump
   mkdir -v ./regress_run_dump/14_adder_func
   make -C ./ full_clean
   make -C ./ build ASM="14_adder_func.s"
   make -C ./ compile
   make -C ./ sim
   echo "## RUN 14: 14_adder_func" >> ./regress_run_dump/checker.log
   make -C ./ diff >> ./regress_run_dump/checker.log
   echo "" >> ./regress_run_dump/checker.log
   grep -q '^PASS$' ./dump/test_result.txt && echo "## RUN 14: 14_adder_func -- PASS" >> ./regress_run_dump/regress_result.txt \
           || echo "## RUN 14: 14_adder_func -- FAIL" >> ./regress_run_dump/regress_result.txt
   cp -rf ./dump/* ./regress_run_dump/14_adder_func
   cp -f ./sim/*.log ./regress_run_dump/14_adder_func
   echo ""
   echo "| PQR5: RUN 14 completed..."
   echo ""
fi

# POST RUN
mv ./regress_run_dump ./dump/
echo ""
echo "| PQR5: REGRESSION RUN completed!!"
echo ""