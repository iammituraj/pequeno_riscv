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
//----%% File Name        : opfwd_control.sv
//----%% Module Name      : Operand Forward Control                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This module controls operand forwarding from DU/RF/EXU/MACCU/WBU to EXU to mitigate RAW hazards.
//----%%                    Execution results of instructions generated/piped at EXU/MACCU/WBU which are not yet written back to RF
//----%%                    are tapped and forwarded to EXU inputs if required by the operands of the next instruction to be executed at EXU.
//----%%                    Forwading of operands to EXU is performed on detecting potential RAW hazard. Possible scenarios are:
//----%%                    -- EXU result   is forwarded to EXU input if dest regaddr of (N-1)th instruction = src regaddr of Nth instruction
//----%%                    -- MACCU result is forwarded to EXU input if dest regaddr of (N-2)th instruction = src regaddr of Nth instruction
//----%%                    -- WBU result   is forwarded to EXU input if dest regaddr of (N-3)th instruction = src regaddr of Nth instruction
//----%%                    -- EXU > MACCU > WBU: The results are forwarded in the priority order of who holds the latest writeback data.
//----%%
//----%%                    For Nth instruction at EXU input, (N-1)th instruction = instruction registered at EXU output
//----%%                                                      (N-2)th instruction = instruction registered at MACCU output
//----%%                                                      (N-3)th instruction = instruction registered at WBU output
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Apr-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                 O P E R A N D   F O R W A R D   C O N T R O L                                          
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Module definition
module opfwd_control (
   // Operands from Register File (RF)
   input  logic [`XLEN-1:0] i_rf_op0            ,  // Operand-0 from RF   
   input  logic [`XLEN-1:0] i_rf_op1            ,  // Operand-1 from RF

   // Interface with Decode Unit (DU) 
   input  logic [`XLEN-1:0] i_du_pc             ,  // PC from DU
   input  logic [4:0]       i_du_rs0            ,  // rs0 from DU
   input  logic [4:0]       i_du_rs0_cpy        ,  // rs0 copy from DU
   input  logic [4:0]       i_du_rs1            ,  // rs1 from DU 
   input  logic [4:0]       i_du_rs1_cpy        ,  // rs1 copy from DU
   input  logic             i_du_is_i_type      ,  // I-type instruction flag from DU
   input  logic [11:0]      i_du_i_type_imm     ,  // I-type immediate from DU   
   input  logic             i_du_is_u_type      ,  // U-type instruction flag from DU
   input  logic [19:0]      i_du_u_type_imm     ,  // U-type immediate from DU
   input  logic             i_du_is_lui         ,  // LUI flag from DU
   input  logic             i_du_instr_rsb      ,  // RSB flag from DU
   input  logic             i_du_instr_risb     ,  // RISB instruction flag from DU
  
   // Interface with Execution Unit (EXU)
   input  logic [`XLEN-1:0] i_exu_result        ,  // Result from EXU
   input  logic [4:0]       i_exu_rdt           ,  // rdt from EXU
   input  logic             i_exu_rdt_not_x0    ,  // rdt neq x0
   input  logic             i_exu_instr_riuj    ,  // RIUJ instruction flag from EXU

   // Interface with Memory Access Unit (MACCU)
   input  logic [`XLEN-1:0] i_dmem_load_data    ,  // Load data from DMEM
   input  logic [`XLEN-1:0] i_maccu_wbdata      ,  // Writeback data from MACCU
   input  logic             i_is_load           ,  // Load flag
   input  logic [4:0]       i_maccu_rdt         ,  // rdt from MACCU
   input  logic             i_maccu_rdt_not_x0  ,  // rdt neq x0
   input  logic             i_maccu_instr_riuj  ,  // RIUJ instruction flag from MACCU

   // Interface with Write Back Unit (WBU)
   input  logic [`XLEN-1:0] i_wbu_result        ,  // Result from WBU
   input  logic [4:0]       i_wbu_rdt           ,  // rdt from WBU
   input  logic             i_wbu_rdt_not_x0    ,  // rdt neq x0
   input  logic             i_wbu_instr_riuj    ,  // RIUJ instruction flag from WBU

   // Forwarded Operands
   output logic [`XLEN-1:0] o_fwd_op0           ,  // Forwarded Operand-0
   output logic [`XLEN-1:0] o_fwd_op1              // Forwarded Operand-1
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic [`XLEN-1:0] maccu_result           ;  // MACCU result to be forwarded

logic             is_exu_rdt_not_x0      ;  // Flags if EXU rdt != x0
logic             is_maccu_rdt_not_x0    ;  // Flags if MACCU rdt != x0
logic             is_wbu_rdt_not_x0      ;  // Flags if WBU rdt != x0

logic             is_du_instr_rsb        ;  // Flags if DU instruction = RSB-type
logic             is_du_instr_risb       ;  // Flags if DU instruction = RISB-type
logic             is_exu_instr_riuj      ;  // Flags if EXU instruction = RIUJ-type
logic             is_maccu_instr_riuj    ;  // Flags if MACCU instruction = RIUJ-type
logic             is_wbu_instr_riuj      ;  // Flags if WBU instruction = RIUJ-type

logic             is_exu_wback_valid     ;  // Flags if EXU writes back to destination
logic             is_maccu_wback_valid   ;  // Flags if MACCU writes back to destination
logic             is_wbu_wback_valid     ;  // Flags if WBU writes back to destination

logic             is_du_exu_op0_raw      ;  // Flags RAW access of Operand-0 wrt EXU
logic             is_du_exu_op1_raw      ;  // Flags RAW access of Operand-1 wrt EXU
logic             is_du_maccu_op0_raw    ;  // Flags RAW access of Operand-0 wrt MACCU
logic             is_du_maccu_op1_raw    ;  // Flags RAW access of Operand-1 wrt MACCU
logic             is_du_wbu_op0_raw      ;  // Flags RAW access of Operand-0 wrt WBU
logic             is_du_wbu_op1_raw      ;  // Flags RAW access of Operand-1 wrt WBU

logic [`XLEN-1:0] rf_bypass_op0, rf_bypass_op1 ;  // Bypassed operands from RF/DU
logic [`XLEN-1:0] immI, immU ;                    // Sign-extended I/U-type immediates

//===================================================================================================================================================
// Bypass logic for operand-0 from RF
// ----------------------------------
// Operand-0 from RF is bypassed with value from DU in case of U-type instruction at DU.
// U-type instruction at DU never causes hazard at operand-0, so the bypassed operand is guaranteed to reach EXU through operand forward logic.
//===================================================================================================================================================
logic [`XLEN-1:0] DU_imm_op0 ;
logic             is_du_req_op0_bypass ;

assign is_du_req_op0_bypass = i_du_is_u_type;
assign DU_imm_op0           = i_du_is_lui? '0 : i_du_pc ;  // For LUI, 0 + immU.. For AUIPC: PC + immU
assign rf_bypass_op0        = is_du_req_op0_bypass? DU_imm_op0 : i_rf_op0 ;

//===================================================================================================================================================
// Bypass logic for operand-1 from RF
// ----------------------------------
// Operand-1 from RF is bypassed with value from DU in case of I/U-type instruction at DU.
// I/U-type instruction at DU never causes hazard at operand-1, so the bypassed operand is guaranteed to reach EXU through operand forward logic.
//===================================================================================================================================================
logic [`XLEN-1:0] DU_imm_op1 ;
logic             is_du_req_op1_bypass ;

assign is_du_req_op1_bypass = i_du_is_i_type | i_du_is_u_type ;
assign DU_imm_op1           = i_du_is_i_type? immI : immU ;
assign rf_bypass_op1        = is_du_req_op1_bypass? DU_imm_op1 : i_rf_op1 ;

assign immI = {{(`XLEN-12){i_du_i_type_imm[11]}}, i_du_i_type_imm} ;  // Sign-extend
assign immU = {i_du_u_type_imm, {(`XLEN-20){1'b0}}} ;  // LSbs to fill 0s

//===================================================================================================================================================
// Combinatorial logic to flag RAW access b/w DU and EXU
//===================================================================================================================================================
assign is_exu_wback_valid = is_exu_instr_riuj & is_exu_rdt_not_x0 ;

// Operand-0 forwarding
assign is_du_exu_op0_raw = (is_exu_wback_valid && is_du_instr_risb && (i_du_rs0 == i_exu_rdt));

// Operand-1 forwarding
assign is_du_exu_op1_raw = (is_exu_wback_valid && is_du_instr_rsb  && (i_du_rs1 == i_exu_rdt));

//===================================================================================================================================================
// Combinatorial logic to flag RAW access b/w DU and MACCU
//===================================================================================================================================================
// Select the data to be forwarded as MACCU result... 
// If Load access happened at MACCU, forward load data from DMEM access, else forward register writeback data from MACCU
assign maccu_result  = (i_is_load)? i_dmem_load_data : i_maccu_wbdata ;

assign is_maccu_wback_valid = is_maccu_instr_riuj & is_maccu_rdt_not_x0 ;

// Operand-0 forwarding
assign is_du_maccu_op0_raw = (is_maccu_wback_valid && is_du_instr_risb && (i_du_rs0_cpy == i_maccu_rdt));

// Operand-1 forwarding
assign is_du_maccu_op1_raw = (is_maccu_wback_valid && is_du_instr_rsb &&  (i_du_rs1_cpy == i_maccu_rdt));

//===================================================================================================================================================
// Combinatorial logic to flag RAW access b/w DU and WBU
//===================================================================================================================================================
assign is_wbu_wback_valid = is_wbu_instr_riuj & is_wbu_rdt_not_x0 ;

// Operand-0 forwarding
assign is_du_wbu_op0_raw = (is_wbu_wback_valid && is_du_instr_risb && (i_du_rs0_cpy == i_wbu_rdt));

// Operand-1 forwarding
assign is_du_wbu_op1_raw = (is_wbu_wback_valid && is_du_instr_rsb &&  (i_du_rs1_cpy == i_wbu_rdt));

//===================================================================================================================================================
// Combinatorial logic to forward Operand-0 to output
//===================================================================================================================================================
logic [1:0] op0_fwd_sel ;  // Priority-encoded forward select for Operand-0
// 3:1 Mux to resolve priority
always_comb begin
   casez ({is_du_exu_op0_raw, is_du_maccu_op0_raw, is_du_wbu_op0_raw})
      3'b1?? : op0_fwd_sel = 2'b00;  // EXU fwd, highest priority
      3'b01? : op0_fwd_sel = 2'b01;  // MACCU fwd
      3'b001 : op0_fwd_sel = 2'b10;  // WBU fwd
      default: op0_fwd_sel = 2'b11;  // RF/DU bypass
   endcase
end
// 4:1 Mux to forward the operand
always_comb begin
   case (op0_fwd_sel)
      2'b00  : o_fwd_op0 = i_exu_result  ;
      2'b01  : o_fwd_op0 = maccu_result  ;
      2'b10  : o_fwd_op0 = i_wbu_result  ;
      default: o_fwd_op0 = rf_bypass_op0 ;
   endcase
end

//===================================================================================================================================================
// Combinatorial logic to forward Operand-1 to output
//===================================================================================================================================================
logic [1:0] op1_fwd_sel ;  // Priority-encoded forward select for Operand-1
always_comb begin
// 3:1 Mux to resolve priority
casez ({is_du_exu_op1_raw, is_du_maccu_op1_raw, is_du_wbu_op1_raw})
      3'b1?? : op1_fwd_sel = 2'b00;  // EXU fwd, highest priority
      3'b01? : op1_fwd_sel = 2'b01;  // MACCU fwd
      3'b001 : op1_fwd_sel = 2'b10;  // WBU fwd
      default: op1_fwd_sel = 2'b11;  // RF/DU bypass
   endcase
end
// 4:1 Mux to forward the operand
always_comb begin
   case (op1_fwd_sel)
      2'b00  : o_fwd_op1 = i_exu_result  ;
      2'b01  : o_fwd_op1 = maccu_result  ;
      2'b10  : o_fwd_op1 = i_wbu_result  ;
      default: o_fwd_op1 = rf_bypass_op1 ;
   endcase
end

//===================================================================================================================================================
// Internal signals derived
//===================================================================================================================================================
assign is_exu_rdt_not_x0   = i_exu_rdt_not_x0   ;
assign is_maccu_rdt_not_x0 = i_maccu_rdt_not_x0 ;
assign is_wbu_rdt_not_x0   = i_wbu_rdt_not_x0   ;

assign is_du_instr_rsb     = i_du_instr_rsb     ;
assign is_du_instr_risb    = i_du_instr_risb    ;
assign is_exu_instr_riuj   = i_exu_instr_riuj   ;
assign is_maccu_instr_riuj = i_maccu_instr_riuj ;
assign is_wbu_instr_riuj   = i_wbu_instr_riuj   ;

endmodule
//###################################################################################################################################################
//                                                 O P E R A N D   F O R W A R D   C O N T R O L                                          
//###################################################################################################################################################