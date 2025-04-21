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
//----%% File Name        : pqr5_core_macros.svh
//----%% Module Name      : PQR5 Core Macros                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This Header file contains all macros (constants/configurable) used by PQR5 Core source files.
//----%%
//----%% Tested on        : -
//----%% Last modified on : Apr-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         P Q R 5   C O R E   M A C R O S                                             
//###################################################################################################################################################
`ifndef PQR5_CORE_MACROS_HEADER
`define PQR5_CORE_MACROS_HEADER

//---------------------------------------------------------------------------------------------------------------------------------------------------
// Generic constants - DO NOT MODIFY
//---------------------------------------------------------------------------------------------------------------------------------------------------
`define CPU           "Pequeno RISC-V"
`define VERS          "v1.0"
`define ISA           "RV32I"

`define XLEN          32                   // Size of register
`define ILEN          32                   // Size of instruction

`define XLSB          $clog2(`XLEN/8)-1:0  // Least significant addressing bits in XLEN addressing space

// Instructions
`define INSTR_NOP     32'h0000_0013        // NOP pseudo-instruction
`define INSTR_END     32'hEEE0_0013        // END simulation instruction (mvi x0, 0xEEE); known only by sim framework, not Assembler
//---------------------------------------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------------------------------------
// Configurable macros
//---------------------------------------------------------------------------------------------------------------------------------------------------
`define PC_INIT       32'h0000_0000       // PC init address after CPU reset i.e., the reset vector (32-bit aligned address)
//`define TEST_PORTS                        // Define this macro to generate test ports from core: x31 bits, boot flag
//`define CORE_SYNTH                        // Define this macro to configure the core for SYNTHESIS
`define DBG                               // Define this macro to generate all debug modules/interfaces for simulation; UNDEFINE FOR SYNTHESIS
//`define DBG_PRINT                         // If DBG is enabled: Define this macro to display per-cycle debug messages; UNDEFINE FOR SYNTHESIS
`define SIMEXIT_INSTR_END                 // Define this macro to exit simulation on receiving END simulation instruction; UNDEFINE FOR SYNTHESIS
`define REGFILE_DUMP  1                   // If DBG is enabled: '1'- Dump Register File @end of simulation, '0'- Do not dump; '0' FOR SYNTHESIS
//---------------------------------------------------------------------------------------------------------------------------------------------------

// SYNTHESIS override ............ //
`ifdef CORE_SYNTH
`undef DBG
`undef DBG_PRINT
`undef SIMEXIT_INSTR_END
`undef REGFILE_DUMP
`define REGFILE_DUMP 0
`endif
// SYNTHESIS override ............ //

`endif
//###################################################################################################################################################
//                                                         P Q R 5   C O R E   M A C R O S                                             
//###################################################################################################################################################
