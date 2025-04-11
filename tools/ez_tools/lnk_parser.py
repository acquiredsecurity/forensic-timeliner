import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_lnk(input_dir: str, batch_size: int, base_dir: str):
    if not os.path.exists(input_dir):
        print("[LNK] FileFolderAccess directory not found: {}".format(input_dir))
        return

    lnk_files = []
    for root, _, files in os.walk(input_dir):
        for f in files:
            if f.lower().endswith("_lecmd_output.csv"):
                lnk_files.append(os.path.join(root, f))

    if not lnk_files:
        print("[LNK] No LNK files found.")
        return

    for file in lnk_files:
        print(f"[LNK] Processing {file}")
        if should_use_batch(file, batch_size):
            for chunk in pd.read_csv(file, chunksize=batch_size):
                rows = _normalize_rows(chunk, base_dir)
                add_rows(rows)
        else:
            df = pd.read_csv(file)
            rows = _normalize_rows(df, base_dir)
            add_rows(rows)

def _normalize_rows(df, base_dir):
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

            evidence_path = os.path.relpath(row.get("SourceFile", ""), base_dir)

            timeline_row = {
                "DateTime": dt_str,
                "TimestampInfo": label,
                "ArtifactName": "LNK",
                "Tool": "EZ Tools",
                "Description": "LNK Shortcut Execution",
                "DataDetails": data_details,
                "DataPath": data_path,
                "FileSize": row.get("FileSize", ""),
                "EvidencePath": evidence_path
            }
            timeline_data.append(timeline_row)

    return timeline_data

def _parse_evidence_path(full_path, base_dir):
    if full_path and full_path.startswith(base_dir):
        return full_path[len(base_dir):].lstrip("\\/")
    return full_path
