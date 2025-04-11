import os
import pandas as pd
from utils.batch import should_use_batch
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

def process_eventlog(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print(f"[EventLogs] Directory not found: {input_dir}")
        return

    eventlog_files = []
    for root, _, files in os.walk(input_dir):
        for f in files:
            if f.lower().endswith(".csv"):
                eventlog_files.append(os.path.join(root, f))

    if not eventlog_files:
        print("[EventLogs] No CSV event log files found.")
        return

    for file in eventlog_files:
        print(f"[EventLogs] Processing {file}")
        if should_use_batch(file, batch_size):
            for chunk in pd.read_csv(file, chunksize=batch_size):
                _process_dataframe(chunk, base_dir)
        else:
            df = pd.read_csv(file)
            _process_dataframe(df, base_dir)

def _process_dataframe(df: pd.DataFrame, base_dir: str):
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
            "EvidencePath": os.path.relpath(row.get("SourceFile", ""), base_dir),
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
