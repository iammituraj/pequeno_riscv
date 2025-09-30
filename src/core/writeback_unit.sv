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
//----%%                    # The memory access response is read by WBU to perfrom write back of load operations.
//----%%                    # Pipeline stall is applied until the response of the memory access is ready (ie., ack is ready). 
//----%%                    # Pipeline latency = 1 cycle
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Sept-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
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
   input  logic             clk                   ,  // Clock
   input  logic             aresetn               ,  // Asynchronous Reset; active-low   
   
   `ifdef DBG
   // Debug Interface  	
   output logic [4:0]       o_wbu_dbg             ,  // Debug signal
   `endif

   // Data Memory/Cache Acknowledge Interface (DMEMIF) 
   input  logic [`XLEN-1:0] i_dmem_rdata          ,  // Read-data from DMEMIF
   input  logic             i_dmem_ack            ,  // Acknowledge from DMEMIF
   output logic             o_dmem_stall          ,  // Stall signal to DMEMIF

   // Operand Forward Interface
   output logic [`XLEN-1:0] o_load_data           ,  // Load data from DMEM access 

   // Interface with Memory Access Unit (MACCU)
   `ifdef DBG
   input  logic [`XLEN-1:0] i_maccu_pc            ,  // PC from MACCU
   input  logic [`ILEN-1:0] i_maccu_instr         ,  // Instruction from MACCU
   `endif
   input  logic             i_maccu_is_riuj       ,  // RIUJ flag from MACCU
   input  logic [2:0]       i_maccu_funct3        ,  // Funct3 from MACCU
   input  logic             i_maccu_bubble        ,  // Bubble from MACCU
   output logic             o_maccu_stall         ,  // Stall signal to MACCU   
   input  logic [4:0]       i_maccu_rdt_addr      ,  // rdt address from MACCU
   input  logic [`XLEN-1:0] i_maccu_rdt_data      ,  // rdt data from MACCU
   input  logic             i_maccu_rdt_not_x0    ,  // rdt neq x0
   input  logic             i_maccu_is_macc       ,  // Memory access flag from MACCU
   input  logic             i_maccu_is_load       ,  // Load operation flag from MACCU
   input  logic             i_maccu_is_dwback     ,  // Direct writeback operation flag from MACCU
   input  logic [`XLSB-1:0] i_maccu_macc_addr_lsb ,  // Memory access address from MACCU (LSbs)

   // Interface with Register File (RF)
   output logic             o_rf_wren             ,  // Write Enable to RF
   output logic [4:0]       o_rf_rdt_addr         ,  // rdt address to RF
   output logic [`XLEN-1:0] o_rf_rdt_data         ,  // rdt data to RF

   // Instruction Interface
   `ifdef DBG
   output logic [`XLEN-1:0] o_pc                  ,  // PC from WBU
   output logic [`ILEN-1:0] o_instr               ,  // Instruction from WBU
   `else
   `ifdef SIMEXIT_INSTR_END
   output logic [`ILEN-1:0] o_instr               ,  // Instruction from WBU
   `endif
   `endif
   output logic             o_is_riuj             ,  // RIUJ flag from WBU
   output logic             o_rdt_wren            ,  // rdt write enable from WBU
   output logic [4:0]       o_rdt_addr            ,  // rdt address from WBU
   output logic [`XLEN-1:0] o_rdt_data            ,  // rdt data from WBU
   output logic             o_rdt_not_x0          ,  // rdt neq x0
   output logic             o_pkt_valid           ,  // Packet valid from WBU
   input  logic             i_stall                  // Stall to WBU
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// Instruction specific
`ifdef DBG
logic [`XLEN-1:0] wbu_pc_rg         ;  // PC
logic [`ILEN-1:0] wbu_instr_rg      ;  // Instruction
`else
`ifdef SIMEXIT_INSTR_END
logic [`ILEN-1:0] wbu_instr_rg      ;  // Instruction
`endif
`endif
logic             wbu_is_riuj_rg    ;  // RIUJ flag
logic             wbu_pkt_valid_rg  ;  // Packet valid

// Memory access/writeback specific
logic             is_dmem_acc      ;  // Flags if memory access required
logic             is_dmem_acc_load ;  // Flags if Load operation
logic             is_dir_writeback ;  // Flags if direct writeback operation w/o any memory access
logic             is_usig_macc     ;  // Flags if unsigned memory access
logic [`XLSB-1:0] maddr_lsb        ;  // Memory access address (LSbs)
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
logic             rdt_wren_rg      ;  // Write Enable copy buffer //**CHECKME**// Debug purpose only...
logic [4:0]       rdt_addr_rg      ;  // Writeback address copy buffer
logic [`XLEN-1:0] rdt_data_rg      ;  // Writeback data copy buffer
logic             rdt_not_x0_rg    ;  // rdt neq x0

// Stall logic specific
logic             ext_stall        ;  // External stall coming to WBU
logic             dmem_stall_ext   ;  // External stall generated by WBU to DMEMIF
logic             dmem_acc_stall   ;  // Stall locally generated on memory access
logic             pipe_stall       ;  // Stall locally generated to stall WBU pipeline
logic             wbu_stall_ext    ;  // External stall generated by WBU to MACCU

//===================================================================================================================================================
// Synchronous logic to pipe instruction, PC, bubble/packet valid
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      `ifdef DBG
      wbu_pc_rg        <= PC_INIT    ;
      wbu_instr_rg     <= `INSTR_NOP ;
      `endif
      wbu_is_riuj_rg   <= 1'b0       ;
      wbu_pkt_valid_rg <= 1'b0       ;      
   end
   // Out of reset
   else if (!pipe_stall) begin
      `ifdef DBG
      wbu_pc_rg        <= i_maccu_pc        ;
      wbu_instr_rg     <= i_maccu_instr     ;
      `endif
      wbu_is_riuj_rg   <= i_maccu_is_riuj & ~i_maccu_bubble ;
      wbu_pkt_valid_rg <= ~i_maccu_bubble ;      
   end
end

//===================================================================================================================================================
// Synchronous logic to decode MACCU packet and perform writeback
//===================================================================================================================================================
// Writeback to copy buffers
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      rdt_wren_rg   <= 1'b0 ;
      rdt_addr_rg   <= '0   ;
      rdt_data_rg   <= '0   ; 
      rdt_not_x0_rg <= 1'b0 ;     
   end
   // Out of reset
   else if (!pipe_stall) begin
      rdt_wren_rg   <= rdt_wren ;      	
      rdt_data_rg   <= rdt_data ;
      rdt_addr_rg   <= rdt_addr ;
      rdt_not_x0_rg <= i_maccu_rdt_not_x0 ;       
   end
end

// Writeback to RF: combi routing to sync RF write with WBU pipe outputs
assign rdt_wren = pipe_stall ? 1'b0 : ((is_dmem_acc_load | is_dir_writeback) && i_maccu_rdt_not_x0);
assign rdt_addr = i_maccu_rdt_addr ;
assign rdt_data = is_dmem_acc_load ? load_data : i_maccu_rdt_data ;  // Writeback data selected from memory (Load data) or MACCU (Direct writeback)

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

assign is_usig_macc = i_maccu_funct3[2]     ;
assign maddr_lsb    = i_maccu_macc_addr_lsb ;
assign msize        = i_maccu_funct3[1:0]   ;

always_comb begin
   case (maddr_lsb)   
      2'b00   : load_hword = i_dmem_rdata[15:0] ;
      2'b01   : load_hword = i_dmem_rdata[23:8] ;
      2'b10   : load_hword = i_dmem_rdata[31:16];
      default : load_hword = {8'h00, i_dmem_rdata[31:24]};        
   endcase
end
assign load_byte    = load_hword[7:0];
assign load_word    = i_dmem_rdata ;

// Load data out
assign o_load_data  = load_data ;

//===================================================================================================================================================
//  Stall logic
//===================================================================================================================================================
assign ext_stall      = i_stall                    ;  // External stall from outside CPU
assign dmem_stall_ext = ext_stall                  ;  // Only external stall can stall memory pipeline
assign dmem_acc_stall = is_dmem_acc & ~i_dmem_ack  ;  // Stall until onging memory access is acknowledged
assign pipe_stall     = ext_stall | dmem_acc_stall ;  // External or memory access stall should stall WBU pipeline 
assign wbu_stall_ext  = pipe_stall                 ;  // If WBU is stalled --> MACCU stall
assign o_dmem_stall   = dmem_stall_ext             ;  // Stall signal to DMEMIF
assign o_maccu_stall  = wbu_stall_ext              ;  // Stall signal to MACCU

//===================================================================================================================================================
// Internally decoded signals and outputs from WBU
//===================================================================================================================================================
`ifdef DBG
// Debug Interface
assign o_wbu_dbg = {is_usig_macc, msize, is_dmem_acc_load, is_dir_writeback, pipe_stall, dmem_acc_stall} ;
`endif

assign is_dmem_acc      = i_maccu_is_macc   ;  // Load/Store?
assign is_dmem_acc_load = i_maccu_is_load   ;  // Load?
assign is_dir_writeback = i_maccu_is_dwback ;  // Direct writeback, not Load/Store?

// Write-side control signals to Register File (RF)
assign o_rf_wren     = rdt_wren ;
assign o_rf_rdt_addr = rdt_addr ;
assign o_rf_rdt_data = rdt_data ;

// Payload out of WBU
`ifdef DBG
assign o_pc          = wbu_pc_rg        ;  
assign o_instr       = wbu_instr_rg     ;
`else
`ifdef SIMEXIT_INSTR_END
assign o_instr       = wbu_instr_rg     ;
`endif
`endif
assign o_is_riuj     = wbu_is_riuj_rg   ;
assign o_rdt_wren    = rdt_wren_rg      ;
assign o_rdt_addr    = rdt_addr_rg      ;
assign o_rdt_data    = rdt_data_rg      ;
assign o_rdt_not_x0  = rdt_not_x0_rg    ;
assign o_pkt_valid   = wbu_pkt_valid_rg ;

endmodule
//###################################################################################################################################################
//                                                         W R I T E B A C K   U N I T                                         
//###################################################################################################################################################