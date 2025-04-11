import pandas as pd
import csv

def export_to_csv(df, output_path):
    df.to_csv(
        output_path,
        index=False,
        encoding='utf-8',
        quoting=csv.QUOTE_MINIMAL,
        line_terminator='\n'  # safer newline
    )
    print(f"✅ Exported {len(df)} rows to {output_path}")