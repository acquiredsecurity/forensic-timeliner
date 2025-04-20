import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.summary import track_summary

def process_axiom_jumplist(axiom_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Axiom_JumpLists"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {axiom_dir}")

    jump_files = find_artifact_files(axiom_dir, base_dir, artifact_name)
    if not jump_files:
        print_and_log(f"[{artifact_name}] No JumpList files found.")
        return

    for file_path in jump_files:
        print_and_log(f"[{artifact_name}] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                timeline_data = []
                date_columns = [
                    ("Target File Created Date/Time - UTC+00:00 (M/d/yyyy)", "Target Created"),
                    ("Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)", "Target Modified"),
                    ("Target File Last Accessed Date/Time - UTC+00:00 (M/d/yyyy)", "Target Accessed"),
                    ("Last Access Date/Time - UTC+00:00 (M/d/yyyy)", "Source Accessed")
                ]

                for _, row in df.iterrows():
                    for time_field, label in date_columns:
                        timestamp = row.get(time_field, "")
                        dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                        if pd.isnull(dt):
                            continue

                        target = next(
                            (
                                val for val in [
                                    row.get("Linked Path"),
                                    row.get("Location"),
                                    row.get("Source")
                                ] if isinstance(val, str) and val.strip()
                            ),
                            ""
                        )

                        if target:
                            if os.path.splitext(target)[1]:
                                details = os.path.basename(target)
                            else:
                                details = os.path.basename(os.path.normpath(target))
                        else:
                            details = row.get("Potential App Name", "")

                        timeline_row = {
                            "DateTime": dt.isoformat().replace("+00:00", "Z"),
                            "Tool": "Axiom",
                            "ArtifactName": "JumpLists",
                            "TimestampInfo": label,
                            "Description": "File & Folder Access",
                            "DataPath": target,
                            "DataDetails": details,
                            "FileSize": row.get("Target File Size (Bytes)", ""),
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

