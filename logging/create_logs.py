#!/usr/bin/env python3

from pathlib import Path
import shutil
import re
import argparse
import logging
import time


MIN_SPACE = 100*2**20   #Assuming 100 MB default


# Вычисляем индекс
def calculate_index(dir=Path("logs")):
    if not dir.exists():
        return 0
        
    max_index = -1
    pattern = re.compile(r"^(\d+)_")  #Ищем число в начале строки
    for item in dir.iterdir():
        if not item.is_dir():
            continue
        match = pattern.match(item.name)
        if not match:
            continue
        try:
            index = int(match.group(1))
            if index > max_index:
                max_index = index
        except ValueError:
            continue
    
    return max_index + 1
                        
    
# Создаём файл с заданным расширением
def create_files(args):
    index = calculate_index()
    timestamp = time.strftime("%d.%m.%Y-%H:%M:%S")
    
    folder_name = f"{index}_{timestamp}_{args.log_name}"
    log_dir = Path("logs")/folder_name
    log_dir.mkdir(parents=True, exists_ok=False)
    
    base_filename = f"{index}_{timestamp}_{args.log_name}"
    
    created_paths = []
    for ext in args.log_extensions:
        log_file = log_dir/f"{base_filename}.{ext}"
        log_file.touch(exists_ok=False)
        created_paths.append(log_file)
    
    return created_paths
    
def arg_parse():
    parser = argparse.ArgumentParser(description="Log creator")
    parser.add_argument("--log-name", "-ln", required=True,
                        help="Desired log name")
    parser.add_argument("--log-extensions", "-le",
                        default=["cpu", "cam", "rosbag"], nargs="+",
                        help="List of file extensions to create (e.g. cpu cam rosbag)")

    args = parser.parse_args()

    # Convert the logging level from string to the corresponding logging constant
    return args


def main():
    args = arg_parse()
    logging.basicConfig(level=logging.DEBUG,
                        format="%(asctime)s [%(levelname)s] %(message)s")
    logging.info("Creating logs...")
    
    total, _, free = shutil.disk_usage("/")
    
    if free < MIN_SPACE:
        logging.critical("Not enough disk space, flight aborted!\n"
                        f"Only {free//2**20} MB of {total//2**20} MB available,"
                        f"minimum {MIN_SPACE//2**20} MB required.")
        return
        
    else:
        created_paths = create_files(args)
        for path in created_paths:
            print(f"{path}\n")
 
if __name__ == "__main__":
    main()
    