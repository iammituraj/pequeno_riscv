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
//----%% File Name        : exu_branch_unit.sv
//----%% Module Name      : EXU Branch Unit (EXU-BU)                                          
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This is the branch unit used by Execution Unit (EXU) of PQR5 Core. Decodes all Jump and Branch instructions and generate branch
//----%%                    status signals.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Feb-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         E X U  -   B R A N C H   U N I T                                          
//###################################################################################################################################################
// Header files
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module exu_branch_unit #(
   // Configurable parameters
   parameter PC_INIT = `PC_INIT  // Init PC on reset
)
(
   // Clock and Reset
   input  logic             clk              ,  // Clock
   input  logic             aresetn          ,  // Asynchronous Reset; active-low

   // Control signals
   input  logic             i_stall          ,  // Stall signal
   input  logic [`XLEN-1:0] i_pc             ,  // Incoming PC
   input  logic             i_bubble         ,  // Bubble in
   input  logic             is_j_type        ,  // J-type instruction flag
   input  logic             is_b_type        ,  // B-type instruction flag
   input  logic [6:0]       i_opcode         ,  // Opcode
   input  logic [2:0]       i_funct3         ,  // funct3
   input  logic [19:0]      i_immJ           ,  // J-type immediate
   input  logic [11:0]      i_immI           ,  // I-type immediate
   input  logic [11:0]      i_immB           ,  // B-type immediate
   input  logic [`XLEN-1:0] i_op0            ,  // Operand-0 from register file
   input  logic [`XLEN-1:0] i_op1            ,  // Operand-1 from register file
   input  logic             i_branch_taken   ,  // Current branch taken status (from upstream pipeline)

   // Status signals
   output logic [`XLEN-1:0] o_nxt_instr_pc   ,  // Next instruction PC; address used to return from subroutines after JAL/JALR
   output logic             o_bubble         ,  // Bubble out
   output logic             o_branch_taken   ,  // Branch taken status after execution; '0'- not taken, '1'- taken  
   output logic [`XLEN-1:0] o_branch_pc      ,  // Branch PC; PC to branch to
   output logic             o_flush             // Flush signal
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic [`XLEN-1:0] nxt_instr_pc_rg               ;  // Next instruction PC
logic             branch_taken, branch_taken_rg ;  // Branch taken status registered
logic [`XLEN-1:0] branch_pc, branch_pc_rg       ;  // Branch PC
logic             bubble, bubble_rg             ;  // Bubble
logic             flush, flush_rg               ;  // Flush

logic [`XLEN-1:0] immJ, immI, immB              ;  // J/I/B-type immediates sign-extended                            
logic [`XLEN-1:0] pc_plus_4                     ;  // PC+4           
logic [`XLEN-1:0] pc_plus_immJ, pc_plus_immB    ;  // PC+immJ and PC+immB        
logic [`XLEN-1:0] op0_plus_immI                 ;  // op0+immI  

logic             is_op_jalr                    ;  // JALR instruction flag  
logic             is_op0_eq_op1, is_op0_lt_op1  ;  // Unsigned comparison flag 
logic             is_sign_op0_lt_op1            ;  // Signed comparison flag 
logic             is_branch_taken_diff          ;  // Branch taken difference flag

//===================================================================================================================================================
// Synchronous logic to register instruction, PC, branch status signals
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      nxt_instr_pc_rg <= PC_INIT ;
      bubble_rg       <= 1'b1    ;
      branch_taken_rg <= 1'b0    ;
      branch_pc_rg    <= PC_INIT ;   
      flush_rg        <= 1'b0    ;        
   end
   // Out of reset
   else if (!i_stall) begin 
      nxt_instr_pc_rg <= pc_plus_4    ;
      bubble_rg       <= bubble       ;     
      branch_taken_rg <= branch_taken ;
      branch_pc_rg    <= branch_pc    ;
      flush_rg        <= flush        ;      
   end
end

//===================================================================================================================================================
// Combinatorial logic for branch decoding
//===================================================================================================================================================
// - No flush for JAL because it is already handled by FU 
// - JALR always generates flush
// - Branch instructions: flush iff current branch status != status computed after execution 
//===================================================================================================================================================
always_comb begin

   // JAL
   if (is_j_type && !i_bubble) begin
      branch_taken = 1'b1         ;
      branch_pc    = pc_plus_immJ ;
      flush        = 1'b0         ;
   end
   // JALR
   else if (is_op_jalr && !i_bubble) begin
      branch_taken = 1'b1 ;
      branch_pc    = op0_plus_immI & {{`XLEN-1{1'b1}}, 1'b0} ;  // LSb should be cleared to 0 for JALR
      flush        = 1'b1 ;  
   end
   // Branch Instructions
   else if (is_b_type && !i_bubble) begin
      case (i_funct3)
         F3_BEQ  : begin
                      branch_taken = is_op0_eq_op1 ;
                      branch_pc    = branch_taken ? pc_plus_immB : pc_plus_4 ;
                      flush        = is_branch_taken_diff ;                  
                   end                       
         F3_BNE  : begin
                      branch_taken = ~is_op0_eq_op1 ; 
                      branch_pc    = branch_taken ? pc_plus_immB : pc_plus_4 ;
                      flush        = is_branch_taken_diff ;  
                   end
         F3_BLT  : begin
                      branch_taken = is_sign_op0_lt_op1 ;
                      branch_pc    = branch_taken ? pc_plus_immB : pc_plus_4 ;
                      flush        = is_branch_taken_diff ;
                   end
         F3_BGE  : begin
                      branch_taken = ~is_sign_op0_lt_op1 ; 
                      branch_pc    = branch_taken ? pc_plus_immB : pc_plus_4 ;
                      flush        = is_branch_taken_diff ;
                   end
         F3_BLTU : begin
                      branch_taken = is_op0_lt_op1 ;
                      branch_pc    = branch_taken ? pc_plus_immB : pc_plus_4 ;
                      flush        = is_branch_taken_diff ;
                   end
         F3_BGEU : begin
                      branch_taken = ~is_op0_lt_op1 ; 
                      branch_pc    = branch_taken ? pc_plus_immB : pc_plus_4 ;
                      flush        = is_branch_taken_diff ;
                   end
         default : begin  // Illegal Branch instruction
                      branch_taken = 1'b0      ;
                      branch_pc    = pc_plus_4 ;
                      flush        = 1'b0      ;     
                   end            
      endcase            
   end
   // Not Jump/Branch instruction, invalid instruction
   else begin
      branch_taken = 1'b0      ;
      branch_pc    = pc_plus_4 ;  
      flush        = 1'b0      ; 
   end

end

//===================================================================================================================================================
// Continuous assignments
//===================================================================================================================================================
assign is_op_jalr = (i_opcode == OP_JALR) ;
assign bubble     = (is_j_type || is_op_jalr)? i_bubble : 1'b1 ;  // Every instruction inserts bubble except JAL/JALR
                                                                  // JAL/JALR instructions need to propagate fwd in pipeline for writeback
                                                                  // Invalid/Branch instructions need not propagate fwd in pipeline 

assign immJ          = {{(`XLEN-20){i_immJ[19]}}, i_immJ[18:0], 1'b0} ;  // Sign-extend after x2
assign immI          = {{(`XLEN-12){i_immI[11]}}, i_immI}             ;  // Sign-extend
assign immB          = {{(`XLEN-12){i_immB[11]}}, i_immB[10:0], 1'b0} ;  // Sign-extend after x2
assign pc_plus_4     = i_pc  + `XLEN'(4) ;
assign pc_plus_immJ  = i_pc  + immJ      ;
assign op0_plus_immI = i_op0 + immI      ;
assign pc_plus_immB  = i_pc  + immB      ;

assign is_op0_eq_op1        = (i_op0 == i_op1)                  ;
assign is_op0_lt_op1        = (i_op0 < i_op1)                   ;  // Unsigned comparison
assign is_sign_op0_lt_op1   = (signed'(i_op0) < signed'(i_op1)) ;  // Signed comparison
assign is_branch_taken_diff = branch_taken ^ i_branch_taken     ;  // Compare current and computed status and flag if different 

// Outputs
assign o_nxt_instr_pc = nxt_instr_pc_rg ;
assign o_branch_taken = branch_taken_rg ;
assign o_branch_pc    = branch_pc_rg    ;
assign o_bubble       = bubble_rg       ;
assign o_flush        = flush_rg        ;

endmodule
//###################################################################################################################################################
//                                                         E X U  -   B R A N C H   U N I T                                          
//###################################################################################################################################################