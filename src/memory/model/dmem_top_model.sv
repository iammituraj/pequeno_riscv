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
//----%% File Name        : dmem_top.sv
//----%% Module Name      : Data Memory (DMEM) Wrapper                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This is a wrapper over the 32-bit addressing space of the CPU (data memory).
//----%%                    Supports valid-ready handshaking at the interface.
//----%%
//----%%                    +===================================================================================+
//----%%                    | ADDRESS SPACE                                                                     |
//----%%                    +===============+======================+===============+============================+
//----%%                    | Base Address  | Peripheral           | Size          | Address Range              |
//----%%                    +---------------+----------------------+---------------+----------------------------+
//----%%                    | 0x0000_0000   | 32-bit Data RAM      | DEPTH*4 bytes | 0x0000_0000 to (DEPTH*4)-1 |
//----%%                    +---------------+----------------------+---------------+----------------------------+
//----%%                    | 0x0001_0000   | dbgUART (Debug UART) | 4 kB          | 0x0001_0000 to 0x0001_0FFF |
//----%%                    +---------------+--------------------------------------+ ---------------------------+
//----%%
//----%%                    The wrapper supports two memory models:
//----%%                    # Zero latency model     : latency=0; always hit, always single-cycle access.
//----%%                    # Non-zero latency model : latency=1 on hit, latency=random/fixed on miss. Hit-Miss depends on hit rate configured.
//----%%
//----%%                    Debug UART module is supported ONLY in Zero latency model. Only TX is supported.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : June-2024
//----%% Notes            : All models are synthesisable.
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                       D A T A   M E M O R Y   -   W R A P P E R                                         
//###################################################################################################################################################
// Header files
`include "../include/pqr5_subsystem_macros.svh"

// Module definition
module dmem_top_model#(
   // Configurable Parameters
   parameter  RAM_DEPTH   = 1024 ,      // Depth of RAM; 2^N; range=[4-..]
   parameter  IS_ZERO_LAT = 1    ,      // '1'- Zero latency model with 100% Hit, '0'- Non-zero latency model
   parameter  IS_RLAT     = 1    ,      // '1'- Random latency, '0'- Fixed latency --> only for Non-zero latency model
   parameter  HITRATE     = 90.0 ,      // Hit rate % --> only for Random latency; latency on hit = 1 cycle always 
   parameter  MISS_RLAT   = 15   ,      // Latency on miss = MISS_RLAT+1 cycles; range=[0-15]
   parameter  FIXED_LAT   = 1    ,      // Fixed latency = FIXED_LAT+1 for hit/miss; range=[0-15]

   // Derived/Constant Parameters
   localparam DATA_W      = 32 ,            // Data width
   localparam ADDR_W      = 32 ,            // Address width
   localparam RAM_ADDR_W  = $clog2(RAM_DEPTH),  // Address (word address) width of Data RAM
   localparam RAM_BADDR_W = RAM_ADDR_W + 2  // Byte address width of Data RAM
)
(
   // Clock and Reset Interface  
   input  logic  clk     ,    // Clock
   input  logic  aresetn ,    // Asynchronous Reset; active-low 

   // Debug UART Interface
   `ifdef DBGUART
   output logic  o_uart_tx ,  // UART Tx
   `endif

   // Clock tick counter
   input  logic [31:0]           i_clktick_cnt    ,  // Clock tick counter

   // Programming Interface: used to write the binary to Instruction RAM
   input  logic                  i_pgm_en         ,  // Programming mode Enable
   input  logic [RAM_ADDR_W-1:0] i_pgm_dram_addr  ,  // Address
   input  logic [DATA_W-1:0]     i_pgm_dram_wdata ,  // Write Data
   input  logic                  i_pgm_dram_en    ,  // RAM Enable
   input  logic                  i_pgm_dram_wen   ,  // Write Enable
   output logic [DATA_W-1:0]     o_pgm_dram_rdata ,  // Read Data
      
   // Memory Interface
   input  logic               i_wen   ,    // Write enable
   input  logic [ADDR_W-1:0]  i_addr  ,    // Address
   input  logic [1:0]         i_size  ,    // Size
   input  logic [DATA_W-1:0]  i_data  ,    // Data in
   input  logic               i_req   ,    // Request
   output logic               o_ready ,    // Memory ready  
   input  logic               i_flush ,    // Flush signal 
   output logic [DATA_W-1:0]  o_data  ,    // Data out
   output logic               o_ack   ,    // Acknowledge
   input  logic               i_ready      // Data ready
);

//===================================================================================================================================================
// localparams
//===================================================================================================================================================
localparam [1:0] BYTE   = 2'b00 ;
localparam [1:0] HWORD  = 2'b01 ;
localparam [1:0] WORD   = 2'b10 ;

generate
////////////////////////////////////////////////////////////== Zero Latency Model ==///////////////////////////////////////////////////////////////// 
////////////////////////////////////////////////////////////== Zero Latency Model ==///////////////////////////////////////////////////////////////// 
////////////////////////////////////////////////////////////== Zero Latency Model ==///////////////////////////////////////////////////////////////// 
if (IS_ZERO_LAT == 1) begin : DMEM_ZEROLAT_MODEL

//===================================================================================================================================================
// localparams
//===================================================================================================================================================
localparam BAUDRATE = int'(((`FCLK * 1000000.0) / `BAUDRATE) / 8.0 - 1) ;   // Baud rate configured

// Address map related
localparam MASK_RAM  = 32'hFFFF_FFFF << RAM_BADDR_W ;
localparam BADR_RAM  = 32'h0000_0000 ;
`ifdef DBGUART
localparam MASK_UART = 32'hFFFF_FFFF << 12 ;
localparam BADR_UART = 32'h0001_0000 ;
`endif

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
logic [RAM_ADDR_W-1:0] ram_addr      ;  // Address to RAM from Memory IF
logic [RAM_ADDR_W-1:0] ram_addr_pp   ;  // Address @RAM after D-RAM Mux
logic [DATA_W-1:0]     ram_rdata     ;  // Data read from RAM
logic [DATA_W-1:0]     ram_wdata_pp  ;  // Write Data @RAM after D-RAM Mux
logic                  ram_hit       ;  // Hit RAM
logic                  ram_wen_pp    ;  // Write Enable @RAM after D-RAM Mux
logic                  ram_en        ;  // Enable RAM from Memory IF
logic [3:0]            ram_en_pp     ;  // Enable @RAM after D-RAM Mux
`ifdef DBGUART
logic [11:0]       uart_addr ;  // Address to UART
logic [DATA_W-1:0] uart_rdata;  // Data read from UART registers
logic              uart_hit  ;  // Hit
logic              uart_en   ;  // Enable
// Debug UART address map connections
logic              uart_tx_en, uart_tx_rst      ;  // TX control signals 
logic [7:0]        uart_tx_data                 ;  // TX data
logic              uart_tx_data_valid           ;  // TX data valid
logic              uart_tx_ready, uart_tx_state ;  // TX status signals
`endif
logic [3:0]        byte_en ;  // Byte-enable
logic              ready, ready_rg, ack_rg ;  // Ready, ack signals
logic [1:0]        rsel_rg ;  // Read select to read data mux
logic [DATA_W-1:0] rdata   ;  // Read data from read data mux

//===================================================================================================================================================
// Hit signal generation
//===================================================================================================================================================
assign ram_hit  = (i_addr & MASK_RAM) == BADR_RAM ;
assign ram_en   = ready & ram_hit ;
`ifdef DBGUART
assign uart_hit = (i_addr & MASK_UART) == BADR_UART ;
assign uart_en  = ready & uart_hit ;
`endif

//===================================================================================================================================================
// Submodule Instances
//===================================================================================================================================================
// 32-bit Data RAM
dram_4x8 #(
   .DEPTH  (RAM_DEPTH)
) 
inst_dram_4x8 (
   .clk    (clk)           ,   
   .i_en   (ram_en_pp)     ,
   .i_wen  (ram_wen_pp)    , 
   .i_addr (ram_addr_pp)   ,
   .i_data (ram_wdata_pp)  ,
   .o_data (ram_rdata)  
);

`ifdef DBGUART
// Debug UART
uart_top inst_dbguart (
   .clk            (clk)       ,  
   .rstn           (aresetn)   ,

   .o_tx           (o_uart_tx) ,
   .i_rx           () ,               // UNUSED
    
   .i_baudrate     (16'(BAUDRATE)) , 
   .i_parity_mode  (2'b00)       ,  // No parity  
   .i_frame_mode   (1'b0)        ,  // 1 start/stop bit
   .i_lpbk_mode_en (1'b0)        ,  // Disable loopback
   .i_tx_break_en  (1'b0)        ,  // Disable TX break control
   .i_tx_en        (uart_tx_en)  ,  // TX enable/disable controlled by CSR
   .i_rx_en        (1'b0)        ,  // Disable RX 
   .i_tx_rst       (uart_tx_rst) ,  // TX reset controller by CSR
   .i_rx_rst       (1'b0)        ,  // Disable RX reset control          
      
   .i_data         (uart_tx_data)        ,  // TX data controlled by CSR  
   .i_data_valid   (uart_tx_data_valid)  ,  // TX data valid 
   .o_ready        (uart_tx_ready)       ,  // TX ready logged by CSR

   .o_data         () ,  // UNUSED
   .o_data_valid   () ,  // UNUSED
   .i_ready        () ,  // UNUSED  
   
   .o_tx_state     (uart_tx_state) ,  // TX state logged by CSR 
   .o_rx_state     () ,  // UNUSED
   .o_rx_break     () ,  // UNUSED   
   .o_parity_err   () ,  // UNUSED  
   .o_frame_err    ()    // UNUSED                                  
);

// Debug UART 32-bit address map
uarttx_addrmap inst_dbguart_addrmap (
   .clk             (clk)     ,
   .rstn            (aresetn) ,

   .i_en            (uart_en)        ,
   .i_wen           (i_wen & i_req)  , 
   .i_byteen        (byte_en)        ,
   .i_addr          (uart_addr[5:0]) ,  // Out of 4KB address space, only 64 bytes currently in use...
   .i_data          (i_data)         ,
   .o_data          (uart_rdata)     ,

   .o_tx_en         (uart_tx_en)         ,
   .o_tx_rst        (uart_tx_rst)        ,
   .o_tx_data       (uart_tx_data)       ,
   .o_tx_data_valid (uart_tx_data_valid) ,
   .i_tx_data_ready (uart_tx_ready)      ,
   .i_tx_state      (uart_tx_state)      ,
   .i_clktick_cnt   (i_clktick_cnt)
);
`endif

//===================================================================================================================================================
// Synchronous logic to manage DMEM valid-ready handshaking and read select
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin   
   // Reset   
   if (!aresetn) begin
      ready_rg <= 1'b0 ;  
      ack_rg   <= 1'b0 ;   
      rsel_rg  <= 2'h0 ;  
   end
   // Out of reset
   else if (!i_flush) begin
      ready_rg <= 1'b1 ; 
      if (ready) begin
         ack_rg <= i_req ;
         `ifdef DBGUART
         rsel_rg <= {uart_en, ram_en} ;
         `else
         rsel_rg <= {1'b0   , ram_en} ;
         `endif
      end    
   end
   // Flush - synchronous
   else begin
      ready_rg <= 1'b0 ; 
      rsel_rg  <= 2'h0 ; 
      ack_rg   <= 1'b0 ;   
   end
end

// Read data mux
always_comb begin
   case (rsel_rg)  
      2'b01   : rdata = ram_rdata  ;
      `ifdef DBGUART
      2'b10   : rdata = uart_rdata ;
      `endif
      default : rdata = '0         ;
   endcase 
end

//===================================================================================================================================================
// Combinatorial logic to encode byte-enable from request address
//===================================================================================================================================================
always_comb begin
   case (i_size)
      BYTE    : byte_en = 4'h1 << i_addr[1:0] ;
      HWORD   : byte_en = 4'h3 << i_addr[1:0] ; 
      WORD    : byte_en = 4'hF << i_addr[1:0] ;
      default : byte_en = 4'hF << i_addr[1:0] ;
   endcase
end

//===================================================================================================================================================
// Continuous Assignments
//===================================================================================================================================================
assign ram_addr  = i_addr[RAM_BADDR_W-1 : 2] ; // Word addressing on RAM
`ifdef DBGUART
assign uart_addr = i_addr[11:0] ;  // Byte addressing on UART
`endif

// D-RAM Mux selects between Master/Programming Interface control
assign ram_addr_pp      = (i_pgm_en)? i_pgm_dram_addr    : ram_addr ;
assign ram_en_pp        = (i_pgm_en)? {4{i_pgm_dram_en}} : (byte_en & {4{ram_en}}) ;
assign ram_wen_pp       = (i_pgm_en)? i_pgm_dram_wen     : (i_wen & i_req) ; 
assign ram_wdata_pp     = (i_pgm_en)? i_pgm_dram_wdata   : i_data ;
assign o_pgm_dram_rdata = rdata ;

assign ready     = (i_ready | ~ack_rg) & ready_rg ; 
assign o_ready   = ready  ;
assign o_data    = rdata  ;
assign o_ack     = ack_rg ;

end//GENERATE: DMEM_ZEROLAT_MODEL

////////////////////////////////////////////////////////== Non-zero Latency Model ==/////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////== Non-zero Latency Model ==/////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////== Non-zero Latency Model ==/////////////////////////////////////////////////////////////////
else begin : DMEM_NONZEROLAT_MODEL

//===================================================================================================================================================
// Typedefs
//===================================================================================================================================================
typedef enum logic {
   IDLE = 1'b0,
   ACK  = 1'b1   
}  state ;

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
state                  state_rg                ;  // State register
logic                  ready, ready_rg, ack_rg ;  // Ready, ack signals
logic [3:0]            en, en_rg               ;  // Byte-enable from Memory Interface
logic [3:0]            ram_en_pp               ;  // Byte-enable @RAM after D-RAM Mux
logic                  wen_rg                  ;  // Write Enable from Memory Interface
logic                  ram_wen_pp              ;  // Write Enable @RAM after D-RAM Mux
logic [RAM_ADDR_W-1:0] addr, addr_rg           ;  // Address to RAM from Memory Interface
logic [RAM_ADDR_W-1:0] ram_addr_pp             ;  // Address @RAM after D-RAM Mux
logic [DATA_W-1:0]     data_rg, rdata          ;  // W/R data to/from RAM from/to Memory Interface
logic [DATA_W-1:0]     ram_wdata_pp            ;  // Write data to
logic                  hit                     ;  // Hit signal
logic [3:0]            lat, lat_rg             ;  // Latency register
logic [3:0]            lat_cnt_rg              ;  // Latency counter

//===================================================================================================================================================
// Submodule Instances
//===================================================================================================================================================
// 32-bit Data RAM
dram_4x8 #(   
   .DEPTH  (RAM_DEPTH)
) 
inst_dram_4x8 (
   .clk    (clk)          ,   
   .i_en   (ram_en_pp)    ,
   .i_wen  (ram_wen_pp)   , 
   .i_addr (ram_addr_pp)  ,
   .i_data (ram_wdata_pp) ,
   .o_data (rdata)  
);

//===================================================================================================================================================
// Synchronous logic to read and write to RAM with valid-ready handshaking
//===================================================================================================================================================
always_ff @(posedge clk or negedge aresetn) begin   
   // Reset   
   if (!aresetn) begin
      state_rg   <= IDLE ;
      ready_rg   <= 1'b0 ;
      ack_rg     <= 1'b0 ;
      en_rg      <= 4'h0 ;
      wen_rg     <= 1'b0 ;
      addr_rg    <= '0   ;
      data_rg    <= '0   ;
      lat_rg     <= 4'd0 ;
      lat_cnt_rg <= 4'd0 ;          
   end
   // Out of reset
   else if (!i_flush) begin 
      case (state_rg) 
         // Idle state: wait for request
         IDLE : begin
            ready_rg <= 1'b1 ;
            if (i_req && ready) begin
               ready_rg <= 1'b0   ;  // Not ready to accept anymore req
               en_rg    <= en     ;  // Enable memory              
               wen_rg   <= i_wen  ;
               addr_rg  <= addr   ;
               data_rg  <= i_data ; 
               lat_rg   <= lat    ;  // Register latency
               state_rg <= ACK    ;              
            end
            if (ready) begin ack_rg <= 1'b0 ; end  // De-assert ack
         end
         // Ack state: sends acknowledgement
         ACK : begin
            if (lat_cnt_rg == lat_rg) begin
               lat_cnt_rg <= 4'd0 ;
               en_rg      <= 4'h0 ;  // Disable memory
               ack_rg     <= 1'b1 ;  // Assert ack
               ready_rg   <= 1'b1 ;  // Ready to accept next req
               state_rg   <= IDLE ;
            end
            else begin
               lat_cnt_rg <= lat_cnt_rg + 4'd1 ;               
            end  
         end
      endcase         
   end
   // Flush - synchronous
   else begin
      state_rg   <= IDLE ;
      ready_rg   <= 1'b0 ;
      ack_rg     <= 1'b0 ;
      en_rg      <= 4'h0 ;
      wen_rg     <= 1'b0 ;
      addr_rg    <= '0   ;
      data_rg    <= '0   ;
      lat_rg     <= 4'd0 ;
      lat_cnt_rg <= 4'd0 ;      
   end
end

//===================================================================================================================================================
// Combinatorial logic to encode byte-enable from request address
//===================================================================================================================================================
always_comb begin
   case (i_size)
      BYTE    : en = 4'h1 << i_addr[1:0] ;
      HWORD   : en = 4'h3 << i_addr[1:0] ; 
      WORD    : en = 4'hF << i_addr[1:0] ;
      default : en = 4'hF << i_addr[1:0] ;
   endcase
end

//===================================================================================================================================================
// Continuous Assignments
//===================================================================================================================================================
assign addr    = i_addr[RAM_BADDR_W-1 : 2] ;  // Word addressing
assign ready   = (i_ready | ~ack_rg) & ready_rg ;
assign o_ready = ready  ;
assign o_ack   = ack_rg ;

// D-RAM Mux selects between Master/Programming Interface control
assign ram_addr_pp      = (i_pgm_en)? i_pgm_dram_addr    : addr_rg ;
assign ram_en_pp        = (i_pgm_en)? {4{i_pgm_dram_en}} : en_rg   ;
assign ram_wen_pp       = (i_pgm_en)? i_pgm_dram_wen     : wen_rg  ;
assign ram_wdata_pp     = (i_pgm_en)? i_pgm_dram_wdata   : data_rg ;
assign o_pgm_dram_rdata = rdata ;

assign o_data           = rdata ;

//===================================================================================================================================================
// Memory latency generation logic
//===================================================================================================================================================
logic [3:0] lfsr_rout_rg   ;  // LFSR output
logic       lfsr_feedback  ;  // LFSR feedback
logic [3:0] rlat           ;  // Random latency generated by LFSR

// Synchronous logic of LFSR to generate random memory latency 
always_ff @(posedge clk or negedge aresetn) begin
   // Reset   
   if (!aresetn) begin
      lfsr_rout_rg <= '0 ;          
   end
   // Out of reset
   else begin
      lfsr_rout_rg <= {lfsr_rout_rg[2:0], lfsr_feedback} ;
   end
end
assign lfsr_feedback = ~(lfsr_rout_rg[3] ^ lfsr_rout_rg[2]) ;

localparam RTH      = int'((HITRATE * 4'd15)/100) ; 
localparam HIT_RLAT = 0 ;  // Hit latency = HIT_RLAT+1 cycles

// Mapping of LFSR output to latency as per probability distribution
always_comb begin
   if (hit) begin rlat = HIT_RLAT  ; end  // Hit
   else     begin rlat = MISS_RLAT ; end  // Miss     
end
assign hit = (lfsr_rout_rg < RTH) ;
assign lat = (IS_RLAT)? rlat : FIXED_LAT ; 

end//GENERATE: DMEM_NONZEROLAT_MODEL

endgenerate

endmodule
//###################################################################################################################################################
//                                                       D A T A   M E M O R Y   -   W R A P P E R                                         
//###################################################################################################################################################