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
//----%% File Name        : booth_multiplier_x32r4.sv
//----%% Module Name      : 32-bit Booth Multiplier (Radix-4)                              
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : 32-bit Multiplier which supports RV32's M extension and implements Booth algorithm at Radix-2.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : July-2026
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                 B O O T H   M U L T I P L I E R   X 3 2 R 4                              
//###################################################################################################################################################
// Module definition
module booth_multiplier_x32r4 (
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

///////////////////////////////////////////////////////////////////////////////
// Instruction Mapping
//
// +----------+-----------------+-----------------+------------------+
// | Instr    | is_signed_op0   | is_signed_op1   | use_upperbits    |
// +----------+-----------------+-----------------+------------------+
// | MUL      |        0        |        0        |        0         |
// | MULH     |        1        |        1        |        1         |
// | MULHSU   |        1        |        0        |        1         |
// | MULHU    |        0        |        0        |        1         |
// +----------+-----------------+-----------------+------------------+
///////////////////////////////////////////////////////////////////////////////

//===================================================================
// Internal Registers/Signals
//===================================================================
// Control FSM states
typedef enum logic [1:0] {
    IDLE   = 2'b00,
    EXEC   = 2'b01,
    RESULT = 2'b10
} state_t;

state_t      state_ff;      // State register
logic        stall_ff;      // Stall to Host
logic        use_upp_ff;    // Use upper bits (UUB) flag registered by the Control FSM
logic [31:0] res_out_ff;    // Result registered
logic        res_valid_ff;  // Result valid

// Booth algorithm specific
logic signed [32:0] mcand_ff;    // Registered multiplicand
logic signed [68:0] prod_next;   // Next partial product
logic signed [68:0] prod_ff;     // Product register {Accumulator, Multiplier, Q-1}
logic         [4:0] iter_ff;     // Booth iteration counter

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
      use_upp_ff   <= 1'b0;
   end
   // Flush --> Highest priority; clear the valid/stall and flush the FSM back to IDLE
   else if (i_flush) begin
      // Same condition as IDLE
      state_ff     <= IDLE;
      res_out_ff   <= '0;
      res_valid_ff <= 1'b0;
      stall_ff     <= 1'b0;
   end
   // FSM execution
   else begin
      case (state_ff)
         ////////////////////////////////////////////////////////////
         // IDLE state: 
         // Waits here to get a valid request from Host
         // Initializes Radix-4 Booth algorithm
         ////////////////////////////////////////////////////////////
         IDLE: begin
            // Pull down result valid 1->0 when the Host has accepted the result
            if (!i_host_stall) begin
               res_valid_ff <= 1'b0;
            end
            // Valid request received and Host is ready?
            if (!i_host_stall && i_op_valid) begin
               // Stall the Host until the multiplication completes
               stall_ff     <= 1'b1;

               // Set flags and move to next state
               use_upp_ff   <= i_use_upperbits;
               state_ff     <= EXEC;
            end
         end

         ////////////////////////////////////////////////////////////
         // EXEC state:
         // Performs one Radix-4 Booth iteration every clock.
         // Total iterations = 17 (16..0): 16 groups for the 32 multiplier
         // bits plus 1 extra group to correctly consume the 2-bit
         // sign/zero-extension guard on the multiplier (needed so that unsigned
         // operands with bit[31] set are handled correctly, not just signed ones)
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
               res_out_ff   <= use_upp_ff ? prod_ff[64:33] : prod_ff[32:1];
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

// Booth datapath registers (mcand_ff, prod_ff, iter_ff)
// No reset for better PPA
always_ff @(posedge clk) begin
   case (state_ff)
      ////////////////////////////////////////////////////////////
      // IDLE state:
      // Waits here to get a valid request from Host
      // Initializes Radix-4 Booth algorithm
      ////////////////////////////////////////////////////////////
      IDLE: begin
         // Valid request received and Host is ready?
         if (!i_host_stall && i_op_valid) begin
            // Initialize
            mcand_ff <= {(i_is_signed_op0 & i_op0[31]), i_op0};
            prod_ff  <= {34'd0, (i_is_signed_op1 & i_op1[31]), (i_is_signed_op1 & i_op1[31]), i_op1, 1'b0};  // Booth product; {Accumulator[34 bits], multiplier[34 bits: 2-bit ext + 32 data], Q-1(init)}
            iter_ff  <= 5'd16;  // = No. of iterations reqd
         end
      end

      ////////////////////////////////////////////////////////////
      // EXEC state:
      // Performs one Radix-4 Booth iteration every clock.
      // Total iterations = 17 (16..0): 16 groups for the 32 multiplier
      // bits plus 1 extra group to correctly consume the 2-bit
      // sign/zero-extension guard on the multiplier (needed so that unsigned
      // operands with bit[31] set are handled correctly, not just signed ones)
      ////////////////////////////////////////////////////////////
      EXEC: begin
         // Update the product register with the next Booth iteration
         prod_ff <= prod_next;
         iter_ff <= iter_ff - 5'd1;
      end

      // DEFAULT
      default: ;
   endcase
end

//===================================================================
// One Radix-4 Booth iteration
//===================================================================
// Internal signals
logic signed [33:0] acc;
logic        [33:0] mult;
logic               q_1;
logic signed [68:0] prod_sum, prod_sum_sr2;
logic signed [33:0] mcand_ff_sl1;
logic signed [33:0] booth_operand;  // Magnitude selected for this Booth case: 0, mcand_ff, or mcand_ff_sl1
logic               booth_sub;      // '0'- add booth_operand, '1'- subtract it; one shared adder/subtractor for all cases below

// Iteration logic
always_comb begin
   //---------------------------------------------------------------
   // Unpack product register
   //---------------------------------------------------------------
   acc  = prod_ff[68:35];
   mult = prod_ff[34:1];
   q_1  = prod_ff[0];

   //---------------------------------------------------------------
   // Booth recoding: select magnitude (0, M, 2M) and sign only; the add/sub itself is common below
   //---------------------------------------------------------------
   case ({mult[1:0], q_1})
      // 000,111 -> 0
      3'b000,
      3'b111: begin
         booth_operand = '0;
         booth_sub     = 1'b0;
      end

      // +M
      3'b001,
      3'b010: begin
         booth_operand = mcand_ff;
         booth_sub     = 1'b0;
      end

      // +2M
      3'b011: begin
         booth_operand = mcand_ff_sl1;
         booth_sub     = 1'b0;
      end

      // -2M
      3'b100: begin
         booth_operand = mcand_ff_sl1;
         booth_sub     = 1'b1;
      end

      // -M
      3'b101,
      3'b110: begin
         booth_operand = mcand_ff;
         booth_sub     = 1'b1;
      end

      // DEFAULT
      default: begin
         booth_operand = '0;
         booth_sub     = 1'b0;
      end
   endcase

   // Add/subtract from acc
   acc = booth_sub ? (acc - booth_operand) : (acc + booth_operand);

   // Pack updated product
   prod_sum = {acc, mult, q_1};

   // Arithmetic right shift by 2 (Radix-4 Booth)
   prod_sum_sr2 = prod_sum >>> 2;
   prod_next    = prod_sum_sr2;
end

assign mcand_ff_sl1 = {mcand_ff[32], mcand_ff} <<< 1;

// Stall out
assign o_host_stall = stall_ff;

// Results out
assign o_res       = res_out_ff;
assign o_res_valid = res_valid_ff;

endmodule
//###################################################################################################################################################
//                                                 B O O T H   M U L T I P L I E R   X 3 2 R 4                              
//###################################################################################################################################################