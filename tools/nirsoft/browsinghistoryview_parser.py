import os
import pandas as pd
from collector.collector import add_rows
from utils.batch import should_use_batch

def process_browsinghistoryview(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print(f"[Nirsoft] Nirsoft directory not found: {input_dir}")
        return

    bhv_files = []
    for root, _, files in os.walk(input_dir):
        for f in files:
            if "brow" in f.lower() and f.lower().endswith(".csv"):
                bhv_files.append(os.path.join(root, f))

    if not bhv_files:
        print("[Nirsoft] No BrowsingHistoryView CSVs found.")
        return

    for file in bhv_files:
        print(f"[Nirsoft] Processing {file}")
        try:
            if should_use_batch(file, batch_size):
                for chunk in pd.read_csv(file, chunksize=batch_size, encoding="cp1252", on_bad_lines='skip'):
                    rows = _normalize_rows(chunk)
                    add_rows(rows)
            else:
                df = pd.read_csv(file, encoding="cp1252", on_bad_lines='skip')
                rows = _normalize_rows(df)
                add_rows(rows)
        except Exception as e:
            print(f"[Nirsoft] Failed to parse {file}: {e}")

def _normalize_rows(df):
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
            "EvidencePath": row.get("History File", "")
        }
        timeline_data.append(timeline_row)

    return timeline_data
