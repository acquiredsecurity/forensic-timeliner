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
            
            by https://github.com/acquiredsecurity
[/bold green]"""
    
    subtitle = Panel.fit(
        "[cyan]Mini Timeline Builder for Axiom, KAPE, Chainsaw, Hayabusa, and Nirsoft![/cyan]\n"
        "| with help from the robots \\[o_o] \n"
        "| Combine csv exports from forensic tools into one powerful timeline",
        border_style="purple",
        padding=(1, 2)
    )

    console.print(Align.center(Text.from_markup(banner)))
    console.print(Align.center(subtitle))
 