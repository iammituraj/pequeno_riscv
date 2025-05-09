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
//----%% File Name        : uarttx_addrmap.sv
//----%% Module Name      : UART TX Address Map                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic™, https://chipmunklogic.com
//----%%
//----%% Description      : Register address map for UART TX in UART IP core. 
//----%%                    Additionally, the clock tick counter is also added to the address map. This has nothing to do with UART,
//----%%                    and is added only for external debug purpose.
//----%%                    +=============+========+===========================================
//----%%                    | ADDRESS     | Access | CSR
//----%%                    +=============+========+===========================================
//----%%                    | 0x0000_0000 | RW     | Control {30'h0, tx_rst, tx_en}
//----%%                    | 0x0000_0004 | RW     | TXdata  {24'h0, tx_data}
//----%%                    | 0x0000_0008 | RO     | Status  {23'h0, tx_state, 7'h0, tx_ready}
//----%%                    | 0x0000_000C | RO     | Counter {clock tick}
//----%%                    +=============+========+===========================================
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : April-2025
//----%% Notes            : -
//----%%
//----%% Copyright        : Open-source license, see LICENSE
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                     U A R T   T X   A D D R E S S   M A P                                          
//###################################################################################################################################################
module uarttx_addrmap (
   // Clock and Reset
   input  logic        clk              ,  // Clock
   input  logic        rstn             ,  // Reset; asynchronous, active-low
   
   // Addressing Interface
   input  logic        i_en             ,  // Enable
   input  logic        i_wen            ,  // Write enable
   input  logic [3:0]  i_byteen         ,  // Byte enable (for write)
   input  logic [5:0]  i_addr           ,  // Address
   input  logic [31:0] i_data           ,  // Write data
   output logic [31:0] o_data           ,  // Read data 
   
   // Control and Status
   output logic        o_tx_en          ,  // TX enable     
   output logic        o_tx_rst         ,  // TX reset     
   output logic [7:0]  o_tx_data        ,  // TX data   
   output logic        o_tx_data_valid  ,  // Data valid
   input  logic        i_tx_data_ready  ,  // Data ready
   input  logic        i_tx_state       ,  // TX state

   // Clock tick counter
   input  logic [31:0] i_clktick_cnt       // Clock tick counter
);

//===================================================================================================================================================
// Localparams and Registers
//===================================================================================================================================================
// Word addressing of CSRs
localparam CSR0_CONTROL = 4'h0 ;
localparam CSR1_TXDATA  = 4'h1 ;
localparam CSR2_STATUS  = 4'h2 ;
localparam CSR3_COUNTER = 4'h3 ;

// CSRegisters
logic [1:0]  csr0_control ;
logic [7:0]  csr1_txdata  ;
logic [8:0]  csr2_status  ;
logic [31:0] csr3_counter ;

//===================================================================================================================================================
// Write logic for RW registers
//===================================================================================================================================================
logic csr1_wen_pulse ;  // Write enable pulse for csr1 to indicate that the register is written...

always @(posedge clk or negedge rstn) begin
   if (!rstn) begin
      csr0_control   <= 2'h0 ;
      csr1_txdata    <= 8'h0 ;   
      csr1_wen_pulse <= 1'b0 ;   
   end 
   else begin
      if (i_en && i_wen) begin
         case (i_addr[5:2])
            CSR0_CONTROL : if (i_byteen[0]) csr0_control <= i_data[1:0] ;
            CSR1_TXDATA  : begin 
                              if (i_byteen[0]) csr1_txdata    <= i_data[7:0] ;
                              if (i_byteen[0]) csr1_wen_pulse <= 1'b1 ;  // csr1 WE pulse assertion
                           end
            default      : ;
         endcase          
      end
      if (csr1_wen_pulse == 1'b1) csr1_wen_pulse <= 1'b0 ;  // csr1 WE pulse de-assertion
   end   
end

//===================================================================================================================================================
// Logging RO registers
//===================================================================================================================================================
assign csr2_status  = {i_tx_state, 7'h0, i_tx_data_ready} ;
assign csr3_counter = i_clktick_cnt ;

//===================================================================================================================================================
// Read logic for all registers
//===================================================================================================================================================
always @(posedge clk or negedge rstn) begin
   if (!rstn) begin
      o_data <= 32'h0 ;   
   end 
   else begin
      if (i_en) begin
         case (i_addr[5:2])
            CSR0_CONTROL : o_data <= {30'h0, csr0_control} ;
            CSR1_TXDATA  : o_data <= {24'h0,  csr1_txdata} ;
            CSR2_STATUS  : o_data <= {23'h0,  csr2_status} ;
            CSR3_COUNTER : o_data <= csr3_counter          ;
            default      : o_data <= 32'h0                 ;
         endcase          
      end
   end   
end

//===================================================================================================================================================
// Control signals
//===================================================================================================================================================
assign o_tx_en         = csr0_control[0] ;
assign o_tx_rst        = csr0_control[1] ;
assign o_tx_data       = csr1_txdata     ;
assign o_tx_data_valid = csr1_wen_pulse  ;

endmodule
//###################################################################################################################################################
//                                                     U A R T   T X   A D D R E S S   M A P                                          
//###################################################################################################################################################