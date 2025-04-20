
<div align="center">
<img src="https://github.com/user-attachments/assets/258920b6-aa55-400a-b699-3d507d6ede21" alt="ft_logo2" width="300"/>
</div>


> A high-speed forensic timeline tool for DFIR Invetigators to quickly combine CSV files from leading Windows triage tool output into a mini timeline. Allows investigators to combine outputs from multiple forensic tools into a single timeline. Adds custom logic and filtering to allow investigators to get to important data quickly.  Supported tools include (EZ Tools/Kape, Axiom, Hayabusa, Chainsaw, Nirsoft), CSV output ready for Timeline Explorer, Excel, etc..
---

## Table of Contents

- [Main Features](#main-features)
- [Quick Start](#quick-start)
- [Downloads](#downloads)
- [Running Forensic Timeliner](#running-forensic-timeliner)
- [Command Line Arguments](#command-line-arguments)
- [Custom Config](#custom-config)
- [Timeline Output](#timeline-output-field-structure)
- [Auto File Discovery](#auto-file-discovery)
- [Artifact and Output Support Table](#artifact-and-output-support-table)
- [License](#license)

---

## Main Features

-Combine csv output from
  - EZ Tools / Kape
  - Axiom
  - Chainsaw
  - Hayabusa
  - Nirsoft
  - output data into a unified timeline

- Automatic CSV discovery from triage directories
  -   simply provide the base directory of where the triage output lives and the tool will attempt to discover

- Timeline enrichment with regex-based data extraction

- RFC-4180-compliant export for compatibility with tools like Timeline Explorer

- Date filtering and deduplication controls

- Interactive Setup and Discovery Preview
  - By default if you run with --i or --Interactive --Preview runs by default. Preview helps Identify if you csv files are being doscovered in your output directory.   

---

## Quick Start

TL;DR!
Get some Kape/EZ Forensic Output

Download the exe and run: 

```powershell, cmd
forensic-timeliner.exe --Interactive

```powershell, cmd
forensic-timeliner.exe --BaseDir C:\triage\hostname --ALL --OutputFile C:\timeline.csv
```

- Use default naming for your csv files and make sure they are inside the base directory you set. There is a fallback to auto discover csv files based on file headers.
- file naming
  - Ez Tools / Kape - default
  - Axiom - default
  - Chainsaw - default
  -  Hayabusa -  "filename_patterns" \["hayabusa", "haya"],
  -  Nirsoft Web History - "filename_patterns": \["nirsoft", "history", "browsing", "web", "browse"],     
  

---


## Downloads


---

## Running Forensic Timeliner

To run as an EXE use --i for interactive menu walkthrough, the ALL flag or a specific tool flag. 

```powershell, cmd
forensic-timeliner.exe  --BaseDir C:\triage\host --ALL --OutputFile C:\timeline.csv
```

```run python in powershel or bash
python timeliner.py --BaseDir C:\triage --ProcessEZ --OutputFile C:\timeline.csv
```

You may also use interactive menu:

```powershell or bash
python timeliner.py --Interactive
```

---

## Command Line Arguments

```python
--BaseDir                # Base path to triage folder
--EZDirectory            # Optional override for EZ Tools output path
--ChainsawDirectory      # Optional override for Chainsaw path
--HayabusaDirectory      # Optional override for Hayabusa path
--AxiomDirectory         # Optional override for Axiom path
--NirsoftDirectory       # Optional override for Nirsoft path
--OutputFile             # Output timeline CSV path
--ProcessEZ              # Parse EZ Tools artifacts
--ProcessChainsaw        # Parse Chainsaw Sigma outputs
--ProcessHayabusa        # Parse Hayabusa logs
--ProcessAxiom           # Parse Axiom CSVs
--ProcessNirsoft         # Parse Nirsoft Web History
--MFTExtensionFilter     # Default: ['.identifier','.exe','.ps1','.zip','.rar','.7z']
--MFTPathFilter          # Default: ['Users']
--BatchSize              # Chunk size for large files (default: 10000)
--StartDate              # ISO format start filter (e.g., 2025-04-01)
--EndDate                # ISO format end filter
--Deduplicate            # Remove duplicate rows (post-export)
--ALL                    # Process all modules
--NoBanner               # Skip banner display
--Preview                # Show discovery preview only
--ConfigExport           # Dump default artifact config to file
--LoadConfigOverride     # Load custom artifact config JSON
--Help / -h              # Show help
--Interactive / -i       # Launch GUI command-line builder
```

---


## Timeline Output Field Structure

- All output is exported as RFC-4180-compliant CSV
- Each timeline includes the follwoing fields:
  - \[
        "DateTime", "TimestampInfo", "ArtifactName", "Tool", "Description",
        "DataDetails", "DataPath", "FileExtension", "EventId",
        "User", "Computer", "FileSize", "IPAddress",
        "SourceAddress", "DestinationAddress", "SHA1", "Count", "EvidencePath"
    ]
- Sorting is done automatically by DateTime
- Event Log Processing and Filtering
  -  EZ Tools and Axiom Event Logs are filtered based on custom logic, so the entire output is not added to the timeline. This isn't adjustable. (Open to input) You should be running chainsaw or hayabusa as well to fill in the gaps. There's a lot of custom Regex matching for Axiom event log output as Magnet doesn't provide Channel by default so mapping is done by provider and the Channel name is regex'd from the source field
  
    {
    "Application": \[1000, 1001],
    "Microsoft-Windows-PowerShell/Operational": \[4100, 4103, 4104],
    "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational": \[72, 98, 104, 131, 140],
    "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational": \[21, 22],
    "Microsoft-Windows-TaskScheduler/Operational": \[106, 140, 141, 129, 200, 201],
    "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational": \[261, 1149],
    "Microsoft-Windows-WinRM/Operational": \[169],
    "Security": \[1102, 4624, 4625, 4648, 4698, 4702, 4720, 4722, 4723, 4724, 4725, 4726, 4732, 4756],
    "SentinelOne/Operational": \[1, 31, 55, 57, 67, 68, 77, 81, 93, 97, 100, 101, 104, 110],
    "System": \[7045],
}

- MFT Processing and Filtering
  - MFT filtering is done automatically. Only created time stamps are provided using Created0x10" The follwing filters are passed by default to look for these extensions in the users folder. 
  - DEFAULT_EXTENSIONS = \[".identifier", ".exe", ".ps1", ".zip", ".rar", ".7z"]
  - DEFAULT_PATHS = \["Users"]
  - You can add additional extensions and paths to search using the foll the filters
    --MFTExtensionFilter   --MFTPathFilter          
  

---

## Auto File Discovery

In order for files to be discovered by default and added to your timeline you need to follow the file naming conventions below. When you provide a $BaseDir Forensic Timeliner will attempt to locate CSV files based on the following file names which should match the default export names from Axiom and EZ Tools/Kape. You can export the default config file with the command flag --ConfigExport and you can load a custom config using --LoadConfigOverride but the files must reside inside the --BaseDir you set.

example config structure
 "Chainsaw_Persistence": {
        "filename_patterns": ["persistence.csv"],
        "foldername_patterns": \["chainsaw"],
        "required_headers": \[ "timestamp", "detections", "path", "Event ID", "Computer", 
        "User Name", "Scheduled Task Name"
        ],
        "strict_filename_match": True,
        "strict_folder_match": False
    },

---

## Artifact and Output Support Table

| Artifact                   | Supported Tool(s)       | Example Filename(s)                                                |
|---------------------------|--------------------------|----------------------------------------------------------------------|
| Amcache                   | EZ Tools, Axiom          | AssociatedFileEntries.csv, AmCache File Entries.csv                 |
| AppCompatCache            | EZ Tools, Axiom          | AppCompatCache.csv, Shim Cache.csv                                  |
| AutoRuns                 | Axiom                    | Autorun Items.csv                                                   |
| Chrome History            | Axiom                    | Chrome Web History.csv                                              |
| Deleted Files             | EZ Tools                 | RBCmd_Output.csv                                                    |
| Edge History              | Axiom                    | Edge Web Visits.csv, Edge Web History.csv                           |
| Event Logs                | EZ Tools, Axiom          | _EvtxECmd_Output.csv, Windows Event Logs.csv                        |
| Firefox History           | Axiom                    | Firefox Web Visits.csv                                              |
| IE History                | Axiom                    | Edge-Internet Explorer 10-11 Main History.csv                       |
| JumpLists                 | EZ Tools, Axiom          | AutomaticDestinations.csv, Jump Lists.csv                           |
| LNK Files                 | EZ Tools, Axiom          | _LECmd_Output.csv, LNK Files.csv                                    |
| MFT                       | EZ Tools, Chainsaw       | _MFTECmd_$MFT_Output.csv, mft.csv                                   |
| MRU Folder Access         | Axiom                    | MRU Folder Access.csv                                               |
| MRU Opened/Saved Files    | Axiom                    | MRU Opened-Saved Files.csv                                          |
| MRU Recent Files & Folders| Axiom                    | MRU Recent Files & Folders.csv                                      |
| Opera History             | Axiom                    | Opera Web Visits.csv                                                |
| Persistence               | Chainsaw                 | persistence.csv                                                     |
| Prefetch                  | EZ Tools, Axiom          | _PECmd_Output.csv, Prefetch Files - Windows 8-10-11.csv             |
| PowerShell Execution      | Chainsaw                 | powershell.csv, powershell_script.csv                               |
| RDP Events                | Chainsaw                 | rdp_events.csv                                                      |
| Recycle Bin               | Axiom                    | Recycle Bin.csv                                                     |
| Registry                  | EZ Tools                 | _RECmd_Batch_Kroll_Batch_Output.csv                                 |
| Service Installation      | Chainsaw                 | service_installation.csv                                            |
| Service Tampering         | Chainsaw                 | service_tampering.csv                                               |
| Shellbags                 | EZ Tools, Axiom          | _UsrClass.csv, Shellbags.csv                                        |
| Sigma Rule Matches        | Chainsaw                 | sigma.csv                                                           |
| UserAssist                | Axiom                    | UserAssist.csv                                                      |
| Threat Events (Chainsaw)  | Chainsaw                 | account_tampering.csv, defense_evasion.csv, credential_access.csv   |
| Web Browsing History      | Nirsoft, Axiom           | WebResults.csv, Chrome/Firefox/Edge History.csv                     |
| VPN / RAS Logs            | Chainsaw                 | microsoft_rasvpn_events.csv, microsoft_rds_events.csv               |
| Login Attacks             | Chainsaw                 | login_attacks.csv                                                   |
| Log Tampering             | Chainsaw                 | log_tampering.csv                                                   |
| Antivirus Detections      | Chainsaw                 | antivirus.csv                                                       |
| Applocker Events          | Chainsaw                 | applocker.csv                                                       |
| Indicator Removal         | Chainsaw                 | indicator_removal.csv                                               |
| Lateral Movement          | Chainsaw                 | lateral_movement.csv                                                |



---

## License

MIT License

---

