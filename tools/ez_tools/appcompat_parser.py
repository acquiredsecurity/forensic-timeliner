import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_appcompat(ez_dir: str, batch_size: int, base_dir: str):
    artifact_name = "AppCompatCache"
    print_and_log(f"[AppCompat] Scanning for relevant CSVs under: {ez_dir}")

    appcompat_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not appcompat_files:
        print_and_log(f"[AppCompat] No AppCompatCache files found.")
        return

    for file_path in appcompat_files:
        print_and_log(f"[AppCompat] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                timeline_data = []

                for _, row in df.iterrows():
                    timestamp = row.get("LastModifiedTimeUTC", "")
                    dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                    if pd.isnull(dt):
                        continue
                    dt_str = dt.isoformat().replace("+00:00", "Z")

                    path = row.get("Path", "")
                    filename = path.split("\\")[-1] if "\\" in path else path

                    timeline_row = {
                        "DateTime": dt_str,
                        "TimestampInfo": "Last Modified Time",
                        "ArtifactName": artifact_name,
                        "Tool": "EZ Tools",
                        "Description": "Program Execution",
                        "DataDetails": filename,
                        "DataPath": path,
                        "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path
                    }

                    timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)
        except Exception as e:
            print_and_log(f"[AppCompat] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")
