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
//----%% File Name        : execution_unit.sv
//----%% Module Name      : Execution Unit (EXU)                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Execution Unit (EXU) of PQR5 Core.
//----%%                    # Executes the instruction decoded by Decode Unit (DU); in-order execution.
//----%%                    # Only valid instructions are executed, if invalid instruction, bubble is inserted.
//----%%                    # Supports pipeline interlock mechanism to mitigate Load instruction RAW hazards.
//----%%                    # Incorporates ALU to execute ALU instructions + LUI/AUIPC instructions.
//----%%                    # Incorporates Branch Unit (EXU-BU) to execute Jump/Branch instructions. Generates branch flush after
//----%%                      branch resolution, if the branch prediction was wrong.
//----%%                    # Incorporates Load-Store Unit (LSU) to execute Load/Store instructions.
//----%%                    # Sends EXU results/memory access commands as payload to Memory Access Unit (MACCU). 
//----%%                    # Pipeline latency = 1 cycle at all execution units ALU, LSU, EXU-BU.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Apr-2025
//----%% Notes            : - 
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         E X E C U T I O N   U N I T                                         
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module execution_unit #(
   // Configurable parameters
   parameter PC_INIT = `PC_INIT  // Init PC on reset
)
(
   // Clock and Reset
   input  logic             clk                ,  // Clock
   input  logic             aresetn            ,  // Asynchronous Reset; active-low
   
   `ifdef DBG
   // Debug Interface  
   output logic [4:0]       o_exu_dbg          ,  // Debug signal
   `endif

   // Operands from Register File/Operand Forward Control
   input  logic [`XLEN-1:0] i_op0              ,  // Operand-0
   input  logic [`XLEN-1:0] i_op1              ,  // Operand-1

   // EXU-BU Interface
   output logic             o_exu_bu_flush     ,  // Flush signal to upstream pipeline
   output logic [`XLEN-1:0] o_exu_bu_pc        ,  // Branch PC to upstream pipeline   
   input  logic             i_exu_bu_br_taken  ,  // Branch taken status from upstream pipeline
   
   // Interface with Decode Unit (DU)   
   input  logic [`XLEN-1:0] i_du_pc            ,  // PC from DU        
   input  logic [`ILEN-1:0] i_du_instr         ,  // Instruction decoded and sent from DU     
   input  logic             i_du_bubble        ,  // Bubble from DU    
   output logic             o_du_stall         ,  // Stall signal to DU

   input  logic [6:0]       i_du_opcode        ,  // Instruction opcode from DU       
   input  logic [3:0]       i_du_alu_opcode    ,  // ALU opcode from DU    
   input  logic [4:0]       i_du_rs0           ,  // rs0 (source register-0) address from DU
   input  logic [4:0]       i_du_rs1           ,  // rs1 (source register-1) address from DU
   input  logic [4:0]       i_du_rdt           ,  // rdt (destination register) address from DU     
   input  logic             i_du_rdt_not_x0    ,  // rdt neq x0   
   input  logic [2:0]       i_du_funct3        ,  // funct3 from DU    
     
   input  logic             i_du_is_r_type     ,  // R-type instruction flag from DU 
   input  logic             i_du_is_i_type     ,  // I-type instruction flag from DU 
   input  logic             i_du_is_s_type     ,  // S-type instruction flag from DU 
   input  logic             i_du_is_b_type     ,  // B-type instruction flag from DU 
   input  logic             i_du_is_u_type     ,  // U-type instruction flag from DU 
   input  logic             i_du_is_j_type     ,  // J-type instruction flag from DU 
   input  logic             i_du_is_risb       ,  // RISB flag from DU //**CHECKME**// Unused here, but tapped by Operand Forward block
   input  logic             i_du_is_riuj       ,  // RIUJ flag from DU
   input  logic             i_du_is_jalr       ,  // JALR flag from DU
   input  logic             i_du_is_load       ,  // Load flag from DU
   input  logic             i_du_is_lui        ,  // LUI flag from DU
   input  logic [11:0]      i_du_i_type_imm    ,  // I-type immediate from DU
   input  logic [11:0]      i_du_s_type_imm    ,  // S-type immediate from DU
   input  logic [11:0]      i_du_b_type_imm    ,  // B-type immediate from DU
   input  logic [19:0]      i_du_u_type_imm    ,  // U-type immediate from DU
   input  logic [19:0]      i_du_j_type_imm    ,  // J-type immediate from DU

   // Interface with Memory Access Unit (MACCU)
   output logic [`XLEN-1:0] o_maccu_pc         ,  // PC to MACCU
   output logic [`ILEN-1:0] o_maccu_instr      ,  // Executed instruction to MACCU
   output logic             o_maccu_is_riuj    ,  // RIUJ flag to MACCU
   output logic             o_maccu_bubble     ,  // Bubble to MACCU
   input  logic             i_maccu_stall      ,  // Stall signal from MACCU

   output logic [4:0]       o_maccu_rdt_addr   ,  // Writeback address to MACCU
   output logic [`XLEN-1:0] o_maccu_rdt_data   ,  // Writeback data to MACCU
   output logic             o_maccu_rdt_not_x0 ,  // Write back address neq x0
   output logic             o_maccu_is_macc_op ,  // Memory access operation flag to MACCU
   output logic             o_maccu_macc_cmd   ,  // Memory access command to MACCU; '0'- Load, '1'- Store
   output logic [`XLEN-1:0] o_maccu_macc_addr  ,  // Memory access address to MACCU
   output logic [1:0]       o_maccu_macc_size  ,  // Memory access size to MACCU
   output logic [`XLEN-1:0] o_maccu_macc_data     // Memory access data (for Store) to MACCU   
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// EXU-BU specific
logic [`XLEN-1:0] bu_result          ;  // EXU-BU result ie., Next Instruction PC
logic             bu_bubble          ;  // Bubble from EXU-BU
logic             bu_branch_taken    ;  // Branch taken status
logic [`XLEN-1:0] bu_branch_pc       ;  // Branch PC
logic             bu_flush           ;  // Flush

// ALU and Pre-processing related
logic             is_op_lui          ;  // LUI instruction flag
logic [`XLEN-1:0] immI, immU         ;  // Sign-extended I/U-type immediates
logic [3:0]       alu_opcode         ;  // ALU opcode
logic [`XLEN-1:0] alu_op0, alu_op1   ;  // ALU operands
logic [`XLEN-1:0] alu_result         ;  // ALU result
logic             alu_bubble         ;  // Bubble from ALU

// LSU specific
logic             lsu_mem_cmd        ;  // Memory command
logic [`XLEN-1:0] lsu_mem_addr       ;  // Memory address
logic [1:0]       lsu_mem_size       ;  // Memory data size
logic [`XLEN-1:0] lsu_mem_data       ;  // Memory data (for Store)
logic             lsu_bubble         ;  // Bubble from LSU

// Buffered packets from DU
logic [`XLEN-1:0] exu_pc_rg          ;  // PC
logic [`ILEN-1:0] exu_instr_rg       ;  // Instruction
logic             exu_is_riuj_rg     ;  // RIUJ flag
logic [4:0]       exu_rdt_rg         ;  // rdt address
logic             exu_rdt_not_x0_rg  ;  // rdt neq x0

// EXU results in the Payload to MACCU
logic             exu_bubble         ;  // Bubble
logic [`XLEN-1:0] exu_result         ;  // EXU result for writeback

// Pipeline Interlock logic specific
logic             is_exu_instr_valid   ;  // Flags if EXU instr is valid
logic             is_exu_instr_load    ;  // Flags if EXU instr is Load
logic             is_src_eq_dest       ;  // Flags RAW access ie., EXU instr's destination register = DU instr's source register
logic             is_du_rs0_eq_exu_rdt ;  // Flags if DU rs0 == EXU rdt
logic             is_du_rs1_eq_exu_rdt ;  // Flags if DU rs1 == EXU rdt
logic             is_du_rsx_eq_exu_rdt ;  // Flags if DU rs0/1 == EXU rdt
logic             is_exu_rdt_not_x0    ;  // Flags if EXU rdt != x0
logic [3:0]       is_du_instr_risb     ;  // Flags if DU instr = R/I/S/B-type
logic             is_du_instr_valid    ;  // Flags if DU instr is valid
logic             is_exu_result_wb     ;  // Flags if EXU result requires writeback
logic             is_exu_result_mem    ;  // Flags if EXU result requires memory access
logic             is_pipe_inlock       ;  // Flags if pipeline interlock required

// Stall logic specific
logic             stall         ;  // Local stall generated by EXU
logic             exu_stall_ext ;  // External stall generated by EXU to DU


//===================================================================================================================================================
// Instances of submodules
//===================================================================================================================================================
// Branch Unit (EXU-BU)
exu_branch_unit #(
   .PC_INIT (PC_INIT)
)  inst_exu_branch_unit (
   .clk            (clk)     ,
   .aresetn        (aresetn) ,

   .i_stall        (stall)             ,
   .i_pc           (i_du_pc)           ,    
   .i_bubble       (i_du_bubble | is_pipe_inlock),  // Pipeline interlock should insert bubble in all exec units    
   .i_is_j_type    (i_du_is_j_type)    ,    
   .i_is_b_type    (i_du_is_b_type)    ,  
   .i_is_jalr      (i_du_is_jalr)      ,
   .i_funct3       (i_du_funct3)       ,    
   .i_immJ         (i_du_j_type_imm)   ,    
   .i_immI         (i_du_i_type_imm)   ,    
   .i_immB         (i_du_b_type_imm)   ,    
   .i_op0          (i_op0)             ,    
   .i_op1          (i_op1)             ,    
   .i_branch_taken (i_exu_bu_br_taken) ,

   .o_nxt_instr_pc (bu_result)       ,  
   .o_bubble       (bu_bubble)       , 
   .o_branch_taken (bu_branch_taken) ,
   .o_branch_pc    (bu_branch_pc)    , 
   .o_flush        (bu_flush)      
);

// ALU
alu inst_alu (
   .clk      (clk)         , 
   .aresetn  (aresetn)     ,
   .i_stall  (stall)       ,
   .i_bubble (i_du_bubble | is_pipe_inlock),  // Pipeline interlock should insert bubble in all exec units
   .i_op0    (alu_op0)     , 
   .i_op1    (alu_op1)     , 
   .i_opcode (alu_opcode)  ,
   .o_result (alu_result)  ,
   .o_bubble (alu_bubble)
);

// Load-Store Unit (LSU)
loadstore_unit inst_loadstore_unit (
   .clk         (clk)     ,
   .aresetn     (aresetn) ,
   
   .i_stall     (stall)           ,
   .i_bubble    (i_du_bubble | is_pipe_inlock),  // Pipeline interlock should insert bubble in all exec units 
   .i_is_s_type (i_du_is_s_type)  ,
   .i_is_load   (i_du_is_load)    ,
   .i_funct3    (i_du_funct3)     ,
   .i_immI      (i_du_i_type_imm) ,
   .i_immS      (i_du_s_type_imm) ,
   .i_op0       (i_op0)           ,    
   .i_op1       (i_op1)           , 
   
   .o_mem_cmd   (lsu_mem_cmd)  ,
   .o_mem_addr  (lsu_mem_addr) ,
   .o_mem_size  (lsu_mem_size) ,
   .o_mem_data  (lsu_mem_data) ,    
   .o_bubble    (lsu_bubble)   
);

//===================================================================================================================================================
//  Pre-processing logic - to select inputs (operands and opcode) to ALU
//===================================================================================================================================================
always_comb begin
   case ({i_du_is_r_type, i_du_is_i_type, i_du_is_u_type}) 
      3'b100  : begin  // R-type instruction
                   alu_op0  = i_op0 ;
                   alu_op1  = i_op1 ; 
                end
      3'b010  : begin  // I-type instruction
                   alu_op0  = i_op0 ;
                   alu_op1  = immI  ;
                end
      3'b001  : begin  // U-type instruction
                   alu_op0  = is_op_lui? '0 : i_du_pc ;  // 0+immU for LUI, pc+immU for AUIPC
                   alu_op1  = immU ;
                end          
      default : begin  // Illegal instruction
                   alu_op0  = '0 ;
                   alu_op1  = '0 ; 
                end      	
   endcase  
end

assign alu_opcode = i_du_alu_opcode ;
assign is_op_lui  = i_du_is_lui     ;
assign immI       = {{(`XLEN-12){i_du_i_type_imm[11]}}, i_du_i_type_imm} ;  // Sign-extend
assign immU       = {i_du_u_type_imm, {(`XLEN-20){1'b0}}} ;                 // LSbs to fill 0s

//===================================================================================================================================================
// Synchronous logic to pipe PC
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin exu_pc_rg <= PC_INIT  ; end
   else if (!stall)   begin exu_pc_rg <= i_du_pc  ; end  // Pipe forward...
end

//===================================================================================================================================================
// Synchronous logic to pipe instruction
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin exu_instr_rg <= `INSTR_NOP ; end
   else if (!stall)   begin exu_instr_rg <= i_du_instr ; end  // Pipe forward... 
end

//===================================================================================================================================================
// Synchronous logic to pipe RIUJ flag
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin exu_is_riuj_rg <= 1'b0         ; end
   else if (!stall)   begin exu_is_riuj_rg <= i_du_is_riuj ; end  // Pipe forward... 
end

//===================================================================================================================================================
// Synchronous logic to pipe rdt
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if (!aresetn) begin
      exu_rdt_rg        <= '0   ; 
      exu_rdt_not_x0_rg <= 1'b0 ;
   end
   else if (!stall) begin // Pipe forward... 
      exu_rdt_rg        <= i_du_rdt        ;  
      exu_rdt_not_x0_rg <= i_du_rdt_not_x0 ;
   end 
end

//===================================================================================================================================================
// Combinatorial logic to insert bubble and compute EXU result for writeback
//===================================================================================================================================================
always_comb begin
   case ({bu_bubble, alu_bubble})       
      2'b01   : exu_result = bu_result  ;
      2'b10   : exu_result = alu_result ;      
      default : exu_result = alu_result ;
   endcase   
end 

assign is_exu_result_wb  = ~bu_bubble | ~alu_bubble ;             // JAL/JALR/ALU/LUI/AUIPC instructions require writeback
assign is_exu_result_mem = ~lsu_bubble  ;                         // Load/Store instructions require memory access          
assign exu_bubble        = bu_bubble & alu_bubble & lsu_bubble ;  // If EXU-BU, ALU, and LSU assert bubble, invalidate the piped instruction

//===================================================================================================================================================
//  Pipeline Interlock logic
//  ------------------------
//  If current instr is Load, and next instr is RISB-type with RAW access, then
//  EXU result doesn't contain the Load data for operand forwarding, so the RAW access may lead to RAW hazard...
//  This is mitigated by generating pipeline interlock. This logic generates 1-cycle stall to DU, inserts bubble in pipeline, allowing MACCU to load
//  the data in the next cycle (if available, else MACCU generates stall next cycle). 
//  Once MACCU registers the result ie., Load data, operand forwarding can take over this data and mitigate the RAW hazard...
//===================================================================================================================================================
// Combinatorial logic to flag RAW access
always_comb begin
   case (is_du_instr_risb)
      4'b1000 , //is_src_eq_dest = (is_du_rsx_eq_exu_rdt && is_exu_rdt_not_x0 ;  // R-type RAW access; x0 never causes hazard
      4'b0010 , //is_src_eq_dest = (is_du_rsx_eq_exu_rdt && is_exu_rdt_not_x0 ;  // S-type RAW access; x0 never causes hazard
      4'b0001 : is_src_eq_dest = is_du_rsx_eq_exu_rdt && is_exu_rdt_not_x0 ;  // B-type RAW access; x0 never causes hazard
      4'b0100 : is_src_eq_dest = is_du_rs0_eq_exu_rdt && is_exu_rdt_not_x0 ;  // I-type RAW access; x0 never causes hazard
      default : is_src_eq_dest = 1'b0 ;   
   endcase
end

assign is_du_rs0_eq_exu_rdt = (i_du_rs0 == exu_rdt_rg) ;
assign is_du_rs1_eq_exu_rdt = (i_du_rs1 == exu_rdt_rg) ;
assign is_du_rsx_eq_exu_rdt = is_du_rs0_eq_exu_rdt | is_du_rs1_eq_exu_rdt ;
assign is_exu_rdt_not_x0    = exu_rdt_not_x0_rg ;
assign is_du_instr_risb     = {i_du_is_r_type, i_du_is_i_type, i_du_is_s_type, i_du_is_b_type} ;
assign is_du_instr_valid    = ~i_du_bubble ;
assign is_exu_instr_valid   = ~exu_bubble  ;
assign is_exu_instr_load    = ~lsu_mem_cmd ;

// Valid Load instruction and RAW access detected? => potential RAW hazard => pipeline interlock!
assign is_pipe_inlock = (is_exu_result_mem && is_exu_instr_load && is_du_instr_valid && is_src_eq_dest) ;

//===================================================================================================================================================
//  Stall logic
//===================================================================================================================================================
assign stall         = i_maccu_stall ;                            // Only MACCU can stall EXU from outside
assign exu_stall_ext = (stall & ~i_du_bubble) | is_pipe_inlock ;  // If invalid instr from DU, stall not generated to DU. Pipeline interlock -> stall  
assign o_du_stall    = exu_stall_ext ;                            // Stall signal to DU

//===================================================================================================================================================
// All other output signals from EXU
//===================================================================================================================================================
`ifdef DBG
// Debug Interface
assign o_exu_dbg = {is_pipe_inlock, bu_branch_taken, ~lsu_bubble, ~alu_bubble, ~bu_bubble} ;
`endif

// EXU-BU outputs to the Core pipeline
assign o_exu_bu_flush = bu_flush     ;
assign o_exu_bu_pc    = bu_branch_pc ;

// Payload to MACCU
assign o_maccu_pc         = exu_pc_rg         ;
assign o_maccu_instr      = exu_instr_rg      ;
assign o_maccu_is_riuj    = exu_is_riuj_rg    ;
assign o_maccu_bubble     = exu_bubble | i_maccu_stall ; // Stall should invalidate instr to disable new memory access requests @maccu
                                                         // cz the stall may be fwded from WBU and DMEMIF@maccu may accept new requests otherwise.
                                                         // This is a strict in-order requirement 
assign o_maccu_rdt_addr   = exu_rdt_rg        ;
assign o_maccu_rdt_data   = exu_result        ;
assign o_maccu_rdt_not_x0 = exu_rdt_not_x0_rg ;
assign o_maccu_is_macc_op = is_exu_result_mem ;
assign o_maccu_macc_cmd   = lsu_mem_cmd       ;
assign o_maccu_macc_addr  = lsu_mem_addr      ;
assign o_maccu_macc_size  = lsu_mem_size      ;
assign o_maccu_macc_data  = lsu_mem_data      ;

endmodule
//###################################################################################################################################################
//                                                         E X E C U T I O N   U N I T                                         
//###################################################################################################################################################