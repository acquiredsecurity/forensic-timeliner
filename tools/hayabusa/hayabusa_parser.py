import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

def process_hayabusa(hayabusa_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Hayabusa"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {hayabusa_dir}")

    hayabusa_files = find_artifact_files(hayabusa_dir, base_dir, artifact_name)

    if not hayabusa_files:
        print_and_log(f"[{artifact_name}] No Hayabusa CSVs found.")
        return

    for file_path in hayabusa_files:
        print_and_log(f"[{artifact_name}] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                timeline_data = []

                # Fallback header mapping
                if "Timestamp" not in df.columns:
                    for alt in ["timestamp", "datetime", "date", "time", "event_time", "eventtime"]:
                        if alt in df.columns:
                            df = df.rename(columns={alt: "Timestamp"})
                            break
                if "Timestamp" not in df.columns:
                    print_and_log(f"  [!] Skipping file due to missing Timestamp column")
                    continue

                for _, row in df.iterrows():
                    try:
                        timestamp = row.get("Timestamp", "")
                        dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                        if pd.isnull(dt):
                            continue
                        dt_str = dt.isoformat().replace("+00:00", "Z")

                        timeline_row = {
                            "DateTime": dt_str,
                            "Tool": "Hayabusa",
                            "ArtifactName": "EventLogs",
                            "TimestampInfo": "Event Time",
                            "Description": row.get("Channel", "Unknown Channel"),
                            "EventId": str(row.get("EventID", "")),
                            "DataPath": row.get("Details", ""),
                            "DataDetails": row.get("RuleTitle", ""),
                            "Computer": row.get("Computer", ""),
                            "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path,
                        }

                        # Optional extra fields
                        for field in ["Level", "Message", "Category", "Provider", "Severity"]:
                            if field in row:
                                timeline_row[field] = row.get(field, "")

                        timeline_data.append(timeline_row)
                    except Exception as e:
                        print_and_log(f"  [!] Error normalizing row: {e}")
                        continue

                total_rows += len(timeline_data)
                add_rows(timeline_data)
        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")