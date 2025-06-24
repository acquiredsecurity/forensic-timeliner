# 🧠 Axiom Artifact Documentation

This page documents how Magnet Axiom artifacts are parsed into Forensic Timeliner's timeline format.

## 📁 Artifacts

* [Activity Timeline](#activity-timeline)
* [Amcache](#amcache)
* [AppCompat Cache](#appcompat-cache)
* [AutoRuns](#autoruns)
* [Chrome History](#chrome-history)
* [Edge History](#edge-history)
* [Event Logs](#event-logs)
* [Firefox History](#firefox-history)
* [IE History](#ie-history)
* [Jump Lists](#jump-lists)
* [LNK Files](#lnk-files)
* [MRU Folder Access](#mru-folder-access)
* [MRU Open & Saved](#mru-open--saved)
* [MRU Recent](#mru-recent)
* [Opera History](#opera-history)
* [Prefetch](#prefetch)
* [Recycle Bin](#recycle-bin)
* [Shellbags](#shellbags)
* [UserAssist](#userassist)

---

## 🔹 Activity Timeline

**Parser:** `AxiomActivityTimelineParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                      | Notes                                    |
| -------------- | ------------------------------------------------- | ---------------------------------------- |
| DateTime       | Multiple UTC timestamp fields                     | Processes all available timestamp fields |
| TimestampInfo  | Mapped labels                                     | "Start Time", "End Time", "Created", etc. |
| ArtifactName   | "WindowsTimelineActivity"                         | Constant                                 |
| Tool           | Tool name                                         | Defined in YAML config                   |
| Description    | Application Name + Activity Type                  | Combined description                     |
| DataPath       | Application Name, Display Name, Content           | First available value                    |
| DataDetails    | Activity Type                                     | Type of activity performed               |
| EvidencePath   | File path                                         | Relative to baseDir                      |

### ⚙️ Special Behavior

* **Multiple timestamp processing**: Extracts timestamps from 6 different date/time fields:
  - Start Date/Time, End Date/Time, Created Date/Time
  - Created In Cloud Date/Time, Last Modified Date/Time, Client Modified Date/Time
* **Dynamic description building**: Combines application name and activity type

---

## 🔹 Amcache

**Parser:** `AxiomAmcacheParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                      | Notes                         |
| -------------- | ------------------------------------------------- | ----------------------------- |
| DateTime       | Key Last Updated Date/Time - UTC+00:00 (M/d/yyyy) | Last registry key update     |
| TimestampInfo  | "Last Write"                                      | Constant                      |
| ArtifactName   | "Amcache"                                         | Constant                      |
| Tool           | "Axiom"                                           | Hardcoded                     |
| Description    | "Program Execution"                               | Constant                      |
| DataPath       | Full Path                                         | Full executable path          |
| DataDetails    | Associated Application Name                       | Application name              |
| FileExtension  | File Extension                                    | File extension                |
| SHA1           | SHA1 Hash                                         | File hash                     |
| EvidencePath   | File path                                         | Relative to baseDir           |

---

## 🔹 AppCompat Cache

**Parser:** `AxiomAppCompatParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                      | Notes                         |
| -------------- | ------------------------------------------------- | ----------------------------- |
| DateTime       | Key Last Updated Date/Time - UTC+00:00 (M/d/yyyy) | Last registry key update     |
| TimestampInfo  | "Last Update"                                     | Constant                      |
| ArtifactName   | "AppCompatCache"                                  | Constant                      |
| Tool           | Tool name                                         | Defined in YAML config        |
| Description    | "Program Execution"                               | Constant                      |
| DataPath       | File Path                                         | Executable path               |
| DataDetails    | File Name                                         | Executable filename           |
| EvidencePath   | File path                                         | Relative to baseDir           |

---

## 🔹 AutoRuns

**Parser:** `AxiomAutoRunsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                         | Notes                         |
| -------------- | ---------------------------------------------------- | ----------------------------- |
| DateTime       | Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy) | Registry modification time |
| TimestampInfo  | "Last Modified"                                      | Constant                      |
| ArtifactName   | "Registry"                                           | Constant                      |
| Tool           | Tool name                                            | Defined in YAML config        |
| Description    | "Program Execution"                                  | Constant                      |
| DataPath       | File Path                                            | Executable path               |
| DataDetails    | File Name                                            | Executable filename           |
| EvidencePath   | File path                                            | Relative to baseDir           |

### ⚙️ Special Behavior

* **Path validation**: Skips records with empty File Path values

---

## 🔹 Chrome History

**Parser:** `AxiomChromeHistoryParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                      | Notes                              |
| -------------- | ------------------------------------------------- | ---------------------------------- |
| DateTime       | Last Visited Date/Time - UTC+00:00 (M/d/yyyy)    | Last visit timestamp               |
| TimestampInfo  | "Last Visited"                                    | Constant                           |
| ArtifactName   | "Web History"                                     | Constant                           |
| Tool           | Tool name                                         | Defined in YAML config             |
| Description    | "Chrome History" + activity tags                  | Enhanced with activity context     |
| DataPath       | URL                                               | Visited URL                        |
| DataDetails    | Title                                             | Page title                         |
| EvidencePath   | File path                                         | Relative to baseDir                |

### ⚙️ Special Behavior

* **URL activity detection**: Automatically categorizes URLs and adds activity tags:
  - "+ File Open Access" for file:/// URLs
  - "+ Search" for search-related URLs
  - "+ Download" for download-related URLs
* **URL validation**: Skips records with empty URLs

---

## 🔹 Edge History

**Parser:** `AxiomEdgeParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                   | Notes                              |
| -------------- | ---------------------------------------------- | ---------------------------------- |
| DateTime       | Date Visited Date/Time - UTC+00:00 (M/d/yyyy) | Visit timestamp                    |
| TimestampInfo  | "Last Visited"                                 | Constant                           |
| ArtifactName   | "Web History"                                  | Constant                           |
| Tool           | Tool name                                      | Defined in YAML config             |
| Description    | "Edge History" + activity tags                 | Enhanced with activity context     |
| DataPath       | URL                                            | Visited URL                        |
| DataDetails    | Title                                          | Page title                         |
| EvidencePath   | File path                                      | Relative to baseDir                |

### ⚙️ Special Behavior

* **Same URL activity detection as Chrome**: Categorizes file access, searches, and downloads

---

## 🔹 Event Logs

**Parser:** `AxiomEventlogsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                    | Notes                                  |
| -------------- | ----------------------------------------------- | -------------------------------------- |
| DateTime       | Created Date/Time - UTC+00:00 (M/d/yyyy)       | Event creation time                    |
| TimestampInfo  | "Event Time"                                    | Constant                               |
| ArtifactName   | "Event Logs"                                    | Constant                               |
| Tool           | Tool name                                       | Defined in YAML config                 |
| Description    | Event Data enrichment                           | Extracted from event data              |
| DataDetails    | Source/Provider Name                            | Event log source                       |
| DataPath       | Enriched event data                             | Key-value pairs from event             |
| Computer       | Computer                                        | Source computer                        |
| EventId        | Event ID                                        | Windows event identifier               |
| RawData        | Event Data                                      | Full event data (if --IncludeRawData) |
| EvidencePath   | File path                                       | Relative to baseDir                    |

### ⚙️ Special Behavior

* **Provider filtering**: Applies YAML-defined provider filters for event selection
* **Event data enrichment**: Extracts key-value pairs from XML event data using regex
* **Conditional raw data**: Includes full event data only when `--IncludeRawData` flag is set
* **Progress tracking**: Shows real-time progress for large event log files

---

## 🔹 Firefox History

**Parser:** `AxiomFirefoxParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                   | Notes                              |
| -------------- | ---------------------------------------------- | ---------------------------------- |
| DateTime       | Date Visited Date/Time - UTC+00:00 (M/d/yyyy) | Visit timestamp                    |
| TimestampInfo  | "Last Visited"                                 | Constant                           |
| ArtifactName   | "Web History"                                  | Constant                           |
| Tool           | Tool name                                      | Defined in YAML config             |
| Description    | "Firefox History" + activity tags              | Enhanced with activity context     |
| DataPath       | URL                                            | Visited URL                        |
| DataDetails    | Title                                          | Page title                         |
| EvidencePath   | File path                                      | Relative to baseDir                |

### ⚙️ Special Behavior

* **Same URL activity detection as Chrome**: Categorizes file access, searches, and downloads

---

## 🔹 IE History

**Parser:** `AxiomIEHistoryParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                 | Notes                              |
| -------------- | -------------------------------------------- | ---------------------------------- |
| DateTime       | Accessed Date/Time - UTC+00:00 (M/d/yyyy)   | Access timestamp                   |
| TimestampInfo  | "Last Visited"                               | Constant                           |
| ArtifactName   | "Web History"                                | Constant                           |
| Tool           | Tool name                                    | Defined in YAML config             |
| Description    | "IE History" + activity tags                 | Enhanced with activity context     |
| DataPath       | URL                                          | Visited URL                        |
| DataDetails    | Page Title                                   | Page title                         |
| EvidencePath   | Browser Source or file path                  | Flexible evidence path            |

### ⚙️ Special Behavior

* **Same URL activity detection as Chrome**: Categorizes file access, searches, and downloads
* **Flexible evidence path**: Uses Browser Source field if available, otherwise uses file path

---

## 🔹 Jump Lists

**Parser:** `AxiomJumpListsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                      | Notes                                |
| -------------- | ------------------------------------------------- | ------------------------------------ |
| DateTime       | Multiple timestamp fields                         | Processes 4 different timestamp types |
| TimestampInfo  | Mapped labels                                     | "Target Created", "Target Modified", etc. |
| ArtifactName   | "JumpLists"                                       | Constant                             |
| Tool           | Tool name                                         | Defined in YAML config               |
| Description    | "File & Folder Access"                            | Constant                             |
| DataPath       | Linked Path, Location, Source                     | First available path value           |
| DataDetails    | Extracted filename or app name                    | Dynamic based on path type           |
| FileSize       | Target File Size (Bytes)                          | File size                            |
| EvidencePath   | File path                                         | Relative to baseDir                  |

### ⚙️ Special Behavior

* **Multiple timestamp processing**: Extracts from Target Created/Modified/Accessed and Source Accessed
* **Smart path handling**: Determines if path is file or directory and extracts appropriate details

---

## 🔹 LNK Files

**Parser:** `AxiomLnkParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                      | Notes                                |
| -------------- | ------------------------------------------------- | ------------------------------------ |
| DateTime       | Multiple timestamp fields                         | Processes 6 different timestamp types |
| TimestampInfo  | Mapped labels                                     | "Source Created", "Target Modified", etc. |
| ArtifactName   | "LNK"                                             | Constant                             |
| Tool           | Tool name                                         | Defined in YAML config               |
| Description    | "File & Folder Access"                            | Constant                             |
| DataPath       | Linked Path, Source, Location                     | First available path value           |
| DataDetails    | Extracted filename or directory name              | Dynamic based on path type           |
| FileSize       | Target File Size (Bytes)                          | File size                            |
| EvidencePath   | File path                                         | Relative to baseDir                  |

### ⚙️ Special Behavior

* **Comprehensive timestamp processing**: Extracts 6 different timestamp types
* **Smart path handling**: Same logic as Jump Lists for determining file vs directory

---

## 🔹 MRU Folder Access

**Parser:** `AxiomMruFolderAccessParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                         | Notes                         |
| -------------- | ---------------------------------------------------- | ----------------------------- |
| DateTime       | Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy) | Registry modification time |
| TimestampInfo  | "Last Modified"                                      | Constant                      |
| ArtifactName   | "Registry"                                           | Constant                      |
| Tool           | Tool name                                            | Defined in YAML config        |
| Description    | "MRU Folder Access"                                  | Constant                      |
| DataPath       | File & Folder Access                                 | Accessed folder path          |
| DataDetails    | Application Name                                     | Application that accessed folder |
| EvidencePath   | File path                                            | Relative to baseDir           |

### ⚙️ Special Behavior

* **Path validation**: Skips records with empty File & Folder Access values

---

## 🔹 MRU Open & Saved

**Parser:** `AxiomMruOpenSavedParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                         | Notes                         |
| -------------- | ---------------------------------------------------- | ----------------------------- |
| DateTime       | Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy) | Registry modification time |
| TimestampInfo  | "Last Modified"                                      | Constant                      |
| ArtifactName   | "Registry"                                           | Constant                      |
| Tool           | Tool name                                            | Defined in YAML config        |
| Description    | "MRU Open & Saved"                                   | Constant                      |
| DataPath       | File Path                                            | File path                     |
| DataDetails    | File Name                                            | Filename                      |
| EvidencePath   | File path                                            | Relative to baseDir           |

### ⚙️ Special Behavior

* **Path validation**: Skips records with empty File Path values

---

## 🔹 MRU Recent

**Parser:** `AxiomMruRecentParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                         | Notes                         |
| -------------- | ---------------------------------------------------- | ----------------------------- |
| DateTime       | Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy) | Registry modification time |
| TimestampInfo  | "Last Modified"                                      | Constant                      |
| ArtifactName   | "Registry"                                           | Constant                      |
| Tool           | Tool name                                            | Defined in YAML config        |
| Description    | "MRU Recent"                                         | Constant                      |
| DataPath       | File/Folder Link                                     | Link path                     |
| DataDetails    | Extracted name or File/Folder Name                   | Dynamic name extraction       |
| EvidencePath   | File path                                            | Relative to baseDir           |

### ⚙️ Special Behavior

* **Smart name extraction**: Determines if path is file or directory and extracts appropriate name

---

## 🔹 Opera History

**Parser:** `AxiomOperaParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                   | Notes                              |
| -------------- | ---------------------------------------------- | ---------------------------------- |
| DateTime       | Date Visited Date/Time - UTC+00:00 (M/d/yyyy) | Visit timestamp                    |
| TimestampInfo  | "Last Visited"                                 | Constant                           |
| ArtifactName   | "Web History"                                  | Constant                           |
| Tool           | Tool name                                      | Defined in YAML config             |
| Description    | "Opera History" + activity tags                | Enhanced with activity context     |
| DataPath       | URL                                            | Visited URL                        |
| DataDetails    | Title                                          | Page title                         |
| EvidencePath   | File path                                      | Relative to baseDir                |

### ⚙️ Special Behavior

* **Same URL activity detection as Chrome**: Categorizes file access, searches, and downloads

---

## 🔹 Prefetch

**Parser:** `AxiomPrefetchParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                      | Notes                                |
| -------------- | ------------------------------------------------- | ------------------------------------ |
| DateTime       | Multiple timestamp fields                         | Processes 10 different timestamp types |
| TimestampInfo  | Mapped labels                                     | "Last Run", "Previous Run 1-7", etc. |
| ArtifactName   | "Prefetch"                                        | Constant                             |
| Tool           | Tool name                                         | Defined in YAML config               |
| Description    | "Program Execution"                               | Constant                             |
| DataPath       | Application Path                                  | Executable path                      |
| DataDetails    | Application Name                                  | Application name                     |
| Count          | Application Run Count                             | Execution count                      |
| EvidencePath   | File path                                         | Relative to baseDir                  |

### ⚙️ Special Behavior

* **Comprehensive run history**: Processes up to 8 execution timestamps plus creation/volume dates
* **Execution tracking**: Includes run count for frequency analysis

---

## 🔹 Recycle Bin

**Parser:** `AxiomRecycleBinParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                 | Notes                         |
| -------------- | -------------------------------------------- | ----------------------------- |
| DateTime       | Deleted Date/Time - UTC+00:00 (M/d/yyyy)    | Deletion timestamp            |
| TimestampInfo  | "Deleted Time"                               | Constant                      |
| ArtifactName   | "FileDeletion"                               | Constant                      |
| Tool           | Tool name                                    | Defined in YAML config        |
| Description    | "File Deleted"                               | Constant                      |
| DataPath       | Original File Path                           | Original file location        |
| FileSize       | Original File Size                           | File size before deletion     |
| EvidencePath   | File path                                    | Relative to baseDir           |

---

## 🔹 Shellbags

**Parser:** `AxiomShellbagsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                         | Notes                                |
| -------------- | ---------------------------------------------------- | ------------------------------------ |
| DateTime       | Multiple timestamp fields                            | Processes 3 different timestamp types |
| TimestampInfo  | Mapped labels                                        | "First Interacted", "Last Interacted", "Last Write" |
| ArtifactName   | "Shellbags"                                          | Constant                             |
| Tool           | Tool name                                            | Defined in YAML config               |
| Description    | "File & Folder Access"                               | Constant                             |
| DataPath       | Path                                                 | Folder path accessed                 |
| EvidencePath   | File path                                            | Relative to baseDir                  |

### ⚙️ Special Behavior

* **Multiple interaction timestamps**: Tracks first interaction, last interaction, and filesystem timestamps

---

## 🔹 UserAssist

**Parser:** `AxiomUserAssistParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                                 | Notes                         |
| -------------- | -------------------------------------------- | ----------------------------- |
| DateTime       | Last Run Date/Time - UTC+00:00 (M/d/yyyy)   | Last execution time           |
| TimestampInfo  | "Last Run"                                   | Constant                      |
| ArtifactName   | "Registry"                                   | Constant                      |
| Tool           | Tool name                                    | Defined in YAML config        |
| Description    | "Program Execution"                          | Constant                      |
| DataPath       | File Name                                    | Executable name               |
| DataDetails    | User Name                                    | User account                  |
| Count          | Application Run Count                        | Execution count               |
| EvidencePath   | File path                                    | Relative to baseDir           |

### ⚙️ Special Behavior

* **Path validation**: Skips records with empty File Name values
* **Execution tracking**: Includes run count for frequency analysis

---

## ⚙️ Common Axiom Behaviors

* **Standardized timestamp format**: All parsers use Axiom's "UTC+00:00 (M/d/yyyy)" format
* **Automatic CSV discovery**: Uses the Discovery utility for file detection
* **Rich metadata extraction**: Leverages Axiom's detailed artifact extraction
* **Progress tracking**: Most parsers include progress indication for large files
* **Data validation**: Comprehensive validation to skip invalid or empty records

### 📝 Expected CSV Format

Axiom typically outputs CSV files with these characteristics:
- **Consistent timestamp format**: "Date/Time - UTC+00:00 (M/d/yyyy)" pattern
- **Rich metadata fields**: Detailed information for each artifact type
- **Standardized field naming**: Predictable column names across artifact types
- **Unicode support**: Full international character support

### 💡 Integration Notes

- Place Axiom CSV outputs in folders with "Axiom" in the name for automatic discovery
- The tool automatically maps Axiom's detailed field structure to the unified timeline format
- Web history parsers automatically categorize activities (searches, downloads, file access)
- Multiple timestamp fields are processed to provide comprehensive timeline coverage
- All parsers handle Axiom's standardized UTC timestamp format consistently
