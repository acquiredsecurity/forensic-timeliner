timeline_rows = []

def sanitize_field(value):
    if value is None:
        return ""
    value = str(value)

    if value.lower() == "nan":
            return ""

    return value.replace("\r", " ").replace("\n", " ").strip()

def sanitize_row(row: dict) -> dict:
    return {k: sanitize_field(v) for k, v in row.items()}

def add_rows(rows):
    """Add parsed and sanitized rows to the global timeline."""
    if rows:
        sanitized = [sanitize_row(row) for row in rows]
        timeline_rows.extend(sanitized)

def get_all_rows():
    """Retrieve all collected timeline rows."""
    return timeline_rows