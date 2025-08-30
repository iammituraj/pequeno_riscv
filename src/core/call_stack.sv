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
//----%% Last modified on : August-2025
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
   input  logic            i_rbk_en    ,  // Roll back enable
   input  logic [PTRW-1:0] i_rbk_ptr   ,  // Roll back pointer
   input  logic [PTRW-0:0] i_rbk_cnt   ,  // Roll back counter
   input  logic [1:0]      i_spec_state,  // Speculative state of the CPU pipeline
                                          // 2'b00 = {other/ret, other/ret} 
                                          // 2'b01 = {other, call} or {call, other} or {call, ret}
                                          // 2'b10 = {call, call}
                                          // 2'b11 = {ret, call}
                                          // bit[1]= instr @DU->EXU, bit[0] = instr @FU->DU
   // Status interface
   output logic [PTRW:0]   o_stack_cnt ,  // Stack items count
   output logic [PTRW-1:0] o_stack_ptr ,  // Stack top pointer

   // Push interface
   input  logic            i_push_en   ,  // Push enable
   input  logic [DW-1:0]   i_push_data ,  // Push data
   output logic            o_full      ,  // Full flag

   // Pop interface
   input  logic            i_pop_en    ,  // Pop enable
   output logic [DW-1:0]   o_pop_data  ,  // Pop data
   output logic            o_empty        // Empty flag
);

// Internal Registers/Signals
logic [DW-1:0]   stack [DPT];      // Stack array
logic [PTRW-1:0] top_ptr_ff;       // Stack pointer @top --> points to next free slot 
logic [PTRW-1:0] top_ptr_m1;       // Stack pointer-1
logic [PTRW-1:0] wr_ptr;           // Write pointer
logic [PTRW:0]   count_ff;         // Counter
logic            push_en, pop_en;  // Conditioned push & pop enable
logic [DW-1:0]   spare_buff[2];    // Spare buffers. Max. outstanding speculative calls/returns = 2 in the pipeline

// Logic to update stack pointer/counter
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      top_ptr_ff <= '0 ;
      count_ff   <= '0 ;
   end  
   // Rollback
   else if (i_rbk_en) begin
      top_ptr_ff <= i_rbk_ptr ;
      count_ff   <= i_rbk_cnt ;   
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

// Logic to push data
// No reset of stack array, for FPGA friendly implementation on LUT RAMs
always_ff @(posedge clk) begin
   // Rollback
   if (i_rbk_en) begin
      case (i_spec_state)
         2'b01  : begin stack[i_rbk_ptr+0] <= spare_buff[0];                                      end
         2'b10  : begin stack[i_rbk_ptr+0] <= spare_buff[1]; stack[i_rbk_ptr+1] <= spare_buff[0]; end
         2'b11  : begin stack[i_rbk_ptr-1] <= spare_buff[0];                                      end
         default: ;  // No change in stack state
      endcase
   end
   // Push to Stack when no rollback is enabled
   else if (push_en) stack[wr_ptr] <= i_push_data ;
end

// Write pointer
assign wr_ptr = top_ptr_ff;

// Pop data
assign top_ptr_m1 = top_ptr_ff-1 ;
assign o_pop_data = stack[top_ptr_m1]  ;

// Conditioned push & pop enable
assign push_en     = i_push_en           ;  // Push is always allowed even when full, to allow wrapping & overwriting older entries...
assign pop_en      = i_pop_en & ~o_empty ;  // Pop is allowed only if not empty

// Full & Empty flags
assign o_full  = (count_ff[PTRW] == 1'b1);  // Equivalent to count_ff == DPT; Overflow bit => max count reached...
assign o_empty = (count_ff == 0);

// Logic to update spare buffers
// spare_buff[0] = latest push data
// spare_buff[1] = older data
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
assign o_stack_cnt = count_ff   ;
assign o_stack_ptr = top_ptr_ff ;

endmodule
//###################################################################################################################################################
//                                                              C A L L   S T A C K                                     
//###################################################################################################################################################