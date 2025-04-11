import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_amcache(input_dir: str, batch_size: int):
    if not os.path.exists(input_dir):
        print(f"[Amcache] ProgramExecution directory not found: {input_dir}")
        return

    amcache_files = [
        os.path.join(input_dir, f)
        for f in os.listdir(input_dir)
        if f.endswith("ssociatedFileEntries.csv")
    ]

    if not amcache_files:
        print("[Amcache] No Amcache files found.")
        return

    for file in amcache_files:
        print(f"[Amcache] Processing {file}")
        if should_use_batch(file, batch_size):
            for chunk in pd.read_csv(file, chunksize=batch_size):
                rows = _normalize_amcache_rows(chunk)
                add_rows(rows)
        else:
            try:
                df = pd.read_csv(file)
                rows = _normalize_amcache_rows(df)
                add_rows(rows)
            except Exception as e:
                print(f"[Amcache] Error reading {file}: {e}")

def _normalize_amcache_rows(df):
    timeline_data = []
    for _, row in df.iterrows():
        timestamp = row.get("FileKeyLastWriteTimestamp", "")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors='coerce')
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue

        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "Last Write",
            "ArtifactName": "Amcache",
            "Tool": "EZ Tools",
            "Description": "Program Execution",
            "DataDetails": row.get("ApplicationName", ""),
            "DataPath": row.get("FullPath", ""),
            "FileExtension": row.get("FileExtension", ""),
            "SHA1": row.get("SHA1", "")
        }
        timeline_data.append(timeline_row)

    return timeline_data
