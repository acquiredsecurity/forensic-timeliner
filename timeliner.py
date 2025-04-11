import pandas as pd
import os
from datetime import datetime

# Define your timeline output columns
PREFERRED_FIELDS = [
    "DateTime", "TimestampInfo", "ArtifactName", "Tool", "Description",
    "DataDetails", "DataPath", "FileExtension", "EvidencePath", "EventId",
    "User", "Computer", "CommandLine", "ProcessName", "FileSize", "IPAddress",
    "SourceAddress", "DestinationAddress", "LogonType", "UserSID",
    "MemberSID", "ServiceType", "SHA1", "Count"
]

def normalize_amcache_row(row):
    try:
        dt = datetime.strptime(row['FileKeyLastWriteTimestamp'], "%Y-%m-%d %H:%M:%S.%f")
        formatted_dt = dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        formatted_dt = row['FileKeyLastWriteTimestamp']

    return {
        "DateTime": formatted_dt,
        "TimestampInfo": "Last Write",
        "ArtifactName": "Amcache",
        "Tool": "EZ Tools",
        "Description": "Program Execution",
        "DataDetails": row.get("ApplicationName", ""),
        "DataPath": row.get("FullPath", ""),
        "FileExtension": row.get("FileExtension", ""),
        "SHA1": row.get("SHA1", ""),
        # The rest can be left blank for now
        **{key: "" for key in PREFERRED_FIELDS if key not in [
            "DateTime", "TimestampInfo", "ArtifactName", "Tool", "Description",
            "DataDetails", "DataPath", "FileExtension", "SHA1"
        ]}
    }

def process_amcache_csv(file_path):
    print(f"Processing {file_path}")
    try:
        df = pd.read_csv(file_path)
        if 'FileKeyLastWriteTimestamp' not in df.columns:
            print("    Skipping: Missing expected Amcache header.")
            return []

        return [normalize_amcache_row(row) for _, row in df.iterrows()]
    except Exception as e:
        print(f"    Error: {e}")
        return []

def process_amcache_directory(directory):
    timeline_rows = []
    for file in os.listdir(directory):
        if "ssociatedFileEntries" in file and file.endswith(".csv"):
            full_path = os.path.join(directory, file)
            rows = process_amcache_csv(full_path)
            timeline_rows.extend(rows)
    return timeline_rows

if __name__ == "__main__":
    # Set your test folder path here
    amcache_dir = r"C:\triage\kape\ProgramExecution"
    timeline = process_amcache_directory(amcache_dir)
    df_output = pd.DataFrame(timeline, columns=PREFERRED_FIELDS)
    df_output.to_csv("Forensic_Timeline_Amcache.csv", index=False)
    print(f"Exported {len(df_output)} rows to Forensic_Timeline_Amcache.csv")
