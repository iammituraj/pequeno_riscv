# pequeno_riscv
Pequeno (meaning "_tiny_" in Spanish) aka _PQR5_ is a 5-staged pipelined in-order RISC-V CPU Core compliant with RV32I ISA.

### Overview
- RV32I ISA v2.2 + custom instructions
  
  _Assembler and Instruction Manual_: https://github.com/iammituraj/pqr5asm)
  
  _FPGA demo of Pequeno running Hello world program_: https://youtu.be/GECyL9U5ZxI
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
### Feature set
| **CPU Feature Set**                        |                                           |
|--------------------------------------------|-------------------------------------------|
| **ISA**                                    | RV32I, user-level v2.2                    |
| **Instructions**                           | All 37 base instructions + 16 custom instructions |
| **Cores**                                  | 1                                         |
| **Issue**                                  | One instruction per cycle                 |
| **Pipeline depth**                         | 5                                         |
|                                            | Fetch, Decode, Execution, Memory Access, Writeback |
| **Bus architecture**                       | Harvard, separate instruction/data bus    |
| **Branch Prediction**                      | Yes, static                               |
| **Cache**                                  | Not available, but can be integrated externally |
| **OS capable**                             | No, privilege modes are not supported     |
| **Interrupt/Exceptions capable**           | No                                        |
| **Debug support**                        | Yes, limited number of signals for simulation purposes only |

### Important notes
Please go through _database_readme.txt_ for information about the organisation of the repo and how to setup the pqr5 build environment.

# Disclaimer
This CPU core is intended for educational purposes only.
Users are encouraged to review the accompanying license document (LICENSE) for detailed terms and conditions.

# Developer
Mitu Raj, [Chipmunk Logic](https://chipmunklogic.com), chip@chipmunklogic.com
