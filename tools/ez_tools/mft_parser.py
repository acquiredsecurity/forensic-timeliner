import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_mft(ez_dir: str, batch_size: int, base_dir: str, extension_filter=None, path_filter=None):
    artifact_name = "MFT"
    print(f"[MFT] Scanning for relevant CSVs under: {ez_dir}")

    mft_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not mft_files:
        print(f"[MFT] No MFT files found in: {ez_dir}")
        return

    for file_path in mft_files:
        print(f"[MFT] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="MFT"):
                timeline_data = _process_dataframe(df, file_path, base_dir, extension_filter, path_filter)
                add_rows(timeline_data)
        except Exception as e:
            print(f"[MFT] Failed to parse {file_path}: {e}")

def _process_dataframe(df, evidence_path, base_dir, extension_filter=None, path_filter=None):
    timeline_data = []
    for _, row in df.iterrows():
        try:
            path = str(row.get("ParentPath", "")) + "\\" + str(row.get("FileName", ""))
            ext = str(row.get("Extension", "")).lower()
            
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
            formatted_dt = parsed_dt.isoformat().replace("+00:00", "Z")
            
            parsed = {
                "DateTime": formatted_dt,
                "TimestampInfo": "Created",
                "ArtifactName": "MFT",
                "Tool": "EZ Tools",
                "Description": "File Created",
                "DataDetails": row.get("FileName", ""),
                "DataPath": path,
                "FileExtension": ext,
                "SHA1": "",
                "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path
            }
            timeline_data.append(parsed)
        except Exception as e:
            print(f"    [!] Error parsing row: {e}")
            continue
    
    return timeline_data
