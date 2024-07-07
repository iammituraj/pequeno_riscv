//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% 
//----%% File Name        : dram.sv
//----%% Module Name      : Single-port RAM                                             
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Single-port RAM with synchronous reads and writes. Configurable data width and depth.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Nov-2022
//----%% Notes            : Infers Block RAM on FPGAs in Read-First configuration. Use appropriate attribute to direct Synthesiser tool.
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                                    R A M                                          
//###################################################################################################################################################
// Header files
`include "../include/pqr5_subsystem_macros.svh"

// Module definition
module dram #(
   // Configurable Parameters
   parameter  DATA_W   = 32   ,           // Data width
   parameter  DEPTH    = 1024 ,           // Depth of RAM

   // Derived/Constant Parameters
   localparam ADDR_W   = $clog2(DEPTH) ,  // Address width
   localparam DEPTH_2N = 2**ADDR_W        // Actual depth implemented = nearest power of 2^N 
)
(
   // Clock and Reset Interface  
   input  logic              clk     ,  // Clock

   `ifdef MEM_DBG
   // Debug Interface
   output logic [DATA_W-1:0] o_ram [DEPTH_2N] ,  // RAM array   
   `endif

   // Memory Interface
   input  logic              i_en    ,  // Enable
   input  logic              i_wen   ,  // Write enable
   input  logic [ADDR_W-1:0] i_addr  ,  // Address
   input  logic [DATA_W-1:0] i_data  ,  // Data in
   output logic [DATA_W-1:0] o_data     // Data out
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
(* ram_style = "block" *)
logic [DATA_W-1:0] ram [DEPTH_2N] ;    // 2D memory array
logic [DATA_W-1:0] data_rg        ;    // Output data

//===================================================================================================================================================
// Synchronous logic to write/read from RAM
//===================================================================================================================================================
always@(posedge clk) begin

   // Enable RAM
   if (i_en) begin
      if (i_wen) begin
         ram[i_addr] <= i_data ;  // Write        
      end
      data_rg <= ram[i_addr] ;    // Read
   end

end

assign o_data = data_rg ;

`ifdef MEM_DBG
// Debug Interface
assign o_ram = ram ;   
`endif

endmodule
//###################################################################################################################################################
//                                                                    R A M                                          
//###################################################################################################################################################