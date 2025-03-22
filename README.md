# Forensic Timeliner

Forensic Timeliner is a PowerShell-based tool that automates the process of aggregating and formatting forensic artifacts from [Chainsaw](https://github.com/WithSecureLabs/chainsaw) and KAPE / EZTools into a structured **MINI** **Master Timeline** in Excel. This is obviously not comprehensive but a great way to take some high value artifacts and get a real quick snapshot using powershell!

## Field Mappings by Artifact Module

📊 Field Mappings by Artifact Module
<details> <summary><strong>account_tampering</strong> 🔵</summary>
Field	Description
TimeCreated	Timestamp of the event
EventID	Windows Event ID
TargetUserName	Account being targeted
CallerUserName	Account making the change
Computer	Hostname
SourceFile	Source CSV file
</details> <details> <summary><strong>antivirus</strong> 🟢</summary>
Field	Description
TimeCreated	Detection time
Threat Name	Detected malware/heuristic
Action	Action taken (quarantine, etc.)
Computer	Hostname
SourceFile	Source CSV file
</details> <details> <summary><strong>indicator_removal</strong> 🔴</summary>
Field	Description
TimeCreated	When the deletion occurred
Target	File, log, or reg key removed
User	Who performed the action
Computer	Hostname
SourceFile	Source CSV file
</details> <details> <summary><strong>lateral_movement</strong> 🟠</summary>
Field	Description
TimeCreated	Time of movement
Source IP	Attacker's machine
Target IP	Remote system
Computer	Hostname
SourceFile	Source CSV file
</details> <details> <summary><strong>login_attacks</strong> 🟡</summary>
Field	Description
TimeCreated	Time of attempt
EventID	Logon success/failure ID
TargetUserName	Account name
IP Address	Remote source
Computer	Hostname
</details> <details> <summary><strong>MFT - FileNameCreated0x30</strong> 🟣</summary>
Field	Description
RecordNumber	MFT record number
FilePath	Full file path
Timestamp	File creation date
Size	File size
SourceFile	Source MFT CSV
</details> <details> <summary><strong>microsoft_rds_events_-_user_profile_disk</strong> 🟦</summary>
Field	Description
EventID	Related RDS Event ID
User	Affected user
UPD Path	Disk mount path
Computer	Hostname
</details> <details> <summary><strong>powershell_script / engine_state</strong> 🟤</summary>
Field	Description
TimeCreated	Execution time
ScriptBlockText	Raw PS script contents
EngineState	PowerShell engine state
User	Who ran the script
Computer	Hostname
</details> <details> <summary><strong>rdp_events</strong> 🟢</summary>
Field	Description
TimeCreated	RDP connection time
User	Remote user account
Source IP	Originating IP address
EventID	RDP session event
</details> <details> <summary><strong>service_installation</strong> 🟦</summary>
Field	Description
TimeCreated	When service was added
ServiceName	Name of the installed service
Path	Binary or script path
User	Account that installed it
</details> <details> <summary><strong>sigma</strong> 💜</summary>
Field	Description
TimeCreated	Detection time
RuleName	Sigma rule name
RuleID	Sigma rule ID (if included)
DetectionName	MITRE Technique or tactic
</details> <details> <summary><strong>Web History</strong> 🔵</summary>
Field	Description
VisitTime	Timestamp of page visit
URL	Visited URL
Title	Page title
Browser	Browser used (Chrome, etc.)
User	Profile owner
</details> <details> <summary><strong>File Deletion / Registry Update / Shellbags</strong> 🟥🟩🟧</summary>
Field	Description
TimeCreated	Timestamp of change
FilePath/KeyPath	Affected file or registry key
User	User performing action
SourceFile	CSV source file
</details> <details> <summary><strong>Program Execution - Amcache / LNK Files</strong> 🟨</summary>
Field	Description
Timestamp	Execution or link opened
Program	Binary path or name
User	Associated user
SourceFile	CSV source file
</details> <details> <summary><strong>MFT - Created / mft (General)</strong> 🔷</summary>
Field	Description
FilePath	Created file or folder path
Timestamp	When file was created
Extension	File extension
User	User (if known)
</details> <details> <summary><strong>Event Logs</strong> ⚫</summary>
Field	Description
TimeCreated	Log timestamp
EventID	Windows Event ID
Channel	Event log source
Computer	Hostname
PayloadData	Extracted data field
SourceFile	CSV log file
</details>


This tool is designed for forensic analysts who need to quickly timeline and triage using output from Chainsaw mianly focused on event logs, MFT, RDP events, sigma rule and other forensic artifacts efficiently.

### Special Thanks
Incoming

---
sample commandline:
.\forensic_timeliner.ps1 -CsvDirectory "C:\chainsaw" -OutputFile "C:\chainsaw\Master_Timeline.xlsx"

-CsvDirectory  - the path to your kape and chainsaw output
-OutputFile - the path to save your timeline to

## Features
- Automatically combines all **Chainsaw CSV outputs** and into a single **Excel timeline**.
- **Normalizes timestamps** into a readable format (MM/DD/YYYY HH:MM:SS).
- Assigns an **artifact name** to each row for easy identification.
- Supports **color-coding** for different artifacts (see `color_macro.vbs` for details).
- Preserves **important metadata** like event IDs, source addresses, user information, and service details.
- Sorts the final timeline by **Date/Time**.

---


## Requirements
### Windows:
1. **PowerShell** (Version 5.1 or later)
2. **ImportExcel PowerShell Module** (for Excel support)
   ```powershell
   Install-Module ImportExcel -Force -Scope CurrentUser
3. Chainsaw (https://github.com/WithSecureLabs/chainsaw)
Optional:
Excel Macro for Color Coding:
The file color_macro.vbs can be used to apply color coding to each row based on the artifact type.

Color Coding (Excel)
The following artifact types are color-coded for better visibility: use the macro in this repo to apply the color coding schema. Macro only runs in excel in Windows machines!


