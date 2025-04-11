import os
from datetime import datetime

def run_interactive_config():
    config = {}

    print("\n===== Forensic Timeliner Interactive Configuration =====")

    # Output format
    fmt = input("Select output format (csv, json, xlsx) [csv]: ").strip().lower()
    config["ExportFormat"] = fmt if fmt in ["csv", "json", "xlsx"] else "csv"

    # Base directory
    base_dir = input("Enter base directory for triage data [C:\\triage]: ").strip()
    config["BaseDir"] = base_dir if base_dir else "C:\\triage"

    # EZ Tools toggle
    proc_ez = input("Include KAPE/EZ Tools output? (y/n) [n]: ").strip().lower()
    config["ProcessEZ"] = proc_ez == "y"

    if config["ProcessEZ"]:
        ez_dir = input("  Path to EZ Tools/KAPE directory [{}\\kape]: ".format(config["BaseDir"])).strip()
        config["EZDirectory"] = ez_dir if ez_dir else os.path.join(config["BaseDir"], "kape")

        # Subdirs
        print("\n  Configure subdirectories (press Enter for default values):")
        config["ProgramExecSubDir"] = input("    Program Execution [ProgramExecution]: ") or "ProgramExecution"
        config["FileSystemSubDir"] = input("    File System [FileSystem]: ") or "FileSystem"
        config["EventLogsSubDir"] = input("    Event Logs [EventLogs]: ") or "EventLogs"
        config["FileFolderSubDir"] = input("    File/Folder Access [FileFolderAccess]: ") or "FileFolderAccess"
        config["FileDeletionSubDir"] = input("    File Deletion [FileDeletion]: ") or "FileDeletion"
        config["RegistrySubDir"] = input("    Registry [Registry]: ") or "Registry"

        # MFT extension filter
        ext_filter = input("  MFT Extension Filter (.exe,.pdf,...) [.exe,.ps1,.zip]: ")
        config["MFTExtensionFilter"] = [e.strip() for e in ext_filter.split(",") if e.strip()] if ext_filter else [".exe", ".ps1", ".zip"]

        # MFT path filter
        path_filter = input("  MFT Path Filter (Users,tmp,...) [Users,tmp]: ")
        config["MFTPathFilter"] = [p.strip() for p in path_filter.split(",") if p.strip()] if path_filter else ["Users", "tmp"]

        # Skip Event Logs
        skip_evt = input("  Skip EZ Event Logs? (y/n) [n]: ").strip().lower()
        config["SkipEventLogs"] = skip_evt == "y"

    # Output location
    default_output = os.path.join(config["BaseDir"], "timeline", f"Forensic_Timeliner.{config['ExportFormat']}")
    output = input(f"Where to save the output? [{default_output}]: ").strip()
    config["OutputFile"] = output if output else default_output

    # Batch size
    batch_input = input("Batch size for large files [10000]: ")
    config["BatchSize"] = int(batch_input) if batch_input.isdigit() else 10000

    # Deduplication
    dedup = input("Enable deduplication of timeline entries? (y/n) [n]: ").strip().lower()
    config["Deduplicate"] = dedup == "y"

    # Date filtering
    if input("Apply date range filter? (y/n) [n]: ").strip().lower() == "y":
        start = input("  Start date (YYYY-MM-DD) [none]: ").strip()
        end = input("  End date (YYYY-MM-DD) [none]: ").strip()
        config["StartDate"] = start if start else None
        config["EndDate"] = end if end else None

    print("\n[+] Interactive configuration complete. Running timeline build...\n")
    return config
