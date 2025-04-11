import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_prefetch(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print("[Prefetch] ProgramExecution directory not found: {}".format(input_dir))
        return

    prefetch_files = []
    for root, _, files in os.walk(input_dir):
        for f in files:
            if f.lower().endswith("_pecmd_output.csv"):
                prefetch_files.append(os.path.join(root, f))

    if not prefetch_files:
        print("[Prefetch] No Prefetch files found.")
        return

    for file in prefetch_files:
        print(f"[Prefetch] Processing {file}")
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
    date_columns = [
        ("SourceCreated", "Source Created"),
        ("SourceModified", "Source Modified"),
        ("SourceAccessed", "Source Accessed"),
        ("LastRun", "Last Run"),
        ("Volume0Created", "Volume Created"),
    ]

    for i in range(7):
        date_columns.append((f"PreviousRun{i}", f"Previous Run {i}"))

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

            timeline_row = {
                "DateTime": dt_str,
                "TimestampInfo": label,
                "ArtifactName": "Prefetch",
                "Tool": "EZ Tools",
                "Description": "Program Execution",
                "DataPath": row.get("SourceFilename", ""),
                "DataDetails": row.get("ExecutableName", ""),
                "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path,
                "Count": row.get("RunCount", "")
            }
            timeline_data.append(timeline_row)

    return timeline_data
