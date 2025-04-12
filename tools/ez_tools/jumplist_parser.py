import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_jumplists(base_dir: str, batch_size: int):
    artifact_name = "JumpLists"
    print(f"[JumpLists] Scanning for relevant CSVs under: {base_dir}")

    jumplist_files = find_artifact_files(base_dir, artifact_name)

    if not jumplist_files:
        print("[JumpLists] No JumpLists found.")
        return

    for file_path in jumplist_files:
        print(f"[JumpLists] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print(f"[JumpLists] Failed to parse {file_path}: {e}")

def _normalize_rows(df, evidence_path, base_dir):
    timeline_data = []
    date_columns = [
        ("SourceCreated", "Source Created"),
        ("SourceModified", "Source Modified"),
        ("SourceAccessed", "Source Accessed"),
        ("CreationTime", "Creation Time"),
        ("LastModified", "Last Modified"),
        ("TargetCreated", "Target Created"),
        ("TargetModified", "Target Modified"),
        ("TargetAccessed", "Target Accessed"),
        ("TrackerCreatedOn", "Tracker Created On")
    ]
    for _, row in df.iterrows():
        for col, label in date_columns:
            timestamp = row.get(col, "")
            try:
                dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                if pd.isnull(dt):
                    continue
                dt_str = dt.isoformat().replace("+00:00", "Z")
            except:
                continue
            
            data_path = row.get("Path", "")
            data_details = os.path.basename(data_path) if data_path else ""
            timeline_row = {
                "DateTime": dt_str,
                "TimestampInfo": label,
                "ArtifactName": "JumpLists",
                "Tool": "EZ Tools",
                "Description": "File & Folder Access",
                "DataDetails": data_details,
                "DataPath": data_path,
                "FileSize": row.get("FileSize", ""),
                "EvidencePath": os.path.relpath(evidence_path, base_dir)
            }
            timeline_data.append(timeline_row)
    return timeline_data