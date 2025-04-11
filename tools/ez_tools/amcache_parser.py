import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_amcache(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print(f"[Amcache] ProgramExecution directory not found: {input_dir}")
        return

    amcache_files = []
    for root, dirs, files in os.walk(input_dir):
        for f in files:
            if "ssociatedFileEntries" in f and f.lower().endswith(".csv"):
                amcache_files.append(os.path.join(root, f))


    if not amcache_files:
        print("[Amcache] No Amcache files found.")
        return

    all_rows = []

    for file in amcache_files:
        print(f"[Amcache] Processing {file}")
        if should_use_batch(file, batch_size):
            for chunk in pd.read_csv(file, chunksize=batch_size):
                all_rows.extend(_normalize_rows(chunk))
        else:
            try:
                df = pd.read_csv(file)
                all_rows.extend(_normalize_rows(df))
            except Exception as e:
                print(f"[Amcache] Error reading {file}: {e}")

    add_rows(all_rows)

def _normalize_rows(df):
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
            "SHA1": row.get("SHA1", ""),
            "EvidencePath": row.get("SourceFile", "")
        }
        timeline_data.append(timeline_row)

    return timeline_data
