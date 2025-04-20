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
# Description      : Makefile to generate CoreMark® CPU Benchmark binary for a system with specs:
#                    ISA : RV32I 
#                    ABI : 32-bit integer operations without HW mul/div instructions
#                    FW  : Baremetal, without OS
#                    
#                    GCC libs are used to transform mul/div to SW routines
#
# Last Modified on : Apr-2025
# Compatibility    : Linux/Unix, Windows require terminal programs like MSYS/Gitbash
#                    RISC-V GCC 14.2.0 tested (newlib)
# Notes            : Items marked as [CONFIGURE] may need to be configured before invoking this Makefile.
# 
#################################################################################################################################

# [CONFIGURE] Toolchain
GCC_DIR    = /opt/riscv
GCC_PREFIX = riscv64-unknown-elf
GCC_VER    = 14.2.0

# [CONFIGURE] CoreMark specific definitions
ITERATIONS     = 400        # Iterations of CoreMark
CLOCKS_PER_SEC = 12000000   # Core clock speed
FLAGS_STR      = ""

# Target architecture and tools
ARCH    = rv32i
ABI     = ilp32
CC      = $(GCC_PREFIX)-gcc
AS      = $(GCC_PREFIX)-as
LD      = $(GCC_PREFIX)-ld
EF      = $(GCC_PREFIX)
OBJDUMP = $(GCC_PREFIX)-objdump
OBJCOPY = $(GCC_PREFIX)-objcopy
NM      = $(GCC_PREFIX)-nm

# Linker script
LINKER_SCRIPT = linker.ld

# Directories
PORT_DIR = barebones

# Output files
PRJNAME  = coremark_pqr5
TARGET   = $(PRJNAME).elf
TEXT_BIN = $(PRJNAME)_iram.bin
DATA_BIN = $(PRJNAME)_dram.bin

# Compiler & Assembler flags
CFLAGS = \
    -g \
    -O3 \
	-march=$(ARCH) \
	-mabi=$(ABI) \
	-ffreestanding \
	-fno-stack-protector \
	-fno-zero-initialized-in-bss \
	-mstrict-align \
	-fno-builtin

# Assembler flags
ASFLAGS = \
	-march=$(ARCH) \
	-mabi=$(ABI)

# Linker flags
LDFLAGS = \
    -T $(LINKER_SCRIPT) \
    -static \
    -nostartfiles \
    -Xlinker \
    -Map=$(PRJNAME)_linker.map

# Extra flags for CC
XCFLAGS = \
	-g \
	-DITERATIONS=$(ITERATIONS) \
	-DCLOCKS_PER_SEC=$(CLOCKS_PER_SEC) \
	-I ./ \
	-I $(PORT_DIR) \
	-DFLAGS_STR=\"$(FLAGS_STR)\" \

# C Libraries for compilation/linking
# These are reqd. to link mul/div/mod SW routines of GCC used by ilp32 ABI
LIBC =
LIBGCC = \
    -L$(GCC_DIR)/lib/gcc/$(GCC_PREFIX)/$(GCC_VER)/$(ARCH)/$(ABI) \
	-lgcc \
	-L$(GCC_DIR)/$(GCC_PREFIX)/lib/$(ARCH)/$(ABI) \

# Core Source files
CORE_SRC_FILES  = \
	core_list_join.c \
	core_main.c \
	core_matrix.c \
	core_state.c \
	core_util.c 

# Ported Source files
PORT_SRC_FILES = \
	$(PORT_DIR)/core_portme.c \
	$(PORT_DIR)/ee_printf.c

# Start-up code source file
STARTUP = startup.s

# Source, object code, linker files
CSRCS  = $(CORE_SRC_FILES) $(PORT_SRC_FILES)
ASRCS  = $(STARTUP) 
OBJS   = $(ASRCS:.s=.o) $(CSRCS:.c=.o) 

# Message before compilation
.PHONY: msgc
msgc:
	@echo ""
	@echo "| COREMARK_PQR5_MAKE: Compiling..."

# Default rule: build everything
all: $(TARGET) dump binary sections symbols

# Minimal build
build: $(TARGET) binary sections

# Compile C & Assembly files to object files
%.o: %.c
	$(CC) $(CFLAGS) $(XCFLAGS) -c $< -o $@

%.o: %.s
	$(AS) $(ASFLAGS) -c $< -o $@

# Link everything and generate ELF
$(TARGET): msgc $(OBJS) $(LINKER_SCRIPT)
	@echo ""
	@echo "| COREMARK_PQR5_MAKE: Linking..."
	$(CC) $(LIBGCC) $(LIBC) $(LDFLAGS) $(OBJS) -o $(TARGET)
	$(EF)-readelf -S $(TARGET)
	@echo ""
	@echo "ELF size:"
	@$(EF)-size $(TARGET)

# Dump entire disassembly of ELF
dump: $(TARGET)
	@echo ""
	@echo "| COREMARK_PQR5_MAKE: Dumping the disassembly of the ELF..."
	$(OBJDUMP) -D $(TARGET) > $(PRJNAME).dump

# Dump only .text section
textdump: $(TARGET)
	@echo ""
	@echo "Dumping the disassembly of the ELF (.text only)..."
	$(OBJDUMP) -d $(TARGET) > $(PRJNAME).text.dump
	@cat $(PRJNAME).text.dump

# Show section memory layout
sections: $(TARGET)
	@echo ""
	@echo "## SECTION MEMORY LAYOUT ##"
	$(OBJDUMP) -h $(TARGET) > $(PRJNAME).sections
	@cat $(PRJNAME).sections

# Show symbol table
symbols: $(TARGET)
	@echo ""
	@echo "## SYMBOL TABLE ##"
	@$(NM) -n $(TARGET) > $(PRJNAME).symbols
	@cat $(PRJNAME).symbols

# Extract text and data sections separately and dump binary files
binary: $(TARGET)
	@echo ""
	@echo "| COREMARK_PQR5_MAKE: Dumping the binaries..."
	$(OBJCOPY) -O binary --only-section=.text $(TARGET) $(TEXT_BIN)
	$(OBJCOPY) -O binary --only-section=.data --only-section=.rodata $(TARGET) $(DATA_BIN)

# Clean output files
.PHONY: clean
clean:
	@echo ""
	@echo "| COREMARK_PQR5_MAKE: Cleaning all generated files!"
	rm -f $(OBJS) $(TARGET) $(TEXT_BIN) $(DATA_BIN)
	rm -f $(PRJNAME)_linker.map
	rm -f $(PRJNAME).dump
	rm -f $(PRJNAME).text.dump
	rm -f $(PRJNAME).sections
	rm -f $(PRJNAME).symbols