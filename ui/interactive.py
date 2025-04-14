import os
import sys
import questionary
from datetime import datetime
from cli.args import parse_iso_datetime 

def run_interactive_config():
    config = {}

    print("\n[Forensic Timeliner Interactive Configuration]\n")

    # Artifact selection
    selections = questionary.checkbox(
        "Select Forensic Tool CSV Output sources to include:",
        choices=[
            "KAPE / EZ Tools",
            "Axiom",
            "Hayabusa",
            "Nirsoft",
            "Chainsaw",
            "All"
        ]
    ).ask()

    if selections is None:
        print("\n[!] Interactive setup cancelled by user.")
        sys.exit(0)

    config["ProcessEZ"] = "KAPE / EZ Tools" in selections or "All" in selections
    config["ProcessAxiom"] = "Axiom" in selections or "All" in selections
    config["ProcessHayabusa"] = "Hayabusa" in selections or "All" in selections
    config["ProcessNirsoft"] = "Nirsoft" in selections or "All" in selections
    config["ProcessChainsaw"] = "Chainsaw" in selections or "All" in selections

    # Base directory
    base_dir = questionary.text("Base directory for triage data:", default="C:\\triage").ask()
    config["BaseDir"] = base_dir

    # EZ-specific options
    if config["ProcessEZ"]:
        config["EZDirectory"] = questionary.text("Path to EZ Tools directory:", default=os.path.join(base_dir, "kape")).ask()
        config["MFTExtensionFilter"] = questionary.text("MFT Extension Filter (comma-separated):", default=".exe,.ps1,.zip").ask().split(",")
        config["MFTPathFilter"] = questionary.text("MFT Path Filter (comma-separated):", default="Users,tmp").ask().split(",")
        config["SkipEventLogs"] = questionary.confirm("Skip EZ Event Logs?", default=False).ask()

    # Output format
    config["ExportFormat"] = questionary.select(
        "Select export format:",
        choices=["csv", "json", "xlsx"]
    ).ask()

    # Output path
    default_output = os.path.join(base_dir, "timeline", f"Forensic_Timeliner.{config['ExportFormat']}")
    config["OutputFile"] = questionary.text("Where to save the output:", default=default_output).ask()

    # Batch size
    batch = questionary.text("Batch size for large files:", default="10000").ask()
    config["BatchSize"] = int(batch) if batch.isdigit() else 10000

    # Deduplication
    config["Deduplicate"] = questionary.confirm("Enable deduplication?", default=False).ask()

    # Date filtering
    if questionary.confirm("Apply date range filter?", default=False).ask():
        config["StartDate"] = parse_iso_datetime(questionary.text("Start date (YYYY-MM-DD):").ask())
        config["EndDate"] = parse_iso_datetime(questionary.text("End date (YYYY-MM-DD):").ask())
    else:
        config["StartDate"] = None
        config["EndDate"] = None

    print("\n[+] Configuration complete. Running timeline build...\n")
    return config