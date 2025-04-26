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
//----%% File Name        : uart_rx.sv
//----%% Module Name      : UART Receiver                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : UART Receiver to receive serial data and send it out parallelly.
//----%%
//----%%                    FEATURES
//----%%                    --------
//----%%                    - Run-time configurable parity mode   : "00" - No parity bit
//----%%                                                            "01" - Odd parity bit
//----%%                                                            "11" - Even parity bit
//----%%                    - Run-time configurable frame mode    : '0'  - 1 Stop bit
//----%%                                                            '1'  - 2 Stop bits
//----%%                    - Data width = 8 bits, Max. baud clock rate = 1/4 system clock freq, sampling rate = x8.
//----%%                    - Expected idle state of the RX line = 1'b1, start bit detection always on the fall edge.
//----%%                    - Framing error flagging : if any of the stop bits is sampled as '0'.
//----%%                    - Parity error flagging  : if parity sampled is wrong.
//----%%                    - Valid-ready handshaking for ease of FIFO integration at output.
//----%%                    - Supports receiving break frames.
//----%%
//----%% Tested on        : Xilinx Zybo Z7-20 (XC7-Z020-CLG400-1), Artix-7 FPGA based board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Jan-2024
//----%% Notes            : Timing verified up to 200 MHz system clock.
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###############################################################################################################################
//                                               U A R T   R E C E I V E R                                        
//###############################################################################################################################
module uart_rx  (
                   input  logic           clk            ,        // Clock
                   input  logic           rstn           ,        // Active-low Asynchronous Reset 

                   input  logic           i_baud_clk     ,        // Baud clock                 
                   
                   /* Control Signals */    
                   input  logic           i_rx_en        ,        // Rx enable
                   input  logic [1  : 0]  i_parity_mode  ,        // Parity mode
                   input  logic           i_frame_mode   ,        // Frame mode                             
                   
                   /* Serial Data */
                   input logic            i_rx           ,        // Serial data input

                   /* Parallel Data */     
                   output logic [7 : 0]   o_data         ,        // Parallel data output
                   output logic           o_data_valid   ,        // Output data valid
                   input  logic           i_ready        ,        // Ready to send data
                   
                   /* Status Signals */    
                   output logic           o_rx_ready     ,        // Rx ready/busy to accept new frame...
                   output logic           o_break        ,        // Break frame received flag
                   output logic           o_parity_err   ,        // Parity error flag
                   output logic           o_frame_err             // Frame error flag        
                ) ;

/*-------------------------------------------------------------------------------------------------------------------------------
   Typedefs
-------------------------------------------------------------------------------------------------------------------------------*/
// TX FSM state
typedef enum logic [5:0] { 
   IDLE    = 6'h01,  // Idle State
   DATA    = 6'h02,  // Receive Data State
   PARITY  = 6'h04,  // Receive Parity State
   STOP_P  = 6'h08,  // Receive Initial Stop State
   STOP_F  = 6'h10,  // Receive Final Stop State
   BUFF    = 6'h20   // Buffer Data State
}  rx_state ;

/*-------------------------------------------------------------------------------------------------------------------------------
   Internal Registers/Signals
-------------------------------------------------------------------------------------------------------------------------------*/
rx_state      state_rg               ;        // State Register

// Frame specific
logic         rx_d1_rg               ;        // Rx delayed by one cycle
logic         is_rx_1_to_0_edge      ;        // Rx falling edge flag
logic         is_frame_sync_rg       ;        // Frame synchronization flag
logic         start_bit_rg           ;        // Start bit sampled
logic         parity_bit_rg          ;        // Parity bit sampled
logic         stop_bit_rg            ;        // Stop bit sampled
logic [7 : 0] data_rg                ;        // Data register
logic         frame_err_rg           ;        // Frame error register
logic         parity_err_rg          ;        // Parity error register

// Counters
logic [2 : 0] start_sample_count_rg  ;        // Counter to count Start bit samples   
logic [2 : 0] data_sample_count_rg   ;        // Counter to count Data bit samples
logic [2 : 0] parity_sample_count_rg ;        // Counter to count Parity bit samples
logic [2 : 0] stop_sample_count_rg   ;        // Counter to count Stop bit samples
logic [2 : 0] data_count_rg          ;        // Counter to count Data bits sampled

// Flags
logic         stop_flag_rg           ;        // To flag if stop bit sampling failed

/*-------------------------------------------------------------------------------------------------------------------------------
   Synchronous logic of UART Rx
-------------------------------------------------------------------------------------------------------------------------------*/
always @ (posedge clk or negedge rstn) begin
   
   // Reset
   if (!rstn) begin      
      // Output Ports
      o_data                 <= '0    ;
      o_data_valid           <= 1'b0  ;
      o_break                <= 1'b0  ;
      o_parity_err           <= 1'b0  ; 
      o_frame_err            <= 1'b0  ;     
 
      // Internal Registers/Signals 
      state_rg               <= IDLE  ;
      
      rx_d1_rg               <= 1'b0  ;
      is_frame_sync_rg       <= 1'b0  ;
      start_bit_rg           <= 1'b1  ;
      parity_bit_rg          <= 1'b0  ;
      stop_bit_rg            <= 1'b0  ;
      data_rg                <= '0    ; 
      frame_err_rg           <= 1'b0  ;  
      parity_err_rg          <= 1'b0  ;   
 
      start_sample_count_rg  <=  0    ;
      data_sample_count_rg   <=  0    ;
      parity_sample_count_rg <=  0    ;
      stop_sample_count_rg   <=  0    ;
      data_count_rg          <=  0    ;

      stop_flag_rg           <= 1'b0  ;
   end

   // Out of Reset
   else begin
      
      // De-assertion of data valid      
      if (i_ready) begin
         o_data_valid <= 1'b0 ;      	
      end
      
      // One baud clock cycle delayed version of Rx when Rx enabled...      
      if (!i_rx_en) begin
         rx_d1_rg <= 1'b0 ;
      end
      else if (i_baud_clk) begin
         rx_d1_rg <= i_rx ;
      end      

      // FSM
      case (state_rg)
         
         /*----------------------------------------------------------------------------------------------------------------------
            Idle State
         ------------------------------------------------------------------------------------------------------------------------
            - Waits in this state for idle -> Start bit transition.
            - Triggers start bit sampler on first 1->0 transition.
            - Moves to DATA State if Start bit is sampled successfully.  
         ----------------------------------------------------------------------------------------------------------------------*/         
         IDLE       : begin 
                         if (i_baud_clk && i_rx_en) begin   
                                                                         
                            // Frame synchronized, keep sampling            
                            if (is_frame_sync_rg) begin
                               start_sample_count_rg <= start_sample_count_rg + 1 ; 
                            end
                            // Frame not synchronized; looking for 1->0 transition at Rx...
                            // if the RX line is idle at 0000000.... or 1111111...., the frame is ignored...
                            // 1->0 is identified as the possible Start bit transition... 
                            else if (is_rx_1_to_0_edge) begin
                               is_frame_sync_rg      <= 1'b1                      ;    // Frame synchronized
                               start_sample_count_rg <= start_sample_count_rg + 1 ; 
                            end
                            
                            // Sampling at middle
                            if (start_sample_count_rg == 3) begin
                               start_bit_rg     <= i_rx ; 
                               // If Start bit detected in the middle, keep frame sync, else lost sync...
                               is_frame_sync_rg      <= i_rx ? 1'b0 : is_frame_sync_rg ; 
                               start_sample_count_rg <= i_rx ? 0    : start_sample_count_rg + 1 ;                       	
                            end
                            
                            // Last sample
                            if (start_sample_count_rg == 7) begin   
                               if (start_bit_rg == 1'b0) begin                        	
                                  state_rg <= DATA ;    // Start bit detected
                               end                               
                            end                                                        	

                         end
                      end

         /*----------------------------------------------------------------------------------------------------------------------
            Receive Data State
         ------------------------------------------------------------------------------------------------------------------------
            - Samples the 8 data bits in this state.
            - Moves to PARITY/STOP_P/STOP_F State based on configuration. 
         ----------------------------------------------------------------------------------------------------------------------*/
         DATA       : begin                         
                         if (i_baud_clk) begin                            
                            // Increment sample counter
                            data_sample_count_rg <= data_sample_count_rg + 1 ;
                            
                            // Sampling at middle
                            if (data_sample_count_rg == 3) begin
                               data_rg [data_count_rg] <= i_rx ;                            	
                            end 
                            
                            // Last sample
                            if (data_sample_count_rg == 7) begin                               
                               // Increment data counter                               
                               data_count_rg <= data_count_rg + 1 ;
                               
                               // Last data bit
                               if (data_count_rg == 7) begin                    
                                  
                                  // Next state deduction
                                  if (i_parity_mode [0]) begin
                                     state_rg     <= PARITY ;    // Parity                                 	
                                  end
                                  else if (!i_frame_mode) begin                                                                       	
                                     state_rg     <= STOP_F ;    // No-parity, 1 Stop bit                                 	
                                  end
                                  else begin
                                     state_rg     <= STOP_P ;    // No parity, 2 Stop bits                                  	
                                  end
                                  
                                  if (!i_frame_mode) begin
                                     stop_flag_rg <= 1'b0   ;    // One-Stop-bit mode transaction, so flag this as successful
                                  end

                               end

                            end
                         end
                      end

         /*----------------------------------------------------------------------------------------------------------------------
            Receive Parity State
         ------------------------------------------------------------------------------------------------------------------------
            - Samples Parity bit in this state.
            - Moves to STOP_P/STOP_F State from here based on configuration. 
         ----------------------------------------------------------------------------------------------------------------------*/
         PARITY     : begin                         
                         if (i_baud_clk) begin                            
                            // Increment sample counter                            
                            parity_sample_count_rg <= parity_sample_count_rg + 1 ;
                            
                            // Sampling at middle
                            if (parity_sample_count_rg == 3) begin
                               parity_bit_rg <= i_rx ;                           	
                            end
                            
                            // Last sample
                            if (parity_sample_count_rg == 7) begin

                               // Next state deduction
                               if (!i_frame_mode) begin                                                                 	
                                  state_rg     <= STOP_F ;        // One-Stop-bit mode transaction                                 	
                               end
                               else begin
                                  state_rg     <= STOP_P ;        // Two-Stop-bit mode transaction                                 	
                               end

                            end
                         end
                      end

         /*----------------------------------------------------------------------------------------------------------------------
            Receive Initial Stop State
         ------------------------------------------------------------------------------------------------------------------------
            - Samples the first Stop bit in case of Two-Stop-bits mode transactions.
            - Moves to STOP_F State from here.
         ----------------------------------------------------------------------------------------------------------------------*/
         STOP_P     : begin
                         if (i_baud_clk) begin                            
                            // Increment sample counter                            
                            stop_sample_count_rg <= stop_sample_count_rg + 1 ;
                            
                            // Sampling at middle
                            if (stop_sample_count_rg == 3) begin
                               stop_flag_rg <= ~ i_rx ;        // Flag if Stop bit was successfully sampled or not                               
                            end
                            
                            // Last sample
                            if (stop_sample_count_rg == 7) begin                               
                               state_rg     <= STOP_F ;
                            end
                         end
                      end
         
         /*----------------------------------------------------------------------------------------------------------------------
            Receive Final Stop State
         ------------------------------------------------------------------------------------------------------------------------
            - Samples the second/final Stop bit.
            - Moves to BUFF State from here.
         ----------------------------------------------------------------------------------------------------------------------*/
         STOP_F     : begin                         
                         if (i_baud_clk) begin                            
                            // Increment sample counter
                            stop_sample_count_rg <= stop_sample_count_rg + 1 ;
                            
                            // Sampling at middle
                            if (stop_sample_count_rg == 3) begin
                               stop_bit_rg          <= i_rx ;    // Stop bit
                               stop_sample_count_rg <= 0    ;    // Reset sample counter                      

                               if (i_rx == 1'b0) begin
                                  frame_err_rg <= 1'b1                ;        // Stop bit was not sampled; Framing error!                                                               	
                               end                                                                                                                          	
                               else begin
                                  frame_err_rg <= 1'b0 | stop_flag_rg ;        // Final Stop bit and Initial Stop bit sampling analysed.                                                                       	
                               end
                               
                               // Finished one frame reception
                               is_frame_sync_rg  <= 1'b0 ;       // De-assert Frame synchronization
                               state_rg          <= BUFF ;
                            end
                         end
                      end

         /*----------------------------------------------------------------------------------------------------------------------
            Buffer Data State
         ------------------------------------------------------------------------------------------------------------------------
            - Buffers the sampled data, parity error flag to output.            
            - Moves Idle State from here.
         ----------------------------------------------------------------------------------------------------------------------*/
         BUFF       : begin                         
                         // Buffer valid data and status to output...                        
                         o_data       <= data_rg ;
                         o_break      <= (!i_frame_mode) ?
                                         (frame_err_rg && data_rg == 8'h00 && parity_bit_rg == 1'b0) :  // 1 stop bit
                                         (stop_flag_rg && data_rg == 8'h00 && parity_bit_rg == 1'b0) ;  // For 2 stop bits, it's considered break frame iff the frame error happened in the first stop bit
                         o_parity_err <= parity_err_rg ; 
                         o_frame_err  <= frame_err_rg  ;
                         o_data_valid <= 1'b1          ;                         
                         
                         // Ready to receive the next frame
                         parity_bit_rg <= 1'b0 ;
                         state_rg      <= IDLE ;
                      end

         default    : ;

      endcase

      /* Parity error flag computation */
      if (i_parity_mode [0]) begin
         parity_err_rg <= i_parity_mode [1]                   ?
                          ((~ (^ data_rg)) == parity_bit_rg ) :        // Even parity check  
                          ((^ data_rg)     == parity_bit_rg ) ;        // Odd parity check 

      end
      else begin
         parity_err_rg <= 1'b0 ;
      end

   end

end

/*-------------------------------------------------------------------------------------------------------------------------------
   Continuous Assignments
-------------------------------------------------------------------------------------------------------------------------------*/
assign is_rx_1_to_0_edge = (rx_d1_rg && !i_rx) ;  // ``\__ detected on Rx

// Output status
assign o_rx_ready        = ~is_frame_sync_rg ;

endmodule

//###############################################################################################################################
//                                               U A R T   R E C E I V E R                                        
//###############################################################################################################################