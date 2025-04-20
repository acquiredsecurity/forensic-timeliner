import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log 
from utils.filters import print_eventlog_filters
from utils.summary import track_summary

# Channel-specific Event ID filters
EVENT_CHANNEL_FILTERS = {
    "Application": [1000, 1001],
    "Microsoft-Windows-PowerShell/Operational": [4100, 4103, 4104],
    "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational": [72, 98, 104, 131, 140],
    "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational": [21, 22],
    "Microsoft-Windows-TaskScheduler/Operational": [106, 140, 141, 129, 200, 201],
    "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational": [261, 1149],
    "Microsoft-Windows-WinRM/Operational": [169],
    "Security": [1102, 4624, 4625, 4648, 4698, 4702, 4720, 4722, 4723, 4724, 4725, 4726, 4732, 4756],
    "SentinelOne/Operational": [1, 31, 55, 57, 67, 68, 77, 81, 93, 97, 100, 101, 104, 110],
    "System": [7045],
}

def process_eventlog(ez_dir: str, batch_size: int, base_dir: str):
    artifact_name = "EventLogs"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {ez_dir}")

    print_eventlog_filters(EVENT_CHANNEL_FILTERS)

    eventlog_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not eventlog_files:
        print("[EventLogs] No CSV event log files found.")
        return

    for file_path in eventlog_files:
        print(f"[EventLogs] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                filtered_df = df[df.apply(_eventlog_filter, axis=1)]
                timeline_data = []

                for _, row in filtered_df.iterrows():
                    timestamp = row.get("TimeCreated", "")
                    dt = pd.to_datetime(timestamp, utc=True, errors='coerce')
                    if pd.isnull(dt):
                        continue

                    dt_str = dt.isoformat().replace("+00:00", "Z")

                    timeline_row = {
                        "DateTime": dt_str,
                        "TimestampInfo": "Event Time",
                        "ArtifactName": artifact_name,
                        "Tool": "EZ Tools",
                        "Description": row.get("Channel", ""),
                        "DataDetails": row.get("MapDescription", ""),
                        "DataPath": row.get("PayloadData1", ""),
                        "Computer": row.get("Computer", ""),
                        "User": row.get("UserName", ""),
                        "DestinationAddress": row.get("RemoteHost", ""),
                        "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path,
                        "EventId": row.get("EventId", "")
                    }

                    timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)
                track_summary("EZ Tools", artifact_name, len(timeline_data))
        except Exception as e:
            print(f"[EventLogs] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")

def _eventlog_filter(row):
    channel = str(row.get("Channel", "")).strip()
    event_id = row.get("EventId")

    if not channel or pd.isnull(event_id):
        return False

    try:
        return int(event_id) in EVENT_CHANNEL_FILTERS.get(channel, [])
    except (ValueError, TypeError):
        return False