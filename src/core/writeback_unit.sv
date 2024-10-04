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
//----%% File Name        : writeback_unit.sv
//----%% Module Name      : WriteBack Unit                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : WriteBack Unit (WBU) of pqr5 core.
//----%%                    # Writes back results from execution pipeline to Register File. Commits all results in-order.
//----%%                    # Acknowledgement to memory access is done by WBU. 
//----%%                    # Single cycle latency pipeline.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : June-2024
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         W R I T E B A C K   U N I T                                         
//###################################################################################################################################################
// Header files
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module writeback_unit #(
   // Configurable parameters
   parameter PC_INIT = `PC_INIT  // Init PC on reset
)
(
   // Clock and Reset
   input  logic             clk                ,  // Clock
   input  logic             aresetn            ,  // Asynchronous Reset; active-low   
   
   `ifdef DBG
   // Debug Interface  	
   output logic [3:0]       o_wbu_dbg          ,  // Debug signal
   `endif

   // Data Memory/Cache Acknowledge Interface (DMEMIF) 
   input  logic [`XLEN-1:0] i_dmem_rdata       ,  // Read-data from DMEMIF
   input  logic             i_dmem_ack         ,  // Acknowledge from DMEMIF
   output logic             o_dmem_stall       ,  // Stall signal to DMEMIF

   // Operand Forward Interface
   output logic [`XLEN-1:0] o_load_data        ,  // Load data from DMEM access 

   // Interface with Memory Access Unit (MACCU)
   input  logic [`XLEN-1:0] i_maccu_pc         ,  // PC from MACCU
   input  logic [`ILEN-1:0] i_maccu_instr      ,  // Instruction from MACCU
   input  logic [5:0]       i_maccu_instr_type ,  // Instruction type from MACCU
   input  logic             i_maccu_bubble     ,  // Bubble from MACCU
   output logic             o_maccu_stall      ,  // Stall signal to MACCU   
   input  logic [4:0]       i_maccu_rdt_addr   ,  // rdt address from MACCU
   input  logic [`XLEN-1:0] i_maccu_rdt_data   ,  // rdt data from MACCU
   input  logic             i_maccu_is_macc    ,  // Memory access flag from MACCU
   input  logic [`XLEN-1:0] i_maccu_macc_addr  ,  // Memory access address from MACCU //**CHECKME**// only LSbs used as of now
   input  logic             i_maccu_macc_type  ,  // Memory access type from MACCU; '0'- Load, '1'- Store

   // Interface with Register File (RF)
   output logic             o_rf_wren          ,  // Write Enable to RF
   output logic [4:0]       o_rf_rdt_addr      ,  // rdt address to RF
   output logic [`XLEN-1:0] o_rf_rdt_data      ,  // rdt data to RF

   // Instruction Interface
   output logic [`XLEN-1:0] o_pc               ,  // PC from WBU
   output logic [`ILEN-1:0] o_instr            ,  // Instruction from WBU
   output logic [5:0]       o_instr_type       ,  // Instruction type from WBU
   output logic [4:0]       o_rdt_addr         ,  // rdt address from WBU
   output logic [`XLEN-1:0] o_rdt_data         ,  // rdt data from WBU
   output logic             o_bubble           ,  // Bubble from WBU
   input  logic             i_stall               // Stall to WBU //**CHECKME**// Currently no external source to stall WBU 
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// Instruction specific
logic [`XLEN-1:0] wbu_pc_rg         ;  // PC
logic [`ILEN-1:0] wbu_instr_rg      ;  // Instruction
logic [5:0]       wbu_instr_type_rg ;  // Instruction type
logic             wbu_bubble_rg     ;  // Bubble
logic [2:0]       funct3            ;  // funct3 

// Memory access/writeback specific
logic             is_dmem_acc      ;  // Flags if memory access required
logic             is_dmem_acc_load ;  // Flags if Load operation
logic             is_dir_writeback ;  // Flags if direct writeback operation w/o any memory access
logic             is_usig_macc     ;  // Flags if unsigned memory access
logic [`XLEN-1:0] maddr            ;  // Memory access address
logic [1:0]       msize            ;  // Memory access size
logic [7:0]       load_byte        ;  // Load byte
logic [15:0]      load_hword       ;  // Load half-word
logic [31:0]      load_word        ;  // Load word
logic [`XLEN-1:0] load_data        ;  // Load data 

// RF control specific
logic             rdt_wren         ;  // Write Enable to RF
logic [4:0]       rdt_addr         ;  // Writeback address
logic [`XLEN-1:0] rdt_data         ;  // Writeback data

// Writeback copy buffers
logic             rdt_wren_rg      ;  // Write Enable copy buffer
logic [4:0]       rdt_addr_rg      ;  // Writeback address copy buffer
logic [`XLEN-1:0] rdt_data_rg      ;  // Writeback data copy buffer

// Stall logic specific
logic             stall            ;  // Stall from outside WBU
logic             dmem_stall       ;  // Stall generated by WBU to DMEMIF
logic             dmem_acc_stall   ;  // Stall locally generated on memory access
logic             pipe_stall       ;  // Stall locally generated to stall WBU pipeline
logic             wbu_stall        ;  // Stall generated by WBU to MACCU

//===================================================================================================================================================
// Synchronous logic to pipe instruction, PC, bubble
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      wbu_pc_rg         <= PC_INIT    ;
      wbu_instr_rg      <= `INSTR_NOP ;
      wbu_instr_type_rg <= '0         ;
      wbu_bubble_rg     <= 1'b1       ;      
   end
   // Out of reset
   else if (!pipe_stall) begin
      wbu_pc_rg         <= i_maccu_pc         ;
      wbu_instr_rg      <= i_maccu_instr      ;
      wbu_instr_type_rg <= i_maccu_instr_type ;
      wbu_bubble_rg     <= i_maccu_bubble     ;      
   end
end

//===================================================================================================================================================
// Synchronous logic to decode MACCU packet and perform writeback
//===================================================================================================================================================
// Writeback to copy buffers
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      rdt_wren_rg <= 1'b0 ;
      rdt_addr_rg <= '0   ;
      rdt_data_rg <= '0   ;      
   end
   // Out of reset
   else if (!pipe_stall) begin
      // Memory access, Load operation
      if (is_dmem_acc && is_dmem_acc_load) begin
         rdt_wren_rg <= 1'b1             ;      	
         rdt_data_rg <= load_data        ;  // Writeback Load data after memory access
         rdt_addr_rg <= i_maccu_rdt_addr ;
      end
      // Not memory access, direct writeback
      else if (is_dir_writeback) begin
         rdt_wren_rg <= 1'b1             ;      	
         rdt_data_rg <= i_maccu_rdt_data ;  // Writeback data from MACCU
         rdt_addr_rg <= i_maccu_rdt_addr ;         	
      end 
      // Invalid packet
      else begin
         rdt_wren_rg <= 1'b0 ;
         rdt_addr_rg <= '0   ;
         rdt_data_rg <= '0   ;    	
      end           
   end
end

// Writeback to RF: combi routing to sync RF write with WBU outputs
always_comb begin
   rdt_wren = 1'b0 ;
   rdt_addr = '0   ;
   rdt_data = '0   ;
   if (!pipe_stall) begin
      // Memory access, Load operation
      if (is_dmem_acc && is_dmem_acc_load) begin
         rdt_wren = 1'b1             ;      	
         rdt_data = load_data        ;  // Writeback Load data after memory access
         rdt_addr = i_maccu_rdt_addr ;
      end
      // Not memory access, direct writeback
      else if (is_dir_writeback) begin
         rdt_wren = 1'b1             ;      	
         rdt_data = i_maccu_rdt_data ;  // Writeback data from MACCU
         rdt_addr = i_maccu_rdt_addr ;         	
      end   	
   end  
end

//===================================================================================================================================================
//  Combinatorial logic to form Load data from read-data from DMEMIF
//===================================================================================================================================================
always_comb begin
   case ({is_usig_macc, msize})
      {1'b0,  BYTE} : load_data = {{(`XLEN-8) {load_byte  [7]}}, load_byte } ;  // Signed Load Byte
      {1'b0, HWORD} : load_data = {{(`XLEN-16){load_hword[15]}}, load_hword} ;  // Signed Load Half-word
      {1'b0,  WORD} : load_data = {                              load_word } ;  // Signed Load Word
      {1'b1,  BYTE} : load_data = {{(`XLEN-8) {          1'b0}}, load_byte } ;  // Unsigned Load Byte
      {1'b1, HWORD} : load_data = {{(`XLEN-16){          1'b0}}, load_hword} ;  // Unsigned Load Half-word
      default       : load_data = {                              load_word } ;  // Signed Load Word
   endcase      
end

assign funct3       = i_maccu_instr[14:12] ;
assign is_usig_macc = funct3[2]            ;
assign maddr        = i_maccu_macc_addr    ;
assign msize        = funct3[1:0]          ;

assign load_byte    = i_dmem_rdata >> (8 * maddr[`XLSB]) ;
assign load_hword   = i_dmem_rdata >> (8 * maddr[`XLSB]) ;
assign load_word    = i_dmem_rdata ;

assign o_load_data  = load_data ;

//===================================================================================================================================================
//  Stall logic
//===================================================================================================================================================
assign stall          = i_stall                                    ;  // External stall 
assign dmem_stall     = stall                                      ;  // Only external stall can stall memory pipeline
assign dmem_acc_stall = is_dmem_acc & ~i_dmem_ack                  ;  // Stall until onging memory access is acknowledged
assign pipe_stall     = stall | dmem_acc_stall                     ;  // External or memory access stall should stall WBU pipeline 
assign wbu_stall      = (stall & ~i_maccu_bubble) | dmem_acc_stall ;  // If invalid instruction from MACCU, stall need not be generated to MACCU
assign o_dmem_stall   = dmem_stall                                 ;  // Stall signal to DMEMIF
assign o_maccu_stall  = wbu_stall                                  ;  // Stall signal to MACCU

//===================================================================================================================================================
// All continuous assignments
//===================================================================================================================================================
`ifdef DBG
// Debug Interface
assign o_wbu_dbg = {is_usig_macc, msize, is_dmem_acc_load, pipe_stall, dmem_acc_stall} ;
`endif

assign is_dmem_acc      = ~i_maccu_bubble &  i_maccu_is_macc  ;  // Valid Load/Store?
assign is_dmem_acc_load = ~i_maccu_macc_type                  ;
assign is_dir_writeback = ~i_maccu_bubble & ~i_maccu_is_macc  ;  // Valid but not Load/Store

// Interface with Register File (RF)
assign o_rf_wren     = rdt_wren ;
assign o_rf_rdt_addr = rdt_addr ;
assign o_rf_rdt_data = rdt_data ;

// Instruction Interface
assign o_pc          = wbu_pc_rg         ;
assign o_instr       = wbu_instr_rg      ;
assign o_instr_type  = wbu_instr_type_rg ;
assign o_rdt_addr    = rdt_addr_rg       ;
assign o_rdt_data    = rdt_data_rg       ;
assign o_bubble      = wbu_bubble_rg     ;

endmodule
//###################################################################################################################################################
//                                                         W R I T E B A C K   U N I T                                         
//###################################################################################################################################################