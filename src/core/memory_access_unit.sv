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
//----%%                    # Controls only Requests to memory, Acknowledgement is expected to be read by WriteBack Unit (WBU).
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
   input  logic             clk                ,  // Clock
   input  logic             aresetn            ,  // Asynchronous Reset; active-low

   // Interface with Execution Unit (EXU)
   `ifdef DBG
   input  logic [`XLEN-1:0] i_exu_pc           ,  // PC from EXU
   input  logic [`ILEN-1:0] i_exu_instr        ,  // Instruction from EXU
   `endif
   input  logic             i_exu_is_riuj      ,  // RIUJ flag from EXU
   input  logic [2:0]       i_exu_funct3       ,  // Funct3 from EXU
   input  logic             i_exu_bubble       ,  // Bubble from EXU
   output logic             o_exu_stall        ,  // Stall signal to EXU

   input  logic [4:0]       i_exu_rdt_addr     ,  // Writeback address from EXU
   input  logic [`XLEN-1:0] i_exu_rdt_data     ,  // Writeback data from EXU
   input  logic             i_exu_rdt_not_x0   ,  // rdt neq x0 
   input  logic             i_exu_is_macc_op   ,  // Memory access operation flag from EXU
   input  logic             i_exu_macc_cmd     ,  // Memory access command from EXU
   input  logic [`XLEN-1:0] i_exu_macc_addr    ,  // Memory access address from EXU
   input  logic [1:0]       i_exu_macc_size    ,  // Memory access size from EXU
   input  logic [`XLEN-1:0] i_exu_macc_data    ,  // Memory access data (for Store) from EXU

   // Data Memory/Cache Request Interface (DMEMIF)
   output logic             o_dmem_wen         ,  // Write enable to DMEMIF
   output logic [`XLEN-1:0] o_dmem_addr        ,  // Address to DMEMIF
   output logic [1:0]       o_dmem_size        ,  // Access size to DMEMIF
   output logic [`XLEN-1:0] o_dmem_wdata       ,  // Write-data to DMEMIF
   output logic             o_dmem_req         ,  // Request to DMEMIF
   input  logic             i_dmem_stall       ,  // Stall signal from DMEMIF
   output logic             o_dmem_flush       ,  // Flush signal to DMEMIF

   // Interface with WriteBack Unit (WBU)
   `ifdef DBG
   output logic [`XLEN-1:0] o_wbu_pc           ,  // PC to WBU
   output logic [`ILEN-1:0] o_wbu_instr        ,  // Instruction to WBU
   `endif
   output logic             o_wbu_is_riuj      ,  // RIUJ flag to WBU
   output logic [2:0]       o_wbu_funct3       ,  // Funct3 to WBU
   output logic             o_wbu_bubble       ,  // Bubble to WBU
   input  logic             i_wbu_stall        ,  // Stall signal from WBU   
   output logic [4:0]       o_wbu_rdt_addr     ,  // rdt address to WBU
   output logic [`XLEN-1:0] o_wbu_rdt_data     ,  // rdt data to WBU
   output logic             o_wbu_rdt_not_x0   ,  // rdt neq x0
   output logic             o_wbu_is_macc      ,  // Memory access flag to WBU
   output logic             o_wbu_is_load      ,  // Load operation flag to WBU
   output logic             o_wbu_is_dwback    ,  // Direct writeback operation flag to WBU
   output logic [`XLSB-1:0] o_wbu_macc_addr_lsb   // Memory access address to WBU (LSbs) 
);

//===================================================================================================================================================
// Localparams
//===================================================================================================================================================
localparam LOAD  = 1'b0 ;
localparam STORE = 1'b1 ;

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// EXU signals
logic             exu_bubble          ;  // Bubble from EXU conditioned with stall

// Packets buffered from EXU
`ifdef DBG
logic [`XLEN-1:0] maccu_pc_rg         ;  // PC 
logic [`ILEN-1:0] maccu_instr_rg      ;  // Instruction
`endif
logic [2:0]       maccu_funct3_rg     ;  // Funct3
logic             maccu_is_riuj_rg    ;  // RIUJ flag
logic             maccu_bubble_rg     ;  // Bubble
logic [4:0]       rdt_addr_rg         ;  // rdt address
logic [`XLEN-1:0] rdt_data_rg         ;  // rdt data
logic             rdt_not_x0_rg       ;  // rdt neq x0

// Other packets in the Payload to WBU
logic             is_macc             ;  // Memory access flag
logic             is_macc_rg          ;  // Memory access flag registered
logic             is_cmd_load         ;  // Memory access command from EXU is Load flag
logic             is_load             ;  // Load operation flag
logic             is_load_rg          ;  // Load operation flag registered
logic             is_store            ;  // Store operation flag
logic             is_dwback           ;  // Direct writeback operation flag i.e, result is ready from EXU
logic             is_dwback_rg        ;  // Direct writeback operation flag registered
logic [`XLSB-1:0] macc_addr_lsb_rg    ;  // Memory access address (LSbs)

// Stall logic specific
logic             stall           ;  // Local stall generated by MACCU
logic             maccu_stall_ext ;  // External stall generated by MACCU

//===================================================================================================================================================
// Synchronous logic to pipe MACCU packets
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      `ifdef DBG
      maccu_pc_rg         <= PC_INIT    ;
      maccu_instr_rg      <= `INSTR_NOP ;
      `endif
      maccu_is_riuj_rg    <= 1'b0       ;
      maccu_funct3_rg     <= 3'h0       ;
      maccu_bubble_rg     <= 1'b1       ;
      rdt_addr_rg         <= '0         ;  
      rdt_data_rg         <= '0         ;
      rdt_not_x0_rg       <= 1'b0       ;
      is_macc_rg          <= 1'b0       ;
      is_load_rg          <= 1'b0       ;
      is_dwback_rg        <= 1'b0       ;
      macc_addr_lsb_rg    <= '0         ;
   end
   // Out of reset
   else if (!stall) begin  // Pipe forward...
      `ifdef DBG
      maccu_pc_rg         <= i_exu_pc         ;
      maccu_instr_rg      <= i_exu_instr      ;
      `endif
      maccu_is_riuj_rg    <= i_exu_is_riuj & ~exu_bubble ;
      maccu_funct3_rg     <= i_exu_funct3     ;
      maccu_bubble_rg     <= exu_bubble       ;
      rdt_addr_rg         <= i_exu_rdt_addr   ;  
      rdt_data_rg         <= i_exu_rdt_data   ;
      rdt_not_x0_rg       <= i_exu_rdt_not_x0 ;
      is_macc_rg          <= is_macc          ;  
      is_load_rg          <= is_load          ;
      is_dwback_rg        <= is_dwback        ;
      macc_addr_lsb_rg    <= i_exu_macc_addr[`XLSB-1:0];
   end
end

assign exu_bubble  =  i_exu_bubble | i_wbu_stall ;    // WBU stall should invalidate EXU instr to disable new memory access requests @MACCU
                                                      // This is a strict in-order requirement
assign is_macc     =  i_exu_is_macc_op & ~exu_bubble ;
assign is_cmd_load =  (i_exu_macc_cmd == LOAD);
assign is_load     =  is_macc &&  is_cmd_load ;
assign is_store    =  is_macc && !is_cmd_load ;
assign is_dwback   = ~i_exu_is_macc_op & ~exu_bubble ;

//===================================================================================================================================================
//  Stall logic
//===================================================================================================================================================
assign stall           = (i_wbu_stall | i_dmem_stall) & ~maccu_bubble_rg ;  // WBU, DMEMIF can stall MACCU from outside
                                                                            // Conditioned with valid to burst unwanted pipeline bubbles.
assign maccu_stall_ext = stall           ;  
assign o_exu_stall     = maccu_stall_ext ;  // Stall signal to EXU

//===================================================================================================================================================
// DMEMIF and WBU outputs
//===================================================================================================================================================
// Control signals to Data Memory/Cache Request Interface
// All control signals are combi routed to memory w/o registering @MACCU so that memory pipeline is sync with MACCU pipeline to pipe MACCU packets
// This will ensure no extra latency if memory/cache supports max. access speed of = 1 cycle on hit
// If the memory/cache access >1 cycle, then WBU may assert stall in the next cycle
assign o_dmem_wen   = is_store ;
assign o_dmem_addr  = i_exu_macc_addr ;
assign o_dmem_size  = i_exu_macc_size ;
assign o_dmem_wdata = i_exu_macc_data ;
assign o_dmem_req   = is_macc ;
assign o_dmem_flush = 1'b0 ;  //**CHECKME**// Flush is unused as of now

// Payload to WriteBack Unit (WBU)
`ifdef DBG
assign o_wbu_pc            = maccu_pc_rg         ;
assign o_wbu_instr         = maccu_instr_rg      ;
`endif
assign o_wbu_is_riuj       = maccu_is_riuj_rg    ;
assign o_wbu_funct3        = maccu_funct3_rg     ;
assign o_wbu_bubble        = maccu_bubble_rg     ;
assign o_wbu_rdt_addr      = rdt_addr_rg         ;
assign o_wbu_rdt_data      = rdt_data_rg         ;
assign o_wbu_rdt_not_x0    = rdt_not_x0_rg       ;
assign o_wbu_is_macc       = is_macc_rg          ;
assign o_wbu_is_load       = is_load_rg          ;
assign o_wbu_is_dwback     = is_dwback_rg        ;
assign o_wbu_macc_addr_lsb = macc_addr_lsb_rg    ;

endmodule
//###################################################################################################################################################
//                                                         M E M O R Y   A C C E S S   U N I T                                         
//###################################################################################################################################################