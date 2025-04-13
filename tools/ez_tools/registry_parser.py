import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_registry(ez_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Registry"
    print(f"[Registry] Scanning for relevant CSVs under: {ez_dir}")

    reg_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not reg_files:
        print("[Registry] No Registry CSVs found.")
        return

    for file_path in reg_files:
        print(f"[Registry] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="Registry"):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print(f"[Registry] Failed to parse {file_path}: {e}")

def _normalize_rows(df, evidence_path, base_dir):
    timeline_data = []
    for _, row in df.iterrows():
        timestamp = row.get("LastWriteTimestamp", "")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue
        
        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "Last Write",
            "ArtifactName": "Registry",
            "Tool": "EZ Tools",
            "Description": row.get("Category", ""),
            "DataDetails": row.get("Description", ""),
            "DataPath": row.get("ValueData", ""),
            "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path
        }
        timeline_data.append(timeline_row)
    return timeline_data
