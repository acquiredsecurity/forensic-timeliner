import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows
from utils.logger import print_and_log

from utils.logger import print_and_log  # Make sure this is imported at the top

def process_mft(ez_dir: str, batch_size: int, base_dir: str, extension_filter=None, path_filter=None):
    artifact_name = "MFT"
    print_and_log(f"[MFT] Scanning for relevant CSVs under: {ez_dir}")

    # Display current filter settings
    print_and_log("")
    print_and_log("  Current MFT Filters:")
    print_and_log("  (You can customize these with --MFTExtensionFilter and --MFTPathFilter)")
    print_and_log("  --------------------------------------------------------")

    if extension_filter:
        print_and_log("  File Extension Filters:")
        for ext in sorted(extension_filter):
            print_and_log(f"    {ext}")
    else:
        print_and_log("  File Extension Filters: [None]")

    if path_filter:
        print_and_log("  Path Substring Filters:")
        for p in sorted(path_filter):
            print_and_log(f"    {p}")
    else:
        print_and_log("  Path Substring Filters: [None]")

    mft_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not mft_files:
        print_and_log(f"[MFT] No MFT files found in: {ez_dir}")
        return

    for file_path in mft_files:
        print_and_log(f"[MFT] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="MFT"):
                timeline_data = _process_dataframe(df, file_path, base_dir, extension_filter, path_filter)
                add_rows(timeline_data)
        except Exception as e:
             print_and_log(f"[MFT] Failed to parse {file_path}: {e}")

def _process_dataframe(df, evidence_path, base_dir, extension_filter=None, path_filter=None):
    timeline_data = []

    for _, row in df.iterrows():
        try:
            parent = row.get("ParentPath", "")
            filename = row.get("FileName", "")

            # Defensive: Convert to string only if not already a list
            if isinstance(parent, list) or isinstance(filename, list):
                print_and_log(f"    [!] Skipped row: ParentPath or FileName is a list. Row: {row.to_dict()}")
                continue


            path = str(parent) + "\\" + str(filename)
            ext = str(row.get("Extension", "")).lower()

            # Optional filters
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
                "ArtifactName": "MFT",
                "Tool": "EZ Tools",
                "Description": "File Created",
                "DataDetails": filename,
                "DataPath": path,
                "FileExtension": ext,
                "SHA1": ""
                
            }
            timeline_data.append(timeline_row)

        except Exception as e:
            print_and_log(f"    [!] Error parsing row: {e}")
            print_and_log(f"        Raw Row: {row.to_dict()}")  # helpful for debugging
            continue

    return timeline_data
