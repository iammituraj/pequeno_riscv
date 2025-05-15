#############################################################################################################
##   _______   _                      __     __             _    
##  / ___/ /  (_)__  __ _  __ _____  / /__  / /  ___  ___ _(_)___ TM
## / /__/ _ \/ / _ \/  ' \/ // / _ \/  '_/ / /__/ _ \/ _ `/ / __/          ////  O P E N - S O U R C E ////
## \___/_//_/_/ .__/_/_/_/\_,_/_//_/_/\_\ /____/\___/\_, /_/\__/ 
##           /_/                                    /___/              
#############################################################################################################
# Script           : Open Serial
# Developer        : Mitu Raj, chip@chipmunklogic.com
# Vendor           : Chipmunk Logic™, https://chipmunklogic.com
#
# Description      : Open serial port and display the received serial data.
#                    Running from command line: 
#                    python opserial.py <PORT> <BAUDRATE> <PARITY> <TIMEOUT in sec>
#                    e.g: python opserial.py COM3 115200 N 1
#                    All arguments have default values: COM3, 115200, N, 1
#
# Last modified on : Aug-2024
# Compatiblility   : Python 3.9 tested
# Notes            : sudo dmesg | grep tty OR ls /dev/ttyUSB* - to list USB serial ports in Linux
#
# Copyright        : Open-source license, see LICENSE.
#############################################################################################################
# Import Libraries 
# If "serial" is not installed: <pip install pyserial>
import serial
import sys

# Global vars
is_ser_open = False

# Function to convert a byte to character (ascii-256) and form string from a data
def bytes_to_ascii(data):
    # Convert bytes to Extended ASCII characters
    return ''.join(chr(byte) for byte in data)

# MAIN()
def main():
    # Default values
    serial_port = 'COM3'  # /dev/ttyUSBx in Linux...
    baud_rate = 115200
    parity = 'N'
    timeout = 0.1  # 100 ms

    # Update defaults based on command-line arguments
    if len(sys.argv) > 1:
        serial_port = sys.argv[1]
    if len(sys.argv) > 2:
        baud_rate = int(sys.argv[2])
    if len(sys.argv) > 3:
        parity = sys.argv[3]
    if len(sys.argv) > 4:
        timeout = int(sys.argv[4])

    # Map parity argument to serial module constants
    parity_map = {
        'N': serial.PARITY_NONE,
        'E': serial.PARITY_EVEN,
        'O': serial.PARITY_ODD,
        'M': serial.PARITY_MARK,
        'S': serial.PARITY_SPACE,
    }

    # Open the serial port
    try:
        ser = serial.Serial(serial_port, baud_rate, parity=parity_map[parity], timeout=timeout)
        if ser.is_open:
            print(f"[OPSERIAL]: Serial port {ser.name} opened successfully...")
            is_ser_open = True
            # Reading from the serial port
            print("[OPSERIAL]: Reading from serial port:")
            while True:
                try:
                    #line = ser.readline().decode('utf-8').strip()
                    data_raw = ser.read(64)
                    data_dec = data_raw.decode('utf-8')
                    #line = ser.read(64).decode('utf-8)
                    print(data_dec, end='', flush=True)                    
                except KeyboardInterrupt:
                    print("\n[OPSERIAL]: Exiting...")
                    break               
                except serial.SerialException as e:
                    print(f"\n[OPSERIAL]: Serial error!!: {e}")
                    break
                except Exception as e:
                    # If junk characters received, decode('utf-8') throws exception and comes here to display the junk!
                    data_raw_in_ascii = bytes_to_ascii(data_raw)
                    print(data_raw_in_ascii, end='', flush=True)
                    continue
        else:
            is_ser_open = False
            print(f"[OPSERIAL]: Failed to open serial port!! {ser.name}.")
            exit(1)
    except serial.SerialException as e:
        print(f"[OPSERIAL]: Error opening serial port!! {serial_port}: {e}")
    finally:
        if is_ser_open:
            ser.close()
            is_ser_open = False
            print(f"[OPSERIAL]: Serial port {ser.name} closed...")
        exit(1)

if __name__ == '__main__':
    main()
