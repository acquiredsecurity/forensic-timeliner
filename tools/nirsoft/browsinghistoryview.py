import os
import pandas as pd
from collector.collector import add_rows

def process_browsinghistoryview(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print(f"[Nirsoft] Nirsoft directory not found: {input_dir}")
        return

    csv_files = [
        os.path.join(input_dir, f)
        for f in os.listdir(input_dir)
        if f.lower().endswith(".csv") and "brow" in f.lower()
    ]

    if not csv_files:
        print("[Nirsoft] No BrowsingHistoryView CSVs found.")
        return

    for file in csv_files:
        print(f"[Nirsoft] Processing {file}")
        try:
            if batch_size > 0:
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
            dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
            if pd.isnull(dt):
                continue
            dt_str = dt.isoformat().replace("+00:00", "Z")
        except:
            continue

        url = str(row.get("URL", ""))
        title = str(row.get("Title", "")).strip()
        description = "Web Activity"
        data_details = ""

        if url.lower().startswith("file:///"):
            if "/" in url:
                filename = url.split("/")[-1]
                data_details = filename
            description = "File & Folder Access"
        elif any(x in url.lower() for x in ["search", "query", "q=", "p=", "find", "lookup", "google.com/search", "bing.com/search", "duckduckgo.com/?q=", "yahoo.com/search"]):
            description = "Web Search"
            data_details = title
        elif any(x in url.lower() for x in ["download", ".exe", ".zip", ".rar", ".7z", ".msi", ".iso", ".pdf", ".dll", "/downloads/"]):
            description = "Web Download"
            data_details = title
        else:
            data_details = title

        timeline_row = {
            "DateTime": dt_str,
            "TimestampInfo": "Event Time",
            "ArtifactName": "BrowsingHistoryView",
            "Tool": "Nirsoft",
            "Description": description,
            "DataDetails": data_details,
            "DataPath": url,
            "User": row.get("User Profile", ""),
            "EvidencePath": row.get("History File", "")
        }
        timeline_data.append(timeline_row)

    return timeline_data
