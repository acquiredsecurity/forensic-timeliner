import os
import pandas as pd
from utils.batch import should_use_batch
from collector.collector import add_rows

def process_mft(input_dir: str, batch_size: int, extension_filter=None, path_filter=None, base_dir: str = ""):
    print(f"[MFT] Looking in: {input_dir}")
    if not os.path.exists(input_dir):
        print(f"  [!] MFT input directory does not exist: {input_dir}")
        return

    mft_files = []
    for root, _, files in os.walk(input_dir):
        for f in files:
            if f.endswith(".csv") and "_MFTECmd_$MFT_Output" in f:
                mft_files.append(os.path.join(root, f))

    if not mft_files:
        print(f"  [!] No MFT files found in: {input_dir}")
        return

    for filename in mft_files:
        print(f"[MFT] Processing {filename}")

        if should_use_batch(filename, batch_size):
            chunks = pd.read_csv(filename, chunksize=batch_size, low_memory=False)
        else:
            chunks = [pd.read_csv(filename, low_memory=False)]

        for df in chunks:
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

                    try:
                        parsed_dt = pd.to_datetime(dt_str, utc=True, errors='coerce')
                        if pd.isnull(parsed_dt):
                            continue
                        formatted_dt = parsed_dt.isoformat().replace("+00:00", "Z")
                    except Exception:
                        continue

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
                        "EvidencePath": os.path.relpath(filename, base_dir) if base_dir else filename
                    }
                    timeline_data.append(parsed)
                except Exception as e:
                    print(f"    [!] Error parsing row: {e}")
                    continue
            add_rows(timeline_data)
