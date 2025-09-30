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
//----%% Description      : PQGBP is a dynamic branch predictor based on global branch history logged in a Global History Register (GHR)
//----%%                    and Branch History Table (BHT). For indexing, hash function(PC, GHR) is used.
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
//----%%                    Flush is generated on predicting branch taken.
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
   parameter  GHRW     = `GHRW,      // GHR width
   parameter  BHT_IDW  = `BHT_IDW,   // Index width of BHT
   parameter  BHT_TYPE = `BHT_TYPE,  // BHT configuration
   parameter  BHT_BIAS = `BHT_BIAS,  // BHT entries reset value

   // Derived Parameters
   localparam BHT_DPT  = 2**BHT_IDW, // BHT size (no. of entries)
   localparam BPCW     = BHT_IDW+2   // PC width to index BHT, MSb 2 bits are not used for indexing
)(
   // Clock and Reset
   input  logic             clk               ,  // Clock
   input  logic             aresetn           ,  // Asynchronous Reset; active-low

   // Request Interface (from the Fetch)
   input  logic [`XLEN-1:0] i_req_pc          ,  // PC requested for prediction
   input  logic             i_stall           ,  // Stall
   input  logic             i_is_op_jal       ,  // JAL instruction?
   input  logic             i_is_op_branch    ,  // Branch instruction? 
   input  logic [`XLEN-1:0] i_immJ            ,  // Sign-extended Immediate (Jump) 
   input  logic [`XLEN-1:0] i_immB            ,  // Sign-extended Immediate (Branch)
   input  logic             i_instr_valid     ,  // Instruction valid

   // Branch Prediction Interface (to the Fetch)
   output logic [`XLEN-1:0] o_branch_pc       ,  // Branch PC   
   output logic             o_pred_btaken     ,  // Predicted branch taken status; '0'- not taken, '1'- taken   
   output logic [GHRW-1:0]  o_ghr_snapshot    ,  // GHR snapshot for which prediction was done
   output logic             o_flush           ,  // Flush generated on branch taken

   // Update Interface (from branch resolution)
   input  logic             i_upd_ghr         ,  // Update GHR signal
   input  logic             i_upd_bht         ,  // Update BHT signal
   input  logic [BPCW-1:0]  i_upd_idx_pc      ,  // PC to index BHT for update
   input  logic [GHRW-1:0]  i_upd_idx_ghr     ,  // GHR to index BHT for update
   input  logic             i_actual_btaken      // Actual branch taken status
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic [BPCW-1:0]    req_pc_lower    ;  // PC lower bits for indexing (prediction)
logic [BHT_IDW-1:0] req_idx         ;  // Index for prediction at BHT
logic               req_en          ;  // Request enable
logic               is_valid_branch ;  // Valid Branch instr flag
logic               is_valid_jal    ;  // Valid JAL instr flag

logic [1:0]         bhist           ;  // Branch history read from BHT
logic               is_bhist_taken  ;  // Flags if branch history indicates "taken"

logic               en_bht_ff       ;  // Enable BHT
logic               en_b_flush_ff   ;  // Enable branch flush
logic               is_jal_ff       ;  // Flags valid JAL instr
logic               en_jal_flush_ff ;  // Enable JAL flush
logic               bp_flush        ;  // Branch Predict flush (BP flush)

logic [BPCW-1:0]    upd_pc_lower    ;  // PC lower bits for indexing (update)
logic [BHT_IDW-1:0] upd_idx         ;  // Index for updating at BHT
logic               upd_en          ;  // Update enable
logic [1:0]         old_bhist       ;  // Old value in BHT; current value
logic               upd_en_ff       ;  // Update enable registered
logic [BHT_IDW-1:0] upd_idx_ff      ;  // Index for updating (registered)
logic               actual_btaken_ff;  // Actual branch taken status registered
logic [1:0]         upd_bhist       ;  // Value to be updated in BHT

logic [GHRW-1:0]    ghr_ff          ;  // GHR
logic [GHRW-1:0]    ghr_p1_ff       ;  // GHR piped by 1 cycle

//-------------------------------------------------------------------------------------------------
// BHT instance
//-------------------------------------------------------------------------------------------------
bhistory_table#(
   .TGT    (BHT_TYPE),
   .DPT    (BHT_DPT) ,
   .RSTVAL (BHT_BIAS) 
) inst_bhistory_table (
   .clk       (clk),
   .aresetn   (aresetn),
   
   .i_wren    (upd_en_ff) ,
   .i_waddr   (upd_idx_ff),
   .i_wdata   (upd_bhist) ,

   .i_rden0   (req_en)    ,
   .i_raddr0  (req_idx)   ,
   .o_rdata0  (bhist)     ,
   .i_rden1   (upd_en)    ,
   .i_raddr1  (upd_idx)   ,
   .o_rdata1  (old_bhist)
);
//-------------------------------------------------------------------------------------------------

//===================================================================================================================================================
// Request to BHT and Branch Prediction
//===================================================================================================================================================
// Valid Branch instr?
assign is_valid_branch = i_instr_valid & i_is_op_branch ;

// Valid JAL instr?
assign is_valid_jal = i_instr_valid & i_is_op_jal ;

// Request signals to BHT
assign req_pc_lower = i_req_pc[BPCW-1:0];
assign req_idx      = hash_bht(req_pc_lower, ghr_ff);
assign req_en       = is_valid_branch & ~i_stall ;

// Register Branch Prediction control signals/flags, GHR, and pipe it forward
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      en_bht_ff <= 1'b0 ; 
      is_jal_ff <= 1'b0 ;
      ghr_p1_ff <= '0   ;
   end  
   // Out of reset
   else if (!i_stall) begin
      en_bht_ff <= is_valid_branch ;  // BHT needs to be enabled only on branch instructions...
      is_jal_ff <= is_valid_jal    ;
      ghr_p1_ff <= ghr_ff          ;
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

// Generation of Branch taken status, BP flush
assign is_bhist_taken = (bhist[1] == 1'b1);                                     // >=2'b10? implies branch should be taken...
assign o_pred_btaken  = (is_bhist_taken && en_bht_ff)     || is_jal_ff       ;  // JAL => branch always taken, else predicted from BHT...
assign bp_flush       = (is_bhist_taken && en_b_flush_ff) || en_jal_flush_ff ;  // Generate flush if JAL or BHT predicts branch taken
assign o_flush        =  bp_flush ;

// Branch PC computation after prediction
logic [`XLEN-1:0] req_pc_offset ;  // Offset to be added to PC after prediction
logic [`XLEN-1:0] branch_pc     ;  // Branch PC
always_comb begin   
   if      (i_is_op_jal)    begin req_pc_offset = i_immJ ; end  // JAL
   else if (i_is_op_branch) begin req_pc_offset = i_immB ; end  // Branch
   else                     begin req_pc_offset = '0     ; end  // PC
end
assign branch_pc = i_req_pc + req_pc_offset ;

// Register Branch PC and pipe it forward
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

// GHR snapshot
assign o_ghr_snapshot = ghr_p1_ff ;

//===================================================================================================================================================
// Updating BHT and GHR on Branch Resolution
//===================================================================================================================================================
// Logic to update GHR
always_ff @(posedge clk or negedge aresetn) begin
   if (!aresetn) begin
      ghr_ff <= '0;   
   end  
   else if (i_upd_ghr) begin
      ghr_ff <= {ghr_ff[GHRW-2:0], i_actual_btaken};  // The status of the resolved branch is logged into the LSB of GHR...
   end
end

// Update signals to BHT
assign upd_pc_lower = i_upd_idx_pc ;
assign upd_idx      = hash_bht(upd_pc_lower, i_upd_idx_ghr);
assign upd_en       = i_upd_bht ; 

//-------------------------------------------------------------------
// Combo logic to find the value to be updated in BHT
//-------------------------------------------------------------------
// Increment BHT entry by 1 if the branch was resolved as "taken"
// Decrement BHT entry by 1 if the branch was resolved as "not taken"
//-------------------------------------------------------------------
always_comb begin
   case ({actual_btaken_ff, old_bhist})
      3'b000  : upd_bhist = 2'b00 ;  // Saturated counter -ve direction
      3'b001  : upd_bhist = 2'b00 ;
      3'b010  : upd_bhist = 2'b01 ;
      3'b011  : upd_bhist = 2'b10 ;
      3'b100  : upd_bhist = 2'b01 ;
      3'b101  : upd_bhist = 2'b10 ;
      3'b110  : upd_bhist = 2'b11 ;
      default : upd_bhist = 2'b11 ;  // Saturated counter +ve direction
   endcase  
end

// Register BHT update control signals/flags and pipe it forward
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      upd_idx_ff       <= '0   ;
      upd_en_ff        <= 1'b0 ;
      actual_btaken_ff <= 1'b0 ;
   end
   // Out of reset
   else begin
      upd_idx_ff       <= upd_idx ;
      upd_en_ff        <= upd_en  ;
      actual_btaken_ff <= i_actual_btaken ;
   end
end

//===================================================================================================================================================
// User-defined functions
//===================================================================================================================================================
// Hash generation to index BHT
function automatic logic [BHT_IDW-1:0] hash_bht (
   input logic [BPCW-1:0] pc,   
   input logic [GHRW-1:0] ghr
);
    logic [BHT_IDW-1:0] pc_part  ;
    logic [BHT_IDW-1:0] ghr_fold ;
begin
    // Msb 2 bits are assumed 0, because instructions are word-aligned... So, it's disregarded for better BHT utilization
    pc_part = pc[BPCW-1:2];

    ghr_fold = '0;
    for (integer i=0; i<GHRW; i++) begin
        ghr_fold = ghr_fold ^ (ghr[i] << (i % BHT_IDW));
    end

    // Final XOR for GShare indexing
    hash_bht = pc_part ^ ghr_fold;
end
endfunction

endmodule
//###################################################################################################################################################
//                                             P E Q U E N O   G S H A R E   B R A N C H   P R E D I C T O R                                      
//###################################################################################################################################################
