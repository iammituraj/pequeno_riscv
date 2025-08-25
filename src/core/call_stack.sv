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
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : May-2025
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
   input  logic           clk         ,  // Clock
   input  logic           aresetn     ,  // Asynchronous Reset; active-low

   // Push interface
   input  logic           i_push_en   ,  // Push enable
   input  logic [DW-1:0]  i_push_data ,  // Push data
   output logic           o_full      ,  // Full flag

   // Pop interface
   input  logic           i_pop_en    ,  // Pop enable
   output logic [DW-1:0]  o_pop_data  ,  // Pop data
   output logic           o_empty        // Empty flag
);

// Internal Registers/Signals
logic [DW-1:0]   stack [DPT];      // Stack array
logic [PTRW-1:0] top_ptr_ff;       // Stack pointer @top --> points to next free slot 
logic [PTRW-1:0] top_ptr_m1;       // Stack pointer-1
logic [PTRW-1:0] wr_ptr;           // Write pointer
logic [PTRW:0]   count_ff;         // Counter
logic            push_en, pop_en;  // Conditioned push & pop enable
logic            exc_push_en, exc_pop_en;  // Exclusive push/pop enable

// Logic to update stack pointer/counter
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      top_ptr_ff <= '0 ;
      count_ff   <= '0 ;
   end  
   // Out of reset
   else begin
      // Pointer update on push & pop
      if      (exc_push_en) top_ptr_ff <= top_ptr_ff + 1 ;  // Increment pointer only on exclusive push
      else if (exc_pop_en)  top_ptr_ff <= top_ptr_ff - 1 ;  // Decrement pointer only on exclusive pop

      // Counter update
      if      (exc_push_en && !o_full) count_ff <= count_ff + 1 ;  // Counter should not increment once full, even though pushing is still allowed...
      else if (exc_pop_en)             count_ff <= count_ff - 1 ;
   end
end

// Logic to push data
// No reset of stack array, for FPGA friendly implementation on LUT RAMs
always_ff @(posedge clk) begin
   if (push_en) stack[wr_ptr] <= i_push_data ; 
end

// Write pointer
assign wr_ptr = pop_en? top_ptr_m1 : top_ptr_ff;  // On simultaneous push & pop, overwrite the top item, instead of writing to next free slot

// Pop data
assign top_ptr_m1 = top_ptr_ff-1 ;
assign o_pop_data = stack[top_ptr_m1]  ;

// Conditioned push & pop enable
assign push_en     = i_push_en           ;  // Push is always allowed, even when full, to allow wrapping and overwriting older entries...
assign pop_en      = i_pop_en & ~o_empty ;  // Pop is allowed only if not empty
assign exc_push_en =  push_en & !pop_en  ;
assign exc_pop_en  = !push_en &  pop_en  ; 

// Full & Empty flags
assign o_full  = (count_ff[PTRW] == 1'b1);  // Equivalent to count_ff == DPT; Overflow bit => max count reached...
assign o_empty = (count_ff == 0);

endmodule
//###################################################################################################################################################
//                                                              C A L L   S T A C K                                     
//###################################################################################################################################################