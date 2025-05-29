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
//----%% File Name        : exu_branch_unit.sv
//----%% Module Name      : EXU Branch Unit (EXU-BU)                                          
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This is the branch unit used by Execution Unit (EXU) of PQR5 Core. Decodes all Jump and Branch instructions and generate
//----%%                    branch status signals.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : May-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
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
   parameter PC_INIT         = `PC_INIT,          // Init PC on reset
   parameter IS_BPREDICT_DYN = `IS_BPREDICT_DYN,  // Dynamic Branch Predictor?
   parameter GHRW            = `GHRW,             // GHR width
   parameter BPCW            = `BHT_IDW+2         // PC width to index BHT
)
(
   // Clock and Reset
   input  logic             clk              ,  // Clock
   input  logic             aresetn          ,  // Asynchronous Reset; active-low

   // Control signals
   input  logic             i_stall          ,  // Stall signal
   input  logic [`XLEN-1:0] i_pc             ,  // Incoming PC
   input  logic             i_bubble         ,  // Bubble in
   input  logic             i_is_b_type      ,  // B-type instruction flag
   input  logic             i_is_jalr        ,  // JALR flag
   input  logic             i_is_j_or_jalr   ,  // J/JALR instruction flag
   input  logic [2:0]       i_funct3         ,  // funct3
   input  logic [11:0]      i_immI           ,  // I-type immediate
   input  logic [11:0]      i_immB           ,  // B-type immediate
   input  logic [`XLEN-1:0] i_op0            ,  // Operand-0 from register file
   input  logic [`XLEN-1:0] i_op1            ,  // Operand-1 from register file
   input  logic             i_op0_lt_op1     ,  // Unsigned comparison flag: op0 < op1 ? from ALU
   input  logic             i_sign_op0_lt_op1,  // Signed comparison flag: signed(op0) < signed(op1) ? from ALU
   input  logic             i_branch_taken   ,  // Branch taken status from Branch Predictor

   `ifdef DBG
   // Debug signals
   output logic             o_dbg_is_b_instr    ,  // Branch instruction flag
   output logic             o_dbg_is_pred_wrong ,  // Prediction wrong?
   `endif

   `ifdef BPREDICT_DYN
   // Branch Predictor Interface
   input  logic [GHRW-1:0]  i_bp_ghr_snapshot,  // GHR snapshot for which prediction was done...
   output logic             o_bp_upd_ghr     ,  // Update GHR signal
   output logic             o_bp_upd_bht     ,  // Update BHT signal
   output logic [BPCW-1:0]  o_bp_idx_pc      ,  // PC to index BHT
   output logic [GHRW-1:0]  o_bp_idx_ghr     ,  // GHR to index BHT
   output logic             o_bp_sts_btaken  ,  // Branch taken status after branch resolution
   `endif

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
logic             bp_branch_taken_rg            ;  // Branch Predictor status registered
logic             en_branch_comp_rg             ;  // Branch comparison enable
logic [`XLEN-1:0] branch_pc, branch_pc_rg       ;  // Branch PC
logic             bubble, bubble_rg             ;  // Bubble
logic             flush                         ;  // Flush

logic [`XLEN-1:0] immI, immB                    ;  // J/I/B-type immediates sign-extended                            
logic [`XLEN-1:0] pc_plus_4                     ;  // PC+4           
logic [`XLEN-1:0] pc_plus_immB                  ;  // PC+immJ and PC+immB  
logic [`XLEN-1:0] op0_plus_immI                 ;  // op0+immI  

logic             is_op0_eq_op1, is_op0_lt_op1  ;  // Equality, Unsigned comparison flags 
logic             is_sign_op0_lt_op1            ;  // Signed comparison flag 
logic             is_branch_taken_diff          ;  // Branch taken difference flag

//===================================================================================================================================================
// Synchronous logic to register instruction, PC, branch status signals
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      nxt_instr_pc_rg    <= PC_INIT   ;
      bubble_rg          <= 1'b1      ;
      branch_taken_rg    <= 1'b0      ;
      bp_branch_taken_rg <= 1'b0      ;
      branch_pc_rg       <= PC_INIT   ;   
   end
   // Out of reset
   else if (!i_stall) begin 
      nxt_instr_pc_rg    <= pc_plus_4      ;
      bubble_rg          <= bubble         ;  
      branch_taken_rg    <= branch_taken   ;
      bp_branch_taken_rg <= i_branch_taken ;
      branch_pc_rg       <= branch_pc      ;
   end
end
// Branch compare signal generation
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      en_branch_comp_rg  <= 1'b0;
   end
   // Out of reset
   else if (flush)    begin en_branch_comp_rg <= 1'b0      ; end  // Compare signal should always de-assert in the next cycle to make flush = pulse...
   else if (!i_stall) begin en_branch_comp_rg <= ~i_bubble ; end
end

//===================================================================================================================================================
// Combinatorial logic for branch decoding & resolution
//===================================================================================================================================================
// - JAL never generates flush because it is already resolved by the Branch Predictor in FU correctly, and the branch is always taken.
// - JALR always generates flush, cz the Branch predictor is static and hence can never resolve the branch address.
//   The branch is always taken, while the Branch predictor always resolves it wrongly as not taken always.
// - Branch instructions: flush iff current branch status != status computed after execution .
//===================================================================================================================================================
always_comb begin
   case ({i_is_j_or_jalr, i_is_b_type})
      // JAL or JALR
      2'b10   : branch_taken = 1'b1 ;
      // Branch
      2'b01   : begin
                   // Which branch instruction?
                   case (i_funct3)
                      F3_BEQ  : branch_taken =  is_op0_eq_op1      ;                
                      F3_BNE  : branch_taken = ~is_op0_eq_op1      ; 
                      F3_BLT  : branch_taken =  is_sign_op0_lt_op1 ;
                      F3_BGE  : branch_taken = ~is_sign_op0_lt_op1 ;
                      F3_BLTU : branch_taken =  is_op0_lt_op1      ;
                      F3_BGEU : branch_taken = ~is_op0_lt_op1      ;
                      default : branch_taken =  1'b0               ;  // Illegal Branch instr --> Never leads to flush cz Branch Predictor should have the same branch taken status = 0
                   endcase
                end
      // Invalid instruction
      default : branch_taken = 1'b0 ;  // Never leads to flush cz Branch Predictor should have the same branch taken status = 0
   endcase
end

assign is_op0_eq_op1        = (i_op0 == i_op1)  ;  // Not implemented this in ALU as it's unused by ALU instructions, so implemented here for locality, and reduce routing delays...
assign is_op0_lt_op1        = i_op0_lt_op1      ;  // Computed from ALU
assign is_sign_op0_lt_op1   = i_sign_op0_lt_op1 ;  // Computed from ALU

// Combinatorial logic for Branch PC resolution
always_comb begin
   case ({i_is_jalr, i_is_b_type})
      2'b10   : branch_pc = op0_plus_immI & {{`XLEN-1{1'b1}}, 1'b0} ;  // LSb should be cleared to 0 for JALR
      2'b01   : branch_pc = branch_taken ? pc_plus_immB : pc_plus_4 ;
      default : branch_pc = pc_plus_4 ;
   endcase
end

// Flush generation logic
assign is_branch_taken_diff = branch_taken_rg ^ bp_branch_taken_rg     ;  // Compare the predicted and resolved branch taken status and flag if different 
assign flush                = is_branch_taken_diff & en_branch_comp_rg ;  // Generate flush if the comparison is enabled and status differ

// Bubble
assign bubble = i_is_j_or_jalr ? i_bubble : 1'b1 ;  // Every instruction inserts bubble except JAL/JALR
                                                    // JAL/JALR instructions need to propagate fwd in pipeline for writeback
                                                    // Invalid/Branch instructions need not propagate fwd in pipeline 

// Decoded immediates
assign immI          = {{(`XLEN-12){i_immI[11]}}, i_immI}             ;  // Sign-extend
assign immB          = {{(`XLEN-12){i_immB[11]}}, i_immB[10:0], 1'b0} ;  // Sign-extend after x2
assign pc_plus_4     = i_pc  + `XLEN'(4) ;
assign op0_plus_immI = i_op0 + immI      ;
assign pc_plus_immB  = i_pc  + immB      ;

// Outputs
assign o_nxt_instr_pc = nxt_instr_pc_rg ;
assign o_branch_taken = branch_taken_rg ;
assign o_branch_pc    = branch_pc_rg    ;
assign o_bubble       = bubble_rg       ;
assign o_flush        = flush           ;

///////////////////////////////////////////////////////////////////////////////
// Branch Predictor control
///////////////////////////////////////////////////////////////////////////////
`ifdef BPREDICT_DYN
logic is_legal_branch     ;  // Flags legal branch instruction
logic upd_ghr, upd_ghr_ff ;  // Update GHR signal
logic upd_bht, upd_bht_ff ;  // Update BHT signal

assign is_legal_branch = i_is_b_type && (i_funct3 != 3'b010) && (i_funct3 != 3'b011);

assign upd_ghr = (i_is_j_or_jalr || is_legal_branch) & ~i_bubble ;  // GHR must be updated on every jump/branch instr resolution
assign upd_bht = is_legal_branch & ~i_bubble ;                      // BHT must be updated on every branch instr resolution

// Update signals to Branch Predictor
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      upd_ghr_ff <= 1'b0 ;
      upd_bht_ff <= 1'b0 ;
   end
   // Out of reset
   else begin 
      upd_ghr_ff <= i_stall ? 1'b0 : upd_ghr ;  // If stalling, drive 0 so that GHR is not updated multiple times wrongly...
      upd_bht_ff <= i_stall ? 1'b0 : upd_bht ;  // If stalling, drive 0 so that BHT is not updated multiple times wrongly...
   end
end

// PC, GHR piped to BHT to index and update
logic [BPCW-1:0] bp_idx_pc_rg  ;
logic [GHRW-1:0] bp_idx_ghr_rg ;
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      bp_idx_pc_rg  <= '0 ;
      bp_idx_ghr_rg <= '0 ;
   end
   // Out of reset
   else if (!i_stall) begin 
      bp_idx_pc_rg  <= i_pc[BPCW-1:0]    ; 
      bp_idx_ghr_rg <= i_bp_ghr_snapshot ;
   end
end

// Outputs to Branch Predictor
assign o_bp_upd_ghr    = upd_ghr_ff      ;
assign o_bp_upd_bht    = upd_bht_ff      ;
assign o_bp_idx_pc     = bp_idx_pc_rg    ;
assign o_bp_idx_ghr    = bp_idx_ghr_rg   ;
assign o_bp_sts_btaken = branch_taken_rg ;

`endif//BPREDICT_DYN

// Debug signals
`ifdef DBG
logic is_b_type_rg ;  // Branch instr flag
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      is_b_type_rg  <= '0 ;
   end
   // Out of reset
   else if (!i_stall) begin is_b_type_rg <= i_is_b_type & ~i_bubble ; end
end
assign o_dbg_is_b_instr    = is_b_type_rg ;
assign o_dbg_is_pred_wrong = flush ;
`endif//DBG

endmodule
//###################################################################################################################################################
//                                                         E X U  -   B R A N C H   U N I T                                          
//###################################################################################################################################################