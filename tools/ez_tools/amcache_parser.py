import os
import pandas as pd
from utils.export import export_to_csv
from utils.helpers import parse_date

def process_amcache(input_dir, output_dir):
    print("[+] Processing Amcache CSVs...")

    if not os.path.exists(input_dir):
        print(f"[!] Amcache input directory not found: {input_dir}")
        return

    rows = []
    for filename in os.listdir(input_dir):
        if not filename.lower().endswith("associatedfileentries.csv") and not filename.lower().endswith("unassociatedfileentries.csv"):
            continue

        full_path = os.path.join(input_dir, filename)
        print(f"  [-] Processing {filename}")

        try:
            df = pd.read_csv(full_path, encoding='utf-8', low_memory=False)
        except Exception as e:
            print(f"    [!] Error reading {filename}: {e}")
            continue

        for _, row in df.iterrows():
            try:
                date_str = row.get("FileKeyLastWriteTimestamp")
                dt = parse_date(date_str)
                if not dt:
                    continue

                timeline_row = {
                    "DateTime": dt,
                    "TimestampInfo": "Last Write",
                    "ArtifactName": "Amcache",
                    "Tool": "EZ Tools",
                    "Description": "Program Execution",
                    "DataDetails": row.get("ApplicationName"),
                    "DataPath": row.get("FullPath"),
                    "FileExtension": row.get("FileExtension"),
                    "SHA1": row.get("SHA1"),
                }
                rows.append(timeline_row)
            except Exception as e:
                print(f"    [!] Error processing row: {e}")

    if rows:
        df_out = pd.DataFrame(rows)
        output_file = os.path.join(output_dir, "Forensic_Timeline_Amcache.csv")
        export_to_csv(df_out, output_file)
    else:
        print("[!] No Amcache rows found to export.")
