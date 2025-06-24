# 📖 Comprehensive Usage Guide

This section provides detailed command-line examples and YAML configurations for all supported tools and scenarios.

## Table of Contents
* [Quick Start Commands](#quick-start-commands)
* [Interactive Mode](#interactive-mode)
* [Tool-Specific Processing](#tool-specific-processing)
* [Advanced Command Examples](#advanced-command-examples)
* [YAML Configuration Examples](#yaml-configuration-examples)
* [Timeline Explorer Integration](#timeline-explorer-integration)
* [Common Scenarios](#common-scenarios)

---

## Quick Start Commands

### All Tools at Once
Process all supported tools in a directory automatically:
```bash
ForensicTimeliner.exe --BaseDir "C:\triage\hostname" --ALL --OutputFile "C:\timeline.csv"
```

### Interactive Setup (Recommended for First-Time Users)
Launch the interactive configuration wizard:
```bash
ForensicTimeliner.exe --Interactive
```
This will guide you through:
- Directory selection
- Tool configuration
- Output format selection
- Keyword tagging setup

---

## Interactive Mode

The interactive mode provides a user-friendly interface for configuration:

```bash
# Launch interactive mode
ForensicTimeliner.exe --Interactive

```

**Interactive Mode Features:**
- 🔍 **Directory Discovery Preview** - See what CSV files will be processed
- ⚙️ **YAML Configuration Generator** - Create custom configurations
- 📊 **Output Format Selection** - Choose CSV, JSON, or Timeline Explorer format
- 🏷️ **Keyword Tagging Setup** - Configure automated tagging rules
- 📁 **File Organization Tips** - Get suggestions for optimal file structure

---

## Tool-Specific Processing

### EZ Tools / KAPE Processing
```bash
# Basic EZ Tools processing
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\KAPE_Output\hostname" --OutputFile "C:\eztools_timeline.csv"

# EZ Tools with Timeline Explorer session
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\KAPE_Output\hostname" --OutputFile "C:\eztools_timeline" --ExportFormat csv --EnableTagger

# EZ Tools with date filtering
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\KAPE_Output\hostname" --OutputFile "C:\filtered_timeline.csv" --StartDate "2024-01-01" --EndDate "2024-12-31"

# EZ Tools with raw data inclusion
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\KAPE_Output\hostname" --OutputFile "C:\detailed_timeline.csv" --IncludeRawData
```

### Hayabusa Processing
```bash
# Basic Hayabusa processing (expects Hayabusa.csv in Hayabusa folder)
ForensicTimeliner.exe --ProcessHayabusa --BaseDir "C:\hayabusa_output" --OutputFile "C:\hayabusa_timeline.csv"

# Hayabusa with custom file name
ForensicTimeliner.exe --ProcessHayabusa --BaseDir "C:\analysis" --OutputFile "C:\events_timeline.csv"

# Hayabusa with Timeline Explorer integration
ForensicTimeliner.exe --ProcessHayabusa --BaseDir "C:\hayabusa_output" --OutputFile "C:\hayabusa_timeline" --EnableTagger --ExportFormat csv
```

**Hayabusa File Organization:**
```
C:\hayabusa_output\
├── Hayabusa\
│   └── Hayabusa.csv          # Primary output file
└── Hayabusa_timeline.csv     # Alternative naming
```

### Chainsaw Processing
```bash
# Basic Chainsaw processing
ForensicTimeliner.exe --ProcessChainsaw --BaseDir "C:\chainsaw_output" --OutputFile "C:\chainsaw_timeline.csv"

# Chainsaw with specific artifact types
ForensicTimeliner.exe --ProcessChainsaw --BaseDir "C:\chainsaw_output" --OutputFile "C:\attacks_timeline.csv" --EnableTagger

# Chainsaw with deduplication
ForensicTimeliner.exe --ProcessChainsaw --BaseDir "C:\chainsaw_output" --OutputFile "C:\unique_timeline.csv" --EnableDeduplication
```

### Axiom Processing
```bash
# Basic Axiom processing
ForensicTimeliner.exe --ProcessAxiom --BaseDir "C:\Axiom_Export" --OutputFile "C:\axiom_timeline.csv"

# Axiom with comprehensive artifact processing
ForensicTimeliner.exe --ProcessAxiom --BaseDir "C:\Axiom_Export" --OutputFile "C:\full_timeline.csv" --IncludeRawData --EnableTagger

# Axiom web history focus
ForensicTimeliner.exe --ProcessAxiom --BaseDir "C:\Axiom_Export\WebHistory" --OutputFile "C:\web_timeline.csv"
```

### Nirsoft Processing
```bash
# Basic Nirsoft processing
ForensicTimeliner.exe --ProcessNirsoft --BaseDir "C:\nirsoft_output" --OutputFile "C:\WebResults.csv"

# Nirsoft with browser history focus
ForensicTimeliner.exe --ProcessNirsoft --BaseDir "C:\nirsoft_output" --OutputFile "C:\WebResults.csv" --EnableTagger
```

---

## Advanced Command Examples

### Multi-Tool Processing
```bash
# Process multiple tools simultaneously
ForensicTimeliner.exe --ProcessEZ --ProcessHayabusa --ProcessChainsaw --BaseDir "C:\combined_analysis" --OutputFile "C:\unified_timeline.csv"

# All tools with advanced options
ForensicTimeliner.exe --ALL --BaseDir "C:\full_triage" --OutputFile "C:\complete_timeline" --EnableTagger --EnableDeduplication  --ExportFormat csv
```

### Date and Time Filtering
```bash
# Specific date range
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\triage" --OutputFile "C:\incident_timeline.csv" --StartDate "2024-03-15" --EndDate "2024-03-20"

# Last 30 days
ForensicTimeliner.exe --ALL --BaseDir "C:\triage" --OutputFile "C:\recent_timeline.csv" --StartDate "2024-11-01"

# Specific time window (if supported)
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\triage" --OutputFile "C:\timeframe_timeline.csv" --StartDate "2024-03-15T09:00:00" --EndDate "2024-03-15T17:00:00"
```

### Output Format Options
```bash
# CSV output (default)
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\triage" --OutputFile "C:\timeline.csv" --ExportFormat csv

# JSON output
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\triage" --OutputFile "C:\timeline.json" --ExportFormat json

# Timeline Explorer with tagging
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\triage" --OutputFile "C:\timeline" --ExportFormat csv --EnableTagger
```

### Advanced Filtering and Processing
```bash
# Enable deduplication
ForensicTimeliner.exe --ALL --BaseDir "C:\triage" --OutputFile "C:\clean_timeline.csv" --EnableDeduplication

# Include raw event data
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\triage" --OutputFile "C:\detailed_timeline.csv" --IncludeRawData

# Verbose logging
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\triage" --OutputFile "C:\timeline.csv" --Verbose

# Quiet mode (minimal output)
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\triage" --OutputFile "C:\timeline.csv" --Quiet
```

---

## YAML Configuration Examples

### Basic Tool Configuration
Create custom YAML files in the `config\` directory:

#### EZ Tools Configuration (`config\eztools.yaml`)
```yaml
Tool: "EZ Tools"
Artifacts:
  - Artifact: "MFT"
    Parser: "MftParser"
    FilenamePatterns:
      - "*mft*"
      - "*$mft*"
    FoldernamePatterns:
      - "MFT"
      - "FileSystem"
    Filters:
      Extensions:
        - "exe"
        - "dll"
        - "bat"
        - "ps1"
      Paths:
        - "Windows\\System32"
        - "Users\\*\\Desktop"
    Timestamps:
      Created0x10: "Created"
      Modified0x10: "Modified"
      Accessed0x10: "Accessed"

  - Artifact: "EventLogs"
    Parser: "EventlogParser"
    FilenamePatterns:
      - "*eventlog*"
      - "*evtx*"
    Filters:
      EventChannelFilters:
        Security:
          - 4624  # Successful logon
          - 4625  # Failed logon
          - 4648  # Explicit credential logon
        System:
          - 7034  # Service crashed
          - 7035  # Service control manager
```

#### Hayabusa Configuration (`config\hayabusa.yaml`)
```yaml
Tool: "Hayabusa"
Artifacts:
  - Artifact: "EventLogs"
    Parser: "HayabusaParser"
    FilenamePatterns:
      - "*hayabusa*"
      - "*timeline*"
    FoldernamePatterns:
      - "Hayabusa"
      - "hayabusa"
    HeaderPatterns:
      - "Timestamp,Channel,EventID,Details,RuleTitle,Computer"
```

#### Chainsaw Configuration (`config\chainsaw.yaml`)
```yaml
Tool: "Chainsaw"
Artifacts:
  - Artifact: "LateralMovement"
    Parser: "LateralMovementParser"
    FilenamePatterns:
      - "*lateral*movement*"
      - "*chainsaw*lateral*"
    
  - Artifact: "CredentialAccess"
    Parser: "CredentialAccessParser"
    FilenamePatterns:
      - "*credential*access*"
      - "*chainsaw*credential*"
    
  - Artifact: "Persistence"
    Parser: "PersistenceParser"
    FilenamePatterns:
      - "*persistence*"
      - "*chainsaw*persistence*"
```

### Advanced YAML Configuration

#### Custom Filtering Configuration
```yaml
Tool: "EZ Tools"
Artifacts:
  - Artifact: "MFT"
    Parser: "MftParser"
    ignore_filters: false  # Set to true to bypass all filters
    FilenamePatterns:
      - "*mft*"
    Filters:
      Extensions:
        - "exe"
        - "dll"
        - "ps1"
        - "bat"
        - "com"
        - "scr"
      Paths:
        - "Windows\\System32"
        - "Windows\\SysWOW64"
        - "Users\\*\\Desktop"
        - "Users\\*\\Downloads"
        - "Users\\*\\Documents"
        - "ProgramData"
        - "Temp"
    Timestamps:
      Created0x10: "Created"
      Modified0x10: "Modified"
```

#### Event Log Provider Filtering
```yaml
Tool: "EZ Tools"
Artifacts:
  - Artifact: "EventLogs"
    Parser: "EventlogParser"
    ignore_filters: false
    Filters:
      ProviderFilters:
        "Microsoft-Windows-Security-Auditing":
          - 4624  # Successful logon
          - 4625  # Failed logon
          - 4634  # Account logoff
          - 4648  # Explicit credential logon
          - 4672  # Admin privileges assigned
        "Microsoft-Windows-Kernel-General":
          - 1     # Process creation
        "Microsoft-Windows-Sysmon":
          - 1     # Process creation
          - 3     # Network connection
          - 7     # Image loaded
```

### Keyword Tagging Configuration (`config\keywords\keywords.yaml`)
```yaml
KeywordCategories:
  Malware:
    Keywords:
      - "mimikatz"
      - "cobalt"
      - "meterpreter"
      - "powersploit"
    Color: "Red"
    Description: "Potential malware indicators"

  Lateral_Movement:
    Keywords:
      - "psexec"
      - "wmic"
      - "schtasks"
      - "net use"
    Color: "Orange"
    Description: "Lateral movement indicators"

  Data_Exfiltration:
    Keywords:
      - "7zip"
      - "winrar"
      - "compress"
      - "ftp"
      - "sftp"
    Color: "Purple"
    Description: "Data exfiltration indicators"

  Persistence:
    Keywords:
      - "startup"
      - "autostart"
      - "scheduled task"
      - "service install"
    Color: "Yellow"
    Description: "Persistence mechanisms"
```

---

## Timeline Explorer Integration

### Generating Timeline Explorer Sessions
```bash
# Create TLE session with tagging
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\triage" --OutputFile "C:\analysis\timeline" --EnableTagger --ExportFormat csv

# This creates:
# - timeline.csv (main timeline data)
# - timeline.tle (Timeline Explorer session file)
```

### Timeline Explorer Session Structure
The generated `.tle` file contains:
- **File paths** to CSV timeline data
- **Column configurations** optimized for forensic analysis
- **Keyword highlighting** based on your keyword configuration
- **Custom filters** for common forensic scenarios

### Using the Timeline Explorer Session
1. Open Timeline Explorer
2. File → Open → Select the `.tle` file
3. Timeline data loads with pre-configured:
   - Column widths and ordering
   - Keyword highlighting
   - Custom filters
   - Time zone settings

---

## Common Scenarios

### Incident Response Timeline
```bash
# Quick incident response timeline with all tools
ForensicTimeliner.exe --ALL --BaseDir "C:\IR_Collection\hostname" --OutputFile "C:\IR_Analysis\incident_timeline" --EnableTagger --EnableDeduplication --StartDate "2024-03-01" --ExportFormat csv
```

### Malware Analysis Timeline
```bash
# Focus on execution artifacts
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\malware_analysis" --OutputFile "C:\execution_timeline.csv" --EnableTagger

# Include detailed event data
ForensicTimeliner.exe --ProcessEZ --ProcessHayabusa --BaseDir "C:\malware_analysis" --OutputFile "C:\detailed_timeline.csv" --IncludeRawData --EnableTagger
```

### Digital Forensics Investigation
```bash
# Comprehensive timeline for forensic investigation
ForensicTimeliner.exe --ALL --BaseDir "C:\forensic_image_analysis" --OutputFile "C:\investigation\complete_timeline" --EnableTagger --EnableDeduplication --ExportFormat csv

# Web activity focus
ForensicTimeliner.exe --ProcessAxiom --ProcessNirsoft --BaseDir "C:\web_artifacts" --OutputFile "C:\web_activity_timeline.csv" --EnableTagger
```

### Threat Hunting Timeline
```bash
# Event log focused threat hunting
ForensicTimeliner.exe --ProcessHayabusa --ProcessChainsaw --BaseDir "C:\event_logs" --OutputFile "C:\threat_hunt_timeline.csv" --EnableTagger --StartDate "2024-01-01"

# All tools with raw data for deep analysis
ForensicTimeliner.exe --ALL --BaseDir "C:\hunt_data" --OutputFile "C:\comprehensive_hunt.csv" --IncludeRawData --EnableTagger
```

### Performance Optimization
```bash
# Large dataset processing
ForensicTimeliner.exe --ALL --BaseDir "C:\large_dataset" --OutputFile "C:\optimized_timeline.csv" --EnableDeduplication --Quiet

# Memory-efficient processing (process tools separately)
ForensicTimeliner.exe --ProcessEZ --BaseDir "C:\large_dataset" --OutputFile "C:\eztools_part.csv"
ForensicTimeliner.exe --ProcessHayabusa --BaseDir "C:\large_dataset" --OutputFile "C:\hayabusa_part.csv"
ForensicTimeliner.exe --ProcessAxiom --BaseDir "C:\large_dataset" --OutputFile "C:\axiom_part.csv"
```

---

## File Organization Best Practices

### Recommended Directory Structure
```
C:\forensic_analysis\
├── triage_data\
│   ├── EZTools\          # EZ Tools output
│   ├── KAPE\             # KAPE output
│   ├── Hayabusa\         # Hayabusa CSV files hayabusa.csv
│   ├── Chainsaw\         # Chainsaw output
│   ├── Axiom\            # Axiom exports
│   └── Nirsoft\          # Nirsoft utility output WebResults.csv
├── timelines\            # Generated timeline files
├── config\               # Custom YAML configurations
└── keywords\             # Keyword tagging files
```

### Tool-Specific File Naming
- **Hayabusa**: Name output files with "Hayabusa" in the filename (e.g., `Hayabusa_timeline.csv`)
- **Chainsaw**: Use descriptive names for different analysis types (e.g., `chainsaw_lateral_movement.csv`)
- **EZ Tools**: Default KAPE naming is supported automatically
- **Axiom**: Standard Axiom export structure is recognized
- **Nirsoft**: Use tool-specific names (e.g., `BrowsingHistoryView.csv`)

---

## Troubleshooting Tips



**Timeline Explorer session issues:**
- Ensure the `.tle` file and `.csv` file are in the same directory
- Update file paths in the `.tle` file if you move files
- Verify Timeline Explorer can access the file paths specified
- Line Ketyword Tagging may be prone to false positives


