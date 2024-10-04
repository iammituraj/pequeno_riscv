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
//----%% File Name        : memory_access_unit.sv
//----%% Module Name      : Memory Access Unit (MACCU)                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Memory Access Unit (MACCU) of PQR5 Core.
//----%%                    # Forwards memory access requests from EXU to Data memory.
//----%%                    # Controls only Requests to memory, Acknowledgement is expected to be done by WriteBack Unit (WBU).
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
//                                                         M E M O R Y   A C C E S S   U N I T                                         
//###################################################################################################################################################
// Header files
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module memory_access_unit #(
   // Configurable parameters
   parameter PC_INIT = `PC_INIT  // Init PC on reset
)
( 
   // Clock and Reset
   input  logic             clk              ,  // Clock
   input  logic             aresetn          ,  // Asynchronous Reset; active-low

   // Interface with Execution Unit (EXU)
   input  logic [`XLEN-1:0] i_exu_pc         ,  // PC from EXU
   input  logic [`ILEN-1:0] i_exu_instr      ,  // Instruction from EXU
   input  logic [5:0]       i_exu_instr_type ,  // Intruction type from EXU
   input  logic             i_exu_bubble     ,  // Bubble from EXU
   output logic             o_exu_stall      ,  // Stall signal to EXU

   input  logic [4:0]       i_exu_rdt_addr   ,  // Writeback address from EXU
   input  logic [`XLEN-1:0] i_exu_rdt_data   ,  // Writeback data from EXU
   input  logic             i_exu_is_macc_op ,  // Memory access operation flag from EXU
   input  logic             i_exu_macc_cmd   ,  // Memory access command from EXU
   input  logic [`XLEN-1:0] i_exu_macc_addr  ,  // Memory access address from EXU
   input  logic [1:0]       i_exu_macc_size  ,  // Memory access size from EXU
   input  logic [`XLEN-1:0] i_exu_macc_data  ,  // Memory access data (for Store) from EXU

   // Data Memory/Cache Request Interface (DMEMIF)
   output logic             o_dmem_wen       ,  // Write enable to DMEMIF
   output logic [`XLEN-1:0] o_dmem_addr      ,  // Address to DMEMIF
   output logic [1:0]       o_dmem_size      ,  // Access size to DMEMIF
   output logic [`XLEN-1:0] o_dmem_wdata     ,  // Write-data to DMEMIF
   output logic             o_dmem_req       ,  // Request to DMEMIF
   input  logic             i_dmem_stall     ,  // Stall signal from DMEMIF
   output logic             o_dmem_flush     ,  // Flush signal to DMEMIF

   // Interface with WriteBack Unit (WBU)
   output logic [`XLEN-1:0] o_wbu_pc         ,  // PC to WBU
   output logic [`ILEN-1:0] o_wbu_instr      ,  // Instruction to WBU
   output logic [5:0]       o_wbu_instr_type ,  // Instruction type to WBU
   output logic             o_wbu_bubble     ,  // Bubble to WBU
   input  logic             i_wbu_stall      ,  // Stall signal from WBU   
   output logic [4:0]       o_wbu_rdt_addr   ,  // rdt address to WBU
   output logic [`XLEN-1:0] o_wbu_rdt_data   ,  // rdt data to WBU
   output logic             o_wbu_is_macc    ,  // Memory access flag to WBU
   output logic [`XLEN-1:0] o_wbu_macc_addr  ,  // Memory access address to WBU     
   output logic             o_wbu_macc_type     // Memory access type to WBU; '0'- Load, '1'- Store
);

//===================================================================================================================================================
// Localparams
//===================================================================================================================================================
localparam LOAD  = 1'b0 ;
localparam STORE = 1'b1 ;

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// MACCU packets
logic [`XLEN-1:0] maccu_pc_rg         ;  // PC 
logic [`ILEN-1:0] maccu_instr_rg      ;  // Instruction
logic [5:0]       maccu_instr_type_rg ;  // Instruction type
logic             maccu_bubble_rg     ;  // Bubble
logic [4:0]       rdt_addr_rg         ;  // rdt address
logic [`XLEN-1:0] rdt_data_rg         ;  // rdt data
logic             is_macc_rg          ;  // Memory access flag
logic [`XLEN-1:0] macc_addr_rg        ;  // Memory access address 
logic             macc_type_rg        ;  // Memory access type

// Stall logic specific
logic             stall       ;  // Stall from outside MACCU
logic             maccu_stall ;  // Stall generated by MACCU to EXU

//===================================================================================================================================================
// Synchronous logic to pipe MACCU packets
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      maccu_pc_rg         <= PC_INIT    ;
      maccu_instr_rg      <= `INSTR_NOP ;
      maccu_instr_type_rg <= '0         ;
      maccu_bubble_rg     <= 1'b1       ;
      rdt_addr_rg         <= '0         ;  
      rdt_data_rg         <= '0         ;
      is_macc_rg          <= 1'b0       ;
      macc_addr_rg        <= '0         ;
      macc_type_rg        <= LOAD       ;
   end
   // Out of reset
   else if (!stall) begin
      maccu_pc_rg         <= i_exu_pc         ;
      maccu_instr_rg      <= i_exu_instr      ;
      maccu_instr_type_rg <= i_exu_instr_type ;
      maccu_bubble_rg     <= i_exu_bubble     ;
      rdt_addr_rg         <= i_exu_rdt_addr   ;  
      rdt_data_rg         <= i_exu_rdt_data   ;
      is_macc_rg          <= i_exu_is_macc_op ;
      macc_addr_rg        <= i_exu_macc_addr  ;
      macc_type_rg        <= i_exu_macc_cmd   ;      
   end
end

//===================================================================================================================================================
//  Stall logic
//===================================================================================================================================================
assign stall       = i_wbu_stall | i_dmem_stall ;  // WBU, DMEMIF can stall MACCU from outside
assign maccu_stall = stall                      ;  // No other locally generated conditions 
assign o_exu_stall = maccu_stall                ;  // Stall signal to EXU

//===================================================================================================================================================
// Continuous assignments 
//===================================================================================================================================================
// Data Memory/Cache Request Interface (DMEMIF)
// All control signals are combi routed to memory w/o registering @MACCU so that memory pipeline is sync with MACCU pipeline to pipe MACCU packets
// This will ensure no extra latency if memory/cache supports max. access speed of = 1 cycle on hit
assign o_dmem_wen   = (!i_exu_bubble && i_exu_is_macc_op && (i_exu_macc_cmd == STORE)) ;
assign o_dmem_addr  = i_exu_macc_addr ;
assign o_dmem_size  = i_exu_macc_size ;
assign o_dmem_wdata = i_exu_macc_data ;
assign o_dmem_req   = (!i_exu_bubble && i_exu_is_macc_op) ;
assign o_dmem_flush = 1'b0 ;  //**CHECKME**// Flush is unused as of now

// Interface with WriteBack Unit (WBU)
assign o_wbu_pc         = maccu_pc_rg         ;
assign o_wbu_instr      = maccu_instr_rg      ;
assign o_wbu_instr_type = maccu_instr_type_rg ;
assign o_wbu_bubble     = maccu_bubble_rg     ;
assign o_wbu_rdt_addr   = rdt_addr_rg         ;
assign o_wbu_rdt_data   = rdt_data_rg         ;
assign o_wbu_is_macc    = is_macc_rg          ;
assign o_wbu_macc_addr  = macc_addr_rg        ;
assign o_wbu_macc_type  = macc_type_rg        ;

endmodule
//###################################################################################################################################################
//                                                         M E M O R Y   A C C E S S   U N I T                                         
//###################################################################################################################################################