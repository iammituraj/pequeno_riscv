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
//----%% File Name        : regfile.sv
//----%% Module Name      : Register File (RF)                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Register File (RF) of PQR5 Core
//----%%                    # Implements all 32 general purpose registers: r0 to r31.
//----%%                    # Supports two synchronous read ports and one synchronous write port.
//----%%                    # Single cycle read and write.
//----%%                    # Supports debugging/dumping register space during simulation.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Jan-2024
//----%% Notes            : The register array is expected to map to BRAMs. Doesn't support reset as FPGA BRAMs don't support resetting the array. 
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         R E G I S T E R   F I L E                                          
//###################################################################################################################################################
// Header files included
`include "../include/pqr5_core_macros.svh"

// Packages imported
import pqr5_core_pkg :: * ;

// Module definition
module regfile (
   // Clock and Reset
   input  logic             clk        ,  // Clock
   input  logic             aresetn    ,  // Asynchronous Reset; active-low //**CHECKME**// Unused signal as of now

   `ifdef DBG
   // Debug Interface  
   output logic [`XLEN-1:0] o_regf_dbg [32] ,  // Debug signal
   `endif

   `ifdef TEST_PORTS
   // Test Ports
   output logic [`XLEN-1:0] o_x31_tst  ,  // x31
   `endif
   
   // Read enable (common for both read ports)
   input  logic             i_rden     ,  // Read Enable

   // Read Port-0   
   input  logic [4:0]       i_rs0_addr ,  // Register address
   output logic [`XLEN-1:0] o_rs0_data ,  // Register data read out

   // Read Port-1
   input  logic [4:0]       i_rs1_addr ,  // Register address
   output logic [`XLEN-1:0] o_rs1_data ,  // Register data read out

   // Write Port
   input  logic             i_wren     ,  // Write Enable
   input  logic [4:0]       i_rdt_addr ,  // Register address
   input  logic [`XLEN-1:0] i_rdt_data    // Register data in
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic [`XLEN-1:0] reg_file [1:31] ;  // Register file
logic             wren            ;  // Write enable to RF
logic [`XLEN-1:0] rs0_data_rg     ;  // Read-data Port-0
logic [`XLEN-1:0] rs1_data_rg     ;  // Read-data Port-1

//===================================================================================================================================================
// Synchronous logic to write to register file
//===================================================================================================================================================
always_ff @(posedge clk) begin
   if (wren) begin
      reg_file[i_rdt_addr] <= i_rdt_data ;
   end
end
assign wren = i_wren && (|i_rdt_addr);  // r0 is hardwired to 0, so no need to enable writes

//===================================================================================================================================================
// Synchronous logic to read from register bank (Read Port-0)
//===================================================================================================================================================
always_ff @(posedge clk) begin
   if (i_rden) begin      
      rs0_data_rg <= reg_file[i_rs0_addr];
   end
end

// Register the address on reads
logic [4:0] rs0_addr_rg ;
always_ff @(posedge clk) begin
   if (i_rden) begin      
      rs0_addr_rg <= i_rs0_addr ;
   end
end
assign o_rs0_data = (|rs0_addr_rg)? rs0_data_rg : '0 ;  // r0 always read as 0

//===================================================================================================================================================
// Synchronous logic to read from register bank (Read Port-1)
//===================================================================================================================================================
always_ff @(posedge clk) begin
   if (i_rden) begin      
      rs1_data_rg <= reg_file[i_rs1_addr];
   end
end

// Register the address on reads
logic [4:0] rs1_addr_rg ;
always_ff @(posedge clk) begin
   if (i_rden) begin      
      rs1_addr_rg <= i_rs1_addr ;
   end
end
assign o_rs1_data = (|rs1_addr_rg)? rs1_data_rg : '0 ;  // r0 always read as 0

`ifdef TEST_PORTS
// Test Ports
assign o_x31_tst = reg_file[31] ;
`endif

//===================================================================================================================================================
// Generate Debug Blocks
//===================================================================================================================================================
`ifdef DBG
logic [`XLEN-1:0] reg_file_pp [0:31] ;  // Register file

generate   
if (`REGFILE_DUMP) begin : DBG_REGFILE_DUMP
// Variables
int    fdump ;
string fdump_fname = "./pqr5_regfile_dump.txt" ;

// Creates dump file
initial begin
   fdump    = $fopen(fdump_fname, "w");
   if (!fdump) begin $display("| PQR5_SIM_REGF: [ERROR] Can't create pqr5_regfile_dump.txt!!");          end
   else        begin $display("| PQR5_SIM_REGF: [INFO ] Created pqr5_regfile_dump.txt successfully..."); end      
   $fclose(fdump);
end

// Dump at the end of simulation
final begin
   fdump = $fopen(fdump_fname, "w");    
   if (!fdump) begin $display("| PQR5_SIM_REGF: [ERROR] Can't dump to pqr5_regfile_dump.txt!!");  end
   else        begin dump_regfile(fdump, 32, reg_file_pp, "Register File Dump"); 
                     $display("| PQR5_SIM_REGF: [INFO ] Dumped Register File successfully...");   end 
   $fclose(fdump);       
end
end//GENERATE: DBG_REGFILE_DUMP 
endgenerate

genvar i;
generate
assign reg_file_pp[0] = '0 ;
for (i=1; i<32; i++) begin
   assign reg_file_pp[i] = reg_file[i];   
end
endgenerate

assign o_regf_dbg  = {reg_file_pp};
`endif

endmodule
//###################################################################################################################################################
//                                                         R E G I S T E R   F I L E                                          
//###################################################################################################################################################