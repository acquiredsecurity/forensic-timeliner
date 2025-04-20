import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.summary import track_summary

def process_browsinghistoryview(nirsoft_dir: str, batch_size: int, base_dir: str):
    artifact_name = "NirsoftBrowsingHistory"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {nirsoft_dir}")

    bhv_files = find_artifact_files(nirsoft_dir, base_dir, artifact_name)

    if not bhv_files:
        print_and_log("[Nirsoft] No BrowsingHistoryView CSVs found.")
        return

    for file_path in bhv_files:
        print_and_log(f"[{artifact_name}] Processing {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="WebHistory"):
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
                    description = "Web History"  # Always "Web History" for Nirsoft combined browsers
                    data_details = title

                    # Check URL for activity type
                    activity = ""
                    if url.startswith("file:///"):
                        activity = " + File Open Access"
                    elif any(term in url for term in ["search", "query", "q=", "p=", "find", "lookup", "google.com/search", "bing.com/search", "duckduckgo.com/?q=", "yahoo.com/search"]):
                        activity = " + Search"
                    elif any(term in url for term in ["download", ".exe", ".zip", ".rar", ".7z", ".msi", ".iso", ".pdf", ".dll", "/downloads/"]):
                        activity = " + Download"

                   # Extract browser and build description
                    browser = row.get("Web Browser", "").strip()
                    description = f"{browser}{activity if activity else ''}"

                    # Create timeline row
                    timeline_row = {
                        "DateTime": dt_str,
                        "Tool": "Nirsoft",
                        "ArtifactName": "Web History",
                        "TimestampInfo": "Last Visited",
                        "Description": description,
                        "DataPath": url,
                        "DataDetails": data_details,
                        "User": row.get("User Profile", ""),
                        "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path
                    }

                    timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)
                track_summary("Nirsoft", artifact_name, len(timeline_data))
        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")
