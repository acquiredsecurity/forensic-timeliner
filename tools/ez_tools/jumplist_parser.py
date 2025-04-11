import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_jumplists(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print("[JumpLists] FileFolderAccess directory not found: {}".format(input_dir))
        return

    jumplist_files = [
        os.path.join(input_dir, f)
        for f in os.listdir(input_dir)
        if f.lower().endswith("_automaticdestinations.csv")
    ]

    if not jumplist_files:
        print("[JumpLists] No JumpList files found.")
        return

    for file in jumplist_files:
        print(f"[JumpLists] Processing {file}")
        if should_use_batch(file, batch_size):
            for chunk in pd.read_csv(file, chunksize=batch_size):
                rows = _normalize_rows(chunk, base_dir)
                add_rows(rows)
        else:
            df = pd.read_csv(file)
            rows = _normalize_rows(df, base_dir)
            add_rows(rows)

def _normalize_rows(df, base_dir):
    timeline_data = []
    date_columns = [
        ("SourceCreated", "Source Created"),
        ("SourceModified", "Source Modified"),
        ("SourceAccessed", "Source Accessed"),
        ("CreationTime", "Creation Time"),
        ("LastModified", "Last Modified"),
        ("TargetCreated", "Target Created"),
        ("TargetModified", "Target Modified"),
        ("TargetAccessed", "Target Accessed"),
        ("TrackerCreatedOn", "Tracker Created On")
    ]

    for _, row in df.iterrows():
        for col, label in date_columns:
            timestamp = row.get(col, "")
            try:
                dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                if pd.isnull(dt):
                    continue
                dt_str = dt.isoformat().replace("+00:00", "Z")
            except:
                continue

            data_path = row.get("Path", "")
            data_details = os.path.basename(data_path) if data_path else ""

            timeline_row = {
                "DateTime": dt_str,
                "TimestampInfo": label,
                "ArtifactName": "JumpLists",
                "Tool": "EZ Tools",
                "Description": "File & Folder Access",
                "DataDetails": data_details,
                "DataPath": data_path,
                "FileSize": row.get("FileSize", ""),
                "EvidencePath": row.get("SourceFile", "")
            }
            timeline_data.append(timeline_row)

    return timeline_data
