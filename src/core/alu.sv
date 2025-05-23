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
//----%% File Name        : alu.sv
//----%% Module Name      : ALU                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : ALU used by Execution Unit (EXU) of PQR5 Core. The ALU supports all RV32I integer computation instructions.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : May-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                                     A L U                                         
//###################################################################################################################################################
// Header files
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module alu (
   input  logic             clk                 ,  // Clock
   input  logic             aresetn             ,  // Asynchronous Reset; active-low
   input  logic             i_stall             ,  // Stall signal
   input  logic             i_bubble            ,  // Bubble in
   input  logic             i_is_alu_op         ,  // ALU operation flag
   input  logic [`XLEN-1:0] i_op0               ,  // Operand-0
   input  logic [`XLEN-1:0] i_op1               ,  // Operand-1
   input  logic [3:0]       i_opcode            ,  // Opcode
   output logic [`XLEN-1:0] o_result            ,  // Result
   output logic             o_op0_lt_op1        ,  // op0 < op1  ?
   output logic             o_sign_op0_lt_op1   ,  // signed (op0) < signed(op1) ?
   output logic             o_bubble               // Bubble out
);

//===================================================================================================================================================
// Combinatorial logic to compute result
//===================================================================================================================================================
logic [`XLEN-1:0] result             ;  // ALU result
logic             is_op0_lt_op1      ;  // Unsigned comparison flag
logic             is_sign_op0_lt_op1 ;  // Signed comparison flag
logic             bubble             ;  // Bubble

always_comb begin
   casez (i_opcode)
      // Legal ALU instructions
      ALU_ADD  : result = i_op0 + i_op1 ; 
      ALU_SUB  : result = i_op0 - i_op1 ;
      ALU_SLT  : result = {{`XLEN-1{1'b0}}, is_sign_op0_lt_op1} ;
      ALU_SLTU : result = {{`XLEN-1{1'b0}}, is_op0_lt_op1} ;
      ALU_XOR  : result = i_op0 ^ i_op1 ;
      ALU_OR   : result = i_op0 | i_op1 ;
      ALU_AND  : result = i_op0 & i_op1 ;
      ALU_SLL  : result = i_op0 << i_op1[4:0] ;
      ALU_SRL  : result = i_op0 >> i_op1[4:0] ;
      ALU_SRA  : result = (signed'(i_op0)) >>> i_op1[4:0] ;
      default  : result = '0 ;  // Illegal ALU instruction. Currently bubble is not generated, allows to go fwd in pipeline as it's non-critical...  	
   endcase
end
assign is_op0_lt_op1      = (i_op0 < i_op1) ;                    // Unsigned comparison
assign is_sign_op0_lt_op1 = (signed'(i_op0) < signed'(i_op1)) ;  // Signed comparison
assign bubble             = i_is_alu_op? i_bubble : 1'b1 ;  // If not ALU operation, insert bubble...

//===================================================================================================================================================
// Synchronous logic to register outputs
//===================================================================================================================================================
logic [`XLEN-1:0] result_rg ;  // ALU result
logic             bubble_rg ;  // Bubble

always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      result_rg <= '0   ;
      bubble_rg <= 1'b1 ;       
   end
   // Out of reset
   else if (!i_stall) begin
      result_rg <= result ;
      bubble_rg <= bubble ;
   end
end

assign o_result          = result_rg          ;
assign o_op0_lt_op1      = is_op0_lt_op1      ;
assign o_sign_op0_lt_op1 = is_sign_op0_lt_op1 ;
assign o_bubble          = bubble_rg          ;

endmodule
//###################################################################################################################################################
//                                                                     A L U                                          
//###################################################################################################################################################