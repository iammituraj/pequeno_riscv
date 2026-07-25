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
//----%% File Name        : dsp_multiplier_x32.sv
//----%% Module Name      : 32-bit DSP Multiplier
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : 32-bit Multiplier which supports RV32's M extension and implements a configurable-latency, DSP-inferred pipeline.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : July-2026
//----%% Notes            : -
//----%%
//----%% Copyright        : Open-source license, see LICENSE.
//----%%
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                       D S P   M U L T I P L I E R   X 3 2
//###################################################################################################################################################
// Module definition
module dsp_multiplier_x32 #(
   // Configurable Parameters
   parameter PIPE_STAGES = 3  // No. of Multiplier pipeline stages; valid value >=2
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
// Localparams
//===================================================================
localparam N      = PIPE_STAGES;  // Multiplier pipeline stages; valid values = 2,3
localparam T_WAIT = 2'(N-1);  // Wait counter load value = N-1

//===================================================================
// Internal Registers/Signals
//===================================================================
// Control FSM states
typedef enum logic [1:0] {
    IDLE   = 2'b00,
    EXEC   = 2'b01,
    RESULT = 2'b10
} state_t;

state_t        state_ff;             // State register
logic          stall_ff;             // Stall to Host
logic   [31:0] res_out, res_out_ff;  // Result registered by the Control FSM
logic          res_valid_ff;         // Result valid
logic   [32:0] op0_ff, op1_ff;       // Operands registered by the Control FSM
logic          use_upp_ff;           // Use upper bits (UUB) flag registered by the Control FSM
logic  [N-1:0] use_upp_ff_d;         // UUB flag pipeline registers
logic          use_upp_retim;        // UUB flag retimed
logic    [1:0] wait_cnt_ff;          // Wait counter

//===================================================================
// Control FSM
//===================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      state_ff      <= IDLE;
      stall_ff      <= 1'b0;
      res_out_ff    <= '0;
      res_valid_ff  <= 1'b0;
      // No reset for better PPA
      //op0_ff        <= '0;
      //op1_ff        <= '0;
      //use_upp_ff    <= 1'b0;
      //wait_cnt_ff   <= T_WAIT;
   end
   // Flush --> Highest priority; clear the valid/stall and flush the FSM back to IDLE
   else if (i_flush) begin
      state_ff     <= IDLE;
      use_upp_ff   <= 1'b0;
      res_valid_ff <= 1'b0;
      stall_ff     <= 1'b0;
   end
   // FSM execution
   else begin
      case (state_ff)
         ////////////////////////////////////////////////////////////
         // IDLE state: 
         // Waits here to get a valid request from Host
         ////////////////////////////////////////////////////////////
         IDLE: begin
            // Reload the wait counter
            wait_cnt_ff  <= T_WAIT;

            // Pull down result valid 1->0 when the Host has accepted the result
            if (!i_host_stall) begin
               res_valid_ff <= 1'b0;
            end
            // Valid request received and Host is ready?
            if (!i_host_stall && i_op_valid) begin
                stall_ff     <= 1'b1;  // Stall the Host until the multiplication completes
                op0_ff       <= {(i_is_signed_op0 ? i_op0[31] : 1'b0), i_op0};  // Sign extend & register the operands on valid
                op1_ff       <= {(i_is_signed_op1 ? i_op1[31] : 1'b0), i_op1};
                use_upp_ff   <= i_use_upperbits;
                state_ff     <= EXEC;
            end  
         end

         ////////////////////////////////////////////////////////////
         // EXEC state: 
         // Waits here for fixed no. of wait cycles until Multiplier 
         // pipeline executes through and the result is available.
         // Multiplier pipeline cannot be stalled by the Host
         ////////////////////////////////////////////////////////////
         EXEC: begin
            wait_cnt_ff <= wait_cnt_ff - 2'd1;
            // Wait cycles expired?
            if (~|wait_cnt_ff) begin
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
               res_out_ff   <= res_out;
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

//===================================================================
// UUB Flag Retiming Pipeline
//===================================================================
// This flag pipeline cannot be stalled by the Host
// No reset required
always_ff @(posedge clk) begin
   // Stage-1
   use_upp_ff_d[0] <= use_upp_ff;

   // Remaining pipeline stages; N>1
   for (int i=1; i<N; i++) begin
      use_upp_ff_d[i] <= use_upp_ff_d[i-1];
   end
end
assign use_upp_retim = use_upp_ff_d[N-1];

//===================================================================
// Multiplier Pipeline
//===================================================================
// Multiplier signals
logic signed [32:0] mult_in0_ff, mult_in1_ff;
(* use_dsp = "yes" *)
logic signed [65:0] mult_out, mult_out_ff;

// Multiplier pipeline to register input and compute result
// Cannot be stalled by the Host
// No reset required; async reset may not be supported by DSP multipliers as well...
always_ff @(posedge clk) begin
   // Stage-1 --> Register the inputs
   mult_in0_ff <= op0_ff;
   mult_in1_ff <= op1_ff;

   // Stage-2  --> Multiply
   mult_out_ff <= mult_in0_ff * mult_in1_ff;
end

generate
if (N > 2) begin : MULT_OUT_REG
   // Multiplier pipeline to register output
   // Cannot be stalled by the Host
   // No reset required
   logic signed [65:0] mult_out_ff_d[N-2];
   always_ff @(posedge clk) begin
      mult_out_ff_d[0] <= mult_out_ff;
      for (int i=1; i<N-2; i++) begin
         mult_out_ff_d[i] <= mult_out_ff_d[i-1];
      end
   end
   assign mult_out = mult_out_ff_d[N-3];
end else begin : MULT_OUT_WIRE
   assign mult_out = mult_out_ff;
end
endgenerate

//===================================================================
// Result Mux
//===================================================================
always_comb begin
   if (use_upp_retim) res_out = mult_out[63:32];
   else               res_out = mult_out[31:0];
end

// Stall out
assign o_host_stall = stall_ff;

// Results out
assign o_res       = res_out_ff;
assign o_res_valid = res_valid_ff;

/////////////////////////////////////////////////////////////////////
// ASSERTION for PIPE STAGES
/////////////////////////////////////////////////////////////////////
generate
if (PIPE_STAGES < 2) begin
    initial begin
       $fatal(1, "dsp_multiplier_x32 PIPE_STAGES must be >=2");
   end
end
endgenerate

endmodule
//###################################################################################################################################################
//                                                       D S P   M U L T I P L I E R   X 3 2
//###################################################################################################################################################