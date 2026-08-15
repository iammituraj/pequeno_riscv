#!/bin/bash
# Script to open Serial Terminal
#
# Thin wrapper around opserial.py -- forwards all arguments unchanged, so opserial.py's
# own CLI applies here too:
#
# USAGE:
#   ./opserial.sh [PORT] [BAUDRATE] [PARITY] [TIMEOUT]
#   ./opserial.sh -l | --list      # list available serial targets (which PORT to use)
#   ./opserial.sh -h | --help      # full usage/help
#
# e.g: ./opserial.sh /dev/ttyUSB0 115200 N 1
#      All arguments have default values: COM3, 115200, N, 1

# Configure Python path
PYTHON=/home/mituraj/my_workspace/python/myenv/bin/python
#PYTHON=python

$PYTHON opserial.py "$@"
