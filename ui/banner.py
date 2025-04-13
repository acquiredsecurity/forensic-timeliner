from rich.console import Console
from rich.panel import Panel

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
        "[bright_black]| Made by https://github.com/acquiredsecurity\n"
        "| with help from the robots \\[o_o] \n"
        "| Combine forensic exports into one powerful timeline",
        border_style="magenta",
        padding=(1, 2)
    )

    console.print(banner)
    console.print(subtitle)
 