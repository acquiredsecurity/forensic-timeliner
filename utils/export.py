import os

def export_to_csv(data, output_path):
    import pandas as pd
    import csv

    df = pd.DataFrame(data)
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
