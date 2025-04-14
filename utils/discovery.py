import os
from pathlib import Path
import pandas as pd
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeRemainingColumn


console = Console()

ARTIFACT_SIGNATURES = {
    "Amcache": {
        "filename_patterns": ["AssociatedFileEntries.csv", "UnassociatedFileEntries.csv"],
        "foldername_patterns": ["ProgramExecution"],
        "required_headers": [
            "ApplicationName", "ProgramId", "FileKeyLastWriteTimestamp", "SHA1",
            "IsOsComponent", "FullPath", "Name", "FileExtension", "LinkDate",
            "ProductName", "Size", "Version", "ProductVersion", "LongPathHash",
            "BinaryType", "IsPeFile", "BinFileVersion", "BinProductVersion",
            "Usn", "Language", "Description"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "AppCompatCache": {
        "filename_patterns": ["AppCompatCache.csv"],
        "foldername_patterns": ["ProgramExecution"],
        "required_headers": [
            "ControlSet", "CacheEntryPosition", "Path",
            "LastModifiedTimeUTC", "Executed", "Duplicate", "SourceFile"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Deleted": {
        "filename_patterns": ["RBCmd_Output.csv"],
        "foldername_patterns": ["FileDeletion"],
        "required_headers": [
            "SourceName", "FileType", "FileName", "FileSize", "DeletedOn"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "EventLogs": {
        "filename_patterns": ["_EvtxECmd_Output.csv"],
        "foldername_patterns": ["EventLogs"],
        "required_headers": [
            "TimeCreated", "EventId", "Channel", "Computer", "MapDescription",
            "SourceFile", "PayloadData1"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "JumpLists": {
        "filename_patterns": ["AutomaticDestinations.csv"],
        "foldername_patterns": ["FileFolderAccess"],
        "required_headers": [
            "Path", "AppId", "AppIdDescription", "CreationTime",
            "SourceCreated", "SourceModified", "SourceAccessed",
            "TargetCreated", "TargetModified", "TargetAccessed"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "LNK": {
        "filename_patterns": ["_LECmd_Output.csv"],
        "foldername_patterns": ["FileFolderAccess"],
        "required_headers": [
            "LocalPath", "TargetIDAbsolutePath", "NetworkPath",
            "SourceCreated", "SourceModified", "SourceAccessed",
            "TargetCreated", "TargetModified", "TargetAccessed"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "MFT": {
        "filename_patterns": ["_MFTECmd_$MFT_Output.csv"],
        "foldername_patterns": ["FileSystem"],
        "required_headers": [
            "FileName", "ParentPath", "Extension", "Created0x10"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Prefetch": {
        "filename_patterns": ["_PECmd_Output.csv"],
        "foldername_patterns": ["ProgramExecution"],
        "required_headers": [
            "ExecutableName", "SourceFilename", "LastRun", "RunCount",
            "SourceCreated", "SourceModified", "SourceAccessed", "Volume0Created"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Registry": {
        "filename_patterns": ["_RECmd_Batch_Kroll_Batch_Output.csv"],
        "foldername_patterns": ["Registry"],
        "required_headers": [
            "HivePath", "HiveType", "Description", "Category", "KeyPath",
            "ValueName", "ValueType", "ValueData", "LastWriteTimestamp"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Shellbags": {
        "filename_patterns": ["_UsrClass.csv", "_NTUSER.csv"],
        "foldername_patterns": ["FileFolderAccess"],
        "required_headers": [
            "BagPath", "AbsolutePath", "Value",
            "LastWriteTime", "FirstInteracted", "LastInteracted"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Hayabusa": {
        "filename_patterns": ["hayabusa", "haya"],
        "foldername_patterns": ["haya"],
        "required_headers": [
            "Timestamp", "RuleTitle", "Level", "Computer", 
            "Channel", "EventID", "RecordID", "Details", 
            "ExtraFieldInfo", "RuleID"
        ],
        "strict_filename_match": False,
        "strict_folder_match": False
    }, 
    "NirsoftBrowsingHistory": {
        "filename_patterns": ["nirsoft", "history", "browsing", "web", "browse"],
        "foldername_patterns": ["nirsoft", "browse"],
        "required_headers": [
            "URL", "Title", "Visit Time", "Visit Count", "Visited From", 
            "Visit Type", "Visit Duration", "Web Browser", "User Profile", 
            "Browser Profile", "URL Length", "Typed Count", "History File", 
            "Record ID"
        ],
        "strict_filename_match": False,
        "strict_folder_match": False
    },
    "Chainsaw_Mft": {
        "filename_patterns": ["mft.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "timestamp", "detections", "path", "FileNamePath"   
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Chainsaw_Sigma": {
        "filename_patterns": ["sigma.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "timestamp", "detections", "path", "count", "Event.System.Provider", "Event ID", "Record ID", "Computer", "Event Data"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Chainsaw_AccountTampering": {
        "filename_patterns": ["account_tampering.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Chainsaw_Antivirus": {
        "filename_patterns": ["antivirus.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Chainsaw_Applocker": {
        "filename_patterns": ["applocker.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Chainsaw_CredentialAccess": {
        "filename_patterns": ["credential_access.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Chainsaw_DefenseEvasion": {
        "filename_patterns": ["defense_evasion.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Chainsaw_IndicatorRemoval": {
        "filename_patterns": ["indicator_removal.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "timestamp", "detections", "path", "Event ID", "Computer", "User Name", "Scheduled Task Name"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Chainsaw_LateralMovement": {
        "filename_patterns": ["lateral_movement.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Chainsaw_LogTampering": {
        "filename_patterns": ["log_tampering.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Chainsaw_LoginAttacks": {
        "filename_patterns": ["login_attacks.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Chainsaw_MicrosoftRasvpnEvents": {
        "filename_patterns": ["microsoft_rasvpn_events.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    },
    "Chainsaw_MicrosoftRdsEvents": {
        "filename_patterns": ["microsoft_rds_events.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "timestamp", "Event ID", "Computer", "detections", "path", "Channel", "Information"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Chainsaw_Persistence": {
        "filename_patterns": ["persistence.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "timestamp", "detections", "path", "Event ID", "Computer", "User Name", "Scheduled Task Name"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Chainsaw_Powershell": {
        "filename_patterns": ["powershell.csv", "powershell_engine_state.csv", "powershell_script.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "timestamp", "detections", "path", "Event ID", "Computer"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Chainsaw_RdpEvents": {
        "filename_patterns": ["rdp_events.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "timestamp", "detections", "path", "Event ID", "Computer", "Information"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Chainsaw_ServiceInstallation": {
        "filename_patterns": ["service_installation.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "timestamp", "detections", "path", "Event ID", "Record ID", "Computer", "Service Name", "Service File Name", "Service Type", "Service Start Type", "Service Account"

        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Chainsaw_ServiceTampering": {
        "filename_patterns": ["service_tampering.csv"],
        "foldername_patterns": ["chainsaw"],
        "required_headers": [
            "UtcTime", "EventID", "ComputerName", "Detection", "RuleTitle"
        ],
        "strict_filename_match": True,
        "strict_folder_match": True
    }

}

def find_artifact_files(input_dir: str, base_dir: str, artifact_name: str) -> list:
    input_path = Path(input_dir)
    if not input_path.exists():
        print(f"[Discovery] Input directory not found: {input_dir}")
        return []

    artifact = ARTIFACT_SIGNATURES.get(artifact_name)
    if not artifact:
        print(f"[Discovery] No known signature for artifact: {artifact_name}")
        return []

    matches = []

    for root, _, files in os.walk(input_path):
        foldername_patterns = artifact.get("foldername_patterns", [])

        # Strict folder matching
        if artifact.get("strict_folder_match", False):
            folder_matched = any(os.path.basename(root).lower() == pattern.lower() for pattern in foldername_patterns)
        else:
            folder_matched = any(pattern.lower() in os.path.basename(root).lower() for pattern in foldername_patterns)

        for fname in files:
            if not fname.lower().endswith('.csv'):
                continue

            file_path = os.path.join(root, fname)

            # Strict filename matching
            if artifact.get("strict_filename_match", False):
                filename_matched = any(fname.lower().endswith(p.lower()) for p in artifact["filename_patterns"])
            else:
                filename_matched = any(p.lower() in fname.lower() for p in artifact["filename_patterns"])

            if filename_matched and folder_matched:
                matches.append(file_path)
                continue
            # Only perform fallback header check if NOT in strict match mode
            if not artifact.get("strict_filename_match", False) and not artifact.get("strict_folder_match", False):
                try:
                    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                        first_line = f.readline()
                        headers = [h.strip().lower() for h in first_line.split(",")]
                        required = [h.lower() for h in artifact["required_headers"]]
                        matched_headers = sum(1 for h in required if h in headers)
                        if matched_headers >= max(1, len(required) // 2):
                            matches.append(file_path)
                except Exception as e:
                    print(f"[Discovery] Failed to inspect {file_path}: {e}")

    return matches


def load_csv_with_progress(file_path: str, batch_size: int, artifact_name: str = "Default"):
    # Simple encoding detection
    if os.path.basename(file_path).lower() == "webresults.csv":
        encoding = "cp1252"  # Use CP1252 specifically for WebResults.csv
        print(f"[Discovery] Using cp1252 encoding for WebResults.csv")
    else:
        encoding = "utf-8"
    
    # Count lines safely with the correct encoding
    try:
        with open(file_path, encoding=encoding, errors="replace") as f:
            total_lines = sum(1 for _ in f) - 1
    except Exception as e:
        print(f"[Discovery] Could not count lines in {file_path}: {e}")
        total_lines = 0
    
    use_chunks = total_lines > batch_size
    style_map = {
        "Amcache": "green on white",
        "AppCompatCache": "magenta on black",
        "Prefetch": "cyan on black",
        "MFT": "bright_green on black",
        "JumpLists": "bright_yellow on black",
        "LNK": "blue on black",
        "Deleted": "red on black",
        "EventLogs": "bright_magenta on black",
        "Shellbags": "bright_blue on black",
        "Registry": "bright_cyan on black",
        "Hayabusa": "white on blue",
        "WebHistory": "white on dark_green",
        "Default": "white on black"
    }
    style = style_map.get(artifact_name, style_map["Default"])
    
    if use_chunks:
        with Progress(
            TextColumn("Progress:", style="bold green"),
            BarColumn(bar_width=None),
            TextColumn("{task.percentage:>3.0f}%", style="bold white"),
            TimeRemainingColumn(),
            console=console,
            transient=False
        ) as progress:
            task = progress.add_task(f"{os.path.basename(file_path)}", total=total_lines)
            for chunk in pd.read_csv(file_path, chunksize=batch_size, encoding=encoding, on_bad_lines="skip"):
                yield chunk
                progress.update(task, advance=len(chunk))
    else:
        df = pd.read_csv(file_path, encoding=encoding, on_bad_lines="skip")
        yield df
