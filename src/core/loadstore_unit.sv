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
//----%% File Name        : loadstore_unit.sv
//----%% Module Name      : Load-Store Unit (LSU)                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This is the Load-Store unit used by Execution Unit (EXU) of PQR5 Core. Decodes all Load/Store instructions and 
//----%%                    generates memory access commands.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Apr-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         L O A D - S T O R E   U N I T                                         
//###################################################################################################################################################
// Header files
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module loadstore_unit (
   // Clock and Reset
   input  logic             clk         ,  // Clock
   input  logic             aresetn     ,  // Asynchronous Reset; active-low
   
   // Control signals
   input  logic             i_stall     ,  // Stall signal    
   input  logic             i_bubble    ,  // Bubble in 
   input  logic             i_is_s_type ,  // S-type instruction flag 
   input  logic             i_is_load   ,  // Load flag
   input  logic [2:0]       i_funct3    ,  // funct3
   input  logic [11:0]      i_immI      ,  // I-type immediate
   input  logic [11:0]      i_immS      ,  // S-type immediate
   input  logic [`XLEN-1:0] i_op0       ,  // Operand-0 from register file
   input  logic [`XLEN-1:0] i_op1       ,  // Operand-1 from register file

   // Memory Access Interface    
   output logic             o_mem_cmd   ,  // Command; '0'- Load, '1'- Store
   output logic [`XLEN-1:0] o_mem_addr  ,  // Address
   output logic [1:0]       o_mem_size  ,  // Size; BYTE/HWORD/WORD
   output logic [`XLEN-1:0] o_mem_data  ,  // Data (for Store)
   output logic             o_bubble       // Bubble out
);

//===================================================================================================================================================
// Localparams
//===================================================================================================================================================
localparam LOAD  = 1'b0 ;
localparam STORE = 1'b1 ;

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic             mem_cmd_rg              ;  // Memory command
logic [`XLEN-1:0] mem_addr_rg             ;  // Memory address
logic [1:0]       mem_size_rg             ;  // Memory access size
logic [`XLEN-1:0] mem_data_rg             ;  // Memory data
logic             bubble, bubble_rg       ;  // Bubble
logic [`XLEN-1:0] immI, immS              ;  // I/S-type immediates sign-extended
logic [`XLEN-1:0] load_addr, store_addr   ;  // Load/Store addresses
logic [`XLEN-1:0] store_data              ;  // Store data
logic [1:0]       memacc_size             ;  // Memory access size
logic             is_op_load, is_op_store ;  // Load/Store instruction flags

//===================================================================================================================================================
// Synchronous logic to control memory access
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      mem_cmd_rg  <= LOAD  ; 
      mem_addr_rg <= '0    ;
      mem_size_rg <= BYTE  ;
      mem_data_rg <= '0    ;
      bubble_rg   <= 1'b1  ;            
   end
   // Out of reset
   else if (!i_stall) begin 
      mem_cmd_rg  <= is_op_store ;      
      mem_addr_rg <= is_op_store ? store_addr : load_addr ;  
      mem_size_rg <= memacc_size ;
      mem_data_rg <= is_op_store ? store_data : '0 ;
      bubble_rg   <= bubble ;          
   end
end

//===================================================================================================================================================
//  Combinatorial logic to form Store data to DMEMIF
//===================================================================================================================================================
always_comb begin
   case (memacc_size)
      BYTE    : store_data = i_op1[7:0]  << (8 * store_addr[`XLSB-1:0]) ;  // Extend LS Byte and send
      HWORD   : store_data = i_op1[15:0] << (8 * store_addr[`XLSB-1:0]) ;  // Extend LS Half-word and send
      WORD    : store_data = i_op1 ;                                       // Send word
      default : store_data = i_op1 ;                                       // Send word
   endcase      
end

// Opcode decoding
assign is_op_load  = i_is_load    ;
assign is_op_store = i_is_s_type  ;
assign memacc_size = i_funct3[1:0];
assign bubble      = (is_op_load || is_op_store)? i_bubble : 1'b1 ;  // Insert bubble if neither Load/Store instruction

// Load/Store address decoding
assign immI        = {{(`XLEN-12){i_immI[11]}}, i_immI} ;  // Sign-extend
assign immS        = {{(`XLEN-12){i_immS[11]}}, i_immS} ;  // Sign-extend
assign load_addr   = i_op0 + immI ;
assign store_addr  = i_op0 + immS ;

// Memory Access Interface outputs
assign o_mem_cmd   = mem_cmd_rg  ;
assign o_mem_addr  = mem_addr_rg ;
assign o_mem_size  = mem_size_rg ;
assign o_mem_data  = mem_data_rg ;
assign o_bubble    = bubble_rg   ;

endmodule
//###################################################################################################################################################
//                                                         L O A D - S T O R E   U N I T                                         
//###################################################################################################################################################