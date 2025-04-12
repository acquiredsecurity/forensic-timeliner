from pathlib import Path
import pandas as pd
from tqdm import tqdm
import os

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

def find_artifact_files(base_dir: str, artifact_name: str) -> list:
    """
    Recursively locate CSV files matching artifact's known patterns or headers.
    Returns a list of matching file paths.
    """
    base_path = Path(base_dir)
    if not base_path.exists():
        print(f"[Discovery] Base directory not found: {base_dir}")
        return []

    artifact = ARTIFACT_SIGNATURES.get(artifact_name)
    if not artifact:
        print(f"[Discovery] No known signature for artifact: {artifact_name}")
        return []

    matches = []
    for root, dirs, files in os.walk(base_path):
        # Check folder names if foldername_patterns exist
        folder_matched = artifact.get("foldername_patterns", []) and any(
            any(pattern in os.path.basename(root).lower() 
                for pattern in artifact["foldername_patterns"])
        )

        # Process files in the directory
        for fname in files:
            if not fname.lower().endswith('.csv'):
                continue

            file_path = os.path.join(root, fname)
            
            # Match conditions: 
            # 1. Filename patterns match
            # 2. Folder name matches (if patterns exist)
            filename_matched = any(p in fname.lower() for p in artifact["filename_patterns"])
            
            if filename_matched or folder_matched:
                matches.append(file_path)
                continue

            # Fallback to header checking
            try:
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    first_line = f.readline()
                    headers = [h.strip().lower() for h in first_line.split(",")]
                    required = [h.lower() for h in artifact["required_headers"]]
                    
                    # Change: Require at least a minimum number of headers to match
                    # For example, require at least 50% of headers to be present
                    min_match_threshold = max(1, len(required) // 2)
                    matched_headers = sum(1 for h in required if h in headers)
                    
                    if matched_headers >= min_match_threshold:
                        matches.append(file_path)
            except Exception as e:
                print(f"[Discovery] Failed to inspect {file_path}: {e}")

    return matches

def load_csv_with_progress(file_path: str, batch_size: int):
    """
    Load CSV using tqdm progress bar if file has more than batch_size rows.
    Yields DataFrame chunks.
    """
    try:
        total_lines = sum(1 for _ in open(file_path, encoding="utf-8", errors="ignore")) - 1  # exclude header
    except Exception as e:
        print(f"[Discovery] Could not count lines in {file_path}: {e}")
        total_lines = 0

    use_chunks = total_lines > batch_size
    if use_chunks:
        for chunk in tqdm(pd.read_csv(file_path, chunksize=batch_size, encoding="utf-8", on_bad_lines="skip"),
                          total=total_lines // batch_size + 1,
                          desc=f"[Batching] {os.path.basename(file_path)}"):
            yield chunk
    else:
        df = pd.read_csv(file_path, encoding="utf-8", on_bad_lines="skip")
        yield df