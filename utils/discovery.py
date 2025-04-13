import os
from pathlib import Path
import pandas as pd
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeRemainingColumn

console = Console()

ARTIFACT_SIGNATURES = {
    "Amcache": {
        "filename_patterns": ["ssociatedfileentries"],
        "foldername_patterns": ["kape", "ez", "ProgramExecution"],
        "required_headers": [
            "ApplicationName", "ProgramId", "FileKeyLastWriteTimestamp", "SHA1",
            "IsOsComponent", "FullPath", "Name", "FileExtension", "LinkDate",
            "ProductName", "Size", "Version", "ProductVersion", "LongPathHash",
            "BinaryType", "IsPeFile", "BinFileVersion", "BinProductVersion",
            "Usn", "Language", "Description"
        ]
    },
    "AppCompatCache": {
        "filename_patterns": ["appcompatcache"],
        "foldername_patterns": ["kape", "ez", "ProgramExecution"],
        "required_headers": [
            "ControlSet", "CacheEntryPosition", "Path",
            "LastModifiedTimeUTC", "Executed", "Duplicate", "SourceFile"
        ]
    },
    "Deleted": {
        "filename_patterns": ["_rbcmd_output"],
        "foldername_patterns": ["kape", "ez", "FileDeletion"],
        "required_headers": [
            "SourceName", "FileType", "FileName", "FileSize", "DeletedOn"
        ]
    },
    "EventLogs": {
        "filename_patterns": ["evtxecmd"],
        "foldername_patterns": ["kape", "ez", "EventLogs"],
        "required_headers": [
            "TimeCreated", "EventId", "Channel", "Computer", "MapDescription",
            "SourceFile", "PayloadData1"
        ]
    },
    "JumpLists": {
        "filename_patterns": ["automaticdestinations"],
        "foldername_patterns": ["kape", "ez", "FileFolderAccess"],
        "required_headers": [
            "Path", "AppId", "AppIdDescription", "CreationTime",
            "SourceCreated", "SourceModified", "SourceAccessed",
            "TargetCreated", "TargetModified", "TargetAccessed"
        ]
    },
    "LNK": {
        "filename_patterns": ["_lecmd_output"],
        "foldername_patterns": ["kape", "ez", "FileFolderAccess"],
        "required_headers": [
            "LocalPath", "TargetIDAbsolutePath", "NetworkPath",
            "SourceCreated", "SourceModified", "SourceAccessed",
            "TargetCreated", "TargetModified", "TargetAccessed"
        ]
    },
    "MFT": {
        "filename_patterns": ["_mftecmd_$mft_output"],
        "foldername_patterns": ["kape", "ez", "FileSystem"],
        "required_headers": [
            "FileName", "ParentPath", "Extension", "Created0x10"
        ]
    },
    "Prefetch": {
        "filename_patterns": ["_pecmd_output"],
        "foldername_patterns": ["kape", "ez", "ProgramExecution"],
        "required_headers": [
            "ExecutableName", "SourceFilename", "LastRun", "RunCount",
            "SourceCreated", "SourceModified", "SourceAccessed", "Volume0Created"
        ]
    },
    "Registry": {
        "filename_patterns": ["_recmd_batch_kroll_batch_output"],
        "foldername_patterns": ["kape", "ez","Registry"],
        "required_headers": [
            "HivePath", "HiveType", "Description", "Category", "KeyPath",
            "ValueName", "ValueType", "ValueData", "LastWriteTimestamp"
        ]
    },
    "Shellbags": {
        "filename_patterns": ["_usrclass", "_ntuser"],
        "foldername_patterns": ["kape", "ez", "FileFolderAccess"],
        "required_headers": [
            "BagPath", "AbsolutePath", "Value",
            "LastWriteTime", "FirstInteracted", "LastInteracted"
        ]
    },
    "Hayabusa": {
        "filename_patterns": ["hayabusa", "haya"],
        "foldername_patterns": ["haya"],
        "required_headers": [
            "Timestamp", "RuleTitle", "Level", "Computer", 
            "Channel", "EventID", "RecordID", "Details", 
            "ExtraFieldInfo", "RuleID"
        ]
    }, 
    "NirsoftBrowsingHistory": {
        "filename_patterns": ["nirsoft", "history", "browsing", "web", "browse"],
        "foldername_patterns": ["nirsoft", "browse"],
        "required_headers": [
            "URL", "Title", "Visit Time", "Visit Count", "Visited From", 
            "Visit Type", "Visit Duration", "Web Browser", "User Profile", 
            "Browser Profile", "URL Length", "Typed Count", "History File", 
            "Record ID"
        ]
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
        folder_matched = artifact.get("foldername_patterns", []) and any(
            pattern in os.path.basename(root).lower()
            for pattern in artifact["foldername_patterns"]
        )

        for fname in files:
            if not fname.lower().endswith('.csv'):
                continue

            file_path = os.path.join(root, fname)
            filename_matched = any(p in fname.lower() for p in artifact["filename_patterns"])

            if filename_matched or folder_matched:
                matches.append(file_path)
                continue

            try:
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    first_line = f.readline()
                    headers = [h.strip().lower() for h in first_line.split(",")]
                    required = [h.lower() for h in artifact["required_headers"]]

                    min_match_threshold = max(1, len(required) // 2)
                    matched_headers = sum(1 for h in required if h in headers)

                    if matched_headers >= min_match_threshold:
                        matches.append(file_path)
            except Exception as e:
                print(f"[Discovery] Failed to inspect {file_path}: {e}")

    return matches

def load_csv_with_progress(file_path: str, batch_size: int, artifact_name: str = "Default"):
    try:
        total_lines = sum(1 for _ in open(file_path, encoding="utf-8", errors="ignore")) - 1
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
            SpinnerColumn(style="cyan"),
            TextColumn("[progress.description]{task.description}", style="bold"),
            BarColumn(bar_width=None, style=style),
            "[progress.percentage]{task.percentage:>3.0f}%",
            TimeRemainingColumn(),
            console=console
        ) as progress:
            task = progress.add_task(f"[{artifact_name}] {os.path.basename(file_path)}", total=total_lines)

            for chunk in pd.read_csv(file_path, chunksize=batch_size, encoding="utf-8", on_bad_lines="skip"):
                yield chunk
                progress.update(task, advance=len(chunk))
    else:
        df = pd.read_csv(file_path, encoding="utf-8", on_bad_lines="skip")
        yield df
