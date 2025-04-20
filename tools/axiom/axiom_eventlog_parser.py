import os
import re
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.summary import track_summary

# Provider Name-based Event ID filter for Axiom logs
EVENT_PROVIDER_FILTERS = {
    "Microsoft-Windows-Security-Auditing": [1102, 4624, 4625, 4648, 4698, 4702, 4720, 4722, 4723, 4724, 4725, 4726, 4732, 4756],
    "Service Control Manager": [7045],
    "Microsoft-Windows-TerminalServices-LocalSessionManager": [21, 22],
    "Windows Error Reporting": [1000, 1001],
    "Microsoft-Windows-WinRM": [169],
    "SentinelOne": [1, 31, 55, 57, 67, 68, 77, 81, 93, 97, 100, 101, 104, 110],
    "Microsoft-Windows-PowerShell": [4104],
}

def process_axiom_eventlog(axiom_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Axiom_EventLogs"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {axiom_dir}")

    eventlog_files = find_artifact_files(axiom_dir, base_dir, artifact_name)
    if not eventlog_files:
        print_and_log(f"[{artifact_name}] No Event Log files found.")
        return

    for file_path in eventlog_files:
        print_and_log(f"[{artifact_name}] Processing: {file_path}")
        total_rows = 0

        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                filtered_df = df[df.apply(_eventlog_filter, axis=1)]
                timeline_data = []

                for _, row in filtered_df.iterrows():
                    timestamp = row.get("Created Date/Time - UTC+00:00 (M/d/yyyy)", "")
                    dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                    if pd.isnull(dt):
                        continue

                    datapath, datadetails = enrich_event_row(row)
                    source = str(row.get("Source", ""))
                    match = re.search(r'\\([^\\]+\.evtx)$', source)
                    description = match.group(1).replace(".evtx", "") if match else row.get("Provider Name", "")


                    timeline_row = {
                        "DateTime": dt.isoformat().replace("+00:00", "Z"),
                        "TimestampInfo": "Event Time",
                        "ArtifactName": "EventLogs",
                        "Tool": "Axiom",
                        "Description": description,
                        "DataDetails": datadetails,
                        "DataPath": datapath,
                        "Computer": row.get("Computer", ""),
                        "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path,
                        "EventId": row.get("Event ID", "")
                    }

                    timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)

        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue

        track_summary("Axiom", artifact_name, total_rows)
        print_and_log(f"[\u2713] Parsed {total_rows} timeline rows from: {file_path}")

def _eventlog_filter(row):
    provider = str(row.get("Provider Name", "")).strip()
    event_id = row.get("Event ID")

    if not provider or pd.isnull(event_id):
        return False

    return provider in EVENT_PROVIDER_FILTERS and int(event_id) in EVENT_PROVIDER_FILTERS[provider]

def enrich_event_row(row):
    summary = str(row.get("Event Description Summary", "") or "")
    event_data = str(row.get("Event Data", "") or "")

    # Always use summary as DataDetails
    datadetails = summary

    # Extract key=value pairs from Event Data (both XML and key: value format)
    extracted_pairs = []

    lines = event_data.strip().splitlines()
    xml_pattern = re.compile(r'<Data Name="([^"]+)">(.*?)</Data>', re.IGNORECASE)
    kv_pattern = re.compile(r'^([^:=\r\n]+?)\s*[:=]\s*(.+)$')

    for line in lines:
        line = line.strip()
        if not line or line.startswith("<Event xmlns="):
            continue

        xml_match = xml_pattern.search(line)
        if xml_match:
            extracted_pairs.append(f"{xml_match.group(1)}={xml_match.group(2)}")
            continue

        kv_match = kv_pattern.match(line)
        if kv_match:
            key = kv_match.group(1).strip()
            val = kv_match.group(2).strip()
            extracted_pairs.append(f"{key}={val}")

    datapath = " | ".join(extracted_pairs)

    return datapath, datadetails