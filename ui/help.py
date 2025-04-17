from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.align import Align

def show_help():
    console = Console()

    banner_panel = Panel.fit(
    "[bold cyan]Forensic Timeliner Help[/bold cyan][center]\n"
    "[green]Builds a timeline from forensic CSV exports[/green]",
    border_style="magenta"
)
    console.print(Align.center(banner_panel))

    # Centered Description
    console.print(Align.center("[bold yellow]Supported Tools:[/bold yellow] Axiom, EZ Tools (KAPE), Chainsaw, Hayabusa, Nirsoft\n"))

    # Parameters Table (Centered)
    param_table = Table(title="Command Line Parameters", show_lines=True, box=None, expand=False)
    param_table.add_column("Argument", style="bold white", no_wrap=True)
    param_table.add_column("Description", style="dim")

    param_table.add_row("--BaseDir", "Base output directory (default: C:/triage)")
    param_table.add_row("--OutputFile", "Timeline output file path (default is timestamped CSV)")
    param_table.add_row("--ExportFormat", "csv, json, or xlsx (default: csv)")
    param_table.add_row("--BatchSize", "Batch size for large CSVs (default: 10000)")
    param_table.add_row("--StartDate", "Start datetime (YYYY-MM-DD or ISO)")
    param_table.add_row("--EndDate", "End datetime (YYYY-MM-DD or ISO)")
    param_table.add_row("--Deduplicate", "Enable deduplication of timeline entries")
    param_table.add_row("--Interactive", "Launch interactive configuration menu")
    param_table.add_row("--Preview", "Visualize discovery of csv files")
    param_table.add_row("--Help", "Display this help menu")

    console.print(Align.center(param_table))

    # Tool Switches Table (Centered)
    tool_table = Table(title="Tool Switches", box=None, expand=False)
    tool_table.add_column("Switch", style="bold green")
    tool_table.add_column("Description")

    tool_table.add_row("--ProcessEZ", "Path to EZ Tools / KAPE output")
    tool_table.add_row("--ProcessAxiom", "Path to Magnet Axiom exports")
    tool_table.add_row("--ProcessHayabusa", "Path to Hayabusa output")
    tool_table.add_row("--ProcessChainsaw", "Path to Chainsaw output")
    tool_table.add_row("--ProcessNirsoft", "Path to Nirsoft WebHistoryView")
    tool_table.add_row("--ALL", "Enable all modules and provide a BaseDir (EZ, Axiom, Hayabusa, Nirsoft, Chainsaw)")

    console.print(Align.center(tool_table))

    # Usage Examples Panel (Centered)
    examples_panel = Panel.fit(
        "[bold yellow]Examples:[/bold yellow]\n"
        "[cyan]python timeliner.py --Interactive[/cyan]\n"
        "[cyan]python timeliner.py --ProcessEZ --Deduplicate --StartDate 2024-01-01[/cyan]\n"
        "[cyan]python timeliner.py --ALL --Preview --BaseDir c:\\triage  --OutputFile C:\\triage\\timeline[/cyan]\n"
        "[cyan]python timeliner.py --ALL --BaseDir c:\\triage --OutputFile C:\\triage\\timeline --StartDate 2024-01-01 --Deduplicate[/cyan]",
        title="Usage Examples",
        border_style="purple"
    )
    console.print(Align.center(examples_panel))

    # Centered Tip
    console.print(Align.center("[italic]Tip: Use --Interactive mode to auto-fill paths and filter options.[/italic]"))
