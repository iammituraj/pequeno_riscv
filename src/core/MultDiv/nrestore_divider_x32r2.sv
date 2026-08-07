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
//----%% File Name        : nrestore_divider_x32r2.sv
//----%% Module Name      : 32-bit Non-restore Divider (Radix-2)                              
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : 32-bit Divider which supports RV32's M extension and implements Non-restoring division algorithm at Radix-2.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : July-2026
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                 N O N  -  R E S T O R E   D I V I D E R   X 3 2 R 2                              
//###################################################################################################################################################
// Module definition
module nrestore_divider_x32r2 (
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

///////////////////////////////////////////////////////////////////////////////
// Instruction Mapping
//
// +----------+-----------------+-----------------+------------------+
// | Instr    | is_signed_op0   | is_signed_op1   | use_remainder    |
// +----------+-----------------+-----------------+------------------+
// | DIV      |        1        |        1        |        0         |
// | DIVU     |        0        |        0        |        0         |
// | REM      |        1        |        1        |        1         |
// | REMU     |        0        |        0        |        1         |
// +----------+-----------------+-----------------+------------------+
///////////////////////////////////////////////////////////////////////////////

//=============================================================================
// Internal Registers/Signals
//=============================================================================
// Control FSM states
typedef enum logic [1:0] {
    IDLE   = 2'b00,
    EXEC   = 2'b01,
    RESULT = 2'b10
} state_t;

state_t       state_ff;           // State register
logic         stall_ff;           // Stall to Host
logic  [31:0] op0_ff;             // Operand-0 registered
logic         op0_sign, op1_sign; // Operand sign
logic  [31:0] op0_abs, op1_abs;   // Operand absolute value; |X|
logic         is_op1_zero;        // op1 == 0 ?
logic  [31:0] res_out_ff;         // Result registered
logic         res_valid_ff;       // Result valid

// Algorithm specific
logic  [31:0] q_next, q_ff;      // Quotient field
logic  [32:0] m_ff;              // Divisor field
logic  [32:0] acc_next, acc_ff;  // Accumulator field
logic   [5:0] iter_ff;           // Iteration counter
logic         quot_neg_ff;       // Quotient is negative flag
logic         rem_neg_ff;        // Remainder is negative flag
logic         use_rem_ff;        // Remainder flag
logic         div_by_zero_ff;    // Division-by-Zero (DBZ) flag
logic  [31:0] rem_out, rem_out_signed;    // Remainder at the end of the algorithm
logic  [31:0] quot_out, quot_out_signed;  // Quotient at the end of the algorithm

//===================================================================
// Control FSM
//===================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      state_ff     <= IDLE;
      stall_ff     <= 1'b0;
      res_out_ff   <= '0;
      res_valid_ff <= 1'b0;
      quot_neg_ff  <= 1'b0;
      rem_neg_ff   <= 1'b0;
      use_rem_ff   <= 1'b0;
      div_by_zero_ff <= 1'b0;
   end
   // Flush --> Highest priority; clear the valid/stall and flush the FSM back to IDLE
   else if (i_flush) begin
      // Same condition as IDLE
      state_ff     <= IDLE;
      stall_ff     <= 1'b0;
      res_out_ff   <= '0;
      res_valid_ff <= 1'b0;
   end
   // FSM execution
   else begin
      case (state_ff)
         ////////////////////////////////////////////////////////////
         // IDLE state:
         // Waits here to get a valid request from Host
         // Converts operands to absolute values and initializes the
         // non-restoring division iteration
         ////////////////////////////////////////////////////////////
         IDLE: begin
            // Pull down result valid 1->0 when the Host has accepted the result
            if (!i_host_stall) begin
               res_valid_ff <= 1'b0;
            end
            // Valid request received and Host is ready?
            if (!i_host_stall && i_op_valid) begin
                // Stall the Host until the division completes
                stall_ff <= 1'b1;

                // Flags
                quot_neg_ff    <= op0_sign ^ op1_sign;  // Quotient = -ve if only one operand is negative
                rem_neg_ff     <= op0_sign;         // Remainder takes dividend's sign
                use_rem_ff     <= i_use_remainder;  // Remainder flag
                div_by_zero_ff <= is_op1_zero;      // DBZ flag

                // Next state
                if (is_op1_zero) begin
                  state_ff <= RESULT;
                end else begin
                  state_ff <= EXEC;
                end
            end
         end

         ////////////////////////////////////////////////////////////
         // EXEC state:
         // Performs one radix-2 non-restoring iteration every clock.
         // Total iterations = 33 (0..32), one quotient bit per cycle.
         // One extra iteration for final correction.
         // On the final iteration, applies the end-of-loop
         // remainder correction (add divisor back if negative)
         ////////////////////////////////////////////////////////////
         EXEC: begin
            // Final iteration?
            if (~|iter_ff) begin
               state_ff <= RESULT;
            end
         end

         ////////////////////////////////////////////////////////////
         // RESULT state:
         // Sends the result to the Host
         ////////////////////////////////////////////////////////////
         RESULT: begin
            // Wait until the Host is ready to accept the result
            if (!i_host_stall) begin
               if (div_by_zero_ff) begin
                  res_out_ff   <= use_rem_ff ? op0_ff : 32'hFFFF_FFFF;  // RISC-V spec mandates Quotient = -1 or FF.. and Remainder = Dividert, on DBZ
               end else begin
                  res_out_ff   <= use_rem_ff ? rem_out_signed : quot_out_signed;  // Sign restoration
               end
               res_valid_ff <= 1'b1;
               stall_ff     <= 1'b0;
               state_ff     <= IDLE;
            end
         end

         // DEFAULT
         default: ;
      endcase
   end
end

// Divider datapath registers (op0_ff, q_ff, m_ff, acc_ff, iter_ff)
// No reset for better PPA
always_ff @(posedge clk) begin
   case (state_ff)
      ////////////////////////////////////////////////////////////
      // IDLE state:
      // Waits here to get a valid request from Host
      // Converts operands to absolute values and initializes the
      // non-restoring division iteration
      ////////////////////////////////////////////////////////////
      IDLE: begin
         // Valid request received and Host is ready?
         if (!i_host_stall && i_op_valid) begin
            // Initialize
            q_ff   <= op0_abs;              // Q = |op0|
            m_ff   <= {1'b0, op1_abs};      // M = |op1|
            acc_ff <= 33'd0;                // A = 0

            // Register raw operand-0 for later use in case of Divide-by-Zero error
            op0_ff  <= i_op0;
            iter_ff <= 6'd32;  // = No. of iterations reqd
         end
      end

      ////////////////////////////////////////////////////////////
      // EXEC state:
      // Performs one radix-2 non-restoring iteration every clock.
      // Total iterations = 33 (0..32), one quotient bit per cycle.
      // One extra iteration for final correction.
      // On the final iteration, applies the end-of-loop
      // remainder correction (add divisor back if negative)
      ////////////////////////////////////////////////////////////
      EXEC: begin
         iter_ff <= iter_ff - 6'd1;

         // Final iteration?
         if (~|iter_ff) begin
            if (acc_ff[32] == 1'b1) begin
               acc_ff <= acc_ff + m_ff;
            end
         end
         // Iterations 0-31
         else begin
            acc_ff <= acc_next;
            q_ff   <= q_next;
         end
      end

      // DEFAULT
      default: ;
   endcase
end

assign is_op1_zero = (i_op1 == 32'd0);

//---------------------------------------------------------
// Operand pre-processing
//---------------------------------------------------------
// Check sign
assign op0_sign = i_is_signed_op0 & i_op0[31];
assign op1_sign = i_is_signed_op1 & i_op1[31];

// Compute absolute value
// If -ve number, calculate 2's complement; MSB of the result can be ignored
assign op0_abs  = op0_sign ? (~i_op0 + 32'd1) : i_op0;
assign op1_abs  = op1_sign ? (~i_op1 + 32'd1) : i_op1;

//---------------------------------------------------------
// Next iteration parameters
//---------------------------------------------------------
wire [64:0] acc_q         = {acc_ff, q_ff};          // AQ
wire        acc_sign      = acc_ff[32];
wire [64:0] acc_q_lshift1 = {acc_q[63:0], 1'b0};     // AQ << 1
wire [32:0] acc_temp      = acc_q_lshift1[64:32];
wire [31:0] q_temp        = acc_q_lshift1[31:0];
assign      acc_next      = acc_sign ? (acc_temp + m_ff) : (acc_temp - m_ff);
wire        acc_next_sign = acc_next[32];
assign      q_next        = {q_temp[31:1],~acc_next_sign};

// Results: Quotient and Remainder
assign  rem_out         = acc_ff[31:0];  // MSB of A can be ignored
assign  quot_out        = q_ff;
assign  rem_out_signed  = rem_neg_ff  ? (~rem_out  + 32'd1) : rem_out;   // If Remainder should be negative, take 2's complement
assign  quot_out_signed = quot_neg_ff ? (~quot_out + 32'd1) : quot_out;  // If Quotient should be negative, take 2's complement

// Stall out
assign o_host_stall = stall_ff;

// Result out
assign o_res       = res_out_ff;
assign o_res_valid = res_valid_ff;

endmodule
//###################################################################################################################################################
//                                                 N O N  -  R E S T O R E   D I V I D E R   X 3 2 R 2                              
//###################################################################################################################################################