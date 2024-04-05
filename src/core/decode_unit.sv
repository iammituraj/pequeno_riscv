//     %%%%%%%%%#      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//  %%%%%%%%%%%%%%%%%  ------------------------------------------------------------------------------------------------------------------------------
// %%%%%%%%%%%%%%%%%%%% %
// %%%%%%%%%%%%%%%%%%%% %%
//    %% %%%%%%%%%%%%%%%%%%
//        % %%%%%%%%%%%%%%%                 //---- O P E N - S O U R C E ----//
//           %%%%%%%%%%%%%%                 ╔═══╦╗──────────────╔╗──╔╗
//           %%%%%%%%%%%%%      %%          ║╔═╗║║──────────────║║──║║
//           %%%%%%%%%%%       %%%%         ║║─╚╣╚═╦╦══╦╗╔╦╗╔╦═╗║║╔╗║║──╔══╦══╦╦══╗
//          %%%%%%%%%%        %%%%%%        ║║─╔╣╔╗╠╣╔╗║╚╝║║║║╔╗╣╚╝╝║║─╔╣╔╗║╔╗╠╣╔═╝ \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
//         %%%%%%%    %%%%%%%%%%%%*%%%      ║╚═╝║║║║║╚╝║║║║╚╝║║║║╔╗╗║╚═╝║╚╝║╚╝║║╚═╗ /////////////////////////////////////////////////////////////////
//        %%%%% %%%%%%%%%%%%%%%%%%%%%%%     ╚═══╩╝╚╩╣╔═╩╩╩╩══╩╝╚╩╝╚╝╚═══╩══╩═╗╠╩══╝
//       %%%%*%%%%%%%%%%%%%  %%%%%%%%%      ────────║║─────────────────────╔═╝║
//       %%%%%%%%%%%%%%%%%%%    %%%%%%%%%   ────────╚╝─────────────────────╚══╝
//       %%%%%%%%%%%%%%%%                   c h i p m u n k l o g i c . c o m
//       %%%%%%%%%%%%%%
//         %%%%%%%%%
//           %%%%%%%%%%%%%%%%  ----------------------------------------------------------------------------------------------------------------------
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% 
//----%% File Name        : decode_unit.sv
//----%% Module Name      : Decode Unit (DU)                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Decode Unit (DU) of PQR5 Core.
//----%%                    # Decodes all instructions fetched by Fetch Unit (FU).
//----%%                    # Sends decoded register addresses to Register File/Execution Unit (EXU).
//----%%                    # Sends decoded instruction fields, type, opcode, immediates to EXU.
//----%%                    # Single cycle latency pipeline.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Feb-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see developer.txt.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                              D E C O D E   U N I T                                         
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module decode_unit #(
   // Configurable parameters
   parameter PC_INIT = `PC_INIT  // Init PC on reset
)
(
   // Clock and Reset
   input  logic             clk                ,  // Clock
   input  logic             aresetn            ,  // Asynchronous Reset; active-low

   `ifdef DBG
   // Debug Interface  
   output logic [9:0]       o_du_dbg           ,  // Debug signal
   `endif

   // Interface with Fetch Unit (FU)
   input  logic [`XLEN-1:0] i_fu_pc            ,  // PC from FU
   input  logic [`ILEN-1:0] i_fu_instr         ,  // Instruction from FU
   input  logic             i_fu_bubble        ,  // Bubble from FU
   input  logic             i_fu_br_taken      ,  // Branch taken status from FU
   output logic             o_fu_stall         ,  // Stall signal to FU

   // Interface with Register File (RF)
   output logic             o_rf_rden          ,  // Read Enable to RF
   output logic [4:0]       o_rf_rs0           ,  // rs0 (source register-0) address to RF
   output logic [4:0]       o_rf_rs1           ,  // rs1 (source register-1) address to RF   
   
   // Interface with Execution Unit (EXU)
   input  logic             i_exu_bu_flush     ,  // Flush signal from EXU-BU
   input  logic [`XLEN-1:0] i_exu_bu_pc        ,  // Branch PC from EXU-BU
   output logic             o_exu_bu_br_taken  ,  // Branch taken status to EXU-BU

   output logic [`XLEN-1:0] o_exu_pc           ,  // PC to EXU
   output logic [`ILEN-1:0] o_exu_instr        ,  // Instruction decoded and sent to EXU
   output logic             o_exu_bubble       ,  // Bubble to EXU
   input  logic             i_exu_stall        ,  // Stall signal from EXU

   output logic [6:0]       o_exu_opcode       ,  // Instruction opcode to EXU
   output logic [3:0]       o_exu_alu_opcode   ,  // ALU opcode to EXU
   output logic [4:0]       o_exu_rs0          ,  // rs0 (source register-0) address to EXU
   output logic [4:0]       o_exu_rs1          ,  // rs1 (source register-1) address to EXU
   output logic [4:0]       o_exu_rdt          ,  // rdt (destination register) address to EXU
   output logic [2:0]       o_exu_funct3       ,  // funct3 to EXU
   output logic [6:0]       o_exu_funct7       ,  // funct7 to EXU

   output logic             o_exu_is_r_type    ,  // R-type instruction flag to EXU
   output logic             o_exu_is_i_type    ,  // I-type instruction flag to EXU
   output logic             o_exu_is_s_type    ,  // S-type instruction flag to EXU
   output logic             o_exu_is_b_type    ,  // B-type instruction flag to EXU
   output logic             o_exu_is_u_type    ,  // U-type instruction flag to EXU
   output logic             o_exu_is_j_type    ,  // J-type instruction flag to EXU
   output logic [11:0]      o_exu_i_type_imm   ,  // I-type immediate to EXU
   output logic [11:0]      o_exu_s_type_imm   ,  // S-type immediate to EXU
   output logic [11:0]      o_exu_b_type_imm   ,  // B-type immediate to EXU
   output logic [19:0]      o_exu_u_type_imm   ,  // U-type immediate to EXU
   output logic [19:0]      o_exu_j_type_imm      // J-type immediate to EXU
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// Instruction decoding related
logic [4:0]       rf_reg_src0         ;  // Source register-0 address
logic [4:0]       rf_reg_src1         ;  // Source register-1 address
logic [6:0]       fu_opcode           ;  // Opcode decoded from FU
logic [5:0]       instr_type_rg       ;  // {R, I, S, B, U, J} type instruction flag (one-hot encoded)

// EXU control specific
logic [`XLEN-1:0] du_pc_rg            ;  // PC buffered
logic [`ILEN-1:0] du_instr_rg         ;  // Instruction buffered for decoding
logic             du_bubble_rg        ;  // Bubble
logic             du_br_taken_rg      ;  // Branch taken status
logic [4:0]       reg_src0, reg_src1  ;  // Source register addresses
logic [4:0]       reg_dest            ;  // Destination register address
logic [6:0]       du_opcode           ;  // Opcode
logic             is_r_type           ;  // R-type instruction flag
logic             is_i_type           ;  // I-type instruction flag
logic             is_s_type           ;  // S-type instruction flag
logic             is_b_type           ;  // B-type instruction flag
logic             is_u_type           ;  // U-type instruction flag
logic             is_j_type           ;  // J-type instruction flag
logic [2:0]       funct3              ;  // funct3
logic [6:0]       funct7              ;  // funct7
logic             is_op_alui          ;  // I-type ALU instruction flag
logic             is_sli_sri          ;  // SLLI/SRLI/SRAI funct3 field flag
logic [3:0]       alu_opcode          ;  // ALU opcode

// Stall logic specific
logic             stall               ;  // Stall from outside FU
logic             du_stall            ;  // Stall generated by DU to FU

// Flush logic specific
logic             flush               ;  // Flush from outside FU

//===================================================================================================================================================
// Synchronous logic to decode instruction type
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin

   // Reset   
   if (!aresetn) begin
      instr_type_rg <= 6'b000000 ;        
   end
   // Out of reset
   else begin 
      // If not stalled
      if (!stall) begin
         case (fu_opcode)  
            OP_ALU    : instr_type_rg <= 6'b100000 ;  // R-type
            //7'h73,  // ECALL/EBREAK/CSRR* 
            //7'h0F,  // FENCE
            OP_JALR,
            OP_LOAD,
            OP_ALUI   : instr_type_rg <= 6'b010000 ;  // I-type
            OP_STORE  : instr_type_rg <= 6'b001000 ;  // S-type
            OP_BRANCH : instr_type_rg <= 6'b000100 ;  // B-type
            OP_LUI,
            OP_AUIPC  : instr_type_rg <= 6'b000010 ;  // U-type
            OP_JAL    : instr_type_rg <= 6'b000001 ;  // J-type
            default   : instr_type_rg <= 6'b000000 ;  // Invalid instruction type
         endcase     
      end                   
   end

end

//===================================================================================================================================================
// Synchronous logic to pipe PC
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn)       begin du_pc_rg <= PC_INIT     ; end
   else if (i_exu_bu_flush) begin du_pc_rg <= i_exu_bu_pc ; end  // Pipe in EXU-BU PC on flush
   else if (!stall)         begin du_pc_rg <= i_fu_pc     ; end  // Pipe through...
end

//===================================================================================================================================================
// Synchronous logic to pipe instruction
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin du_instr_rg <= `INSTR_NOP ; end
   else if (flush)    begin du_instr_rg <= `INSTR_NOP ; end  // Pipe in NOP instruction on flush
   else if (!stall)   begin du_instr_rg <= i_fu_instr ; end  // Pipe through... 
end

//===================================================================================================================================================
// Synchronous logic to insert/pipe bubble
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin du_bubble_rg <= 1'b1 ;        end
   else if (flush)    begin du_bubble_rg <= 1'b1 ;        end  // Invalidate on flush
   else if (!stall)   begin du_bubble_rg <= i_fu_bubble ; end  // Pipe through...
end

//===================================================================================================================================================
// Synchronous logic to pipe branch taken status
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin du_br_taken_rg <= 1'b0          ; end
   else if (!stall)   begin du_br_taken_rg <= i_fu_br_taken ; end  // Pipe through...
end

assign o_exu_bu_br_taken = du_br_taken_rg ;

//===================================================================================================================================================
// ALU opcode encoding logic
//===================================================================================================================================================
always_comb begin
   if (is_r_type) begin  // R-type instruction is always ALU instruction
      alu_opcode = {funct3, funct7[5]} ;
   end 
   else if (is_op_alui) begin  // I-type ALU instruction
      alu_opcode = is_sli_sri ? {funct3, funct7[5]} : {funct3, 1'b0} ;  // LSb = 0 except if SLLI/SRLI/SRAI 
   end 
   else if (is_u_type) begin   // U-type instruction is always ALU instruction: LUI/AUIPC requires ADD at ALU
      alu_opcode = ALU_ADD ;   
   end
   else begin                  // Illegal ALU instruction
      alu_opcode = ALU_ILLG ;
   end
end

assign is_op_alui = (du_opcode == OP_ALUI) ;
assign is_sli_sri = (funct3 == F3_SLLX || funct3 == F3_SRXX) ;

//===================================================================================================================================================
//  Stall logic
//===================================================================================================================================================
assign stall      = i_exu_stall          ;  // Only EXU can stall DU from outside
assign du_stall   = stall & ~i_fu_bubble ;  // If invalid instruction from FU, stall need not be generated to FU   
assign o_fu_stall = du_stall             ;  // Stall signal to FU

//===================================================================================================================================================
//  Flush logic
//===================================================================================================================================================
assign flush = i_exu_bu_flush ;  // Only EXU-BU can flush FU from outside

//===================================================================================================================================================
// Continuous assignments
//===================================================================================================================================================
`ifdef DBG
// Debug Interface
assign o_du_dbg = {(du_opcode == OP_LUI), (du_opcode == OP_JALR), (du_opcode == OP_LOAD), is_op_alui, instr_type_rg} ;
`endif

// Other internal signals
assign fu_opcode  = i_fu_instr[6:0]    ;
assign reg_src0   = du_instr_rg[19:15] ;
assign reg_src1   = du_instr_rg[24:20] ;
assign reg_dest   = du_instr_rg[11:7]  ;
assign du_opcode  = du_instr_rg[6:0]   ;
assign is_r_type  = instr_type_rg[5]   ;
assign is_i_type  = instr_type_rg[4]   ;
assign is_s_type  = instr_type_rg[3]   ;
assign is_b_type  = instr_type_rg[2]   ;
assign is_u_type  = instr_type_rg[1]   ;
assign is_j_type  = instr_type_rg[0]   ;
assign funct3     = du_instr_rg[14:12] ;
assign funct7     = du_instr_rg[31:25] ;

// Interface with Register File (RF)
assign o_rf_rden    = ~stall            ;  // DU and RF (read-side) are at the same stage of pipeline, so they should stall together always
assign rf_reg_src0  = i_fu_instr[19:15] ; 
assign rf_reg_src1  = i_fu_instr[24:20] ;
assign o_rf_rs0     = rf_reg_src0       ;  // Combi routing to sync RF read-data with DU outputs to EXU 
assign o_rf_rs1     = rf_reg_src1       ;  // Combi routing to sync RF read-data with DU outputs to EXU

// Interface with Execution Unit (EXU)
assign o_exu_pc         = du_pc_rg    ;
assign o_exu_instr      = du_instr_rg ;
assign o_exu_bubble     = flush | du_bubble_rg ;  // Flush should invalidate next instruction from going to EXU and executed  
                                                  // This is to avoid control hazards on branching                                                        
assign o_exu_opcode     = du_opcode  ;
assign o_exu_alu_opcode = alu_opcode ;
assign o_exu_rs0        = reg_src0   ;
assign o_exu_rs1        = reg_src1   ;
assign o_exu_rdt        = reg_dest   ;
assign o_exu_funct3     = funct3     ;
assign o_exu_funct7     = funct7     ;

assign o_exu_is_r_type  = is_r_type  ;
assign o_exu_is_i_type  = is_i_type  ;
assign o_exu_is_s_type  = is_s_type  ;
assign o_exu_is_b_type  = is_b_type  ;
assign o_exu_is_u_type  = is_u_type  ;
assign o_exu_is_j_type  = is_j_type  ;
assign o_exu_i_type_imm = {du_instr_rg[31:20]}                                                       ;
assign o_exu_s_type_imm = {du_instr_rg[31:25], du_instr_rg[11:7]}                                    ;
assign o_exu_b_type_imm = {du_instr_rg[31], du_instr_rg[7], du_instr_rg[30:25], du_instr_rg[11:8]}   ;
assign o_exu_u_type_imm = {du_instr_rg[31:12]}                                                       ;
assign o_exu_j_type_imm = {du_instr_rg[31], du_instr_rg[19:12], du_instr_rg[20], du_instr_rg[30:21]} ;

endmodule
//###################################################################################################################################################
//                                                              D E C O D E   U N I T                                         
//###################################################################################################################################################