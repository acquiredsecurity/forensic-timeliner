
<div align="center">

<img src="https://github.com/user-attachments/assets/9505c070-c5b3-4b19-bc4f-ebeb0c28cad1" width="600">
</div>


> A high-speed forensic processing engine built for DFIR investigators. Quickly consolidate CSV output from top-tier triage tools into a unified mini timeline with built-in filtering, artifact detection, date filtering, keyword tagging, and deduplication.

![Version](https://img.shields.io/badge/version-v2.2-blue?style=for-the-badge)
![Downloads](https://img.shields.io/github/downloads/acquiredsecurity/forensic-timeliner/total?style=for-the-badge)
![Stars](https://img.shields.io/github/stars/acquiredsecurity/forensic-timeliner?style=for-the-badge)
![Contributors](https://img.shields.io/github/contributors/acquiredsecurity/forensic-timeliner?style=for-the-badge)
![Maintained](https://img.shields.io/badge/Maintenance-Actively--Developed-brightgreen?style=for-the-badge)
[![CodeFactor](https://img.shields.io/codefactor/grade/github/acquiredsecurity/forensic-timeliner?style=for-the-badge&label=CodeFactor)](https://www.codefactor.io/repository/github/acquiredsecurity/forensic-timeliner)
![C#](https://img.shields.io/badge/C%23-239120.svg?style=for-the-badge&logo=c-sharp&logoColor=white)
![.NET 9](https://img.shields.io/badge/.NET_9-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)

---

## Release
## Forensic Timeliner v2.2 – Release Notes

### ✨ New Features

- **Interactive Menu Enhancements**
  - Added prompts to **display filter configuration** for:
    - **MFT** (timestamp, path, and extension filters)
    - **Event Logs** (channel and provider filters)
    - **Keyword tagging rules** from `keywords.yaml`
  - Prompts now appear automatically if EZ Tools is selected and config files are present.
  - Filter previews are displayed as rich tables using `Spectre.Console`.

- **Keyword Tagging Support for TLE**
  - New interactive option to enable the **Timeline Explorer keyword tagger**.
  - Generates a `.tle_sess` file with tagged rows based on user-defined keyword groups.
  - Interactive preview of keyword groups before enabling.

---

---

**Table of Contents**
* [Main Features](#main-features)
* [Quick Start](#quick-start)
* [Downloads](#downloads)
* [Screenshots](#screenshots)
* [Command Line Arguments](#command-line-arguments)
* [Timeline Output](#timeline-output-field-structure)
* [Yaml Config](#yaml-config)
* [Tool Documentation](#-tool-documentation)
* [Artifact and Output Support Table](#artifact-and-output-support-table)
* [License](#license)

---

## Main Features

-Combine csv output from
  - EZ Tools / Kape
  - Axiom
  - Chainsaw
  - Hayabusa
  - Nirsoft
  - output data into a unified timeline

- Automatic CSV discovery from triage directories (all configurable) with YAML
    - Yaml files already use default namings for tools with default output
    - For tools like Hayabusa where you can set the file output name you should name the file some variaition of Hayabusa.csv and put it in a folder named Hayabusa   
    - Simply provide the base directory of where the triage output lives and the tool will attempt to discover the csv files based on
    - File Name
    - Folder Name
    - File Headers
    - For Event Logs Channel\Provider Filters
    - For MFT File Extension and Path Filters



- Timeline enrichment with with keyword tagging for use with Timeline Explorer. Automatically create a TLE session file based on keyword searching for CSV output.

- RFC-4180-compliant export for compatibility with tools like Timeline Explorer

- Date filtering and deduplication controls

- Interactive Setup and Yaml Discovery Preview

---

## Quick Start

TL;DR!
Get some Kape/EZ Forensic Output

Download the exe and run: 

```powershell, cmd
ForensicTimeliner.exe --Interactive
```

```powershell, cmd
ForensicTimeliner.exe --BaseDir C:\triage\hostname --ALL --OutputFile C:\timeline.csv
```

```
.\ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\Users\admin0x\Desktop\sample_data\host_t800" --OutputFile "C:\Users\admin0x\Desktop\test" --ExportFormat csv --EnableTagger
```
- Open TLE Session file from your output directory. If you move the file you need to updste the session file path.

- Use default naming for your csv files and make sure they are inside the base directory you set. There is a fallback to auto discover csv files based on file headers, or adjust the filename in the YAML settings.

- Use the --EnableTagger feature view command line to build a Timeline Explorer session file based on keyword tagging. Adjust keywords in config\keywords\keywords.yaml
  

---
## Downloads

Latest Release: [ v2.2](https://github.com/acquiredsecurity/forensic-timeliner/releases/tag/v2.2)

Download sample data for testing purposes here.

[Sample Data](https://drive.google.com/file/d/1dplyT1Rf1gIYkItAeKlbWKAKgR91uFK-/view?usp=sharing)


---

## Screenshots

Interactive Menu

<img width="472" alt="image" src="https://github.com/user-attachments/assets/5548a452-4d07-4325-ac1f-03155a0f5714" />

Timeline Explorer Support
<img width="1434" alt="image" src="https://github.com/user-attachments/assets/5ccc7b6d-9eb4-4a66-9ced-66efb483c06d" />

- Auto coloring applied in TLE with latest plugin files
- Automatically Build a TLE Session File with tagged rows based on keywords
  - Edit the Keywords config file and add your keywords
  - Run ForensicTimeliner.exe from the command line using the --EnableTagger flag
---



## Command Line Arguments

| Argument                | Type         | Default           | Description                                                                |
|------------------------|--------------|-------------------|-----------------------------------------------------------------------------|
| `--BaseDir`            | `string`     | `C:\triage`       | Root directory to recursively search for supported artifact CSVs            |
| `--OutputFile`         | `string`     | `"timeline.csv"`  | Output file or folder for exported timeline                                 |
| `--ExportFormat`       | `string`     | `csv`             | Export format: `csv`, `json`, or `jsonl`                                    |
| `--StartDate`          | `datetime`   | `null`            | Filter: only include rows after this date                                   |
| `--EndDate`            | `datetime`   | `null`            | Filter: only include rows before this date                                  |
| `--Deduplicate` / `-d` | `bool`       | `false`           | Remove duplicate timeline rows after export                                 |
| `--EnableTagger`       | `bool`       | `false`           | Enables keyword-based tagging via `config/keywords/keywords.yaml`           |
| `--IncludeRawData`     | `bool`       | `false`           | Adds a `RawData` column for unmodified source row contents (if available) experimental |
| `--NoBanner`           | `bool`       | `false`           | Skip printing the banner/logo at start                                      |
| `--Help` / `-h`        | `bool`       | `false`           | Show help and usage information                                             |
| `--ALL` / `-a`         | `bool`       | `false`           | Process all tools listed below (based on discovery)                         |
| `--Interactive` / `-i` | `bool`       | `false`           | Launch an interactive CLI to build a custom command                         |
| `--ProcessEZ`          | `bool`       | `false`           | Enable EZ Tools artifact parsing                                            |
| `--ProcessAxiom`       | `bool`       | `false`           | Enable Axiom artifact parsing                                               |
| `--ProcessChainsaw`    | `bool`       | `false`           | Enable Chainsaw artifact parsing                                            |
| `--ProcessHayabusa`    | `bool`       | `false`           | Enable Hayabusa artifact parsing                                            |
| `--ProcessNirsoft`     | `bool`       | `false`           | Enable Nirsoft artifact parsing                                             |

---

## Timeline Output Field Structure

🧾 Timeline Output Field Structure
All output is exported as RFC-4180-compliant CSV and ready for review in Timeline Explorer, Excel, or other forensic tools.

Each timeline entry includes the following fields:
```
DateTime,TimestampInfo,ArtifactName,Tool,Description,DataDetails,DataPath,FileExtension,EventId,User,Computer,FileSize,IPAddress,SourceAddress,DestinationAddress,SHA1,Count,EvidencePath
```

## YAML Config

Timeline parsers can be customized using per-artifact YAML definitions. These control:

- Artifact discovery (`filename_patterns`, `foldername_patterns`, etc.)
- Filtering (`event_channel_filters`, `provider_filters`, `paths`, `extensions`)
- Timestamp mapping (`timestamp_fields`) ** MFT Only
- Optional overrides (`ignore_filters`) ** MFT & Event Logs
  - Set ignore_filters: true to skip all filters for MFT and Event Logs. 

---

## 📚 Tool Documentation

Detailed documentation for each supported tool showing how artifacts are parsed and mapped to the unified timeline format:

### Supported Tools
* **[EZ Tools](Docs/EZTools.md)** - Comprehensive Windows artifact analysis (Activity Timeline, Amcache, AppCompatCache, Event Logs, JumpLists, LNK Files, MFT, Prefetch, Registry, Shellbags, UserAssist, and more)
* **[Hayabusa](Docs/Hayabusa.md)** - Sigma-based Windows event log analysis and threat hunting
* **[Chainsaw](Docs/Chainsaw.md)** - MITRE ATT&CK focused event log analysis (Account Tampering, Credential Access, Lateral Movement, Persistence, PowerShell, and more)
* **[Axiom](Docs/Axiom.md)** - Magnet Forensics comprehensive artifact extraction (Web History, Prefetch, Registry, File System, and more)
* **[Nirsoft](Docs/Nirsoft.md)** - Cross-browser history analysis and Windows utility artifacts

Each documentation page includes:
- **Field Mapping Tables** - How source CSV fields map to timeline format
- **Special Behaviors** - Unique processing logic and features
- **Expected CSV Format** - Required input format and structure
- **Integration Notes** - Tips for optimal usage and file organization

---

## Event Log Filters

Define EventChannelFilters per channel in your YAML configuration as seen below. Spport for [] to include an entire event log as needed.

```
event_channel_filters:
  Application: []
  Microsoft-Windows-PowerShell/Operational: [4100, 4103, 4104]
  Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational: [72, 98, 104, 131, 140]
  Microsoft-Windows-TerminalServices-LocalSessionManager/Operational: [21, 22]
  Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational: [261, 1149]
  Microsoft-Windows-TaskScheduler/Operational: [106, 140, 141, 129, 200, 201]
  Microsoft-Windows-WinRM/Operational: [169]
  SentinelOne/Operational: [1, 31, 55, 57, 67, 68, 77, 81, 93, 97, 100, 101, 104, 110]
  Security: [1102, 4624, 4625, 4648, 4698, 4702, 4720, 4722, 4723, 4724, 4725, 4726, 4732, 4756]
  System: [7045]

provider_filters:
    edgeupdate: [0]
    SentinelHelperService: [0]
    brave: [0]
    Edge: [256]
    SentinelOne: [1, 31, 55, 57, 67, 68, 77, 81] 
```

MFT Processing and Filtering
MFT parsing includes automatic timestamp normalization and extension/path filtering.

By default, only Created0x10 timestamps are included to focus on file creation events and limit the overall timeline size

Default filters:
```
DEFAULT_EXTENSIONS = [".identifier", ".exe", ".ps1", ".zip", ".rar", ".7z"]
DEFAULT_PATHS = ["Users"]
```     
  

---


## Artifact and Output Support Table

| Artifact                   | Supported Tool(s)       | Example Filename(s)                                                |
|---------------------------|--------------------------|----------------------------------------------------------------------|
| Amcache                   | EZ Tools, Axiom          | UnAssociatedFileEntries.csv, AssociatedFileEntries.csv, AmCache File Entries.csv                 |
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
| UserAssist                | EZ Tools, Axiom          | UserAssist.csv                                                      |
| TypedUrls                 | EZ Tools                 | *__TypedURLS__NTUSER.CSV                                            |
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

