## Forensic Timeliner
Forensic Timeliner is a PowerShell-based tool that automates the process of aggregating and formatting forensic artifacts from [Chainsaw](https://github.com/WithSecureLabs/chainsaw) and KAPE / [EZTools](https://github.com/EricZimmerman) into a structured **MINI** **Master Timeline** and can output to CSV, JSON and XLSX. Use this tool to quickly get your analysis started on a host by combining the output of Kape/EZ Tools and Chainsaw output. Use the VB macro to color code the artifacts and once you have formatted the Date/Time Column you can sort by Date/Time and start the anlaysis. This tool is designed for forensic analysts who need to quickly timeline and triage using output from Kape, EZTools WebHistoryView and Chainsaw mainly focused on standard !Sans Kape output.

<img width="1407" alt="image" src="https://github.com/user-attachments/assets/300855b7-dc4a-4aef-9ee6-ca36e24d3dbc" />
<img width="1409" alt="image" src="https://github.com/user-attachments/assets/725e7a77-5815-41d6-a111-9889c72875ed" />
<img width="1397" alt="image" src="https://github.com/user-attachments/assets/107f1874-0fe3-4dac-b3e5-2e8f5b5a1dac" />

## Features

- Processes forensic artifacts from multiple sources:
  - KAPE/EZ Tools outputs
  - Chainsaw CSV results
  - Web browsing history
- Normalizes data from different sources into a consistent timeline format
- Applies custom mapping and logic for several forensic artifacts
- Prefilters MFT file and allows for custom path and file extension filters. 
- Prefilters Event log data for high priority Event IDs. Can adjust as needed.
- Categorizes web browsing history by type (Search, Download, File Access)
- Supports filtering by date ranges
- Deduplicates timeline entries
- Exports to multiple formats (CSV, JSON, XLSX)
- Interactive setup mode
- Batch processing for large datasets
  - Uses a StreamReader to read the file line by line into batches of 10k lines at a time

## Requirements

- Windows environment with PowerShell 5.1+
- Optional: ImportExcel module (auto-installed if needed for XLSX export)

## Usage

### Quick Start

```powershell
.\forensic_timeliner.ps1 -Interactive
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| -BaseDir | Base directory for KAPE output | C:\kape |
| -KapeDirectory | Path to main KAPE timeline folder | $BaseDir\timeline |
| -WebResultsPath | Path to webResults.csv | $BaseDir\browsinghistory\webResults.csv |
| -ChainsawDirectory | Directory containing Chainsaw CSV files | $BaseDir\chainsaw |
| -OutputFile | Output timeline file | $BaseDir\timeline\Master_Timeline.csv |
| -ExportFormat | Output format (csv, json, xlsx) | csv |
| -SkipEventLogs | Skip event logs processing | False |
| -Deduplicate | Enable deduplication of timeline entries | False |
| -Interactive | Launch interactive prompt | False |
| -Help | Show help menu | False |

## Field Mappings

The tool normalizes various forensic artifacts into a consistent timeline format. Below is how fields from different sources map to the standardized timeline fields:

### Common Timeline Fields

| Field | Description |
|-------|-------------|
| DateTime | Timestamp of the event (normalized to yyyy/MM/dd HH:mm:ss) |
| ArtifactName | Source artifact type (Amcache, MFT, Registry, etc.) |
| EventId | Event ID (mostly for Windows Event Logs) |
| Description | Category of activity (File System, Web Activity, Program Execution, etc.) |
| Info | Additional contextual information |
| DataPath | Primary path or URL information |
| DataDetails | Details about the artifact (filename, title, etc.) |
| User | User account related to the event |
| Computer | Computer name |
| FileSize | Size of the file (if applicable) |
| FileExtension | Extension of the file (if applicable) |
| UserSID | User Security Identifier |
| MemberSID | Member Security Identifier (for group membership) |
| ProcessName | Process name (if applicable) |
| IPAddress | IP address (if applicable) |
| LogonType | Logon type (for authentication events) |
| Count | Count of occurrences (for aggregated events) |
| SourceAddress | Source network address |
| DestinationAddress | Destination network address |
| ServiceType | Service type (for service-related events) |
| CommandLine | Command line (for process execution) |
| SHA1 | SHA1 hash (if available) |
| EvidencePath | Path to the source evidence file |

### Source-Specific Mappings

#### Amcache (Program Execution)
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| FileKeyLastWriteTimestamp | DateTime |
| FullPath | DataPath |
| ProductName | Info |
| Name | DataDetails |
| FileExtension | FileExtension |
| SHA1 | SHA1 |

#### AppCompatCache
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| LastModifiedTimeUTC | DateTime |
| Path | DataPath |
| Path (filename extraction) | DataDetails |
| "Last Modified" | Info |
| SourceFile | EvidencePath |

#### Jump Lists (AutomaticDestinations)
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| SourceCreated | DateTime |
| Path | DataPath |
| AppIdDescription | DataDetails |
| "Source Created" | Info |
| Hostname | Computer |
| FileSize | FileSize |
| SourceFile | EvidencePath |

#### Event Logs
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| TimeCreated | DateTime |
| EventId | EventId |
| Channel | Description |
| MapDescription | Info |
| PayloadData1 | DataDetails |
| PayloadData2 | DataPath |
| Computer | Computer |
| SourceFile | EvidencePath |

### Event Log Filtering

Event logs are filtered by channel and event ID. You can customize the filtering criteria in the script by modifying the `$EventChannelFilters` hashtable.

#### Default Event Log Filtering Configuration

| Channel | Event IDs |
|---------|-----------|
| Application | 1000, 1001 |
| Microsoft-Windows-PowerShell/Operational | 4100, 4103, 4104 |
| Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational | 72, 98, 104, 131, 140 |
| Microsoft-Windows-TerminalServices-LocalSessionManager/Operational | 21, 22 |
| Microsoft-Windows-TaskScheduler/Operational | 106, 140, 141, 129, 200, 201 |
| Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational | 261, 1149 |
| Microsoft-Windows-WinRM/Operational | 169 |
| Security | 1102, 4624, 4625, 4648, 4698, 4702, 4720, 4722, 4723, 4724, 4725, 4726, 4732, 4756 |
| SentinelOne/Operational | 1, 31, 55, 57, 67, 68, 77, 81, 93, 97, 100, 101, 104, 110 |
| System | 7045 |

#### File Deletion
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| DeletedOn | DateTime |
| FileName | DataPath |
| FileName (extracted) | DataDetails |
| FileType | Info |
| FileSize | FileSize |
| SourceName | EvidencePath |

#### LNK Files
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| TargetCreated/SourceCreated/TargetModified | DateTime |
| LocalPath/TargetIDAbsolutePath/NetworkPath | DataPath |
| Extracted filename | DataDetails |
| "Target Created"/"Source Created"/"Target Modified" | Info |
| FileSize | FileSize |
| SourceFile | EvidencePath |

#### MFT
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| Created0x10 | DateTime |
| ParentPath | DataPath |
| FileName | DataDetails |
| "File Created" | Info |
| FileSize | FileSize |
| Extension | FileExtension |

MFT Filtering:

Filters by File Path by looking in the Users Directory or TMP folder. Can be configured in interactive mode or in the script.
Filter by file path looking for executables and file compression. Can be configured in interactive mode or in the script.



#### Prefetch Files
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| LastRun | DateTime |
| SourceFilename | DataPath |
| "Last Run" | Info |
| ExecutableName | DataDetails |

#### Registry
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| LastWriteTimestamp | DateTime |
| ValueData | DataPath |
| Category | Description |
| Description | DataDetails |
| Comment | Info |
| HivePath | EvidencePath |

#### Shellbags
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| LastWriteTime/FirstInteracted/LastInteracted | DateTime |
| AbsolutePath | DataPath |
| Value | DataDetails |
| Last Write, First/Last Interacted | Info |

#### Web History
| EZ Tool Field | Timeline Field |
|--------------|----------------|
| Visit Time | DateTime |
| URL | DataPath |
| Web Browser | Info |
| Title / Extracted Filename | DataDetails |
| Description | Description (categorized as "Web Search", "Web Download", "File & Folder Access", or "Web Activity") |
| User Profile | User |

URL Categorization for Web History:
- URLs starting with "file:///" are categorized as "File & Folder Access" with filename extraction
- URLs containing search terms are categorized as "Web Search"
- URLs containing download indicators are categorized as "Web Download" 
- Other URLs are categorized as "Web Activity"

#### Chainsaw CSV Files
| Chainsaw Field | Timeline Field |
|--------------|----------------|
| timestamp | DateTime |
| Event ID | EventId |
| "Chainsaw" | Description |
| detections | Info |
| Various fields | DataPath (prioritized based on availability) |
| Various fields | DataDetails (prioritized based on availability) |
| User/User Name | User |
| Computer | Computer |
| User SID | UserSID |
| Member SID | MemberSID |
| Process Name | ProcessName |
| IP Address | IPAddress |
| Logon Type | LogonType |
| count | Count |
| Source Address | SourceAddress |
| Dest Address | DestinationAddress |
| Service Type | ServiceType |
| CommandLine | CommandLine |
| SHA1 | SHA1 |
| path | EvidencePath |

## Output Examples

The timeline entries are formatted as follows:

```
DateTime,ArtifactName,Description,Info,DataDetails,DataPath,FileExtension,EvidencePath,EventId,User,Computer,CommandLine,ProcessName,FileSize,IPAddress,SourceAddress,DestinationAddress,LogonType,UserSID,MemberSID,ServiceType,SHA1,Count
2023/02/15 08:43:22,WebHistory,Web Search,Chrome,How to create PowerShell script,https://www.google.com/search?q=how+to+create+powershell+script,,,,admin,DESKTOP-ABC123,,,,,,,,,,,
2023/02/15 09:12:45,MFT,File System,File Created,script.ps1,C:\Users\admin\Documents,.ps1,,,,,,2048,,,,,,,,,,
2023/02/15 09:15:33,Prefetch Files,Program Execution,Last Run,POWERSHELL.EXE,C:\Windows\Prefetch\POWERSHELL.EXE-1A2B3C4D.pf,,,,,,,,,,,,,,,,,
```

## Advanced Usage

### MFT Filtering

The tool provides options to filter MFT entries by file extension and path. Default filters include:

- Extensions: .identifier, .exe, .ps1, .zip, .rar, .7z
- Paths: Users, tmp

These can be customized in interactive mode or by modifying the script parameters.

### Event Log Filtering

Event logs are filtered by channel and event ID. You can customize the filtering criteria in the script by modifying the `$EventChannelFilters` hashtable.



## License

This project is licensed under the MIT License - see the LICENSE file for details.

### Special Thanks
Eric Zimmerman for building and maintaining Kape and all his tools
Chainsaw Creators
Nirsoft
Anybody who uses this!

# Disclaimer
DISCLAIMER: This script is provided as-is, without warranty or guarantee of fitness for a particular purpose. It automates third-party tools that are licensed under their own terms. Ensure you have proper authorization to use and distribute all tools involved.


