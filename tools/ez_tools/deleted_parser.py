import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_deleted(base_dir: str, batch_size: int):
    artifact_name = "Deleted"
    print(f"[Deleted] Scanning for relevant CSVs under: {base_dir}")

    deleted_files = find_artifact_files(base_dir, artifact_name)

    if not deleted_files:
        print("[Deleted] No deleted file CSVs found.")
        return

    for file_path in deleted_files:
        print(f"[Deleted] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print(f"[Deleted] Failed to parse {file_path}: {e}")

def _normalize_rows(df, evidence_path, base_dir):
    timeline_data = []
    for _, row in df.iterrows():
        timestamp = row.get("DeletedOn", "")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue
        
        full_path = row.get("FileName", "")
        filename = os.path.basename(str(full_path)) if full_path else ""
        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "File Deleted On",
            "ArtifactName": "FileDeletion",
            "Tool": "EZ Tools",
            "Description": "File System",
            "DataDetails": filename,
            "DataPath": full_path,
            "FileSize": row.get("FileSize", ""),
            "EvidencePath": os.path.relpath(row.get("SourceName", ""), base_dir)
        }
        timeline_data.append(timeline_row)
    return timeline_data