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
//----%% File Name        : ras_predictor.sv
//----%% Module Name      : RAS Predictor                                   
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : RAS predictor monitors CALL/RET instructions and controls push/pop operations to call stack.
//----%%                    - Return address (PC+4) from FU is pushed to the stack on every CALL
//----%%                    - RAS prediction on every RET - If the stack is not empty, return address is popped out and flush is generated.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : August-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         R A S   P R E D I C T O R                                   
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Module definition
module ras_predictor #(
   parameter  ST_DPT   = `RAS_DPT,        // Stack depth; MUST BE 2^N size
   parameter  ST_DW    = `XLEN,           // Stack data size
   localparam ST_PTRW  = $clog2(ST_DPT)   // Stack pointer size
)(
   // Clock and Reset
   input  logic               clk           ,  // Clock
   input  logic               aresetn       ,  // Asynchronous Reset; active-low

   // Stack Rollback Interface
   input  logic               i_rbk_en      ,  // Roll back enable
   input  logic [ST_PTRW-1:0] i_rbk_ptr     ,  // Roll back pointer
   input  logic [ST_PTRW-0:0] i_rbk_cnt     ,  // Roll back counter

   // CPU pipeline state
   input  logic               i_is_call_fu  ,  // CALL instr flag at FU output
   input  logic               i_is_ret_fu   ,  // RET instr flag at DU output
   input  logic               i_is_call_du  ,  // CALL instr flag at DU output
   input  logic               i_is_ret_du   ,  // RET instruction flag at DU output

   // Fetch Unit Interface
   input  logic [ST_DW-1:0]   i_pc          ,  // PC in
   input  logic               i_stall       ,  // Stall
   input  logic               i_is_call     ,  // CALL instr flag at FU input
   input  logic               i_is_ret      ,  // RET instr flag at FU input
   input  logic               i_instr_valid ,  // Instruction valid

   // Prediction signals
   output logic [ST_DW-1:0]   o_ret_addr    ,  // Return address predicted
   output logic               o_ret_taken   ,  // Return taken status; '0'- not taken, '1'- taken
   output logic               o_flush          // Flush generated on return taken
);

//logic [ST_DW-1:0] i_ret_addr    ,  // Return address to be stored in the stack on CALL

endmodule
//###################################################################################################################################################
//                                                         R A S   P R E D I C T O R                                   
//###################################################################################################################################################