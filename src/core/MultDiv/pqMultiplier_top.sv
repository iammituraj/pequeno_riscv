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
//----%% File Name        : pqMultiplier_top.sv
//----%% Module Name      : pqMultiplier Top
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Top-level wrapper for the pqMultiplier. 
//----%%                    Instantiates the RV32IM compliant 32-bit multiplier, supports selecting between:
//----%%                    - DSP multiplier (To target FPGA DSP slices)
//----%%                    - Booth multiplier (Radix-4)
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Jul-2026
//----%% Notes            : -
//----%%
//----%% Copyright        : Open-source license, see LICENSE.
//----%%
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                             P Q M U L T I P L I E R   T O P
//###################################################################################################################################################
// Module definition
module pqMultiplier_top #(
   // Configurable Parameters
   parameter EN_FPGA_DSP_MULT = 1,  // 1 = use x32 DSP multiplier, 0 = use x32 Radix-4 Booth multiplier
   parameter PIPE_STAGES      = 4   // No. of DSP multiplier pipeline stages; valid value >=2; applies only when EN_FPGA_DSP_MULT=1
)(
   // Clock & Reset
   input  logic       clk,                // Clock
   input  logic       aresetn,            // Async Reset active-low

   // Flush
   input  logic       i_flush,            // Flush

   // Operand Interface
   input  logic [31:0] i_op0,             // Operand0 = rs1
   input  logic [31:0] i_op1,             // Operand1 = rs2
   input  logic        i_is_signed_op0,   // Is operand0 signed?
   input  logic        i_is_signed_op1,   // Is operand1 signed?
   input  logic        i_use_upperbits,   // Use upper bits of the result
   input  logic        i_op_valid,        // Operands valid
   output logic        o_host_stall,      // Stall to Host

   // Result Interface
   output logic [31:0] o_res,             // Result = op0*op1
   output logic        o_res_valid,       // Result valid
   input  logic        i_host_stall       // Stall from Host
);

//===================================================================
// Multiplier Selection
//===================================================================
// EN_FPGA_DSP_MULT=1 --> Instantiate the DSP-based multiplier
// EN_FPGA_DSP_MULT=0 --> Instantiate the Booth (fabric) multiplier
//===================================================================
generate
if (EN_FPGA_DSP_MULT) begin : DSP_MULT
   dsp_multiplier_x32 #(
      .PIPE_STAGES     (PIPE_STAGES)
   ) inst_dsp_multiplier_x32 (
      .clk             (clk),
      .aresetn         (aresetn),

      .i_flush         (i_flush),

      .i_op0           (i_op0),
      .i_op1           (i_op1),
      .i_is_signed_op0 (i_is_signed_op0),
      .i_is_signed_op1 (i_is_signed_op1),
      .i_use_upperbits (i_use_upperbits),
      .i_op_valid      (i_op_valid),
      .o_host_stall    (o_host_stall),

      .o_res           (o_res),
      .o_res_valid     (o_res_valid),
      .i_host_stall    (i_host_stall)
   );
end else begin : BOOTH_MULT
   booth_multiplier_x32r4 inst_booth_multiplier_x32r4 (
      .clk             (clk),
      .aresetn         (aresetn),

      .i_flush         (i_flush),

      .i_op0           (i_op0),
      .i_op1           (i_op1),
      .i_is_signed_op0 (i_is_signed_op0),
      .i_is_signed_op1 (i_is_signed_op1),
      .i_use_upperbits (i_use_upperbits),
      .i_op_valid      (i_op_valid),
      .o_host_stall    (o_host_stall),

      .o_res           (o_res),
      .o_res_valid     (o_res_valid),
      .i_host_stall    (i_host_stall)
   );
end
endgenerate

endmodule
//###################################################################################################################################################
//                                                             P Q M U L T I P L I E R   T O P
//###################################################################################################################################################
