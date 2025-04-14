import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_chainsaw_account_tampering(chainsaw_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Chainsaw_AccountTampering"
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
            "TimestampInfo": "EventTime",
            "ArtifactName": "EventLogs",
            "Tool": "Chainsaw",
            "Description": "Account Tampering",
            "DataDetails": row.get("detections", ""),
            "DataPath": row.get("User SID", "") or row.get("Member SID", ""),
            "EventId": row.get("Event ID", ""),
            "User": row.get("User Name", ""),
            "Computer": row.get("Computer", ""),
            "EvidencePath": row.get("path", ""),
        }

        timeline_data.append(timeline_row)

    return timeline_data
