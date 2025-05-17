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
//----%% File Name        : pqr5_subsystem_macros.svh
//----%% Module Name      : pqr5 Subsystem Macros                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This Header File contains all macros (constants/configurable) used by PQR5 Subsystem simulation.
//----%%
//----%% Tested on        : -
//----%% Last modified on : Apr-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                    P Q R 5   S U B S Y S T E M   M A C R O S                                             
//###################################################################################################################################################
`ifndef PQR5_SUBSYSTEM_MACROS_HEADER
`define PQR5_SUBSYSTEM_MACROS_HEADER

//---------------------------------------------------------------------------------------------------------------------------------------------------
// Generic constants - DO NOT MODIFY
//---------------------------------------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------------------------------------
// Configurable macros
//---------------------------------------------------------------------------------------------------------------------------------------------------
// Features
//`define EN_LOADER                    // Define this macro to generate Loader to program the core on the fly via UART
//`define COREMARK                     // Define this macro to enable Coremark Benchmarking

// On-board Test/Simulation environment INFO - define the parameters here
`define FCLK                 10                         // System clock speed targetted for on-board testing/simulation; in MHz
`define TCLK                 (1000.0/`FCLK)             // System clock period targetted for on-board testing/simulation; in ns
`define IRAM_SIZE            1024                       // Size of the generated IRAM; in bytes
`define IRAM_DW              32                         // Data width of the generated IRAM [CONSTANT]
`define IRAM_DEPTH           ((`IRAM_SIZE*8)/`IRAM_DW)  // Depth of the generated IRAM 
`define IRAM_AW              ($clog2(`IRAM_DEPTH))      // Address width of the generated IRAM
`define DRAM_SIZE            1024                       // Size of the generated DRAM; in bytes, max. 64kB
`define DRAM_DW              32                         // Data width of the generated DRAM [CONSTANT]
`define DRAM_DEPTH           ((`DRAM_SIZE*8)/`DRAM_DW)  // Depth of the generated IRAM
`define DRAM_AW              ($clog2(`DRAM_DEPTH))      // Address width of the generated DRAM

// Loader related (configuration of these macros are required only if EN_LOADER is enabled)
`define BAUDRATE             115200          // Baud rate @programming I/F; [shouldn't be faster than 1/16 FCLK]
                                             // Validate: 
                                             // 1. (FCLK in Hz/BAUDRATE) < 2^16
                                             // 2. BAUDRATE < (1/16)* FCLK in Hz
`define TIMEOUT             32'h5555_5555    // Max. Timeout in FCLK cycles during programming... Loader throws timeout error beyond this limit

// SYNTHESIS switch
//`define SUBSYS_SYNTH                         // Define this macro to configure the subsystem for SYNTHESIS

// Simulation control; all macros are qualified by global macro SUBSYS_DBG
`define SUBSYS_DBG                     // Define this macro to generate TB clock & reset internally for simulation; OVERRIDEN FOR SYNTHESIS
`define SYSCLK_PERIOD        `TCLK     // TB clock period in ns
`define SYSRST_LEN           20        // TB reset length in clock cycles
`define SIMLIMIT                       // Define this macro if subsystem simulation should be cycles limited
`define SIMCYCLES            100000    // If SIMLIMIT is enabled: Max. no. of clock cycles of simulation 

// Memory Dump during simulation
`define MEM_DBG                      // Define this macro to generate all debug ports in DMEM/IMEM for simulation; OVERRIDEN FOR SYNTHESIS
`define IMEM_DUMP            1       // If MEM_DBG: '1'- Dump IMEM content @end of simulation, '0'- Do not dump
`define DMEM_DUMP            1       // If MEM_DBG: '1'- Dump DMEM content @end of simulation, '0'- Do not dump

// DMEM Model to be generated for Simulation/Synthesis
`define DMEM_IS_ZERO_LAT     1       // '1'- Zero latency model with 100% Hit, '0'- Non-zero latency model
`define DMEM_IS_RLAT         1       // '1'- Random latency, '0'- Fixed latency --> These settings are only for Non-zero latency model
`define DMEM_HITRATE         90.0    // Hit rate % --> only for Random latency; latency on hit = 1 cycle
`define DMEM_MISS_RLAT       15      // Latency on miss = MISS_RLAT+1 cycles; range=[0-15]
`define DMEM_FIXED_LAT       1       // Fixed latency = FIXED_LAT+1 for hit/miss; range=[0-15]

// Debug UART 
`define DBGUART                              // Define this macro to enable Debug UART; SUPPORTED ONLY in DMEM Zero latency model
`define DBGUART_BRATE        115200          // Baud rate @programming I/F; [shouldn't be faster than 1/16 FCLK]
                                             // Validate: 
                                             // 1. (FCLK in Hz/BAUDRATE) < 2^16
                                             // 2. BAUDRATE < (1/16)* FCLK in Hz
//---------------------------------------------------------------------------------------------------------------------------------------------------

// SYNTHESIS override ............ //
`ifdef SUBSYS_SYNTH
`undef SUBSYS_DBG
`undef MEM_DBG
`endif
// SYNTHESIS override ............ //

// COREMARK override ..............//
`ifdef COREMARK
`undef SIMLIMIT
`undef DMEM_IS_ZERO_LAT
`define DMEM_IS_ZERO_LAT     1 
`ifndef DBGUART
`define DBGUART
`endif
`ifndef DBGUART_BRATE
`define DBGUART_BRATE        115200 
`endif
`endif
// COREMARK override ..............//

`endif
//###################################################################################################################################################
//                                                    P Q R 5   S U B S Y S T E M   M A C R O S                                             
//###################################################################################################################################################
