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
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                                   R A M                                          
//###################################################################################################################################################
// Header files
`include "../include/pqr5_subsystem_macros.svh"

// Packages imported
import pqr5_subsystem_pkg :: * ;

// Module definition
module ram #(
   // Configurable Parameters
   parameter  DATA_W   = 32   ,           // Data width
   parameter  DEPTH    = 1024 ,           // Depth of RAM

   // Derived/Constant Parameters
   localparam ADDR_W   = $clog2(DEPTH) ,  // Address width
   localparam DEPTH_2N = 2**ADDR_W        // Actual depth implemented = nearest power of 2^N
)
(
   // Clock and Reset Interface  
   input  logic              clk    ,  // Clock   
   
   // Memory Interface
   input  logic              i_en   ,  // Enable
   input  logic              i_wen  ,  // Write enable
   input  logic [ADDR_W-1:0] i_addr ,  // Address
   input  logic [DATA_W-1:0] i_data ,  // Data in
   output logic [DATA_W-1:0] o_data    // Data out
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
      data_rg <= ram[i_addr];     // Read
   end

end

assign o_data = data_rg ;

//===================================================================================================================================================
// Generate Debug Blocks
//===================================================================================================================================================
`ifdef MEM_DBG
generate   
if (`IMEM_DUMP) begin : DBG_IMEM_DUMP
// Variables
int     fdump ;
string  fdump_fname = "./pqr5_imem_dump.txt" ;

// Creates dump file
initial begin
   fdump    = $fopen(fdump_fname, "w");
   if (!fdump) begin $display("| PQR5_SIM_IMEM: [ERROR] Can't create pqr5_imem_dump.txt!!");          end
   else        begin $display("| PQR5_SIM_IMEM: [INFO ] Created pqr5_imem_dump.txt successfully..."); end      
   $fclose(fdump);
end

// Dump at the end of simulation
final begin
   fdump = $fopen(fdump_fname, "w");    
   if (!fdump) begin $display("| PQR5_SIM_IMEM: [ERROR] Can't dump to pqr5_imem_dump.txt!!");  end
   else        begin dump_mem(fdump, DEPTH_2N, 32, ram, "IMEM Dump"); 
                     $display("| PQR5_SIM_IMEM: [INFO ] Dumped IMEM content successfully..."); end 
   $fclose(fdump);       
end
end//GENERATE: DBG_IMEM_DUMP 
endgenerate
`endif

endmodule
//###################################################################################################################################################
//                                                                   R A M                                          
//###################################################################################################################################################
