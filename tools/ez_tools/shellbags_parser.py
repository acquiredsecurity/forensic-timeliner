import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_shellbags(ez_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Shellbags"
    print(f"[Shellbags] Scanning for relevant CSVs under: {ez_dir}")

    shellbag_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not shellbag_files:
        print("[Shellbags] No Shellbags files found.")
        return

    for file_path in shellbag_files:
        print(f"[Shellbags] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="Shellbags"):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print(f"[Shellbags] Failed to parse {file_path}: {e}")

def _normalize_rows(df, evidence_path, base_dir):
    timeline_data = []
    date_columns = [
        ("LastWriteTime", "Last Write"),
        ("FirstInteracted", "First Interacted"),
        ("LastInteracted", "Last Interacted")
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

            timeline_row = {
                "DateTime": dt_str,
                "TimestampInfo": label,
                "ArtifactName": "Shellbags",
                "Tool": "EZ Tools",
                "Description": "File & Folder Access",
                "DataPath": row.get("AbsolutePath", ""),
                "DataDetails": row.get("Value", ""),
                "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path
            }
            timeline_data.append(timeline_row)
    return timeline_data
