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
//----%% File Name        : uart_tx.sv
//----%% Module Name      : UART Transmitter                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : UART Transmitter to read a parallel data and send it out serially.
//----%%
//----%%                    FEATURES
//----%%                    --------
//----%%                    - Run-time configurable parity mode   : "00" - No parity bit
//----%%                                                            "01" - Odd parity bit
//----%%                                                            "11" - Even parity bit
//----%%                    - Run-time configurable frame mode    : '0'  - 1 Stop bit
//----%%                                                            '1'  - 2 Stop bits
//----%%                    - Data width = 8 bits.
//----%%                    - Supports sending break frame:
//----%%                      If parity enabled  : 10 bits of '0' + 1 or 2 stop bits
//----%%                      If parity disabled : 11 bits of '0' + 1 or 2 stop bits
//----%%                    - Max baud clock rate = 1/4 system clock freq.
//----%%                    - Valid-ready handshaking for ease of FIFO integration at input.
//----%%                    - Supports sending break frames.
//----%%
//----%% Tested on        : Xilinx Zybo Z7-20 (XC7-Z020-CLG400-1), Artix-7 FPGA based board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Jan-2024
//----%% Notes            : Timing verified up to 200 MHz system clock.
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###############################################################################################################################
//                                               U A R T   T R A N S M I T T E R                                         
//###############################################################################################################################
module uart_tx  (
                   input  logic           clk            ,        // Clock
                   input  logic           rstn           ,        // Active-low Asynchronous Reset

                   input  logic           i_baud_clk     ,        // Baud clock                  
                   
                   /* Control Signals */                   
                   input  logic [1  : 0]  i_parity_mode  ,        // Parity mode
                   input  logic           i_frame_mode   ,        // Frame mode   
                   input  logic           i_break_en     ,        // Enable to send break frame                                  
                   
                   /* Parallel Data */    
                   input  logic [7 :  0]  i_data         ,        // Parallel data input
                   input  logic           i_data_valid   ,        // Input data valid
                   output logic           o_ready        ,        // Ready to accept data  

                   /* Serial Data */
                   output logic           o_tx                    // Serial data output            
                ) ;

/*-------------------------------------------------------------------------------------------------------------------------------
   Typedefs
-------------------------------------------------------------------------------------------------------------------------------*/
// TX FSM state
typedef enum logic [5:0] { 
   IDLE    = 6'h01,  // Idle State
   START   = 6'h02,  // Send Start State
   DATA    = 6'h04,  // Send Data State
   PARITY  = 6'h08,  // Send Parity State
   BREAK   = 6'h10,  // Send BREAK State
   STOP    = 6'h20   // Send Stop State
}  tx_state ;

/*-------------------------------------------------------------------------------------------------------------------------------
   Internal Registers/Signals
-------------------------------------------------------------------------------------------------------------------------------*/
tx_state      state_rg      ;        // State Register

logic [7 : 0] data_rg       ;        // Data buffer
logic         parity_rg     ;        // Parity bit register
logic         ready_rg      ;        // Ready register
logic         break_flag_rg ;        // Flags break enabled
logic [2 : 0] tx_count_rg   ;        // Data counter
logic         stop_count_rg ;        // Stop bit counter

/*-------------------------------------------------------------------------------------------------------------------------------
   Synchronous logic of UART Tx
-------------------------------------------------------------------------------------------------------------------------------*/
always @ (posedge clk or negedge rstn) begin
   
   // Reset
   if (!rstn) begin      
      // Output Ports
      o_tx          <= 1'b1 ;

      // Internal Registers/Signals
      state_rg      <= IDLE ;
      data_rg       <= '0   ;
      parity_rg     <= 1'b0 ;
      ready_rg      <= 1'b0 ;
      break_flag_rg <= 1'b0 ;
      tx_count_rg   <= 0    ;
      stop_count_rg <= 0    ;
   end

   // Out of Reset
   else begin 

      // FSM   
      case (state_rg)
         
         /*----------------------------------------------------------------------------------------------------------------------
            Idle State
         ------------------------------------------------------------------------------------------------------------------------
            - State in which UART Tx waits for a valid parallel data input.
            - Buffer the parallel data and moves to START State from here.
         ----------------------------------------------------------------------------------------------------------------------*/         
         IDLE       : begin
                         // IDLE state of TX line
                         o_tx <= 1'b1 ;

                         // Ready to accept data
                         ready_rg <= 1'b1 ;
                         
                         // Buffer the input data
                         // If break enabled, buffer all 0s
                         if (i_data_valid & ready_rg) begin
                            data_rg       <= i_break_en ? 8'h00 : i_data ;
                            break_flag_rg <= i_break_en ;
                            ready_rg      <= 1'b0   ;
                            state_rg      <= START  ;
                         end
                      end

         /*----------------------------------------------------------------------------------------------------------------------
            Send Start State
         ------------------------------------------------------------------------------------------------------------------------
            - State in which Start bit is sent.
            - Moves to DATA State from here.
         ----------------------------------------------------------------------------------------------------------------------*/
         START      : begin                         
                         if (i_baud_clk) begin                         
                            o_tx     <= 1'b0 ;
                            state_rg <= DATA ;
                         end
                      end
         
         /*----------------------------------------------------------------------------------------------------------------------
            Send Data State
         ------------------------------------------------------------------------------------------------------------------------
            - State in which data bits are sent serially.
            - Moves to PARITY/BREAK/STOP State from here based on parity mode/break configuration.
         ----------------------------------------------------------------------------------------------------------------------*/
         DATA       : begin
                         if (i_baud_clk) begin                            
                            // Increment data counter                            
                            tx_count_rg <= tx_count_rg + 1 ;
                            
                            // Last data bit
                            if (tx_count_rg == 7) begin 

                               // Reset data counter
                               tx_count_rg <= 0      ;        
                               
                               // Parity enabled or not                               
                               if (i_parity_mode [0]) begin
                                  state_rg <= PARITY ;        // Proceed to send parity bit
                               end
                               else begin
                                  state_rg <= break_flag_rg ? BREAK : STOP ;   // Proceed to send STOP bit iff no break enabled                               
                               end

                            end

                            // Serial data output
                            o_tx <= data_rg [tx_count_rg] ; 
                         end 
                      end 
         
         /*----------------------------------------------------------------------------------------------------------------------
            Send Parity State
         ------------------------------------------------------------------------------------------------------------------------
            - State in which parity bit is sent.
            - Moves to BREAK/STOP State from here.
         ----------------------------------------------------------------------------------------------------------------------*/
         PARITY     : begin                         
                         if (i_baud_clk) begin
                            o_tx     <= break_flag_rg ? 1'b0 : parity_rg ;  // Should send 0 always if break is enabled
                            state_rg <= break_flag_rg ? BREAK : STOP     ;  // Proceed to send STOP bit iff no break enabled                            
                         end
                      end

         /*----------------------------------------------------------------------------------------------------------------------
            Send BREAK State
         ------------------------------------------------------------------------------------------------------------------------
            - State in which break bit is sent.
            - Sends 0 at the place of stop bit, which should trigger a frame error at the receiver end.
            - Moves to STOP State from here to send Stop bit, so that the receiver can re-sync to the next frame.
         ----------------------------------------------------------------------------------------------------------------------*/
         BREAK      : begin                         
                         if (i_baud_clk) begin                         
                            o_tx     <= 1'b0 ;
                            state_rg <= STOP ;
                         end
                      end

         /*----------------------------------------------------------------------------------------------------------------------
            Send Stop State
         ------------------------------------------------------------------------------------------------------------------------
            - State in which Stop bit is sent.
            - No. of Stop bits sent depend on frame mode configuration.
            - Moves to IDLE State from here.
         ----------------------------------------------------------------------------------------------------------------------*/
         STOP       : begin                         
                         if (i_baud_clk) begin
                            // Increment Stop bit counter                         
                            stop_count_rg <= stop_count_rg + 1 ; 

                            // Last Stop bit
                            if (stop_count_rg == i_frame_mode) begin
                               stop_count_rg <= 0    ;
                               state_rg      <= IDLE ;                           
                            end   

                            // Stop bit   
                            o_tx <= 1'b1 ;
                         end
                      end

         default    : ;

      endcase
      
      // Parity bit computation
      parity_rg <= i_parity_mode [1]  ?        // Parity mode
                   (^ data_rg   )     :        // Even parity bit  
                   (~ (^ data_rg))    ;        // Odd parity bit

   end

end

/*-------------------------------------------------------------------------------------------------------------------------------
   Continuous Assignments
-------------------------------------------------------------------------------------------------------------------------------*/
assign o_ready = ready_rg ;

endmodule

//###############################################################################################################################
//                                               U A R T   T R A N S M I T T E R                                         
//###############################################################################################################################