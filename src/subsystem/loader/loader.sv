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
//----%% File Name        : loader.sv
//----%% Module Name      : Loader                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Loader programs the Instruction & Data RAM (IRAM/DRAM) with binary stream received via UART and boots up the CPU.
//----%%                    - Supports configurable baud rate and robust error detection while programming.
//----%%                    - Supports booting the CPU with NOPs.
//----%%                    - Supports re-booting the CPU with no re-programming.
//----%%                    Binary file is assumed to be validated for compliance with the format dumped by pqr5asm before sending to Loader.
//----%%                    Refer to PeqFlash manual for more information.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Aug-2024
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                                   L O A D E R                                          
//###################################################################################################################################################
// Header files
`include "../../include/pqr5_subsystem_macros.svh"

// Module definition
module loader# (
   // Configurable Parameters
   parameter IRAM_AW  = `IRAM_AW  ,  // Address width of IRAM, max. 30
   parameter IRAM_DW  = `IRAM_DW  ,  // Data width of IRAM, max. 30
   parameter DRAM_AW  = `DRAM_AW  ,  // Address width of DRAM, max. 30
   parameter DRAM_DW  = `DRAM_DW     // Data width of DRAM, max. 30
)
(
   // Clock and Reset
   input  logic               clk                ,  // Clock
   input  logic               aresetn            ,  // Asynchronous Reset; active-low
   
   // Control Signals 
   input  logic               i_halt_cpu         ,  // Halt CPU execution, by putting in reset
   output logic               o_ldr_cpu_stall    ,  // Stall signal from Loader to CPU
   output logic               o_ldr_cpu_reset    ,  // Reset to CPU, active-low

   // Status Signals
   output logic               o_init_done        ,  // Flags that loader has been successfully initialized
   output logic               o_busy             ,  // Programming status from Loader: '0'- Idle, '1'- Busy with programming
   output logic               o_pgm_done         ,  // Flags when programming is done successfully without errors
   output logic               o_err              ,  // Error in programming/other internal errors
   output logic [4:0]         o_err_code         ,  // Error code

   // UART I/F to accept commands to program IRAM
   input  logic               i_uart_rx          ,  // UART RX
   output logic               o_uart_tx          ,  // UART TX
   
   // IRAM Interface
   output logic [IRAM_AW-1:0] o_iram_addr        ,  // Address
   output logic [IRAM_DW-1:0] o_iram_wdata       ,  // Write Data
   output logic               o_iram_en          ,  // RAM Enable
   output logic               o_iram_wen         ,  // Write Enable
   input  logic [IRAM_DW-1:0] i_iram_rdata       ,  // Read Data

   // DRAM Interface
   output logic [DRAM_AW-1:0] o_dram_addr        ,  // Address
   output logic [DRAM_DW-1:0] o_dram_wdata       ,  // Write Data
   output logic               o_dram_en          ,  // RAM Enable
   output logic               o_dram_wen         ,  // Write Enable
   input  logic [DRAM_DW-1:0] i_dram_rdata          // Read Data
);

//===================================================================================================================================================
// Localparams (constants - DO NOT MODIFY) 
//===================================================================================================================================================
localparam I_PREAMBLE              = 8'hC0        ;  // Pre-amble (IRAM binary)
localparam D_PREAMBLE              = 8'hD0        ;  // Pre-amble (DRAM binary)
localparam POSTAMBLE               = 8'hE0        ;  // Post-amble
localparam CMD_REQ_DEVC_SIGN       = 8'hD3        ;  // Command: Device Signature Request
localparam CMD_BOOT_REQ_IRAM_CLN   = 8'hB1        ;  // Command: Clean Boot Request - Reset and reboot with IRAM clean slate
localparam CMD_BOOT_REQ            = 8'hB0        ;  // Command: Boot Request       - Reset and reboot with existing IRAM binary
localparam SUCCESS                 = 8'h55        ;  // Success flag
localparam ERROR_CMD_INVALID       = 8'hEC        ;  // Error code: Invalid Command
localparam ERROR_PGM               = 8'hED        ;  // Error code: Programming Error
localparam ERROR_POSTAMBLE         = 8'hEE        ;  // Error code: Post-amble Error
localparam DEVC_SIGN               = 32'hC0DE4A11 ;  // Device Signature: "Code For All"

// UART programming I/F specific
localparam BAUDRATE = int'(((`FCLK * 1000000.0) / `BAUDRATE) / 8.0 - 1) ;   // Baud rate configured

// NOP instruction for IRAM clean slate
localparam INSTR_NOP = 32'h0000_0013 ;

//===================================================================================================================================================
// Typedefs
//===================================================================================================================================================
// Loader FSM state
typedef enum logic [3:0] {
   INIT,            // INIT state
   IDLE,            // IDLE state   
   IRAM_CLN,        // IRAM Clean state
   READ_PGM_SIZE,   // Read Program Size state
   READ_PGM_BADDR,  // Read Program Base Address state
   READ_PGM_BIN,    // Read Program Binary state
   RAM_PGM,         // RAM Programming state
   READ_POSTAMBLE,  // Read Post-amble state
   ACK,             // ACK state
   PGM_DONE         // Programming done state
}  ldr_state ;

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
ldr_state   state_rg          ;  // State register
ldr_state   ack_exit_state_rg ;  // State to be transitted to after ACK exit

// Control signals - CPU
logic       cpu_stall_rg      ;  // CPU stall; active-high
logic       cpu_reset_rg      ;  // CPU reset; active-low

// Control/Status signals - UART
logic       uart_tx_en_rg        ;  // UART TX enable
logic       uart_rx_en_rg        ;  // UART RX enable
logic [7:0] uart_txdata_rg       ;  // UART TX data to be transmitted
logic       uart_txdata_valid_rg ;  // UART TX data valid
logic       uart_tx_ready        ;  // UART TX ready
logic [7:0] uart_rxdata          ;  // UART RX data received
logic       uart_rxdata_valid    ;  // UART RX data valid
logic       uart_rx_ack          ;  // UART RX ack
logic       uart_error           ;  // UART Error

// Command related
logic [7:0]  cmd_rg              ;  // Command register: debug purpose only
logic [31:0] ack_resp_rg         ;  // ACK response
logic [1:0]  ack_byte_rg         ;  // ACK response first byte index
logic        is_ack_byte_zero    ;  // Flags if ACK response byte index is zero
logic        is_last_ack_byte_rg ;  // Flags if ACK response byte index is zero (registered)

// RX data sampling and BIN stream related
logic [1:0]  sample_cnt_rg       ;  // Sample counter to count UART RX data
logic [31:0] pgm_size_rg         ;  // Program size
logic [29:0] instr_cnt           ;  // Instruction count; no. of instructions to be programmed
logic [31:0] pgm_data_rg         ;  // Programming data
logic [29:0] pgm_cnt_rg          ;  // Programming counter, to count no. of instructions written to IRAM

// Error flags
// -----------
// cmd_err        : sets on invalid command, cleared only on registering a valid command
// pgm_err        : sets on errors during IRAM/DRAM programming, cleared only after correct programming of IRAM/DRAM
// postamble_err  : sets on post-amble missing/error, cleared only after correct programming of IRAM/DRAM
logic        cmd_err_rg          ;  // Invalid Command Error
logic        pgm_err_rg          ;  // Programming Error
logic        postamble_err_rg    ;  // Post-amble Error 

// Control signals to IRAM & DRAM after de-muxing
logic [IRAM_AW-1:0] iram_addr  ;  // Address
logic [IRAM_DW-1:0] iram_wdata ;  // Write Data
logic               iram_en    ;  // RAM Enable
logic               iram_wen   ;  // Write Enable
logic [DRAM_AW-1:0] dram_addr  ;  // Address
logic [DRAM_DW-1:0] dram_wdata ;  // Write Data
logic               dram_en    ;  // RAM Enable
logic               dram_wen   ;  // Write Enable

// Address overflow flag
logic               is_ram_addr_ovflow ;

// Control signals from Loader to RAM
logic [29:0]        ram_addr_rg  ;  // Address
logic [31:0]        ram_wdata_rg ;  // Write Data
logic               ram_en_rg    ;  // RAM Enable
logic               ram_wen_rg   ;  // Write Enable
logic               ram_sel_rg   ;  // RAM select: 0= IRAM, 1= DRAM
logic [31:0]        addr_cnt_rg  ;  // Address counter

//===================================================================================================================================================
// Loader FSM
//===================================================================================================================================================
always @(posedge clk or negedge aresetn) begin

   // Reset
   if (!aresetn) begin
      state_rg            <= INIT ;
      ack_exit_state_rg   <= INIT ;

      cpu_reset_rg        <= 1'b0 ;
      cpu_stall_rg        <= 1'b0 ;

      uart_tx_en_rg       <= 1'b0 ;       
      uart_rx_en_rg       <= 1'b0 ;       
      uart_txdata_rg      <= '0   ;     
      uart_txdata_valid_rg<= 1'b0 ;                      
      
      cmd_rg              <= '0   ;
      ack_resp_rg         <= '0   ;
      ack_byte_rg         <= 2'd0 ;
      is_last_ack_byte_rg <= 1'b0 ;
      
      ram_addr_rg   <= '0    ;
      ram_wdata_rg  <= '0    ;
      ram_en_rg     <= 1'b0  ;
      ram_wen_rg    <= 1'b0  ;
      ram_sel_rg    <= 1'b0  ;
      addr_cnt_rg   <= 32'd0 ;

      sample_cnt_rg <= 2'd0  ;
      pgm_size_rg   <= 32'd0 ;
      pgm_data_rg   <= 32'd0 ;
      pgm_cnt_rg    <= 29'd0 ;

      cmd_err_rg       <= 1'b0 ;      
      pgm_err_rg       <= 1'b0 ;
      postamble_err_rg <= 1'b0 ;
      
      o_init_done <= 1'b0 ;
      o_busy      <= 1'b0 ;
      o_pgm_done  <= 1'b0 ; 
   end

   // Out of Reset
   else begin
      case (state_rg)
         // ---------------------------------------------------------------------------------------
         // INIT state
         // ---------------------------------------------------------------------------------------
         // Set initial states of UART, CPU signals...
         // ---------------------------------------------------------------------------------------
         INIT : begin
            // UART RX : Enabled for command reception
            // UART TX : Disabled for power saving
            // CPU     : Released out of reset and no stall, in execute state 
            uart_rx_en_rg <= 1'b1 ; 
            uart_tx_en_rg <= 1'b0 ;
            cpu_reset_rg  <= 1'b1 ; 
            cpu_stall_rg  <= 1'b0 ;
            o_init_done   <= 1'b1 ;  // Initialization done            
            
            state_rg <= IDLE ;
         end
         
         // ---------------------------------------------------------------------------------------
         // IDLE state
         // ---------------------------------------------------------------------------------------
         // Wait here until a command is received via UART RX
         // ---------------------------------------------------------------------------------------
         IDLE : begin
            
            // Command: Device Signature Request
            if (uart_rxdata_valid && uart_rxdata == CMD_REQ_DEVC_SIGN) begin 
               // Register the command  
               cmd_rg     <= CMD_REQ_DEVC_SIGN ;
               cmd_err_rg <= 1'b0 ;

               // Clear sample counter on any other command than PREAMBLE
               sample_cnt_rg <= 2'd0 ;
               
               // Set up command ACK               
               // ACK response = Device Signature, size = 4 bytes  
               ack_resp_rg       <= DEVC_SIGN  ;  
               ack_byte_rg       <= 2'd3       ;
               ack_exit_state_rg <= IDLE       ;  // After ACK, come back to IDLE                              
               state_rg          <= ACK        ;               
            end

            // Command: Boot Request
            else if (uart_rxdata_valid && ((uart_rxdata == CMD_BOOT_REQ_IRAM_CLN) || (uart_rxdata == CMD_BOOT_REQ))) begin
               // Register the command               
               cmd_rg     <= uart_rxdata ;
               cmd_err_rg <= 1'b0 ;

               // Clear sample counter on any other command than PREAMBLE
               sample_cnt_rg <= 2'd0 ;

               // Reset programming status
               // Set Loader status = BUSY
               o_busy     <= 1'b1  ;
               o_pgm_done <= 1'b0  ;                                

               // IRAM clean slate request           
               if (uart_rxdata[0]) begin
                  cpu_reset_rg <= 1'b0     ;  // Assert CPU reset   
                  cpu_stall_rg <= 1'b1     ;  // Put CPU in stall state, to transfer IRAM control to Loader 
                  ram_sel_rg   <= 1'b0     ;                 
                  state_rg     <= IRAM_CLN ;                  
               end
               // Reboot request
               else begin
                  cpu_reset_rg <= 1'b0     ;  // Assert CPU reset
                  cpu_stall_rg <= 1'b0     ;  // No transfer of IRAM control reqd...                  
                  state_rg     <= PGM_DONE ;  // Transit to DONE state to complete the single cycle reset pulse ``\__/`` to the CPU  
               end
            end

            // Command: Pre-amble of IRAM BIN stream
            else if (uart_rxdata_valid && (uart_rxdata == I_PREAMBLE)) begin
               // If previous command was the other preamble, then preamble pattern detection should be reset with the currently received preamble
               if (cmd_rg == D_PREAMBLE) begin
                  sample_cnt_rg <= 2'd1 ;
               end
               else begin
                  sample_cnt_rg <= sample_cnt_rg + 1 ;
               end

               // Register the command = PREAMBLE 
               cmd_rg     <= I_PREAMBLE ;
               cmd_err_rg <= 1'b0 ;

               // Pre-amble successfully sampled...  
               if (sample_cnt_rg == 2'd3) begin    
                  cpu_reset_rg <= 1'b0 ;  // Assert CPU reset   
                  cpu_stall_rg <= 1'b1 ;  // Put CPU in stall state, to transfer IRAM control to Loader
                  ram_sel_rg   <= 1'b0 ;

                  // Reset programming status
                  // Set Loader status = BUSY
                  o_busy     <= 1'b1  ;
                  o_pgm_done <= 1'b0  ;                  

                  state_rg   <= READ_PGM_SIZE ;                                  
               end
            end

            // Command: Pre-amble of DRAM BIN stream
            else if (uart_rxdata_valid && (uart_rxdata == D_PREAMBLE)) begin
               // If previous command was the other preamble, then preamble pattern detection should be reset with the currently received preamble
               if (cmd_rg == I_PREAMBLE) begin
                  sample_cnt_rg <= 2'd1 ;
               end
               else begin
                  sample_cnt_rg <= sample_cnt_rg + 1 ;
               end

               // Register the command = PREAMBLE              
               cmd_rg     <= D_PREAMBLE ;
               cmd_err_rg <= 1'b0 ; 

               // Pre-amble successfully sampled...  
               if (sample_cnt_rg == 2'd3) begin    
                  cpu_reset_rg <= 1'b0 ;  // Assert CPU reset   
                  cpu_stall_rg <= 1'b1 ;  // Put CPU in stall state, to transfer DRAM control to Loader
                  ram_sel_rg   <= 1'b1 ;

                  // Reset programming status
                  // Set Loader status = BUSY
                  o_busy     <= 1'b1  ;
                  o_pgm_done <= 1'b0  ;                  

                  state_rg   <= READ_PGM_SIZE ;                                  
               end
            end

            // Invalid Command
            else if (uart_rxdata_valid) begin                
               // Register the command with error             
               cmd_rg     <= uart_rxdata ;
               cmd_err_rg <= 1'b1 ;

               // Clear sample counter on any other command than PREAMBLE
               sample_cnt_rg <= 2'd0 ;

               // Set up command ACK               
               // ACK response = ERROR, size = 1 byte  
               ack_resp_rg       <= {24'h0, ERROR_CMD_INVALID} ;  
               ack_byte_rg       <= 2'd0 ;
               ack_exit_state_rg <= IDLE ;                              
               state_rg          <= ACK  ;
            end            
         end         
         
         // ---------------------------------------------------------------------------------------
         // IRAM Clean state
         // ---------------------------------------------------------------------------------------
         // Cleans IRAM by overwriting every data with NOP instruction
         // ---------------------------------------------------------------------------------------
         IRAM_CLN : begin
            if (is_ram_addr_ovflow) begin  // Reached max addr @IRAM
               // Disable IRAM, reset counter, RAM address
               ram_en_rg    <= 1'b0 ;
               ram_wen_rg   <= 1'b0 ;
               addr_cnt_rg  <=  0   ;
               ram_addr_rg  <= '0   ;                        
               
               // Programming done
               postamble_err_rg <= 1'b0     ;  // Postamble errors if any, can be cleared               
               pgm_err_rg       <= 1'b0     ;  // Programming success, no errors
               state_rg         <= PGM_DONE ;
            end  
            else begin
               // Write to IRAM         
               ram_en_rg    <= 1'b1 ;
               ram_wen_rg   <= 1'b1 ;
               ram_addr_rg  <= addr_cnt_rg[31:2] ;  // RAM has word addressing
               ram_wdata_rg <= INSTR_NOP   ;

               // Increment address counter
               addr_cnt_rg   <= addr_cnt_rg + 4 ;   // System has byte addressing
            end
         end
         
         // ---------------------------------------------------------------------------------------
         // Read Program Size state        
         // ---------------------------------------------------------------------------------------         
         READ_PGM_SIZE : begin
            if (uart_rxdata_valid) begin
               sample_cnt_rg      <= sample_cnt_rg + 1  ;
               pgm_size_rg[7:0]   <= uart_rxdata        ;
               pgm_size_rg[15:8]  <= pgm_size_rg[7:0]   ;
               pgm_size_rg[23:16] <= pgm_size_rg[15:8]  ; 
               pgm_size_rg[31:24] <= pgm_size_rg[23:16] ;
               if (sample_cnt_rg == 2'd3) begin
                  state_rg <= READ_PGM_BADDR ;
               end
            end
         end

         // ---------------------------------------------------------------------------------------
         // Read Program Base Address state        
         // ---------------------------------------------------------------------------------------
         READ_PGM_BADDR : begin
            if (uart_rxdata_valid) begin
               sample_cnt_rg      <= sample_cnt_rg + 1  ;
               addr_cnt_rg[7:0]   <= uart_rxdata        ;
               addr_cnt_rg[15:8]  <= addr_cnt_rg[7:0]   ;
               addr_cnt_rg[23:16] <= addr_cnt_rg[15:8]  ; 
               addr_cnt_rg[31:24] <= addr_cnt_rg[23:16] ;
               if (sample_cnt_rg == 2'd3) begin
                  state_rg <= READ_PGM_BIN ;
               end
            end
         end         
         
         // ---------------------------------------------------------------------------------------
         // Read Program Binary state     
         // ---------------------------------------------------------------------------------------
         // Read incoming binary stream, buffer the 32-bit instruction/data to be written to RAM   
         // ---------------------------------------------------------------------------------------
         READ_PGM_BIN : begin
            // All instructions written or address overflow happened...
            if ((pgm_cnt_rg == instr_cnt) || is_ram_addr_ovflow) begin  
               // Reset counters, RAM address
               pgm_cnt_rg   <=  0 ; 
               addr_cnt_rg  <=  0 ; 
               ram_addr_rg  <= '0 ;                

               pgm_err_rg <= (pgm_cnt_rg != instr_cnt) ;  // If RAM address overflow, log it as error... but it's okay to have instruction count of 0             
               state_rg   <= (pgm_cnt_rg != instr_cnt)? PGM_DONE : READ_POSTAMBLE ;               
            end
            // Instructions/data pending to be written...
            else if (uart_rxdata_valid) begin
               sample_cnt_rg      <= sample_cnt_rg + 1  ;
               pgm_data_rg[7:0]   <= uart_rxdata        ;
               pgm_data_rg[15:8]  <= pgm_data_rg[7:0]   ;
               pgm_data_rg[23:16] <= pgm_data_rg[15:8]  ; 
               pgm_data_rg[31:24] <= pgm_data_rg[23:16] ;
               if (sample_cnt_rg == 2'd3) begin
                  state_rg <= RAM_PGM ;
               end                 
            end
         end

         // ---------------------------------------------------------------------------------------
         // Program RAM state     
         // ---------------------------------------------------------------------------------------
         // Write the buffered instruction/data to RAM
         // ---------------------------------------------------------------------------------------
         RAM_PGM : begin
            if (!ram_en_rg) begin
               // Write to RAM
               ram_en_rg    <= 1'b1 ;
               ram_wen_rg   <= 1'b1 ;
               ram_addr_rg  <= addr_cnt_rg[31:2] ;  // RAM has word addressing
               ram_wdata_rg <= pgm_data_rg ;               
            end
            else begin
               // Disable RAM in the next clock cycle after writing...
               ram_en_rg    <= 1'b0 ;
               ram_wen_rg   <= 1'b0 ;
               
               // Increment counters, proceed to read next instruction/data from BIN stream...
               addr_cnt_rg <= addr_cnt_rg + 4 ;  // System has byte addressing
               pgm_cnt_rg  <= pgm_cnt_rg + 1  ; 
               state_rg    <= READ_PGM_BIN    ;                
            end      
         end

         // ---------------------------------------------------------------------------------------
         // Read Post-amble state     
         // ---------------------------------------------------------------------------------------         
         READ_POSTAMBLE: begin
            if (uart_rxdata_valid && (uart_rxdata == POSTAMBLE)) begin
               sample_cnt_rg <= sample_cnt_rg + 1 ;
               // Post-amble successfully sampled...
               if (sample_cnt_rg == 2'd3) begin
                  postamble_err_rg <= 1'b0     ;  // Success, no errors              
                  state_rg         <= PGM_DONE ;                               
               end
            end 
            // Post-amble byte sequence violated...
            else if (uart_rxdata_valid && (uart_rxdata != POSTAMBLE)) begin
               sample_cnt_rg    <= 2'd0     ;
               postamble_err_rg <= 1'b1     ;  // Set error
               state_rg         <= PGM_DONE ;  
            end     
         end

         // ---------------------------------------------------------------------------------------
         // ACK state
         // ---------------------------------------------------------------------------------------
         // Acknowledge the command received/BIN stream by sending back the ACK via UART TX
         // ---------------------------------------------------------------------------------------
         ACK : begin
            // Enable UART TX
            uart_tx_en_rg <= 1'b1 ;  
          
            // UART TX is ready to accept byte            
            if (uart_tx_ready) begin
               // Send ACK byte to UART TX buffer
               if (!is_last_ack_byte_rg) begin
                  uart_txdata_rg        <= ack_resp_rg[(ack_byte_rg*8)+:8] ;  // MSB first...
                  uart_txdata_valid_rg  <= 1'b1 ;                  
                  ack_byte_rg           <= (is_ack_byte_zero)? ack_byte_rg : (ack_byte_rg - 2'd1) ;
                  is_last_ack_byte_rg   <= (is_ack_byte_zero) ;
               end     
               // Finished sending the last ACK byte sent to UART TX buffer...
               else begin
                   is_last_ack_byte_rg  <= 1'b0 ;  // Reset the flag
                   uart_txdata_valid_rg <= 1'b0 ;  
                   uart_tx_en_rg        <= 1'b0 ;  // Disable UART TX
                   state_rg             <= ack_exit_state_rg  ;  
               end  
            end
         end

         // ---------------------------------------------------------------------------------------
         // Programming Done state
         // ---------------------------------------------------------------------------------------
         // After every command other than DEVICE SIGNATURE REQUEST, Loader reaches this state.
         // After BIN stream, Loader reaches this state.
         // Log programming status, initiate ACK.
         // Put CPU back in execute state if no errors...else CPU should remain reset
         // ---------------------------------------------------------------------------------------         
         PGM_DONE : begin
            // Put CPU back in execute state if no errors, else keep in RESET state
            // Release IRAM/DRAM control by releasing CPU from stall...
            cpu_reset_rg <= ~pgm_err_rg & ~postamble_err_rg ;
            cpu_stall_rg <= 1'b0 ;
            
            // Set programming status = DONE if no programming errors
            // Set Loader status      = IDLE
            o_busy     <= 1'b0 ;
            o_pgm_done <= ~pgm_err_rg & ~postamble_err_rg ;

            // Set up command ACK               
            // ACK response = SUCCESS if no errors, else ERROR code; size = 1 byte  
            if (postamble_err_rg) begin
               ack_resp_rg <= {24'h0, ERROR_POSTAMBLE} ;  // Post-amble Error
            end 
            else if (pgm_err_rg) begin
               ack_resp_rg <= {24'h0, ERROR_PGM} ;  // Programming Error
            end
            else begin
               ack_resp_rg <= {24'h0, SUCCESS} ;  // Programming success, no errors
            end
            ack_byte_rg       <= 2'd0 ;
            ack_exit_state_rg <= IDLE ;
            state_rg          <= ACK  ;
         end         
         
         // Default state
         default    : ;

      endcase     
   end

end

// RAM de-mux to route RAM control signals to IRAM or/and DRAM
always_comb begin
   case (ram_sel_rg)      
      // IRAM selected
      1'b0: begin
         iram_addr  = ram_addr_rg  ;
         iram_wdata = ram_wdata_rg ;
         iram_en    = ram_en_rg    ;
         iram_wen   = ram_wen_rg   ;
         dram_addr  = '0   ;
         dram_wdata = '0   ;
         dram_en    = 1'b0 ;
         dram_wen   = 1'b0 ;         
      end
      // DRAM selected
      1'b1: begin
         dram_addr  = ram_addr_rg  ;
         dram_wdata = ram_wdata_rg ;
         dram_en    = ram_en_rg    ;
         dram_wen   = ram_wen_rg   ;
         iram_addr  = '0   ;
         iram_wdata = '0   ;
         iram_en    = 1'b0 ;
         iram_wen   = 1'b0 ;         
      end
   endcase
end

// Address overflow flag
assign is_ram_addr_ovflow = ram_sel_rg? (&dram_addr) : (&iram_addr) ;

//=========================================================================================================================================
// Timeout logic
//=========================================================================================================================================
logic [31:0] timer_rg      ;  // Timer
logic        timer_en      ;  // Timer enable
logic        is_timer_zero ;  // Timer underflow flag
logic        timeout_rg    ;  // Programming timeout; sets when timeout happens in Loader FSM, cleared only on reset
                              // NOTE: If timeout happens, the system including Loader MUST BE reset, as the current state is undefined

always @(posedge clk or negedge aresetn) begin
   // Reset
   if (!aresetn) begin
      timeout_rg <= 1'b0     ;
      timer_rg   <= `TIMEOUT ;
   end
   // Timer enabled
   else if (timer_en) begin
      timer_rg   <= is_timer_zero ? timer_rg : (timer_rg - 32'd1) ;  // If reaches 0, stop counting...
      timeout_rg <= is_timer_zero ? 1'b1     : timeout_rg ;          // Once set, never cleared until reset         
   end  
   // Timer reset
   else begin
      timer_rg <= `TIMEOUT ;   
   end 
end

assign timer_en      = (state_rg != IDLE) ;  // Timer triggered when Loader becomes busy with processing command/programming...
assign is_timer_zero = (~|timer_rg) ;
//=========================================================================================================================================

// RX ack
// ------
// Always ack immediately when in UART RX data sampling states...
// valid ___/``\___
// ack  ____/``\___
assign uart_rx_ack = uart_rxdata_valid && ((state_rg == IDLE) || (state_rg == READ_PGM_SIZE) || 
                     (state_rg == READ_PGM_BIN) || (state_rg == READ_PGM_BADDR) || (state_rg == READ_POSTAMBLE)) ;

// Counts
assign instr_cnt = pgm_size_rg[31:2] ;  // Program size (in bytes) / 4 = no. of instructions, cz each instruction = 4 byte

// Flags
assign is_ack_byte_zero = (ack_byte_rg == 2'd0) ;

// UART instance
uart_top inst_uart_pgmLoader (
   .clk            (clk)       ,  
   .rstn           (aresetn)   ,

   .o_tx           (o_uart_tx) ,
   .i_rx           (i_uart_rx) ,
    
   .i_baudrate     (16'(BAUDRATE)) , 
   .i_parity_mode  (2'b00)         ,  // No parity  
   .i_frame_mode   (1'b0)          ,  // 1 start/stop bit
   .i_lpbk_mode_en (1'b0)          ,  // No loopback
   .i_tx_break_en  (1'b0)          ,  // No TX break
   .i_tx_en        (uart_tx_en_rg) ,  
   .i_rx_en        (uart_rx_en_rg) ,     
   .i_tx_rst       (1'b0)          ,  // Disable TX reset
   .i_rx_rst       (1'b0)          ,  // Disable RX reset           
      
   .i_data         (uart_txdata_rg)       ,  
   .i_data_valid   (uart_txdata_valid_rg) ,  
   .o_ready        (uart_tx_ready)        ,  

   .o_data         (uart_rxdata)       ,  
   .o_data_valid   (uart_rxdata_valid) , 
   .i_ready        (uart_rx_ack)       ,  
   
   .o_tx_state     () ,  // UNUSED
   .o_rx_state     () ,  // UNUSED
   .o_rx_break     () ,  // UNUSED   
   .o_parity_err   () ,  // UNUSED  
   .o_frame_err    (uart_error)                                      
);

// CDC synchronizer for i_halt_cpu as this may come from external to system
logic halt_cpu_sync ;
cdc_sync #(
   .STAGES (2)
)  inst_sync_halt_cpu (
   .clk        (clk)          ,        
   .rstn       (aresetn)      ,       
   .i_sig      (i_halt_cpu)   ,     
   .o_sig_sync (halt_cpu_sync)     
);

// Control/Reset signals to CPU
assign o_ldr_cpu_reset = ~halt_cpu_sync & cpu_reset_rg ;
assign o_ldr_cpu_stall = cpu_stall_rg ;

// Error signal out
assign o_err      = cmd_err_rg | pgm_err_rg | postamble_err_rg | timeout_rg | uart_error ;
assign o_err_code = {cmd_err_rg, pgm_err_rg, postamble_err_rg, timeout_rg, uart_error}   ;

// IRAM control signals out
assign o_iram_addr  = iram_addr  ;
assign o_iram_wdata = iram_wdata ;
assign o_iram_en    = iram_en    ;
assign o_iram_wen   = iram_wen   ;

// DRAM control signals out
assign o_dram_addr  = dram_addr  ;
assign o_dram_wdata = dram_wdata ;
assign o_dram_en    = dram_en    ;
assign o_dram_wen   = dram_wen   ;

endmodule
//###################################################################################################################################################
//                                                                   L O A D E R                                          
//###################################################################################################################################################