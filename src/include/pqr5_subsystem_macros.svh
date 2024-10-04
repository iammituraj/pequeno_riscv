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
//----%% Last modified on : Jan-2024
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see developer.txt.
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

// On-board test/simulation environment INFO - define the test environment parameters here
`define FCLK                 10                     // System clock speed targetted for on-board testing/simulation; in MHz
`define TCLK                 (1000.0/`FCLK)         // System clock period targetted for on-board testing/simulation; in ns
`define IRAM_DEPTH           256                    // Depth of the generated I-RAM; Size = (I_RAM_DEPTH * 4) bytes
`define IRAM_AW              ($clog2(`IRAM_DEPTH))  // Address width of the generated I-RAM
`define IRAM_DW              32                     // Data width of the generated I-RAM; should be 32-bit
`define DRAM_DEPTH           256                    // Depth of the generated D-RAM; 2^N; range=[4-16384] => Size = (DEPTH * 4) bytes;
`define DRAM_AW              ($clog2(`DRAM_DEPTH))  // Address width of the generated D-RAM
`define DRAM_DW              32                     // Data width of the generated D-RAM; should be 32-bit

// Loader related (configuration required only if EN_LOADER is enabled)
`define BAUDRATE             115200          // Baud rate @programming I/F; [shouldn't be faster than 1/16 FCLK]
                                             // Validate: 
                                             // 1. (FCLK in Hz/BAUDRATE) < 2^16
                                             // 2. BAUDRATE < (1/16)* FCLK in Hz
`define TIMEOUT             32'h5555_5555    // Max. Timeout in FCLK cycles during programming... Loader throws timeout error beyond this limit

// SYNTHESIS switch
//`define SUBSYS_SYNTH                         // Define this macro to override sim macros, and configure the subsystem for SYNTHESIS

// Simulation control; all macro definition enabled by global macro SUBSYS_DBG
`define SUBSYS_DBG                     // Define this macro to generate TB clock & reset internally for simulation; UNDEFINE FOR SYNTHESIS
`define SYSCLK_PERIOD        `TCLK     // TB clock period in ns
`define SYSRST_LEN           100       // TB reset length in clock cycles
`define SIMLIMIT                       // Define this macro if subsystem simulation should be cycles limited
`define SIMCYCLES            30000     // If SIMLIMIT is enabled: Max. no. of clock cycles of simulation 

// Memory Dump during simulation
`define MEM_DBG                      // Define this macro to generate all debug ports in DMEM/IMEM for simulation; UNDEFINE FOR SYNTHESIS
`define IMEM_DUMP            1       // If MEM_DBG: '1'- Dump IMEM content @end of simulation, '0'- Do not dump
`define DMEM_DUMP            1       // If MEM_DBG: '1'- Dump DMEM content @end of simulation, '0'- Do not dump

// DMEM Model to be generated for Simulation/Synthesis
`define DMEM_IS_ZERO_LAT     1       // '1'- Zero latency model with 100% Hit, '0'- Non-zero latency model
`define DMEM_IS_RLAT         1       // '1'- Random latency, '0'- Fixed latency --> These settings are only for Non-zero latency model
`define DMEM_HITRATE         90.0    // Hit rate % --> only for Random latency; latency on hit = 1 cycle always 
`define DMEM_MISS_RLAT       15      // Latency on miss = MISS_RLAT+1 cycles; range=[0-15]
`define DMEM_FIXED_LAT       1       // Fixed latency = FIXED_LAT+1 for hit/miss; range=[0-15]

// Debug UART 
//`define DBGUART                              // Define this macro to enable Debug UART; SUPPORTED ONLY in DMEM Zero latency model
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
// SYNTHESIS override .......--... //

`endif
//###################################################################################################################################################
//                                                    P Q R 5   S U B S Y S T E M   M A C R O S                                             
//###################################################################################################################################################