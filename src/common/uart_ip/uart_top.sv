//     %%%%%%%%%#      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//  %%%%%%%%%%%%%%%%%  ------------------------------------------------------------------------------------------------------------------------------
// %%%%%%%%%%%%%%%%%%%% %
// %%%%%%%%%%%%%%%%%%%% %%
//    %% %%%%%%%%%%%%%%%%%%
//        % %%%%%%%%%%%%%%%                 //---- O P E N - S O U R C E ----//
//           %%%%%%%%%%%%%%                 ╔═══╦╗──────────────╔╗──╔╗
//           %%%%%%%%%%%%%      %%          ║╔═╗║║──────────────║║──║║
//           %%%%%%%%%%%       %%%%         ║║─╚╣╚═╦╦══╦╗╔╦╗╔╦═╗║║╔╗║║──╔══╦══╦╦══╗
//          %%%%%%%%%%        %%%%%%        ║║─╔╣╔╗╠╣╔╗║╚╝║║║║╔╗╣╚╝╝║║─╔╣╔╗║╔╗╠╣╔═╝ \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
//         %%%%%%%    %%%%%%%%%%%%*%%%      ║╚═╝║║║║║╚╝║║║║╚╝║║║║╔╗╗║╚═╝║╚╝║╚╝║║╚═╗ /////////////////////////////////////////////////////////////////
//        %%%%% %%%%%%%%%%%%%%%%%%%%%%%     ╚═══╩╝╚╩╣╔═╩╩╩╩══╩╝╚╩╝╚╝╚═══╩══╩═╗╠╩══╝
//       %%%%*%%%%%%%%%%%%%  %%%%%%%%%      ────────║║─────────────────────╔═╝║
//       %%%%%%%%%%%%%%%%%%%    %%%%%%%%%   ────────╚╝─────────────────────╚══╝
//       %%%%%%%%%%%%%%%%                   c h i p m u n k l o g i c . c o m
//       %%%%%%%%%%%%%%
//         %%%%%%%%%
//           %%%%%%%%%%%%%%%%  ----------------------------------------------------------------------------------------------------------------------
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% 
//----%% File Name        : uart_top.sv
//----%% Module Name      : UART Controller - Top Module                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic™ , https://chipmunklogic.com
//----%%
//----%% Description      : UART Controller IP Core provides a simple asynchronous serial interface for data transmission 
//----%%                    and reception. UART signalling is implemented at the serial interface.
//----%%
//----%%                    FEATURES
//----%%                    --------
//----%%                    - Full duplex, 8-bit data, x8 sampling at RX, sampling at middle.
//----%%                    - Configurable baud rate, B.
//----%%                      Computing B:
//----%%                      Desired baud rate  = Clock freq / ((B + 1) * 8)
//----%%                      ==> B = INT((Clock freq / Desired baud rate) / 8) - 1  // Rounding off to nearest integer...
//----%%                      Min value of B = 1 which gives max. baud rate = F/16
//----%%                      Max value of B = 16'hFFFF
//----%%                    - Configurable parity mode: 
//----%%                         - 2'bx0 = No parity bit
//----%%                         - 2'b01 = Odd parity bit
//----%%                         - 2'b11 = Even parity bit
//----%%                    - Configurable frame mode:
//----%%                         - 1'b0 = 1 Start bit and 1 Stop bit
//----%%                         - 1'b1 = 1 Start bit and 2 Stop bits
//----%%                    - Data packet format: <START><d0><d1><d2><d3><d4><d5><d6><d7><PARITY><STOP1><STOP2>
//----%%                    - Max. baud rate for reliable use = 1/16 core clock freq
//----%%                      Max. permissible baud clock error = +/- 5.0 % at receiver
//----%%                    - Framing error flagging at Receiver: 
//----%%                         - Flags if any of the stop bits is incorrectly received as '0'.
//----%%                         - The data is still buffered at the output if framing error happens; The core will try to re-sync
//----%%                           to next start bit 1->0 always.
//----%%                           Frame error may be due to break character, in this case the core will re-sync
//----%%                           correctly to the next frame.
//----%%                           If Frame error is due to baud rate mismatch/noise/incompatible packet format, 
//----%%                           TX-RX may have gone out of sync. 
//----%%                           The comm. link may need to be explicitly re-sync by the controlling SW/system by corrective action.
//----%%                    - Parity error flagging at Receiver:
//----%%                         - Flags if parity bit is sampled as wrong, the data could be corrupted.
//----%%                         - The data is still buffered at the output.
//----%%                    - Supports sending and receiving break frame:
//----%%                      If parity disabled : 10 bits of '0' + 1 or 2 stop bits
//----%%                      If parity enabled  : 11 bits of '0' + 1 or 2 stop bits
//----%%                    - Supports internal loopback for testing purpose.
//----%%                    - Valid-ready handshaking I/F for the ease of FIFO integration at input (TX) and output (RX).
//----%%
//----%% Tested on        : Xilinx Zybo Z7-20 (XC7-Z020-CLG400-1), Artix-7 FPGA based board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Feb-2024
//----%% Notes            : Timing verified up to 200 MHz core clock, and tested on board @baud rates 300-115200 bps
//----%%
//----%% IP User Guide    : https://chipmunklogic.com/wp-content/uploads/ip_cores/pdfs/uart_controller_v1_2_ug.pdf
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                    U A R T   C O N T R O L L E R   -   T O P                                       
//###################################################################################################################################################
module uart_top (
                   /* Clock and Reset */
                   input  logic         clk            ,        // Clock
                   input  logic         rstn           ,        // Active-low Asynchronous Reset   

                   /* Serial Interface */
                   output logic         o_tx           ,        // Serial data out, TX
                   input  logic         i_rx           ,        // Serial data in, RX              
                   
                   /* Control Signals */    
                   input  logic [15:0]  i_baudrate     ,        // Baud rate
                   input  logic [1:0]   i_parity_mode  ,        // Parity mode
                   input  logic         i_frame_mode   ,        // Frame mode 
                   input  logic         i_lpbk_mode_en ,        // Loopback mode enable
                   input  logic         i_tx_break_en  ,        // Enable to send break frame on TX
                   input  logic         i_tx_en        ,        // UART TX (Transmitter) enable
                   input  logic         i_rx_en        ,        // UART RX (Receiver) enable 
                   input  logic         i_tx_rst       ,        // UART TX reset
                   input  logic         i_rx_rst       ,        // UART RX reset                
                   
                   /* UART TX Data Interface */    
                   input  logic [7:0]   i_data         ,        // Parallel data input
                   input  logic         i_data_valid   ,        // Input data valid
                   output logic         o_ready        ,        // Ready signal from UART TX 
                   
                   /* UART RX Data Interface */ 
                   output logic [7:0]   o_data         ,        // Parallel data output
                   output logic         o_data_valid   ,        // Output data valid
                   input  logic         i_ready        ,        // Ready signal to UART RX
                   
                   /* Status Signals */   
                   output logic         o_tx_state     ,        // State of UART TX (enabled/disabled)
                   output logic         o_rx_state     ,        // State of UART RX (enabled/disabled)
                   output logic         o_rx_break     ,        // Flags break frame received on RX
                   output logic         o_parity_err   ,        // Parity error flag
                   output logic         o_frame_err             // Frame error flag                                            
);


/*---------------------------------------------------------------------------------------------------------------------------------------------------
   Internal Registers/Signals
---------------------------------------------------------------------------------------------------------------------------------------------------*/

// Connection between Baud Generator & UART TX 
logic tx_baud_clk ;        // Baud clock pulse from Baud Generator to UART TX
logic tx_ready    ;        // TX ready

// Connection between Baud Generator & UART RX 
logic rx_baud_clk ;        // Baud clock pulse from Baud Generator to UART RX
logic rx_ready    ;        // RX ready
logic rx_en       ;        // RX enable

// Other signals
logic tx          ;        // TX data to Serial I/F
logic rx          ;        // RX data from Serial I/F or loopback
logic irx_sync    ;        // Serial data input synchronized to the core-clock domain
logic tx_rst_sync ;        // Synchronized reset to TX
logic rx_rst_sync ;        // Synchronized reset to RX


/*---------------------------------------------------------------------------------------------------------------------------------------------------
   Sub-modules Instantations
---------------------------------------------------------------------------------------------------------------------------------------------------*/

// Baud Generator
baud_gen inst_baud_gen    (
                        .clk           ( clk  )                  ,
                        .tx_rst        ( tx_rst_sync )           ,
                        .rx_rst        ( rx_rst_sync )           ,
         
                        .i_baudrate    ( i_baudrate  )           ,
                        .i_tx_en       ( i_tx_en     )           ,
                        .i_rx_en       ( i_rx_en     )           ,    
                        .i_tx_ready    ( tx_ready    )           ,    
                        .i_rx_ready    ( rx_ready    )           , 
                        .o_rx_en       ( rx_en       )           ,  
         
                        .o_tx_baud_clk ( tx_baud_clk )           ,
                        .o_rx_baud_clk ( rx_baud_clk )           ,

                        .o_tx_state    ( o_tx_state )            ,
                        .o_rx_state    ( o_rx_state )
                     ) ;

// UART TX   
uart_tx inst_uart_tx      (
                        .clk           ( clk            )        ,
                        .rstn          ( tx_rst_sync    )        , 
        
                        .i_baud_clk    ( tx_baud_clk    )        ,

                        .i_parity_mode ( i_parity_mode  )        ,
                        .i_frame_mode  ( i_frame_mode   )        ,
                        .i_break_en    ( i_tx_break_en  )        ,

                        .i_data        ( i_data         )        ,
                        .i_data_valid  ( i_data_valid   )        ,
                        .o_ready       ( tx_ready       )        ,

                        .o_tx          ( tx             )     
                     ) ;

// UART RX   
uart_rx inst_uart_rx      (
                        .clk           ( clk            )        ,
                        .rstn          ( rx_rst_sync    )        , 
        
                        .i_baud_clk    ( rx_baud_clk    )        ,
                        
                        .i_rx_en       ( rx_en          )        ,
                        .i_parity_mode ( i_parity_mode  )        ,
                        .i_frame_mode  ( i_frame_mode   )        ,
                        
                        .i_rx          ( irx_sync       )        ,

                        .o_data        ( o_data         )        ,
                        .o_data_valid  ( o_data_valid   )        ,
                        .i_ready       ( i_ready        )        ,
                        
                        .o_rx_ready    ( rx_ready       )        ,
                        .o_break       ( o_rx_break     )        ,
                        .o_parity_err  ( o_parity_err   )        ,
                        .o_frame_err   ( o_frame_err    )   
                     ) ;

// RX serial data synchronizer for CDC
cdc_sync inst_rx_sync     (
                        .clk         ( clk      ) ,
                        .rstn        ( rstn     ) ,
                        .i_sig       ( rx       ) ,
                        .o_sig_sync  ( irx_sync )
                     ) ;

// Reset synchronizer for TX
areset_sync inst_tx_rst_sync (
                         .clk         (clk)              ,
                         .i_rst_async (~i_tx_rst & rstn) ,
                         .o_rst_sync  (tx_rst_sync)

                      ) ;

// Reset synchronizer for RX
areset_sync inst_rx_rst_sync (
                         .clk         (clk)              ,
                         .i_rst_async (~i_rx_rst & rstn) ,
                         .o_rst_sync  (rx_rst_sync)

                      ) ;

// Loopback
// Loopback is expected to be switched after disabling TX and RX to avoid glitches/broken frames...
assign rx = i_lpbk_mode_en?  tx : i_rx ;

// Outputs
assign o_tx    = tx       ;
assign o_ready = tx_ready ;

endmodule

//###################################################################################################################################################
//                                                    U A R T   C O N T R O L L E R   -   T O P                                       
//###################################################################################################################################################