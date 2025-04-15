import sys
from datetime import datetime

def parse_iso_datetime(value: str) -> datetime:
    try:
        if "T" in value:
            return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
        return datetime.strptime(value, "%Y-%m-%d")
    except ValueError:
        raise ValueError(f"Invalid date format: {value}")


def parse_arguments():
    args = {
        "BaseDir": "C:\\triage",
        "EZDirectory": None,
        "ChainsawDirectory": None,
        "HayabusaDirectory": None,
        "NirsoftDirectory": None,
        "AxiomDirectory": None,
        "OutputFile": None,
        "ExportFormat": "csv",
        "SkipEventLogs": False,
        "ProcessAxiom": False,
        "ProcessChainsaw": False,
        "ProcessEZ": False,
        "ProcessHayabusa": False,
        "ProcessNirsoft": False,
        "MFTExtensionFilter": [".identifier", ".exe", ".ps1", ".zip", ".rar", ".7z"],
        "MFTPathFilter": ["Users", "tmp"],
        "BatchSize": 10000,
        "StartDate": None,
        "EndDate": None,
        "Deduplicate": False,
        "Interactive": False,
        "Preview": False,
        "ALL": False,
        "Help": False
    }

    # Normalize for case-insensitive matching
    args_keys_lower = {k.lower(): k for k in args}

    aliases = {
        "-i": "Interactive",
        "--i": "Interactive",
        "-h": "Help",
        "--h": "Help",
        "--help": "Help",
        "--Help": "Help",
        "-H": "Help",
        "-a": "ALL",
        "--a": "ALL",
        "-d": "Deduplicate",
        "--d": "Deduplicate",
        "--p": "Preview",
        "--preview": "Preview"

    }

    # Parse short aliases
    for flag, dest in aliases.items():
        if flag in sys.argv:
            args[dest] = True

    # Parse full flags like --StartDate 2025-04-01
    for i, arg in enumerate(sys.argv):
        if arg.startswith("--"):
            key = arg[2:]
            if key in args:
                if isinstance(args[key], bool):
                    args[key] = True
                else:
                    if i + 1 < len(sys.argv):
                        val = sys.argv[i + 1]
                        if key in ["MFTExtensionFilter", "MFTPathFilter"]:
                            args[key] = val.split(",")
                        elif key == "BatchSize":
                            args[key] = int(val)
                        elif key in ["StartDate", "EndDate"]:
                            args[key] = parse_iso_datetime(val)
                        else:
                            args[key] = val

    return args

