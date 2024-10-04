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
//----%% File Name        : cdc_sync.sv
//----%% Module Name      : CDC Synchronizer                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : CDC Synchronizer synchronizes 1-bit signal from src. clock domain safely to dest. clock domain.
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Jan-2024
//----%% Notes            : Attribute ASYNC_REG used to PAR the flops together in Xilinx FPGAs.
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                               C D C   S Y N C H R O N I Z E R                                         
//###################################################################################################################################################
module cdc_sync #(
   
   // Configurable parameters   
   parameter STAGES = 2             // No. of flops in the sync chain, min. 2
)

(
   input  logic clk        ,        // Clock @ destination clock domain
   input  logic rstn       ,        // Reset @ destination clock domain; this may be omitted if targetting FPGAs
   input  logic i_sig      ,        // Input signal, asynchronous
   output logic o_sig_sync          // Output signal synchronized to clk
) ;

(* ASYNC_REG = "TRUE" *)
logic [STAGES-1: 0] sync_ff ;

// Synchronizing logic
always @(posedge clk or negedge rstn) begin   
   if (!rstn) begin
      sync_ff <= '0 ;
   end
   else begin
      sync_ff <= {sync_ff [STAGES-2 : 0], i_sig} ;     
   end
end

// Synchronized signal
assign o_sig_sync = sync_ff [STAGES-1] ;

endmodule

//###################################################################################################################################################
//                                               C D C   S Y N C H R O N I Z E R                                         
//###################################################################################################################################################