import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.summary import track_summary


def process_axiom_opera(axiom_dir: str, batch_size: int, base_dir: str):
    artifact_name = "Axiom_Opera"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {axiom_dir}")

    # Find both Web History and Web Visits files
    opera_files = find_artifact_files(axiom_dir, base_dir, artifact_name)
    if not opera_files:
        print_and_log(f"[{artifact_name}] No Opera browser history files found.")
        return

    for file_path in opera_files:
        print_and_log(f"[{artifact_name}] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                timeline_data = []
                for _, row in df.iterrows():
                    # Adjusted timestamp field
                    timestamp = row.get("Date Visited Date/Time - UTC+00:00 (M/d/yyyy)", "")
                    dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                    if pd.isnull(dt):
                        continue
                    dt_str = dt.isoformat().replace("+00:00", "Z")

                    # URL and activity description
                    url = str(row.get("URL", "")).strip().lower()
                    if not url:
                        continue

                    activity = ""
                    if url.startswith("file:///"):
                        activity = " + File Open Access"
                    elif any(term in url for term in ["search", "query", "q=", "p=", "find", "lookup", "google.com/search", "bing.com/search", "duckduckgo.com/?q=", "yahoo.com/search"]):
                        activity = " + Search"
                    elif any(term in url for term in ["download", ".exe", ".zip", ".rar", ".7z", ".msi", ".iso", ".pdf", ".dll", "/downloads/"]):
                        activity = " + Download"

                    title = row.get("Title", "")
                    title = title if title else ""  # Ensure title is empty if not present

                    timeline_row = {
                        "DateTime": dt_str,
                        "Tool": "Axiom",
                        "ArtifactName": "Web History",  # Set as Web History for both types
                        "TimestampInfo": "Last Visited",
                        "Description": "Opera History" + activity,
                        "DataPath": url,
                        "DataDetails": title,
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

