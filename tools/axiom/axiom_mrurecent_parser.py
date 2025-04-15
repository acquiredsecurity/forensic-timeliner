import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_axiom_mrurecent(axiom_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Axiom_MRURecent"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {axiom_dir}")

    recent_files = find_artifact_files(axiom_dir, base_dir, artifact_name)
    if not recent_files:
        print_and_log(f"[{artifact_name}] No MRU Recent files found.")
        return

    for file_path in recent_files:
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

                    data_path = row.get("File/Folder Link", "")
                    data_path = data_path if isinstance(data_path, str) else ""

                    if data_path:
                        if os.path.splitext(data_path)[1]:
                            data_details = os.path.basename(data_path)
                        else:
                            data_details = os.path.basename(os.path.normpath(data_path))
                    else:
                        data_details = row.get("File/Folder Name", "")

                    timeline_row = {
                        "DateTime": dt.isoformat().replace("+00:00", "Z"),
                        "Tool": "Axiom",
                        "ArtifactName": "MRU_Recent",
                        "TimestampInfo": "Key Last Modified",
                        "Description": "Shortcut Accessed",
                        "DataPath": data_path,
                        "DataDetails": data_details,
                        "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path
                    }

                    timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)
        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")