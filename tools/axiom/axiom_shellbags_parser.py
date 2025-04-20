import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.summary import track_summary

def process_axiom_shellbags(axiom_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Axiom_Shellbags"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {axiom_dir}")

    shell_files = find_artifact_files(axiom_dir, base_dir, artifact_name)
    if not shell_files:
        print_and_log(f"[{artifact_name}] No Shellbags files found.")
        return

    date_columns = [
        ("First Interaction Date/Time - UTC+00:00 (M/d/yyyy)", "First Interacted"),
        ("Last Interaction Date/Time - UTC+00:00 (M/d/yyyy)", "Last Interacted"),
        ("File System Last Modified Date/Time - UTC+00:00 (M/d/yyyy)", "File Modified"),
        ("File System Last Accessed Date/Time - UTC+00:00 (M/d/yyyy)", "File Accessed"),
        ("File System Created Date/Time - UTC+00:00 (M/d/yyyy)", "File Created")
    ]

    for file_path in shell_files:
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

                        timeline_row = {
                            "DateTime": dt.isoformat().replace("+00:00", "Z"),
                            "Tool": "Axiom",
                            "ArtifactName": "Shellbags",
                            "TimestampInfo": label,
                            "Description": "Folder Accessed",
                            "DataPath": row.get("Path", ""),
                            "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path
                        }

                        timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)

            track_summary("Axiom", artifact_name, total_rows)
            print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")

        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue

