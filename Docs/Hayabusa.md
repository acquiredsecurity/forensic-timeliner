# 🔹 Hayabusa

**Parser:** `HayabusaParser.cs`

### 🧩 Field Mapping

| Timeline Field | Source Field | Notes                                    |
| -------------- | ------------ | ---------------------------------------- |
| DateTime       | Timestamp    | Primary timestamp field                  |
| TimestampInfo  | "Event Time" | Constant                                 |
| ArtifactName   | "Event Logs" | Constant                                 |
| Tool           | Tool name    | Defined in YAML config                   |
| Description    | Channel      | Event log channel                        |
| EventId        | EventID      | Event identifier                         |
| DataPath       | Details      | Event details/description                |
| DataDetails    | RuleTitle    | Sigma rule title that triggered          |
| Computer       | Computer     | Source computer name                     |
| EvidencePath   | File path    | Relative to baseDir                      |

### ⚙️ Special Behavior

* **Flexible timestamp detection**: If the primary `Timestamp` field is missing, falls back to alternative timestamp fields in this order:
  - `timestamp`
  - `datetime` 
  - `date`
  - `time`
  - `event_time`
  - `eventtime`

* **Automatic CSV discovery**: Uses the Discovery utility to find Hayabusa CSV files based on filename patterns, folder names, and file headers.

* **Progress tracking**: Displays real-time progress during CSV processing with row count updates.

### 📝 Expected CSV Format

Hayabusa typically outputs CSV files with these key columns:
- **Timestamp**: Primary event timestamp (ISO format preferred)
- **Channel**: Windows event log channel (e.g., Security, System, Application)
- **EventID**: Windows event ID number
- **Details**: Detailed event description or payload
- **RuleTitle**: Name of the Sigma rule that detected the event
- **Computer**: Source computer/hostname

### 💡 Integration Notes

- Place Hayabusa CSV output in a folder named `Hayabusa` for automatic discovery
- Name the output file with "Hayabusa" in the filename (e.g., `Hayabusa.csv`, `Hayabusa_timeline.csv`)
- The parser automatically maps Hayabusa's event data to the unified timeline format for analysis in Timeline Explorer
