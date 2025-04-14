import logging
import os
from datetime import datetime

logger = None

def setup_logger(output_dir: str) -> str:
    global logger

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_filename = f"{timestamp}_forensic_timeliner_log.txt"
    os.makedirs(output_dir, exist_ok=True)
    log_path = os.path.join(output_dir, log_filename)

    logger = logging.getLogger("forensic_timeliner")
    logger.setLevel(logging.INFO)

    fh = logging.FileHandler(log_path, encoding='utf-8')
    formatter = logging.Formatter('[%(asctime)s] %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
    fh.setFormatter(formatter)
    
    if not logger.handlers:
        logger.addHandler(fh)

    print(f"[Log] Console output is being saved to: {log_path}")
    logger.info("Logger initialized")

    return log_path 

def log_info(msg: str):
    if logger:
        logger.info(msg)

def print_and_log(msg: str):
    print(msg)
    log_info(msg)
