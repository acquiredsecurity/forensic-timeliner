import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.summary import track_summary

def process_shellbags(ez_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Shellbags"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {ez_dir}")

    shellbag_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not shellbag_files:
        print_and_log(f"[{artifact_name}] No Shellbags files found.")
        return

    date_columns = [
        ("LastWriteTime", "Last Write"),
        ("FirstInteracted", "First Interacted"),
        ("LastInteracted", "Last Interacted")
    ]

    for file_path in shellbag_files:
        print_and_log(f"[{artifact_name}] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                timeline_data = []

                for _, row in df.iterrows():
                    for col, label in date_columns:
                        timestamp = row.get(col, "")
                        dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                        if pd.isnull(dt):
                            continue
                        dt_str = dt.isoformat().replace("+00:00", "Z")

                        timeline_row = {
                            "DateTime": dt_str,
                            "TimestampInfo": label,
                            "ArtifactName": artifact_name,
                            "Tool": "EZ Tools",
                            "Description": "File & Folder Access",
                            "DataPath": row.get("AbsolutePath", ""),
                            "DataDetails": row.get("Value", ""),
                            "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path
                        }

                        timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)
                track_summary("EZ Tools", artifact_name, len(timeline_data))
        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")