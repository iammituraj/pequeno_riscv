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
//----%% File Name        : pqr5_subsystem_top.sv
//----%% Module Name      : PQR5 Subsystem Top                                         
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This subsystem integrates PQR5 Core with Instruction and Data RAM wrappers + Loader. 
//----%%                    The subsystem is ready to be implemented and tested on FPGA boards which support Block RAMs.
//----%%                    If block RAMs are not supported, RAMs will be implemented on the fabric.
//----%%                    # Instruction RAM (IRAM) wrapper consists of IRAM and IRAM Mux.
//----%%                    # Data RAM (DRAM) wrapper consists of DRAM and Debug UART.
//----%%                    # Instruction & Data RAMs are assumed to be loaded on reset with binary program to be executed.
//----%%                    # Dedicated Reset Controller to synchronize and distribute system reset.
//----%%                    # Configurability:
//----%%                      -- PC_INIT can be configured to start executing program from a specific address in IRAM after reset. 
//----%%                      -- All other configurability features in pqr5_core_macros/pqr5_subsystem_macros include files.    
//----%% 
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : Apr-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                      P Q R 5   S U B S Y S T E M   T O P                                         
//###################################################################################################################################################
`timescale 1ns/100ps

// Header files
`include "../include/pqr5_core_macros.svh"
`include "../include/pqr5_subsystem_macros.svh"

// Module definition
module pqr5_subsystem_top (
   `ifdef TEST_PORTS
   // Test Ports
   output logic [3:0] o_x31_tst   ,  // x31 bits: {x31[24], x31[16], x31[8], x31[0]}
   output logic       o_boot_flag ,  // Boot flag: flags that the core is out of reset and booted
   `endif

   `ifdef EN_LOADER
   // UART Programming I/F
   input  logic       i_uart_rx   ,  // UART Rx
   output logic       o_uart_tx   ,  // UART Tx
   
   // Status Signals
   output logic       o_pgmr_init     ,  // Programmer initialization; '1'- Initialized '0'- Not initialized
   output logic       o_pgmr_busy     ,  // Programmer busy; '1'- Busy '0'- Idle
   output logic       o_pgmr_done     ,  // Programming done 
   output logic       o_pgmr_err      ,  // Programming Error
   output logic [4:0] o_pgmr_err_code ,  // Programmer Error code
      
   // Control signals
   input  logic       i_halt_cpu  ,  // Halt CPU execution
   `endif

   `ifdef DBGUART
   // Debug UART I/F
   output logic       o_dbg_uart_tx ,  // UART Tx
   `endif

   // Clock and Reset  
   input  logic       clk         ,  // Clock
   input  logic       aresetn        // Asynchronous Reset; active-low
);

//===================================================================================================================================================
// Localparams
//===================================================================================================================================================

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================
// PQR5 Core - IRAM connections
logic [`XLEN-1:0] cpu_imem_pc          ;  // PC requested by CPU to IRAM 
logic             cpu_imem_pc_valid    ;  // PC request valid from CPU to IRAM
logic [`XLEN-1:0] cpu_imem_addr        ;  // PC from CPU to IRAM converted to word address 
logic             cpu_imem_addr_valid  ;  // Word address valid from CPU to IRAM
logic             imem_cpu_ready       ;  // IRAM ready to CPU
logic             imem_cpu_stall       ;  // Stall signal from IRAM to CPU
logic [`XLEN-1:0] imem_cpu_instr_pc    ;  // PC associated with instruction fetched by IRAM to CPU
logic [`ILEN-1:0] imem_cpu_instr       ;  // Instruction fetched by IRAM to CPU
logic             imem_cpu_instr_valid ;  // Instruction valid from IRAM to CPU
logic             cpu_imem_stall       ;  // Stall signal from CPU to IRAM
logic             cpu_imem_flush       ;  // Flush signal from CPU to IRAM

// PQR5 Core - DRAM connections
logic             cpu_dmem_wen         ;  // Write Enable from CPU to DRAM
logic [`XLEN-1:0] cpu_dmem_addr        ;  // Address from CPU to DRAM
logic [1:0]       cpu_dmem_size        ;  // Access size from CPU to DRAM
logic [`XLEN-1:0] cpu_dmem_wdata       ;  // Write-data from CPU to DRAM
logic             cpu_dmem_req         ;  // Request from CPU to DRAM
logic             dmem_cpu_ready       ;  // DRAM ready to CPU
logic             dmem_cpu_stall       ;  // Stall signal from DRAM to CPU
logic             cpu_dmem_flush       ;  // Flush signal from CPU to DRAM
logic [`XLEN-1:0] dmem_cpu_rdata       ;  // Read-data from DRAM to CPU
logic             dmem_cpu_ack         ;  // Acknowledge from DRAM to CPU
logic             cpu_dmem_stall       ;  // Stall signal from CPU to DRAM

// Clock and Reset
logic             sys_clk              ;  // System clock
logic             sys_reset_async      ;  // System reset before sync
logic             sys_reset_sync       ;  // System reset synced
`ifdef SUBSYS_DBG
logic             tb_clk               ;  // Test clock; for simulation only
logic             tb_resetn            ;  // Test reset; for simulation only
`endif

`ifdef EN_LOADER
logic             halt_cpu             ;  // Halt CPU
logic             ldr_cpu_stall        ;  // Stall signal from Loader to CPU while programming IRAM
// Loader - Reset Controller connections
logic             ldr_sys_reset        ;  // System reset request from Loader
logic             reset_ldr            ;  // Reset to Loader

// Loader - IRAM connections
logic [`IRAM_AW-1:0] ldr_iram_addr     ;  // Address
logic [`IRAM_DW-1:0] ldr_iram_wdata    ;  // Write Data
logic                ldr_iram_en       ;  // Access Enable
logic                ldr_iram_wen      ;  // Write Enable
logic [`IRAM_DW-1:0] ldr_iram_rdata    ;  // Read data

// Loader - DRAM connections
logic [`DRAM_AW-1:0] ldr_dram_addr     ;  // Address
logic [`DRAM_DW-1:0] ldr_dram_wdata    ;  // Write Data
logic                ldr_dram_en       ;  // Access Enable
logic                ldr_dram_wen      ;  // Write Enable
logic [`DRAM_DW-1:0] ldr_dram_rdata    ;  // Read data
`endif

logic                ext_cpu_stall     ;  // External stall to CPU
logic [31:0]         clktick_cnt_rg    ;  // Free-running clock tick counter

//===================================================================================================================================================
// Instances of submodules
//===================================================================================================================================================
`ifdef EN_LOADER  // Loader enabled
// Reset Controller
reset_ctl inst_reset_ctl (
   .clk                    (sys_clk)         ,
   .i_ext_resetn_async     (sys_reset_async) ,
   .i_aux_resetn           (ldr_sys_reset)   ,
   .o_resetn_sync_x2       (reset_ldr)       ,  // To loader
   .o_sys_resetn_sync_x4   ()                ,  // UNUSED as of now
   .o_sys_resetn_sync_x8   (sys_reset_sync)     // To Core + Mem subsystem     
);

// Loader
loader inst_loader (
   .clk             (sys_clk)       ,  
   .aresetn         (reset_ldr)     ,

   .i_halt_cpu      (halt_cpu)      ,  
   .o_ldr_cpu_stall (ldr_cpu_stall) ,
   .o_ldr_cpu_reset (ldr_sys_reset) ,

   .o_init_done     (o_pgmr_init)     ,
   .o_busy          (o_pgmr_busy)     ,
   .o_pgm_done      (o_pgmr_done)     ,
   .o_err           (o_pgmr_err)      ,
   .o_err_code      (o_pgmr_err_code) ,

   .i_uart_rx       (i_uart_rx) , 
   .o_uart_tx       (o_uart_tx) ,

   .o_iram_addr     (ldr_iram_addr)  ,     
   .o_iram_wdata    (ldr_iram_wdata) ,  
   .o_iram_en       (ldr_iram_en)    ,
   .o_iram_wen      (ldr_iram_wen)   ,
   .i_iram_rdata    (ldr_iram_rdata) ,

   .o_dram_addr     (ldr_dram_addr)  ,
   .o_dram_wdata    (ldr_dram_wdata) ,
   .o_dram_en       (ldr_dram_en)    ,
   .o_dram_wen      (ldr_dram_wen)   ,
   .i_dram_rdata    (ldr_dram_rdata) 
);
`else  // No Loader enabled
// Reset Controller 
reset_ctl inst_reset_ctl (
   .clk                    (sys_clk)         ,
   .i_ext_resetn_async     (sys_reset_async) ,
   .i_aux_resetn           (1'b1)            ,
   .o_resetn_sync_x2       (reset_ldr)       ,
   .o_sys_resetn_sync_x4   ()                ,  // UNUSED as of now
   .o_sys_resetn_sync_x8   (sys_reset_sync)          
);
`endif

// PQR5 Core/CPU
pqr5_core_top #(
   .PC_INIT (`PC_INIT)
)  inst_pqr5_core_top (
   .clk              (sys_clk)              ,
   .aresetn          (sys_reset_sync)       ,

   `ifdef TEST_PORTS
   .o_x31_tst        (o_x31_tst)            ,
   .o_boot_flag      (o_boot_flag)          ,
   `endif

   .i_ext_stall      (ext_cpu_stall)        ,
   
   .o_imem_pc        (cpu_imem_pc)          ,
   .o_imem_pc_valid  (cpu_imem_pc_valid)    ,
   .i_imem_stall     (imem_cpu_stall)       ,

   .i_imem_pc        (imem_cpu_instr_pc)    ,
   .i_imem_pkt       (imem_cpu_instr)       ,
   .i_imem_pkt_valid (imem_cpu_instr_valid) ,
   .o_imem_stall     (cpu_imem_stall)       ,
   .o_imem_flush     (cpu_imem_flush)       ,

   .o_dmem_wen       (cpu_dmem_wen)         ,
   .o_dmem_addr      (cpu_dmem_addr)        ,
   .o_dmem_size      (cpu_dmem_size)        ,
   .o_dmem_wdata     (cpu_dmem_wdata)       ,
   .o_dmem_req       (cpu_dmem_req)         ,
   .i_dmem_stall     (dmem_cpu_stall)       ,
   .o_dmem_flush     (cpu_dmem_flush)       ,
   .i_dmem_rdata     (dmem_cpu_rdata)       ,
   .i_dmem_ack       (dmem_cpu_ack)         ,
   .o_dmem_stall     (cpu_dmem_stall)
);

// IRAM Wrapper
imem_top inst_imem_top (
   .clk              (sys_clk)        ,
   .aresetn          (sys_reset_sync) ,

   `ifdef EN_LOADER  
   .i_pgm_en         (ldr_cpu_stall)  ,
   .i_pgm_iram_addr  (ldr_iram_addr)  ,
   .i_pgm_iram_wdata (ldr_iram_wdata) ,
   .i_pgm_iram_en    (ldr_iram_en)    ,
   .i_pgm_iram_wen   (ldr_iram_wen)   ,
   .o_pgm_iram_rdata (ldr_iram_rdata) ,
   `else  // No Loader => tie all input ports to 1'b0...
   .i_pgm_en         (1'b0)           ,
   .i_pgm_iram_addr  ('0)             ,
   .i_pgm_iram_wdata ('0)             ,
   .i_pgm_iram_en    (1'b0)           ,
   .i_pgm_iram_wen   (1'b0)           ,
   .o_pgm_iram_rdata ()               ,
   `endif

   .i_reqid          (cpu_imem_pc)        ,
   .o_reqid          (imem_cpu_instr_pc)  ,
   .i_flush          (cpu_imem_flush)     ,

   .i_addr           (cpu_imem_addr)        ,
   .i_valid          (cpu_imem_addr_valid)  ,
   .o_ready          (imem_cpu_ready)       ,   
   .o_data           (imem_cpu_instr)       ,
   .o_valid          (imem_cpu_instr_valid) ,
   .i_ready          (~cpu_imem_stall)
);

// DRAM Wrapper
dmem_top #(
   .RAM_DEPTH   (`DRAM_DEPTH)       ,     
   .IS_ZERO_LAT (`DMEM_IS_ZERO_LAT) ,
   .IS_RLAT     (`DMEM_IS_RLAT)     ,    
   .HITRATE     (`DMEM_HITRATE)     ,   
   .MISS_RLAT   (`DMEM_MISS_RLAT)   ,  
   .FIXED_LAT   (`DMEM_FIXED_LAT)  
)  inst_dmem_top (
   .clk     (sys_clk)         ,
   .aresetn (sys_reset_sync)  ,

   `ifdef DBGUART
   .o_uart_tx (o_dbg_uart_tx) ,
   `endif

   .i_clktick_cnt    (clktick_cnt_rg) ,

   `ifdef EN_LOADER  
   .i_pgm_en         (ldr_cpu_stall)  ,
   .i_pgm_dram_addr  (ldr_dram_addr)  ,
   .i_pgm_dram_wdata (ldr_dram_wdata) ,
   .i_pgm_dram_en    (ldr_dram_en)    ,
   .i_pgm_dram_wen   (ldr_dram_wen)   ,
   .o_pgm_dram_rdata (ldr_dram_rdata) ,
   `else  // No Loader => tie all input ports to 1'b0...
   .i_pgm_en         (1'b0)           ,
   .i_pgm_dram_addr  ('0)             ,
   .i_pgm_dram_wdata ('0)             ,
   .i_pgm_dram_en    (1'b0)           ,
   .i_pgm_dram_wen   (1'b0)           ,
   .o_pgm_dram_rdata ()               ,
   `endif

   .i_wen   (cpu_dmem_wen)    ,
   `ifdef BENCHMARK
   .i_addr  ({1'b0, cpu_dmem_addr[30:0]}),  // For Benchmark programs, Linker reserved the baseaddr 0x8000_0000 for Data Memory 
   `else
   .i_addr  (cpu_dmem_addr)   ,
   `endif
   .i_size  (cpu_dmem_size)   ,
   .i_data  (cpu_dmem_wdata)  ,
   .i_req   (cpu_dmem_req)    ,
   .o_ready (dmem_cpu_ready)  ,
   .i_flush (cpu_dmem_flush)  ,
   .o_data  (dmem_cpu_rdata)  ,
   .o_ack   (dmem_cpu_ack)    ,
   .i_ready (~cpu_dmem_stall)
);

//===================================================================================================================================================
// Clock and Reset block
//===================================================================================================================================================
`ifndef SUBSYS_DBG
assign sys_clk         = clk        ;
assign sys_reset_async = aresetn    ;
`ifdef EN_LOADER
assign halt_cpu        = i_halt_cpu ;
`endif
`else 
// Clocking
initial begin 
   $display("| PQR5_SIM_SUBS: [INFO ] Clocking @period = %0d ns", `SYSCLK_PERIOD);
   tb_clk = 1'b0 ;
   forever #(`SYSCLK_PERIOD/2.0) tb_clk = ~tb_clk;   
end

// Reset
initial begin
   tb_resetn = 1'b0 ;
   $display("| PQR5_SIM_SUBS: [INFO ] Reset asserted @t = %0t ns", $time);
   #(`SYSRST_LEN * `SYSCLK_PERIOD);
   tb_resetn = 1'b1 ;
   $display("| PQR5_SIM_SUBS: [INFO ] Reset deasserted @t = %0t ns", $time);
   `ifdef SIMLIMIT
   #(`SYSCLK_PERIOD * (`SIMCYCLES + 1));
   $display("| PQR5_SIM_SUBS: [INFO ] Simulation exit triggered @t = %0t ns", $time);
   $finish;
   `endif
end

assign sys_clk         = tb_clk      ;
assign sys_reset_async = tb_resetn   ;
`ifdef EN_LOADER
assign halt_cpu        = (i_halt_cpu === 1'bz)? 1'b0 :        // Connect pull-down to i_halt_cpu I/P to avoid floating, 
                         (i_halt_cpu == 1'b0)? 1'b0 : 1'b1 ;  // User can still drive to '1' or '0' if reqd during simulation... 
`endif 

`ifdef DUMPVCD
// VCD dump
initial begin
   $dumpfile("sim.vcd");
   $dumpvars(0, pqr5_subsystem_top);
end
`endif

`endif

//===================================================================================================================================================
// All continuous assignments
//===================================================================================================================================================
assign imem_cpu_stall      = ~imem_cpu_ready ;
assign cpu_imem_addr       = {2'b0, cpu_imem_pc[31:2]} ;  // IRAM has word-addressing, but CPU has byte-addressing 
assign cpu_imem_addr_valid = cpu_imem_pc_valid ;
assign dmem_cpu_stall      = ~dmem_cpu_ready ;
`ifdef EN_LOADER 
assign ext_cpu_stall       = ldr_cpu_stall ;
`else
assign ext_cpu_stall       = 1'b0 ;
`endif

//===================================================================================================================================================
// Free-running clock tick counter (Used for debug purpose)
//===================================================================================================================================================
always @(posedge sys_clk or negedge sys_reset_sync) begin
   if (!sys_reset_sync) begin
      clktick_cnt_rg <= 32'h0 ;   
   end 
   else begin
      clktick_cnt_rg <= clktick_cnt_rg + 32'd1; 
   end
end

endmodule
//###################################################################################################################################################
//                                                      P Q R 5   S U B S Y S T E M   T O P                                         
//###################################################################################################################################################