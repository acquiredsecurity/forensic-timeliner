import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_appcompat(base_dir: str, batch_size: int):
    artifact_name = "AppCompatCache"
    print(f"[AppCompat] Scanning for relevant CSVs under: {base_dir}")

    appcompat_files = find_artifact_files(base_dir, artifact_name)

    if not appcompat_files:
        print("[AppCompat] No AppCompatCache files found.")
        return

    all_rows = []
    for file_path in appcompat_files:
        print(f"[AppCompat] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size):
                all_rows.extend(_normalize_rows(df, file_path))
        except Exception as e:
            print(f"[AppCompat] Failed to parse {file_path}: {e}")
    
    add_rows(all_rows)

def _normalize_rows(df, evidence_path):
    timeline_data = []
    for _, row in df.iterrows():
        timestamp = row.get("LastModifiedTimeUTC", "")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue
        
        path = row.get("Path", "")
        filename = path.split("\\")[-1] if "\\" in path else path
        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "Last Modified Time",
            "ArtifactName": "AppCompatCache",
            "Tool": "EZ Tools",
            "Description": "Program Execution",
            "DataDetails": filename,
            "DataPath": path,
            "EvidencePath": evidence_path
        }
        timeline_data.append(timeline_row)
    return timeline_data