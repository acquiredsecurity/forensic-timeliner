import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_appcompat(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print(f"[AppCompat] ProgramExecution directory not found: {input_dir}")
        return

    appcompat_files = []
    for root, _, files in os.walk(input_dir):
        for f in files:
            if "appcompatcache" in f.lower() and f.lower().endswith(".csv"):
                appcompat_files.append(os.path.join(root, f))

    if not appcompat_files:
        print("[AppCompat] No AppCompatCache files found.")
        return

    all_rows = []

    for file in appcompat_files:
        print(f"[AppCompat] Processing {file}")
        if should_use_batch(file, batch_size):
            for chunk in pd.read_csv(file, chunksize=batch_size):
                all_rows.extend(_normalize_rows(chunk))
        else:
            try:
                df = pd.read_csv(file)
                all_rows.extend(_normalize_rows(df))
            except Exception as e:
                print(f"[AppCompat] Error reading {file}: {e}")

    add_rows(all_rows)

def _normalize_rows(df):
    timeline_data = []
    for _, row in df.iterrows():
        timestamp = row.get("LastModifiedTimeUTC", "")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue

        path = row.get("Path", "")
        filename = path.split("\\")[-1] if "\\" in path else path

        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "Last Modified Time",
            "ArtifactName": "AppCompatCache",
            "Tool": "EZ Tools",
            "Description": "Program Execution",
            "DataDetails": filename,
            "DataPath": path,
            "EvidencePath": row.get("SourceFile", "")
        }
        timeline_data.append(timeline_row)

    return timeline_data