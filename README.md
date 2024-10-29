# pequeno_riscv
Pequeno (meaning "_tiny_" in Spanish) aka _PQR5_ is a 5-staged pipelined in-order RISC-V CPU Core compliant with RV32I ISA.

### Overview
- RV32I ISA v2.2 + custom instructions
  
  _Assembler and Instruction Manual_: https://github.com/iammituraj/pqr5asm)
  
  _FPGA demo of Pequeno running Hello world program_: https://youtu.be/GECyL9U5ZxI
- Single-core, Single-issue, In-order execution
- Classic 5-stage RISC-V pipeline
- Intended for baremetal applications, not OS capable.

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

### Important notes
Please go through _database_readme.txt_ for information about the organisation of the repo and how to setup the pqr5 build environment.

# Disclaimer
This CPU core is intended for educational purposes only.
Users are encouraged to review the accompanying license document (LICENSE) for detailed terms and conditions.

# Developer
Mitu Raj, [Chipmunk Logic](https://chipmunklogic.com), chip@chipmunklogic.com
