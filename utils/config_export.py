# utils/config_export.py
import os
import json
from utils.discovery import ARTIFACT_SIGNATURES

def export_default_config(path="artifact_config.json"):
    path = os.path.abspath(path)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(ARTIFACT_SIGNATURES, f, indent=4)
    print(f"[✓] Artifact signature config exported to:\n  {path}")
