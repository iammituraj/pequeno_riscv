# pequeno_riscv
Pequeno (meaning "_tiny_" in Spanish) aka _PQR5_ is a 5-staged pipelined in-order RISC-V CPU Core compliant with RV32I ISA.
The core is bare RTL, balanced for area/performance, and portable across platforms like FPGA, ASIC.

## Overview
- RV32I ISA v2.2
- Single-core, Single-issue, In-order execution
- Classic 5-stage RISC-V pipeline
- Intended for baremetal applications, not OS & interrupt capable.

                                             ____________________________
                                            / CHIPMUNK LOGIC            /\
                                           /                           / /\ 
                                          /     =================     / /
                                         /     / P e q u e n o  /   / \/
                                        /     /  RISC-V 32I    /    /\
                                       /     /================/    / /
                                      /___________________________/ /
                                      \___________________________\/
                                       \ \ \ \ \ \ \ \ \ \ \ \ \ \ \
  
        chipmunklogic.com                                                    [[[[[[[ O P E N - S O U R C E _
## Feature set
| **CPU Feature Set**                        |                                           |
|--------------------------------------------|-------------------------------------------|
| **ISA**                                    | RV32I, user-level v2.2                    |
| **Instructions**                           | All 37 base instructions                  |
| **Cores**                                  | 1                                         |
| **Issue**                                  | One instruction per cycle                 |
| **Pipeline depth**                         | 5                                         |
|                                            | Fetch, Decode, Execution, Memory Access, Writeback |
| **Execution model**                        | In-order
| **Bus architecture**                       | Harvard, separate instruction/data bus    |
| **Branch prediction**                      | Yes, static                               |
| **Cache**                                  | Not available, but can be integrated externally |
| **OS capable**                             | No, privilege modes are not supported     |
| **Interrupt/Exceptions capable**           | No                                        |

## Functional Block Diagram

![This is an alt text.](doc/misc/pequeno_block_diagram.png "Block Diagram of PQR5")

## PQR5ASM, The tailor-made Assembler
   This RV32I assembler supports all 37 base instructions + 16 pseudo instructions 
   
  _Assembler and Instruction Manual_: 
  https://github.com/iammituraj/pqr5asm


## Pequeno in Action!  
  * _FPGA demo of Pequeno running Hello world program_: 
  https://youtu.be/GECyL9U5ZxI

  * _FPGA demo of Pequeno being flashed by peqFlash through serial interface (UART) and running Blinky LED program_: https://www.youtube.com/watch?v=cEEZbzSd6v0

The validation was primarily done on Xilinx Artix-7 based FPGA boards Basys-3, CMOD-A735T

## FPGA Resource Utilization
| **Synthesis summary**                      |                                           |
|--------------------------------------------|-------------------------------------------|
| **Core version** | pqr5 v1.0.1
| **Target** | Artix-7, xc7a35tcpg236-1
| **LUTs** | 1424
| **Registers** | 562
| **Targetted clock freq** | 100 MHz

## CoreMark®
| **Performance Validation**                 |                                           |
|--------------------------------------------|-------------------------------------------|
| **CoreMark score** | 0.7 CoreMark/MHz 
| **Iterations** | 400
| **Iterations per second** | 8
| **Test clock freq** | 12 MHz
| **Test platform** | FPGA
| **Full Report** | [coremark/coremark_report_18Apr25.html](https://raw.githack.com/iammituraj/pequeno_riscv/main/coremark/coremark_report_18Apr25.html)



## Important
Please go through [readme_database.html](https://raw.githack.com/iammituraj/pequeno_riscv/main/readme_database.html) for info about this repo database and how to setup the PQR5 build environment.

# Disclaimer
This CPU core is intended for educational purposes only.
The users must review the accompanying license document (LICENSE) for detailed terms and conditions before the use.

# Developer
Mitu Raj, [Chipmunk Logic](https://chipmunklogic.com), chip@chipmunklogic.com
