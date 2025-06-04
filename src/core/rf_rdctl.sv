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
//----%% File Name        : rf_rdctl.sv
//----%% Module Name      : Register File Read Control                                         
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Glue logic that handles the reads to Register File (RF) of PQR5 core.   
//----%%
//----%% Tested on        : Basys-3 Artix-7 FPGA board, Vivado 2019.2 Synthesiser
//----%% Last modified on : June-2025
//----%% Notes            : - 
//----%%                  
//----%% Copyright        : Open-source license, see LICENSE.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         R F   R E A D   C O N T R O L                                    
//###################################################################################################################################################
module rf_rdctl (
   // Control from DU/Writeback
   input  logic       i_du_rf_rden  ,  // Read enable from DU
   input  logic [4:0] i_du_rs0      ,  // rs0 address decoded from DU
   input  logic [4:0] i_du_rs1      ,  // rs1 address decoded from DU
   input  logic [4:0] i_pkt2exu_rs0 ,  // rs0 address in the packet to EXU
   input  logic [4:0] i_pkt2exu_rs1 ,  // rs1 address in the packet to EXU
   input  logic       i_du_stall    ,  // DU stall
   input  logic [4:0] i_wbk_rdt     ,  // Writeback rdt address from WBU
   input  logic       i_wbk_en      ,  // Writeback enable from WBU

   // Read side control signals to RF
   output logic       o_rf_rden0    ,  // rs0 read enable
   output logic       o_rf_rden1    ,  // rs1 read enable
   output logic [4:0] o_rf_rs0_addr ,  // rs0 address
   output logic [4:0] o_rf_rs1_addr    // rs1 address
);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Readback
// --------
// If DU is stalled by EXU and writeback happened to the same register being read by DU in the same clock cycle, Operand Forward cannot 
// guarantee forwarding the data (from WBU to EXU) when the stall is released, because the upstream pipeline could be emptied already.
// In such cases, Register File should be read back during the stall to avoid stale value of the register being transferred to EXU.  
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
logic is_wbk_rdt_eq_pkt2exu_rs0, is_wbk_rdt_eq_pkt2exu_rs1;
logic rdbk_en_rs0, rdbk_en_rs1;

assign is_wbk_rdt_eq_pkt2exu_rs0 = (i_wbk_rdt == i_pkt2exu_rs0);          // Writeback reg & EXU packet's rs0 addresses match?
assign is_wbk_rdt_eq_pkt2exu_rs1 = (i_wbk_rdt == i_pkt2exu_rs1);          // Writeback reg & EXU packet's rs1 addresses match?
assign rdbk_en_rs0               = i_wbk_en & is_wbk_rdt_eq_pkt2exu_rs0;  // Readback rs0 enable
assign rdbk_en_rs1               = i_wbk_en & is_wbk_rdt_eq_pkt2exu_rs1;  // Readback rs1 enable

// Outputs to RF
assign o_rf_rden0    = i_du_stall? rdbk_en_rs0 : i_du_rf_rden ;             // Enable readback rs0 only if stalling 
assign o_rf_rden1    = i_du_stall? rdbk_en_rs1 : i_du_rf_rden ;             // Enable readback rs1 only if stalling
assign o_rf_rs0_addr = (i_du_stall && rdbk_en_rs0)? i_wbk_rdt : i_du_rs0 ;  // rs0 address
assign o_rf_rs1_addr = (i_du_stall && rdbk_en_rs1)? i_wbk_rdt : i_du_rs1 ;  // rs1 address

endmodule
//###################################################################################################################################################
//                                                         R F   R E A D   C O N T R O L                                    
//###################################################################################################################################################