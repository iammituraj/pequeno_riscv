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
//----%% File Name        : ras_predictor.sv
//----%% Module Name      : RAS Predictor                                   
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : RAS predictor monitors CALL/RET instructions and controls push/pop operations to call stack.
//----%%                    - Return address (PC+4) from FU is pushed to the stack on every CALL
//----%%                    - RAS prediction on every RET - If the stack is not empty, return address is popped out and flush is generated.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Sept-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         R A S   P R E D I C T O R                                   
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Module definition
module ras_predictor #(
   parameter  ST_DPT   = `RAS_DPT,        // Stack depth; MUST BE 2^N size
   parameter  ST_DW    = `XLEN,           // Stack data size
   localparam ST_PTRW  = $clog2(ST_DPT)   // Stack pointer size
)(
   // Clock and Reset
   input  logic               clk           ,  // Clock
   input  logic               aresetn       ,  // Asynchronous Reset; active-low

   // Stack Rollback Interface
   input  logic               i_st_rbk_en       ,  // Roll back enable
   input  logic [ST_PTRW-1:0] i_st_rbk_ptr      ,  // Roll back pointer
   input  logic               i_st_rbk_full     ,  // Roll back to full state
   input  logic               i_st_rbk_incr_ptr ,  // Roll back pointer increment flag

   // CPU pipeline state
   input  logic               i_is_call_fu        ,  // CALL instr flag at FU output
   input  logic               i_is_call_du        ,  // CALL instr flag at DU output
   input  logic               i_is_ret_taken_du   ,  // RET taken flag at DU output

   // Fetch Unit Interface
   input  logic [`XLEN-1:0]   i_pc          ,  // PC in
   input  logic               i_stall       ,  // Stall
   input  logic               i_is_call     ,  // CALL instr flag at FU input
   input  logic               i_is_ret      ,  // RET instr flag at FU input
   input  logic               i_instr_valid ,  // Instruction valid
   
   // Stack snapshot
   output logic [ST_PTRW-1:0] o_st_snap_ptr ,  // Stack pointer
   output logic               o_st_snap_full,  // Stack full flag

   // Prediction signals
   output logic [`XLEN-1:0]   o_ret_addr    ,  // Return address predicted
   output logic               o_ret_taken   ,  // Return taken status; '0'- not taken, '1'- taken
   output logic               o_flush          // Flush generated on return taken
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic               is_call_valid       ;  // Valid CALL instr received
logic               is_ret_valid        ;  // Valid RET instr received
logic               ret_taken           ;  // RET taken status
logic               ret_taken_rg        ;  // RET taken status, registered
logic               ras_flush_rg        ;  // RAS flush
logic [`XLEN-1:0]   ret_addr_on_call    ;  // Return address to be stored in the stack on CALL
logic [`XLEN-1:0]   ret_addr_on_ret     ;  // Return address popped from the stack on RET
logic [`XLEN-1:0]   ret_addr_on_ret_rg  ;  // Return address popped from the stack on RET, registered

logic               push_en, pop_en     ;  // Push and pop signals to stack
logic               st_full,st_empty    ;  // Stack Full, Empty flags
logic               st_alm_full         ;  // Stack Almost Full flag
logic [ST_PTRW-1:0] curr_st_ptr         ;  // Stack pointer

logic [1:0]         cpu_spec_state      ;  // Speculative state of the CPU pipeline

/////////////////////////////////////////////////////////////////////
// Call Stack Instance
/////////////////////////////////////////////////////////////////////
call_stack #(
   .DPT (ST_DPT),
   .DW  (ST_DW)
)  inst_call_stack (
   .clk            (clk),
   .aresetn        (aresetn),

   .i_rbk_en       (i_st_rbk_en),
   .i_rbk_ptr      (i_st_rbk_ptr),
   .i_rbk_full     (i_st_rbk_full),
   .i_rbk_incr_ptr (i_st_rbk_incr_ptr),
   .i_spec_state   (cpu_spec_state),

   .o_stack_ptr    (curr_st_ptr),

   .i_push_en      (push_en),
   .i_push_data    (ret_addr_on_call),
   .o_full         (st_full),
   .o_alm_full     (st_alm_full),

   .i_pop_en       (pop_en),
   .o_pop_data     (ret_addr_on_ret),
   .o_empty        (st_empty)
);

//===================================================================
// Push & Pop control
//-------------------------------------------------------------------
// - Push should be performed on valid CALLs
// - Pop should be performed on valid RETs
// - Push/pop must be blocked on FU stall or RAS flush
//===================================================================
assign is_call_valid    = i_is_call & i_instr_valid ;
assign is_ret_valid     = i_is_ret  & i_instr_valid ;
assign push_en          = is_call_valid  & ~i_stall & ~ras_flush_rg ;
assign pop_en           = is_ret_valid   & ~i_stall & ~ras_flush_rg ;
assign ret_addr_on_call = i_pc + `XLEN'(4);  // Return address after exiting a subroutine CALL is always PC+4

//===================================================================
// Encode speculative state of the CPU pipeline
//===================================================================
always_comb begin
   if   (i_is_ret_taken_du && i_is_call_fu) cpu_spec_state = 2'b11;
   else                                     cpu_spec_state = {1'b0, i_is_call_du} + {1'b0, i_is_call_fu};
end

//===================================================================
// Stack Snapshot
//===================================================================
logic [ST_PTRW-1:0] curr_st_ptr_p1;
logic [ST_PTRW-1:0] curr_st_ptr_m1;
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      o_st_snap_ptr <= '0;
      o_st_snap_full<= 1'b0;
   end
   // Out of reset
   else if (!i_stall) begin 
      // Pipe forward ptr+1 on CALLs cz potential push may have happened... so rollback of stack contents must use reference = ptr+1
      // Pipe forward almost full on CALLs cz potential push may have happened and stack may have got full!
      // Pipe forward ptr-1 on RET taken cz pop has happened... so rollback of stack contents must use reference =  ptr-1
      o_st_snap_ptr <= i_is_call? curr_st_ptr_p1 : (ret_taken? curr_st_ptr_m1 : curr_st_ptr);
      o_st_snap_full<= i_is_call? st_alm_full : st_full ;
   end
end
assign curr_st_ptr_p1 = curr_st_ptr + 1;
assign curr_st_ptr_m1 = curr_st_ptr - 1;

//===================================================================
// RET address prediction
//===================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      ret_addr_on_ret_rg <= '0;
      ret_taken_rg       <= '0;
   end
   // Out of reset
   else if (!i_stall) begin 
      ret_addr_on_ret_rg <= ret_addr_on_ret ;  // Pipe forward...
      ret_taken_rg       <= ret_taken       ;  // Pipe forward...         
   end
end
assign o_ret_addr  = ret_addr_on_ret_rg ;
assign o_ret_taken = ret_taken_rg       ;
assign ret_taken   = (is_ret_valid && !st_empty);  // If stack is not empty and is valid RET instr, then pop from RAS may have happened => RET is taken

//===================================================================
// RAS flush generation on RET address prediction
//===================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      ras_flush_rg <= 1'b0;
   end
   // Out of reset
   else begin
      if      (ras_flush_rg) begin ras_flush_rg <= 1'b0      ; end  // Flush should always de-assert in the next cycle...
      else if (!i_stall)     begin ras_flush_rg <= ret_taken ; end  // Flush asserted on RET taken
   end
end
assign o_flush = ras_flush_rg ;

endmodule
//###################################################################################################################################################
//                                                         R A S   P R E D I C T O R                                   
//###################################################################################################################################################