from rich.console import Console
from rich.panel import Panel
from rich.align import Align
from rich.text import Text

console = Console()

def print_banner():
    banner = """[bold green]

███████╗ ██████╗ ██████╗ ███████╗███╗   ██╗███████╗██╗ ██████╗      
██╔════╝██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██║██╔════╝      
█████╗  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║███████╗██║██║           
██╔══╝  ██║   ██║██╔══██╗██╔══╝  ██║╚██╗██║╚════██║██║██║           
██║     ╚██████╔╝██║  ██║███████╗██║ ╚████║███████║██║╚██████╗      
╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚══════╝╚═╝ ╚═════╝      
                                                                    
████████╗██╗███╗   ███╗███████╗██╗     ██╗███╗   ██╗███████╗██████╗ 
╚══██╔══╝██║████╗ ████║██╔════╝██║     ██║████╗  ██║██╔════╝██╔══██╗
   ██║   ██║██╔████╔██║█████╗  ██║     ██║██╔██╗ ██║█████╗  ██████╔╝
   ██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██║██║╚██╗██║██╔══╝  ██╔══██╗
   ██║   ██║██║ ╚═╝ ██║███████╗███████╗██║██║ ╚████║███████╗██║  ██║
   ╚═╝   ╚═╝╚═╝     ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
[/bold green]"""
    
    subtitle = Panel.fit(
        "[cyan]Mini Timeline Builder for Axiom, KAPE, Chainsaw, Hayabusa, Nirsoft and more?!?[/cyan]\n"
        "[cyan]Post Processing of CSV output from Leading forensic tools into a single timeline![/cyan]\n"
        "[bright_black]| Made by https://github.com/acquiredsecurity\n"
        "| with help from the robots \\[o_o] \n"
        "| Combine forensic exports into one powerful timeline",
        border_style="purple",
        padding=(1, 2)
    )

    console.print(Align.center(Text.from_markup(banner)))
    console.print(Align.center(subtitle))
 