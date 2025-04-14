from rich.console import Console
from rich.table import Table
from rich.panel import Panel

def show_help():
    console = Console()

    # Banner Panel
    console.print(Panel.fit("[bold cyan]Forensic Timeliner Help[/bold cyan]\n[green]Builds timeline from forensic CSV exports[/green]"))

    # Description
    console.print("[bold yellow]Supported Tools:[/bold yellow] Axiom, EZ Tools (KAPE), Chainsaw, Hayabusa, Nirsoft\n")

    # Parameters Table
    param_table = Table(title="Command Line Parameters", show_lines=True, box=None)
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
    param_table.add_row("--Help", "Display this help menu")

    console.print(param_table)

    # Tool switches
    tool_table = Table(title="Tool Switches", box=None)
    tool_table.add_column("Switch", style="bold green")
    tool_table.add_column("Description")

    tool_table.add_row("--ProcessEZ", "Process EZ Tools / KAPE output")
    tool_table.add_row("--ProcessAxiom", "Process Magnet Axiom exports")
    tool_table.add_row("--ProcessHayabusa", "Process Hayabusa output")
    tool_table.add_row("--ProcessChainsaw", "Process Chainsaw output")
    tool_table.add_row("--ProcessNirsoft", "Process Nirsoft WebHistoryView")
    tool_table.add_row("--SkipEventLogs", "Skip Event Log parsing")
    tool_table.add_row("--ALL", "Enable all modules (EZ, Axiom, Hayabusa, Nirsoft, Chainsaw)")

    console.print(tool_table)

    console.print(Panel.fit(
    "[bold yellow]Examples:[/bold yellow]\n"
    "[cyan]python timeliner.py --Interactive[/cyan]\n"
    "[cyan]python timeliner.py --ProcessEZ --Deduplicate --StartDate 2024-01-01[/cyan]\n"
    "[cyan]python timeliner.py --ALL --OutputFile C:\\triage --StartDate 2024-01-01 --Deduplicate[/cyan]",
    title="Usage Examples",
    border_style="cyan"
))

    # Recommendation
    console.print("\n[italic]Tip: Use --Interactive mode to auto-fill paths and filter options.[/italic]")
