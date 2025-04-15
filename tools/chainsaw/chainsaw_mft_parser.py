import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_chainsaw_mft(chainsaw_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Chainsaw_Mft"
    print_and_log(f"[Chainsaw - {artifact_name}] Scanning for relevant CSVs under: {chainsaw_dir}")

    csv_files = find_artifact_files(chainsaw_dir, base_dir, artifact_name)

    if not csv_files:
        print_and_log(f"[Chainsaw - {artifact_name}] No files found.")
        return

    for file_path in csv_files:
        print_and_log(f"[Chainsaw - {artifact_name}] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="Chainsaw"):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print_and_log(f"[Chainsaw - {artifact_name}] Failed to parse {file_path}: {e}")

def _normalize_rows(df, evidence_path, base_dir):
    timeline_data = []

    for _, row in df.iterrows():
        timestamp = row.get("timestamp")
        dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
        if pd.isnull(dt):
            continue
        dt_str = dt.isoformat().replace("+00:00", "Z")

        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "Created",
            "ArtifactName": "MFT",
            "Tool": "Chainsaw",
            "Description": "Chainsaw MFT",
            "DataDetails": row.get("detections", ""),
            "DataPath": row.get("FileNamePath", ""),
            "FileSize": row.get("FileSize", ""),
            "FileExtension": os.path.splitext(str(row.get("FileNamePath", "")))[-1].lstrip(".").lower() if row.get("path") else "",
            "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path,
        }
        timeline_data.append(timeline_row)

    return timeline_data
