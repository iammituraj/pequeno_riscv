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
//----%%                    are tapped and forwarded to EXU inputs if required by operands of the next instruction to be executed at EXU.
//----%%                    Forwading of operands to EXU is performed on detecting potential RAW hazard. Possible scenarios are:
//----%%                    -- EXU result   is forwarded to EXU input if dest regaddr of (N-1)th instruction = src regaddr of Nth instruction
//----%%                    -- MACCU result is forwarded to EXU input if dest regaddr of (N-2)th instruction = src regaddr of Nth instruction
//----%%                    -- WBU result   is forwarded to EXU input if dest regaddr of (N-3)th instruction = src regaddr of Nth instruction
//----%%                    For Nth instruction at EXU input, (N-1)th instruction = instruction registered at EXU
//----%%                                                      (N-2)th instruction = instruction registered at MACCU
//----%%                                                      (N-3)th instruction = instruction registered at WBU
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Feb-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
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
   input  logic [4:0]       i_du_rs0            ,  // rs0 from DU
   input  logic [4:0]       i_du_rs1            ,  // rs1 from DU 
   input  logic [5:0]       i_du_instr_type     ,  // Instruction type from DU
   input  logic             i_du_instr_valid    ,  // Instruction valid from DU 

   // Interface with Execution Unit (EXU)
   input  logic [`XLEN-1:0] i_exu_result        ,  // Result from EXU
   input  logic [4:0]       i_exu_rdt           ,  // rdt from EXU
   input  logic [5:0]       i_exu_instr_type    ,  // Instruction type from EXU
   input  logic             i_exu_instr_valid   ,  // Instruction valid from EXU 

   // Interface with Memory Access Unit (MACCU)
   input  logic [`XLEN-1:0] i_maccu_result      ,  // Result from MACCU
   input  logic [4:0]       i_maccu_rdt         ,  // rdt from MACCU
   input  logic [5:0]       i_maccu_instr_type  ,  // Instruction type from MACCU
   input  logic             i_maccu_instr_valid ,  // Instruction valid from MACCU 

   // Interface with Write Back Unit (WBU)
   input  logic [`XLEN-1:0] i_wbu_result        ,  // Result from EXU
   input  logic [4:0]       i_wbu_rdt           ,  // rdt from EXU
   input  logic [5:0]       i_wbu_instr_type    ,  // Instruction type from EXU
   input  logic             i_wbu_instr_valid   ,  // Instruction valid from EXU 

   // Forwarded Operands
   output logic [`XLEN-1:0] o_fwd_op0           ,  // Forwarded Operand-0
   output logic [`XLEN-1:0] o_fwd_op1              // Forwarded Operand-1
);

//===================================================================================================================================================
// Localparams
//===================================================================================================================================================
localparam R = 5 ;  // Index for R-type instruction flag
localparam I = 4 ;  // Index for I-type instruction flag
localparam S = 3 ;  // Index for S-type instruction flag
localparam B = 2 ;  // Index for B-type instruction flag
localparam U = 1 ;  // Index for U-type instruction flag
localparam J = 0 ;  // Index for J-type instruction flag

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic [`XLEN-1:0] exu_fwd_op0            ;  // EXU fwd Operand-0
logic [`XLEN-1:0] exu_fwd_op1            ;  // EXU fwd Operand-1

logic [`XLEN-1:0] maccu_fwd_op0          ;  // MACCU fwd Operand-0
logic [`XLEN-1:0] maccu_fwd_op1          ;  // MACCU fwd Operand-1

logic [`XLEN-1:0] wbu_fwd_op0            ;  // WBU fwd Operand-0
logic [`XLEN-1:0] wbu_fwd_op1            ;  // WBU fwd Operand-1 

logic             is_exu_rdt_not_x0      ;  // Flags if EXU rdt != x0
logic             is_maccu_rdt_not_x0    ;  // Flags if MACCU rdt != x0
logic             is_wbu_rdt_not_x0      ;  // Flags if WBU rdt != x0

logic             is_du_instr_risb       ;  // Flags if DU instruction = RISB-type
logic             is_exu_instr_riuj      ;  // Flags if EXU instruction = RIUJ-type 
logic             is_maccu_instr_riuj    ;  // Flags if MACCU instruction = RIUJ-type
logic             is_wbu_instr_riuj      ;  // Flags if WBU instruction = RIUJ-type

logic             is_du_exu_op0_raw      ;  // Flags RAW access of Operand-0 wrt EXU
logic             is_du_exu_op1_raw      ;  // Flags RAW access of Operand-1 wrt EXU
logic             is_du_maccu_op0_raw    ;  // Flags RAW access of Operand-0 wrt MACCU
logic             is_du_maccu_op1_raw    ;  // Flags RAW access of Operand-1 wrt MACCU
logic             is_du_wbu_op0_raw      ;  // Flags RAW access of Operand-0 wrt WBU
logic             is_du_wbu_op1_raw      ;  // Flags RAW access of Operand-1 wrt WBU
logic [2:0]       is_op0_raw, is_op1_raw ;  // Flags RAW access of Operand-0, Operand-1 wrt {EXU, MACCU, WBU}

//===================================================================================================================================================
// Combinatorial logic to forward EXU result
//===================================================================================================================================================
always_comb begin 
   // Hazard condition
   if (is_exu_instr_riuj && is_du_instr_risb && i_exu_instr_valid && i_du_instr_valid) begin
      // Operand-0 fwd; x0 never causes hazards
      if ((i_du_rs0 == i_exu_rdt) && is_exu_rdt_not_x0) begin 
         exu_fwd_op0       = i_exu_result ;  // Potential RAW hazard, forward WBU result 
         is_du_exu_op0_raw = 1'b1         ;
      end      
      else begin 
         exu_fwd_op0       = i_rf_op0     ;  // No hazard, bypass RF operand
         is_du_exu_op0_raw = 1'b0         ;
      end
      // Operand-1 fwd; I-type instr @DU output doesn't have operand-1, but no harm in forwarding as it is anyway unused...
      if ((i_du_rs1 == i_exu_rdt) && is_exu_rdt_not_x0) begin 
         exu_fwd_op1       = i_exu_result ;  // Potential RAW hazard, forward WBU result 
         is_du_exu_op1_raw = 1'b1         ;
      end       
      else begin 
         exu_fwd_op1       = i_rf_op1     ;  // No hazard, bypass RF operand
         is_du_exu_op1_raw = 1'b0         ;
      end                                       	
   end
   // No hazard condition, bypass
   else begin
      exu_fwd_op0       = i_rf_op0 ;
      exu_fwd_op1       = i_rf_op1 ; 
      is_du_exu_op0_raw = 1'b0     ;
      is_du_exu_op1_raw = 1'b0     ;	
   end
end

//===================================================================================================================================================
// Combinatorial logic to forward MACCU result
//===================================================================================================================================================
always_comb begin 
   // Hazard condition
   if (is_maccu_instr_riuj && is_du_instr_risb && i_maccu_instr_valid && i_du_instr_valid) begin
      // Operand-0 fwd; x0 never causes hazards
      if ((i_du_rs0 == i_maccu_rdt) && is_maccu_rdt_not_x0) begin 
         maccu_fwd_op0       = i_maccu_result ;  // Potential RAW hazard, forward WBU result 
         is_du_maccu_op0_raw = 1'b1           ;
      end      
      else begin 
         maccu_fwd_op0       = i_rf_op0       ;  // No hazard, bypass RF operand
         is_du_maccu_op0_raw = 1'b0           ;
      end
      // Operand-1 fwd; I-type instr @DU output doesn't have operand-1, but no harm in forwarding as it is anyway unused...
      if ((i_du_rs1 == i_maccu_rdt) && is_maccu_rdt_not_x0) begin 
         maccu_fwd_op1       = i_maccu_result ;  // Potential RAW hazard, forward WBU result 
         is_du_maccu_op1_raw = 1'b1           ;
      end      
      else begin 
         maccu_fwd_op1       = i_rf_op1       ;  // No hazard, bypass RF operand
         is_du_maccu_op1_raw = 1'b0           ;
      end                                       	
   end
   // No hazard condition, bypass
   else begin
      maccu_fwd_op0       = i_rf_op0 ;
      maccu_fwd_op1       = i_rf_op1 ;
      is_du_maccu_op0_raw = 1'b0     ; 	
      is_du_maccu_op1_raw = 1'b0     ;
   end
end

//===================================================================================================================================================
// Combinatorial logic to forward WBU result
//===================================================================================================================================================
always_comb begin 
   // Hazard condition
   if (is_wbu_instr_riuj && is_du_instr_risb && i_wbu_instr_valid && i_du_instr_valid) begin
      // Operand-0 fwd; x0 never causes hazards
      if ((i_du_rs0 == i_wbu_rdt) && is_wbu_rdt_not_x0) begin 
         wbu_fwd_op0       = i_wbu_result ;  // Potential RAW hazard, forward WBU result 
         is_du_wbu_op0_raw = 1'b1         ;
      end      
      else begin 
         wbu_fwd_op0       = i_rf_op0     ;  // No hazard, bypass RF operand
         is_du_wbu_op0_raw = 1'b0         ;
      end
      // Operand-1 fwd; I-type instr @DU output doesn't have operand-1, but no harm in forwarding as it is anyway unused...
      if ((i_du_rs1 == i_wbu_rdt) && is_wbu_rdt_not_x0) begin 
         wbu_fwd_op1       = i_wbu_result ;  // Potential RAW hazard, forward WBU result 
         is_du_wbu_op1_raw = 1'b1         ;
      end       
      else begin 
         wbu_fwd_op1       = i_rf_op1     ;  // No hazard, bypass RF operand
         is_du_wbu_op1_raw = 1'b0         ;
      end                                       	
   end
   // No hazard condition, bypass
   else begin
      wbu_fwd_op0       = i_rf_op0 ;
      wbu_fwd_op1       = i_rf_op1 ; 
      is_du_wbu_op0_raw = 1'b0     ;	
      is_du_wbu_op1_raw = 1'b0     ;
   end
end

//===================================================================================================================================================
// Combinatorial logic to forward Operand-0 to output
//===================================================================================================================================================
always_comb begin 
   casez (is_op0_raw)
      3'b1??  : begin o_fwd_op0 = exu_fwd_op0   ; end  // EXU fwd, highest priority
      3'b01?  : begin o_fwd_op0 = maccu_fwd_op0 ; end  // MACCU fwd
      3'b001  : begin o_fwd_op0 = wbu_fwd_op0   ; end  // WBU fwd      
      default : begin o_fwd_op0 = i_rf_op0      ; end  // Bypass  
   endcase
end

assign is_op0_raw = {is_du_exu_op0_raw, is_du_maccu_op0_raw, is_du_wbu_op0_raw} ;

//===================================================================================================================================================
// Combinatorial logic to forward Operand-1 to output
//===================================================================================================================================================
always_comb begin 
   casez (is_op1_raw)
      3'b1??  : begin o_fwd_op1 = exu_fwd_op1   ; end  // EXU fwd
      3'b01?  : begin o_fwd_op1 = maccu_fwd_op1 ; end  // MACCU fwd
      3'b001  : begin o_fwd_op1 = wbu_fwd_op1   ; end  // WBU fwd      
      default : begin o_fwd_op1 = i_rf_op1      ; end  // Bypass  
   endcase
end

assign is_op1_raw = {is_du_exu_op1_raw, is_du_maccu_op1_raw, is_du_wbu_op1_raw} ;

//===================================================================================================================================================
// Continuous assignments
//===================================================================================================================================================
assign is_exu_rdt_not_x0   = (|i_exu_rdt)   ;
assign is_maccu_rdt_not_x0 = (|i_maccu_rdt) ;
assign is_wbu_rdt_not_x0   = (|i_wbu_rdt)   ;

assign is_du_instr_risb    = i_du_instr_type[R]    | i_du_instr_type[I]    | i_du_instr_type[S]    | i_du_instr_type[B]    ;
assign is_exu_instr_riuj   = i_exu_instr_type[R]   | i_exu_instr_type[I]   | i_exu_instr_type[U]   | i_exu_instr_type[J]   ;
assign is_maccu_instr_riuj = i_maccu_instr_type[R] | i_maccu_instr_type[I] | i_maccu_instr_type[U] | i_maccu_instr_type[J] ;
assign is_wbu_instr_riuj   = i_wbu_instr_type[R]   | i_wbu_instr_type[I]   | i_wbu_instr_type[U]   | i_wbu_instr_type[J]   ;

endmodule
//###################################################################################################################################################
//                                                 O P E R A N D   F O R W A R D   C O N T R O L                                          
//###################################################################################################################################################