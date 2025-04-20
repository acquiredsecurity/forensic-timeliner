from rich.console import Console
from rich.table import Table
from utils.logger import print_and_log  # Required for log file output

# Global summary dictionary
TOOL_ARTIFACT_SUMMARY = {}

# Normalization map for summary display
ARTIFACT_NAME_MAP = {
    # Axiom
    "Axiom_Amcache": "Amcache",
    "Axiom_AppCompat": "AppCompatCache",
    "Axiom_AutoRuns": "Autoruns",
    "Axiom_EventLogs": "EventLogs",
    "Axiom_LNK": "LNK",
    "Axiom_JumpLists": "JumpLists",
    "Axiom_Shellbags": "Shellbags",
    "Axiom_Registry": "Registry",
    "Axiom_Prefetch": "Prefetch",
    "Axiom_IE": "IE History",
    "Axiom_Chrome": "Chrome History",
    "Axiom_Edge": "Edge History",
    "Axiom_Firefox": "Firefox History",
    "Axiom_Opera": "Opera History",
    "Axiom_RecycleBin": "Deleted",
    "Axiom_MRURecent": "MRU - Recent",
    "Axiom_MRUFolderAccess": "MRU - Folder Access",
    "Axiom_MRUOpenSaved": "MRU - Open/Save",
    "Axiom_UserAssist": "UserAssist",
    "Axiom_Autoruns": "Autoruns",

    # Nirsoft
    "NirsoftBrowsingHistory": "Web History",

    # Hayabusa
    "Hayabusa": "EventLogs (Hayabusa)",

    # Chainsaw
    "Chainsaw_Sigma": "Sigma Rules",
    "Chainsaw_Mft": "MFT (Chainsaw)",
    "Chainsaw_Persistence": "Persistence",
    "Chainsaw_Powershell": "PowerShell",
    "Chainsaw_ServiceInstallation": "Service Installation",
    "Chainsaw_ServiceTampering": "Service Tampering",
    "Chainsaw_IndicatorRemoval": "Indicator Removal",
    "Chainsaw_LogTampering": "Log Tampering",
    "Chainsaw_CredentialAccess": "Credential Access",
    "Chainsaw_LateralMovement": "Lateral Movement",
    "Chainsaw_DefenseEvasion": "Defense Evasion",
    "Chainsaw_AccountTampering": "Account Tampering",
    "Chainsaw_LoginAttacks": "Login Attacks",
    "Chainsaw_RdpEvents": "RDP Events",
    "Chainsaw_Antivirus": "Antivirus",
    "Chainsaw_AppLocker": "AppLocker",
    "Chainsaw_MicrosoftRDP": "Microsoft RDS Events",
    "Chainsaw_MicrosoftRAS": "Microsoft RAS VPN Events"
}

def track_summary(tool: str, artifact: str, row_count: int):
    normalized_artifact = ARTIFACT_NAME_MAP.get(artifact, artifact)
    key = (normalized_artifact, tool)
    TOOL_ARTIFACT_SUMMARY[key] = TOOL_ARTIFACT_SUMMARY.get(key, 0) + row_count



def print_final_summary():
    if not TOOL_ARTIFACT_SUMMARY:
        return

    console = Console()

    all_tools = sorted({tool for (_, tool) in TOOL_ARTIFACT_SUMMARY})
    all_artifacts = sorted({artifact for (artifact, _) in TOOL_ARTIFACT_SUMMARY})

    table = Table(title="Forensic Timeliner Export Summary", border_style="green", style="green")
    table.add_column("Artifact", style="bold green")
    for tool in all_tools:
        table.add_column(tool, justify="right", style="green")

    for artifact in all_artifacts:
        row = [artifact]
        for tool in all_tools:
            count = TOOL_ARTIFACT_SUMMARY.get((artifact, tool), 0)
            row.append(str(count) if count > 0 else "-")
        table.add_row(*row)

    total_row = ["TOTAL"]
    for tool in all_tools:
        total = sum(
            count for (artifact, t), count in TOOL_ARTIFACT_SUMMARY.items() if t == tool
        )
        total_row.append(f"{total}" if total > 0 else "-")
    table.add_row(*total_row)

    # Only print to console — no logging
    console.print(table)



