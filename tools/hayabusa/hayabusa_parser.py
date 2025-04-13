import os
import pandas as pd
import logging
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

# Set up logging
logger = logging.getLogger('hayabusa_parser')

def process_hayabusa(hayabusa_dir: str, batch_size: int, base_dir: str):
    """
    Process Hayabusa CSV files to extract timeline information.
    """
    artifact_name = "Hayabusa"
    print(f"[Hayabusa] Scanning for relevant CSVs under: {hayabusa_dir}")

    hayabusa_files = find_artifact_files(hayabusa_dir, base_dir, artifact_name)

    if not hayabusa_files:
        print("[Hayabusa] No Hayabusa CSVs found.")
        return

    processed_count = 0
    for file_path in hayabusa_files:
        print(f"[Hayabusa] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="Hayabusa"):
                rows = _normalize_rows(df, file_path, base_dir)
                if rows:
                    add_rows(rows)
                    processed_count += len(rows)
                    print(f"  [+] Added {len(rows)} Hayabusa entries to timeline")
        except Exception as e:
            print(f"[Hayabusa] Failed to parse {file_path}: {e}")
            logger.error(f"Error processing Hayabusa file {file_path}: {e}", exc_info=True)

    print(f"[Hayabusa] Completed processing {len(hayabusa_files)} files with {processed_count} total entries added to timeline")

def _normalize_rows(df, evidence_path, base_dir):
    """
    Normalize the rows from a Hayabusa CSV into a standard timeline format.
    """
    timeline_data = []

    required_columns = ['Timestamp']
    missing_columns = [col for col in required_columns if col not in df.columns]

    if missing_columns:
        column_mappings = {
            'Timestamp': ['timestamp', 'datetime', 'date', 'time', 'event_time', 'eventtime']
        }
        for required, alternatives in column_mappings.items():
            if required in missing_columns:
                for alt in alternatives:
                    if alt in df.columns:
                        df = df.rename(columns={alt: required})
                        missing_columns.remove(required)
                        break
        if missing_columns:
            logger.error(f"Cannot process file, missing required columns: {missing_columns}")
            return []

    for _, row in df.iterrows():
        try:
            timestamp = row.get("Timestamp")
            dt = pd.to_datetime(timestamp, utc=True, errors='coerce')
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
                "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path
            }

            # Optional metadata
            for field in ["Level", "Message", "Category", "Provider", "Severity"]:
                if field in row:
                    timeline_row[field] = row.get(field, "")

            timeline_data.append(timeline_row)
        except Exception as e:
            logger.error(f"Error normalizing row: {e}")
            continue

    return timeline_data
