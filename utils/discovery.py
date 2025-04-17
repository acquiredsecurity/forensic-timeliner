import os
from pathlib import Path
import pandas as pd
from tqdm import tqdm


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
        "strict_folder_match": False
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
    "Axiom_Amcache": {
        "filename_patterns": ["AmCache File Entries.csv"],
        "foldername_patterns": ["ProgramExecution", "Axiom"],
        "required_headers": [
            "ApplicationName", "ProgramId", "FileKeyLastWriteTimestamp", "SHA1",
            "IsOsComponent", "FullPath", "Name", "FileExtension", "LinkDate",
            "ProductName", "Size", "Version", "ProductVersion", "LongPathHash",
            "BinaryType", "IsPeFile", "BinFileVersion", "BinProductVersion",
            "Language", "Description"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_AppCompat": {
        "filename_patterns": ["Shim Cache.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["Path", "File Name", "Last Modified Date/Time - UTC+00:00 (M/d/yyyy)"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_AutoRuns": {
        "filename_patterns": ["Autorun Items.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)", "File Path", "File Name", "Command"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_ChromeHistory": {
        "filename_patterns": ["Chrome Web History.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["Visit Date/Time - UTC+00:00 (M/d/yyyy)", "URL", "Page Title"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_Edge": {
        "filename_patterns": ["Edge Web Visits.csv", "Edge Web History.csv" ],
        "foldername_patterns": ["Axiom"],
        "required_headers": [
            "Last Visited Date/Time - UTC+00:00 (M/d/yyyy)",
            "URL", "Title", "Visit Count", "Evidence number"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_IEHistory": {
        "filename_patterns": ["Edge-Internet Explorer 10-11 Main History.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["Accessed Date/Time - UTC+00:00 (M/d/yyyy)", "URL", "Page Title"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_Firefox": {
        "filename_patterns": ["Firefox Web Visits.csv"],
        "foldername_patterns": ["Axiom"],
        "required_headers": ["Last Visited Date/Time - UTC+00:00 (M/d/yyyy)", "URL", "Title"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_Opera": {
        "filename_patterns": ["Opera Web Visits.csv"],
        "foldername_patterns": ["Axiom"],
        "required_headers": ["Last Visited Date/Time - UTC+00:00 (M/d/yyyy)", "URL", "Title"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_JumpLists": {
        "filename_patterns": ["Jump Lists.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": [
            "Linked Path", "Target File Created Date/Time - UTC+00:00 (M/d/yyyy)",
            "Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)",
            "Last Access Date/Time - UTC+00:00 (M/d/yyyy)", "Source"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_LNK": {
        "filename_patterns": ["LNK Files.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": [
            "Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)",
            "Target Path", "Target File Size"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_MRUFolderAccess": {
        "filename_patterns": ["MRU Folder Access.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)", "Folder Accessed", "Application Name"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_MRUOpenSaved": {
        "filename_patterns": ["MRU Opened-Saved Files.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["Last Access Date/Time - UTC+00:00 (M/d/yyyy)", "Full Path", "Program Name"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_MRURecent": {
        "filename_patterns": ["MRU Recent Files & Folders.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["Last Modified Date/Time - UTC+00:00 (M/d/yyyy)", "Shortcut Target Path", "Shortcut Name"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_Prefetch": {
        "filename_patterns": ["Prefetch Files - Windows 8-10-11.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": [
            "Last Run Time - UTC+00:00 (M/d/yyyy)",
            "Executable Path", "Executable Name"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_RecycleBin": {
        "filename_patterns": ["Recycle Bin.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["Deleted Date/Time - UTC+00:00 (M/d/yyyy)", "Original Path", "Current Location"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_Shellbags": {
        "filename_patterns": ["Shellbags.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["First Interaction Date/Time - UTC+00:00 (M/d/yyyy)", "Path"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },
    "Axiom_UserAssist": {
        "filename_patterns": ["UserAssist.csv"],
        "foldername_patterns": ["axiom"],
        "required_headers": ["Last Execution Date/Time - UTC+00:00 (M/d/yyyy)", "Program Path", "Program Name", "Execution Count"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
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
            "timestamp", "EventID", "Computer", "detections", "path", "Threat Name", "Threat Path", "SHA1", "User"

        ],
        "strict_filename_match": True,
        "strict_folder_match": False
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
    
    print(f"[{artifact_name}] Processing: {os.path.basename(file_path)}")

    if use_chunks:
        with tqdm(
            total=total_lines,
            unit="rows",
            unit_scale=True,
            desc=f"{artifact_name}",
            ncols=90,
            ascii=False,  # ✨ force Unicode
            dynamic_ncols=False,
            bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}, {rate_fmt}]"
        ) as pbar:
            for chunk in pd.read_csv(file_path, chunksize=batch_size, encoding=encoding, on_bad_lines="skip"):
                yield chunk
                pbar.update(len(chunk))
    else:
        df = pd.read_csv(file_path, encoding=encoding, on_bad_lines="skip")
        yield df
