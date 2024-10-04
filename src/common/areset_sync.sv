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
//----%% File Name        : areset_sync.sv
//----%% Module Name      : Async Reset Synchronizer                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Async Reset Synchronizer synchronizes the de-assertion of asynchronous reset to the design's clock domain.    
//----%% 
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2018.3 Synthesiser
//----%% Last modified on : Aug-17-2022
//----%% Notes            : Attribute ASYNC_REG used to PAR the flops together in Xilinx FPGAs.
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.md
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                               A S Y N C   R E S E T   S Y N C H R O N I Z E R                                         
//###################################################################################################################################################
module areset_sync #(   
   // Configurable parameters   
   parameter STAGES  = 2    ,        // No. of flops in the synchronizer chain, min. 2
   parameter RST_POL = 1'b0          // Reset polarity
)

(
   input  logic clk         ,        // Clock @ destination clock domain   
   input  logic i_rst_async ,        // Asynchronous Reset in
   output logic o_rst_sync           // Asynchronous Reset with de-assertion synchronized
) ;

logic reset ;
assign reset = i_rst_async ^ RST_POL ;

(* ASYNC_REG = "TRUE" *)
logic [STAGES-1:0] sync_ff ;

// Synchronizing logic
always @(posedge clk or negedge reset) begin
   
   if (!reset) begin
      sync_ff <= {STAGES{RST_POL}} ;
   end
   else begin
      sync_ff <= {sync_ff[STAGES-2:0], ~RST_POL} ;     
   end  

end

// Synchronized reset
assign o_rst_sync = sync_ff[STAGES-1] ;

endmodule
//###################################################################################################################################################
//                                               A S Y N C   R E S E T   S Y N C H R O N I Z E R                                         
//###################################################################################################################################################