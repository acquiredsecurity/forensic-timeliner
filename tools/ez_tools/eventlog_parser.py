import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

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

def process_eventlog(base_dir: str, batch_size: int):
    artifact_name = "EventLogs"
    print(f"[EventLogs] Scanning for relevant CSVs under: {base_dir}")

    eventlog_files = find_artifact_files(base_dir, artifact_name)

    if not eventlog_files:
        print("[EventLogs] No CSV event log files found.")
        return

    for file_path in eventlog_files:
        print(f"[EventLogs] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size):
                _process_dataframe(df, file_path, base_dir)
        except Exception as e:
            print(f"[EventLogs] Failed to parse {file_path}: {e}")

def _process_dataframe(df: pd.DataFrame, evidence_path: str, base_dir: str):
    filtered_df = df[df.apply(_eventlog_filter, axis=1)]
    rows = []
    for _, row in filtered_df.iterrows():
        timestamp = row.get("TimeCreated", "")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors='coerce')
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue
        
        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "Event Time",
            "ArtifactName": "EventLogs",
            "Tool": "EZ Tools",
            "Description": row.get("Channel", ""),
            "DataDetails": row.get("MapDescription", ""),
            "DataPath": row.get("PayloadData1", ""),
            "Computer": row.get("Computer", ""),
            "EvidencePath": os.path.relpath(evidence_path, base_dir),
            "EventId": row.get("EventId", "")
        }
        rows.append(timeline_row)
    add_rows(rows)

def _eventlog_filter(row):
    channel = str(row.get("Channel", "")).strip()
    event_id = row.get("EventId")
    if not channel or pd.isnull(event_id):
        return False
    return channel in EVENT_CHANNEL_FILTERS and int(event_id) in EVENT_CHANNEL_FILTERS[channel]