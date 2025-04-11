import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_registry(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print("[Registry] Registry directory not found: {}".format(input_dir))
        return

    reg_files = []
    for root, _, files in os.walk(input_dir):
        for f in files:
            if f.endswith("_RECmd_Batch_Kroll_Batch_Output.csv"):
                reg_files.append(os.path.join(root, f))

    if not reg_files:
        print("[Registry] No Registry CSVs found.")
        return

    for file in reg_files:
        print(f"[Registry] Processing {file}")
        if should_use_batch(file, batch_size):
            for chunk in pd.read_csv(file, chunksize=batch_size):
                rows = _normalize_rows(chunk, base_dir, file)
                add_rows(rows)
        else:
            df = pd.read_csv(file)
            rows = _normalize_rows(df, base_dir, file)
            add_rows(rows)

def _normalize_rows(df, base_dir, evidence_path):
    timeline_data = []
    for _, row in df.iterrows():
        timestamp = row.get("LastWriteTimestamp", "")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue

        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "Last Write",
            "ArtifactName": "Registry",
            "Tool": "EZ Tools",
            "Description": row.get("Category", ""),
            "DataDetails": row.get("Description", ""),
            "DataPath": row.get("ValueData", ""),
            "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path
        }
        timeline_data.append(timeline_row)

    return timeline_data
