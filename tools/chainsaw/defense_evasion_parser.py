import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_defense_evasion(chainsaw_dir: str, batch_size: int, base_dir: str):
    artifact_name = "defense_evasion"
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

        data_path = next((
            row.get(field) for field in [
                "Threat Path", "Scheduled Task Name", "FileNamePath",
                "Information", "HostApplication", "Service File Name", "Event Data"
            ] if row.get(field)
        ), "")

        user = row.get("User") or row.get("User Name") or ""

        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "EventTime",
            "ArtifactName": "Chainsaw - Defense Evasion",
            "Tool": "Chainsaw",
            "Description": "Sigma Rule Match",
            "DataPath": data_path,
            "DataDetails": row.get("detections", ""),
            "User": user,
            "Computer": row.get("Computer", ""),
            "UserSID": row.get("User SID", ""),
            "MemberSID": row.get("Member SID", ""),
            "ProcessName": row.get("Process Name", ""),
            "CommandLine": row.get("CommandLine", ""),
            "IPAddress": row.get("IP Address", ""),
            "SourceAddress": row.get("Source Address", ""),
            "DestinationAddress": row.get("Dest Address", ""),
            "LogonType": row.get("Logon Type", ""),
            "ServiceType": row.get("Service Type", ""),
            "SHA1": row.get("SHA1", ""),
            "Count": row.get("count", ""),
            "EventId": row.get("Event ID", ""),
            "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path,
        }

        timeline_data.append(timeline_row)

    return timeline_data
