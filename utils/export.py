import os

def export_to_csv(data, output_path):
    import pandas as pd
    import csv

    df = pd.DataFrame(data)

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

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    if os.path.exists(output_path):
        print(f"[!] File already exists. Deleting: {output_path}")
        os.remove(output_path)

    df.to_csv(
        output_path,
        index=False,
        encoding='utf-8',
        quoting=csv.QUOTE_MINIMAL,
        lineterminator='\n'
    )

    print(f"Exported {len(df)} rows to {output_path}")
