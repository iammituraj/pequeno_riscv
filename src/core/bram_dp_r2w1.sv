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
//----%% File Name        : bram_dp_r2w1.sv
//----%% Module Name      : Dual-port Block RAM with 2 read ports, 1 write port                                          
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Dual-port Block RAM which can be mapped to FPGA BRAMs.
//----%%                    ## Two Read ports with common read enable, one Write port
//----%%                    ## Synchronous read & write, 1-cycle access
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Apr-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                    D U A L - P O R T   B L O C K   R A M                                       
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Module definition
module bram_dp_r2w1#(
   // Configurable Parameters
   parameter  DTW = 32,  // Data width
   parameter  DPT = 32,  // Depth of RAM

   // Derived/Constant Parameters
   localparam ADW    = $clog2(DPT),  // Address width
   localparam DPT_2N = 2**ADW        // Depth of RAM scaled to 2^N for compatibility with FPGA Block RAMs
)
(
   // Clock
   input  logic clk,

   `ifdef DBG
   // Debug ports
   output logic [DTW-1:0] o_marray [DPT_2N] ,  // Memory array
   `endif
   
   // Write Port
   input  logic           i_wren  ,  // Write enable
   input  logic [ADW-1:0] i_waddr ,  // Write address
   input  logic [DTW-1:0] i_wdata ,  // Write data

   // Read Ports
   input  logic           i_rden   ,  // Read enable
   input  logic [ADW-1:0] i_raddr0 ,  // Read address to port-0
   output logic [DTW-1:0] o_rdata0 ,  // Read data from port-0
   input  logic [ADW-1:0] i_raddr1 ,  // Read address to port-1
   output logic [DTW-1:0] o_rdata1    // Read data from port-1
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
(* ram_style = "block" *)
logic [DTW-1:0] ram [DPT_2N]         ;  // 2D memory array
logic [DTW-1:0] rdata0_rg, rdata1_rg ;  // Read data

//===================================================================================================================================================
// Synchronous logic to write to RAM
//===================================================================================================================================================
always_ff @(posedge clk) begin
   if (i_wren) begin
      ram[i_waddr] <= i_wdata ;
   end
end

//===================================================================================================================================================
// Synchronous logic to read from Read port-0
//===================================================================================================================================================
always_ff @(posedge clk) begin
   if (i_rden) begin      
      rdata0_rg <= ram[i_raddr0];
   end
end

//===================================================================================================================================================
// Synchronous logic to read from Read port-1
//===================================================================================================================================================
always_ff @(posedge clk) begin
   if (i_rden) begin      
      rdata1_rg <= ram[i_raddr1];
   end
end

// Read data to outputs
assign o_rdata0 = rdata0_rg ;
assign o_rdata1 = rdata1_rg ;

`ifdef DBG
assign o_marray = ram ;
`endif

endmodule
//###################################################################################################################################################
//                                                    D U A L - P O R T   B L O C K   R A M                                       
//###################################################################################################################################################