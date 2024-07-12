# pequeno_riscv
Pequeno (meaning "_tiny_" in Spanish) aka _PQR5_ is a 5-staged pipelined in-order RISC-V CPU Core compliant with RV32I

### Overview
- RV32I ISA v2.2 + custom instructions
  
  _Assembler and Instruction Manual_: https://github.com/iammituraj/pqr5asm)
- Single-core, Single-issue, In-order execution
- Classic 5-stage RISC-V pipeline

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
# Disclaimer
This CPU core is intended for educational purposes only. 
Users are encouraged to review the accompanying license document (LICENSE) for detailed terms and conditions.

# Developer
Mitu Raj, [Chipmunk Logic](https://chipmunklogic.com), chip@chipmunklogic.com
