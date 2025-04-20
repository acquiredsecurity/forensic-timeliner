import os
from rich.console import Console
from rich.table import Table
from rich.align import Align
from rich.prompt import Prompt, Confirm
from cli.args import parse_iso_datetime
import questionary

console = Console()

def run_interactive_config():
    config = {}

    console.print("\n[*] Launching interactive configuration...", style="bold cyan")

    # Tool selection
    tool_table = Table(title="[bold yellow]Select your tools![/bold yellow]", border_style="purple")
    tool_table.add_column("Key", style="bold white", justify="center")
    tool_table.add_column("Tool", style="white")

    tools = [
        ("1", "EZ Tools / KAPE"),
        ("2", "Axiom"),
        ("3", "Hayabusa"),
        ("4", "Chainsaw"),
        ("5", "Nirsoft"),
        ("6", "All")
    ]
    for key, name in tools:
        tool_table.add_row(key, name)

    console.print(Align.center(tool_table))

    valid_inputs = {"1", "2", "3", "4", "5", "6"}
    while True:
        selection = Prompt.ask("Select tools (enter numbers separated by commas, or 6 for ALL): ", default="6")
        selected = [s.strip() for s in selection.split(",")]
        if all(s in valid_inputs for s in selected):
            break
        console.print("[red]Invalid input. Please enter numbers 1 through 6 separated by commas.[/red]")

    config["ProcessEZ"] = "1" in selected or "6" in selected
    config["ProcessAxiom"] = "2" in selected or "6" in selected
    config["ProcessHayabusa"] = "3" in selected or "6" in selected
    config["ProcessChainsaw"] = "4" in selected or "6" in selected
    config["ProcessNirsoft"] = "5" in selected or "6" in selected

    # Base directory
    base_dir = Prompt.ask("Set base directory for your CSV output from a single host", default="eg. C:\\triage\\hostname")
    config["BaseDir"] = base_dir

    # MFT filters if EZ or ALL was selected
    if config["ProcessEZ"]:
        path_filter = Prompt.ask("MFT Path Filter (comma-separated) Add more output to your timeline. The follwoing paths are filtered for automatically", default="Users")
        ext_filter = Prompt.ask("MFT Extension Filter (comma-separated) Add more file types to your timeline, the following extensions are filtered for automatically", default=".exe,.ps1,.zip,.rar,.7z")
       
        config["MFTPathFilter"] = path_filter.split(",")       
        config["MFTExtensionFilter"] = ext_filter.split(",")
        

    # Output
    config["ExportFormat"] = "csv" 
    default_output = os.path.join(base_dir, "timeline", "forensic_timeliner.csv")
    config["OutputFile"] = Prompt.ask("Where would you like to save your unified Forensic Timeline?", default=default_output)

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
