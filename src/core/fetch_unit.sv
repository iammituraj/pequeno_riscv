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
//----%% File Name        : fetch_unit.sv
//----%% Module Name      : Fetch Unit (FU)                                          
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Instruction Fetch Unit (FU) of PQR5 Core. 
//----%%                    # Supports interface to fetch instructions from instruction memory/cache controller in-order.
//----%%                    # Fetched instructions forwarded to Decode Unit (DU) with pipeline latency = 2 clock cycles.
//----%%                    # Never issues stalls, unless stalled by DU.
//----%%                    # Simple static branch prediction supported, supports basic branch, stall, and flush mechanisms on branching.
//----%%                    # Inserts bubbles (NOPs) into pipelines when idle ie., when no instruction available to be fetched.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Feb-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
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
   parameter PC_INIT = `PC_INIT  // Init PC on reset
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
   output logic             o_du_bubble        ,  // Bubble to DU
   output logic             o_du_br_taken      ,  // Branch taken status to DU; '0'- not taken, '1'- taken
   input  logic             i_du_stall         ,  // Stall signal from DU


   // Interface with Execution Unit (EXU)
   input  logic             i_exu_bu_flush     ,  // Flush signal from EXU-BU
   input  logic [`XLEN-1:0] i_exu_bu_pc           // Branch PC from EXU-BU
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// IMEMIF specific
logic [`XLEN-1:0] pc_rg              ;  // PC to IMEMIF
logic             pc_valid_rg        ;  // PC valid
logic             pc_rst_flag_rg     ;  // Flag to indicate if PC is coming out of reset
logic [`XLEN-1:0] pc_plus_four       ;  // PC+4
logic [`XLEN-1:0] nxt_pc             ;  // Next PC to IMEMIF

// Instruction pipe buffers
logic [`ILEN-1:0] instr_rg [2]       ;  // Instruction buffer with two entries (Buffer-1, Buffer-2)
logic             instr_valid_rg [2] ;  // Instruction valid corresponding to instruction buffer entries
logic [`XLEN-1:0] instr_pc_rg [2]    ;  // PC corresponding to instruction buffer entries

// Branch logic specific
logic             branch_taken       ;  // To flag that branch has to be taken
logic             branch_taken_rg    ;  // branch_taken registered
logic [`XLEN-1:0] branch_pc          ;  // Branch PC; PC to branch to
logic [`ILEN-1:0] instr              ;  // Buffer-1 instruction
logic             instr_valid        ;  // Buffer-1 instruction valid
logic [`XLEN-1:0] instr_pc           ;  // Buffer-1 instruction PC
logic [6:0]       op                 ;  // Opcode in Buffer-1 instruction
logic [`XLEN-1:0] immJ, immB         ;  // Sign-extended Immediate (Jump/Branch) in Buffer-1 instruction
logic             is_op_jal          ;  // To flag if JAL instruction in Buffer-1
logic             is_op_branch       ;  // To flag if branch instruction in Buffer-1

// Stall logic specific
logic             stall              ;  // Stall from outside FU
logic             fu_stall           ;  // Stall generated by FU to IMEMIF

// Flush logic specific
logic             flush              ;  // Flush from outside FU
logic             fu_flush           ;  // Flush locally generated by FU

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
      else if (branch_taken)   begin pc_rg <= branch_pc   ; end  // Request Branch PC if branch taken
      else if (!i_imem_stall)  begin pc_rg <= nxt_pc      ; end  // Request PC+4 
      
      // PC valid
      if      (i_exu_bu_flush) begin pc_valid_rg <= 1'b1 ; end  // Valid
      else if (branch_taken)   begin pc_valid_rg <= 1'b1 ; end  // Valid  
      else if (!i_imem_stall)  begin pc_valid_rg <= 1'b1 ; end  // Valid

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
      if      (flush)                  begin instr_rg[0] <= `INSTR_NOP ; end                                  // Pipe in NOP instruction on flush
      else if (branch_taken && !stall) begin instr_rg[0] <= `INSTR_NOP ; end                                  // Pipe in NOP instruction if branch taken
      else if (!stall)                 begin instr_rg[0] <= i_imem_pkt_valid ? i_imem_pkt : `INSTR_NOP ; end  // Pipe in NOP instruction if invalid packet   
      
      // Instruction Buffer-1 valid
      if      (flush)                  begin instr_valid_rg[0] <= 1'b0 ; end              // Invalidate on flush
      else if (branch_taken && !stall) begin instr_valid_rg[0] <= 1'b0 ; end              // Invalidate if branch taken
      else if (!stall)                 begin instr_valid_rg[0] <= i_imem_pkt_valid ; end  // Pipe through packet valid... 

      // Instruction Buffer-1 PC
      if      (i_exu_bu_flush)         begin instr_pc_rg[0] <= i_exu_bu_pc ; end                                    // Pipe in EXU-BU PC on EXU-BU flush -- NOT reqd, but kept for debug
      else if (branch_taken && !stall) begin instr_pc_rg[0] <= branch_pc   ; end                                    // Pipe in Branch PC if branch taken -- NOT reqd, but kept for debug
      else if (!stall)                 begin instr_pc_rg[0] <= i_imem_pkt_valid ? i_imem_pc : instr_pc_rg[0] ; end  // Pipe in PC only if valid packet                
   end

end

//===================================================================================================================================================
// Synchronous logic to buffer instruction at Instruction Buffer-2
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin

   // Reset   
   if (!aresetn) begin
      instr_rg      [1] <= `INSTR_NOP ;
      instr_valid_rg[1] <= 1'b0       ;
      instr_pc_rg   [1] <= PC_INIT    ;
   end
   // Out of reset
   else begin 
      // Instruction Buffer-2
      if      (flush)  begin instr_rg[1] <= `INSTR_NOP  ; end  // Pipe in NOP instruction on flush  
      else if (!stall) begin instr_rg[1] <= instr_rg[0] ; end  // Pipe through...  
      
      // Instruction Buffer-2 valid
      if      (flush)  begin instr_valid_rg[1] <= 1'b0              ; end  // Invalidate on flush
      else if (!stall) begin instr_valid_rg[1] <= instr_valid_rg[0] ; end  // Pipe through...

      // Instruction Buffer-2 PC
      if      (i_exu_bu_flush) begin instr_pc_rg[1] <= i_exu_bu_pc    ; end  // Pipe in EXU-BU PC on EXU-BU flush -- NOT reqd, but kept for debug
      else if (!stall)         begin instr_pc_rg[1] <= instr_pc_rg[0] ; end  // Pipe through...               
   end

end

//===================================================================================================================================================
// Branch prediction logic
//===================================================================================================================================================
// Branch PC computation
always_comb begin   
   if      (is_op_jal)    begin branch_pc = instr_pc + immJ      ; end  // JAL
   else if (is_op_branch) begin branch_pc = instr_pc + immB      ; end  // Branch
   else                   begin branch_pc = instr_pc + `XLEN'(4) ; end  // PC+4
end

assign instr        = instr_rg[0]       ;
assign instr_valid  = instr_valid_rg[0] ;
assign instr_pc     = instr_pc_rg[0]    ;
assign op           = instr[6:0]        ;
assign immJ         = {{(`XLEN-20){instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0} ;
assign immB         = {{(`XLEN-12){instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}   ;

assign is_op_jal    = instr_valid && (op == OP_JAL)    ;  
assign is_op_branch = instr_valid && (op == OP_BRANCH) ;

// If Jump instruction, branch is always taken
// If Branch instruction, branch is taken if backward jump    
assign branch_taken = is_op_jal || (is_op_branch && immB[31]) ;  

// Synchronous logic to register branch_taken and pipe it through
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      branch_taken_rg <= 1'b0 ;
   end
   // Out of reset
   else begin
      if (!stall) begin branch_taken_rg <= branch_taken ; end
   end
end

assign o_du_br_taken = branch_taken_rg ;

//===================================================================================================================================================
//  Stall logic
//===================================================================================================================================================
assign stall        = i_du_stall               ;  // Only DU can stall FU from outside
assign fu_stall     = stall & i_imem_pkt_valid ;  // Iff valid instruction from IMEMIF, stall needs to be generated to IMEMIF  
assign o_imem_stall = fu_stall                 ;  // Stall signal to IMEMIF 

//===================================================================================================================================================
//  Flush logic
//===================================================================================================================================================
assign flush        = i_exu_bu_flush           ;  // Only EXU-BU can flush FU from outside
assign fu_flush     = flush | branch_taken     ;  // If branch taken, flush should be generated internally
assign o_imem_flush = fu_flush                 ;  // Flush signal to IMEMIF

//===================================================================================================================================================
// Continuous assignments to outputs
//===================================================================================================================================================
`ifdef DBG
// Debug Interface
assign o_fu_dbg = {branch_taken, is_op_branch, is_op_jal} ;
`endif

// Outputs to IMEMIF
assign o_imem_pc       = pc_rg        ;
assign o_imem_pc_valid = pc_valid_rg  ;

// Outputs to IDU
assign o_du_pc     =  instr_pc_rg[1]    ; 
assign o_du_instr  =  instr_rg[1]       ;
assign o_du_bubble = ~instr_valid_rg[1] ;  // Insert bubble if invalid instruction

endmodule
//###################################################################################################################################################
//                                                              F E T C H   U N I T                                         
//###################################################################################################################################################