###################################################################################################
##   _______   _                      __     __             _    
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/     //  O P E N - S O U R C E //
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/              
##           /_/                                    /___/                     chipmunklogic.com
###################################################################################################
# Script : Script for RTL-to-bitstream non-project batch flow in Vivado
# Author : Mitu Raj, chip@chipmunklogic.com 
# Date   : July-2024
# Notes  : Tested with Vivado 2019.2
###################################################################################################

############## CONFIGURE your synth setup ###############
set xdcpath "./xdc/top.xdc"
set topmdl  "pqr5_subsystem_top"
set fpgapart "xc7a35tcpg236-1"
############## END OF CONFIGURATION #####################

# Set output directories
set outputDir ./synth_output 
set bitfileDir ./bitfile_output
file delete -force ./synth_output        
file delete -force ./bitfile
file mkdir $outputDir
file mkdir $bitfileDir

# STEP#1: set RTL sources, XDC design constraints
read_verilog -sv [ glob ./rtl_src/include/*.svh ]
read_verilog -sv [ glob ./rtl_src/common/pqr5_core_pkg.sv ]
read_verilog -sv [ glob ./rtl_src/common/pqr5_subsystem_pkg.sv ]
read_verilog -sv [ glob ./rtl_src/*/*.sv ]
read_verilog -sv [ glob ./rtl_src/*/*/*.sv ]
read_xdc $xdcpath

# STEP#2: run synthesis, report utilization and timing estimates, write checkpoint design
synth_design -top $topmdl -part $fpgapart
write_checkpoint -force $outputDir/post_synth
#open_checkpoint post_synth.dcp
report_utilization -file $outputDir/post_synth_utilization_summary.rpt
report_timing_summary -file $outputDir/post_synth_timing_summary.rpt
report_power -file $outputDir/post_synth_power.rpt

# STEP#3: run placement and logic optimzation, report utilization and timing estimates, write checkpoint design
opt_design
place_design
phys_opt_design
write_checkpoint -force $outputDir/post_place
report_timing_summary -file $outputDir/post_place_timing_summary.rpt

# STEP#4: run router, report actual utilization and timing, write checkpoint design, run drc, write verilog and xdc out
route_design
write_checkpoint -force $outputDir/post_route
report_utilization -file $outputDir/post_route_utilization_summary.rpt
report_timing_summary -file $outputDir/post_route_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/post_route_timing.rpt
report_clock_utilization -file $outputDir/clock_util.rpt
report_utilization -file $outputDir/post_route_util.rpt
report_power -file $outputDir/post_route_power.rpt
report_drc -file $outputDir/post_imp_drc.rpt
write_verilog -force $outputDir/impl_netlist.v
#write_xdc -no_fixed_only -force $outputDir/impl.xdc

# STEP#5: generate a bitstream
write_bitstream -force $bitfileDir/$topmdl.bit
