# pequeno_riscv
Pequeno aka _pqr5_ is a pipelined in-order RISC-V CPU Core compliant with RV32I

### Overview
- RV32I ISA v2.2 + custom instructions (Assembler and Instruction Manual: https://github.com/iammituraj/pqr5asm)
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
  
        chipmunklogic.com                                                                         [[[[[[[ O P E N - S O U R C E _
                                                                                                
# Developer
Mitu Raj, [Chipmunk Logic](https://chipmunklogic.com), chip@chipmunklogic.com
