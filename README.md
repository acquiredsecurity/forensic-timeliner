# 🧭 Forensic Timeliner 

This tool consolidates and normalizes digital forensic artifact data  
from multiple tools (**EZ Tools**, **Nirsoft**, **Hayabusa**, **Axiom**, **Chainsaw**)  
into a single unified forensic timeline.

https://youtu.be/8fwJ_3Sks0E?feature=shared

## Example Usage

```powershell
.\forensic_timeliner.ps1 -Interactive
.\forensic_timeliner.ps1 -i
.\forensic_timeliner.ps1 -help
.\forensic_timeliner.ps1 -ProcessKape -ProcessAxiom -ExportFormat json

 

Use the VB macro to color code the artifacts in excel. 
This tool is designed to quickly timeline and triage using output 
from Axiom, EZ parsers / Kape, Chainsaw and Hayabusa. Correlate 
tool output across different tools!

## Quick Start

1. Download [Sample Data](https://drive.google.com/file/d/15ofv0xNYFCfwEYvmIZgMnJalwbHowAyw/view?usp=sharing) and unzip to the root of C:

2. Run the script with interactive mode:
```powershell
.\forensic_timeliner.ps1 -Interactive
```

---
![image](https://github.com/user-attachments/assets/ddc7a7d7-a67b-45e5-bb06-983d37529fbc)

Forensic Timeliner is a PowerShell-based tool that automates the process of combining csv output from forensic tools into a single timeline that is easy and quick to review! Quickly parse through CSV data output from KAPE / [EZTools](https://github.com/EricZimmerman) / [Chainsaw](https://github.com/WithSecureLabs/chainsaw) / [Hayabusa](https://github.com/Yamato-Security/hayabusa) and [Axiom](https://www.magnetforensics.com/products/magnet-axiom/) into a structured **MINI Timeline**. Export data to CSV, JSON and XLSX. 

Output suported:
- Axiom
- Kape/EZ Tools
- Chainsaw + Rules + Sigma
- Hayabusa + Rules + Sigma
- Nirsoft Web History View

(More Artifact Support Coming, let me know what tools you want supported!)

## 📌 Parameters

| Parameter                     | Description                                                                 |
|------------------------------|-----------------------------------------------------------------------------|
| `-BaseDir <path>`            | Base output path *(Default: `C:\triage`)*                                   |
| `-OutputFile <path>`         | Timeline output file *(Default: `$BaseDir\timeline\Forensic_Timeliner.csv`)* |
| `-ExportFormat <csv|json|xlsx>` | Export format *(Default: `csv`)*                                          |
| `-BatchSize <int>`           | Number of lines to process per batch *(Default: `10000`)*                   |
| `-StartDate <datetime>`      | Only include events after this date                                         |
| `-EndDate <datetime>`        | Only include events before this date                                        |
| `-Deduplicate`               | Enable deduplication of timeline entries                                    |
| `-Interactive`               | Launch interactive configuration menu                                       |
| `-Help`                      | Display this help menu                                                      |

---

## 🔧 Tool Switches

| Switch                         | Description                                  |
|--------------------------------|----------------------------------------------|
| `-ProcessKape`                 | Process EZ Tools KAPE output                 |
| `-ProcessChainsaw`             | Process Chainsaw CSV exports                |
| `-ProcessHayabusa`             | Process Hayabusa CSV exports                |
| `-ProcessAxiom`                | Process Magnet Axiom CSV exports            |
| `-ProcessNirsoftWebHistory`    | Process Nirsoft BrowsingHistoryView CSV     |
| `-SkipEventLogs`               | Skip EZ Tools Event Log processing          |

---

## 🧩 Supported Artifacts

### 📁 EZ Tools (KAPE)

| Artifact                 | Default Path |
|--------------------------|--------------|
| **Amcache (AmcacheParser)**           | `$BaseDir\kape_out\ProgramExecution\*ssociatedFileEntries.csv` |
| **AppCompatCache (Shim)**             | `$BaseDir\kape_out\ProgramExecution\*AppCompatCache*.csv` |
| **Deleted Files (RBCmd)**             | `$BaseDir\kape_out\FileDeletion\*RBCmd*.csv` |
| **Event Logs (EvtxECmd)**             | `$BaseDir\kape_out\EventLogs\*.csv` |
| **Jump Lists (JLECmd)**               | `$BaseDir\kape_out\FileFolderAccess\*_AutomaticDestinations.csv` |
| **LNK Files (LECmd)**                 | `$BaseDir\kape_out\FileFolderAccess\*_LECmd_Output.csv` |
| **MFT (MFTECmd)**                     | `$BaseDir\kape_out\FileSystem\*MFT_Out*.csv` |
| **Prefetch (PECmd)**                  | `$BaseDir\kape_out\ProgramExecution\*_PECmd_Output.csv` |
| **Registry (RECmd)**                  | `$BaseDir\kape_out\Registry\*_RECmd_Batch_Kroll_Batch_Output.csv` |
| **Shellbags (SBECmd)**                | `$BaseDir\kape_out\FileFolderAccess\*_UsrClass.csv` or `_NTUSER.csv` |

### 🧲 Axiom (Magnet)

| Artifact                     | Default Path |
|------------------------------|--------------|
| **Amcache**                      | `$BaseDir\axiom\AmCache File Entries.csv` |
| **AppCompatCache (Shim)**        | `$BaseDir\axiom\Shim Cache.csv` |
| **AutoRuns**                     | `$BaseDir\axiom\AutoRun Items.csv` |
| **Chrome Web History**           | `$BaseDir\axiom\Chrome Web History.csv` |
| **Edge/IE Main History**         | `$BaseDir\axiom\Edge-Internet Explorer 10-11 Main History.csv` |
| **Jump Lists**                   | `$BaseDir\axiom\Jump Lists.csv` |
| **LNK Files**                    | `$BaseDir\axiom\LNK Files.csv` |
| **MRU (Folder Access)**          | `$BaseDir\axiom\MRU Folder Access.csv` |
| **MRU (Open-Saved Files)**       | `$BaseDir\axiom\MRU Opened-Saved Files.csv` |
| **MRU (Recent Files & Folders)** | `$BaseDir\axiom\MRU Recent Files & Folders.csv` |
| **Prefetch**                     | `$BaseDir\axiom\Prefetch Files*.csv` |
| **Recycle Bin**                  | `$BaseDir\axiom\Recycle Bin.csv` |
| **Shellbags**                    | `$BaseDir\axiom\Shellbags.csv` |
| **UserAssist**                   | `$BaseDir\axiom\UserAssist.csv` |

### 🛡️ Hayabusa

- **Event Logs with Sigma rule matching:**  
  `$BaseDir\hayabusa\hayabusa.csv`

### 🧨 Chainsaw

- **Sigma-correlated event logs:**  
  `$BaseDir\chainsaw\*.csv`

### 🌐 Nirsoft

- **Web Browsing History (BrowsingHistoryView):**  
  `$BaseDir\nirsoft\*.csv`

---

## 📈 Features

- Efficient batch processing for large CSVs  
- Interactive prompts and progress indicators  
- Filter by start/end date  
- Deduplication support  
- Combined timeline across tools  
- Clear artifact coloring (via Excel macro)

---

## Advanced Usage

### MFT Filtering

The tool provides options to filter MFT entries by file extension and path. Default filters include:

- Extensions: .identifier, .exe, .ps1, .zip, .rar, .7z
- Paths: Users, tmp

These can be customized in interactive mode or by modifying the script parameters.

### Event Log Filtering

Event logs are filtered by channel and event ID. You can customize the filtering criteria in the script by modifying the `$EventChannelFilters` hashtable.

# Forensic Timeliner Supported Artifacts with Tool and Description Details

| Artifact Name | Description | Supported Forensic Tool Output | Artifact Description | Time Stamps Used|
|----------------|----------------------------|----------------------|----------------------|---------------------------|
| AmCache        | Cached application information            | Axiom, EZ Tools/Kape                   | Program Execution | Last Write    |
| AppCompatCache | Application Compatability Checker  | Axiom, EZ Tools/Kape                   | Program Execution | Last Modified |
| ChromeHistory  | Chrome browser history     | Axiom                                  | Web Activity, Web Search, Web Download   | Last Visited  |
| EdgeIEHistory  | Chrome browser history     | Axiom                                  | File & Folder Access, Web Activity, Web Search, Web Download | Last Accessed  / Last Visited |
| EventLogs      | Windows Event Logs         | EZ Tools/Kape, Chainsaw, Hayabusa      | **Maps to Channels identifiers    | Event Time  |
| File Deletion  | Deleted File Info          | EZ Tools/Kape                          | File System       | File Deleted On |
| FireFoxHistory | Firefox browser history    | Axiom                                  | Web Activity, Web Search, Web Download   | Last Visited |
| JumpLists      | Recent file/folder/application usage | Axiom, EZ Tools/Kape         | File & Folder Access     | Creation Time, Last Access Time, Last Modified Time |
| LNK Files      | Recent file/folder/application usage | Axiom, EZ Tools/Kape         | File & Folder Access     | Source Created, Source Modified Time, Target Created |
| MFT            | Windows NTFS file system metadata | EZ Tools/Kape, Chainsaw          File System       | Date Created | 
| OperaHistory   | Opera browser history      | Axiom, Nirsoft                         | Web Activity, Web Search, Web Download | Last Visited |
| PrefetchFiles  | File Execution             | Axiom, EZ Tools/Kape                   | Program Execution | Last Run, File Created |
| Recycle Bin    | Deleted File Info          | Axiom                                 | File System       | File Deleted On |
| Registry       | Windows registry artifacts | Axiom, EZ Tools/Kape                   | Registry, Registry - MRU Opened-Saved Files, Registry - MRU Recent Files & Folders , Registry - MRU Folder Access, Registry - AutoRun Items, Registry - UserAssist| LAst Run, Last Write, Registry Modified |
| Shellbags      | Folder view preferences and accessed locations | Axiom, EZ Tools/Kape | File & Folder Access | First Interaction, Last Interaction, Last Modified, Last Write |
| WebHistory - Brave  | Brave browser history  | Nirsoft | Web Activity, Web Search, Web Download | Event Time |
| WebHistory - Chrome | Chrome browser history | Nirsoft | Web Search, Web Download | Event Time |
| WebHistory - Chrome | Chrome browser history | Nirsoft | Web Activity, Web Search, Web Download | Event Time |
| WebHistory - Internet Explorer | IE browser history | Nirsoft | File & Folder Access, Web Activity, Web Search, Web Download | Event Time |
| WebHistory - Opera | Opera browser history | Nirsoft | Web Activity, Web Search, Web Download | Event Time |










## License

This project is licensed under the MIT License - see the LICENSE file for details.

### Special Thanks
Eric Zimmerman for building and maintaining Kape and all his tools
Chainsaw Creators
Nirsoft
Anybody who uses this!

# Disclaimer
DISCLAIMER: This script is provided as-is, without warranty or guarantee of fitness for a particular purpose. It automates third-party tools that are licensed under their own terms. Ensure you have proper authorization to use and distribute all tools involved.


