import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log 

def process_amcache(ez_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Amcache"
    print(f"[Amcache] Scanning for relevant CSVs under: {ez_dir}")

    amcache_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not amcache_files:
        print("[Amcache] No Amcache-associated files found.")
        return

    for file_path in amcache_files:
        print(f"[Amcache] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="Amcache"):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print(f"[Amcache] Failed to parse {file_path}: {e}")

def _normalize_rows(df, evidence_path, base_dir):
    timeline_data = []

    for _, row in df.iterrows():
        timestamp = row.get("FileKeyLastWriteTimestamp", "")
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
            "ArtifactName": "Amcache",
            "Tool": "EZ Tools",
            "Description": "Program Execution",
            "DataPath": row.get("FullPath", ""),
            "DataDetails": row.get("ApplicationName", ""),
            "FileSize": row.get("Size", ""),
            "FileExtension": row.get("FileExtension", ""),
            "SHA1": row.get("SHA1", ""),
            "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path,
        }
        timeline_data.append(timeline_row)

    return timeline_data
