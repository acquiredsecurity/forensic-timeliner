from rich.panel import Panel
from rich.console import Console
from rich.text import Text
from rich.align import Align

console = Console()

def print_eventlog_filters(filters):
    lines = []

    for channel, event_ids in filters.items():
        joined_ids = ", ".join(str(eid) for eid in event_ids)
        lines.append(f"[bold cyan]{channel}[/]\n  Event IDs: [white]{joined_ids}[/]")

    filter_text = "\n".join(lines)

    panel = Panel(
        filter_text,
        title="[bold magenta]Event Log Filters[/]",
        subtitle="Only these Event IDs will be parsed from EZ Tools EVTX exports",
        border_style="purple",
        expand=False,
    )

    console.print(Align.center(panel))

def print_mft_filters():
    lines = [
        "[bold cyan]File Extensions:[/] exe, dll, ps1, zip, 7z, rar",
        "[bold cyan]Suspicious Paths:[/] users, public, temp, appdata, downloads",
        "[bold cyan]Timestamp Filter:[/] Created timestamps only (MFT 0x10)"
    ]

    filter_text = "\n".join(lines)

    panel = Panel(
        filter_text,
        title="[bold magenta]MFT Filters[/]",
        subtitle="Only these conditions are used during EZ Tools MFT parsing",
        border_style="purple",
        expand=False,
    )

    console.print(Align.center(panel))
