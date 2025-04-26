//     %%%%%%%%%%%%      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//  %%%%%%%%%%%%%%%%%%                      
// %%%%%%%%%%%%%%%%%%%% %%                
//    %% %%%%%%%%%%%%%%%%%%                
//        % %%%%%%%%%%%%%%%                 
//           %%%%%%%%%%%%%%                 ////    O P E N - S O U R C E     ////////////////////////////////////////////////////////////
//           %%%%%%%%%%%%%      %%          _________________________________////
//           %%%%%%%%%%%       %%%%                ________    _                             __      __                _     
//          %%%%%%%%%%        %%%%%%              / ____/ /_  (_)___  ____ ___  __  ______  / /__   / /   ____  ____ _(_)____ TM 
//         %%%%%%%    %%%%%%%%%%%%*%%%           / /   / __ \/ / __ \/ __ `__ \/ / / / __ \/ //_/  / /   / __ \/ __ `/ / ___/
//        %%%%% %%%%%%%%%%%%%%%%%%%%%%%         / /___/ / / / / /_/ / / / / / / /_/ / / / / ,<    / /___/ /_/ / /_/ / / /__  
//       %%%%*%%%%%%%%%%%%%  %%%%%%%%%          \____/_/ /_/_/ .___/_/ /_/ /_/\__,_/_/ /_/_/|_|  /_____/\____/\__, /_/\___/
//       %%%%%%%%%%%%%%%%%%%    %%%%%%%%%                   /_/                                              /____/  
//       %%%%%%%%%%%%%%%%                                                             ___________________________________________________               
//       %%%%%%%%%%%%%%                    //////////////////////////////////////////////       c h i p m u n k l o g i c . c o m    //// 
//         %%%%%%%%%                       
//           %%%%%%%%%%%%%%%%               
//    
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% 
//----%% File Name        : pqr5_core_top.sv
//----%% Module Name      : pqr5 Core Top                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : pequeno_riscv_v1_0 aka PQR5 is 5-stage pipelined RISC-V CPU which supports RV32I ISA User Level v2.2.
//----%%                    PQR5 is a 32-bit single-issue, single-core CPU which incorporates strictly in-order pipeline.
//----%%                    The core is bare RTL, balanced for area/performance, and portable across platforms like FPGA, ASIC.
//----%%                         ____________________________
//----%%                        / CHIPMUNK LOGIC            /\
//----%%                       /                           / /\
//----%%                      /     =================     / /
//----%%                     /     / P e q u e n o  /   / \/
//----%%                    /     /  RISC-V 32I    /    /\
//----%%                   /     /================/    / /
//----%%                  /___________________________/ /
//----%%                  \___________________________\/
//----%%                   \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ 
//----%%
//----%%                    [For full specs, refer to pequeno_riscv_v1_0 User Guide/IP Documentation]
//----%%
//----%%                    This is the top module for pqr5 core, this module integrates:
//----%%                    # Fetch Unit (FU)           -- [Stage 1] : Fetches and issues instructions (single issue)
//----%%                    # Decode Unit (DU)          -- [Stage 2] : Decodes instructions
//----%%                    # Register File (RF)        --           : General purpose registers   
//----%%                    # Execution Unit (EXU)      -- [Stage 3] : Executes instructions and forwards results
//----%%                    # Memory Access Unit (MAU)  -- [Stage 4] : Manages data memory access
//----%%                    # Write Back Unit (WBU)     -- [Stage 5] : Writes back results to Register File
//----%%
//----%%                                                                         [Data Memory/Cache]                 
//----%%                                                                            ^
//----%%                                                                            |
//----%%                                                                            v
//----%%                          Stage-1          Stage-2        Stage-3         Stage-4         Stage-5                 
//----%%                        +----------+    +----------+    +----------+    +----------+    +----------+
//----%%                        |  Fetch   |===>|  Decode  |===>| Execute  |===>|  Access  |===>| Writeback|    
//----%%                        +__________+    +__________+    +__________+    +__________+    +__________+
//----%%                            ^              ^         +---------------+                     |
//----%%                            |              |_________| Register File |_____________________v 
//----%%                            v                        +---------------+                               
//----%%                    [Instruction Memory/Cache]                                                                       
//----%%
//----%%                    Configurability
//----%%                    ===============
//----%%                    -- On-reset PC value ie., reset vector
//----%%                    -- Debug interfaces/modules for simulation can be generated using DBG macro.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Apr-2025
//----%% Notes            : -
//----%%
//----%% User Guide       : [TBD]
//----%%             
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                              P Q R 5   C O R E   T O P                                          
//###################################################################################################################################################
// Header files
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module pqr5_core_top #(
   // Configurable parameters
   parameter PC_INIT = `PC_INIT  // Init PC on reset
)
(   
   // Clock and Reset  
   input  logic             clk                 ,  // Clock
   input  logic             aresetn             ,  // Asynchronous Reset; active-low

   `ifdef TEST_PORTS
   // Test Ports  
   output logic [3:0]       o_x31_tst           ,  // x31 bits: {x31[24], x31[16], x31[8], x31[0]}
   output logic             o_boot_flag         ,  // Boot flag: flags that the core is out of reset and booted
   `endif
   
   // External Stall Interface
   input  logic             i_ext_stall         ,  // External stall to CPU

   // Instruction Memory/Cache Interface (IMEMIF)
   output logic [`XLEN-1:0] o_imem_pc           ,  // PC to IMEMIF
   output logic             o_imem_pc_valid     ,  // PC valid
   input  logic             i_imem_stall        ,  // Stall signal from IMEMIF 

   input  logic [`XLEN-1:0] i_imem_pc           ,  // PC from IMEMIF; corresponding to the packet
   input  logic [`ILEN-1:0] i_imem_pkt          ,  // Instruction packet from IMEMIF
   input  logic             i_imem_pkt_valid    ,  // Instruction packet valid
   output logic             o_imem_stall        ,  // Stall signal to IMEMIF
   output logic             o_imem_flush        ,  // Flush signal to IMEMIF

   // Data Memory/Cache Interface (DMEMIF)
   output logic             o_dmem_wen          ,  // Write enable to DMEMIF
   output logic [`XLEN-1:0] o_dmem_addr         ,  // Address to DMEMIF
   output logic [1:0]       o_dmem_size         ,  // Access size to DMEMIF
   output logic [`XLEN-1:0] o_dmem_wdata        ,  // Write-data to DMEMIF
   output logic             o_dmem_req          ,  // Request to DMEMIF
   input  logic             i_dmem_stall        ,  // Stall signal from DMEMIF
   output logic             o_dmem_flush        ,  // Flush signal to DMEMIF
   input  logic [`XLEN-1:0] i_dmem_rdata        ,  // Read-data from DMEMIF
   input  logic             i_dmem_ack          ,  // Acknowledge from DMEMIF
   output logic             o_dmem_stall           // Stall signal to DMEMIF
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// FU-DU Interface
logic [`XLEN-1:0] fu_du_pc          ;  // PC from FU to DU
logic [`ILEN-1:0] fu_du_instr       ;  // Instruction from FU to DU
logic             fu_du_bubble      ;  // Bubble from FU to DU
logic             fu_du_br_taken    ;  // Branch taken status from FU to DU
logic             du_fu_stall       ;  // Stall signal from DU to FU

// DU-RF Interface
logic             du_rf_rden        ;  // Read-enable from DU to RF
logic [4:0]       du_rf_rs0         ;  // rs0 from DU to RF
logic [4:0]       du_rf_rs1         ;  // rs1 from DU to RF

// Operand Forward Control Interface
logic [`XLEN-1:0] opfwd_exu_op0     ;  // Operand-0 forwarded to EXU
logic [`XLEN-1:0] opfwd_exu_op1     ;  // Operand-1 forwarded to EXU

// EXU-BU signals
logic             exu_bu_flush      ;  // Flush signal from EXU-BU
logic [`XLEN-1:0] exu_bu_pc         ;  // Branch PC from EXU-BU
logic             exu_bu_br_taken   ;  // Branch taken status to EXU-BU

// RF-EXU Interface
logic [`XLEN-1:0] rf_exu_op0        ;  // Operand-0 from RF to EXU
logic [`XLEN-1:0] rf_exu_op1        ;  // Operand-1 from RF to EXU

// DU-EXU Interface
logic [`XLEN-1:0] du_exu_pc         ;  // PC from DU to EXU   
logic [`ILEN-1:0] du_exu_instr      ;  // Instruction from DU to EXU
logic             du_exu_bubble     ;  // Bubble from DU to EXU
logic             exu_du_stall      ;  // Stall signal from EXU to DU

logic [6:0]       du_exu_opcode     ;  // Opcode from DU to EXU
logic [3:0]       du_exu_alu_opcode ;  // ALU opcode from DU to EXU
logic [4:0]       du_exu_rs0        ;  // rs0 from DU to EXU
logic [4:0]       du_exu_rs1        ;  // rs1 from DU to EXU
logic [4:0]       du_exu_rdt        ;  // rdt from DU to EXU
logic             du_exu_rdt_not_x0 ;  // rdt neq x0
logic [2:0]       du_exu_funct3     ;  // funct3 from DU to EXU

logic             du_exu_is_r_type  ;  // R-type instruction flag from DU to EXU
logic             du_exu_is_i_type  ;  // I-type instruction flag from DU to EXU
logic             du_exu_is_s_type  ;  // S-type instruction flag from DU to EXU
logic             du_exu_is_b_type  ;  // B-type instruction flag from DU to EXU
logic             du_exu_is_u_type  ;  // U-type instruction flag from DU to EXU
logic             du_exu_is_j_type  ;  // J-type instruction flag from DU to EXU
logic             du_exu_is_risb    ;  // RISB flag from DU to EXU
logic             du_exu_is_riuj    ;  // RIUJ flag from DU to EXU
logic             du_exu_is_jalr    ;  // JALR flag from DU to EXU
logic             du_exu_is_load    ;  // Load flag from DU to EXU
logic             du_exu_is_lui     ;  // LUI flag from DU to EXU
logic [11:0]      du_exu_i_type_imm ;  // I-type immediate from DU to EXU
logic [11:0]      du_exu_s_type_imm ;  // S-type immediate from DU to EXU
logic [11:0]      du_exu_b_type_imm ;  // B-type immediate from DU to EXU
logic [19:0]      du_exu_u_type_imm ;  // U-type immediate from DU to EXU
logic [19:0]      du_exu_j_type_imm ;  // J-type immediate from DU to EXU

// EXU-MACCU Interface
logic [`XLEN-1:0] exu_maccu_pc         ;  // PC from EXU to MACCU    
logic [`ILEN-1:0] exu_maccu_instr      ;  // Instruction from EXU to MACCU
logic             exu_maccu_is_riuj    ;  // RIUJ flag from EXU to MACCU
logic             exu_maccu_bubble     ;  // Bubble from EXU to MACCU
logic             maccu_exu_stall      ;  // Stall signal from MACCU to EXU

logic [4:0]       exu_maccu_rdt_addr   ;  // Writeback register address from EXU to MACCU 
logic [`XLEN-1:0] exu_maccu_rdt_data   ;  // Writeback register data from EXU to MACCU 
logic             exu_maccu_rdt_not_x0 ;  // rdt neq x0
logic             exu_maccu_is_macc_op ;  // Memory access operation flag from EXU to MACCU
logic             exu_maccu_cmd        ;  // Memory access command from EXU to MACCU
logic [`XLEN-1:0] exu_maccu_addr       ;  // Memory access address from EXU to MACCU 
logic [1:0]       exu_maccu_size       ;  // Memory access size from EXU to MACCU
logic [`XLEN-1:0] exu_maccu_data       ;  // Memory access data (for Store) from EXU to MACCU 

// MACCU-WBU Interface  
logic [`XLEN-1:0] maccu_wbu_pc         ;  // PC from MACCU to WBU   
logic [`ILEN-1:0] maccu_wbu_instr      ;  // Instruction from MACCU to WBU
logic             maccu_wbu_is_riuj    ;  // RIUJ flag from MACCU to WBU
logic             maccu_wbu_bubble     ;  // Bubble from MACCU to WBU
logic             wbu_maccu_stall      ;  // Stall signal from WBU to MACCU  
logic [4:0]       maccu_wbu_rdt_addr   ;  // rdt address from MACCU to WBU
logic [`XLEN-1:0] maccu_wbu_rdt_data   ;  // rdt data from MACCU to WBU
logic             maccu_wbu_rdt_not_x0 ;  // rdt neq x0
logic             maccu_wbu_is_macc    ;  // Memory access flag from MACCU to WBU
logic             maccu_wbu_is_load    ;  // Load operation flag from MACCU to WBU
logic             maccu_wbu_is_dwback  ;  // Direct writeback operation flag from MACCU to WBU
logic [`XLEN-1:0] maccu_wbu_macc_addr  ;  // Memory access address from MACCU to WBU
logic [`XLEN-1:0] maccu_result         ;  // Memory access result to be sent to Operand Forward block
logic [`XLEN-1:0] dmem_load_data       ;  // Load data from memory access

// WBU-RF Interface
logic             wbu_rf_wren      ;  // Write Enable from WBU to RF  
logic [4:0]       wbu_rf_rdt_addr  ;  // rdt address from WBU to RF
logic [`XLEN-1:0] wbu_rf_rdt_data  ;  // rdt data from WBU to RF

// WBU Interface
logic [`XLEN-1:0] wbu_pc_out           ;  // PC from WBU
logic [`ILEN-1:0] wbu_instr_out        ;  // Instruction from WBU
logic             wbu_is_riuj_out      ;  // RIUJ flag from WBU
logic             wbu_bubble_out       ;  // Bubble from WBU
logic [4:0]       wbu_rdt_addr_out     ;  // rdt address from WBU
logic [`XLEN-1:0] wbu_rdt_data_out     ;  // rdt data from WBU
logic             wbu_rdt_not_x0_out   ;  // rdt neq x0
//logic             wbu_stall_in         ;  // Stall to WBU

// Debug signals
`ifdef DBG
logic [2:0]       fu_dbg    ;  // Debug signal from FU  : {branch_taken, is_op_branch, is_op_jal}
logic [9:0]       du_dbg    ;  // Debug signal from DU  : {(opcode == OP_LUI), (opcode == OP_JALR), (opcode == OP_LOAD), is_op_alui, instr_type_rg} 
logic [4:0]       exu_dbg   ;  // Debug signal from EXU : {is_pipe_inlock, bu_branch_taken, lsu_bubble, alu_bubble, bu_bubble}
logic [4:0]       wbu_dbg   ;  // Debug signal from WBU : {is_usig_macc, is_dmem_acc_load, is_dir_writeback, pipe_stall, dmem_acc_stall}
logic [`XLEN-1:0] regf [32] ;  // Debug signal from REGF: Register File
`endif

// Test signals
`ifdef TEST_PORTS
logic [`XLEN-1:0] x31_tst   ;  // x31
logic boot_flag_rg          ;  // Boot flag
`endif

//===================================================================================================================================================
// Instances of submodules
//===================================================================================================================================================
// Fetch Unit (FU)
fetch_unit #(
   .PC_INIT (PC_INIT)   
)  inst_fetch_unit (
   .clk              (clk)     ,
   .aresetn          (aresetn) ,

   `ifdef DBG
   .o_fu_dbg         (fu_dbg)  ,
   `endif
    
   .o_imem_pc        (o_imem_pc)        ,
   .o_imem_pc_valid  (o_imem_pc_valid)  ,
   .i_imem_stall     (i_imem_stall)     ,

   .i_imem_pc        (i_imem_pc)        ,
   .i_imem_pkt       (i_imem_pkt)       ,
   .i_imem_pkt_valid (i_imem_pkt_valid) ,
   .o_imem_stall     (o_imem_stall)     ,
   .o_imem_flush     (o_imem_flush)     ,
   
   .o_du_pc          (fu_du_pc)       ,
   .o_du_instr       (fu_du_instr)    ,
   .o_du_bubble      (fu_du_bubble)   ,
   .o_du_br_taken    (fu_du_br_taken) ,
   .i_du_stall       (du_fu_stall)    ,

   .i_exu_bu_flush   (exu_bu_flush)   ,
   .i_exu_bu_pc      (exu_bu_pc)
);

// Decode Unit (DU)
decode_unit #(
   .PC_INIT (PC_INIT)   
)  inst_decode_unit (
   .clk               (clk)     ,     
   .aresetn           (aresetn) ,

   `ifdef DBG
   .o_du_dbg          (du_dbg)  ,    
   `endif

   .i_fu_pc           (fu_du_pc)        ,      
   .i_fu_instr        (fu_du_instr)     ,
   .i_fu_bubble       (fu_du_bubble)    ,
   .i_fu_br_taken     (fu_du_br_taken)  ,
   .o_fu_stall        (du_fu_stall)     ,
   
   .o_rf_rden         (du_rf_rden) ,      
   .o_rf_rs0          (du_rf_rs0)  ,      
   .o_rf_rs1          (du_rf_rs1)  ,      
   
   .i_exu_bu_flush    (exu_bu_flush)    ,
   .i_exu_bu_pc       (exu_bu_pc)       ,
   .o_exu_bu_br_taken (exu_bu_br_taken) ,

   .o_exu_pc          (du_exu_pc)     ,  
   .o_exu_instr       (du_exu_instr)  ,  
   .o_exu_bubble      (du_exu_bubble) ,  
   .i_exu_stall       (exu_du_stall)  ,
   
   .o_exu_opcode      (du_exu_opcode)     , 
   .o_exu_alu_opcode  (du_exu_alu_opcode) ,
   .o_exu_rs0         (du_exu_rs0)        ,
   .o_exu_rs1         (du_exu_rs1)        ,
   .o_exu_rdt         (du_exu_rdt)        , 
   .o_exu_rdt_not_x0  (du_exu_rdt_not_x0) ,
   .o_exu_funct3      (du_exu_funct3)     , 
   
   .o_exu_is_r_type   (du_exu_is_r_type)  ,
   .o_exu_is_i_type   (du_exu_is_i_type)  ,
   .o_exu_is_s_type   (du_exu_is_s_type)  ,
   .o_exu_is_b_type   (du_exu_is_b_type)  ,
   .o_exu_is_u_type   (du_exu_is_u_type)  ,
   .o_exu_is_j_type   (du_exu_is_j_type)  ,
   .o_exu_is_risb     (du_exu_is_risb)    ,
   .o_exu_is_riuj     (du_exu_is_riuj)    ,
   .o_exu_is_jalr     (du_exu_is_jalr)    ,
   .o_exu_is_load     (du_exu_is_load)    ,
   .o_exu_is_lui      (du_exu_is_lui)     ,
   .o_exu_i_type_imm  (du_exu_i_type_imm) ,
   .o_exu_s_type_imm  (du_exu_s_type_imm) ,
   .o_exu_b_type_imm  (du_exu_b_type_imm) ,
   .o_exu_u_type_imm  (du_exu_u_type_imm) ,
   .o_exu_j_type_imm  (du_exu_j_type_imm)  
);

// Register File (RF)
regfile inst_regfile (
   .clk        (clk)             ,  
   .aresetn    (aresetn)         , 
   `ifdef DBG
   .o_regf_dbg (regf)            ,
   `endif
   `ifdef TEST_PORTS
   .o_x31_tst  (x31_tst)         ,
   `endif
   .i_rden     (du_rf_rden)      ,
   .i_rs0_addr (du_rf_rs0)       ,  
   .o_rs0_data (rf_exu_op0)      ,  
   .i_rs1_addr (du_rf_rs1)       ,  
   .o_rs1_data (rf_exu_op1)      ,  
   .i_wren     (wbu_rf_wren)     ,
   .i_rdt_addr (wbu_rf_rdt_addr) , 
   .i_rdt_data (wbu_rf_rdt_data)
);

// Operand Forward Control
opfwd_control inst_opfwd_control (
   .i_rf_op0            (rf_exu_op0)           ,   
   .i_rf_op1            (rf_exu_op1)           ,

   .i_du_rs0            (du_exu_rs0)           ,
   .i_du_rs1            (du_exu_rs1)           , 
   .i_du_instr_risb     (du_exu_is_risb)       ,
   .i_du_instr_valid    (~du_exu_bubble)       ,

   .i_exu_result        (exu_maccu_rdt_data)   ,  
   .i_exu_rdt           (exu_maccu_rdt_addr)   ,  
   .i_exu_rdt_not_x0    (exu_maccu_rdt_not_x0) ,
   .i_exu_instr_riuj    (exu_maccu_is_riuj)    ,  
   .i_exu_instr_valid   (~exu_maccu_bubble)    ,

   .i_maccu_result      (maccu_result)         ,
   .i_maccu_rdt         (maccu_wbu_rdt_addr)   ,
   .i_maccu_rdt_not_x0  (maccu_wbu_rdt_not_x0) ,
   .i_maccu_instr_riuj  (maccu_wbu_is_riuj)    ,
   .i_maccu_instr_valid (~maccu_wbu_bubble)    ,  

   .i_wbu_result        (wbu_rdt_data_out)     ,  
   .i_wbu_rdt           (wbu_rdt_addr_out)     ,  
   .i_wbu_rdt_not_x0    (wbu_rdt_not_x0_out)   ,
   .i_wbu_instr_riuj    (wbu_is_riuj_out)      ,  
   .i_wbu_instr_valid   (~wbu_bubble_out)      ,

   .o_fwd_op0           (opfwd_exu_op0)        , 
   .o_fwd_op1           (opfwd_exu_op1) 
);

// If Load access@MACCU, forward load data from DMEM access, else forward register writeback data
//**CHECKME**// This logic can be moved inside opfwd block or MACCU block?
assign maccu_result      = (maccu_wbu_is_load)? dmem_load_data : maccu_wbu_rdt_data ;  

// Execution Unit (EXU)
execution_unit #(
   .PC_INIT (PC_INIT)
)  inst_execution_unit (
   .clk                (clk)     ,          
   .aresetn            (aresetn) ,

   `ifdef DBG
   .o_exu_dbg          (exu_dbg) ,    
   `endif 

   .i_op0              (opfwd_exu_op0)   ,
   .i_op1              (opfwd_exu_op1)   ,

   .o_exu_bu_flush     (exu_bu_flush)    ,   
   .o_exu_bu_pc        (exu_bu_pc)       ,  
   .i_exu_bu_br_taken  (exu_bu_br_taken) ,

   .i_du_pc            (du_exu_pc)       ,
   .i_du_instr         (du_exu_instr)    ,
   .i_du_bubble        (du_exu_bubble)   ,
   .o_du_stall         (exu_du_stall)    ,

   .i_du_opcode        (du_exu_opcode)     ,
   .i_du_alu_opcode    (du_exu_alu_opcode) ,
   .i_du_rs0           (du_exu_rs0)        ,
   .i_du_rs1           (du_exu_rs1)        ,
   .i_du_rdt           (du_exu_rdt)        ,
   .i_du_rdt_not_x0    (du_exu_rdt_not_x0) ,
   .i_du_funct3        (du_exu_funct3)     ,

   .i_du_is_r_type     (du_exu_is_r_type)  ,
   .i_du_is_i_type     (du_exu_is_i_type)  ,
   .i_du_is_s_type     (du_exu_is_s_type)  ,
   .i_du_is_b_type     (du_exu_is_b_type)  ,
   .i_du_is_u_type     (du_exu_is_u_type)  ,
   .i_du_is_j_type     (du_exu_is_j_type)  ,
   .i_du_is_risb       (du_exu_is_risb)    ,
   .i_du_is_riuj       (du_exu_is_riuj)    ,
   .i_du_is_jalr       (du_exu_is_jalr)    ,
   .i_du_is_load       (du_exu_is_load)    ,
   .i_du_is_lui        (du_exu_is_lui)     ,
   .i_du_i_type_imm    (du_exu_i_type_imm) ,
   .i_du_s_type_imm    (du_exu_s_type_imm) ,
   .i_du_b_type_imm    (du_exu_b_type_imm) ,
   .i_du_u_type_imm    (du_exu_u_type_imm) ,
   .i_du_j_type_imm    (du_exu_j_type_imm) ,  

   .o_maccu_pc         (exu_maccu_pc)         ,
   .o_maccu_instr      (exu_maccu_instr)      ,
   .o_maccu_is_riuj    (exu_maccu_is_riuj)    ,
   .o_maccu_bubble     (exu_maccu_bubble)     ,
   .i_maccu_stall      (maccu_exu_stall)      ,

   .o_maccu_rdt_addr   (exu_maccu_rdt_addr)   ,
   .o_maccu_rdt_data   (exu_maccu_rdt_data)   ,
   .o_maccu_rdt_not_x0 (exu_maccu_rdt_not_x0) ,
   .o_maccu_is_macc_op (exu_maccu_is_macc_op) , 
   .o_maccu_macc_cmd   (exu_maccu_cmd)        ,
   .o_maccu_macc_addr  (exu_maccu_addr)       ,
   .o_maccu_macc_size  (exu_maccu_size)       ,
   .o_maccu_macc_data  (exu_maccu_data)
);

// Memory Access Unit (MACCU)
memory_access_unit #(
   .PC_INIT(PC_INIT)
)  inst_memory_access_unit (   
   .clk              (clk)     ,
   .aresetn          (aresetn) ,

   .i_exu_pc         (exu_maccu_pc)         ,
   .i_exu_instr      (exu_maccu_instr)      ,
   .i_exu_is_riuj    (exu_maccu_is_riuj)    ,
   .i_exu_bubble     (exu_maccu_bubble)     ,
   .o_exu_stall      (maccu_exu_stall)      ,

   .i_exu_rdt_addr   (exu_maccu_rdt_addr)   ,
   .i_exu_rdt_data   (exu_maccu_rdt_data)   ,
   .i_exu_rdt_not_x0 (exu_maccu_rdt_not_x0) ,
   .i_exu_is_macc_op (exu_maccu_is_macc_op) ,
   .i_exu_macc_cmd   (exu_maccu_cmd)        ,
   .i_exu_macc_addr  (exu_maccu_addr)       ,
   .i_exu_macc_size  (exu_maccu_size)       ,
   .i_exu_macc_data  (exu_maccu_data)       ,

   .o_dmem_wen       (o_dmem_wen)   ,
   .o_dmem_addr      (o_dmem_addr)  ,
   .o_dmem_size      (o_dmem_size)  ,
   .o_dmem_wdata     (o_dmem_wdata) ,
   .o_dmem_req       (o_dmem_req)   ,
   .i_dmem_stall     (i_dmem_stall) ,
   .o_dmem_flush     (o_dmem_flush) ,

   .o_wbu_pc         (maccu_wbu_pc)         ,
   .o_wbu_instr      (maccu_wbu_instr)      ,
   .o_wbu_is_riuj    (maccu_wbu_is_riuj)    ,
   .o_wbu_bubble     (maccu_wbu_bubble)     ,
   .i_wbu_stall      (wbu_maccu_stall)      ,
   .o_wbu_rdt_addr   (maccu_wbu_rdt_addr)   ,
   .o_wbu_rdt_data   (maccu_wbu_rdt_data)   ,
   .o_wbu_rdt_not_x0 (maccu_wbu_rdt_not_x0) ,
   .o_wbu_is_macc    (maccu_wbu_is_macc)    ,
   .o_wbu_is_load    (maccu_wbu_is_load)    ,
   .o_wbu_is_dwback  (maccu_wbu_is_dwback)  ,
   .o_wbu_macc_addr  (maccu_wbu_macc_addr)  
);

// WriteBack Unit (WBU)
writeback_unit #(
   .PC_INIT(PC_INIT)
)  inst_writeback_unit ( 
   .clk                (clk)     ,
   .aresetn            (aresetn) ,
   
   `ifdef DBG
   .o_wbu_dbg          (wbu_dbg) ,    
   `endif 

   .i_dmem_rdata       (i_dmem_rdata) ,
   .i_dmem_ack         (i_dmem_ack)   ,
   .o_dmem_stall       (o_dmem_stall) ,

   .o_load_data        (dmem_load_data)       ,
   
   .i_maccu_pc         (maccu_wbu_pc)         ,
   .i_maccu_instr      (maccu_wbu_instr)      ,
   .i_maccu_is_riuj    (maccu_wbu_is_riuj)    ,
   .i_maccu_bubble     (maccu_wbu_bubble)     ,
   .o_maccu_stall      (wbu_maccu_stall)      ,
   .i_maccu_rdt_addr   (maccu_wbu_rdt_addr)   ,
   .i_maccu_rdt_data   (maccu_wbu_rdt_data)   ,
   .i_maccu_rdt_not_x0 (maccu_wbu_rdt_not_x0) ,
   .i_maccu_is_macc    (maccu_wbu_is_macc)    ,
   .i_maccu_is_load    (maccu_wbu_is_load)    ,
   .i_maccu_is_dwback  (maccu_wbu_is_dwback)  ,
   .i_maccu_macc_addr  (maccu_wbu_macc_addr)  ,
   
   .o_rf_wren          (wbu_rf_wren)        ,
   .o_rf_rdt_addr      (wbu_rf_rdt_addr)    ,
   .o_rf_rdt_data      (wbu_rf_rdt_data)    ,
   
   .o_pc               (wbu_pc_out)         ,  
   .o_instr            (wbu_instr_out)      ,  
   .o_is_riuj          (wbu_is_riuj_out)    ,  
   .o_bubble           (wbu_bubble_out)     ,
   .o_rdt_addr         (wbu_rdt_addr_out)   , 
   .o_rdt_data         (wbu_rdt_data_out)   , 
   .o_rdt_not_x0       (wbu_rdt_not_x0_out) , 
   .i_stall            (i_ext_stall)        
);

//assign wbu_stall_in = 1'b0 ;

//===================================================================================================================================================
// Debug block
//===================================================================================================================================================
`ifdef SIMEXIT_INSTR_END
// Simulation END control
initial begin
   for (;;) begin 
       @(posedge clk);
       if (wbu_instr_out == `INSTR_END) begin   // END simulation command: mvi x0, 0xEEE ??  
          $display("| PQR5_SIM_CORE: [INFO ] Simulation exit triggered by END command @t = %0t ns", $time);        
          $finish;  // Finish simulation
      end
   end
end
`endif

`ifdef DBG

// Registers/Signals/Variables
logic clk_stable  ;
logic exec_begin  ;
int   exec_cycles ;
int   stal_cycles ;
int   bubb_cycles ;

// Header display
initial begin
   disp_simheader();
end

// Display debug signals
`ifdef DBG_PRINT
always @(posedge clk or negedge clk or negedge aresetn) begin
   if (!aresetn) begin
      //$display("| PQR5_SIM_CORE: [INFO ] Under reset @t = %0t ns", $time);   
      clk_stable <= 1'b0 ;
   end
   else if (clk) begin            
      $display("");
      $display("| PQR5_SIM_CORE: [INFO ] Dumping to console @t = %0t ns", $time);
      $display("");
      disp_regfile(regf);  
      $display("");      
      clk_stable <= 1'b1 ;
   end 
   else if (!clk && clk_stable) begin
      $display("+================================================");
      $display("| FETCH - DEBUG");
      $display("+------------------------------------------------");
      $display("| Branch taken    : %s", ynstatus(fu_dbg[2]));
      $write  ("| Flush generated : %s", ynstatus(o_imem_flush));
      if (fu_dbg[2] && !exu_bu_flush) $write(", by %s", ynstatus(fu_dbg[0], "JAL instr", "Branch instr")); 
      $write("\n");
      $display("| Stall generated : %s", ynstatus(o_imem_stall));
      $display("+================================================");
      $display("| DECODE - DEBUG");
      $display("+------------------------------------------------");
      $write  ("| Instr decoded   : %s", instrtype(du_dbg[5:0], ~du_exu_bubble));
      if      (du_dbg[9] && !du_exu_bubble) $write(", LUI");
      else if (du_dbg[1] && !du_exu_bubble) $write(", AUIPC");
      else if (du_dbg[8] && !du_exu_bubble) $write(", JALR");
      else if (du_dbg[7] && !du_exu_bubble) $write(", LOAD");
      else if (du_dbg[6] && !du_exu_bubble) $write(", ALUI");
      $write("\n");
      $display("| Stall generated : %s", ynstatus(du_fu_stall));
      $display("+================================================");
      $display("| EXECUTE - DEBUG");
      $display("+------------------------------------------------");
      $display("| Branch taken    : %s", ynstatus(exu_dbg[3]));
      if      (exu_dbg[2] && !exu_maccu_bubble) $display("| Instr executed  : by Load-Store Unit");
      else if (exu_dbg[1] && !exu_maccu_bubble) $display("| Instr executed  : by ALU");
      else if (exu_dbg[0] && !exu_maccu_bubble) $display("| Instr executed  : by Branch Unit");  
      else                                      $display("| Instr executed  : --");
      $write  ("| MEM access init : %s, ", ynstatus(exu_maccu_is_macc_op));
      $write  ("%s", memacctype(exu_maccu_size, exu_maccu_cmd, exu_maccu_is_macc_op));
      $write  ("\n");
      $display("| Write back init : %s", ynstatus(~exu_maccu_is_macc_op && ~exu_maccu_bubble));
      $write  ("| Flush generated : %s", ynstatus(exu_bu_flush));
      if (exu_bu_flush) $write(", by JALR/Branch instr");
      $write("\n");
      $display("| Stall generated : %s", ynstatus(exu_du_stall));
      $display("+================================================");
      $display("| MEMACC - DEBUG");
      $display("+------------------------------------------------");      
      $display("| Stall generated : %s", ynstatus(maccu_exu_stall));
      $display("+================================================");
      $display("| WRITEBACK - DEBUG");
      $display("+------------------------------------------------");
      $display("| Write to REGF   : %s", ynstatus(wbu_rf_wren));
      $display("| Stall generated : %s", ynstatus(wbu_maccu_stall));
      $display("+================================================");
      $display("");
      $display("+===========================+");
      $display("| CPI MONITOR");
      $display("+===========================+");
      $display("| Exec   = %0d cycles ", exec_cycles);
      $display("| Bubble = %0d cycles ", bubb_cycles);
      $display("| Stall  = %0d cycles ", stal_cycles);
      $display("| CPI    = %0.2f ", (exec_cycles * 1.0)/((exec_cycles * 1.0) - bubb_cycles - stal_cycles));
      $display("+===========================+");
      $display("");
      $display("+=====================================================================================+");
      $display("| PIPELINE STATUS                                                                     |");
      $display("+=====================================================================================+");
      $display("| Stage    |     FETCH    |    DECODE    |    EXECUTE   |    MEMACC    |  WRITEBACK   |");
      $display("+----------+--------------+--------------+--------------+--------------+--------------+");
      $write  ("| Valid    |");
      $write  ("       %0d      |", ~fu_du_bubble);
      $write  ("       %0d      |", ~du_exu_bubble);
      $write  ("       %0d      |", ~exu_maccu_bubble);
      $write  ("       %0d      |", ~maccu_wbu_bubble);
      $write  ("       %0d      |", ~wbu_bubble_out);
      $write  ("\n");
      $display("+----------+--------------+--------------+--------------+--------------+--------------+");      
      $write  ("| PC       |");
      hex2txt (32, fu_du_pc,     " 0x", "_", 4, "  |");
      hex2txt (32, du_exu_pc,    " 0x", "_", 4, "  |");
      hex2txt (32, exu_maccu_pc, " 0x", "_", 4, "  |");
      hex2txt (32, maccu_wbu_pc, " 0x", "_", 4, "  |");
      hex2txt (32, wbu_pc_out,   " 0x", "_", 4, "  |");
      $write  ("\n");
      $write  ("| Instr    |");
      hex2txt (32, fu_du_instr,     " 0x", "_", 4, "  |");
      hex2txt (32, du_exu_instr,    " 0x", "_", 4, "  |");
      hex2txt (32, exu_maccu_instr, " 0x", "_", 4, "  |");
      hex2txt (32, maccu_wbu_instr, " 0x", "_", 4, "  |");
      hex2txt (32, wbu_instr_out,   " 0x", "_", 4, "  |");
      $write  ("\n");
      $write  ("| Stall in |");
      $write  ("       %0d      |", du_fu_stall);
      $write  ("       %0d      |", exu_du_stall);
      $write  ("       %0d      |", maccu_exu_stall);
      $write  ("       %0d      |", wbu_maccu_stall);
      $write  ("       %0d      |", i_ext_stall);
      $write  ("\n");
      $write  ("| Flush in |");
      $write  ("       %0d      |", exu_bu_flush);
      $write  ("       %0d      |", exu_bu_flush);
      $write  ("       %0d      |", 0);
      $write  ("       %0d      |", 0);
      $write  ("       %0d      |", 0);
      $write  ("\n");
      $display("+----------+--------------+--------------+--------------+--------------+--------------+");
      $write  ("| DMEM Access : %s", ynstatus((exu_maccu_is_macc_op | wbu_dbg[0]), "ACTIVE", "IDLE"));
      $write  ("\n");
      $display("+=====================================================================================+");
      $display("");
   end   
end
`endif

// CPI Monitor
logic is_cpu_bubble ;
assign is_cpu_bubble = du_exu_bubble | (du_exu_instr == `INSTR_NOP) ;

always @(posedge clk or negedge aresetn) begin
   if (!aresetn) begin    
      exec_begin  <= 1'b0 ;     
      exec_cycles <= 1    ;
      stal_cycles <= 0    ;
      bubb_cycles <= 0    ;
   end
   else begin
      if (exec_begin) begin
         if (is_cpu_bubble)                  bubb_cycles <= bubb_cycles + 1 ;
         if (!du_exu_bubble && exu_du_stall) stal_cycles <= stal_cycles + 1 ;
         exec_cycles <= exec_cycles + 1 ;                       
      end
      else begin
         exec_begin  <= ~du_exu_bubble  ;         
      end
   end
end

`endif

`ifdef TEST_PORTS
// Test ports
assign o_x31_tst = {x31_tst[24], x31_tst[16], x31_tst[8], x31_tst[0]} ;

// Boot flag
always @(posedge clk or negedge aresetn) begin
   if (!aresetn) begin    
      boot_flag_rg <= 1'b0 ;
   end
   else begin
      boot_flag_rg <= 1'b1 ;   // Core is out of reset and booted
   end
end
assign o_boot_flag = boot_flag_rg ;
`endif

endmodule
//###################################################################################################################################################
//                                                              P Q R 5   C O R E   T O P                                          
//###################################################################################################################################################