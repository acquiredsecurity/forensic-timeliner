# utils/config_override.py

import json
import os
from utils.discovery import ARTIFACT_SIGNATURES

def load_config_override(override_path):
    if not os.path.exists(override_path):
        print(f"[!] Config override path not found: {override_path}")
        return

    try:
        with open(override_path, "r", encoding="utf-8") as f:
            user_config = json.load(f)

        updated = 0
        for artifact, values in user_config.items():
            if not isinstance(values, dict):
                print(f"[!] Skipping malformed entry for {artifact}")
                continue

            # Apply override (create if missing, update if exists)
            if artifact not in ARTIFACT_SIGNATURES:
                print(f"[+] Adding new artifact signature: {artifact}")
                ARTIFACT_SIGNATURES[artifact] = {}

            for key in ["filename_patterns", "foldername_patterns", "required_headers"]:
                if key in values:
                    ARTIFACT_SIGNATURES[artifact][key] = values[key]

            updated += 1

        print(f"[✓] Loaded and applied overrides for {updated} artifacts from: {override_path}")

    except Exception as e:
        print(f"[!] Failed to load config override from {override_path}: {e}")
