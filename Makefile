#################################################################################################################################
# File Name        : Makefile
# Description      : Makefile to compile pequeno_riscv_v1_0 core/subsystem and simulate in ModelSim/QuestaSim - in UNIX/LINUX.
#                    The Makefile is also compatible with terminal programs like MSYS/Gitbash in Windows...
# Developer        : Mitu Raj, chip@chipmunklogic.com at Chipmunk Logic ™, https://chipmunklogic.com
# Last Modified on : June-2024
#################################################################################################################################

# Define shell
.ONESHELL:
SHELL:=/bin/bash

# Define directories
SRC_DIR    = $(shell pwd)/src
SIM_DIR    = $(shell pwd)/sim
SYNTH_DIR  = $(shell pwd)/synth
SCRIPT_DIR = $(shell pwd)/scripts
ASM_DIR    = $(shell pwd)/assembler
DUMP_DIR   = $(shell pwd)/dump
FL_DIR     = $(shell pwd)/filelist

# Shell variables default values
GUI  = 0                      # GUI/Command line simulation
DPT  = 256                    # Depth - IRAM
DTW  = 32                     # Data width - IRAM
OFT  = 0                      # Offset addr - IRAM
ASM  =                        # Assembly program for asm2bin
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
	@echo "1.  make compile                                    -- To clean compile design"
	@echo "2.  make qcompile                                   -- To quick compile without clean"
	@echo "3.  make sim TOP=<top> GUI=0/1                      -- To simulate design"
	@echo "4.  make run_all TOP=<top> GUI=0/1                  -- To clean + compile + simulate design with FW"	
	@echo "5.  make asm2bin ASM=<filename>                     -- To run assembler and generate Hex/Bin code file"
	@echo "6.  make genram DPT=<RAM depth> OFT=<data[0] addr>  -- To generate Instruction RAM wrt Hex/Bin code file"
	@echo "7.  make build ASM=<> DPT=<> OFT=<>                 -- To perform asm2bin + genram + compile"
	@echo "8.  make build_synth                                -- To generate basic synthesis setup for Xilinx Vivado"
	@echo "9.  make synth                                      -- To perform synthesis, implementation, bitstream generation"
	@echo "10. make burn                                       -- To write the generated bitstream to the target FPGA"
	@echo "11. make clean                                      -- To clean sim + dump files"
	@echo "12. make deep_clean                                 -- To clean sim + dump + generated RAM files"
	@echo "13. make asm_clean                                  -- To clean ASM build files"
	@echo "14. make synth_clean                                -- To clean synth files"
	@echo "15. make full_clean                                 -- To clean sim + dump + generated RAM + ASM build + synth files"
	@echo "16. make regress                                    -- To run regressions and dump results"
	@echo "17. make diff                                       -- To diff simulation dumps wrt golden reference"
	@echo "18. make listasm                                    -- To display the list of example ASM programs"
	@echo "19. make sweep                                      -- To perform full_clean + clear left over regression dumps"
	@echo "NOTES:"
	@echo "1) Pay attention to all errors/warnings on build before simulating..."
	@echo "2) Default values: DPT=256, OFT=0, GUI=0; for full list refer to Makefile..."

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
	rm -rf $(DUMP_DIR)/ref
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
asm2bin: asm_clean
	@echo ""
	@echo "| MAKE_PQR5: Invoking Assembler ..."
	@echo ""	
	cp $(ASM_DIR)/example_programs/$(ASM) $(ASM_DIR)/sample.s
	python $(ASM_DIR)/pqr5asm.py $(ASM_DIR)/sample.s	
	@mkdir $(ASM_DIR)/asm_pgm_dump_ref
	@cp -f $(ASM_DIR)/example_programs/test_results/$(ASM)/*_dump.txt $(ASM_DIR)/asm_pgm_dump_ref/
	echo "The program built by the assembler is: $(ASM)" > $(ASM_DIR)/asm_pgm_info.txt

# genram
genram:
	@echo ""
	@echo "| MAKE_PQR5: Invoking GENRAM ..."
	@echo ""
	python $(SCRIPT_DIR)/pqr5genram.py $(ASM_DIR)/sample_hex.txt $(SRC_DIR)/memory/model/ram.sv iram $(DPT) $(DTW) $(OFT)
	@mv $(SRC_DIR)/memory/model/iram.sv $(SRC_DIR)/memory/iram.sv 
	@echo ""
	@echo "| MAKE_PQR5: Generating wrapper for Instruction RAM ..."
	@echo ""
	python $(SCRIPT_DIR)/pqr5genwrap.py $(SRC_DIR)/memory/model/ram_top.sv imem_top $(DPT) $(DTW)
	mv $(SRC_DIR)/memory/model/imem_top.sv $(SRC_DIR)/memory/imem_top.sv

# build
build: asm2bin genram compile 

# synth
synth: check_synth
	@echo ""
	@echo "| MAKE_PQR5: Initiating synthesis and implementation in Vivado ..."
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

# listasm
listasm:
	@echo ""
	@echo "List of Example ASM Programs"
	@echo "----------------------------"
	@ls $(ASM_DIR)/example_programs/*.s | sed -r 's/^.+\///'

# regress
regress:
	bash $(SCRIPT_DIR)/regress_run.sh

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
	rm -rf $(SRC_DIR)/memory/imem*.sv

# asm_clean
asm_clean:
	@echo "| MAKE_PQR5: Cleaning all ASM build files ..."
	@echo ""
	@rm -rf $(ASM_DIR)/sample*.*
	@rm -rf $(ASM_DIR)/asm_pgm_dump_ref
	@rm -rf $(ASM_DIR)/asm_pgm_info.txt

# synth_clean
synth_clean:
	@echo "| MAKE_PQR5: Cleaning all synthesis & implementation files ..."
	@echo ""
	@rm -rf $(SYNTH_DIR)

# full_clean
full_clean: deep_clean asm_clean synth_clean
	@echo "| MAKE_PQR5: Performing full clean ..."
	@echo ""	

# sweep
sweep: full_clean
	@rm -rf regress_run_dump
	@echo "| MAKE_PQR5: Clearing regression dumps ..."
	@echo ""