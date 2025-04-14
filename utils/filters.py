from rich.console import Console
from rich.text import Text

EVENT_CHANNEL_FILTERS = {
    "Application": [1000, 1001],
    "Microsoft-Windows-PowerShell/Operational": [4100, 4103, 4104],
    "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational": [72, 98, 104, 131, 140],
    "Microsoft-Windows-TaskScheduler/Operational": [106, 140, 141, 129, 200, 201],
    "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational": [21, 22],
    "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational": [261, 1149],
    "Microsoft-Windows-WinRM/Operational": [169],
    "Security": [1102, 4624, 4625, 4648, 4698, 4702, 4720, 4722, 4723, 4724, 4725, 4726, 4732, 4756],
    "SentinelOne/Operational": [1, 31, 55, 57, 67, 68, 77, 81, 93, 97, 100, 101, 104, 110],
    "System": [7045]
}

def print_eventlog_filters(filters: dict):
    console = Console()
    for channel, ids in filters.items():
        console.print(Text(channel, style="bold cyan"))
        event_ids = Text("  Event IDs: ", style="bold green")
        event_ids.append(", ".join(str(i) for i in ids), style="white")
        console.print(event_ids)
        console.print("")  # spacing