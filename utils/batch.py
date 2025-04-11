import csv

def should_use_batch(file_path, threshold=10000):
    """
    Quickly checks if the file has more lines than the threshold.
    Returns True if batch processing should be used.
    """
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        for i, _ in enumerate(f):
            if i > threshold:
                return True
    return False
