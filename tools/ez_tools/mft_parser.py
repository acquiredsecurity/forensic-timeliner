import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log
from utils.filters import print_mft_filters
from utils.summary import track_summary

# These are always included
DEFAULT_EXTENSIONS = [".identifier", ".exe", ".ps1", ".zip", ".rar", ".7z"]
DEFAULT_PATHS = ["Users"]

def process_mft(ez_dir: str, batch_size: int, base_dir: str, extension_filter=None, path_filter=None):
    artifact_name = "MFT"
    print_and_log(f"[{artifact_name}] Scanning for relevant CSVs under: {ez_dir}")
    print_mft_filters()

    # Merge user-supplied filters with the defaults
    extension_filter = (extension_filter or []) + DEFAULT_EXTENSIONS
    path_filter = (path_filter or []) + DEFAULT_PATHS

    mft_files = find_artifact_files(ez_dir, base_dir, artifact_name)
    if not mft_files:
        print_and_log(f"[{artifact_name}] No MFT files found in: {ez_dir}")
        return

    for file_path in mft_files:
        print_and_log(f"[{artifact_name}] Processing: {file_path}")
        total_rows = 0
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name=artifact_name):
                timeline_data = []

                for _, row in df.iterrows():
                    try:
                        parent = row.get("ParentPath", "")
                        filename = row.get("FileName", "")

                        if isinstance(parent, list) or isinstance(filename, list):
                            print_and_log(f"    [!] Skipped row: ParentPath or FileName is a list. Row: {row.to_dict()}")
                            continue

                        path = f"{parent}\\{filename}"
                        ext = str(row.get("Extension", "")).lower()

                        # Apply filters (merged with defaults above)
                        if extension_filter and not any(ext.endswith(e.lower()) for e in extension_filter):
                            continue
                        if path_filter and not any(p.lower() in path.lower() for p in path_filter):
                            continue

                        dt_str = str(row.get("Created0x10", "")).strip()
                        if not dt_str:
                            continue

                        parsed_dt = pd.to_datetime(dt_str, utc=True, errors='coerce')
                        if pd.isnull(parsed_dt):
                            continue

                        timeline_row = {
                            "DateTime": parsed_dt.isoformat().replace("+00:00", "Z"),
                            "TimestampInfo": "Created",
                            "ArtifactName": artifact_name,
                            "Tool": "EZ Tools",
                            "Description": "File Created",
                            "DataDetails": filename,
                            "DataPath": path,
                            "FileExtension": ext,
                            "EvidencePath": os.path.relpath(file_path, base_dir) if base_dir else file_path,
                        }

                        timeline_data.append(timeline_row)

                    except Exception as e:
                        print_and_log(f"    [!] Error parsing row: {e}")
                        print_and_log(f"        Raw Row: {row.to_dict()}")
                        continue

                total_rows += len(timeline_data)
                add_rows(timeline_data)
                track_summary("EZ Tools", artifact_name, len(timeline_data))

        except Exception as e:
            print_and_log(f"[{artifact_name}] Failed to parse {file_path}: {e}")
            continue

        print_and_log(f"[✓] Parsed {total_rows} timeline rows from: {file_path}")
