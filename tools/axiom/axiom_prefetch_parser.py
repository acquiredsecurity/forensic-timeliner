import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.summary import track_summary

def process_axiom_prefetch(axiom_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Axiom_Prefetch"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {axiom_dir}")

    prefetch_files = find_artifact_files(axiom_dir, base_dir, artifact_name)
    if not prefetch_files:
        print_and_log(f"[{artifact_name}] No Prefetch files found.")
        return

    date_columns = [
        ("File Created Date/Time - UTC+00:00 (M/d/yyyy)", "Source Created"),
        ("Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Last Run"),
        ("2nd Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 1"),
        ("3rd Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 2"),
        ("4th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 3"),
        ("5th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 4"),
        ("6th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 5"),
        ("7th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 6"),
        ("8th Last Run Date/Time - UTC+00:00 (M/d/yyyy)", "Previous Run 7"),
        ("Volume Created Date/Time - UTC+00:00 (M/d/yyyy)", "Volume Created")
    ]

    for file_path in prefetch_files:
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
                            "TimestampInfo": label,
                            "ArtifactName": "Prefetch",
                            "Tool": "Axiom",
                            "Description": "Program Execution",
                            "DataPath": row.get("Application Path", ""),
                            "DataDetails": row.get("Application Name", ""),
                            "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path,
                            "Count": row.get("Application Run Count", "")
                        }

                        timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)

            track_summary("Axiom", artifact_name, total_rows)
            print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")

        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue
