import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.summary import track_summary

def process_axiom_mrufolderaccess(axiom_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Axiom_MRUFolderAccess"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {axiom_dir}")

    folder_files = find_artifact_files(axiom_dir, base_dir, artifact_name)
    if not folder_files:
        print_and_log(f"[{artifact_name}] No MRU Folder Access files found.")
        return

    for file_path in folder_files:
        print_and_log(f"[{artifact_name}] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                timeline_data = []

                for _, row in df.iterrows():
                    timestamp = row.get("Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)", "")
                    dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                    if pd.isnull(dt):
                        continue

                    path = row.get("Folder Accessed", "")
                    if not isinstance(path, str) or path.strip() == "":
                        continue

                    timeline_row = {
                        "DateTime": dt.isoformat().replace("+00:00", "Z"),
                        "Tool": "Axiom",
                        "ArtifactName": "MRU Folder Access",
                        "TimestampInfo": "Registry Modified",
                        "Description": "File & Folder Access",
                        "DataPath": path,
                        "DataDetails": row.get("Application Name", ""),
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

