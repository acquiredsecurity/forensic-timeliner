import os
from datetime import datetime
import re
import pandas as pd
import csv

def normalize_datetime_field(value):
    """
    Normalize various DateTime formats to: YYYY-MM-DD HH:MM:SS
    """
    if not isinstance(value, str):
        return value
    try:
        value = re.sub(r"[TZ]", " ", value).split(".")[0].strip()
        dt = datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return value

def export_to_csv(data, output_path):
    

    df = pd.DataFrame(data)

    # Normalize DateTime column if it exists
    if "DateTime" in df.columns:
        df["DateTime"] = df["DateTime"].apply(normalize_datetime_field)

        # Sort by DateTime
        try:
            df["DateTime"] = pd.to_datetime(df["DateTime"], errors='coerce')
            df = df.sort_values("DateTime")
        except Exception as e:
            print(f"[!] Warning: Failed to sort by DateTime: {e}")

    # Define the preferred field order
    preferred_order = [
        "DateTime", "TimestampInfo", "ArtifactName", "Tool", "Description",
        "DataDetails", "DataPath", "FileExtension", "EventId",
        "User", "Computer", "CommandLine", "ProcessName", "FileSize", "IPAddress",
        "SourceAddress", "DestinationAddress", "LogonType", "UserSID", "MemberSID",
        "ServiceType", "SHA1", "Count", "EvidencePath"
    ]

    # Apply preferred order + preserve unknown fields at the end
    ordered_columns = [col for col in preferred_order if col in df.columns]
    extra_columns = [col for col in df.columns if col not in ordered_columns]
    df = df[ordered_columns + extra_columns]

    df = df.fillna("").astype(str)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    if os.path.exists(output_path):
        print(f"[!] File already exists. Deleting: {output_path}")
        os.remove(output_path)

    df.to_csv(
        output_path,
        index=False,
        encoding='utf-8',
        quoting=csv.QUOTE_MINIMAL,
        lineterminator='\r\n',
        na_rep=''
    )

    print(f"Exported {len(df)} rows to {output_path}")