#!/usr/bin/env bash
#################################################################################################################################
##   _______   _                      __     __             _
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/                            ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/
##           /_/                                    /___/                                              chipmunklogic.com
#################################################################################################################################
# File Name        : configurator.sh
# Description      : Launcher for the PQR5 Interactive Configurator, configurator/configurator.py
# Copyright        : Open-source license, see LICENSE.
#################################################################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHON_BIN="python3"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    echo "ERROR: python3 (or python) not found in PATH. Python >= 3.9 is required." >&2
    exit 1
fi

exec "$PYTHON_BIN" "$SCRIPT_DIR/configurator/configurator.py" "$@"
