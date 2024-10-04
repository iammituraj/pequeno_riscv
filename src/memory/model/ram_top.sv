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
//----%% Module Name      : Instruction Memory (IMEM) Wrapper                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This is a wrapper over Instruction RAM (I-RAM) to incorporate valid-ready handshaking and Programming Interface.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Jan-2024
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                               I N S T R U C T I O N   M E M O R Y   -   W R A P P E R                                         
//###################################################################################################################################################
module ram_top #(	
   // Configurable Parameters
   parameter  DATA_W = 32   ,           // Data width of RAM
   parameter  DEPTH  = 1024 ,           // Depth of RAM
   parameter  ID_W   = 32   ,           // Request ID width

   // Derived/Constant Parameters
   localparam ADDR_W = $clog2(DEPTH)    // Address width of RAM
)
(
   // Clock and Reset Interface  
   input  logic              clk     ,    // Clock
   input  logic              aresetn ,    // Asynchronous Reset; active-low
   
   // Programming Interface: used to write the binary to Instruction RAM
   input  logic              i_pgm_en         ,  // Programming mode Enable
   input  logic [ADDR_W-1:0] i_pgm_iram_addr  ,  // Address
   input  logic [DATA_W-1:0] i_pgm_iram_wdata ,  // Write Data
   input  logic              i_pgm_iram_en    ,  // RAM Enable
   input  logic              i_pgm_iram_wen   ,  // Write Enable
   output logic [DATA_W-1:0] o_pgm_iram_rdata ,  // Read Data
   
   // Miscellaneous control: used by Master
   input  logic [ID_W-1:0]   i_reqid ,    // Request ID in
   output logic [ID_W-1:0]   o_reqid ,    // Request ID out
   input  logic              i_flush ,    // Flush signal

   // Memory Interface: used by Master
   input  logic [ADDR_W-1:0] i_addr  ,    // Address
   input  logic              i_valid ,    // Address valid
   output logic              o_ready ,    // Memory ready   
   output logic [DATA_W-1:0] o_data  ,    // Data out
   output logic              o_valid ,    // Data valid
   input  logic              i_ready      // Data ready
);

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic              mstr_iram_en     ;    // I-RAM Enable from Master
logic              mstr_iram_wen    ;    // I-RAM Write Enable from Master
logic [ADDR_W-1:0] mstr_iram_addr   ;    // I-RAM Address from Master
logic              rd_en            ;    // Read enable from Master

logic [ID_W-1:0]   reqid_rg         ;    // Request ID out

logic              iram_en          ;    // I-RAM Enable
logic              iram_wen         ;    // I-RAM Write Enable
logic [ADDR_W-1:0] iram_addr        ;    // I-RAM Address
logic [DATA_W-1:0] iram_wdata       ;    // I-RAM Write Data
logic [DATA_W-1:0] iram_rdata       ;    // I-RAM Read Data

logic              data_valid_rg    ;    // Data valid register
logic              ready, ready_rg  ;    // Ready, Ready register

//===================================================================================================================================================
// Submodule Instances
//===================================================================================================================================================

// Instruction RAM (I-RAM)
iram #(
   .DATA_W (DATA_W) ,
   .DEPTH  (DEPTH)
) 
inst_iram (
   .clk    (clk)        ,   
   .i_en   (iram_en)    ,
   .i_wen  (iram_wen)   , 
   .i_addr (iram_addr)  ,
   .i_data (iram_wdata) ,
   .o_data (iram_rdata)  
);

//===================================================================================================================================================
// Synchronous logic to generate ready and valid
//===================================================================================================================================================
always @(posedge clk or negedge aresetn) begin
   if (!aresetn) begin
      ready_rg      <= 1'b0 ;  
      data_valid_rg <= 1'b0 ;  
      reqid_rg      <= '0   ; 
   end
   else if (!i_flush) begin
      ready_rg      <= 1'b1  ;      
      data_valid_rg <= ready? rd_en   : data_valid_rg ; 
      reqid_rg      <= ready? i_reqid : reqid_rg      ;     
   end
   else begin  // Flush - synchronous
      ready_rg      <= 1'b0 ;  
      data_valid_rg <= 1'b0 ;  
      reqid_rg      <= '0   ;
   end
end

//===================================================================================================================================================
// Continuous Assignments
//===================================================================================================================================================
// I-RAM control signals from Master
assign mstr_iram_en    = i_valid && ready ;
assign mstr_iram_wen   = 1'b0             ;
assign mstr_iram_addr  = i_addr           ;
assign rd_en           = mstr_iram_en     ;

// I-RAM Mux: selects between Master/Programming Interface control
assign iram_en    = (i_pgm_en)? i_pgm_iram_en   : mstr_iram_en   ;
assign iram_wen   = (i_pgm_en)? i_pgm_iram_wen  : mstr_iram_wen  ;
assign iram_addr  = (i_pgm_en)? i_pgm_iram_addr : mstr_iram_addr ;
assign iram_wdata = i_pgm_iram_wdata ;

// Valid and Ready
assign ready   = i_ready && ready_rg ;
assign o_ready = ready               ;
assign o_valid = data_valid_rg       ;

// Data and Request ID out
assign o_reqid          = reqid_rg   ;
assign o_data           = iram_rdata ;
assign o_pgm_iram_rdata = iram_rdata ;

endmodule
//###################################################################################################################################################
//                                               I N S T R U C T I O N   M E M O R Y   -   W R A P P E R                                         
//###################################################################################################################################################