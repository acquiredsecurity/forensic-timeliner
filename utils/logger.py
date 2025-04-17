import logging
import os
from datetime import datetime
from rich.console import Console
from rich.table import Table
from rich.live import Live
from rich.text import Text

logger = None
log_table = None
live = None
console = Console()

def setup_logger(output_dir: str) -> str:
    global logger, log_table, live

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

    # Setup live Rich table
    log_table = Table(show_header=True, header_style="bold magenta")
    log_table.add_column("Time", width=20)
    log_table.add_column("Message", overflow="fold")
    live = Live(log_table, console=console, refresh_per_second=5)
    live.start()

    print(f"[Log] Console output is being saved to: {log_path}")
    logger.info("Logger initialized")

    return log_path

def log_info(msg: str):
    if logger:
        logger.info(msg)

def print_and_log(msg: str):
    print(msg)
    log_info(msg)

    if log_table:
        log_table.add_row(datetime.now().strftime('%Y-%m-%d %H:%M:%S'), Text(msg, style="white"))

def stop_live_log():
    global live
    if live:
        live.stop()
