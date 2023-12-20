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
//----%% File Name        : pqr5_core_pkg.sv
//----%% Module Name      : PQR5 Core Package                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : This Package contains all parameters/functions/tasks used by PQR5 Core blocks.
//----%%
//----%% Tested on        : -
//----%% Last modified on : Mar-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : This code is licensed under the MIT License. See LICENSE.md for the full license text.
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         P Q R 5   C O R E   P A C K A G E                                         
//###################################################################################################################################################
// Header files
`include "../include/pqr5_core_macros.svh"
`include "../include/pqr5_subsystem_macros.svh"

// Package definition
package pqr5_core_pkg ;

//===================================================================================================================================================
// Register and Memory access - Localparams
//===================================================================================================================================================
localparam int   RSIZE  = `XLEN ;  // Register size
localparam int   DSIZE  = RSIZE ;  // Max. size of data 2^N processed by core/subsystem -- used ONLY for debugging
localparam [1:0] BYTE   = 2'b00 ;  // Encoding for BYTE access
localparam [1:0] HWORD  = 2'b01 ;  // Encoding for Half-word access
localparam [1:0] WORD   = 2'b10 ;  // Encoding for Word access

//===================================================================================================================================================
// Opcodes - Localparams
//===================================================================================================================================================
localparam [6:0] OP_LUI     = 7'b011_0111 ;  // 0x37
localparam [6:0] OP_AUIPC   = 7'b001_0111 ;  // 0x17
localparam [6:0] OP_JAL     = 7'b110_1111 ;  // 0x6F
localparam [6:0] OP_JALR    = 7'b110_0111 ;  // 0x67
localparam [6:0] OP_BRANCH  = 7'b110_0011 ;  // 0x63
localparam [6:0] OP_LOAD    = 7'b000_0011 ;  // 0x03
localparam [6:0] OP_STORE   = 7'b010_0011 ;  // 0x23
localparam [6:0] OP_ALU     = 7'b011_0011 ;  // 0x33
localparam [6:0] OP_ALUI    = 7'b001_0011 ;  // 0x13

//===================================================================================================================================================
// funct3 - Localparams
//===================================================================================================================================================
localparam [2:0] F3_ADDX  = 3'b000 ;
localparam [2:0] F3_SUB   = 3'b000 ;
localparam [2:0] F3_SLTX  = 3'b010 ;
localparam [2:0] F3_SLTUX = 3'b011 ;
localparam [2:0] F3_XORX  = 3'b100 ;
localparam [2:0] F3_ORX   = 3'b110 ;
localparam [2:0] F3_ANDX  = 3'b111 ;
localparam [2:0] F3_SLLX  = 3'b001 ;
localparam [2:0] F3_SRXX  = 3'b101 ;

localparam [2:0] F3_JALR = 3'b000 ;
localparam [2:0] F3_BEQ  = 3'b000 ;
localparam [2:0] F3_BNE  = 3'b001 ;
localparam [2:0] F3_BLT  = 3'b100 ;
localparam [2:0] F3_BGE  = 3'b101 ;  
localparam [2:0] F3_BLTU = 3'b110 ;
localparam [2:0] F3_BGEU = 3'b111 ;

localparam [2:0] F3_LB   = 3'b000 ;
localparam [2:0] F3_LH   = 3'b001 ;
localparam [2:0] F3_LW   = 3'b010 ;
localparam [2:0] F3_LBU  = 3'b100 ;
localparam [2:0] F3_LHU  = 3'b101 ;
localparam [2:0] F3_SB   = 3'b000 ;
localparam [2:0] F3_SH   = 3'b001 ;
localparam [2:0] F3_SW   = 3'b010 ;

//===================================================================================================================================================
// ALU Opcodes - Localparams
//===================================================================================================================================================
localparam [3:0] ALU_ADD  = 4'b0000 ;
localparam [3:0] ALU_SUB  = 4'b0001 ;
localparam [3:0] ALU_SLT  = 4'b0100 ;
localparam [3:0] ALU_SLTU = 4'b0110 ;
localparam [3:0] ALU_XOR  = 4'b1000 ;
localparam [3:0] ALU_OR   = 4'b1100 ;
localparam [3:0] ALU_AND  = 4'b1110 ;
localparam [3:0] ALU_SLL  = 4'b0010 ;
localparam [3:0] ALU_SRL  = 4'b1010 ;
localparam [3:0] ALU_SRA  = 4'b1011 ;
localparam [3:0] ALU_ILLG = 4'b1111 ;  // Illegal opcode

//===================================================================================================================================================
// Functions/Tasks
//===================================================================================================================================================
// Task to display simulation header
task disp_simheader ();
   $display("");
   $display("//////////////////////////////////////////////////////////////////");
   $display("//  chipmunklogic.com                      O P E N S O U R C E  //"); 
   $display("//////////////////////////////////////////////////////////////////");    
   $display("// +==========================================================+ //"); 
   $display("// |              Pequeno RISC-V CPU - Simulation             | //");
   $display("// +==========================================================+ //");
   $display("// | Version   : %-044s | //", `VERS);
   $display("// | ISA       : %-044s | //", `ISA);
   $display("// | PC_INIT   : %-044s | //", rhex2txt(32, `PC_INIT));
   `ifdef DBG
   $display("// | DBG       : %-044s | //", "YES");
   `else
   $display("// | DBG       : %-044s | //", "NO");
   `endif
   `ifdef MEM_DBG
   $display("// | MEM_DBG   : %-044s | //", "YES");
   `else
   $display("// | MEM_DBG   : %-044s | //", "NO");
   `endif
   $display("// | REGF dump : %-044s | //", ynstatus(`REGFILE_DUMP));
   $display("// | IMEM dump : %-044s | //", ynstatus(`IMEM_DUMP));
   $display("// | DMEM dump : %-044s | //", ynstatus(`DMEM_DUMP));
   `ifdef SIMLIMIT
   $display("// | SIMLIMIT  : %-044s | //", "YES");
   `else
   $display("// | SIMLIMIT  : %-044s | //", "NO");
   `endif
   $display("// +==========================================================+ //");
   $display("//////////////////////////////////////////////////////////////////");
   $display(""); 
endtask

// Function to convert hex to text for printing in file: [prefix][data with separator][suffix]
function automatic void hex2txtf (int fptr, int size, logic [DSIZE-1:0] hexval, string prefix = "32'h", string sep = "_", int sepnib = 4, string suffix = "");
   // Variables
   int nibbles = (size/4) + (size%4 != 0) ;
   int zp_size = nibbles * 4 ;
   int msb     = zp_size - 1 ;
   int i, j ;
   string hexstr = "x" ;
   
   // Iterate thru each nibble and print   
   $fwrite(fptr, "%0s", prefix);    // Print prefix
   for (i=msb, j=1; i>=3; i-=4, j+=1) begin
       logic x_check = ^hexval[i-:4] ;
       if (x_check !== 1'bx) hexstr.hextoa(hexval[i-:4]);              
       $fwrite(fptr, "%0s", hexstr.toupper());                      // Print data in HEX string   
       if ((j%sepnib == 0) && (i != 3)) $fwrite(fptr, "%0s", sep);  // Print separator
   end
   $fwrite(fptr, "%0s", suffix);  // Print suffix
endfunction

// Function to convert hex to text for printing in stdio [prefix][data with separator][suffix]
function automatic void hex2txt (int size, logic [DSIZE-1:0] hexval, string prefix = "32'h", string sep = "_", int sepnib = 4, string suffix = "");
   // Variables
   int nibbles = (size/4) + (size%4 != 0) ;
   int zp_size = nibbles * 4 ;
   int msb     = zp_size - 1 ;
   int i, j ;
   string hexstr = "x" ;
   
   // Iterate thru each nibble and print
   $write("%0s", prefix);  // Print prefix
   for (i=msb, j=1; i>=3; i-=4, j+=1) begin
         logic x_check = ^hexval[i-:4] ;
         if (x_check !== 1'bx) hexstr.hextoa(hexval[i-:4]);
   	   $write("%0s", hexstr.toupper());                      // Print data in HEX string          
   	   if ((j%sepnib == 0) && (i != 3)) $write("%0s", sep);  // Print separator
   end
   $write("%0s", suffix);  // Print suffix
endfunction

// Function to convert hex to text and return string [prefix][data with separator][suffix]
function automatic string rhex2txt (int size, logic [DSIZE-1:0] hexval, string prefix = "32'h", string sep = "_", int sepnib = 4, string suffix = "");
   // Variables
   int nibbles = (size/4) + (size%4 != 0) ;
   int zp_size = nibbles * 4 ;
   int msb     = zp_size - 1 ;
   int i, j ;
   string hexstr = "x" ;
   string txtstr = prefix ;
   
   // Iterate thru each nibble and append
   for (i=msb, j=1; i>=3; i-=4, j+=1) begin
         logic x_check = ^hexval[i-:4] ;
         if (x_check !== 1'bx) hexstr.hextoa(hexval[i-:4]);
         txtstr = {txtstr, hexstr.toupper()} ;  // Append nibble         
         if ((j%sepnib == 0) && (i != 3)) txtstr = {txtstr, sep} ;  // Append separator
   end
   return {txtstr, suffix} ;  // Append suffix and return
endfunction

// Function to dump Register File
function automatic void dump_regfile (int fdump, int n, logic [RSIZE-1:0] regarray [], string dumpname);      
   $fdisplay(fdump, "+======================================");
   $fdisplay(fdump, "| Pequeno RISC-V CPU v1.0 Simulation   ");
   $fdisplay(fdump, "+======================================");
   $fdisplay(fdump, "| %0s", dumpname);
   $fdisplay(fdump, "+--------------------------------------");
   for (int r=0; r<n; r++) begin       
       $fwrite(fdump, "| R%-2d", r, " : ");  // Print reg ID
       hex2txtf(fdump, RSIZE, regarray[r]);  // Print reg data
       $fwrite(fdump, "\n");
   end
   $fdisplay(fdump, "+======================================");   
endfunction

// Function to display Register File
function automatic void disp_regfile (logic [RSIZE-1:0] regarray []);
   int i = 0 ;
   $display("+================================================================+");
   $display("| REGFILE                                                        |");
   $display("+================================================================+");
   $write  ("| R0-3   :");
   while (i<4) begin hex2txt (32, regarray[i], " 0x", "_", 4, " |"); i=i+1 ; end 
   $write  ("\n");
   $write  ("| R4-7   :");
   while (i<8) begin hex2txt (32, regarray[i], " 0x", "_", 4, " |"); i=i+1 ; end
   $write  ("\n");
   $write  ("| R8-11  :");
   while (i<12) begin hex2txt (32, regarray[i], " 0x", "_", 4, " |"); i=i+1 ; end
   $write  ("\n");
   $write  ("| R12-15 :");
   while (i<16) begin hex2txt (32, regarray[i], " 0x", "_", 4, " |"); i=i+1 ; end
   $write  ("\n");
   $write  ("| R16-19 :");
   while (i<20) begin hex2txt (32, regarray[i], " 0x", "_", 4, " |"); i=i+1 ; end
   $write  ("\n");
   $write  ("| R20-23 :");
   while (i<24) begin hex2txt (32, regarray[i], " 0x", "_", 4, " |"); i=i+1 ; end
   $write  ("\n");
   $write  ("| R24-27 :");
   while (i<28) begin hex2txt (32, regarray[i], " 0x", "_", 4, " |"); i=i+1 ; end
   $write  ("\n");
   $write  ("| R28-31 :");
   while (i<32) begin hex2txt (32, regarray[i], " 0x", "_", 4, " |"); i=i+1 ; end
   $write  ("\n");
   $display("+================================================================+");
endfunction

// Function to return YES/NO/-/NA
function automatic string ynstatus (bit [1:0] val, string ystr = "YES", string nstr = "NO");
   if      (val == 2'b00) return nstr  ;
   else if (val == 2'b01) return ystr  ;
   else if (val == 2'b10) return "--"  ;
   else                   return "NA"  ;
endfunction

// Function to return instruction type
function automatic string instrtype (bit [5:0] instr_type, logic valid);
   if (valid) begin
      if      (instr_type [5]) return "R-type, ALU"    ;
      else if (instr_type [4]) return "I-type"         ;
      else if (instr_type [3]) return "S-type, STORE"  ;
      else if (instr_type [2]) return "B-type, BRANCH" ;
      else if (instr_type [1]) return "U-type"         ;
      else if (instr_type [0]) return "J-type, JAL"    ;
   end
   else begin
      return "--" ; 
   end
endfunction

// Function to return memory access type
function automatic string memacctype (logic[1:0] size, logic cmd, logic valid);
   if (valid) begin
      if (cmd) begin
         if      (size == 2'b00) return "8-bit, Store"  ;   
         else if (size == 2'b01) return "16-bit, Store" ;  
         else                    return "32-bit, Store" ;   
      end
      else begin
         if      (size == 2'b00) return "8-bit, Load"   ;   
         else if (size == 2'b01) return "16-bit, Load"  ;  
         else                    return "32-bit, Load"  ;   
      end
   end
   else begin
      return "--" ;
   end
endfunction

endpackage
//###################################################################################################################################################
//                                                         P Q R 5   C O R E   P A C K A G E                                         
//###################################################################################################################################################