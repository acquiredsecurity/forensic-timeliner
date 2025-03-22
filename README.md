# Forensic Timeliner

Forensic Timeliner is a PowerShell-based tool that automates the process of aggregating and formatting forensic artifacts from [Chainsaw](https://github.com/WithSecureLabs/chainsaw) and KAPE / EZTools into a structured **MINI** **Master Timeline** in Excel. This is obviously not comprehensive but a great way to take some high value artifacts and get a real quick snapshot using powershell!

## Field Mappings by Artifact Module

<img width="1002" alt="image" src="https://github.com/user-attachments/assets/60ab3f12-ab54-4157-8f41-88eb43d9aaef" />
<img width="992" alt="image" src="https://github.com/user-attachments/assets/49023386-f4cc-4cfc-8915-cc31f7fc28d8" />
<img width="1002" alt="image" src="https://github.com/user-attachments/assets/1925e215-6fd8-46f6-b8a7-9ba23959f94a" />





This tool is designed for forensic analysts who need to quickly timeline and triage using output from Chainsaw mianly focused on event logs, MFT, RDP events, sigma rule and other forensic artifacts efficiently.

### Special Thanks
Incoming

---
sample commandline:
.\forensic_timeliner.ps1 -CsvDirectory "C:\chainsaw" -OutputFile "C:\chainsaw\Master_Timeline.xlsx"

-CsvDirectory  - the path to your kape and chainsaw output
-OutputFile - the path to save your timeline to

## Features
- Automatically combines all **Chainsaw CSV outputs** and into a single **Excel timeline**.
- **Normalizes timestamps** into a readable format (MM/DD/YYYY HH:MM:SS).
- Assigns an **artifact name** to each row for easy identification.
- Supports **color-coding** for different artifacts (see `color_macro.vbs` for details).
- Preserves **important metadata** like event IDs, source addresses, user information, and service details.
- Sorts the final timeline by **Date/Time**.

---


## Requirements
### Windows:
1. **PowerShell** (Version 5.1 or later)
2. **ImportExcel PowerShell Module** (for Excel support)
   ```powershell
   Install-Module ImportExcel -Force -Scope CurrentUser
3. Chainsaw (https://github.com/WithSecureLabs/chainsaw)
Optional:
Excel Macro for Color Coding:
The file color_macro.vbs can be used to apply color coding to each row based on the artifact type.

Color Coding (Excel)
The following artifact types are color-coded for better visibility: use the macro in this repo to apply the color coding schema. Macro only runs in excel in Windows machines!


