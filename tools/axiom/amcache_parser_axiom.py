import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_amcache_axiom(axiom_dir: str, base_dir: str, batch_size: int):
    
    artifact_name = "AxiomAmcache"
    print(f"[Axiom Amcache] Scanning for relevant CSVs under: {base_dir}")

    amcache_files = find_artifact_files(axiom_dir, base_dir, artifact_name)

    if not amcache_files:
        print("[Axiom Amcache] No Amcache files found.")
        return

    for file_path in amcache_files:
        print(f"[Axiom Amcache] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print(f"[Axiom Amcache] Failed to parse {file_path}: {e}")

def _normalize_rows(df, evidence_path, base_dir):
    """
    Normalize the rows from an Axiom Amcache CSV into a standard timeline format.
    
    Args:
        df (DataFrame): Pandas DataFrame containing Amcache data
        evidence_path (str): Path to the evidence file
        base_dir (str): Base directory for relative path calculation
        
    Returns:
        list: List of normalized timeline rows
    """
    timeline_data = []
    
    for _, row in df.iterrows():
        # Parse timestamp
        timestamp = row.get("Key Last Updated Date/Time - UTC+00:00 (M/d/yyyy)", "")
        try:
            # Convert timestamp to ISO format
            dt = pd.to_datetime(timestamp, utc=True, errors='coerce')
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except Exception:
            continue

        # Create timeline entry
        timeline_row = {
            "DateTime": dt_str,
            "Tool": "Axiom",
            "ArtifactName": "Amcache",
            "TimestampInfo": "Last Write",
            "Description": "Program Execution",
            "DataPath": row.get("Full Path", ""),
            "DataDetails": row.get("Associated Application Name", ""),
            "FileExtension": row.get("File Extension", ""),
            "SHA1": row.get("SHA1 Hash", ""),
            "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path
        }
        
        timeline_data.append(timeline_row)
    
    return timeline_data