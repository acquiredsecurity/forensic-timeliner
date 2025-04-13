import os
import pandas as pd
from utils.discovery import find_artifact_files, load_csv_with_progress
from collector.collector import add_rows

def process_lnk(ez_dir: str, batch_size: int, base_dir: str):
    artifact_name = "LNK"
    print(f"[LNK] Scanning for relevant CSVs under: {ez_dir}")

    lnk_files = find_artifact_files(ez_dir, base_dir, artifact_name)

    if not lnk_files:
        print("[LNK] No LNK files found.")
        return

    for file_path in lnk_files:
        print(f"[LNK] Processing {file_path}")
        try:
            for df in load_csv_with_progress(file_path, batch_size, artifact_name="LNK"):
                rows = _normalize_rows(df, file_path, base_dir)
                add_rows(rows)
        except Exception as e:
            print(f"[LNK] Failed to parse {file_path}: {e}")

def _normalize_rows(df, evidence_path, base_dir):
    timeline_data = []
    date_columns = [
        ("SourceCreated", "Source Created"),
        ("SourceModified", "Source Modified"),
        ("SourceAccessed", "Source Accessed"),
        ("TargetCreated", "Target Created"),
        ("TargetModified", "Target Modified"),
        ("TargetAccessed", "Target Accessed")
    ]
    for _, row in df.iterrows():
        for col, label in date_columns:
            timestamp = row.get(col, "")
            try:
                dt = pd.to_datetime(timestamp, utc=True, errors="coerce")
                if pd.isnull(dt):
                    continue
                dt_str = dt.isoformat().replace("+00:00", "Z")
            except:
                continue

            data_path = next(
                (
                    val for val in [
                        row.get("LocalPath"),
                        row.get("TargetIDAbsolutePath"),
                        row.get("NetworkPath"),
                        _parse_evidence_path(row.get("SourceFile", ""), base_dir)
                    ]
                    if isinstance(val, str) and val.strip()
                ),
                ""
            )

            if data_path:
                if os.path.splitext(data_path)[1]:
                    data_details = os.path.basename(data_path)
                else:
                    data_details = os.path.basename(os.path.normpath(data_path))
            else:
                data_details = ""

            timeline_row = {
                "DateTime": dt_str,
                "TimestampInfo": label,
                "ArtifactName": "LNK",
                "Tool": "EZ Tools",
                "Description": "LNK Shortcut Execution",
                "DataDetails": data_details,
                "DataPath": data_path,
                "FileSize": row.get("FileSize", ""),
                "EvidencePath": os.path.relpath(evidence_path, base_dir) if base_dir else evidence_path
            }
            timeline_data.append(timeline_row)
    return timeline_data

def _parse_evidence_path(full_path, base_dir):
    if full_path and base_dir and full_path.startswith(base_dir):
        return full_path[len(base_dir):].lstrip("\\/")
    return full_path
