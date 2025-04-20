import pandas as pd
import csv

from utils.logger import print_and_log  # Adjust path if needed

def deduplicate_rows(rows):
    """
    Deduplicate a list of dicts based on full row content.
    """
    seen = set()
    deduped = []
    for row in rows:
        key = tuple(row.items())
        if key not in seen:
            seen.add(key)
            deduped.append(row)
    return deduped

def run_post_export_deduplication(output_path: str):
    """
    Load the CSV at `output_path`, deduplicate the rows, and overwrite the file.
    Logs the number of removed rows.
    """
    try:
        df = pd.read_csv(output_path)
        original_count = len(df)

        deduped_rows = deduplicate_rows(df.to_dict(orient="records"))
        deduped_df = pd.DataFrame(deduped_rows)

        deduped_df.to_csv(
            output_path,
            index=False,
            encoding='utf-8',
            quoting=csv.QUOTE_MINIMAL,
            lineterminator='\r\n',
            na_rep=''
        )

        print_and_log(f"[✓] Post-export deduplication complete: removed {original_count - len(deduped_df)} rows (final count: {len(deduped_df)})")

    except Exception as e:
        print_and_log(f"[!] Post-export deduplication failed: {e}")
