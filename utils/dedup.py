# utils/dedup.py
def deduplicate_rows(rows, key_fields=None):
    """
    Removes duplicate rows based on a tuple of key fields.
    If key_fields is None, dedupes on the full row.
    """
    seen = set()
    deduped = []

    for row in rows:
        try:
            key = tuple(row[k] for k in key_fields) if key_fields else tuple(sorted(row.items()))
            if key not in seen:
                seen.add(key)
                deduped.append(row)
        except KeyError:
            continue

    return deduped