import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_axiom_amcache(axiom_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Axiom_Amcache"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {base_dir}")

    amcache_files = find_artifact_files(axiom_dir, base_dir, artifact_name)
    if not amcache_files:
        print_and_log(f"[{artifact_name}] No Amcache files found.")
        return

    for file_path in amcache_files:
        print_and_log(f"[{artifact_name}] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                timeline_data = []

                for _, row in df.iterrows():
                    timestamp = row.get("Key Last Updated Date/Time - UTC+00:00 (M/d/yyyy)", "")
                    dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                    if pd.isnull(dt):
                        continue

                    timeline_row = {
                        "DateTime": dt.isoformat().replace("+00:00", "Z"),
                        "Tool": "Axiom",
                        "ArtifactName": "Amcache",
                        "TimestampInfo": "Last Write",
                        "Description": "Program Execution",
                        "DataPath": row.get("Full Path", "") or "",
                        "DataDetails": row.get("Associated Application Name", "") or "",
                        "FileExtension": row.get("File Extension", "") or "",
                        "SHA1": row.get("SHA1 Hash", "") or "",
                        "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path
                    }

                    timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)
        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")
