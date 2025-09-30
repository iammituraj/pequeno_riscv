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
//----%% File Name        : call_stack.sv
//----%% Module Name      : Call Stack                                   
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Call stack is used to store recent N return address of the functions called by the CPU.
//----%%                    The stack follows LIFO scheme & allows pushing data even after hitting full, by circular wrapping.
//----%%                    Hence, it always holds recently received N items for depth N. The depth is assumed of 2^N order.
//----%%                    The stack assumes that a time, either push or pop is performed by the CPU.
//----%%                    Simultaneous PUSH and POP = INVALID operation!
//----%%                    The stack supports rollback feature to reset the stack back to the original state in case the speculative calls/returns
//----%%                    in the pipeline got flushed.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Sept-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                              C A L L   S T A C K                                     
//###################################################################################################################################################
// Module definition
module call_stack #(
   parameter  DPT   = 8  ,         // Stack depth; MUST BE 2^N size
   parameter  DW    = 32 ,         // Data size
   localparam PTRW  = $clog2(DPT)  // Pointer size
)(
   // Clock and Reset
   input  logic            clk         ,  // Clock
   input  logic            aresetn     ,  // Asynchronous Reset; active-low

   // Rollback interface
   input  logic            i_rbk_en       ,  // Roll back enable __/''\__
   input  logic [PTRW-1:0] i_rbk_ptr      ,  // Roll back pointer
   input  logic            i_rbk_full     ,  // Roll back to full
   input  logic            i_rbk_incr_ptr ,  // Roll back pointer increment flag
   input  logic [1:0]      i_spec_state   ,  // Speculative state of the CPU pipeline
                                             // 2'b00 = {other/ret, other/ret} 
                                             // 2'b01 = {other, call} or {call, other/ret}
                                             // 2'b10 = {call, call}
                                             // 2'b11 = {ret, call}
                                             // bit[1]= instr @DU->EXU, bit[0] = instr @FU->DU
   // Status interface
   output logic [PTRW-1:0] o_stack_ptr ,  // Stack pointer

   // Push interface
   input  logic            i_push_en   ,  // Push enable
   input  logic [DW-1:0]   i_push_data ,  // Push data
   output logic            o_full      ,  // Full flag
   output logic            o_alm_full  ,  // Almost Full flag

   // Pop interface
   input  logic            i_pop_en    ,  // Pop enable
   output logic [DW-1:0]   o_pop_data  ,  // Pop data
   output logic            o_empty        // Empty flag
);

// localparams
localparam [PTRW:0] MAX_CNT = 2**(PTRW);

// Internal Registers/Signals
logic [DW-1:0]   stack [DPT];      // Stack array
logic [PTRW-1:0] top_ptr_ff;       // Stack pointer @top --> points to next free slot 
logic [PTRW-1:0] top_ptr_m1;       // Stack pointer-1
logic [PTRW-1:0] wr_ptr;           // Write pointer
logic            wr_en;            // Write enable
logic [DW-1:0]   wr_data;          // Write data
logic [PTRW:0]   count_ff;         // Counter
logic            push_en, pop_en;  // Conditioned push & pop enable
logic [DW-1:0]   spare_buff[2];    // Spare buffers. Max. outstanding speculative calls/returns = 2 in the pipeline

//=============================================================================
// Logic to update stack pointer/counter
//=============================================================================
logic [PTRW-1:0] rbk_ptr_p1;
logic [PTRW-1:0] top_ptr_post_rbk;
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      top_ptr_ff <= '0 ;
      count_ff   <= '0 ;
   end  
   // Rollback
   else if (i_rbk_en) begin
      top_ptr_ff <= top_ptr_post_rbk ;
      count_ff   <= i_rbk_full? MAX_CNT : {1'b0, top_ptr_post_rbk} ;  // Count = Top pointer unless stack is full
   end
   // Push/Pop when no rollback is enabled
   else begin
      // Pointer update on push & pop
      if      (push_en) top_ptr_ff <= top_ptr_ff + 1 ;  // Increment pointer only on push
      else if (pop_en)  top_ptr_ff <= top_ptr_ff - 1 ;  // Decrement pointer only on pop

      // Counter update
      if      (push_en && !o_full) count_ff <= count_ff + 1 ;  // Counter should not increment once full, even though pushing is still allowed...
      else if (pop_en)             count_ff <= count_ff - 1 ;  // Counter decrements on every pop
   end
end
assign rbk_ptr_p1       = i_rbk_ptr + 1 ;
assign top_ptr_post_rbk = i_rbk_incr_ptr? rbk_ptr_p1 : i_rbk_ptr ;

//=============================================================================
// Rollback control signals
//=============================================================================
logic rbk_en_ff    ;  // Rollback enable registered
logic rbk_en_gated ;  // Rollback enable gated
logic rbk_en_extnd ;  // Rollback enable extended
logic rbk_cyc_ff   ;  // Rollback cycle no.

// 2-cycle rollback?
logic is_rbk_2cyc;
assign is_rbk_2cyc = (i_spec_state == 2'b10);  // Only CPU speculative state 2'b10 requires 2-cycle rollback

// Rollback enable & Rollback cycle
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      rbk_en_ff  <= 1'b0;
      rbk_cyc_ff <= 1'b0;
   end  
   // Out of Reset
   else begin
      rbk_en_ff  <= is_rbk_2cyc? i_rbk_en : 1'b0 ;  // Latch only on 2-cycle rollback
      rbk_cyc_ff <= i_rbk_en? 1'b1 : 1'b0 ;         // Alternating counter 010... for every rollback pulse
   end 
end
assign rbk_en_gated = i_rbk_en && (i_spec_state != 2'b00);  // Disable rollback of stack entries on CPU speculative state 2'b00
assign rbk_en_extnd = rbk_en_gated | rbk_en_ff ;            // Extend rollback enable pulse by one cycle to generate 2-cycle rollback...

// Current rollback pointer & spare buffer
logic [PTRW-1:0] curr_rbk_ptr;           // Current pointer used for rollback
logic            curr_rbk_sbuff_addr;    // Current spare buffer address used for rollback
logic [DW-1:0]   curr_rbk_sbuff;         // Current spare buffer used for rollback
logic [PTRW-1:0] nxt_rbk_ptr_ff;         // Next pointer used for rollback
logic            nxt_rbk_sbuff_addr_ff;  // Next spare buffer address used for rollback

// Based on the CPU spec. state, current rollback pointer & spare buffer address is generated on every cycle of rollback
always_comb begin
   // First cycle of rollback
   if (~rbk_cyc_ff) begin
      case (i_spec_state)
         2'b01  : begin curr_rbk_ptr = i_rbk_ptr+0; curr_rbk_sbuff_addr = 1'b0; end
         2'b10  : begin curr_rbk_ptr = i_rbk_ptr+0; curr_rbk_sbuff_addr = 1'b1; end
         2'b11  : begin curr_rbk_ptr = i_rbk_ptr-1; curr_rbk_sbuff_addr = 1'b0; end
         default: begin curr_rbk_ptr = i_rbk_ptr+0; curr_rbk_sbuff_addr = 1'b0; end
      endcase  
   end
   // Second cycle of rollback
   else begin
      curr_rbk_ptr        = nxt_rbk_ptr_ff        ;
      curr_rbk_sbuff_addr = nxt_rbk_sbuff_addr_ff ;
   end 
end
assign curr_rbk_sbuff = spare_buff[curr_rbk_sbuff_addr];

// Next rollback pointer & spare buffer address
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      nxt_rbk_ptr_ff        <= '0 ;
      nxt_rbk_sbuff_addr_ff <= '0 ;
   end  
   // Updating the next values only on rollback enable to save switching power...
   else if (i_rbk_en) begin
      nxt_rbk_ptr_ff        <= is_rbk_2cyc? rbk_ptr_p1 : nxt_rbk_ptr_ff ;  // Next pointer = rbk_ptr++ if 2-cycle rollback, all other cases, the next pointer doesn't matter...
      nxt_rbk_sbuff_addr_ff <= 1'b0 ;  // Next spare_buff address = addr--, therefore it is always 0, cz sbuff[1], sbuff[0] is the order for 2-cycle rollback!
   end
end

//=============================================================================
// Logic to push data/rollback
//=============================================================================
always_ff @(posedge clk) begin
   if (wr_en) stack[wr_ptr] <= wr_data;
end

// Write pointer & Write data
always_comb begin
   // Rollback phase - 2 cycle pulse on CPU speculative state 2'b10, else single cycle pulse...
   // By design, it's ensured that the next valid instruction comes @Fetch Unit input atleast after 2 cycles, after the EXU BU flush which initiated the rollback.
   // So, spare buffers remain clean during this phase, and no push/pop happens during the rollback phase.
   // So, we can do rollback safely in 2 cycles instead of 1.
   if (rbk_en_extnd) begin
      wr_ptr  = curr_rbk_ptr  ; 
      wr_data = curr_rbk_sbuff;
   end
   // In case of push, or any other case...
   else begin
      wr_ptr  = top_ptr_ff ;
      wr_data = i_push_data;  
   end
end
assign wr_en = rbk_en_extnd | push_en ;  // Rollback / push can write to stack

// Pop data
assign top_ptr_m1 = top_ptr_ff-1 ;
assign o_pop_data = stack[top_ptr_m1]  ;

// Conditioned push & pop enable
assign push_en     = i_push_en           ;  // Push is always allowed even when full, to allow wrapping & overwriting older entries...
assign pop_en      = i_pop_en & ~o_empty ;  // Pop is allowed only if not empty

// Full & Empty flags
assign o_full     = (count_ff[PTRW] == 1'b1);  // Equivalent to count_ff == DPT; Overflow bit => max count reached...
assign o_empty    = (count_ff == 0);
assign o_alm_full = &count_ff[PTRW-1:0];  // If the counter = (MAX_CNT -1) => Almost full!

//===================================================================
// Logic to update spare buffers
//-------------------------------------------------------------------
// On every push, there is a potential data overwrite at the top,
// This data is stored on spare buffs in case rollback is reqd later.
//
// spare_buff[0] = latest data
// spare_buff[1] = older data
//===================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      spare_buff[0] <= '0 ;
      spare_buff[1] <= '0 ;
   end  
   // Update the buffer on every push when no rollback
   else if (push_en && !i_rbk_en) begin
      spare_buff[0] <= stack[wr_ptr];
      spare_buff[1] <= spare_buff[0];
   end
end

// Status output
assign o_stack_ptr = top_ptr_ff ;

endmodule
//###################################################################################################################################################
//                                                              C A L L   S T A C K                                     
//###################################################################################################################################################