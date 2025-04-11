import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_deleted(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print(f"[Deleted] FileDeletion directory not found: {input_dir}")
        return

    deleted_files = []
    for root, _, files in os.walk(input_dir):
        for f in files:
            if f.lower().endswith(".csv"):
                deleted_files.append(os.path.join(root, f))

    if not deleted_files:
        print("[Deleted] No deleted file CSVs found.")
        return

    for file in deleted_files:
        print(f"[Deleted] Processing {file}")
        if should_use_batch(file, batch_size):
            for chunk in pd.read_csv(file, chunksize=batch_size):
                rows = _normalize_rows(chunk, file, base_dir)
                add_rows(rows)
        else:
            df = pd.read_csv(file)
            rows = _normalize_rows(df, file, base_dir)
            add_rows(rows)

def _normalize_rows(df, evidence_path, base_dir):
    timeline_data = []
    for _, row in df.iterrows():
        timestamp = row.get("DeletedOn", "")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue

        full_path = row.get("FileName", "")
        filename = os.path.basename(str(full_path)) if full_path else ""

        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "File Deleted On",
            "ArtifactName": "FileDeletion",
            "Tool": "EZ Tools",
            "Description": "File System",
            "DataDetails": filename,
            "DataPath": full_path,
            "FileSize": row.get("FileSize", ""),
            "EvidencePath": os.path.relpath(row.get("SourceName", ""), base_dir)
        }
        timeline_data.append(timeline_row)

    return timeline_data
