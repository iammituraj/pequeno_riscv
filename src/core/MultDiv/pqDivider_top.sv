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
//----%% File Name        : pqDivider_top.sv
//----%% Module Name      : pqDivider Top
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Top-level wrapper for the pqDivider. Instantiates the RV32IM compliant 32-bit non-restoring divider (Radix-2).
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Jul-2026
//----%% Notes            : -
//----%%
//----%% Copyright        : Open-source license, see LICENSE.
//----%%
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                             P Q D I V I D E R   T O P
//###################################################################################################################################################
// Module definition
module pqDivider_top (
   // Clock & Reset
   input  logic       clk,                // Clock
   input  logic       aresetn,            // Async Reset active-low

   // Flush
   input  logic       i_flush,            // Flush

   // Operand Interface
   input  logic [31:0] i_op0,             // Operand0 = rs1 (Dividend)
   input  logic [31:0] i_op1,             // Operand1 = rs2 (Divisor)
   input  logic        i_is_signed_op0,   // Is operand0 signed?
   input  logic        i_is_signed_op1,   // Is operand1 signed?
   input  logic        i_use_remainder,   // 0 = Quotient (DIV/DIVU), 1 = Remainder (REM/REMU)
   input  logic        i_op_valid,        // Operands valid
   output logic        o_host_stall,      // Stall to Host

   // Result Interface
   output logic [31:0] o_res,             // Result = quotient or remainder per i_use_remainder
   output logic        o_res_valid,       // Result valid
   input  logic        i_host_stall       // Stall from Host
);

//==================================================================================================
// Divider Instantiation
//==================================================================================================
nrestore_divider_x32r2 inst_nrestore_divider_x32r2 (
   .clk             (clk),
   .aresetn         (aresetn),

   .i_flush         (i_flush),

   .i_op0           (i_op0),
   .i_op1           (i_op1),
   .i_is_signed_op0 (i_is_signed_op0),
   .i_is_signed_op1 (i_is_signed_op1),
   .i_use_remainder (i_use_remainder),
   .i_op_valid      (i_op_valid),
   .o_host_stall    (o_host_stall),

   .o_res           (o_res),
   .o_res_valid     (o_res_valid),
   .i_host_stall    (i_host_stall)
);

endmodule
//###################################################################################################################################################
//                                                             P Q D I V I D E R   T O P
//###################################################################################################################################################
