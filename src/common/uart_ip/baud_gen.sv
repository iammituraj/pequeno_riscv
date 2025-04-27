//     %%%%%%%%%#      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//  %%%%%%%%%%%%%%%%%  ----------------------------------------------------------------------------------------------------------
// %%%%%%%%%%%%%%%%%%%% %
// %%%%%%%%%%%%%%%%%%%% %%
//    %% %%%%%%%%%%%%%%%%%%
//        % %%%%%%%%%%%%%%%                 //---- O P E N - S O U R C E ----//
//           %%%%%%%%%%%%%%                 ╔═══╦╗──────────────╔╗──╔╗
//           %%%%%%%%%%%%%      %%          ║╔═╗║║──────────────║║──║║
//           %%%%%%%%%%%       %%%%         ║║─╚╣╚═╦╦══╦╗╔╦╗╔╦═╗║║╔╗║║──╔══╦══╦╦══╗
//          %%%%%%%%%%        %%%%%%        ║║─╔╣╔╗╠╣╔╗║╚╝║║║║╔╗╣╚╝╝║║─╔╣╔╗║╔╗╠╣╔═╝ \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
//         %%%%%%%    %%%%%%%%%%%%*%%%      ║╚═╝║║║║║╚╝║║║║╚╝║║║║╔╗╗║╚═╝║╚╝║╚╝║║╚═╗ /////////////////////////////////////////////
//        %%%%% %%%%%%%%%%%%%%%%%%%%%%%     ╚═══╩╝╚╩╣╔═╩╩╩╩══╩╝╚╩╝╚╝╚═══╩══╩═╗╠╩══╝
//       %%%%*%%%%%%%%%%%%%  %%%%%%%%%      ────────║║─────────────────────╔═╝║
//       %%%%%%%%%%%%%%%%%%%    %%%%%%%%%   ────────╚╝─────────────────────╚══╝
//       %%%%%%%%%%%%%%%%                   c h i p m u n k l o g i c . c o m
//       %%%%%%%%%%%%%%
//         %%%%%%%%%
//           %%%%%%%%%%%%%%%%  --------------------------------------------------------------------------------------------------
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% 
//----%% 
//----%% Module Name      : Baud Generator                                              
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Baud Generator to generate baud clock pulse for Uart Transmitter and Receiver.
//----%%
//----%%                    FEATURES
//----%%                    --------
//----%%                    - Run-time configurable baud rate, B.
//----%%                    - Computing B:
//----%%                      Desired baud rate  = Clock freq / ((B + 1) * 8)
//----%%                      ==> B = INT((Clock freq / Desire baud rate) / 8) - 1  // Rounding off to nearest integer...
//----%%                      Min value of B = 1 which gives max. baud rate = F/16
//----%%                      Max value of B = 16'hFFFF
//----%%                    - Rx sampling rate = Clock freq / (B + 1)
//----%%                    - Tx baud clock rate = Clock freq / ((B + 1) * 8)
//----%%
//----%% Tested on        : Xilinx Zybo Z7-20 (XC7-Z020-CLG400-1), Artix-7 FPGA based board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Jan 2024
//----%% Notes            : Timing verified up to 200 MHz core clock.
//----%%
//----%% Copyright        : Open-source license, see LICENSE
//----%%                                                                                              
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###############################################################################################################################
//                                               B A U D   G E N E R A T O R                                         
//###############################################################################################################################
module baud_gen (
                   // Clock and Reset
                   input  logic           clk            ,        // Clock
                   input  logic           tx_rst         ,        // TX reset; Active-low Asynchronous
                   input  logic           rx_rst         ,        // RX reset; Active-low Asynchronous      
                   
                   // Baud clock control                   
                   input  logic [15 : 0]  i_baudrate     ,        // Baud rate
                   input  logic           i_tx_en        ,        // UART TX baud clock enable
                   input  logic           i_rx_en        ,        // UART RX baud clock enable
                   input  logic           i_tx_ready     ,        // UART TX ready
                   input  logic           i_rx_ready     ,        // UART RX ready
                   output logic           o_rx_en        ,        // UART RX enable
                   
                   // Baud clock pulses
                   output logic           o_tx_baud_clk  ,        // Baud clock pulse for UART TX
                   output logic           o_rx_baud_clk  ,        // Baud clock pulse for UART RX

                   // Status signals
                   output logic           o_tx_state     ,        // State of UART TX (enabled/disabled)
                   output logic           o_rx_state              // State of UART RX (enabled/disabled)       
                ) ;  

/*-------------------------------------------------------------------------------------------------------------------------------
   Internal Registers/Signals
-------------------------------------------------------------------------------------------------------------------------------*/
logic          tx_en, rx_en             ;    // TX/RX baud clock internal enable
logic          is_tx_en_rg, is_rx_en_rg ;    // TX/RX baud clock state
logic [18 : 0] tx_count_rg              ;    // Counter for UART TX baud clock
logic [15 : 0] rx_count_rg              ;    // Counter for UART RX baud clock
logic [15 : 0] rx_baudcount             ;    // Rx baud count
logic [18 : 0] tx_baudcount             ;    // Tx baud count

/*-------------------------------------------------------------------------------------------------------------------------------
   Synchronous logic to generate baud clock pulse for UART TX
-------------------------------------------------------------------------------------------------------------------------------*/
always @ (posedge clk or negedge tx_rst) begin   
   // Reset
   if (!tx_rst) begin
      is_tx_en_rg   <= 1'b0 ;
      o_tx_baud_clk <= 1'b0 ;
      tx_count_rg   <= 0    ;
   end
   // Out of Reset
   else begin
      // TX disabled: disable clock pulses, reset counters...
      if (!tx_en) begin
         o_tx_baud_clk <= 1'b0 ;
         tx_count_rg   <= 0    ;
         is_tx_en_rg   <= 1'b0 ;  // TX baud clock is in disabled state     
      end
      // TX enabled
      else begin
         is_tx_en_rg <= 1'b1 ;  // TX baud clock is in enabled state
         if (tx_count_rg == tx_baudcount) begin
            o_tx_baud_clk <= 1'b1            ;  // Assert the pulse
            tx_count_rg   <= 0               ;
         end      
         else begin
            o_tx_baud_clk <= 1'b0            ;  // De-assert the pulse after one cycle 
            tx_count_rg   <= tx_count_rg + 1 ;
         end
      end
   end
end

// Generate TX baud clock enable internally...
assign tx_en = i_tx_en ? 1'b1 : (is_tx_en_rg && !i_tx_ready) ;

/*-------------------------------------------------------------------------------------------------------------------------------
   Synchronous logic to generate baud clock pulse for UART RX
-------------------------------------------------------------------------------------------------------------------------------*/
always @ (posedge clk or negedge rx_rst) begin   
   // Reset
   if (!rx_rst) begin
      is_rx_en_rg   <= 1'b0 ;
      o_rx_baud_clk <= 1'b0 ;
      rx_count_rg   <= 0    ;
   end
   // Out of Reset
   else begin
      // RX disabled: disable clock pulses, reset counters...
      if (!rx_en) begin
         o_rx_baud_clk <= 1'b0 ;
         rx_count_rg   <= 0    ;
         is_rx_en_rg   <= 1'b0 ;  // RX baud clock is in disabled state   
      end
      // RX enabled
      else begin
         is_rx_en_rg <= 1'b1 ;  // RX baud clock is in enabled state
         if (rx_count_rg == rx_baudcount) begin  // Sampling at x8
            o_rx_baud_clk <= 1'b1            ;   // Assert the pulse
            rx_count_rg   <= 0               ;
         end
         else begin
            o_rx_baud_clk <= 1'b0            ;  // De-assert the pulse after one cycle 
            rx_count_rg   <= rx_count_rg + 1 ; 
         end
      end
   end
end

// Baud counts
assign rx_baudcount = i_baudrate ;
assign tx_baudcount = (i_baudrate << 3) + 19'd7 ;

// Generate TX baud clock enable internally...
assign rx_en = i_rx_en ? 1'b1 : (is_rx_en_rg && !i_rx_ready) ;

// RX enable
assign o_rx_en = rx_en ;

// Status outputs
assign o_tx_state = is_tx_en_rg ;
assign o_rx_state = is_rx_en_rg ;

endmodule

//###############################################################################################################################
//                                               B A U D   G E N E R A T O R                                         
//###############################################################################################################################