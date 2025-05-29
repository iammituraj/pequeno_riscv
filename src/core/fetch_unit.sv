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
//----%% File Name        : fetch_unit.sv
//----%% Module Name      : Fetch Unit (FU)                                          
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Instruction Fetch Unit (FU) of PQR5 Core. 
//----%%                    # Supports interface to fetch instructions from instruction memory/cache controller in-order.
//----%%                    # Branch prediction is supported, supports basic branch, stall, and flush mechanisms on branching.
//----%%                    # Sends the fetched instruction and branch prediction signals as payload to Decode Unit (DU).
//----%%                    # Inserts bubbles (NOPs) into pipelines when idle ie., when no instruction is available to be fetched.
//----%%                    # Pipeline latency = 2 cycles
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : May-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                              F E T C H   U N I T                                         
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module fetch_unit #(
   // Configurable parameters
   parameter PC_INIT         = `PC_INIT        ,  // Init PC on reset
   parameter IS_BPREDICT_DYN = `IS_BPREDICT_DYN,  // Dynamic Branch Predictor?
   parameter BHT_IDW         = `BHT_IDW        ,  // BHT index width
   parameter BHT_TYPE        = `BHT_TYPE       ,  // BHT target configuration (for Dynamic Branch Predictor)
   parameter GHRW            = `GHRW           ,  // GHR width

   // Derived parameters
   localparam BPCW           = BHT_IDW+2          // PC width to index BHT
)
(   
   // Clock and Reset  
   input  logic             clk                ,  // Clock
   input  logic             aresetn            ,  // Asynchronous Reset; active-low
   
   `ifdef DBG
   // Debug Interface  
   output logic [2:0]       o_fu_dbg           ,  // Debug signal
   `endif

   // Instruction Memory/Cache Interface (IMEMIF)
   output logic [`XLEN-1:0] o_imem_pc          ,  // PC to IMEMIF
   output logic             o_imem_pc_valid    ,  // PC valid
   input  logic             i_imem_stall       ,  // Stall signal from IMEMIF 

   input  logic [`XLEN-1:0] i_imem_pc          ,  // PC from IMEMIF; corresponding to the instruction packet
   input  logic [`ILEN-1:0] i_imem_pkt         ,  // Instruction packet from IMEMIF
   input  logic             i_imem_pkt_valid   ,  // Instruction packet valid
   output logic             o_imem_stall       ,  // Stall signal to IMEMIF
   output logic             o_imem_flush       ,  // Flush signal to IMEMIF

   // Interface with Decode Unit (DU)
   output logic [`XLEN-1:0] o_du_pc            ,  // PC to DU
   output logic [`ILEN-1:0] o_du_instr         ,  // Instruction fetched and sent to DU
   output logic             o_du_br_taken      ,  // Branch taken status to DU; '0'- not taken, '1'- taken
   `ifdef BPREDICT_DYN
   output logic [GHRW-1:0]  o_du_ghr_snapshot  ,  // GHR snapshot to DU
   `endif
   output logic             o_du_bubble        ,  // Bubble to DU
   input  logic             i_du_stall         ,  // Stall signal from DU

   // Interface with Execution Unit (EXU)
   `ifdef BPREDICT_DYN
   input  logic             i_exu_bp_upd_ghr   ,  // Update GHR signal
   input  logic             i_exu_bp_upd_bht   ,  // Update BHT signal
   input  logic [BPCW-1:0]  i_exu_bp_idx_pc    ,  // PC to index BHT
   input  logic [GHRW-1:0]  i_exu_bp_idx_ghr   ,  // GHR to index BHT
   input  logic             i_exu_bp_sts_btaken,  // Branch taken status after branch resolution
   `endif

   input  logic             i_exu_bu_flush     ,  // Flush signal from EXU-BU
   input  logic [`XLEN-1:0] i_exu_bu_pc           // Branch PC from EXU-BU
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// PC generation related
logic [`XLEN-1:0] pc_rg              ;  // PC to IMEMIF
logic             pc_valid_rg        ;  // PC valid
logic             pc_rst_flag_rg     ;  // Flag to indicate if PC is coming out of reset
logic [`XLEN-1:0] pc_plus_four       ;  // PC+4
logic [`XLEN-1:0] nxt_pc             ;  // Next PC to IMEMIF

// Instruction buffers
logic [`ILEN-1:0] instr_rg [1]       ;  // Instruction buffer with one entry (Buffer-1)
logic             instr_valid_rg [1] ;  // Instruction valid corresponding to instruction buffer entries
logic [`XLEN-1:0] instr_pc_rg [1]    ;  // PC corresponding to instruction buffer entries

// Branch logic specific
logic             branch_taken       ;  // To flag that branch has to be taken
logic             bp_flush           ;  // Branch predictor flush
logic [`XLEN-1:0] branch_pc          ;  // Branch PC; PC to branch to
logic [`ILEN-1:0] instr              ;  // Buffer-1 instruction
logic             instr_valid        ;  // Buffer-1 instruction valid
logic [`XLEN-1:0] instr_pc           ;  // Buffer-1 instruction PC
logic [6:0]       op                 ;  // Opcode in Buffer-1 instruction
logic [2:0]       funct3             ;  // funct3 in Buffer-1 instruction
logic [`XLEN-1:0] immJ, immB         ;  // Sign-extended Immediate (Jump/Branch) in Buffer-1 instruction
logic             is_op_jal          ;  // To flag if JAL instruction in Buffer-1
logic             is_op_branch       ;  // To flag if branch instruction in Buffer-1

// Stall logic specific
logic             stall              ;  // Local stall generated by FU
logic             fu_stall_ext       ;  // External stall generated by FU to upstream pipeline

// Flush logic specific
logic             flush              ;  // Local flush generated by FU
logic             fu_flush_ext       ;  // External flush generated by FU to upstream pipeline

//===================================================================================================================================================
// Synchronous logic to generate PC to fetch instruction from IMEMIF
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      pc_rg          <= '0   ; 
      pc_valid_rg    <= 1'b0 ; 
      pc_rst_flag_rg <= 1'b1 ;         
   end   
   // Out of reset
   else begin
      // PC 
      if      (i_exu_bu_flush) begin pc_rg <= i_exu_bu_pc ; end  // Request EXU-BU PC on flush; highest priority
      else if (bp_flush)       begin pc_rg <= branch_pc   ; end  // Request Branch PC if branch taken
      else if (!i_imem_stall)  begin pc_rg <= nxt_pc      ; end  // Request PC+4 
      
      // PC valid
      if (!i_imem_stall) begin pc_valid_rg <= 1'b1 ;  end  // Always valid after coming out of reset

      // PC reset flag
      if (!i_imem_stall) begin pc_rst_flag_rg <= 1'b0 ; end              
   end
end 

// Next PC to IMEMIF
assign pc_plus_four = pc_rg + `XLEN'(4) ;
assign nxt_pc       = pc_rst_flag_rg ? PC_INIT : pc_plus_four ;

//===================================================================================================================================================
// Synchronous logic to buffer instruction at Instruction Buffer-1
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      instr_rg      [0] <= `INSTR_NOP ;
      instr_valid_rg[0] <= 1'b0       ;
      instr_pc_rg   [0] <= PC_INIT    ;
   end
   // Out of reset
   else begin 
      // Instruction Buffer-1 
      if (!stall) begin instr_rg[0] <= i_imem_pkt ; end  // Pipe forward...
      
      // Instruction Buffer-1 valid
      if      (flush)              begin instr_valid_rg[0] <= 1'b0 ; end              // Invalidate on external flush; highest priority 
      else if (bp_flush && !stall) begin instr_valid_rg[0] <= 1'b0 ; end              // Invalidate on BP flush iff not stalling
      else if (!stall)             begin instr_valid_rg[0] <= i_imem_pkt_valid ; end  // Pipe forward packet valid... 

      // Instruction Buffer-1 PC
      if (!stall) begin instr_pc_rg[0] <= i_imem_pc ; end             
   end
end

//===================================================================================================================================================
// Branch prediction logic
// -----------------------
// Handles all Jump, Branch instructions.
// Generates branch taken status, which is later validated during branch resolution at Execution Unit (EXU).
//===================================================================================================================================================
generate
if (!IS_BPREDICT_DYN) begin : GEN_BPREDICT_STT
   // Static Branch Predictor
   static_bpredictor inst_static_bpredictor(
      .clk            (clk)          ,
      .aresetn        (aresetn)      ,
      
      .i_pc           (instr_pc)     ,            
      .i_stall        (stall)        ,
      .i_is_op_jal    (is_op_jal)    ,    
      .i_is_op_branch (is_op_branch) ,   
      .i_immJ         (immJ)         ,      
      .i_immB         (immB)         , 
      .i_instr_valid  (instr_valid & ~i_exu_bu_flush),  // Flush should immediately invalidate to avoid any potential bp flush in the next clock cycle... 
   
      .o_branch_pc    (branch_pc)    ,  
      .o_branch_taken (branch_taken) ,
      .o_flush        (bp_flush)
   );
end else begin : GEN_BPREDICT_DYN
   // Pequeno Gshare Dynamic Branch Predictor
   pqGshare_bpredictor#(
      .GHRW     (GHRW),
      .BHT_IDW  (BHT_IDW),
      .BHT_TYPE (BHT_TYPE)
   ) inst_pqGshare_bpredictor (
      .clk            (clk)          ,
      .aresetn        (aresetn)      ,
   
      .i_req_pc       (instr_pc)     ,   
      .i_stall        (stall)        ,
      .i_is_op_jal    (is_op_jal)    ,    
      .i_is_op_branch (is_op_branch) ,  
      .i_immJ         (immJ)         ,      
      .i_immB         (immB)         ,  
      .i_instr_valid  (instr_valid & ~i_exu_bu_flush),  // Flush should immediately invalidate to avoid any potential bp flush in the next clock cycle... 
   
      .o_branch_pc    (branch_pc)    ,
      .o_pred_btaken  (branch_taken) ,
      .o_ghr_snapshot (o_du_ghr_snapshot),   
      .o_flush        (bp_flush)     ,
      
      .i_upd_ghr      (i_exu_bp_upd_ghr),
      .i_upd_bht      (i_exu_bp_upd_bht),
      .i_upd_idx_pc   (i_exu_bp_idx_pc) ,
      .i_upd_idx_ghr  (i_exu_bp_idx_ghr),
      .i_actual_btaken(i_exu_bp_sts_btaken)
   );
end  //GEN_BPREDICT
endgenerate

assign instr        = i_imem_pkt        ;
assign instr_valid  = i_imem_pkt_valid  ;
assign instr_pc     = i_imem_pc         ;
assign immJ         = {{(`XLEN-20){instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0} ;
assign immB         = {{(`XLEN-12){instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}   ;
assign op           = instr[6:0]        ;
assign funct3       = instr[14:12]      ;
assign is_op_jal    = (op == OP_JAL)    ;  
assign is_op_branch = (op == OP_BRANCH) && (funct3 != 3'b010) && (funct3 != 3'b011) ;

//===================================================================================================================================================
//  Stall logic
//===================================================================================================================================================
assign stall        = i_du_stall & instr_valid_rg[0] ;  // Only DU can stall FU from outside.
                                                        // Conditioned with valid to burst unwanted pipeline bubbles
assign fu_stall_ext = stall        ;
assign o_imem_stall = fu_stall_ext ;  // Stall signal to IMEMIF 

//===================================================================================================================================================
//  Flush logic
//===================================================================================================================================================
assign flush        = i_exu_bu_flush   ;  // Only EXU-BU can flush FU from outside
assign fu_flush_ext = flush | bp_flush ;  // Any flush should be propagated to the upstream...
assign o_imem_flush = fu_flush_ext     ;  // Flush signal to IMEMIF

//===================================================================================================================================================
//  All other outputs from FU
//===================================================================================================================================================
`ifdef DBG
// Debug Interface
assign o_fu_dbg = {bp_flush, (is_op_branch & instr_valid), (is_op_jal & instr_valid)} ;
`endif

// PC output to IMEMIF
assign o_imem_pc       = pc_rg        ;
assign o_imem_pc_valid = pc_valid_rg  ;

// Payload to Decode Unit (DU)
assign o_du_pc       =  instr_pc_rg[0]    ; 
assign o_du_instr    =  instr_rg[0]       ;
assign o_du_br_taken =  branch_taken      ;
assign o_du_bubble   = ~instr_valid_rg[0] ;  // Insert bubble if invalid instruction

endmodule
//###################################################################################################################################################
//                                                              F E T C H   U N I T                                         
//###################################################################################################################################################