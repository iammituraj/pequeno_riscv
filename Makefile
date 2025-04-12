#################################################################################################################################
##   _______   _                      __     __             _    
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/                            ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/ 
##           /_/                                    /___/              
#################################################################################################################################
#################################################################################################################################
# File Name        : Makefile
# Description      : Makefile to compile pequeno_riscv_v1_0 core/subsystem and simulate in ModelSim/QuestaSim - in UNIX/LINUX.
#                    It also supports writing bitstream to target Xilinx FPGAs, flashing program binary to target.
#                    The Makefile is compatible with terminal programs like MSYS/Gitbash in Windows...
# Developer        : Mitu Raj, chip@chipmunklogic.com at Chipmunk Logic ™, https://chipmunklogic.com
# Last Modified on : Mar-2025
#################################################################################################################################

# Define shell
.ONESHELL:
SHELL:=/bin/bash

# Python env path: user needs to modify this path...
PYTHON:=~/my_workspace/python/myenv/bin/python
#PYTHON:=python

# Define directories
SRC_DIR    = $(shell pwd)/src
SIM_DIR    = $(shell pwd)/sim
SYNTH_DIR  = $(shell pwd)/synth
SCRIPT_DIR = $(shell pwd)/scripts
ASM_DIR    = $(shell pwd)/assembler
DUMP_DIR   = $(shell pwd)/dump
FL_DIR     = $(shell pwd)/filelist
FLASH_DIR  = $(shell pwd)/peqFlash

# Shell variables default values
GUI  = 0                      # GUI/Command line simulation
DPT  = 256                    # Depth - IRAM
DTW  = 32                     # Data width - IRAM
OFT  = 0                      # Offset addr - IRAM
ASM  =                        # Assembly program for asm2bin; currently empty; but MANDATORY by recipes
PQF  =                        # peqFlash flags; currently empty
#DATE = $$(date +'%d_%m_%Y')   # Date in DD-MM-YYY

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
	@echo "HELP"
	@echo "===="
	@echo "1.  make compile                                -- To clean compile design"
	@echo "2.  make qcompile                               -- To quick compile without clean"
	@echo "3.  make sim TOP=<top> GUI=0/1                  -- To simulate design"
	@echo "4.  make run_all TOP=<top> GUI=0/1              -- To clean + compile + simulate design with FW"	
	@echo "5.  make asm2bin ASM=<assembly file>            -- To run assembler and generate Hex/Bin code file"
	@echo "6.  make genram DPT=<RAM depth> OFT=<PC_INIT>   -- To generate Instruction & Data RAMs wrt Hex/Bin code file"
	@echo "7.  make build ASM=<> DPT=<> OFT=<>             -- To perform asm2bin + genram + compile"
	@echo "8.  make build_synth                            -- To generate basic synthesis setup for Xilinx Vivado"
	@echo "9.  make synth                                  -- To perform synthesis, implementation, bitstream generation"
	@echo "10. make burn                                   -- To write the generated bitstream to the target FPGA"
	@echo "11. make flash SP=<port> BAUD=<> PQF=<flags>    -- To flash the program binary via serial port to the target"
	@echo "12. make clean                                  -- To clean sim + dump files"
	@echo "13. make deep_clean                             -- To clean sim + dump + generated RAM files"
	@echo "14. make asm_clean                              -- To clean ASM build files"
	@echo "15. make build_clean                            -- To perform deep_clean + asm_clean and clean all build files"
	@echo "16. make synth_clean                            -- To clean synth files"
	@echo "17. make full_clean                             -- To perform full clean = build_clean + synth_clean"
	@echo "18. make regress                                -- To run regressions and dump results"
	@echo "19. make diff                                   -- To diff simulation dumps wrt golden reference"
	@echo "20. make listasm                                -- To display the list of example ASM programs"
	@echo "21. make sweep                                  -- To perform full_clean + clear left over regression dumps"
	@echo "NOTES:"
	@echo "1) Pay attention to all errors/warnings on build before simulating/synthesis/bitstream burning/flashing..."
	@echo "2) Default values for optional flags: TOP=pqr5_subsystem_top, DPT=256, OFT=0, GUI=0"
	@echo "3) Flash flags (PQF) are -cleanimem, -reloc <addr>, -rebootonly"
	@echo "   More details in the doc: Programming_Pequeno_with_peqFlash.pdf"
	@echo ""

# build_sim
build_sim:
	@
	if [ ! -d $(SIM_DIR) ]; then echo "| MAKE PQR5: sim directory doesn't exist ..."; \
		echo "| MAKE_PQR5: Building sim directory ..."; \
		echo ""; \
		mkdir -pv $(SIM_DIR); \
	else \
		echo ""; \
		echo "| MAKE_PQR5: sim directory FOUND ..."; \
		echo ""; \
	fi	

# build_synth
build_synth: synth_clean
	@
	if [ ! -d $(SYNTH_DIR) ]; then echo "| MAKE PQR5: synth directory doesn't exist ..."; \
		echo "| MAKE_PQR5: Building synth directory ..."; \
		echo ""; \
		mkdir -pv $(SYNTH_DIR); \
	else \
		echo ""; \
		echo "| MAKE_PQR5: synth directory FOUND ..."; \
		echo ""; \
	fi
	@cp $(SCRIPT_DIR)/synth_setup/write_bitstream.tcl $(SYNTH_DIR)/
	@cp $(SCRIPT_DIR)/synth_setup/run_synth.tcl $(SYNTH_DIR)/
	@mkdir -pv $(SYNTH_DIR)/rtl_src
	@cp -r $(SRC_DIR)/* $(SYNTH_DIR)/rtl_src/
	@rm -rf $(SYNTH_DIR)/rtl_src/memory/model
	@echo ""
	@echo "| MAKE_PQR5: Synthesis setup ready, please make appropriate changes to tcl/src/xdc files in ./synth folder before synthesising..."

# build_dump
build_dump:
	@echo ""
	@echo "| MAKE_PQR5: Building dump directory ..."
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
	if [ -d $(SIM_DIR) ]; then echo "| MAKE PQR5: sim library found ..."; fi
	if [ ! -d $(SIM_DIR) ]; then echo "| MAKE PQR5: sim library NOT FOUND! ... please compile first. OR run make help"; exit 1; fi

# check_synth
check_synth:
	@
	#$(shell test $(SYNTH_DIR) || echo "| MAKE_PQR5: synth directory not found - please build_synth first. OR run make help")
	if [ -d $(SYNTH_DIR) ]; then echo "| MAKE PQR5: synth directory found ..."; fi
	if [ ! -d $(SYNTH_DIR) ]; then echo "| MAKE PQR5: synth directory NOT FOUND! ... please build_synth first. OR run make help"; exit 1; fi

# check_flash
check_flash:
	@if [ -z "$(SP)" ]; then \
		echo "| MAKE_PQR5: Flasher launch aborted because SP is empty!!"; \
		exit 1; \
	fi
	@if [ -z "$(BAUD)" ]; then \
		echo "| MAKE_PQR5: Flasher launch aborted because BAUD is empty!!"; \
		exit 1; \
	fi

# compile
compile: clean build_sim
	@echo ""
	@echo "| MAKE_PQR5: Compiling design ..."
	@echo ""
	vlog -logfile $(SIM_DIR)/vlog.log $(VLOG_FLAGS) -work $(SIM_DIR)/work -f "$(FL_DIR)/all_design_src_files.txt"

# qcompile
qcompile: build_sim
	@echo ""
	@echo "| MAKE_PQR5: Compiling design ..."
	@echo ""
	vlog -logfile $(SIM_DIR)/vlog.log $(VLOG_FLAGS) -work $(SIM_DIR)/work -f "$(FL_DIR)/all_design_src_files.txt"

# sim
sim: check_sim build_dump	
	@echo ""
	@echo "| MAKE_PQR5: Removing dump files, if any ..."
	@echo ""
	@rm -rf $(DUMP_DIR)/*
	@echo ""
	@if [ -e $(SCRIPT_DIR)/run.do ]; then \
        cp $(SCRIPT_DIR)/run.do ./; \
        echo "| MAKE_PQR5: DO file found ... copying ..."; \
	else \
        echo "| MAKE_PQR5: No DO file found ..."; \
	fi
	@echo "| MAKE_PQR5: Simulating design ..."
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
	@echo "| MAKE_PQR5: Invoking Assembler ..."
	@echo ""	
	@cp $(ASM_DIR)/example_programs/$(ASM) $(ASM_DIR)/sample.s
	$(PYTHON) $(ASM_DIR)/pqr5asm.py -file=$(ASM_DIR)/sample.s -pcrel	
	@mkdir $(ASM_DIR)/asm_pgm_dump_ref
	@cp -f $(ASM_DIR)/example_programs/test_results/$(ASM)/*_dump.txt $(ASM_DIR)/asm_pgm_dump_ref/	
	echo "The program built by the assembler is: $(ASM)" > $(ASM_DIR)/asm_pgm_info.txt
	$(PYTHON) $(SCRIPT_DIR)/decode_baseaddr.py $(ASM_DIR)/sample_imem.bin $(ASM_DIR)/sample_imem_baseaddr.txt
	$(PYTHON) $(SCRIPT_DIR)/decode_baseaddr.py $(ASM_DIR)/sample_dmem.bin $(ASM_DIR)/sample_dmem_baseaddr.txt

# genram
genram:
	@echo ""
	@echo "| MAKE PQR5: Analyzing binary files for Instruction & Data base addresses..."
	@imem_baseaddr=$$(cat $(ASM_DIR)/sample_imem_baseaddr.txt); \
    echo "| MAKE PQR5: Parsed program base address         = $$imem_baseaddr"; \
    #echo "| MAKE PQR5: User requested program base address = $(OFT)"; \
	echo "| MAKE PQR5: User requested program base address = 0x$$(printf '%08X' $$(($(OFT))))";\
	dmem_baseaddr=$$(cat $(ASM_DIR)/sample_dmem_baseaddr.txt); \
    echo "| MAKE PQR5: Parsed data base address            = $$dmem_baseaddr"
	@echo ""
	@echo "| MAKE_PQR5: Invoking GENRAM to generate Instruction RAM with program binary initialized..."
	@echo ""
	$(PYTHON) $(SCRIPT_DIR)/pqr5genram.py $(ASM_DIR)/sample_imem_hex.txt $(SRC_DIR)/memory/model/ram.sv iram $(DPT) $(DTW) $(OFT) 0
	@mv $(SRC_DIR)/memory/model/iram.sv $(SRC_DIR)/memory/iram.sv 
	@echo ""
	@echo ""
	@echo "| MAKE_PQR5: Invoking GENRAM to generate Data RAM with data binary initialized..."
	@echo ""
	$(PYTHON) $(SCRIPT_DIR)/pqr5genram.py $(ASM_DIR)/sample_dmem_hex.txt $(SRC_DIR)/memory/model/dram_model.sv dram $(DPT) $(DTW) $$dmem_baseaddr 1
	@mv $(SRC_DIR)/memory/model/dram_b*.sv $(SRC_DIR)/memory/
	@mv $(SRC_DIR)/memory/model/dram_4x8.sv $(SRC_DIR)/memory/dram_4x8.sv
	@echo ""
	@echo "| MAKE_PQR5: Generating wrapper for Instruction RAM..."
	@echo ""
	$(PYTHON) $(SCRIPT_DIR)/pqr5genwrap.py $(SRC_DIR)/memory/model/ram_top.sv imem_top $(DPT) $(DTW) 0
	@mv $(SRC_DIR)/memory/model/imem_top.sv $(SRC_DIR)/memory/imem_top.sv
	@echo ""
	@echo ""
	@echo "| MAKE_PQR5: Generating wrapper for Data RAM..."
	@echo ""
	$(PYTHON) $(SCRIPT_DIR)/pqr5genwrap.py $(SRC_DIR)/memory/model/dmem_top_model.sv dmem_top $(DPT) $(DTW) 1	
	@mv $(SRC_DIR)/memory/model/dmem_top.sv $(SRC_DIR)/memory/dmem_top.sv

# build
build: asm2bin genram compile 

# synth
synth: check_synth
	@echo ""
	@echo "| MAKE_PQR5: Initiating Synthesis, Implementation, and Bitfile generation in Vivado ..."
	@echo ""	
	@master_dir=$$(pwd); \
	cd $(SYNTH_DIR); \
	vivado -mode batch -source run_synth.tcl; \
	cd "$$master_dir"

# burn
burn: check_synth
	@echo ""
	@echo "| MAKE_PQR5: Programming the FPGA with bitfile ..."
	@echo ""	
	@master_dir=$$(pwd); \
	cd $(SYNTH_DIR); \
	vivado -mode batch -source write_bitstream.tcl; \
	cd "$$master_dir"

# flash
flash: check_flash
	@echo ""
	@echo "| MAKE_PQR5: Invoking Flasher ..."
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
	bash $(SCRIPT_DIR)/regress_run.sh
	@echo "|| Regression result ||"
	@cat $(DUMP_DIR)/regress_run_dump/regress_result.txt

# clean
clean:
	@echo ""
	@echo "| MAKE_PQR5: Cleaning all simulation and dump files ..."
	@echo ""
	@rm -rf $(SIM_DIR)
	@rm -rf $(DUMP_DIR)
	@rm -f *.do
	@rm -rf transcript
	@rm -rf *.vstf
	@rm -rf *.wlf
	@rm -rf *.vcd
	@rm -rf *_dump.txt
	@rm -rf *.log

# deep_clean
deep_clean: clean	
	@echo "| MAKE_PQR5: Cleaning all generated RAM files ..."
	@echo ""
	@rm -rf $(SRC_DIR)/memory/iram*.sv
	@rm -rf $(SRC_DIR)/memory/imem*.sv
	@rm -rf $(SRC_DIR)/memory/dram*.sv
	@rm -rf $(SRC_DIR)/memory/dmem*.sv

# asm_clean
asm_clean:
	@echo "| MAKE_PQR5: Cleaning all ASM build files ..."
	@echo ""
	@rm -rf $(ASM_DIR)/sample*.*
	@rm -rf $(ASM_DIR)/asm_pgm_dump_ref
	@rm -rf $(ASM_DIR)/asm_pgm_info.txt

# build_clean
build_clean: deep_clean asm_clean
	@echo "| MAKE_PQR5: Performing full build clean ..."
	@echo ""

# synth_clean
synth_clean:
	@echo "| MAKE_PQR5: Cleaning all synthesis & implementation files ..."
	@echo ""
	@rm -rf $(SYNTH_DIR)

# full_clean
full_clean: deep_clean asm_clean synth_clean
	@echo "| MAKE_PQR5: Performing full clean ..."
	@echo ""	

# sweep - in case failed regression leaves junk
sweep: full_clean
	@rm -rf regress_run_dump
	@echo "| MAKE_PQR5: Clearing regression dumps ..."
	@echo ""
