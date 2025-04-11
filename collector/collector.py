timeline_rows = []

def add_rows(rows):
    """Add parsed rows from a module to the global timeline."""
    if rows:
        timeline_rows.extend(rows)

def get_all_rows():
    """Retrieve all collected timeline rows."""
    return timeline_rows