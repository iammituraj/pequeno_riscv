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
//----%%                    # Branch prediction is supported.
//----%%                    # RAS prediction is supported, supports speculative RET address prediction.
//----%%                    # Generates Branch prediction and RAS prediction flushes in the pipeline.
//----%%                    # Sends the fetched instruction and branch, RAS prediction signals as payload to Decode Unit (DU).
//----%%                    # Inserts bubbles (NOPs) into pipelines when idle ie., when no instruction is available to be fetched.
//----%%                    # Pipeline latency = 1 cycle
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Sept-2025
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
   parameter EN_BPREDICT_DYN = `IS_BPREDICT_DYN,  // Dynamic Branch Predictor enabled?
   parameter BHT_IDW         = `BHT_IDW        ,  // BHT index width
   parameter BHT_TYPE        = `BHT_TYPE       ,  // BHT target configuration (for Dynamic Branch Predictor)
   parameter BHT_BIAS        = `BHT_BIAS       ,  // BHT entries reset value
   parameter GHRW            = `GHRW           ,  // GHR width
   parameter EN_RAS          = `EN_RAS         ,  // RAS enabled?
   parameter RAS_DPT         = `RAS_DPT        ,  // RAS depth

   // Derived parameters
   localparam BPCW           = BHT_IDW+2       ,  // PC width to index BHT
   localparam RPTW           = $clog2(RAS_DPT)    // RAS pointer size 
)
(   
   // Clock and Reset  
   input  logic             clk                ,  // Clock
   input  logic             aresetn            ,  // Asynchronous Reset; active-low
   
   `ifdef DBG
   // Debug Interface  
   `ifdef RAS
   output logic [5:0]       o_fu_dbg           ,  // Debug signal
   `else
   output logic [2:0]       o_fu_dbg           ,  // Debug signal
   `endif
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

   `ifdef RAS
   input  logic             i_ras_rbk_en       ,  // RAS roll back enable
   input  logic [RPTW-1:0]  i_ras_rbk_ptr      ,  // RAS roll back pointer
   input  logic             i_ras_rbk_full     ,  // RAS roll back to full
   input  logic             i_ras_rbk_incr_ptr ,  // RAS roll back pointer increment flag
   input  logic             i_du_is_call       ,  // CALL flag from DU
   input  logic             i_du_is_ret_taken  ,  // RET taken flag from DU

   output logic             o_du_is_call       ,  // CALL flag to DU
   output logic [`XLEN-1:0] o_du_ras_ret_addr  ,  // RAS predicted RET address to DU
   output logic             o_du_ras_ret_taken ,  // RAS predicted RET taken status to DU
   output logic [RPTW-1:0]  o_du_ras_snap_ptr  ,  // RAS pointer snapshot to DU
   output logic             o_du_ras_snap_full ,  // RAS full flag snapshot to DU
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

// RAS predictor specific
`ifdef RAS
logic [4:0]       rs0, rdt             ;  // RS0, RDT decoded from instruction
logic             is_call, is_ret      ;  // CALL, RET flags
logic [`XLEN-1:0] ras_ret_addr         ;  // RAS predicted RET addr        
logic             ras_ret_taken        ;  // RAS predicted RET taken status
`endif
logic is_call_rg, is_ret_rg            ;  // CALL, RET flags registered
logic             ras_flush            ;  // RAS flush

// Stall logic specific
logic             stall           ;  // Local stall generated by FU
logic             fu_stall_ext    ;  // External stall generated by FU to upstream pipeline

// Flush logic specific
logic             flush           ;  // Local flush generated by FU
logic             bu_or_ras_flush ;  // BU or RAS flush
logic             bu_or_bp_flush  ;  // BU or BP flush
logic             bp_or_ras_flush ;  // BP or RAS flush
logic             fu_flush_ext    ;  // External flush generated by FU to upstream pipeline

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
      `ifdef RAS
      else if (ras_flush)      begin pc_rg <= ras_ret_addr; end  // Request RET addr if RET taken; RAS & BP flushes are exclusive, so the priority doesn't matter...
      `endif
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
      if      (flush)                     begin instr_valid_rg[0] <= 1'b0 ; end              // Invalidate on external flush; highest priority 
      else if (bp_or_ras_flush && !stall) begin instr_valid_rg[0] <= 1'b0 ; end              // Invalidate on BP/RAS flush IFF not stalling - cz the instr that generated flush shouldn't get invalidated in the pipeline!
      else if (!stall)                    begin instr_valid_rg[0] <= i_imem_pkt_valid ; end  // Pipe forward packet valid... 

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
if (!EN_BPREDICT_DYN) begin : GEN_BPREDICT_STT
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
      .i_instr_valid  (instr_valid & ~bu_or_ras_flush),  // BU/RAS flush should immediately invalidate to avoid any spurious BP flush in the next clk cycle... 
                                                         // BP flush need not invalidate, as it wont cause another spurious BP flush in the next clk cycle...
      .o_branch_pc    (branch_pc)    ,  
      .o_branch_taken (branch_taken) ,
      .o_flush        (bp_flush)
   );
end else begin : GEN_BPREDICT_DYN
   // Pequeno Gshare Dynamic Branch Predictor
   pqGshare_bpredictor#(
      .GHRW     (GHRW),
      .BHT_IDW  (BHT_IDW),
      .BHT_TYPE (BHT_TYPE),
      .BHT_BIAS (BHT_BIAS)
   ) inst_pqGshare_bpredictor (
      .clk            (clk)          ,
      .aresetn        (aresetn)      ,
   
      .i_req_pc       (instr_pc)     ,   
      .i_stall        (stall)        ,
      .i_is_op_jal    (is_op_jal)    ,    
      .i_is_op_branch (is_op_branch) ,  
      .i_immJ         (immJ)         ,      
      .i_immB         (immB)         ,  
      .i_instr_valid  (instr_valid & ~bu_or_ras_flush),  // BU/RAS flush should immediately invalidate to avoid any spurious BP flush in the next clock cycle... 
                                                         // BP flush need not invalidate, as it wont cause another spurious BP flush in the next clk cycle...
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

//===================================================================================================================================================
// RAS prediction logic
// --------------------
// Handles all CALL, RET instructions.
// Generates RET taken status, which is later validated during RET resolution at Execution Unit (EXU).
//===================================================================================================================================================
generate
if (EN_RAS) begin : GEN_RAS
///////////////////////////////////////////////////////////
// RAS Predictor
///////////////////////////////////////////////////////////
ras_predictor #(
   .ST_DPT (RAS_DPT),
   .ST_DW  (`XLEN)
)  inst_ras_predictor (
   .clk               (clk),
   .aresetn           (aresetn),

   .i_st_rbk_en       (i_ras_rbk_en),
   .i_st_rbk_ptr      (i_ras_rbk_ptr),
   .i_st_rbk_full     (i_ras_rbk_full),
   .i_st_rbk_incr_ptr (i_ras_rbk_incr_ptr),

   .i_is_call_fu      (is_call_rg & instr_valid_rg[0]),  // CALL flag is qualified by instr valid at FU output
   .i_is_call_du      (i_du_is_call),                    // Flag is assumed to be qualified by instr valid at DU output
   .i_is_ret_taken_du (i_du_is_ret_taken),               // Flag is assumed to be qualified by instr valid at DU output

   .i_pc              (instr_pc),
   .i_stall           (stall),
   .i_is_call         (is_call),
   .i_is_ret          (is_ret),
   .i_instr_valid     (instr_valid & ~bu_or_bp_flush),  // BU/BP flush should immediately invalidate to avoid any spurious RAS flush/push/pop in the next clock cycle...
                                                        // RAS flush need not invalidate, as it won't cause another spurious RAS flush in the next clk cycle...
                                                        // RAS flush internally gates push/pop in the RAS predictor
   .o_st_snap_ptr     (o_du_ras_snap_ptr),
   .o_st_snap_full    (o_du_ras_snap_full),

   .o_ret_addr        (ras_ret_addr),
   .o_ret_taken       (ras_ret_taken),
   .o_flush           (ras_flush)
);

// Decode CALL, RET based on RV32 ABIs
assign rs0     = instr[19:15];
assign rdt     = instr[11:7];
assign is_call = ((op == OP_JALR) || (op == OP_JAL)) && (rdt == 5'd1);
assign is_ret  =  (op == OP_JALR) && (rs0 == 5'd1)   && (rdt == 5'd0);

//=========================================================
// Pipe forward registered CALL, RET flags
//=========================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      is_call_rg <= 1'b0;
      is_ret_rg  <= 1'b0;
   end
   // Out of reset
   else if (!stall) begin 
      is_call_rg <= is_call ;
      is_ret_rg  <= is_ret  ;              
   end
end
end  //GEN_RAS
else begin : NO_RAS
   assign is_call_rg = 1'b0 ;  // Unused...
   assign is_ret_rg  = 1'b0 ;  // Unused...
   assign ras_flush  = 1'b0 ;  // Unused...
end
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
assign flush           = i_exu_bu_flush             ;  // Only EXU-BU can flush FU from outside
assign bu_or_ras_flush = flush    | ras_flush       ;
assign bu_or_bp_flush  = flush    | bp_flush        ; 
assign bp_or_ras_flush = bp_flush | ras_flush       ;
assign fu_flush_ext    = flush    | bp_or_ras_flush ;  // Any flush should be propagated to the upstream...
assign o_imem_flush    = fu_flush_ext               ;  // Flush signal to IMEMIF

//===================================================================================================================================================
//  All other outputs from FU
//===================================================================================================================================================
`ifdef DBG
// Debug Interface
logic is_op_branch_rg, is_op_jal_rg;
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      is_op_branch_rg <= 1'b0;
      is_op_jal_rg    <= 1'b0;   
   end
   // Out of reset
   else if (!stall) begin   
      is_op_branch_rg <= is_op_branch;
      is_op_jal_rg    <= is_op_jal;  
   end
end
`ifdef RAS
assign o_fu_dbg = {ras_flush, is_call_rg, is_ret_rg, bp_flush, is_op_branch_rg, is_op_jal_rg};
`else
assign o_fu_dbg = {bp_flush, is_op_branch_rg, is_op_jal_rg};
`endif//RAS
`endif//DBG

// PC output to IMEMIF
assign o_imem_pc       = pc_rg        ;
assign o_imem_pc_valid = pc_valid_rg  ;

// Payload to Decode Unit (DU)
assign o_du_pc       =  instr_pc_rg[0]    ; 
assign o_du_instr    =  instr_rg[0]       ;
assign o_du_br_taken =  branch_taken      ;
assign o_du_bubble   = ~instr_valid_rg[0] ;  // Insert bubble if invalid instruction
`ifdef RAS
assign o_du_is_call       = is_call_rg    ;
assign o_du_ras_ret_addr  = ras_ret_addr  ;
assign o_du_ras_ret_taken = ras_ret_taken ;
`endif

endmodule
//###################################################################################################################################################
//                                                              F E T C H   U N I T                                         
//###################################################################################################################################################