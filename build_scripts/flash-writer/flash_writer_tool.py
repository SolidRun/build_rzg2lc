#!/usr/bin/env python3

import serial
import argparse
import time
import sys
from tqdm import tqdm
import os

def parse_args():
    parser = argparse.ArgumentParser(description='Firmware flashing tool')
    parser.add_argument('--port', default='/dev/ttyUSB0', help='Serial port device')
    parser.add_argument('--fw', required=True, help='Path to flashwriter .mot file')
    parser.add_argument('--bl2', help='Path to bl2_bp.bin')
    parser.add_argument('--fip', help='Path to fip image')
    parser.add_argument('--overlays', help='Path to fit image with dts overlays')

    args = parser.parse_args()

    if not (args.bl2 or args.fip or args.overlays):
        parser.error('At least one of --bl2, --fip, or --overlays must be specified')

    return args

def open_serial(port, baudrate, timeout=1):
    ser = serial.Serial(port, baudrate=baudrate, timeout=timeout)
    return ser

def send_command(ser, command, expect=None, timeout=5):
    ser.write((command + '\r').encode())
    if expect:
        return wait_for_prompt(ser, expect, timeout)
    else:
        return True

def wait_for_prompt(ser, expect, timeout=5):
    end_time = time.time() + timeout
    buffer = ''
    while time.time() < end_time:
        data = ser.read(ser.in_waiting or 1)
        if data:
            decoded = data.decode(errors='ignore')
            buffer += decoded
            sys.stdout.write(decoded)
            sys.stdout.flush()
            # Clean buffer to remove carriage returns and newlines
            clean_buffer = buffer.replace('\r', '').replace('\n', '')
            if expect in clean_buffer:
                return True
        else:
            time.sleep(0.1)
    print(f"\nBuffer received: {repr(buffer)}")
    raise Exception(f"Timeout waiting for '{expect}'")

def send_file(ser, file_path):
    file_size = os.path.getsize(file_path)
    with open(file_path, 'rb') as f:
        bytes_sent = 0
        with tqdm(total=file_size, unit='B', unit_scale=True, desc='Sending file') as pbar:
            while True:
                chunk = f.read(1024)
                if not chunk:
                    break
                ser.write(chunk)
                ser.flush()
                bytes_sent += len(chunk)
                pbar.update(len(chunk))
    print("File transfer complete.")

def main():
    args = parse_args()

    ser = open_serial(args.port, 115200)

    print("Please reset the board")
    wait_for_prompt(ser, "please send !", timeout=30)
    start_time = time.time()
    print(f"Sending firmware: {args.fw}")
    send_file(ser, args.fw)
    send_command(ser, "", ">")

    print("Increasing baudrate to 921600")
    send_command(ser, "SUP")
    ser.close()
    time.sleep(0.1)
    ser = open_serial(args.port, 921600)
    # Send newline and check for '>'
    send_command(ser, "", ">")
    # wait_for_prompt(ser, ">", timeout=5)

    # Function to flash binary to eMMC
    def flash_binary(file_path, sector_number):
        send_command(ser, "EM_WB", expect="Select area(0-2)>")
        send_command(ser, "1", expect="Please Input Start Address in sector :")
        sector_hex = format(sector_number, 'X')
        send_command(ser, sector_hex, expect="Please Input File size(byte) : ")
        file_size = os.path.getsize(file_path)
        file_size_hex = format(file_size, 'X')
        send_command(ser, file_size_hex, expect="please send binary file!")
        print(f"Sending binary file: {file_path}")
        send_file(ser, file_path)
        wait_for_prompt(ser, ">", timeout=10)

    flashed = False

    if args.bl2:
        print(f"\nFlashing bl2: {args.bl2}")
        flash_binary(args.bl2, sector_number=1)
        flashed = True

    if args.fip:
        print(f"\nFlashing fip: {args.fip}")
        flash_binary(args.fip, sector_number=0x100)
        flashed = True

    if args.overlays:
        print(f"\nFlashing overlays: {args.overlays}")
        flash_binary(args.overlays, sector_number=0x1800)
        flashed = True

    if flashed:
        # Enable eMMC boot
        send_command(ser, "EM_SECSD", expect="Please Input EXT_CSD Index(H'00 - H'1FF) :")
        send_command(ser, "b3", expect="Please Input Value(H'00 - H'FF) :")
        send_command(ser, "08", expect=">")

    ser.close()
    print(f"\nFlashing complete in {int(time.time() - start_time)} seconds.")

if __name__ == "__main__":
    main()
