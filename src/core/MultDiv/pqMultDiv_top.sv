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
//----%% File Name        : pqMultDiv_top.sv
//----%% Module Name      : pqMultDiv Top
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Top-level wrapper instantiating pqMultiplier and pqDivider, and unifying them behind a single
//----%%                    operand interface and a single result interface towards the Host (EXU):
//----%%                    - MULT/DIV operation select (mult_op/div_op) is decoded within this wrapper from i_is_mult_op/i_is_div_op
//----%%                      qualified with the single i_op_valid.
//----%%                    - Single stall out (o_multdiv_stall) to Host, asserted while either sub-unit is in-flight.
//----%%                    - Single stall in (i_stall) from Host, internally arbitrated so MULT and DIV never complete/writeback
//----%%                      in the same cycle (they share the single Result Interface).
//----%%                    - Result mux (MULT/DIV) is internal; results are mutually exclusive by construction.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : July-2026
//----%% Notes            : -
//----%%
//----%% Copyright        : Open-source license, see LICENSE.
//----%%
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                             P Q M U L T D I V   T O P
//###################################################################################################################################################
// Module definition
module pqMultDiv_top #(
   // Configurable Parameters
   parameter EN_FPGA_DSP_MULT = 1,  // 1 = use x32 DSP multiplier, 0 = use x32 Radix-4 Booth multiplier
   parameter PIPE_STAGES      = 4   // No. of DSP multiplier pipeline stages; valid value >=2; applies only when EN_FPGA_DSP_MULT=1
)(
   // Clock & Reset
   input  logic       clk,                 // Clock
   input  logic       aresetn,             // Async Reset active-low

   // Flush
   input  logic       i_flush,             // Flush

   // Operand Interface
   input  logic [31:0] i_op0,              // Operand0 = rs1 (Multiplicand / Dividend)
   input  logic [31:0] i_op1,              // Operand1 = rs2 (Multiplier   / Divisor)
   input  logic        i_is_mult_op,       // MULT operation flag
   input  logic        i_is_div_op,        // DIV operation flag
   input  logic        i_is_signed_op0,    // Is operand0 signed?
   input  logic        i_is_signed_op1,    // Is operand1 signed?
   input  logic        i_use_upper_or_rem, // Upper-word (MUL*) / Remainder (REM*) result select flag
   input  logic        i_op_valid,         // Operands valid; qualifies i_is_mult_op/i_is_div_op
   output logic        o_multdiv_stall,    // Stall to Host; asserted while MULT or DIV is in-flight

   // Result Interface
   output logic [31:0] o_res,              // Result = product, or quotient/remainder per i_use_upper_or_rem
   output logic        o_res_valid,        // Result valid
   input  logic        i_stall             // Stall from Host
);

//===================================================================
// Internal Signals
//===================================================================
logic        mult_op_valid  ;  // MULT operand valid; decoded internally
logic        div_op_valid   ;  // DIV operand valid; decoded internally
logic        mult_busy      ;  // Multiplier busy status
logic        div_busy       ;  // Divider busy status
logic        stall2mult     ;  // Stall to Multiplier
logic        stall2div      ;  // Stall to Divider
logic [31:0] mult_res       ;  // Multiplier result
logic [31:0] div_res        ;  // Divider result
logic        mult_res_valid ;  // Multiplier result valid
logic        div_res_valid  ;  // Divider result valid

//===================================================================
// MULT/DIV operation decode
//===================================================================
assign mult_op_valid = i_op_valid & i_is_mult_op ;
assign div_op_valid  = i_op_valid & i_is_div_op  ;

//===================================================================
// Multiplier Instantiation
//===================================================================
pqMultiplier_top #(
   .EN_FPGA_DSP_MULT (EN_FPGA_DSP_MULT),
   .PIPE_STAGES      (PIPE_STAGES)
) inst_pqMultiplier_top (
   .clk             (clk),
   .aresetn         (aresetn),

   .i_flush         (i_flush),

   .i_op0           (i_op0),
   .i_op1           (i_op1),
   .i_is_signed_op0 (i_is_signed_op0),
   .i_is_signed_op1 (i_is_signed_op1),
   .i_use_upperbits (i_use_upper_or_rem),
   .i_op_valid      (mult_op_valid),
   .o_host_stall    (mult_busy),

   .o_res           (mult_res),
   .o_res_valid     (mult_res_valid),
   .i_host_stall    (stall2mult)
);

//===================================================================
// Divider Instantiation
//===================================================================
pqDivider_top inst_pqDivider_top (
   .clk             (clk),
   .aresetn         (aresetn),

   .i_flush         (i_flush),

   .i_op0           (i_op0),
   .i_op1           (i_op1),
   .i_is_signed_op0 (i_is_signed_op0),
   .i_is_signed_op1 (i_is_signed_op1),
   .i_use_remainder (i_use_upper_or_rem),
   .i_op_valid      (div_op_valid),
   .o_host_stall    (div_busy),

   .o_res           (div_res),
   .o_res_valid     (div_res_valid),
   .i_host_stall    (stall2div)
);

//===================================================================
// Stall logic
//---------------------------------------------------------------
// MULT and DIV share the single Result Interface, so one must be
// held back while the other is completing/using it; each is also
// stalled by the Host stall.
//===================================================================
assign stall2mult    = i_stall | div_busy  ;
assign stall2div     = i_stall | mult_busy ;
assign o_multdiv_stall = mult_busy | div_busy ;

//===================================================================
// Result mux
//---------------------------------------------------------------
// MULT and DIV results are mutually exclusive by construction, cz
// of the mutual stalling above.
//===================================================================
assign o_res       = mult_res_valid ? mult_res : div_res ;
assign o_res_valid = mult_res_valid | div_res_valid       ;

endmodule
//###################################################################################################################################################
//                                                             P Q M U L T D I V   T O P
//###################################################################################################################################################
