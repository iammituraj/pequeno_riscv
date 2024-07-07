//     %%%%%%%%%#      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//  %%%%%%%%%%%%%%%%%  ------------------------------------------------------------------------------------------------------------------------------
// %%%%%%%%%%%%%%%%%%%% %
// %%%%%%%%%%%%%%%%%%%% %%
//    %% %%%%%%%%%%%%%%%%%%
//        % %%%%%%%%%%%%%%%                 //---- O P E N - S O U R C E ----//
//           %%%%%%%%%%%%%%                 ╔═══╦╗──────────────╔╗──╔╗
//           %%%%%%%%%%%%%      %%          ║╔═╗║║──────────────║║──║║
//           %%%%%%%%%%%       %%%%         ║║─╚╣╚═╦╦══╦╗╔╦╗╔╦═╗║║╔╗║║──╔══╦══╦╦══╗
//          %%%%%%%%%%        %%%%%%        ║║─╔╣╔╗╠╣╔╗║╚╝║║║║╔╗╣╚╝╝║║─╔╣╔╗║╔╗╠╣╔═╝ \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
//         %%%%%%%    %%%%%%%%%%%%*%%%      ║╚═╝║║║║║╚╝║║║║╚╝║║║║╔╗╗║╚═╝║╚╝║╚╝║║╚═╗ /////////////////////////////////////////////////////////////////
//        %%%%% %%%%%%%%%%%%%%%%%%%%%%%     ╚═══╩╝╚╩╣╔═╩╩╩╩══╩╝╚╩╝╚╝╚═══╩══╩═╗╠╩══╝
//       %%%%*%%%%%%%%%%%%%  %%%%%%%%%      ────────║║─────────────────────╔═╝║
//       %%%%%%%%%%%%%%%%%%%    %%%%%%%%%   ────────╚╝─────────────────────╚══╝
//       %%%%%%%%%%%%%%%%                   c h i p m u n k l o g i c . c o m
//       %%%%%%%%%%%%%%
//         %%%%%%%%%
//           %%%%%%%%%%%%%%%%  ----------------------------------------------------------------------------------------------------------------------
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% 
//----%% File Name        : alu.sv
//----%% Module Name      : ALU                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : ALU used by Execution Unit (EXU) of PQR5 Core. The ALU supports all RV32I integer computation instructions.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Feb-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
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
   input  logic             clk      ,  // Clock
   input  logic             aresetn  ,  // Asynchronous Reset; active-low
   input  logic             i_stall  ,  // Stall signal
   input  logic             i_bubble ,  // Bubble in
   input  logic [`XLEN-1:0] i_op0    ,  // Operand-0
   input  logic [`XLEN-1:0] i_op1    ,  // Operand-1
   input  logic [3:0]       i_opcode ,  // Opcode
   output logic [`XLEN-1:0] o_result ,  // Result
   output logic             o_bubble    // Bubble out
);

//===================================================================================================================================================
// Combinatorial logic to compute result
//===================================================================================================================================================
logic [`XLEN-1:0] result ;  // ALU result
logic             bubble ;  // Bubble

always_comb begin
   bubble = i_bubble ;
   case (i_opcode)
      // Legal ALU instructions
      ALU_ADD  : result = i_op0 + i_op1 ; 
      ALU_SUB  : result = i_op0 - i_op1 ;
      ALU_SLT  : result = {{`XLEN-1{1'b0}}, (signed'(i_op0) < signed'(i_op1))} ;
      ALU_SLTU : result = {{`XLEN-1{1'b0}}, (i_op0 < i_op1)} ;
      ALU_XOR  : result = i_op0 ^ i_op1 ;
      ALU_OR   : result = i_op0 | i_op1 ;
      ALU_AND  : result = i_op0 & i_op1 ;
      ALU_SLL  : result = i_op0 << i_op1[4:0] ;
      ALU_SRL  : result = i_op0 >> i_op1[4:0] ;
      ALU_SRA  : result = (signed'(i_op0)) >>> i_op1[4:0] ;
      default  : begin result = '0 ; bubble = 1'b1 ; end  // Insert bubble on illegal ALU instruction  	
   endcase
end

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

assign o_result = result_rg ;
assign o_bubble = bubble_rg ;

endmodule
//###################################################################################################################################################
//                                                                     A L U                                          
//###################################################################################################################################################