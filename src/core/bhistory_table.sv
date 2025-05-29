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
//----%% File Name        : bhistory_table.sv
//----%% Module Name      : Branch History Table                                      
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Branch History Table (BHT) stores the history of recently executed branches. 2-bit value indicates the history.
//----%%                    2'b00 - Strongly not taken
//----%%                    2'b01 - Weakly not taken
//----%%                    2'b10 - Weakly taken
//----%%                    2'b11 - Strongly taken
//----%%                    - BHT has two read ports, one write port 
//----%%                    - BHT can be configured to map to Block RAM or LUT RAM on FPGAs; no reset.
//----%%                    - On ASIC, BHT should be configured to be implemented on flip-flops to support reset value.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : May-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                    B R A N C H   H I S T O R Y   T A B L E                                      
//###################################################################################################################################################
// Module definition
module bhistory_table#(
   // Configurable Parameters
   parameter  TGT    = "blkram",  // Target = "blkram" / "lutram" / "flops"; BHT to be implemented on Block RAM / Distributed or LUT RAM / Flops
   parameter  DPT    = 64      ,  // No. of entries in the table, 2^N
   parameter  RSTVAL = 2'b10   ,  // BHT reset value of all entries

   // Derived/Constant Parameters 
   localparam ADW    = $clog2(DPT),  // Address width
   localparam DPT_2N = 2**ADW        // Depth scaled to 2^N
)
(
   // Clock and Reset
   input  logic           clk       ,  // Clock
   input  logic           aresetn   ,  // Asynchronous Reset; active-low
   
   // Write Port
   input  logic           i_wren    ,  // Write enable
   input  logic [ADW-1:0] i_waddr   ,  // Write address
   input  logic [1:0]     i_wdata   ,  // Write data

   // Read Ports
   input  logic           i_rden0  ,  // Read enable @port-0
   input  logic [ADW-1:0] i_raddr0 ,  // Read address @port-0
   output logic [1:0]     o_rdata0 ,  // Read data @port-0
   input  logic           i_rden1  ,  // Read enable @port-1
   input  logic [ADW-1:0] i_raddr1 ,  // Read address @port-1
   output logic [1:0]     o_rdata1    // Read data @port-1
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
generate
if (TGT == "blkram") begin : gen_ram
   (* ram_style = "block" *)
   logic [1:0] ram [DPT_2N] ;  // 2D memory array on BRAM
   initial begin
      for (integer i=0; i<DPT_2N; i=i+1) ram[i] = RSTVAL; // Initial value, synthesisable only on FPGAs
   end
end else if (TGT == "lutram") begin : gen_ram
   (* ram_style = "distributed" *)
   logic [1:0] ram [DPT_2N] ;  // 2D memory array on LUT RAM
   initial begin
      for (integer i=0; i<DPT_2N; i=i+1) ram[i] = RSTVAL; // Initial value, synthesisable only on FPGAs
   end
end else begin : gen_ram
	logic [1:0] ram [DPT_2N] ;  // 2D memory array on flip-flops
end
endgenerate

logic [1:0] rdata0_rg, rdata1_rg ;  // Read data

//===================================================================================================================================================
// Synchronous logic to update BHT
//===================================================================================================================================================
generate
if (TGT == "blkram" || TGT == "lutram") begin
   always_ff @(posedge clk) begin
      if (i_wren) begin
         gen_ram.ram[i_waddr] <= i_wdata ;
      end
   end
end else begin
   always_ff @(posedge clk or negedge aresetn) begin
      if (!aresetn) begin  // Reset is reqd only if the BHT is implemented on flops...
         for (integer i=0; i<DPT_2N; i=i+1) gen_ram.ram[i] <= RSTVAL;
      end else if (i_wren) begin
         gen_ram.ram[i_waddr] <= i_wdata ;
      end
   end	
end
endgenerate

//===================================================================================================================================================
// Synchronous logic to read from BHT at Read port-0
//===================================================================================================================================================
always_ff @(posedge clk) begin
   if (i_rden0) begin      
      rdata0_rg <= gen_ram.ram[i_raddr0];
   end
end

//===================================================================================================================================================
// Synchronous logic to read from BHT at Read port-1
//===================================================================================================================================================
always_ff @(posedge clk) begin
   if (i_rden1) begin      
      rdata1_rg <= gen_ram.ram[i_raddr1];
   end
end

// Read data to outputs
assign o_rdata0 = rdata0_rg ;
assign o_rdata1 = rdata1_rg ;

endmodule
//###################################################################################################################################################
//                                                    B R A N C H   H I S T O R Y   T A B L E                                      
//###################################################################################################################################################