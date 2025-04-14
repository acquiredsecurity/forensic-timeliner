# tools/chainsaw/sigma_chainsaw_parser.py
import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_chainsaw_sigma(chainsaw_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Chainsaw_Sigma"
    print_and_log(f"[Chainsaw_Sigma] Scanning for relevant CSVs under: {chainsaw_dir}")

    sigma_files = find_artifact_files(chainsaw_dir, base_dir, artifact_name)
    if not sigma_files:
        print_and_log("[Chainsaw_Sigma] No Sigma Chainsaw CSVs found.")
        return

    for file_path in sigma_files:
        print_and_log(f"[Chainsaw_Sigma] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="Chainsaw_Sigma"):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print_and_log(f"[Chainsaw_Sigma] Failed to process {file_path}: {e}")

def _normalize_rows(df, evidence_path, base_dir):
    timeline_data = []

    for _, row in df.iterrows():
        timestamp = row.get("UtcTime") or row.get("Timestamp") or ""
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue

        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "EventTime",
            "ArtifactName": "Sigma Match",
            "Tool": "Chainsaw",
            "Description": row.get("RuleTitle", "Sigma Rule Triggered"),
            "DataDetails": row.get("Detection", row.get("RuleId", "")),
            "EventId": row.get("EventID", ""),
            "Computer": row.get("ComputerName", ""),
            "User": row.get("User", ""),
            "CommandLine": row.get("CommandLine", ""),
            "ProcessName": row.get("Image", ""),
            "SHA1": row.get("SHA1", ""),
            "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path,
        }
        timeline_data.append(timeline_row)

    return timeline_data
