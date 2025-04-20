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

    # Normalize and sort by DateTime
    if "DateTime" in df.columns:
        df["DateTime"] = df["DateTime"].apply(normalize_datetime_field)
        try:
            df["DateTime"] = pd.to_datetime(df["DateTime"], errors='coerce')
            df = df.sort_values("DateTime")
        except Exception as e:
            print(f"[!] Warning: Failed to sort by DateTime: {e}")

    # Safely convert FileSize
    if "FileSize" in df.columns:
        def safe_int(x):
            try:
                if pd.isnull(x) or str(x).strip() == "":
                    return ""
                return int(float(x))
            except:
                return ""
        df["FileSize"] = df["FileSize"].apply(safe_int)

    # Define the preferred field order
    preferred_order = [
        "DateTime", "TimestampInfo", "ArtifactName", "Tool", "Description",
        "DataDetails", "DataPath", "FileExtension", "EventId",
        "User", "Computer", "FileSize", "IPAddress",
        "SourceAddress", "DestinationAddress", "SHA1", "Count", "EvidencePath"
    ]

    # Ensure all preferred fields exist, even if missing from the data
    for col in preferred_order:
        if col not in df.columns:
            df[col] = ""

    # Apply preferred order + preserve any extra columns
    ordered_columns = preferred_order + [col for col in df.columns if col not in preferred_order]
    df = df[ordered_columns]

    # Sanitize
    df = df.fillna("").astype(str)

    # Ensure directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    # Delete existing file if present
    if os.path.exists(output_path):
        print(f"[!] File already exists. Deleting: {output_path}")
        os.remove(output_path)

    # Export to CSV (RFC 4180-compliant)
    df.to_csv(
        output_path,
        index=False,
        encoding='utf-8',
        quoting=csv.QUOTE_MINIMAL,
        lineterminator='\r\n',
        na_rep=''
    )

    print(f"Exported {len(df)} rows to {output_path}")
