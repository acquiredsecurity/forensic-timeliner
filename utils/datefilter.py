# utils/datefilter.py
from datetime import datetime

def parse_datetime_string(value: str) -> datetime:
    # Try multiple formats in case DateTime field varies
    for fmt in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    raise ValueError(f"Unrecognized datetime format: {value}")

def filter_rows_by_date(rows, start_date, end_date, date_field="DateTime"):
    filtered = []
    for row in rows:
        try:
            row_date = parse_datetime_string(row[date_field])
            if start_date <= row_date <= end_date:
                filtered.append(row)
        except Exception:
            continue
    return filtered