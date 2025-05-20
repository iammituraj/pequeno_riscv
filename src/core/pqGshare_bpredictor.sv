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
//----%% File Name        : pqGshare_bpredictor.sv
//----%% Module Name      : Pequeno Gshare Branch Predictor (PQGBP)                                    
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : PQGBP is a dynamic branch predictor based on global branch history logged in a 8-bit Global History Register (GHR)
//----%%                    and a 64-entry Branch History Table (BHT). For indexing, 6-bit hash function(PC, GHR) is used.
//----%%
//----%%                    Branch History Table (BHT) 
//----%%                    ==========================
//----%%                    BHT stores the recent history of executed branches.
//----%%                    BHT is indexed by the hash(PC, GHR) which uses folded XOR for enhanced entropy.
//----%%                    Each entry in BHT stores a 2-bit saturating counter that logs the history of the branch (taken or not taken).
//----%%                    2'b00 - Strongly not taken
//----%%                    2'b01 - Weakly not taken
//----%%                    2'b10 - Weakly taken
//----%%                    2'b11 - Strongly taken
//----%%
//----%%                    1. PQGBP generates a hash based on the fetched PC and GHR to index into BHT.
//----%%                    2. PQGBP predicts the branch as taken if BHT entry >= 2'b10, else not taken.
//----%%                    3. On branch resolution - GHR is updated with the actual branch outcome.
//----%%                                            - BHT is updated to bias towards the actual branch outcome.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : May-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                             P E Q U E N O   G S H A R E   B R A N C H   P R E D I C T O R                                      
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Module definition
module pqGshare_bpredictor#(
   // Configurable Parameters
   parameter  BHT_TYPE = `BHT_TYPE  // BHT configuration
)(
   // Clock and Reset
   input  logic             clk               ,  // Clock
   input  logic             aresetn           ,  // Asynchronous Reset; active-low

   // Request Interface (from the fetch)
   input  logic [`XLEN-1:0] i_req_pc          ,  // PC requested for prediction
   input  logic             i_stall           ,  // Stall
   input  logic             i_is_op_jal       ,  // JAL instruction?
   input  logic             i_is_op_branch    ,  // Branch instruction? 
   input  logic [`XLEN-1:0] i_immJ            ,  // Sign-extended Immediate (Jump) 
   input  logic [`XLEN-1:0] i_immB            ,  // Sign-extended Immediate (Branch)
   input  logic             i_instr_valid     ,  // Instruction valid

   // Branch Prediction Interface
   output logic [`XLEN-1:0] o_branch_pc       ,  // Branch PC   
   output logic             o_pred_btaken     ,  // Predicted branch taken status; '0'- not taken, '1'- taken   
   output logic             o_flush           ,  // Flush generated on branch taken

   // Update Interface (from branch resolution)
   input  logic             i_update          ,  // Update BHT
   input  logic [`XLEN-1:0] i_update_pc       ,  // PC for which BHT to be updated
   input  logic             i_actual_btaken      // Actual branch taken status
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic [7:0] req_pc_lower    ;  // PC lower bits for indexing (prediction)
logic [5:0] req_idx         ;  // Index used for prediction
logic       req_en          ;  // Request enable
logic [1:0] bhist           ;  // Branch history read from BHT
logic       is_bhist_taken  ;  // Flags if branch history indicates "taken"

logic [5:0] upd_pc_lower    ;  // PC lower bits for indexing (update)
logic [5:0] upd_idx         ;  // Index used for updating
logic [1:0] upd_val         ;  // Updated value in BHT
logic       upd_en          ;  // Update enable

logic [7:0] ghr_ff          ;  // GHR

logic       en_bht_ff       ;  // Enable BHT
logic       en_b_flush_ff   ;  // Enable branch flush
logic       is_jal_ff       ;  // Flags valid JAL instr
logic       en_jal_flush_ff ;  // Enable JAL flush
logic       bp_flush        ;  // Branch Predict flush (BP flush)

//-------------------------------------------------------------------
// BHT instance
//-------------------------------------------------------------------
bhistory_table#(
   .TGT    (BHT_TYPE),
   .DPT    (64),
   .RSTVAL (2'b01)  // 2'b01 bias is the best fit for most of the embedded applications...
) inst_bhistory_table (
   .clk       (clk),
   .aresetn   (aresetn),
   
   .i_wren    (),
   .i_waddr   (),
   .i_wdata   (),

   .i_rden0   (req_en)  ,
   .i_raddr0  (req_idx) ,
   .o_rdata0  (bhist)   ,
   .i_rden1   (),
   .i_raddr1  (),
   .o_rdata1  ()
);

// Valid Branch instr?
logic is_valid_branch ;
assign is_valid_branch = i_instr_valid & i_is_op_branch ;

// Valid JAL instr?
logic is_valid_jal ;
assign is_valid_jal = i_instr_valid & i_is_op_jal ;

// Request to BHT
assign req_pc_lower = i_req_pc[7:0];
assign req_idx      = hash_bht(req_pc_lower, ghr_ff);
assign req_en       = is_valid_branch & ~i_stall ;

//===================================================================================================================================================
// Logic to pipe Branch Prediction control signals
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      en_bht_ff <= 1'b0 ; 
      is_jal_ff <= 1'b0 ;
   end  
   // Out of reset
   else if (!i_stall) begin
      en_bht_ff <= is_valid_branch ;  // BHT needs to be enabled only on branch instructions...
      is_jal_ff <= is_valid_jal    ;
   end
end

// Branch Flush enable
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      en_b_flush_ff <= 1'b0 ; 
   end  
   // Out of reset
   else begin
      if      (bp_flush) begin en_b_flush_ff <= 1'b0            ; end  // Flush should always de-assert in the next cycle...
      else if (!i_stall) begin en_b_flush_ff <= is_valid_branch ; end  // Flush is enabled on valid branch
   end
end

// JAL Flush enable
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      en_jal_flush_ff <= 1'b0 ; 
   end  
   // Out of reset
   else begin
      if      (bp_flush) begin en_jal_flush_ff <= 1'b0         ; end  // Flush should always de-assert in the next cycle...
      else if (!i_stall) begin en_jal_flush_ff <= is_valid_jal ; end  // Flush is enabled on valid JAL
   end
end

//===================================================================================================================================================
// Logic to generate Branch taken status, BP flush
//===================================================================================================================================================
assign is_bhist_taken = (bhist[1] == 1'b1);                                     // >=2'b10? implies branch should be taken...
assign o_pred_btaken  = (is_bhist_taken && en_bht_ff)     || is_jal_ff       ;  // JAL => branch always taken, else BHT dependent...
assign bp_flush       = (is_bhist_taken && en_b_flush_ff) || en_jal_flush_ff ;  // Generate flush when BHT predicts branch taken or JAL 
assign o_flush        =  bp_flush ;

//===================================================================================================================================================
// Logic to update GHR
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if (!aresetn) begin
      ghr_ff <= '0;   
   end  
   else if (i_update) begin
      ghr_ff <= {ghr_ff[6:0], i_actual_btaken};  // The status of the resolved branch is logged into the LSB of GHR...
   end
end

// Branch PC computation
logic [`XLEN-1:0] req_pc_offset ;  // Offset to be added to PC after prediction
logic [`XLEN-1:0] branch_pc ;  // Branch PC
always_comb begin   
   if      (i_is_op_jal)    begin req_pc_offset = i_immJ ; end  // JAL
   else if (i_is_op_branch) begin req_pc_offset = i_immB ; end  // Branch
   else                     begin req_pc_offset = '0     ; end  // PC
end
assign branch_pc = i_req_pc + req_pc_offset ;

// Synchronous logic to register Branch PC and pipe it forward
logic [`XLEN-1:0] branch_pc_rg ;  // Branch PC registered
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      branch_pc_rg <=  '0 ;
   end
   // Out of reset
   else if (!i_stall) begin  
      branch_pc_rg <= branch_pc ;
   end
end
assign o_branch_pc = branch_pc_rg ;

//===================================================================================================================================================
// User-defined functions
//===================================================================================================================================================
// Hash generation
function automatic logic [5:0] hash_bht (
   input logic [7:0] pc,   
   input logic [7:0] ghr
);
    logic [5:0] pc_part;
    logic [5:0] ghr_fold;
begin
    pc_part  = pc[7:2]             ;  // Only pc[7:2] is meaningful (instructions are 4-byte aligned)        
    ghr_fold = ghr[7:2] ^ ghr[5:0] ;  // Fold 8-bit GHR to 6 bits to add more entropy
    hash_bht = pc_part  ^ ghr_fold ;  // Final hash
end
endfunction

endmodule
//###################################################################################################################################################
//                                             P E Q U E N O   G S H A R E   B R A N C H   P R E D I C T O R                                      
//###################################################################################################################################################