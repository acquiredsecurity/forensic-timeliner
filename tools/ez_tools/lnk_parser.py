import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.summary import track_summary

def process_lnk(ez_dir: str, batch_size: int, base_dir: str):
    artifact_name = "LNK"
    print(f"[LNK] Scanning for relevant CSVs under: {ez_dir}")

    lnk_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not lnk_files:
        print("[LNK] No LNK files found.")
        return

    timestamp_fields = [
        "SourceCreated", "SourceModified", "SourceAccessed",
        "TargetCreated", "TargetModified", "TargetAccessed",
        "TrackerCreatedOn"
    ]

    path_fields = ["LocalPath", "TargetIDAbsolutePath", "NetworkPath"]

    for file_path in lnk_files:
        print(f"[LNK] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                timeline_data = []

                for _, row in df.iterrows():
                    for ts_field in timestamp_fields:
                        timestamp = row.get(ts_field, "")
                        dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                        if pd.isnull(dt):
                            continue

                        dt_str = dt.isoformat().replace("+00:00", "Z")

                        # Determine best DataPath
                        data_path = ""
                        for pf in path_fields:
                            data_path = row.get(pf, "")
                            if pd.notnull(data_path) and str(data_path).strip():
                                break

                        timeline_row = {
                            "DateTime": dt_str,
                            "TimestampInfo": ts_field,
                            "ArtifactName": artifact_name,
                            "Tool": "EZ Tools",
                            "Description": "File & Folder Access",
                            "DataDetails": row.get("RelativePath", ""),
                            "DataPath": data_path,
                            "FileSize": row.get("FileSize", ""),
                            "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path,
                        }

                        timeline_data.append(timeline_row)

                total_rows += len(timeline_data)
                add_rows(timeline_data)
                track_summary("EZ Tools", artifact_name, len(timeline_data))
        except Exception as e:
            print(f"[LNK] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")
