# Forensic Timeliner

A comprehensive digital forensic timeline generation tool that automatically discovers and processes forensic artifacts from multiple sources.

## Overview

Forensic Timeliner is designed to help investigators create unified timelines from various forensic artifacts scattered across complex directory structures. It supports output from popular forensic tools including:

- EZ Tools (Amcache, AppCompat, MFT, Prefetch, Registry, Shellbags, etc.)
- Hayabusa (Windows Event Log Analysis) 
- Nirsoft (BrowsingHistoryView)
- Chainsaw (Event Log Parser)
- Axiom (Commercial Forensic Tool)

## Key Features

- **Intelligent Artifact Discovery**: Automatically locates relevant forensic files across complex directory structures
- **Multi-tool Integration**: Processes outputs from multiple forensic tools into a unified timeline
- **Robust File Handling**: Handles large files through efficient batch processing
- **Automatic Directory Structure Detection**: Identifies common artifact directories without manual configuration
- **Flexible Output Options**: Export to CSV, JSON, or Excel formats

## Quick Start

```bash
# Basic usage with automatic discovery
python timeliner.py --BaseDir "C:\path\to\triage_data" --ALL --AutoDetect

# Process specific modules
python timeliner.py --BaseDir "C:\path\to\triage_data" --ProcessEZ --ProcessHayabusa

# With date filtering
python timeliner.py --BaseDir "C:\path\to\triage_data" --ALL --StartDate 2023-01-01 --EndDate 2023-03-01
```

## Command Line Options

### Directory Configuration

| Option | Description |
|--------|-------------|
| `--BaseDir` | Base directory for triage data (default: C:\triage) |
| `--EZDirectory` | Directory for EZ Tools output |
| `--HayabusaDirectory` | Directory for Hayabusa output |
| `--ChainsawDirectory` | Directory for Chainsaw output |
| `--NirsoftDirectory` | Directory for Nirsoft output |
| `--AxiomDirectory` | Directory for Axiom output |

### Artifact Subdirectory Configuration

| Option | Description |
|--------|-------------|
| `--ProgramExecSubDir` | Directory containing program execution artifacts |
| `--FileFolderSubDir` | Directory containing file/folder access artifacts |
| `--FileSystemSubDir` | Directory containing filesystem artifacts |
| `--FileDeletionSubDir` | Directory containing file deletion artifacts |
| `--RegistrySubDir` | Directory containing registry artifacts |
| `--EventLogsSubDir` | Directory containing event log artifacts |
| `--NirsoftSubDir` | Directory containing Nirsoft output |

### Processing Options

| Option | Description |
|--------|-------------|
| `--ProcessEZ` | Process EZ Tools output |
| `--ProcessHayabusa` | Process Hayabusa output |
| `--ProcessNirsoft` | Process Nirsoft output |
| `--ProcessChainsaw` | Process Chainsaw output |
| `--ProcessAxiom` | Process Axiom output |
| `--ALL` | Process all available artifact types |

### Discovery Options

| Option | Description |
|--------|-------------|
| `--AutoDetect` | Automatically detect artifact directories and files |
| `--Recursive` | Enable recursive discovery of artifact files |
| `--DiscoveryDepth` | Maximum directory depth for recursive discovery (default: 3) |
| `--verbose` | Enable verbose output for debugging |

### Filtering and Output Options

| Option | Description |
|--------|-------------|
| `--MFTExtensionFilter` | Filter MFT entries by file extensions |
| `--MFTPathFilter` | Filter MFT entries by path components |
| `--StartDate` | Filter events starting from date (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ) |
| `--EndDate` | Filter events ending at date (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ) |
| `--Deduplicate` | Remove duplicate entries from the timeline |
| `--OutputFile` | Path to output file (default: timestamp_forensic_timeliner.csv) |
| `--ExportFormat` | Format of the output file [csv, json, xlsx] (default: csv) |
| `--BatchSize` | Number of records to process at once (default: 10000) |

### Other Options

| Option | Description |
|--------|-------------|
| `--Interactive` | Enable interactive configuration mode |
| `--Help` | Show detailed help information |

## Directory Structure Discovery

The tool can automatically discover forensic artifacts within complex directory structures. Here's how it works:

### 1. Pattern-Based Discovery

The tool uses pattern matching to identify directories containing specific forensic artifacts:

```
# Example directory structure - will be automatically discovered
C:\triage\
  |-- EZ_Tools_Output\
      |-- Program_Execution\
          |-- Prefetch_PECmd_Output.csv
          |-- Amcache_AssociatedFileEntries.csv
      |-- Registry\
          |-- Registry_RECmd_Batch_Kroll_Batch_Output.csv
  |-- Hayabusa_Output\
      |-- hayabusa_results.csv
  |-- BHV\
      |-- browsinghistory.csv
```

### 2. Discovery Process

The discovery process follows these steps:

1. **First Pass**: Look for tool output directories (EZ Tools, Hayabusa, Nirsoft, etc.)
2. **Second Pass**: Look for artifact subdirectories within tool directories
3. **Third Pass**: Look for specific artifact file types in discovered directories
4. **Fallback**: If directories aren't found, use default subdirectory names

### 3. Supported Directory Patterns

The tool recognizes many naming conventions:

- **EZ Tools**: `ez_tools`, `kape_out`, `kape_results`, `triage_out`, etc.
- **Hayabusa**: `hayabusa`, `haya_out`, `event_detection`, `sigma`, etc.
- **Nirsoft**: `nirsoft`, `browser_history`, `web_history`, etc.
- **Program Execution**: `program_exec`, `execution`, `amcache`, `prefetch`, etc.
- **File Deletion**: `file_deletion`, `deleted`, `recycle`, `recycle_bin`, etc.
- **Registry**: `registry`, `reg`, `hive`, `ntuser`, etc.

## Advanced Usage Examples

### Discovering and Processing All Artifacts

```bash
python timeliner.py --BaseDir "D:\cases\case123\evidence01" --ALL --AutoDetect --Recursive
```

### Processing Specific Artifact Types with Custom Paths

```bash
python timeliner.py --BaseDir "D:\cases\case123" --ProcessEZ --ProcessHayabusa --EZDirectory "D:\cases\case123\KAPE_Output" --HayabusaDirectory "D:\cases\case123\Hayabusa_Output" --Recursive
```

### Filtering by Date Range and Exporting to JSON

```bash
python timeliner.py --BaseDir "D:\cases\case123" --ALL --StartDate 2023-05-15T00:00:00Z --EndDate 2023-05-17T23:59:59Z --ExportFormat json --OutputFile "D:\cases\case123\reports\may_incident.json"
```

### Handling Large Datasets

```bash
python timeliner.py --BaseDir "D:\cases\case123" --ALL --AutoDetect --BatchSize 5000 --Deduplicate
```

### Verbose Debugging Mode

```bash
python timeliner.py --BaseDir "D:\cases\case123" --ALL --AutoDetect --verbose
```

## Extending the Tool

### Adding New Parsers

1. Create a new module in the appropriate tool directory
2. Implement a `process_xyz()` function that follows the existing pattern
3. Update the file discovery patterns in `utils/file_discovery.py`
4. Import and call your parser in `timeliner.py`

### Adding New File Patterns

Edit the `FILE_PATTERNS` dictionary in `utils/file_discovery.py`:

```python
FILE_PATTERNS = {
    'YourNewFileType': [r'.*your_pattern.*\.csv', r'.*alternate_pattern.*\.csv'],
    # Existing patterns...
}
```

## Troubleshooting

### Common Issues

1. **No files found**: Check that your directory structure is correct and that files exist. Try using the `--verbose` flag for detailed output.

2. **Error processing files**: Check that the CSV files are properly formatted and contain the expected columns. If needed, add column name mappings in the relevant parser.

3. **Missing timeline data**: Ensure that date fields are properly formatted in your source files. The tool expects dates that can be parsed by pandas.

### Debugging

Enable verbose logging to see the full discovery process:

```bash
python timeliner.py --BaseDir "C:\path\to\triage_data" --ALL --AutoDetect --verbose
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
