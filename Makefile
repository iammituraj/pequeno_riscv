#################################################################################################################################
##   _______   _                      __     __             _    
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/                            ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/ 
##           /_/                                    /___/                                              chipmunklogic.com
#################################################################################################################################
#################################################################################################################################
# File Name        : Makefile
# Author           : Mitu Raj, chip@chipmunklogic.com at Chipmunk Logic ™, https://chipmunklogic.com
#
# Description      : Makefile to build the Pequeno subsystem with Instruction & Data memories.
#                    With this Makefile, you can:
#                    - Compile assembly programs and generate the pgm/data binaries with pqr5asm.
#                    - Generate IRAM and DRAM with the generated firmware binary.
#                    - Compile and simulate the core with firmware (HW-SW co-RTL-sim), and dump results. 
#                    - On-board testing: 
#                         - Synthesis, implementation for Xilinx FPGAs.
#                         - Generate bitstream & burn to the FPGA. 
#                         - Flash the binary to the target (Pequeno on FPGA) using peqFlash.
#                    - Run CoreMark® CPU Benchmark and generate the binary for on-board validation.
#                      The CoreMark binary typically requires >16kB IRAM and >4kB DRAM.
#
# Last Modified on : Apr-2025
# Compatibility    : Linux/Unix, Windows require terminal programs like MSYS/Gitbash
#                    ModelSim/QuestaSim for RTL simulation
#                    Pequeno SW toolchain for ASM compiling, flashing Pequeno
#                    Xilinx FPGA + Vivado for FPGA implementation
#                    RISC-V GNU GCC 14.2.0 tested
# Notes            : Items marked as [CONFIGURE] must be configured before invoking this Makefile.
#
#################################################################################################################################

# Define shell
.ONESHELL:
SHELL:=/bin/bash

# [CONFIGURE] Python env path
PYTHON:=~/my_workspace/python/myenv/bin/python
#PYTHON:=python

# [CONFIGURE] CoreMark

# Define directories
SRC_DIR    = $(shell pwd)/src
SIM_DIR    = $(shell pwd)/sim
SYNTH_DIR  = $(shell pwd)/synth
SCRIPT_DIR = $(shell pwd)/scripts
ASM_DIR    = $(shell pwd)/assembler
COREMK_DIR = $(shell pwd)/coremark
DUMP_DIR   = $(shell pwd)/dump
FL_DIR     = $(shell pwd)/filelist
FLASH_DIR  = $(shell pwd)/peqFlash

##### Make variables default values  ####
# GUI/Command line simulation
GUI  = 0
# IRAM/DRAM size in bytes
ISZ  = 1024
DSZ  = 1024
# Data width in RAMs
DTW  = 32
# Base address in IRAM                
OFT  = 0
# Assembly pgm passed to asm2bin; empty but MANDATORY input to recipes
ASM  =
# peqFlash flags
PQF  =
# pqr5asm flags; -pcrel to generate relocatable (text) binary by default
ASMF = -pcrel
#DATE = $$(date +'%d_%m_%Y') # Date in DD-MM-YYY

# Derived shell variables
IDPT = $(shell expr \( $(ISZ) + 3 \) / 4)# Depth of IRAM
DDPT = $(shell expr \( $(DSZ) + 3 \) / 4)# Depth of DRAM
IDPT_2n = $(shell n=$(IDPT); i=0; while [ $$((1 << $$i)) -lt $$n ]; do i=$$((i+1)); done; echo $$((1 << $$i)))
DDPT_2n = $(shell n=$(DDPT); i=0; while [ $$((1 << $$i)) -lt $$n ]; do i=$$((i+1)); done; echo $$((1 << $$i)))
ISZ_2n = $(shell expr $(IDPT_2n) \* 4)# Size of IRAM 
DSZ_2n = $(shell expr $(DDPT_2n) \* 4)# Size of DRAM

# Bash/GUI Mode Selection
ifneq ($(GUI), 1)
BASH_FLAG = -c
else
BASH_FLAG =
endif

# Questasim flags
TOP        = pqr5_subsystem_top
VLOG_FLAGS =
VSIM_FLAGS = $(BASH_FLAG) -voptargs="+acc -O0" -logfile "$(SIM_DIR)/vsim.log" -do "do "run.do""

#--------------------------------------------------------------------------------------------------------------------------------
# Targets and Recipes
#--------------------------------------------------------------------------------------------------------------------------------
# help
help:
	@echo ""
	@echo "Pequeno Subsystem Builder Makefile - Chipmunk Logic™ "
	@echo ""
	@echo "HELP"
	@echo "===="
	@echo "1.  make compile                                                -- To clean compile the PQR5 subsystem RTL database"
	@echo "2.  make qcompile                                               -- To compile without clean"
	@echo "3.  make sim GUI=0/1                                            -- To simulate the PQR5 subsystem"
	@echo "4.  make run_all GUI=0/1                                        -- To clean + compile + simulate"	
	@echo "5.  make asm2bin ASM=<assembly file> ASMF=<>                    -- To run the assembler and generate the binaries"
	@echo "6.  make coremark ISZ=<IRAM size> DSZ=<DRAM size>               -- To build CoreMark® CPU Benchmark"
	@echo "7.  make genram ISZ=<IRAM size> DSZ=<DRAM size> OFT=<PC_INIT>   -- To generate IRAM & DRAM with binaries initialized"
	@echo "8.  make build ASM=<> ISZ=<> DSZ=<> OFT=<>                      -- To build the PQR5 subsystem with FW: asm2bin + genram + compile"
	@echo "9.  make build_synth                                            -- To generate a basic synthesis setup for Xilinx Vivado"
	@echo "10. make synth                                                  -- To perform synthesis, implementation, and generate bitfile"
	@echo "11. make burn                                                   -- To write the generated bitfile to the target FPGA"
	@echo "12. make flash SP=<port> BAUD=<baudrate> PQF=<>                 -- To flash the program binary via serial port to the target"
	@echo "13. make clean                                                  -- To clean sim + dump files"
	@echo "14. make deep_clean                                             -- To clean sim + dump + generated RAM files"
	@echo "15. make asm_clean                                              -- To clean ASM build files"
	@echo "16. make cmk_clean                                              -- To clean CoreMark build files"
	@echo "17. make build_clean                                            -- To perform deep_clean + asm_clean + cmk_clean"
	@echo "18. make synth_clean                                            -- To clean synth files"
	@echo "19. make full_clean                                             -- To perform full clean = build_clean + synth_clean"
	@echo "20. make regress                                                -- To run regressions and dump the results"
	@echo "21. make diff                                                   -- To diff simulation dumps wrt golden reference"
	@echo "22. make listasm                                                -- To display the list of example ASM programs"
	@echo "23. make sweep                                                  -- To perform full_clean + clear left over regression dumps"
	@echo ""
	@echo "NOTES:"
	@echo "1) Pay attention to all errors/warnings of build before proceeding ahead..."
	@echo "2) Default values for optional flags: ISZ/DSZ=1024, OFT=0, GUI=0"
	@echo "   OFT, PC_INIT, program (text section) base address are related, refer to: database_readme.txt"
	@echo "3) ASM flags (ASMF) available are: -pcrel. It is added by default for relocatable program binary."
	@echo "   Override ASMF=<empty> to create non-relocatable program binary"
	@echo "   For more details, refer to: pqr5asm_imanual.pdf"
	@echo "4) Flash flags (PQF) available are -cleanimem, -reloc <addr>, -rebootonly"
	@echo "   For more details, refer to: Programming_Pequeno_with_peqFlash.pdf"
	@echo "5) [Units] Baudrate = bps, IRAM/DRAM size = bytes"
	@echo ""

# build_sim
build_sim:
	@
	if [ ! -d $(SIM_DIR) ]; then echo "| MAKE PQR5: sim directory doesn't exist..."; \
		echo "| MAKE_PQR5: Building sim directory..."; \
		echo ""; \
		mkdir -pv $(SIM_DIR); \
	else \
		echo ""; \
		echo "| MAKE_PQR5: sim directory FOUND..."; \
		echo ""; \
	fi	

# build_synth
build_synth: synth_clean
	@
	if [ ! -d $(SYNTH_DIR) ]; then echo "| MAKE PQR5: synth directory doesn't exist..."; \
		echo "| MAKE_PQR5: Building synth directory..."; \
		echo ""; \
		mkdir -pv $(SYNTH_DIR); \
	else \
		echo ""; \
		echo "| MAKE_PQR5: synth directory FOUND..."; \
		echo ""; \
	fi
	@cp $(SCRIPT_DIR)/synth_setup/write_bitstream.tcl $(SYNTH_DIR)/
	@cp $(SCRIPT_DIR)/synth_setup/run_synth.tcl $(SYNTH_DIR)/
	@mkdir -pv $(SYNTH_DIR)/rtl_src
	@mkdir -pv $(SYNTH_DIR)/xdc
	@cp -r $(SRC_DIR)/* $(SYNTH_DIR)/rtl_src/
	@rm -rf $(SYNTH_DIR)/rtl_src/memory/model
	@echo ""
	@echo "| MAKE_PQR5: Synthesis setup ready, please make appropriate changes to tcl/src/xdc files in ./synth folder before synthesising..."

# build_dump
build_dump:
	@echo ""
	@echo "| MAKE_PQR5: Building dump directory..."
	@echo ""
	@mkdir -pv $(DUMP_DIR)

# check_asm
check_asm:
	@if [ -z "$(ASM)" ]; then \
		echo "| MAKE_PQR5: Assembler launch aborted because ASM is empty!!"; \
		exit 1; \
	fi

# check_sim
check_sim:
	@
	#$(shell test $(SIM_DIR) || echo "| MAKE_PQR5: sim directory not found - please compile first. OR run make help")
	if [ -d $(SIM_DIR) ]; then echo "| MAKE PQR5: sim library found..."; fi
	if [ ! -d $(SIM_DIR) ]; then echo "| MAKE PQR5: sim library NOT FOUND!... please compile first. OR run make help"; exit 1; fi

# check_synth
check_synth:
	@
	#$(shell test $(SYNTH_DIR) || echo "| MAKE_PQR5: synth directory not found - please build_synth first. OR run make help")
	if [ -d $(SYNTH_DIR) ]; then echo "| MAKE PQR5: synth directory found..."; fi
	if [ ! -d $(SYNTH_DIR) ]; then echo "| MAKE PQR5: synth directory NOT FOUND!... please build_synth first. OR run make help"; exit 1; fi

# check_flash
check_flash:
	@if [ -z "$(SP)" ]; then \
		echo "| MAKE_PQR5: **CRITICAL ERROR** Flasher launch aborted because SP is empty!!"; \
		exit 1; \
	fi
	@if [ -z "$(BAUD)" ]; then \
		echo "| MAKE_PQR5: **CRITICAL ERROR** Flasher launch aborted because BAUD is empty!!"; \
		exit 1; \
	fi

# compile
compile: clean build_sim
	@echo ""
	@echo "| MAKE_PQR5: Compiling design..."
	@echo ""
	@set -e
	vlog -logfile $(SIM_DIR)/vlog.log $(VLOG_FLAGS) -work $(SIM_DIR)/work -f "$(FL_DIR)/all_design_src_files.txt"

# qcompile
qcompile: build_sim
	@echo ""
	@echo "| MAKE_PQR5: Compiling design..."
	@echo ""
	@set -e
	vlog -logfile $(SIM_DIR)/vlog.log $(VLOG_FLAGS) -work $(SIM_DIR)/work -f "$(FL_DIR)/all_design_src_files.txt"

# sim
sim: check_sim build_dump	
	@echo ""
	@echo "| MAKE_PQR5: Removing dump files, if any..."
	@echo ""
	@rm -rf $(DUMP_DIR)/*
	@echo ""
	@if [ -e $(SCRIPT_DIR)/run.do ]; then \
		cp $(SCRIPT_DIR)/run.do ./; \
		echo "| MAKE_PQR5: DO file found... copying..."; \
	else \
		echo "| MAKE_PQR5: No DO file found..."; \
	fi
	@echo "| MAKE_PQR5: Simulating design..."
	@echo ""
	vsim $(VSIM_FLAGS) $(SIM_DIR)/work.$(TOP) -t ns
	@rm -f $(shell pwd)/*.do
	@mv -f $(shell pwd)/*.vcd $(DUMP_DIR) 2>/dev/null; true
	@mv -f $(shell pwd)/*_dump.txt $(DUMP_DIR) 2>/dev/null; true

# check_diff
check_diff:
	@	
	if [ ! -d $(ASM_DIR)/asm_pgm_dump_ref/ ]; then echo "| MAKE PQR5: ref dump NOT FOUND! please recheck ASM source..."; exit 1; fi
	if [ ! -d $(DUMP_DIR) ]; then echo " MAKE PQR5: dump NOT FOUND! please run simulation first..."; exit 1; fi

# diff
diff: check_diff
	@echo ""
	@echo "| MAKE_PQR5: Invoking diff tool to verify the dumps with golden reference dumps after simulation..."	
	@rm -rf $(DUMP_DIR)/ref
	@mkdir -v $(DUMP_DIR)/ref
	@cp -f $(ASM_DIR)/asm_pgm_dump_ref/*_dump.txt $(DUMP_DIR)/ref/
	diff $(DUMP_DIR)/pqr5_dmem_dump.txt $(DUMP_DIR)/ref/pqr5_dmem_dump.txt > $(DUMP_DIR)/diff_dmem_dump.txt
	diff $(DUMP_DIR)/pqr5_imem_dump.txt $(DUMP_DIR)/ref/pqr5_imem_dump.txt > $(DUMP_DIR)/diff_imem_dump.txt
	diff $(DUMP_DIR)/pqr5_regfile_dump.txt $(DUMP_DIR)/ref/pqr5_regfile_dump.txt > $(DUMP_DIR)/diff_regfile_dump.txt
	[ -s $(DUMP_DIR)/diff_dmem_dump.txt ] || [ -s $(DUMP_DIR)/diff_imem_dump.txt ] || [ -s $(DUMP_DIR)/diff_regfile_dump.txt ]\
	     && (echo "| MAKE_PQR5: OOPS... ERRORS FOUND!! All differences have been logged into dump/diff_*.txt..."; echo "FAIL" > $(DUMP_DIR)/test_result.txt)\
	     || (echo "| MAKE_PQR5: SUCCESS!! No differences found!"; echo "PASS" > $(DUMP_DIR)/test_result.txt ; rm -f $(DUMP_DIR)/diff_*.txt)
			
# run_all
run_all: compile sim

# asm2bin
asm2bin: check_asm asm_clean
	@echo ""
	@echo "| MAKE_PQR5: Invoking pqr5asm Assembler..."
	@echo ""	
	@set -e
	@cp $(ASM_DIR)/example_programs/$(ASM) $(ASM_DIR)/sample.s
	$(PYTHON) $(ASM_DIR)/pqr5asm.py -file=$(ASM_DIR)/sample.s $(ASMF)	
	@mkdir $(ASM_DIR)/asm_pgm_dump_ref
	@cp -f $(ASM_DIR)/example_programs/test_results/$(ASM)/*_dump.txt $(ASM_DIR)/asm_pgm_dump_ref/	
	@echo "The program built by the assembler is: $(ASM)" > $(ASM_DIR)/asm_pgm_info.txt
	$(PYTHON) $(SCRIPT_DIR)/decode_baseaddr.py $(ASM_DIR)/sample_imem.bin $(ASM_DIR)/sample_imem_baseaddr.txt
	$(PYTHON) $(SCRIPT_DIR)/decode_baseaddr.py $(ASM_DIR)/sample_dmem.bin $(ASM_DIR)/sample_dmem_baseaddr.txt

# cmk2bin
cmk2bin: asm_clean cmk_clean
	@echo ""
	@echo "CoreMark® CPU Benchmark Build"
	@echo "-----------------------------"
	@echo "This will compile CoreMark and build the Pequeno subsystem with the CoreMark binaries initialized on RAMs."
	@echo ""
	@echo "PRE-REQUISITES to build CoreMark for Pequeno subsystem"
	@echo "1. Configure the test parameters and environment in CoreMark Makefile."
	@echo "   . ITERATIONS     = <no. of CoreMark iterations to be performed>"
	@echo "   . CLOCKS_PER_SEC = <Core clock speed>"
	@echo "2. Configure CoreMark linker.ld." 
	@echo "   . IRAM ORIGIN = 0x00000000"
	@echo "   . IRAM LENGTH = <IRAM size>"
	@echo "   . DRAM ORIGIN = 0x80000000"
	@echo "   . DRAM LENGTH = <DRAM size>"
	@echo "3. Configure the PQR5 subsystem macros:"
	@echo "   . COREMARK      = Enabled"
	@echo "   . DBGUART       = Enabled"
	@echo "   . DBGUART_BRATE = <Targetted baudrate>"
	@echo "   . FCLK          = CLOCKS_PER_SEC"
	@echo "   . IRAM_SIZE     = ISZ = $(ISZ) = IRAM LENGTH"
	@echo "   . DRAM_SIZE     = DSZ = $(DSZ) = DRAM LENGTH"	
	@echo "   . SUBSYS_DBG    = Enabled if RTL simulation required"
	@echo "4. Configure CPU Core macros:"
	@echo "   . PC_INIT           = 0x00000000"
	@echo "   . SIMEXIT_INSTR_END = Enabled if you require RTL simulation with exit on END"
	@echo ""
	@read -p "Press ENTER to continue... ELSE ctrl+C to break" dummy
	@echo ""
	@echo "| MAKE_PQR5: Building CoreMark CPU for the system..."
	@echo ""
	@set -e
	@master_dir=$$(pwd); \
	cd $(COREMK_DIR); \
	make build ; \
	cd "$$master_dir"
	@echo ""
	$(PYTHON) $(SCRIPT_DIR)/bin2pqr5bin.py -binfile $(COREMK_DIR)/coremark_pqr5_iram.bin -outfile $(ASM_DIR)/sample_imem.bin -baseaddr 0x0
	$(PYTHON) $(SCRIPT_DIR)/bin2pqr5bin.py -binfile $(COREMK_DIR)/coremark_pqr5_dram.bin -outfile $(ASM_DIR)/sample_dmem.bin -baseaddr 0x0
	@echo ""
	bash $(SCRIPT_DIR)/bin2hextxt.sh $(COREMK_DIR)/coremark_pqr5_iram.bin $(ASM_DIR)/sample_imem_hex.txt
	bash $(SCRIPT_DIR)/bin2hextxt.sh $(COREMK_DIR)/coremark_pqr5_dram.bin $(ASM_DIR)/sample_dmem_hex.txt
	@echo "The program built by the Make is: CoreMark " > $(ASM_DIR)/asm_pgm_info.txt
	@echo "0x00000000" > $(ASM_DIR)/sample_imem_baseaddr.txt
	@echo "0x00000000" > $(ASM_DIR)/sample_dmem_baseaddr.txt
	@echo ""
	@echo "| MAKE_PQR5: Finished building the CoreMark !!!"
	@echo ""

# genram
genram:
	@set -e
	@echo ""
	@echo "| MAKE PQR5: Analyzing binary files for Instruction & Data base addresses..."
	@imem_baseaddr=$$(cat $(ASM_DIR)/sample_imem_baseaddr.txt); \
	echo "| MAKE PQR5: Parsed program base address         = $$imem_baseaddr"; \
	echo "| MAKE PQR5: User requested program base address = 0x$$(printf '%08X' $$(($(OFT))))";\
	dmem_baseaddr=$$(cat $(ASM_DIR)/sample_dmem_baseaddr.txt); \
	echo "| MAKE PQR5: Parsed data base address            = $$dmem_baseaddr"
	@echo ""
	@echo "| MAKE_PQR5: Invoking GENRAM to generate Instruction RAM with program binary initialized..."
	@echo ""
	$(PYTHON) $(SCRIPT_DIR)/pqr5genram.py $(ASM_DIR)/sample_imem_hex.txt $(SRC_DIR)/memory/model/ram.sv iram $(IDPT) $(DTW) $(OFT) 0
	@mv $(SRC_DIR)/memory/model/iram.sv $(SRC_DIR)/memory/iram.sv 
	@echo ""
	@echo ""
	@echo "| MAKE_PQR5: Invoking GENRAM to generate Data RAM with data binary initialized..."
	@echo ""
	$(PYTHON) $(SCRIPT_DIR)/pqr5genram.py $(ASM_DIR)/sample_dmem_hex.txt $(SRC_DIR)/memory/model/dram_model.sv dram $(DDPT) $(DTW) $$dmem_baseaddr 1
	@mv $(SRC_DIR)/memory/model/dram_b*.sv $(SRC_DIR)/memory/
	@mv $(SRC_DIR)/memory/model/dram_4x8.sv $(SRC_DIR)/memory/dram_4x8.sv
	@echo ""
	@echo "| MAKE_PQR5: Generating wrapper for Instruction RAM..."
	@echo ""
	$(PYTHON) $(SCRIPT_DIR)/pqr5genwrap.py $(SRC_DIR)/memory/model/iram_top_model.sv imem_top $(IDPT) $(DTW) 0
	@mv $(SRC_DIR)/memory/model/imem_top.sv $(SRC_DIR)/memory/imem_top.sv
	@echo ""
	@echo ""
	@echo "| MAKE_PQR5: Generating wrapper for Data RAM..."
	@echo ""
	$(PYTHON) $(SCRIPT_DIR)/pqr5genwrap.py $(SRC_DIR)/memory/model/dmem_top_model.sv dmem_top $(DDPT) $(DTW) 1	
	@mv $(SRC_DIR)/memory/model/dmem_top.sv $(SRC_DIR)/memory/dmem_top.sv
	@echo ""
	@echo "| MAKE_PQR5: Generation of RAMs successfully completed."
	@echo ". IRAM size = $(ISZ_2n) Bytes"
	@echo ". DRAM size = $(DSZ_2n) Bytes"

# build
build: asm2bin genram compile 

# coremark
coremark: cmk2bin genram compile
	@echo ""
	@echo "| MAKE_PQR5: Built the system with CoreMark® successfully!!"
	@echo ""
	@echo "  SUMMARY"
	@echo "  -------"
	@echo ". Compiled the CoreMark and generated the binary for PQR5."
	@echo ". Generated IRAM and DRAM with the CoreMark binary initialized."
	@echo "  IRAM size = $(ISZ_2n) Bytes"
	@echo "  DRAM size = $(DSZ_2n) Bytes"
	@echo "  Program binary base address = 0x00000000 @IRAM"
	@echo "  Data binary base address    = 0x00000000 @DRAM"
	@echo ". Compiled the PQR5 subsystem successfully."
	@echo ""

# synth
synth: check_synth
	@echo ""
	@echo "| MAKE_PQR5: Initiating Synthesis, Implementation, and Bitfile generation in Vivado..."
	@echo ""
	@set -e	
	@master_dir=$$(pwd); \
	cd $(SYNTH_DIR); \
	vivado -mode batch -source run_synth.tcl; \
	cd "$$master_dir"

# burn
burn: check_synth
	@echo ""
	@echo "| MAKE_PQR5: Programming the FPGA with bitfile..."
	@echo ""	
	@master_dir=$$(pwd); \
	cd $(SYNTH_DIR); \
	vivado -mode batch -source write_bitstream.tcl; \
	cd "$$master_dir"

# flash
flash: check_flash
	@echo ""
	@echo "| MAKE_PQR5: Invoking peqFlash Flasher..."
	@echo ""
	@$(PYTHON) $(FLASH_DIR)/peqflash.py -serport $(SP) -baud $(BAUD) -imembin "$(ASM_DIR)/sample_imem.bin" -dmembin "$(ASM_DIR)/sample_dmem.bin" $(PQF)

# listasm
listasm:
	@echo ""
	@echo "List of Example ASM Programs"
	@echo "----------------------------"
	@ls $(ASM_DIR)/example_programs/*.s | sed -r 's/^.+\///'

# regress
regress:
	@echo ""
	@echo "Running Regressions in the CPU"
	@echo "==============================="
	@echo "Running regressions validate the functionality of the PQR5 subsystem built."
	@echo "This will run all example programs in the CPU and dump the results in dump/regress_run_dump"
	@echo ""
	@echo "Following configuration should be set before running regression."
	@echo ""
	@echo "PQR5 subsystem macros:"
	@echo "   . IRAM_SIZE  = 1024"
	@echo "   . DRAM_SIZE  = 1024"
	@echo "   . SUBSYS_DBG = Enable"
	@echo "   . MEM_DBG    = Enable"
	@echo "   . SIMLIMIT   = Enable"
	@echo "CPU core macros:"
	@echo "   . PC_INIT           = 32'h00000000"
	@echo "   . REGFILE_DUMP      = 1"
	@echo "   . SIMEXIT_INSTR_END = Enable"
	@echo ""
	@read -p "Press ENTER to continue... ELSE ctrl+C to break" dummy
	@echo ""
	@echo "| MAKE_PQR5: Initiating regression runs..."
	@echo ""
	@set -e
	bash $(SCRIPT_DIR)/regress_run.sh
	@echo "|| Regression result ||"
	@cat $(DUMP_DIR)/regress_run_dump/regress_result.txt

# clean
clean:
	@echo ""
	@echo "| MAKE_PQR5: Cleaning all simulation and dump files..."
	@echo ""
	@rm -rf $(SIM_DIR)
	@rm -rf $(DUMP_DIR)
	@rm -f *.do
	@rm -f transcript
	@rm -rf *.vstf
	@rm -rf *.wlf
	@rm -rf *.vcd
	@rm -rf *_dump.txt
	@rm -rf *.log

# deep_clean
deep_clean: clean	
	@echo "| MAKE_PQR5: Cleaning all generated RAM files..."
	@echo ""
	@rm -rf $(SRC_DIR)/memory/iram*.sv
	@rm -rf $(SRC_DIR)/memory/imem*.sv
	@rm -rf $(SRC_DIR)/memory/dram*.sv
	@rm -rf $(SRC_DIR)/memory/dmem*.sv

# asm_clean
asm_clean:
	@echo "| MAKE_PQR5: Cleaning all ASM build files..."
	@echo ""
	@rm -rf $(ASM_DIR)/sample*.*
	@rm -rf $(ASM_DIR)/asm_pgm_dump_ref
	@rm -rf $(ASM_DIR)/asm_pgm_info.txt

# cmk_clean
cmk_clean:
	@echo "| MAKE_PQR5: Cleaning all CoreMark build files..."
	@echo ""
	@master_dir=$$(pwd); \
	cd $(COREMK_DIR); \
	make clean ; \
	cd "$$master_dir"

# build_clean
build_clean: deep_clean asm_clean cmk_clean
	@echo "| MAKE_PQR5: Full build clean finished..."
	@echo ""

# synth_clean
synth_clean:
	@echo "| MAKE_PQR5: Cleaning all synthesis & implementation files..."
	@echo ""
	@rm -rf $(SYNTH_DIR)

# full_clean
full_clean: build_clean synth_clean
	@echo "| MAKE_PQR5: Full clean finished..."
	@echo ""	

# sweep - in case failed regression leaves junk
sweep: full_clean
	@rm -rf regress_run_dump
	@echo "| MAKE_PQR5: Clearing regression dumps if any..."
	@echo ""
