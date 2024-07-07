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
//----%% File Name        : pqr5_subsystem_pkg.sv
//----%% Module Name      : PQR5 Subsystem Package                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This Package contains all parameters/functions/tasks used by PQR5 Subsystem blocks.
//----%%
//----%% Tested on        : -
//----%% Last modified on : Feb-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                 P Q R 5   S U B S Y S T E M   P A C K A G E                                         
//###################################################################################################################################################
package pqr5_subsystem_pkg ;

// Packages imported
import pqr5_core_pkg :: hex2txtf ;
import pqr5_core_pkg :: DSIZE    ;

//===================================================================================================================================================
// Functions/Tasks
//===================================================================================================================================================
// Function to dump Memory content
function automatic void dump_mem (int fdump, int depth, int width, logic [DSIZE-1:0] ramarray [], string dumpname);      
   $fdisplay(fdump, "+======================================");
   $fdisplay(fdump, "| Pequeno RISC-V CPU v1.0 Simulation   ");
   $fdisplay(fdump, "+======================================");
   $fdisplay(fdump, "| %0s", dumpname);   
   $fdisplay(fdump, "+---------------+----------------------");
   $fdisplay(fdump, "| Address       | Data                 ");
   $fdisplay(fdump, "+---------------+----------------------");
   for (int d=0; d<depth; d++) begin       
       hex2txtf(fdump, width, d*4, "| 0x", "_", 4, "   : " );   // Print address
       hex2txtf(fdump, width, ramarray[d], "0x ", " ", 2, "");  // Print data
       $fwrite(fdump, "\n");
   end
   $fdisplay(fdump, "+======================================");   
endfunction
 
endpackage
//###################################################################################################################################################
//                                                 P Q R 5   S U B S Y S T E M   P A C K A G E                                         
//###################################################################################################################################################