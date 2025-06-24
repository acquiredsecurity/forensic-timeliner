# Nirsoft Artifact Documentation

This page documents how Nirsoft utility artifacts are parsed into Forensic Timeliner's timeline format.

## 📁 Artifacts

* [Browsing History View](#browsing-history-view)

---

## Browsing History View

**Parser:** `BrowsingHistoryViewParser.cs`

### Field Mapping

| Timeline Field | Source Field    | Notes                                    |
| -------------- | --------------- | ---------------------------------------- |
| DateTime       | Visit Time      | Visit timestamp                          |
| TimestampInfo  | "Last Visited"  | Constant                                 |
| ArtifactName   | "Web History"   | Constant                                 |
| Tool           | Tool name       | Defined in YAML config                   |
| Description    | Web Browser + activity tags | Enhanced with activity context |
| DataPath       | URL             | Visited URL                              |
| DataDetails    | Title           | Page title                               |
| User           | User Profile    | User profile/account                     |
| EvidencePath   | File path       | Relative to baseDir                      |

### ⚙️ Special Behavior

* **Browser identification**: Uses the "Web Browser" field to identify the source browser
* **URL activity detection**: Automatically categorizes URLs and adds activity tags:
  - "+ File Open Access" for file:/// URLs
  - "+ Search" for search-related URLs (multiple search engines supported)
  - "+ Download" for download-related URLs (multiple file types and patterns)
* **Cross-browser support**: Consolidates browsing history from multiple browsers into unified timeline
* **User context**: Includes user profile information for multi-user analysis

### 📝 Expected CSV Format

Nirsoft BrowsingHistoryView typically outputs CSV files with these key columns:
- **Visit Time**: Timestamp of the visit
- **URL**: The visited URL
- **Title**: Page title
- **Web Browser**: Source browser (Chrome, Firefox, Edge, IE, etc.)
- **User Profile**: User account/profile name

### Integration Notes

- Place Nirsoft CSV outputs in folders with "Nirsoft" in the name for automatic discovery
- BrowsingHistoryView consolidates history from multiple browsers into a single output
- The parser automatically detects and categorizes different types of web activities
- Supports analysis across multiple user profiles on the same system
- URLs are normalized to lowercase for consistent processing

---

## Common Nirsoft Behaviors

* **Automatic CSV discovery**: Uses the Discovery utility to find Nirsoft CSV files based on filename patterns, folder names, and file headers
* **Cross-tool compatibility**: Nirsoft utilities often have consistent CSV output formats
* **Multi-user support**: Many Nirsoft tools extract data across user profiles
* **Activity enrichment**: Intelligent categorization of activities based on content analysis

### General Nirsoft CSV Characteristics

Nirsoft utilities typically output CSV files with these features:
- **Consistent field naming**: Predictable column names across different utilities
- **Comprehensive metadata**: Detailed information extraction from Windows artifacts
- **Multi-source aggregation**: Tools often combine data from multiple sources
- **User context**: Strong support for multi-user environments

### General Integration Notes

- Nirsoft tools are designed for standalone forensic analysis and integrate well with timeline analysis
- Most Nirsoft utilities support CSV export making them ideal for timeline integration
- Tools often provide more detailed metadata than built-in Windows utilities
- Output is typically ready for immediate analysis without additional processing

