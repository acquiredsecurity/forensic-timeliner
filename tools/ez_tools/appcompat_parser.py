import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_appcompat(input_dir: str, batch_size: int):
    if not os.path.exists(input_dir):
        print(f"[AppCompat] ProgramExecution directory not found: {input_dir}")
        return

    appcompat_files = [
        os.path.join(input_dir, f)
        for f in os.listdir(input_dir)
        if "AppCompatCache" in f and f.endswith(".csv")
    ]

    if not appcompat_files:
        print("[AppCompat] No AppCompatCache files found.")
        return

    for file in appcompat_files:
        print(f"[AppCompat] Processing {file}")
        if should_use_batch(file, batch_size):
            for chunk in pd.read_csv(file, chunksize=batch_size):
                rows = _normalize_rows(chunk)
                add_rows(rows)
        else:
            df = pd.read_csv(file)
            rows = _normalize_rows(df)
            add_rows(rows)

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
