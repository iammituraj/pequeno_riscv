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
//----%% File Name        : pqr5_subsystem_macros.svh
//----%% Module Name      : pqr5 Subsystem Macros                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This Header File contains all macros (constants/configurable) used by PQR5 Subsystem simulation.
//----%%
//----%% Tested on        : -
//----%% Last modified on : Feb-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : This code is licensed under the MIT License. See LICENSE.md for the full license text.
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
// Simulation related
`define SUBSYS_DBG                   // Define this macro to generate clock & reset internally for simulation; UNDEFINE FOR SYNTHESIS
`define SYSCLK_PERIOD        10      // Clock period in ns
`define SYSRST_LEN           100     // Reset length in cycles
//`define SIMLIMIT                     // Define this macro if simulation should be cycles limited
`define SIMCYCLES            1000    // Max. no. of clock cycles of simulation   

// Memory Dump
`define MEM_DBG                      // Define this macro to generate all debug ports in DMEM/IMEM for simulation; UNDEFINE FOR SYNTHESIS
`define IMEM_DUMP            1       // If MEM_DBG: '1'- Dump IMEM content @end of simulation, '0'- Do not dump; UNDEFINE FOR SYNTHESIS
`define DMEM_DUMP            1       // If MEM_DBG: '1'- Dump DMEM content @end of simulation, '0'- Do not dump; UNDEFINE FOR SYNTHESIS

// DMEM Model for Simulation/Synthesis
`define DMEM_DEPTH           256     // Depth of RAM; 2^N; range=[4-..] => Size = (DEPTH * 4) bytes
`define DMEM_IS_ZERO_LAT     1       // '1'- Zero latency model with 100% Hit, '0'- Non-zero latency model
`define DMEM_IS_RLAT         1       // '1'- Random latency, '0'- Fixed latency --> only for Non-zero latency model
`define DMEM_HITRATE         90.0    // Hit rate % --> only for Random latency; latency on hit = 1 cycle always 
`define DMEM_MISS_RLAT       15      // Latency on miss = MISS_RLAT+1 cycles; range=[0-15]
`define DMEM_FIXED_LAT       1       // Fixed latency = FIXED_LAT+1 for hit/miss; range=[0-15]
//---------------------------------------------------------------------------------------------------------------------------------------------------

`endif
//###################################################################################################################################################
//                                                    P Q R 5   S U B S Y S T E M   M A C R O S                                             
//###################################################################################################################################################