import os
import pandas as pd
from collector.collector import add_rows
from utils.batch import should_use_batch

def process_hayabusa(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print(f"[Hayabusa] Directory not found: {input_dir}")
        return

    hayabusa_files = []
    for root, _, files in os.walk(input_dir):
        for f in files:
            if f.lower().endswith(".csv") and "haya" in f.lower():
                hayabusa_files.append(os.path.join(root, f))

    if not hayabusa_files:
        print("[Hayabusa] No Hayabusa CSVs found.")
        return

    for file in hayabusa_files:
        print(f"[Hayabusa] Processing {file}")
        try:
            if should_use_batch(file, batch_size):
                for chunk in pd.read_csv(file, chunksize=batch_size, encoding_errors='replace'):
                    rows = _normalize_rows(chunk, base_dir, file)
                    add_rows(rows)
            else:
                df = pd.read_csv(file, encoding_errors='replace')
                rows = _normalize_rows(df, base_dir, file)
                add_rows(rows)
        except Exception as e:
            print(f"[Hayabusa] Failed to parse {file}: {e}")

def _normalize_rows(df, base_dir, evidence_path):
    timeline_data = []
    for _, row in df.iterrows():
        timestamp = row.get("Timestamp")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors='coerce')
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue

        timeline_row = {
            "DateTime": dt_str,
            "Tool": "Hayabusa",
            "ArtifactName": "EventLogs",
            "TimestampInfo": "Event Time",
            "Description": row.get("Channel", ""),
            "EventId": row.get("EventID", ""),
            "DataPath": row.get("Details", ""),
            "DataDetails": row.get("RuleTitle", ""),
            "Computer": row.get("Computer", ""),
            "EvidencePath": os.path.relpath(evidence_path, base_dir)
        }
        timeline_data.append(timeline_row)

    return timeline_data
