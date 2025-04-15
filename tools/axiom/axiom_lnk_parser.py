import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_axiom_lnk(axiom_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Axiom_LNK"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {axiom_dir}")

    lnk_files = find_artifact_files(axiom_dir, base_dir, artifact_name)
    if not lnk_files:
        print_and_log(f"[{artifact_name}] No LNK files found.")
        return

    date_columns = [
        ("Created Date/Time - UTC+00:00 (M/d/yyyy)", "Source Created"),
        ("Last Modified Date/Time - UTC+00:00 (M/d/yyyy)", "Source Modified"),
        ("Accessed Date/Time - UTC+00:00 (M/d/yyyy)", "Source Accessed"),
        ("Target File Created Date/Time - UTC+00:00 (M/d/yyyy)", "Target Created"),
        ("Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)", "Target Modified"),
        ("Target File Last Accessed Date/Time - UTC+00:00 (M/d/yyyy)", "Target Accessed")
    ]

    for file_path in lnk_files:
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

                        data_path = next(
                            (
                                val for val in [
                                    row.get("Linked Path"),
                                    row.get("Source"),
                                    row.get("Location")
                                ] if isinstance(val, str) and val.strip()
                            ),
                            ""
                        )

                        if data_path:
                            if os.path.splitext(data_path)[1]:
                                data_details = os.path.basename(data_path)
                            else:
                                data_details = os.path.basename(os.path.normpath(data_path))
                        else:
                            data_details = ""

                        timeline_row = {
                            "DateTime": dt.isoformat().replace("+00:00", "Z"),
                            "TimestampInfo": label,
                            "ArtifactName": "LNK",
                            "Tool": "Axiom",
                            "Description": "LNK Shortcut Execution",
                            "DataDetails": data_details,
                            "DataPath": data_path,
                            "FileSize": row.get("Target File Size (Bytes)", ""),
                            "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path
                        }

                        timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)
        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")
