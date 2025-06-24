# 🧠 Chainsaw Artifact Documentation

This page documents how Chainsaw artifacts are parsed into Forensic Timeliner's timeline format.

## 📁 Artifacts

* [Account Tampering](#account-tampering)
* [Antivirus](#antivirus)
* [Applocker](#applocker)
* [Chainsaw MFT](#chainsaw-mft)
* [Credential Access](#credential-access)
* [Defense Evasion](#defense-evasion)
* [Indicator Removal](#indicator-removal)
* [Lateral Movement](#lateral-movement)
* [Login Attacks](#login-attacks)
* [Log Tampering](#log-tampering)
* [Microsoft RAS VPN Events](#microsoft-ras-vpn-events)
* [Microsoft RDS Events](#microsoft-rds-events)
* [Persistence](#persistence)
* [PowerShell](#powershell)
* [RDP Events](#rdp-events)
* [Service Installation](#service-installation)
* [Service Tampering](#service-tampering)
* [Sigma Rules](#sigma-rules)

---

## 🔹 Account Tampering

**Parser:** `AccountTamperingParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Account Tampering"        | Constant                           |
| DataPath       | User SID, Member SID       | First available SID value          |
| EventId        | Event ID                   | Windows event identifier           |
| User           | User Name                  | Account name                       |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Antivirus

**Parser:** `AntivirusParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Antivirus"                | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Threat Path                | Path to detected threat            |
| EventId        | Event ID                   | Windows event identifier           |
| User           | User                       | User account                       |
| SHA1           | SHA1                       | File hash                          |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Applocker

**Parser:** `ApplockerParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Applocker"                | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Executable                 | Blocked/allowed executable         |
| EventId        | Event ID                   | Windows event identifier           |
| User           | User Name                  | User account                       |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Chainsaw MFT

**Parser:** `ChainsawMftParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "MFT"                      | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "MFT Created"              | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | FileNamePath               | Full file path                     |
| FileSize       | FileSize                   | File size in bytes                 |
| FileExtension  | Derived from path          | Extracted and lowercased           |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Credential Access

**Parser:** `CredentialAccessParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Credential Access"        | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Process Name               | Process involved in credential access |
| EventId        | Event ID                   | Windows event identifier           |
| User           | User Name                  | User account                       |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Defense Evasion

**Parser:** `DefenseEvasionParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Defense Evasion"          | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Service Name               | Service involved in evasion        |
| EventId        | Event ID                   | Windows event identifier           |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Indicator Removal

**Parser:** `IndicatorRemovalParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Indicator Removal"        | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Scheduled Task Name        | Task involved in indicator removal |
| EventId        | Event ID                   | Windows event identifier           |
| User           | User Name                  | User account                       |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Lateral Movement

**Parser:** `LateralMovementParser.cs`

### 🧩 Field Mapping

| Timeline Field     | Source Field               | Notes                              |
| ------------------ | -------------------------- | ---------------------------------- |
| DateTime           | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo      | "Event Time"               | Constant                           |
| ArtifactName       | "Event Logs"               | Constant                           |
| Tool               | Tool name                  | Defined in YAML config             |
| Description        | "Lateral Movement"         | Constant                           |
| DataDetails        | detections                 | Detection details                  |
| DataPath           | Logon Type                 | Type of logon used                 |
| EventId            | Event ID                   | Windows event identifier           |
| User               | User                       | User account                       |
| Computer           | Computer                   | Source system                      |
| IPAddress          | IP Address                 | IP address involved                |
| DestinationAddress | Dest Address               | Destination IP                     |
| SourceAddress      | Source Address             | Source IP                          |
| EvidencePath       | path or file               | Relative to baseDir                |

---

## 🔹 Login Attacks

**Parser:** `LoginAttacksParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Login Attacks"            | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| EventId        | Event ID                   | Windows event identifier           |
| Count          | count                      | Number of attack attempts          |
| User           | User                       | Target user account                |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Log Tampering

**Parser:** `LogTamperingParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp                  | Primary timestamp only             |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Log Tampering"            | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| EventId        | Event ID                   | Windows event identifier           |
| User           | User Name                  | User account                       |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | file                       | Source file path                   |

---

## 🔹 Microsoft RAS VPN Events

**Parser:** `MicrosoftRasVpnEventsParser.cs`

### 🧩 Field Mapping

| Timeline Field     | Source Field               | Notes                              |
| ------------------ | -------------------------- | ---------------------------------- |
| DateTime           | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo      | "Event Time"               | Constant                           |
| ArtifactName       | "Event Logs"               | Constant                           |
| Tool               | Tool name                  | Defined in YAML config             |
| Description        | "RAS VPN Events"           | Constant                           |
| DataDetails        | detections                 | Detection details                  |
| DataPath           | Remote IP                  | VPN remote IP address              |
| DestinationAddress | Remote IP                  | Same as DataPath                   |
| EventId            | Event ID                   | Windows event identifier           |
| User               | User Name                  | VPN user account                   |
| Computer           | Computer                   | Source system                      |
| EvidencePath       | path or file               | Relative to baseDir                |

---

## 🔹 Microsoft RDS Events

**Parser:** `MicrosoftRdsEventsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "RDS Events"               | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Information                | RDS event information              |
| EventId        | Event ID                   | Windows event identifier           |
| User           | User Name                  | User account                       |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Persistence

**Parser:** `PersistenceParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Persistence"              | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Scheduled Task Name        | Persistence mechanism              |
| EventId        | Event ID                   | Windows event identifier           |
| User           | User Name                  | User account                       |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 PowerShell

**Parser:** `PowershellParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "PowerShell"               | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Information, HostApplication | PowerShell command or host info  |
| User           | User Name                  | User account                       |
| Computer       | Computer                   | Source system                      |
| EventId        | Event ID                   | Windows event identifier           |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 RDP Events

**Parser:** `RdpEventsParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "RDP Events"               | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Information                | RDP session information            |
| User           | User Name                  | User account                       |
| EventId        | Event ID                   | Windows event identifier           |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Service Installation

**Parser:** `ServiceInstallationParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Service Installation"     | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Service Name + Service File Name | Combined service info        |
| User           | User Name                  | User account                       |
| EventId        | Event ID                   | Windows event identifier           |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Service Tampering

**Parser:** `ServiceTamperingParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Service Tampering"        | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Service Name + Service File Name | Combined service info        |
| User           | User Name                  | User account                       |
| EventId        | Event ID                   | Windows event identifier           |
| Computer       | Computer                   | Source system                      |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## 🔹 Sigma Rules

**Parser:** `SigmaParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| DateTime       | timestamp, TimeCreated, UtcTime | Flexible timestamp detection |
| TimestampInfo  | "Event Time"               | Constant                           |
| ArtifactName   | "Event Logs"               | Constant                           |
| Tool           | Tool name                  | Defined in YAML config             |
| Description    | "Sigma Rule Match"         | Constant                           |
| DataDetails    | detections                 | Detection details                  |
| DataPath       | Event Data                 | Event log data                     |
| EventId        | Event ID                   | Windows event identifier           |
| Computer       | Computer                   | Source system                      |
| Count          | count                      | Number of matches                  |
| EvidencePath   | path or file               | Relative to baseDir                |

---

## ⚙️ Special Behavior

* **Flexible timestamp detection**: All parsers support multiple timestamp fields in order of preference:
  - `timestamp` (primary)
  - `TimeCreated` (fallback)
  - `UtcTime` (secondary fallback)

* **Automatic CSV discovery**: Uses the Discovery utility to find Chainsaw CSV files based on filename patterns, folder names, and file headers.

* **MITRE ATT&CK mapping**: Each parser corresponds to specific attack techniques and tactics for focused analysis.

* **Unified event log format**: All parsers normalize different Chainsaw outputs to a consistent timeline format.

### 📝 Expected CSV Format

Chainsaw typically outputs CSV files with these common columns:
- **timestamp/TimeCreated/UtcTime**: Event timestamp
- **Event ID**: Windows event log identifier
- **Computer**: Source computer name
- **detections**: Sigma rule or detection details
- **path**: Source file path for evidence tracking

### 💡 Integration Notes

- Place Chainsaw CSV outputs in folders with "Chainsaw" in the name for automatic discovery
- Each parser handles specific attack categories (MITRE ATT&CK techniques)
- The tool automatically maps Chainsaw's detection results to the unified timeline format
- Supports both Sigma rule matches and custom Chainsaw detection rules
