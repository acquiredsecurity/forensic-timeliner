import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_prefetch(ez_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Prefetch"
    print(f"[Prefetch] Scanning for relevant CSVs under: {ez_dir}")

    prefetch_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not prefetch_files:
        print("[Prefetch] No Prefetch files found.")
        return

    for file_path in prefetch_files:
        print(f"[Prefetch] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="Prefetch"):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print(f"[Prefetch] Failed to parse {file_path}: {e}")

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
