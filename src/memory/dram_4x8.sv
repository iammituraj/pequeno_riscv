//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% 
//----%% File Name        : dram_4x8.sv
//----%% Module Name      : Data RAM 4x8                                          
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : 32-bit Data RAM with 4 banks of 8-bit RAMs. Depth is configurable.
//----%%                    All banks are simultaneously accessed for read and writes. Per-bank ie., Per-byte write/read is supported.
//----%%                    Supports debugging/dumping memory content during simulation.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Feb-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                           D A T A   R A M   4 x 8                                          
//###################################################################################################################################################
// Header files
`include "../include/pqr5_subsystem_macros.svh"

// Packages imported
import pqr5_subsystem_pkg :: * ;

// Module definition
module dram_4x8 #(
   // Configurable Parameters   
   parameter  DEPTH    = 1024 ,            // Depth of RAM

   // Derived/Constant Parameters
   localparam DATA_W   = 32            ,   // Data width
   localparam ADDR_W   = $clog2(DEPTH) ,   // Address width
   localparam DEPTH_2N = 2**ADDR_W         // Actual depth implemented = nearest power of 2^N 
)
(
   // Clock and Reset Interface  
   input  logic              clk    ,    // Clock
      
   // Memory Interface
   input  logic [3:0]        i_en   ,    // Byte-enable
   input  logic              i_wen  ,    // Write enable
   input  logic [ADDR_W-1:0] i_addr ,    // Address
   input  logic [DATA_W-1:0] i_data ,    // Data in
   output logic [DATA_W-1:0] o_data      // Data out
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic [7:0]        wdata [4] ;  // Write-data to each bank
logic [7:0]        rdata [4] ;  // Read-data from each bank
`ifdef MEM_DBG
logic [7:0]        ram      [4] [DEPTH_2N] ;  // 2D RAM array to store RAM array from each bank
logic [DATA_W-1:0] ram_dram [DEPTH_2N]     ;  // RAM array which accumulates data of all banks
`endif

//===================================================================================================================================================
// Submodule Instances
//===================================================================================================================================================
// 8-bit Data RAM instance for Bank-0
dram #(
   .DATA_W (8) ,
   .DEPTH  (DEPTH_2N)
) 
inst_dram_b0 (
   .clk    (clk)       , 
   `ifdef MEM_DBG
   .o_ram  (ram[0])    ,
   `endif  
   .i_en   (i_en[0])   ,
   .i_wen  (i_wen)     , 
   .i_addr (i_addr)    ,
   .i_data (wdata[0])  ,
   .o_data (rdata[0])  
);

// 8-bit Data RAM instance for Bank-1
dram #(
   .DATA_W (8) ,
   .DEPTH  (DEPTH_2N)
) 
inst_dram_b1 (
   .clk    (clk)       ,
   `ifdef MEM_DBG
   .o_ram  (ram[1])    ,
   `endif   
   .i_en   (i_en[1])   ,
   .i_wen  (i_wen)     , 
   .i_addr (i_addr)    ,
   .i_data (wdata[1])  ,
   .o_data (rdata[1])  
);

// 8-bit Data RAM instance for Bank-2
dram #(
   .DATA_W (8) ,
   .DEPTH  (DEPTH_2N)
) 
inst_dram_b2 (
   .clk    (clk)       ,
   `ifdef MEM_DBG
   .o_ram  (ram[2])    ,
   `endif   
   .i_en   (i_en[2])   ,
   .i_wen  (i_wen)     , 
   .i_addr (i_addr)    ,
   .i_data (wdata[2])  ,
   .o_data (rdata[2])  
);

// 8-bit Data RAM instance for Bank-3
dram #(
   .DATA_W (8) ,
   .DEPTH  (DEPTH_2N)
) 
inst_dram_b3 (
   .clk    (clk)       ,
   `ifdef MEM_DBG
   .o_ram  (ram[3])    ,
   `endif   
   .i_en   (i_en[3])   ,
   .i_wen  (i_wen)     , 
   .i_addr (i_addr)    ,
   .i_data (wdata[3])  ,
   .o_data (rdata[3])  
);

//===================================================================================================================================================
// Continuous assignments
//===================================================================================================================================================
`ifdef MEM_DBG
genvar i ;
for (i=0; i<DEPTH_2N; i++) begin    
   assign ram_dram[i][7:0]   = ram[0][i] ;  // Bank-0
   assign ram_dram[i][15:8]  = ram[1][i] ;  // Bank-1
   assign ram_dram[i][23:16] = ram[2][i] ;  // Bank-2
   assign ram_dram[i][31:24] = ram[3][i] ;  // Bank-3 
end
`endif

assign wdata[0] = i_data[7:0]   ;  // Bank-0
assign wdata[1] = i_data[15:8]  ;  // Bank-1
assign wdata[2] = i_data[23:16] ;  // Bank-2
assign wdata[3] = i_data[31:24] ;  // Bank-3

assign o_data   = {rdata[3], rdata[2], rdata[1], rdata[0]} ;  //{Bank-3, Bank-2, Bank-1, Bank-0}

//===================================================================================================================================================
// Generate Debug Blocks
//===================================================================================================================================================
`ifdef MEM_DBG
generate   
if (`DMEM_DUMP) begin : DBG_DMEM_DUMP
// Variables
int     fdump ;
string  fdump_fname = "./pqr5_dmem_dump.txt" ;

// Creates dump file
initial begin
   fdump    = $fopen(fdump_fname, "w");
   if (!fdump) begin $display("| PQR5_SIM_DMEM: [ERROR] Can't create pqr5_dmem_dump.txt!!");          end
   else        begin $display("| PQR5_SIM_DMEM: [INFO ] Created pqr5_dmem_dump.txt successfully..."); end      
   $fclose(fdump);
end

// Dump at the end of simulation
final begin
   fdump = $fopen(fdump_fname, "w");    
   if (!fdump) begin $display("| PQR5_SIM_DMEM: [ERROR] Can't dump to pqr5_dmem_dump.txt!!");  end
   else        begin dump_mem(fdump, DEPTH_2N, 32, ram_dram, "DMEM Dump"); 
                     $display("| PQR5_SIM_DMEM: [INFO ] Dumped DMEM content successfully..."); end 
   $fclose(fdump);       
end
end//GENERATE: DBG_DMEM_DUMP 
endgenerate
`endif

endmodule
//###################################################################################################################################################
//                                                           D A T A   R A M   4 x 8                                          
//###################################################################################################################################################