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
//----%% File Name        : reset_ctl.sv
//----%% Module Name      : Reset Controller                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This is a tailor-made reset controller for PQR5 Subsystem.
//----%%                    It accepts an external asynchronous reset at input and generates resets with de-assertion synced with clock.
//----%%                    - Generates x4 and x8 clocks stretched sync resets at output for system reset.
//----%%                    - Generates x2 clocks stretched sync reset at output for Loader.
//----%%                    - Support auxiliary reset input for soft reset generated from Loader. 
//----%%                    - All resets are active-low.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Jan-2024
//----%% Notes            : External reset is assumed to be glitch-free.
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         R E S E T   C O N T R O L L E R                                         
//###################################################################################################################################################
module reset_ctl (
   input  logic clk                    ,  // Clock; resets will be synced to this clock for de-assertion       
   input  logic i_ext_resetn_async     ,  // Asynchronous external reset in
   input  logic i_aux_resetn           ,  // Auxiliary reset in
   output logic o_resetn_sync_x2       ,  // x2 sync stretched sync reset out
   output logic o_sys_resetn_sync_x4   ,  // x4 clocks stretched sync system reset out
   output logic o_sys_resetn_sync_x8      // x8 clocks stretched sync system reset out
);

// System reset
// No glitches are expected to happen in auxiliary reset as it's assumed to be driven by a register... single cycle pulse is enough...
logic sys_resetn ;
assign sys_resetn = i_ext_resetn_async & i_aux_resetn ;

//===================================================================================================================================================
// Internal Registers/Signals
//===================================================================================================================================================

// ARESET Synchronizer for x2 reset
areset_sync #(     
   .STAGES  (2)    ,        
   .RST_POL (1'b0)         
)  inst_reset_sync_n_x4 (
   .clk         (clk)                ,         
   .i_rst_async (i_ext_resetn_async) ,
   .o_rst_sync  (o_resetn_sync_x2)      
);

// ARESET Synchronizer for x4 reset
areset_sync #(     
   .STAGES  (4)    ,        
   .RST_POL (1'b0)         
)  inst_sys_resetn_sync_x4 (
   .clk         (clk)        ,         
   .i_rst_async (sys_resetn) ,
   .o_rst_sync  (o_sys_resetn_sync_x4)      
);

// ARESET Synchronizer for x8 reset
areset_sync #(     
   .STAGES  (8)    ,        
   .RST_POL (1'b0)         
)  inst_sys_resetn_sync_x8 (
   .clk         (clk)        ,         
   .i_rst_async (sys_resetn) ,
   .o_rst_sync  (o_sys_resetn_sync_x8)      
);

endmodule
//###################################################################################################################################################
//                                                         R E S E T   C O N T R O L L E R                                         
//###################################################################################################################################################