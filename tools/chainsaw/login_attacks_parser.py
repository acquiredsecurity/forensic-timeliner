import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_login_attacks(chainsaw_dir: str, batch_size: int, base_dir: str):
    artifact_name = "login_attacks"
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
        timestamp = row.get("Timestamp") or row.get("TimeCreated") or row.get("UtcTime")
        dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
        if pd.isnull(dt):
            continue
        dt_str = dt.isoformat().replace("+00:00", "Z")

        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "EventTime",
            "ArtifactName": "Login Attacks",
            "Tool": "Chainsaw",
            "Description": row.get("detections", ""),
            "DataPath": row.get("Threat Path") or row.get("Scheduled Task Name") or row.get("FileNamePath")
                        or row.get("Information") or row.get("HostApplication") or row.get("Service File Name")
                        or row.get("Event Data", ""),
            "User": row.get("User") or row.get("User Name", ""),
            "Computer": row.get("Computer", ""),
            "UserSID": row.get("User SID", ""),
            "MemberSID": row.get("Member SID", ""),
            "ProcessName": row.get("Process Name", ""),
            "IPAddress": row.get("IP Address", ""),
            "LogonType": row.get("Logon Type", ""),
            "Count": row.get("count", ""),
            "SourceAddress": row.get("Source Address", ""),
            "DestinationAddress": row.get("Dest Address", ""),
            "ServiceType": row.get("Service Type", ""),
            "CommandLine": row.get("CommandLine", ""),
            "SHA1": row.get("SHA1", ""),
            "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path,
        }
        timeline_data.append(timeline_row)

    return timeline_data
