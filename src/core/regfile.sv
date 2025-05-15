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
//----%% Last modified on : Apr-2025
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
logic wren ;                         // Write enable to Register array
logic rden ;                         // Read enable to Register array
logic [`XLEN-1:0] reg_file [1:31] ;  // Register file: x1-x31, x0 is implicitly 0...

//===================================================================================================================================================
// Register Array of RF
//===================================================================================================================================================
`ifdef RF_IN_BRAM
////////////////////////////////////////////// BRAM based RF /////////////////////////////////////////////////////
logic [`XLEN-1:0] rdata0, rdata1 ;  // Read data from the Register array
`ifdef DBG
logic [`XLEN-1:0] bram_marray[0:31]   ;  // Memory array of BRAM
`endif

// BRAM instance
bram_dp_r2w1 #(
   .DTW (`XLEN),
   .DPT (32)
)  inst_bram_regfile (
   .clk      (clk),

   .i_wren   (wren),
   .i_waddr  (i_rdt_addr),
   .i_wdata  (i_rdt_data),

   `ifdef DBG
   .o_marray (bram_marray),
   `endif

   .i_rden   (rden),      
   .i_raddr0 (i_rs0_addr),
   .o_rdata0 (rdata0),
   .i_raddr1 (i_rs1_addr),
   .o_rdata1 (rdata1)
);

// Write & Read enable conditioned...
assign wren = i_wren ;  // If target is x0, WBU never generates write enable... So no need to condition with |i_rdt_addr
assign rden = i_rden ;

//-------------------------------------------------------------------
// Glue Logic to condition the read data if x0 is accessed
//-------------------------------------------------------------------
// Flag the x0 access concurrent to read access
logic is_rs0_not_x0_rg ;
always_ff @(posedge clk) begin
   if (rden) begin      
      is_rs0_not_x0_rg <= |i_rs0_addr ;
   end
end
assign o_rs0_data = is_rs0_not_x0_rg? rdata0 : '0 ;  // x0 always read as 0...

// Flag the x0 access concurrent to read access
logic is_rs1_not_x0_rg ;
always_ff @(posedge clk) begin
   if (rden) begin      
      is_rs1_not_x0_rg <= |i_rs1_addr ;
   end
end
assign o_rs1_data = is_rs1_not_x0_rg? rdata1 : '0 ;  // x0 always read as 0...

`ifdef DBG
assign reg_file = bram_marray[1:31];
`endif

`else
////////////////////////////////////////////// Flops based RF ////////////////////////////////////////////////////
logic [`XLEN-1:0] rs0_data_rg   ;  // Read data from port-0
logic [`XLEN-1:0] rs1_data_rg   ;  // Read data from port-1

// Write & Read enable conditioned...
assign wren = i_wren ;  // If target is x0, WBU will not generate write enable... So no need to condition with |i_rdt_addr
assign rden = i_rden ;

//-------------------------------------------------------------------
// Synchronous logic to write to register file
//-------------------------------------------------------------------
always_ff @(posedge clk) begin
   if (wren) begin
      reg_file[i_rdt_addr] <= i_rdt_data ;
   end
end

//-------------------------------------------------------------------
// Synchronous logic to read from register file (Read port-0)
//-------------------------------------------------------------------
always_ff @(posedge clk) begin
   if (rden) begin      
      if (~|i_rs0_addr) begin rs0_data_rg <= '0                   ; end  // x0 is hard-wired & read as 0
      else              begin rs0_data_rg <= reg_file[i_rs0_addr] ; end
   end
end
assign o_rs0_data = rs0_data_rg ;

//-------------------------------------------------------------------
// Synchronous logic to read from register file (Read port-1)
//-------------------------------------------------------------------
always_ff @(posedge clk) begin
   if (rden) begin
      if (~|i_rs1_addr) begin rs1_data_rg <= '0                   ; end  // x0 is hard-wired & read as 0
      else              begin rs1_data_rg <= reg_file[i_rs1_addr] ; end
   end
end
assign o_rs1_data = rs1_data_rg ;

`endif  //RF_IN_BRAM

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