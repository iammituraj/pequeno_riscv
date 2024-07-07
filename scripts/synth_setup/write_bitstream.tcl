###################################################################################################
# ╔═╦╗╔╗─────────╔╗─╔╗────╔╗
# ║╔╣╚╬╬═╦══╦╦╦═╦╣╠╗║║╔═╦═╬╬═╗
# ║╚╣║║║╬║║║║║║║║║═╣║╚╣╬║╬║║═╣ /////////////// O P E N S O U R C E 
# ╚═╩╩╩╣╔╩╩╩╩═╩╩═╩╩╝╚═╩═╬╗╠╩═╝                                                  
# ─────╚╝───────────────╚═╝                                                     chipmunklogic.com
###################################################################################################
# Script : To program FPGA with bitfile using Vivado HW manager
# Author : Mitu Raj, chip@chipmunklogic.com 
# Date   : July-2024
# Notes  : Tested with Vivado 2019.2, Digilent FPGAs
###################################################################################################
# Open Vivado HW manager
open_hw_manager

############## CONFIGURE your test setup ###############
# Server, Bit file
set myserver "localhost:3121"
set hostname "Digilent/210328B799B6A"
set bitfile "./bitfile_output/pqr5_subsystem_top.bit"
############# END OF CONFIGURATION #####################

# Connect to server
connect_hw_server -url $myserver
current_hw_target [get_hw_targets */xilinx_tcf/$hostname]
open_hw_target

# Connect to the FPGA device
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices] 0]

# Set bit file
set_property PROGRAM.FILE $bitfile [lindex [get_hw_devices] 0]
#set_property PROBES.FILE {C:/design.ltx} [lindex [get_hw_devices] 0]

# Program the device
program_hw_devices [lindex [get_hw_devices] 0]
refresh_hw_device [lindex [get_hw_devices] 0]

# Close Vivado HW manager
close_hw_manager