## Forensic Timeliner v2.3 – Release Notes

### New Features

- **AS Tools — New Tool Category**
  - Introduced **AS Tools** (Acquired Security) as a first-class tool suite alongside EZ Tools, Axiom, Hayabusa, Chainsaw, and Nirsoft.
  - AS Tools groups together cross-platform forensic parsers built by Acquired Security:
    - **[forensic-webhistory](https://github.com/acquiredsecurity/forensic-webhistory)** — Cross-platform browser history extractor supporting Chrome, Firefox, Edge, Brave, Opera, and Safari. Extracts browsing history from forensic images, KAPE collections, and live systems. Outputs standardized CSV for direct ingestion into Forensic Timeliner.
    - **[evtx-forensic](https://github.com/acquiredsecurity/evtx-forensic)** — Cross-platform Rust-based Windows Event Log (EVTX) analyzer with built-in detection rules.
  - Auto-discovers CSV output from these tools using filename and header-based matching — no manual configuration required.
  - Selectable via `--ProcessAS` on the command line, or "AS Tools" in the interactive menu.
  - Selecting "All" in either CLI (`--ALL`) or interactive mode includes AS Tools automatically.

- **forensic-webhistory Integration**
  - Parses both standard and carved/recovered browser history output.
  - Artifacts: `ForensicWebHistory` (standard extraction) and `ForensicWebHistoryCarved` (recovered/deleted records).
  - Normalizes timestamps, URLs, page titles, browser type, and profile information into the unified timeline format.

---

### Bug Fixes

- **Timezone Corruption on Non-UTC Systems (Critical)**
  - Fixed a bug where all timezone-less timestamps (MFT, Registry, AppCompat, Shellbags, etc.) were silently shifted by the system's UTC offset during parsing and export.
  - On a UTC+1 system, `16:47:52 UTC` would be stored as `16:47:52+01:00` and exported as `15:47:52Z` — a 1-hour shift. This affected any investigator not running on a UTC system.
  - Root cause: `DateTime.TryParse` without `AssumeUniversal | AdjustToUniversal` flags treats ambiguous timestamps as local time.
  - Fixed in: `CsvRowHelpers.GetDateTime`, `Exporter.NormalizeDateTime`, `DateFilter.FilterRowsByDate`, and `ShellbagsParser`.
  - Added 12 automated timezone tests (unit, pipeline, and end-to-end) to prevent regression.

- **Artifact Discovery Failures**
  - Fixed partial-match logic in the discovery engine that caused artifacts to be silently skipped when only the filename or folder pattern matched (but not both).
  - Fixed 9 EZ Tools YAML config files where filename patterns had a leading underscore that prevented matching after KAPE timestamp prefix stripping (e.g., `_MFTECmd_$MFT_Output.csv` should have been `MFTECmd_$MFT_Output.csv`).
  - Affected artifacts: MFT, EventLogs, Deleted (Recycle Bin), Jumplists, Prefetch, LNK, Amcache, Registry, Shellbags.

- **Config Path Resolution**
  - Fixed a bug where the compiled binary could not find the `config/` directory when run from a working directory other than where the binary lives. Now uses `AppContext.BaseDirectory` for absolute path resolution.

---

### Platforms

Pre-built self-contained binaries (no .NET runtime required):
- Windows x64
- macOS ARM64 (Apple Silicon)
- Linux x64
