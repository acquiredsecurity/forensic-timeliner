from time import sleep
from rich.live import Live
from rich.console import Group
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, BarColumn, TextColumn, TimeElapsedColumn
from rich.align import Align
from rich.text import Text

def launch_animation():
    progress = Progress(
        SpinnerColumn(style="magenta"),
        TextColumn("[bold cyan]Initializing Forensic Timeliner..."),
        BarColumn(bar_width=40),
        TimeElapsedColumn(),
        transient=True,
    )

    task = progress.add_task("boot", total=30)

    panel = Panel.fit(
        Group(
            Align.center(Text("🔎 Forensic Timeliner", style="bold magenta")),
            Align.center(progress)
        ),
        title="[bold blue]Launching[/]",
        border_style="purple",
        padding=(1, 4)
    )

    with Live(Align.center(panel), refresh_per_second=20):
        while not progress.finished:
            progress.advance(task)
            sleep(0.05)

    sleep(0.3)
