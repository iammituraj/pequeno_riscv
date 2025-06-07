/* Target */
OUTPUT_ARCH(riscv)
OUTPUT_FORMAT(elf32-littleriscv)

/* Entry point label (only for ELF simulation) */
ENTRY(_start)

/* Memory Layout */
MEMORY
{
    IRAM (rx)  : ORIGIN = 0x00000000, LENGTH = 32K   /* Instruction RAM */
    DRAM (rw)  : ORIGIN = 0x80000000, LENGTH = 32K   /* Data RAM: addr range that would work for Pequeno HW setup = 0x8000_0000 to 8FFF_FFFF 
                                                        cz in the HW, starting address of .data is 0x0 so 31st addr bit should be masked and unused... */
}

/* Sections layout in the memory */
SECTIONS
{
    /*. = ORIGIN(IRAM); - reqd if ALIGN(4) is used */
    /* Text section (code) placed in IRAM */
    .text : {
        *startup.o(.text)  /* First, place .text from startup.o, may not be reqd if startup.s is compiled first */
        *(.text)
        *(.text.*)
    } > IRAM
    
    /*. = ORIGIN(DRAM); - reqd if ALIGN(4) is used */
    /* Read-only data section */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
    } > DRAM

    /* Initialized data section placed in DRAM */
    .data ALIGN(4): {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > DRAM

    /* Uninitialized data section (BSS) in DRAM */
    .bss ALIGN(4): {
        _sbss = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        _ebss = .; /* Assumes next section will be ALIGN(4)... */
    } > DRAM

    /* .comment is avoided intentionally... */

    /* Stack located at the top of DRAM
       Stack decrements first and store, growing downwards
       Aligning SP initial value to 16-byte boundary as suggested by RISC-V ABI */
    _stack_top = (ORIGIN(DRAM) + LENGTH(DRAM)) & ~0xF;  
}