import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_browsinghistoryview(base_dir: str, batch_size: int):
    artifact_name = "NirsoftBrowsingHistory"
    print(f"[Nirsoft] Scanning for relevant CSVs under: {base_dir}")

    bhv_files = find_artifact_files(base_dir, artifact_name)

    if not bhv_files:
        print("[Nirsoft] No BrowsingHistoryView CSVs found.")
        return

    for file_path in bhv_files:
        print(f"[Nirsoft] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size):
                rows = _normalize_rows(df, file_path)
                add_rows(rows)
        except Exception as e:
            print(f"[Nirsoft] Failed to parse {file_path}: {e}")

def _normalize_rows(df, evidence_path):
    timeline_data = []
    for _, row in df.iterrows():
        timestamp = row.get("Visit Time", "")
        try:
            dt = pd.to_datetime(timestamp, utc=True, errors='coerce')
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue
        
        url = str(row.get("URL", "")).strip().lower()
        title = row.get("Title", "")
        description = "Web Activity"
        data_details = title
        
        if url.startswith("file:///"):
            if "/" in url:
                data_details = url.split("/")[-1]
            description = "File & Folder Access"
        elif any(term in url for term in ["search", "query", "q=", "p=", "find", "lookup", "google.com/search", "bing.com/search", "duckduckgo.com/?q=", "yahoo.com/search"]):
            description = "Web Search"
        elif any(term in url for term in ["download", ".exe", ".zip", ".rar", ".7z", ".msi", ".iso", ".pdf", ".dll", "/downloads/"]):
            description = "Web Download"
        
        timeline_row = {
            "DateTime": dt_str,
            "Tool": "Nirsoft",
            "ArtifactName": "WebHistory",
            "TimestampInfo": "EventTime",
            "DataPath": url,
            "DataDetails": data_details,
            "Description": description,
            "User": row.get("User Profile", ""),
            "EvidencePath": str(row.get("History File", evidence_path))
        }
        timeline_data.append(timeline_row)
    
    return timeline_data