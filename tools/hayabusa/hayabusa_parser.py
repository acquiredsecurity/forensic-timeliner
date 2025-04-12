import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
import logging

# Set up logging
logger = logging.getLogger('hayabusa_parser')

def process_hayabusa(base_dir: str, batch_size: int):
    """
    Process Hayabusa CSV files to extract timeline information.
    
    Args:
        base_dir (str): Base directory to search for Hayabusa files
        batch_size (int): Number of records to process at once
    """
    artifact_name = "Hayabusa"
    print(f"[Hayabusa] Scanning for relevant CSVs under: {base_dir}")

    # Use discovery utility to find Hayabusa files
    hayabusa_files = find_artifact_files(base_dir, artifact_name)
    
    # Check if we found any files
    if not hayabusa_files:
        print("[Hayabusa] No Hayabusa CSVs found.")
        return

    # Process each Hayabusa file
    processed_count = 0
    for file_path in hayabusa_files:
        print(f"[Hayabusa] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size):
                rows = _normalize_rows(df, base_dir, file_path)
                if rows:
                    add_rows(rows)
                    processed_count += len(rows)
                    print(f"  [+] Added {len(rows)} Hayabusa entries to timeline")
        except Exception as e:
            print(f"[Hayabusa] Failed to parse {file_path}: {e}")
            logger.error(f"Error processing Hayabusa file {file_path}: {e}", exc_info=True)

    print(f"[Hayabusa] Completed processing {len(hayabusa_files)} files with {processed_count} total entries added to timeline")

def _normalize_rows(df, base_dir, evidence_path):
    """
    Normalize the rows from a Hayabusa CSV into a standard timeline format.
    
    Args:
        df (DataFrame): Pandas DataFrame containing Hayabusa data
        base_dir (str): Base directory for relative path calculation
        evidence_path (str): Path to the evidence file
        
    Returns:
        list: List of normalized timeline rows
    """
    timeline_data = []
    
    # Check for required columns
    required_columns = ['Timestamp']
    missing_columns = [col for col in required_columns if col not in df.columns]
    
    # Try to adapt to different column names if necessary
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
        
        # If still missing columns, return empty list
        if missing_columns:
            logger.error(f"Cannot process file, missing required columns: {missing_columns}")
            return []
    
    # Process each row
    for _, row in df.iterrows():
        try:
            # Parse timestamp
            timestamp = row.get("Timestamp")
            try:
                dt = pd.to_datetime(timestamp, utc=True, errors='coerce')
                if pd.isnull(dt):
                    continue
                dt_str = dt.isoformat().replace("+00:00", "Z")
            except Exception as e:
                logger.debug(f"Error parsing date {timestamp}: {e}")
                continue

            # Create timeline entry
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
            
            # Handle optional columns
            if "Level" in row:
                timeline_row["Level"] = row.get("Level", "")
            if "Message" in row:
                timeline_row["Message"] = row.get("Message", "")
            if "Category" in row:
                timeline_row["Category"] = row.get("Category", "")
            if "Provider" in row:
                timeline_row["Provider"] = row.get("Provider", "")
            if "Severity" in row:
                timeline_row["Severity"] = row.get("Severity", "")
                
            timeline_data.append(timeline_row)
        except Exception as e:
            logger.error(f"Error normalizing row: {e}")
            continue

    return timeline_data