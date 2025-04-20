import os
import sys
import time
import logging
import pandas as pd
import msvcrt
from rich.console import Console
from rich.table import Table
from rich.align import Align
from rich.panel import Panel
from utils.discovery import find_artifact_files, ARTIFACT_SIGNATURES

console = Console()

logger = logging.getLogger("discovery_preview")
logger.setLevel(logging.INFO)
handler = logging.FileHandler("discovery_preview.log")
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)

TOOL_GROUPS = {
    "EZ Tools": [k for k in ARTIFACT_SIGNATURES if not k.startswith(("Axiom", "Chainsaw", "Hayabusa", "Nirsoft"))],
    "Axiom": [k for k in ARTIFACT_SIGNATURES if k.startswith("Axiom")],
    "Chainsaw": [k for k in ARTIFACT_SIGNATURES if k.startswith("Chainsaw")],
    "Hayabusa": [k for k in ARTIFACT_SIGNATURES if k.startswith("Hayabusa")],
    "Nirsoft": [k for k in ARTIFACT_SIGNATURES if k.startswith("Nirsoft")],
}

def pause_with_countdown(seconds=10):
    dark_purple = "dark_violet"  # or use "#301934" for custom RGB
    for i in range(seconds, 0, -1):
        msg = f"[bold {dark_purple}]Next tool preview in: {i} seconds... (press space to skip)[/bold {dark_purple}]"
        centered = Align.center(msg, vertical="middle")
        console.print(centered, end='\r')
        time.sleep(1)

        start = time.time()
        while time.time() - start < 1:
            if msvcrt.kbhit() and msvcrt.getch() == b' ':
                console.print(" " * 100, end='\r')
                return
            time.sleep(0.05)
    console.print(" " * 100, end='\r')

def show_matched_files_table(tool, matched_rows):
    table = Table(title=f"[bold green]{tool} - Matched Files[/]", border_style="purple")
    table.add_column("Artifact", style="purple", no_wrap=True)
    table.add_column("File Name", style="white")
    table.add_column("Match Type", style="green")

    discovery_paths = set()

    for artifact, file_name, full_path, match_type in matched_rows:
        table.add_row(artifact, file_name, match_type)
        discovery_paths.add(os.path.dirname(full_path))

    console.print(Align.center(table))

    if discovery_paths:
        if len(discovery_paths) == 1:
            footer_text = f"[cyan]Discovery Path:[/] {list(discovery_paths)[0]}"
        else:
            footer_lines = [f"{idx+1}. {path}" for idx, path in enumerate(sorted(discovery_paths))]
            footer_text = "[cyan]Discovery Paths:[/]\n" + "\n".join(footer_lines)

        footer_panel = Panel(footer_text, title="[bold magenta]Discovery Info[/]", border_style="purple")
        console.print(Align.center(footer_panel))

def preview_artifact_discovery(base_dir):
    all_csv_files = []
    for root, _, files in os.walk(base_dir):
        for file in files:
            if file.lower().endswith(".csv"):
                all_csv_files.append(os.path.abspath(os.path.join(root, file)))

    matched_files = set()

    for tool, artifact_keys in TOOL_GROUPS.items():
        matched_rows = []
        missing_table = Table(title=f"[bold red]{tool} - Missing Artifacts[/]", border_style="purple")
        missing_table.add_column("Artifact")
        missing_table.add_column("Expected Filename")
        missing_table.add_column("Expected Folder")

        matched_count = 0
        total_count = len(artifact_keys)

        for artifact in artifact_keys:
            config = ARTIFACT_SIGNATURES[artifact]
            matches = find_artifact_files(base_dir, base_dir, artifact)

            if matches:
                matched_count += 1
                for match in matches:
                    matched_files.add(os.path.abspath(match))
                    matched_rows.append((artifact, os.path.basename(match), match, "Filename & Headers"))
            else:
                fname_hint = ", ".join(config.get("filename_patterns", []))
                folder_hint = ", ".join(config.get("foldername_patterns", []))
                missing_table.add_row(artifact, fname_hint, folder_hint)

        percent = int((matched_count / total_count) * 100)
        summary = f"[bold white]{tool}: Matched {matched_count} of {total_count} artifacts ({percent}%)"
        console.print(Align.center(summary))
        if matched_count < total_count:
            console.print(Align.center(f"[red]Some artifacts not found for {tool}[/red]"))
        else:
            console.print(Align.center(f"[green]All supported artifacts found for {tool}![/green]"))

        if matched_rows:
            show_matched_files_table(tool, matched_rows)
        if matched_count < total_count:
            console.print(Align.center(missing_table))

        pause_with_countdown(10)

    unmatched = [f for f in all_csv_files if os.path.abspath(f) not in matched_files]
    if unmatched:
        console.print(Align.center("[yellow]Unmatched CSV files were found and logged to discovery_preview.log[/yellow]"))
        for f in unmatched:
            logger.info(f"Unmatched CSV file: {f}")

def run_discovery_preview(base_dir):
    console.rule("[bold cyan]Previewing Artifact Discovery")
    preview_artifact_discovery(base_dir)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        run_discovery_preview(sys.argv[1])
    else:
        console.print("[red]Usage: python discovery_preview.py <BaseDir>[/red]")