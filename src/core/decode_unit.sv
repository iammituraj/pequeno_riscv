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
//----%% File Name        : decode_unit.sv
//----%% Module Name      : Decode Unit (DU)                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Decode Unit (DU) of PQR5 Core.
//----%%                    # Decodes the instruction fetched by Fetch Unit (FU).
//----%%                    # Sends the decoded register addresses to Register File for read.
//----%%                    # Sends the decoded information as payload to Execution Unit (EXU).
//----%%                    # Pipeline latency = 1 cycle
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Apr-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
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
   output logic             o_exu_bu_br_taken  ,  // Branch taken status to EXU-BU

   output logic [`XLEN-1:0] o_exu_pc           ,  // PC to EXU
   `ifdef DBG
   output logic [`ILEN-1:0] o_exu_instr        ,  // Instruction decoded and sent to EXU
   `endif
   output logic             o_exu_bubble       ,  // Bubble to EXU
   output logic             o_exu_pkt_valid    ,  // Packet valid to EXU
   input  logic             i_exu_stall        ,  // Stall signal from EXU

   output logic             o_exu_is_alu_op    ,  // ALU operation flag to EXU
   output logic [3:0]       o_exu_alu_opcode   ,  // ALU opcode to EXU
   output logic [4:0]       o_exu_rs0          ,  // rs0 (source register-0) address to EXU
   output logic [4:0]       o_exu_rs0_cpy_ff   ,  // rs0 copy; Tapped by opfwd block...
   output logic [4:0]       o_exu_rs1          ,  // rs1 (source register-1) address to EXU
   output logic [4:0]       o_exu_rs1_cpy_ff   ,  // rs1 copy; Tapped by opfwd block...
   output logic [4:0]       o_exu_rdt          ,  // rdt (destination register) address to EXU
   output logic             o_exu_rdt_not_x0   ,  // rdt neq x0
   output logic [2:0]       o_exu_funct3       ,  // Funct3 to EXU

   output logic             o_exu_is_r_type    ,  // R-type instruction flag to EXU
   output logic             o_exu_is_i_type    ,  // I-type instruction flag to EXU
   output logic             o_exu_is_s_type    ,  // S-type instruction flag to EXU
   output logic             o_exu_is_b_type    ,  // B-type instruction flag to EXU
   output logic             o_exu_is_u_type    ,  // U-type instruction flag to EXU; Tapped by opfwd block...
   output logic             o_exu_is_rsb       ,  // RSB flag to EXU
   output logic             o_exu_is_risb      ,  // RISB flag to EXU
   output logic             o_exu_is_riuj      ,  // RIUJ flag to EXU
   output logic             o_exu_is_jalr      ,  // JALR flag to EXU
   output logic             o_exu_is_j_or_jalr ,  // J/JALR flag to EXU
   output logic             o_exu_is_load      ,  // Load flag to EXU
   output logic             o_exu_is_lui       ,  // LUI flag to EXU; Tapped by opfwd block...
   output logic [11:0]      o_exu_i_type_imm   ,  // I-type immediate to EXU
   output logic [11:0]      o_exu_s_type_imm   ,  // S-type immediate to EXU
   output logic [11:0]      o_exu_b_type_imm   ,  // B-type immediate to EXU
   output logic [19:0]      o_exu_u_type_imm      // U-type immediate to EXU; Tapped by opfwd block...
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// Decoded from FU packet
logic [4:0]       rf_reg_src0         ;  // Source register-0 address to RF
logic [4:0]       rf_reg_src1         ;  // Source register-1 address to RF
logic [6:0]       fu_opcode           ;  // Opcode decoded from FU instr
logic [2:0]       fu_funct3           ;  // Funct3 decoded from FU instr
logic [6:0]       fu_funct7           ;  // Funct7 decoded from FU instr

// Decoded flags --> Payload to EXU
logic [5:0]       instr_type          ;  // {R, I, S, B, U, J} type instruction flag (one-hot encoded)
logic [5:0]       instr_type_rg       ;  // Instruction type flag (registered)
logic             is_rsb              ;  // RSB flag
logic             is_rsb_rg           ;  // RSB flag (registered)
logic             is_risb             ;  // RISB flag (registered)
logic             is_risb_rg          ;  // RISB flag
logic             is_jal              ;  // JAL flag
logic             is_jalr             ;  // JALR flag
logic             is_jalr_rg          ;  // JALR flag (registered)
logic             is_j_or_jalr        ;  // J/JALR flag
logic             is_j_or_jalr_rg     ;  // J/JALR flag (registered)
logic             is_load             ;  // Load flag
logic             is_load_rg          ;  // Load flag (registered)
logic             is_alur             ;  // ALUR flag
logic             is_alui             ;  // ALUI flag 
logic             is_alui_rg          ;  // ALUI flag (registered)  //**CHECKME**// Used only when DBG is enabled...
logic             is_lui              ;  // LUI flag
logic             is_lui_rg           ;  // LUI flag (registered)
logic             is_auipc            ;  // AUIPC flag
logic             is_lui_or_auipc     ;  // LUI or AUIPC flag
logic             is_sli_sri          ;  // SLLI/SRLI/SRAI flag
logic             is_illegal          ;  // Illegal instruction flag
logic             is_alu_op           ;  // ALU operation flag
logic             is_alu_op_rg        ;  // ALU operation flag (registered)
logic [3:0]       alu_opcode          ;  // ALU opcode
logic [3:0]       alu_opcode_rg       ;  // ALU opcode (registered)

// Decoded from buffered flags/instruction --> Payload to EXU
logic             is_r_type           ;  // R-type instruction flag
logic             is_i_type           ;  // I-type instruction flag
logic             is_s_type           ;  // S-type instruction flag
logic             is_b_type           ;  // B-type instruction flag
logic             is_u_type           ;  // U-type instruction flag
logic             is_j_type           ;  // J-type instruction flag
logic [4:0]       reg_src0, reg_src1  ;  // Source register addresses
logic [4:0]       reg_dest            ;  // Destination register address
logic [6:0]       du_opcode           ;  // Opcode
logic [2:0]       funct3              ;  // Funct3
logic [6:0]       funct7              ;  // Funct7

// Buffered packets from FU
logic [`XLEN-1:0] du_pc_rg            ;  // PC
logic [`ILEN-1:0] du_instr_rg         ;  // Instruction
logic             du_bubble_rg        ;  // Bubble
logic             du_pkt_valid_rg     ;  // Packet valid
logic             du_br_taken_rg      ;  // Branch taken status

// Stall logic specific
logic             stall               ;  // Local stall generated by DU
logic             du_stall_ext        ;  // External stall generated by DU to upstream pipeline

// Flush logic specific
logic             flush               ;  // Flush from outside FU

//===================================================================================================================================================
// Logic to decode instruction flags
//===================================================================================================================================================
// Synchronous logic to register the flags
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      instr_type_rg   <= 6'b000000 ;   
      is_risb_rg      <= 1'b0 ; 
      is_rsb_rg       <= 1'b0 ;
      is_jalr_rg      <= 1'b0 ;
      is_j_or_jalr_rg <= 1'b0 ;
      is_load_rg      <= 1'b0 ;
      is_lui_rg       <= 1'b0 ;
      is_alui_rg      <= 1'b0 ;
   end
   // Out of reset
   else begin 
      // If not stalled
      if (!stall) begin
         // Flags
         instr_type_rg   <= instr_type   ;
         is_risb_rg      <= is_risb      ;
         is_rsb_rg       <= is_rsb       ;
         is_jalr_rg      <= is_jalr      ;
         is_j_or_jalr_rg <= is_j_or_jalr ;
         is_load_rg      <= is_load      ; 
         is_alui_rg      <= is_alui      ; 
         is_lui_rg       <= is_lui       ;
      end                   
   end
end

// Combi logic to decode the flags
always_comb begin
   case (fu_opcode)  
      OP_ALU    : begin 
                     instr_type = 6'b100000    ;  // R-type 
                     is_risb    = ~i_fu_bubble ;
                     is_rsb     = ~i_fu_bubble ; 
                  end
      //7'h73,  // ECALL/EBREAK/CSRR* 
      //7'h0F,  // FENCE
      OP_JALR,
      OP_LOAD,
      OP_ALUI   : begin 
                     instr_type = 6'b010000    ;  // I-type 
                     is_risb    = ~i_fu_bubble ; 
                     is_rsb     = 1'b0         ; 
                  end
      OP_STORE  : begin 
                     instr_type = 6'b001000    ;  // S-type
                     is_risb    = ~i_fu_bubble ; 
                     is_rsb     = ~i_fu_bubble ;
                  end
      OP_BRANCH : begin 
                     instr_type = 6'b000100    ;  // B-type 
                     is_risb    = ~i_fu_bubble ; 
                     is_rsb     = ~i_fu_bubble ; 
                  end
      OP_LUI,
      OP_AUIPC  : begin 
                     instr_type = 6'b000010    ;  // U-type 
                     is_risb    = 1'b0         ; 
                     is_rsb     = 1'b0         ; 
                  end
      OP_JAL    : begin 
                     instr_type = 6'b000001    ;  // J-type 
                     is_risb    = 1'b0         ; 
                     is_rsb     = 1'b0         ;
                  end
      default   : begin 
                     instr_type = 6'b000000    ;  // Illegal instruction!!
                     is_risb    = 1'b0         ; 
                     is_rsb     = 1'b0         ; 
                  end  
   endcase
end

assign is_jal          = (fu_opcode == OP_JAL)  ;
assign is_jalr         = (fu_opcode == OP_JALR) ;
assign is_j_or_jalr    = (is_jal || is_jalr)    ;
assign is_load         = (fu_opcode == OP_LOAD) ;
assign is_alur         = (fu_opcode == OP_ALU)  ;
assign is_alui         = (fu_opcode == OP_ALUI) ;
assign is_lui          = (fu_opcode == OP_LUI)  ;
assign is_auipc        = (fu_opcode == OP_AUIPC);
assign is_lui_or_auipc = (is_lui || is_auipc)   ;
assign is_sli_sri      = (fu_funct3 == F3_SLLX || fu_funct3 == F3_SRXX);
assign is_illegal      = ~|(instr_type);

//===================================================================================================================================================
// Synchronous logic to decode ALU operation
//===================================================================================================================================================
// Synchronous logic to register the ALU operation parameters
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      is_alu_op_rg  <= 1'b0 ;
      alu_opcode_rg <= '0   ;
   end
   // Out of reset
   else begin 
      // If not stalled
      if (!stall) begin
         is_alu_op_rg  <= is_alu_op  ;
         alu_opcode_rg <= alu_opcode ;
      end 

   end
end
assign is_alu_op  = (is_alur || is_alui || is_lui_or_auipc);

// ALU opcode decoder
always_comb begin
   case ({is_lui_or_auipc, (is_alui && !is_sli_sri)})
      2'b10   : alu_opcode = ALU_ADD ;                   // LUI/AUIPC requires ADD at ALU
      2'b01   : alu_opcode = {fu_funct3, 1'b0} ;         // LSb = 0 if ALUI-I but not SLLI/SRLI/SRAI 
      default : alu_opcode = {fu_funct3, fu_funct7[5]};  // This will cover ALU-R, and ALU-I instructions: SLLI/SRLI/SRAI
   endcase
end

//===================================================================================================================================================
// Synchronous logic to pipe PC
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin du_pc_rg <= PC_INIT ; end
   else if (!stall)   begin du_pc_rg <= i_fu_pc ; end  // Pipe forward...
end

//===================================================================================================================================================
// Synchronous logic to pipe instruction
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin du_instr_rg <= `INSTR_NOP ; end
   else if (!stall)   begin du_instr_rg <= i_fu_instr ; end  // Pipe forward...
end

//===================================================================================================================================================
// Synchronous logic to pipe bubble
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin du_bubble_rg <= 1'b1        ; end
   else if (flush)    begin du_bubble_rg <= 1'b1        ; end  // Invalidate on flush
   else if (!stall)   begin du_bubble_rg <= i_fu_bubble ; end  // Pipe forward...
end

//===================================================================================================================================================
// Synchronous logic to pipe packet valid
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin du_pkt_valid_rg <= 1'b0         ; end
   else if (flush)    begin du_pkt_valid_rg <= 1'b0         ; end  // Invalidate on flush
   else if (!stall)   begin du_pkt_valid_rg <= ~i_fu_bubble ; end  // Pipe forward valid...
end

//===================================================================================================================================================
// Synchronous logic to pipe branch taken status
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if      (!aresetn) begin du_br_taken_rg <= 1'b0          ; end
   else if (!stall)   begin du_br_taken_rg <= i_fu_br_taken ; end  // Pipe forward...
end

assign o_exu_bu_br_taken = du_br_taken_rg ;

//===================================================================================================================================================
// Synchronous logic to generate rs0/rs1 copies to relax fanout & timing at opfwd block
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   if (!aresetn) begin 
      o_exu_rs0_cpy_ff <= '0; 
      o_exu_rs1_cpy_ff <= '0;
   end 
   else if (!stall)   begin
      o_exu_rs0_cpy_ff <= i_fu_instr[19:15]; 
      o_exu_rs1_cpy_ff <= i_fu_instr[24:20]; 
   end
end

//===================================================================================================================================================
//  Stall logic
//===================================================================================================================================================
assign stall        = i_exu_stall & du_pkt_valid_rg ;  // Only EXU can stall DU from outside. 
                                                       // Conditioned with valid to burst unwanted pipeline bubbles.
assign du_stall_ext = stall        ;
assign o_fu_stall   = du_stall_ext ;  // Stall signal to FU

//===================================================================================================================================================
//  Flush logic
//===================================================================================================================================================
assign flush = i_exu_bu_flush ;  // Only EXU-BU can flush FU from outside

//===================================================================================================================================================
// ALl decoded signals
//===================================================================================================================================================
`ifdef DBG
// Debug Interface
assign o_du_dbg = {is_lui_rg, is_jalr_rg, is_load_rg, is_alui_rg, instr_type_rg} ;
`endif

// Instruction decoded
assign fu_opcode  = i_fu_instr[6:0]    ;
assign fu_funct3  = i_fu_instr[14:12]  ;
assign fu_funct7  = i_fu_instr[31:25]  ;
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

// Read-side control signals to Register File (RF)
assign o_rf_rden    = ~i_fu_bubble & ~stall ;  // DU and RF (read-side) are at the same stage of pipeline, so they should stall together always
assign rf_reg_src0  = i_fu_instr[19:15] ; 
assign rf_reg_src1  = i_fu_instr[24:20] ;
assign o_rf_rs0     = rf_reg_src0       ;  // Combi routing to sync the read-data from RF with DU payload to EXU 
assign o_rf_rs1     = rf_reg_src1       ;  // Combi routing to sync the read-data from RF with DU payload to EXU

// Payload to Execution Unit (EXU)
assign o_exu_pc           = du_pc_rg        ;
`ifdef DBG
assign o_exu_instr        = du_instr_rg     ;
`endif
assign o_exu_bubble       = du_bubble_rg    ;
assign o_exu_pkt_valid    = du_pkt_valid_rg ;
                                                                                                
assign o_exu_is_alu_op    = is_alu_op_rg  ;
assign o_exu_alu_opcode   = alu_opcode_rg ;
assign o_exu_rs0          = reg_src0      ;
assign o_exu_rs1          = reg_src1      ;
assign o_exu_rdt          = reg_dest      ;
assign o_exu_rdt_not_x0   = |reg_dest     ;
assign o_exu_funct3       = funct3        ;
  
assign o_exu_is_r_type    = is_r_type  ;
assign o_exu_is_i_type    = is_i_type  ;
assign o_exu_is_s_type    = is_s_type  ;
assign o_exu_is_b_type    = is_b_type  ;
assign o_exu_is_u_type    = is_u_type  ;
assign o_exu_is_rsb       = is_rsb_rg  ;
assign o_exu_is_risb      = is_risb_rg ; 
assign o_exu_is_riuj      = is_r_type | is_i_type | is_u_type | is_j_type ;  // R/I/U/J-type instruction?
assign o_exu_is_jalr      = is_jalr_rg ;
assign o_exu_is_j_or_jalr = is_j_or_jalr_rg ;
assign o_exu_is_load      = is_load_rg ;
assign o_exu_is_lui       = is_lui_rg  ;
assign o_exu_i_type_imm   = {du_instr_rg[31:20]}                                                       ;
assign o_exu_s_type_imm   = {du_instr_rg[31:25], du_instr_rg[11:7]}                                    ;
assign o_exu_b_type_imm   = {du_instr_rg[31], du_instr_rg[7], du_instr_rg[30:25], du_instr_rg[11:8]}   ;
assign o_exu_u_type_imm   = {du_instr_rg[31:12]}                                                       ;

endmodule
//###################################################################################################################################################
//                                                              D E C O D E   U N I T                                         
//###################################################################################################################################################