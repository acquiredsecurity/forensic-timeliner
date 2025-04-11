import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_shellbags(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print("[Shellbags] FileFolderAccess directory not found: {}".format(input_dir))
        return

    shellbag_files = [
        os.path.join(input_dir, f)
        for f in os.listdir(input_dir)
        if f.endswith("_UsrClass.csv") or f.endswith("_NTUSER.csv")
    ]

    if not shellbag_files:
        print("[Shellbags] No UsrClass or NTUSER files found.")
        return

    for file in shellbag_files:
        print(f"[Shellbags] Processing {file}")
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
    timestamp_fields = [
        ("LastWriteTime", "Last Write"),
        ("FirstInteracted", "First Interacted"),
        ("LastInteracted", "Last Interacted")
    ]

    for _, row in df.iterrows():
        for col, label in timestamp_fields:
            timestamp = row.get(col, "")
            try:
                dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                if pd.isnull(dt):
                    continue
                dt_str = dt.isoformat().replace("+00:00", "Z")
            except:
                continue

            timeline_row = {
                "DateTime": dt_str,
                "TimestampInfo": label,
                "ArtifactName": "Shellbags",
                "Tool": "EZ Tools",
                "Description": "File & Folder Access",
                "DataPath": row.get("AbsolutePath", ""),
                "DataDetails": row.get("Value", ""),
                "EvidencePath": row.get("SourceFile", "")
            }
            timeline_data.append(timeline_row)

    return timeline_data
