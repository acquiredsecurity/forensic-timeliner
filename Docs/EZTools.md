# 🧠 EZ Tools Artifact Documentation

This page documents how the following EZ Tools artifacts are parsed into Forensic Timeliner's timeline format.

## 📁 Artifacts

* [Activity Timeline](#activity-timeline)
* [Amcache](#amcache)
* [AppCompatCache](#appcompatcache)
* [Deleted Files](#deleted-files)
* [Event Logs](#event-logs)
* [JumpLists](#jumplists)
* [LNK Files](#lnk-files)
* [MFT](#mft)
* [Prefetch](#prefetch)
* [Recent Docs](#recent-docs)
* [Registry](#registry)
* [Shellbags](#shellbags)
* [Typed URLs](#typed-urls)
* [UserAssist](#userassist)

---

## Activity Timeline

**Parser:** `ActivityTimelineParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field                       | Notes                               |
| -------------- | ---------------------------------- | ----------------------------------- |
| DateTime       | StartTime, EndTime, Duration, etc. | Each valid timestamp produces a row |
| TimestampInfo  | "Start Time", etc.                 | Based on the timestamp field name   |
| ArtifactName   | WindowsTimelineActivity            | Hardcoded in parser                 |
| Tool           | "EZ Tools"                         | Defined in YAML config              |
| Description    | "Activity Timeline"                | Defined in YAML config              |
| DataPath       | Executable                         | Path to executable                  |
| DataDetails    | ActivityType                       | Type of activity                    |
| EvidencePath   | File path                          | Relative to baseDir                 |

---

## Amcache

**Parser:** `AmcacheParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field              | Notes                  |
| -------------- | ------------------------- | ---------------------- |
| DateTime       | FileKeyLastWriteTimestamp | Last write time        |
| TimestampInfo  | "Last Write"              | Constant               |
| ArtifactName   | "Amcache"                 | Defined in YAML config |
| Tool           | "EZ Tools"                | Defined in YAML config |
| Description    | "Amcache Entry"           | Defined in YAML config |
| DataPath       | FullPath                  |                        |
| DataDetails    | ApplicationName           |                        |
| FileSize       | Size                      |                        |
| FileExtension  | FileExtension             |                        |
| SHA1           | SHA1                      |                        |
| EvidencePath   | Source file path          | Normalized to baseDir  |

---

## AppCompatCache

**Parser:** `AppCompatParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field        | Notes                              |
| -------------- | ------------------- | ---------------------------------- |
| DateTime       | LastModifiedTimeUTC |                                    |
| TimestampInfo  | "Last Modified"     | Constant                           |
| ArtifactName   | "AppCompatCache"    | Defined in YAML config             |
| Tool           | "EZ Tools"          | Defined in YAML config             |
| Description    | "ShimCache Entry"   | Defined in YAML config             |
| DataPath       | Path                | Full path of binary                |
| DataDetails    | Path (filename)     | Extracted using `Path.GetFileName` |
| EvidencePath   | Source file path    | Relative to baseDir                |

---

## Deleted Files

**Parser:** `DeletedParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field        | Notes                  |
| -------------- | ------------------- | ---------------------- |
| DateTime       | DeletedOn           |                        |
| TimestampInfo  | "File Deleted On"   | Constant               |
| ArtifactName   | "Deleted Files"     | Defined in YAML config |
| Tool           | "EZ Tools"          | Defined in YAML config |
| Description    | "Deleted Artifact"  | Defined in YAML config |
| DataPath       | FileName            |                        |
| DataDetails    | FileName (filename) | Extracted from path    |
| FileSize       | FileSize            |                        |
| EvidencePath   | SourceName or file  | Relative to baseDir    |

---

## Event Logs

**Parser:** `EventlogParser.cs`

### 🧩 Field Mapping

| Timeline Field     | Source Field   | Notes                                |
| ------------------ | -------------- | ------------------------------------ |
| DateTime           | TimeCreated    |                                      |
| TimestampInfo      | "Event Time"   | Constant                             |
| ArtifactName       | "Event Logs"   | Constant                             |
| Tool               | "EZ Tools"     | Defined in YAML config               |
| Description        | MapDescription | Event rule description               |
| DataDetails        | Channel        | Event log channel                    |
| DataPath           | Derived        | Channel, EventID, Computer + Payload |
| EventId            | EventId        | Parsed as string                     |
| Computer           | Computer       |                                      |
| User               | UserName       |                                      |
| DestinationAddress | RemoteHost     |                                      |
| RawData            | Payload        | Only if --IncludeRawData set         |
| EvidencePath       | File path      | Relative to baseDir                  |

### ⚙️ Special Behavior

* Applies **Event ID filters** from YAML via `EventChannelFilters` or `ProviderFilters`.
* Uses a custom method to build a long `DataPath` with payload parts.

---

## JumpLists

**Parser:** `JumplistsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field(s)        | Notes                             |
| -------------- | ---------------------- | --------------------------------- |
| DateTime       | Multiple timestamps    | SourceCreated, CreationTime, etc. |
| TimestampInfo  | e.g., "Source Created" | Label mapped from field key       |
| ArtifactName   | "JumpLists"            | Constant                          |
| Tool           | "EZ Tools"             | From YAML                         |
| Description    | "JumpList Entry"       | From YAML                         |
| DataPath       | Path                   | Full path                         |
| DataDetails    | Path (filename)        | Extracted from Path               |
| FileSize       | FileSize               | Raw long field                    |
| EvidencePath   | Source CSV             | Relative to baseDir               |

---

## LNK Files

**Parser:** `LnkParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field(s)          | Notes                              |
| -------------- | ------------------------ | ---------------------------------- |
| DateTime       | Multiple timestamps      | e.g., SourceCreated, TargetCreated |
| TimestampInfo  | Field label              | e.g., "Target Created"             |
| ArtifactName   | "LNK"                    | From YAML                          |
| Tool           | "EZ Tools"               | From YAML                          |
| Description    | "LNK File"               | From YAML                          |
| DataPath       | LocalPath, TargetID, Net | First available value              |
| DataDetails    | File name from path      | or RelativePath                    |
| FileExtension  | Extracted from path      | Dot trimmed                        |
| FileSize       | FileSize                 | Raw long                           |
| EvidencePath   | Source CSV               | Relative to baseDir                |

---

## MFT

**Parser:** `MftParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field(s)         | Notes                             |
| -------------- | ----------------------- | --------------------------------- |
| DateTime       | From YAML timestamps    | e.g., Created, Accessed, Modified |
| TimestampInfo  | From YAML field mapping | e.g., "Accessed"                  |
| ArtifactName   | "MFT"                   | From YAML                         |
| Tool           | "EZ Tools"              | From YAML                         |
| Description    | With timestamp context  | e.g., "MFT Entry - Modified"      |
| DataPath       | ParentPath + FileName   | Normalized                        |
| DataDetails    | FileName                |                                   |
| FileExtension  | Extension (no dot)      | Lowercased                        |
| FileSize       | FileSize                |                                   |
| EvidencePath   | Source file             | Relative to baseDir               |

### ⚙️ Special Behavior

* Applies path and extension filters via YAML (`artifact.Filters.Paths` and `artifact.Filters.Extensions`).

---

## Prefetch

**Parser:** `PrefetchParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field       | Notes                            |
| -------------- | ------------------ | -------------------------------- |
| DateTime       | RunTime            | Execution timestamp              |
| TimestampInfo  | "Run Time"         | Constant                         |
| ArtifactName   | "Prefetch"         | From YAML                        |
| Tool           | "EZ Tools"         | From YAML                        |
| Description    | "Prefetch Entry"   | From YAML                        |
| DataPath       | Cleaned Executable | Volume prefix removed with regex |
| DataDetails    | Filename from path | `Path.GetFileName(exe)`          |
| EvidencePath   | Source file path   | Relative to baseDir              |

---

## Recent Docs

**Parser:** `RecentDocsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field(s)                          | Notes                                     |
| -------------- | ---------------------------------------- | ----------------------------------------- |
| DateTime       | OpenedOn or ExtensionLastOpened          | First valid timestamp used                |
| TimestampInfo  | "Last Opened" or "Extension Last Opened" | Based on timestamp field used             |
| ArtifactName   | "Registry"                               | Constant                                  |
| Tool           | "EZ Tools"                               | From YAML                                 |
| Description    | "RecentDocs Entry"                       | From YAML                                 |
| DataDetails    | TargetName                               | File/document opened                      |
| DataPath       | LnkName                                  | LNK file path                             |
| FileExtension  | Extension                                | Extension of target file                  |
| EvidencePath   | BatchKeyPath                             | Registry key path                         |
| Computer       | Extracted from filename                  | From `NTUSER.DAT`-based naming convention |

---

## Registry

**Parser:** `RegistryParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field            | Notes                             |
| -------------- | ----------------------- | --------------------------------- |
| DateTime       | LastWriteTimestamp      | Last write time of registry key   |
| TimestampInfo  | "Last Write"            | Constant                          |
| ArtifactName   | "Registry"              | Constant                          |
| Tool           | "EZ Tools"              | From YAML                         |
| Description    | Description + Comment   | Concatenated string               |
| DataDetails    | Same as Description     |                                   |
| DataPath       | ValueName + ValueData\* | Combined from up to 3 data fields |
| EvidencePath   | KeyPath + CSV path      | Normalized                        |

---

## Shellbags

**Parser:** `ShellbagsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field(s)     | Notes                    |
| -------------- | ------------------- | ------------------------ |
| DateTime       | LastWriteTime, etc. | Up to 3 fields processed |
| TimestampInfo  | Field label         | e.g., "First Interacted" |
| ArtifactName   | "Shellbags"         | From YAML                |
| Tool           | "EZ Tools"          | From YAML                |
| Description    | "Shellbag Entry"    | From YAML                |
| DataPath       | AbsolutePath        | Folder viewed            |
| DataDetails    | Value               | Parsed field from CSV    |
| EvidencePath   | CSV source path     | Relative to baseDir      |

---

## Typed URLs

**Parser:** `TypedURLsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field        | Notes                               |
| -------------- | ------------------- | ----------------------------------- |
| DateTime       | Timestamp           | When URL was last typed             |
| TimestampInfo  | "Last Write"        | Constant                            |
| ArtifactName   | "Registry"          | Constant                            |
| Tool           | "EZ Tools"          | From YAML                           |
| Description    | "Typed URL"         | Constant                            |
| DataPath       | Url                 | URL string                          |
| DataDetails    | Url                 | Same as path                        |
| EvidencePath   | BatchKeyPath        | Registry key                        |
| User           | Extracted from file | Username from `NTUSER.DAT` filename |
| IPAddress      | Host extracted      | From parsed URL                     |

---

## UserAssist

**Parser:** `UserAssistParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field       | Notes                  |
| -------------- | ------------------ | ---------------------- |
| DateTime       | LastExecuted       | Last time app was run  |
| TimestampInfo  | "Last Executed"    | Constant               |
| ArtifactName   | "Registry"         | Constant               |
| Tool           | "EZ Tools"         | From YAML              |
| Description    | "UserAssist Entry" | From YAML              |
| DataPath       | BatchValueName     | App path or identifier |
| DataDetails    | ProgramName        | Application name       |
| EvidencePath   | BatchKeyPath       | Registry path          |
| Count          | RunCounter         | Number of executions   |
