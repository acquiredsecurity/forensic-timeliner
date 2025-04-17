import os
import sys
from datetime import datetime
from rich.console import Console
from rich.table import Table
from rich.align import Align
from rich.panel import Panel
from rich.prompt import Prompt, Confirm
from cli.args import parse_iso_datetime
import questionary

console = Console()

def run_interactive_config():
    config = {}

    console.print("\n[*] Launching interactive configuration...", style="bold cyan")

    # Tool selection
    tool_table = Table(title="[bold yellow]Select Tools to Include[/bold yellow]", border_style="purple")
    tool_table.add_column("Key", style="bold white", justify="center")
    tool_table.add_column("Tool", style="white")

    tools = [
        ("1", "EZ Tools / KAPE"),
        ("2", "Axiom"),
        ("3", "Hayabusa"),
        ("4", "Nirsoft"),
        ("5", "Chainsaw"),
        ("6", "All")
    ]
    for key, name in tools:
        tool_table.add_row(key, name)

    console.print(Align.center(tool_table))

    valid_inputs = {"1", "2", "3", "4", "5", "6"}
    while True:
        selection = Prompt.ask("Enter tool numbers separated by commas eg.. 1,3,5 OR 6 for ALL Defaults to ALL", default="6")
        selected = [s.strip() for s in selection.split(",")]
        if all(s in valid_inputs for s in selected):
            break
        console.print("[red]Invalid input. Please enter numbers 1 through 6 separated by commas.[/red]")

    config["ProcessEZ"] = "1" in selected or "6" in selected
    config["ProcessAxiom"] = "2" in selected or "6" in selected
    config["ProcessHayabusa"] = "3" in selected or "6" in selected
    config["ProcessNirsoft"] = "4" in selected or "6" in selected
    config["ProcessChainsaw"] = "5" in selected or "6" in selected

    # Base directory
    base_dir = Prompt.ask("Base directory for triage csv output", default="eg. C:\\triage\\hostname")
    config["BaseDir"] = base_dir

    # EZ Tools settings
    if config["ProcessEZ"]:
        config["EZDirectory"] = Prompt.ask("EZ/Kape Tool csv output directory with data in default subfolder eg.. FileSystem ProgramExecution etc..", default=os.path.join(base_dir, "kape"))
        ext_filter = Prompt.ask("MFT Extension Filter (comma-separated)", default=".exe,.ps1,.zip,.rar,.7z")
        path_filter = Prompt.ask("MFT Path Filter (comma-separated)", default="Users,tmp")
        config["MFTExtensionFilter"] = ext_filter.split(",")
        config["MFTPathFilter"] = path_filter.split(",")

    # Output
    config["ExportFormat"] = "csv"  # Enforced for now
    default_output = os.path.join(base_dir, "timeline", "forensic_timeliner.csv")
    config["OutputFile"] = Prompt.ask("Timeline output file path", default=default_output)

    batch = Prompt.ask("Batch size for large files", default="10000")
    config["BatchSize"] = int(batch) if batch.isdigit() else 10000

    config["Deduplicate"] = Confirm.ask("Enable deduplication?", default=False)

    if Confirm.ask("Apply date range filter?", default=False):
        start_input = questionary.text("Start date (YYYY-MM-DD):").ask()
        end_input = questionary.text("End date (YYYY-MM-DD):").ask()

        config["StartDate"] = parse_iso_datetime(start_input) if start_input.strip() else None
        config["EndDate"] = parse_iso_datetime(end_input) if end_input.strip() else None
    else:
        config["StartDate"] = None
        config["EndDate"] = None

    console.print("\n[✓] Interactive configuration complete.\n", style="bold green")
    return config
