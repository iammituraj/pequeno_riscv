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
//----%% File Name        : static_bpredictor.sv
//----%% Module Name      : Static Branch Predictor                                          
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Static Branch Predictor used by the Fetch Unit (FU) of PQR5 Core. 
//----%%                    The predictor is static in nature and doesn't keep track of branch resolution history.
//----%%                    # Unconditional Jumps are always taken (JAL)
//----%%                    # If Branch instruction, the branch is taken if backward jump, else not taken. 
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Apr-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                    S T A T I C   B R A N C H   P R E D I C T O R                                       
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Module definition
module static_bpredictor (  
   // Fetch Unit Interface
   input  logic             i_is_op_jal       ,  // JAL instruction?
   input  logic             i_is_op_branch    ,  // Branch instruction? 
   input  logic [`XLEN-1:0] i_immJ            ,  // Sign-extended Immediate (Jump) 
   input  logic [`XLEN-1:0] i_immB            ,  // Sign-extended Immediate (Branch)
   input  logic             i_instr_valid     ,  // Instruction valid
   input  logic [`XLEN-1:0] i_pc              ,  // PC of 

   // Branch Prediction signals
   output logic [`XLEN-1:0] o_branch_pc       ,  // Branch PC         
   output logic             o_branch_taken       // Branch taken status; '0'- not taken, '1'- taken
);

// Branch PC computation
logic [`XLEN-1:0] pc_offset ;  // Offset to be added to PC after prediction
always_comb begin   
   if      (i_is_op_jal)    begin pc_offset = i_immJ ; end  // JAL
   else if (i_is_op_branch) begin pc_offset = i_immB ; end  // Branch
   else                     begin pc_offset = '0     ; end  // PC
end
assign o_branch_pc = i_pc + pc_offset ;

// Branch Prediction
// - If Jump instruction, branch is always taken
// - If Branch instruction, branch is taken if backward jump 
// - Branch taken status is never set if the instruction is not Branch/Jump   
assign o_branch_taken = (i_is_op_jal || (i_is_op_branch && i_immB[31])) & i_instr_valid ;  

endmodule
//###################################################################################################################################################
//                                                    S T A T I C   B R A N C H   P R E D I C T O R                                       
//###################################################################################################################################################