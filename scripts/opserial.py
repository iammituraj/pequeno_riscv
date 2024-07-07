#############################################################################################################
# ╔═╦╗╔╗─────────╔╗─╔╗────╔╗
# ║╔╣╚╬╬═╦══╦╦╦═╦╣╠╗║║╔═╦═╬╬═╗
# ║╚╣║║║╬║║║║║║║║║═╣║╚╣╬║╬║║═╣ /////////////// O P E N S O U R C E
# ╚═╩╩╩╣╔╩╩╩╩═╩╩═╩╩╝╚═╩═╬╗╠╩═╝
# ─────╚╝───────────────╚═╝
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
# Last modified on : June-2024
# Compatiblility   : Python 3.9 tested
#
# Copyright        : Open-source license, see developer.txt.
#############################################################################################################
# Import Libraries 
# If "serial" is not installed: <pip install pyserial>
import serial
import sys

def main():
    # Default values
    serial_port = 'COM3'
    baud_rate = 115200
    parity = 'N'
    timeout = 1

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

            # Example: Reading from the serial port
            print("[OPSERIAL]: Reading from serial port:")
            while True:
                try:
                    line = ser.readline().decode('utf-8').strip()
                    if line:
                        print(line)
                except KeyboardInterrupt:
                    print("[OPSERIAL]: Exiting...")
                    break
                except serial.SerialException as e:
                    print(f"[OPSERIAL]: Serial error!!: {e}")
                    break

        else:
            print(f"[OPSERIAL]: Failed to open serial port!! {ser.name}.")
    except serial.SerialException as e:
        print(f"[OPSERIAL]: Error opening serial port!! {serial_port}: {e}")
    finally:
        if ser.is_open:
            ser.close()
            print(f"[OPSERIAL]: Serial port {ser.name} closed...")

if __name__ == '__main__':
    main()