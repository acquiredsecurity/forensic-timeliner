param (
    [string]$CsvDirectory,        # Directory containing Chainsaw CSV files
    [string]$OutputFile,          # Output timeline file
    [ValidateSet("xlsx", "csv", "json")]
    [string]$ExportFormat = "csv",  # Format to export (xlsx, csv, or json)
    [string]$WebResultsPath,      # Path to webResults.csv
    [string]$KapeDirectory,       # Path to main KAPE timeline folder
    [switch]$Interactive,         # Launch interactive prompt
    [switch]$Help                 # Show help menu
)
# =============================================
# Help Menu
# =============================================

if ($Help) {
    Write-Host "" -ForegroundColor Cyan
    Write-Host "========================= Forensic Timeliner Help =========================" -ForegroundColor Cyan
    Write-Host "" 
    Write-Host "Description:" -ForegroundColor Yellow
    Write-Host "  This script builds a mini forensic timeline from Chainsaw, EZTools/KAPE,"
    Write-Host "  and optional web history CSVs. Use it after running KapeSaw.ps1 or stand-alone."
    Write-Host "" 
    Write-Host "Usage Examples:" -ForegroundColor Yellow
    Write-Host "  .\forensic_timeliner.ps1 -CsvDirectory 'C:\kape\chainsaw' -OutputFile 'C:\kape\timeline\Master_Timeline.csv'"
    Write-Host "  .\forensic_timeliner.ps1 -Interactive" 
    Write-Host "" 
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -CsvDirectory        Path to Chainsaw CSVs (default: C:\kape\chainsaw)"
    Write-Host "  -OutputFile          Path for final Excel file (default: C:\kape\timeline\Master_Timeline.csv)"
    Write-Host "  -WebResultsPath      Full Path to webResults.csv **Include file name** (default: C:\kape\browsinghistory\webResults.csv)"
    Write-Host "  -KapeDirectory       Root folder for Registry/FileSystem/EventLogs/etc (default: C:\kape\timeline)"
    Write-Host "  -Interactive         Launches local-friendly guided setup"
    Write-Host "  -Help                Display this help screen"
    Write-Host "" 
    exit 0
}

# =============================================
# Interactive Mode
# =============================================

    if ($Interactive) {
        Write-Host "" -ForegroundColor Cyan
        Write-Host "====== Forensic Timeliner Interactive Configuration ======" -ForegroundColor Cyan

        $CsvDirectory = Read-Host "Path to Chainsaw CSVs [Default: C:\kape\chainsaw]"
        if (-not $CsvDirectory) { $CsvDirectory = "C:\kape\chainsaw" }

        $OutputFile = Read-Host "Path to output CSV file [Default: C:\kape\timeline\Master_Timeline.csv]"
        if (-not $OutputFile) { $OutputFile = "C:\kape\timeline\Master_Timeline.csv" }

        $WebResultsPath = Read-Host "Path to webResults.csv [Default: C:\kape\browsinghistory\webResults.csv]"
        if (-not $WebResultsPath) { $WebResultsPath = "C:\kape\browsinghistory\webResults.csv" }

        $KapeDirectory = Read-Host "Path to KAPE timeline root [Default: C:\kape\timeline]"
        if (-not $KapeDirectory) { $KapeDirectory = "C:\kape\timeline" }

        Write-Host "Interactive configuration complete. Running timeline build..." -ForegroundColor Green

        $exportFormatPrompt = Read-Host "Select output format: xlsx, csv, or json [Default: csv]"
        if ($exportFormatPrompt -and $exportFormatPrompt -in @("xlsx", "csv", "json")) {
            $ExportFormat = $exportFormatPrompt
        } else {
            $ExportFormat = "csv"
}

    }


# =============================================
# SentinelOne Auto Mode
# =============================================
    $calledWithArgs = ($PSBoundParameters.Count -gt 0)
    $s1EnvDetected = $Env:S1_PACKAGE_DIR_PATH -and (Test-Path $Env:S1_PACKAGE_DIR_PATH)

    if (-not $calledWithArgs -and -not $s1EnvDetected -and -not $Interactive) {
        Write-Host "" -ForegroundColor Yellow
        Write-Warning "No parameters provided and not running in SentinelOne."
        Write-Host "Use -Interactive for guided setup or -Help for options."
        exit 1
    }
    # Default Fallbacks if Running in S1 or Param Partial
    if (-not $CsvDirectory) { $CsvDirectory = "C:\kape\chainsaw" }
    if (-not $OutputFile) { $OutputFile = "C:\kape\timeline\Master_Timeline.csv" }
    if (-not $WebResultsPath) { $WebResultsPath = "C:\kape\browsinghistory\webResults.csv" }
    if (-not $KapeDirectory) { $KapeDirectory = "C:\kape\timeline" }

# ============================================
# Adjust extension based on export format
# =============================================    
    $desiredExtension = "." + $ExportFormat.ToLower()
    $OutputFile = [System.IO.Path]::ChangeExtension($OutputFile, $desiredExtension)


# ASCII Art Banner

Write-Host @"
  ______     
 |  ____|                     (_)                
 | |__ ___  _ __ ___ _ __  ___ _  ___            
 |  __/ _ \| '__/ _ \ '_ \/ __| |/ __|           
 | | | (_) | | |  __/ | | \__ \ | (__            
 |_________|_|  \___|_| |_|___/_|\___|           
 |__   __(_)              | (_)                  
    | |   _ _ __ ___   ___| |_ _ __   ___ _ __   
    | |  | | '_ ` _ \ / _ \ | | '_ \ / _ \ '__|  
    | |  | | | | | | |  __/ | | | | |  __/ |     
    |_|  |_|_| |_| |_|\___|_|_|_| |_|\___|_|
                                                                                           
Mini Timeline Builder for Kape Output, Chainsaw +Sigma 
| Made by https://github.com/acquiredsecurity 
| with help from the robots [o_o] 
- Build a quick mini-timeline with Kape and Chainsaw run Rules and Sigma! Use my other script Kapesaw 
to collect your triage and integrate this Module as well!
Shoutouts:  
@EricZimmerman https://github.com/EricZimmerman  
WithSecure Countercept (@FranticTyping, @AlexKornitzer) For making Chainsaw, @ https://github.com/WithSecureLabs/chainsaw 
Happy Timelining!
"@ -ForegroundColor Cyan



# Ensure ImportExcel module is installed
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module ImportExcel -Force -Scope CurrentUser
}

# Load ImportExcel module
Import-Module ImportExcel

# Create an empty DataTable
$MasterTimeline = @()

# Scan directory for CSV files
$CsvFiles = Get-ChildItem -Path $CsvDirectory -Recurse | Where-Object { $_.Extension -eq ".csv" -and $_.Name -ne "webResults.csv" }

foreach ($CsvFile in $CsvFiles) {
    Write-Host "Processing - Chainsaw Data: $($CsvFile.Name)"
    $ArtifactName = $CsvFile.BaseName
    $Data = Import-Csv -Path $CsvFile.FullName

    # Normalize fields based on artifact type
    $Data = $Data | ForEach-Object {
        $OrderedObject = [ordered]@{}

        # Format Date/Time field
        $OrderedObject["Date/Time"] = if ($ArtifactName -match "mft") {
            if ($_.PSObject.Properties.Name -contains "FileNameCreated0x30" -and $_."FileNameCreated0x30" -match "(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})") {
                "{0:yyyy/MM/dd HH:mm:ss}" -f (Get-Date "$($matches[1]) $($matches[2])")
            } else { "" }
        } elseif ($_.PSObject.Properties.Name -contains "timestamp" -and $_.timestamp -match "(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})") {
            "{0:yyyy/MM/dd HH:mm:ss}" -f (Get-Date "$($matches[1]) $($matches[2])")
        } else { "" }

        $OrderedObject["Artifact Name"] = $ArtifactName
        $OrderedObject["Event ID"] = $_."Event ID"
        $OrderedObject["Channel"] = if ($_.PSObject.Properties.Name -contains "Channel") { $_."Channel" } else { $_."Event.System.Provider" }
		$OrderedObject["Detections"] = $_."detections"
        $OrderedObject["Data Path"] = if ($_.PSObject.Properties.Name -contains "Scheduled Task Name" -and $_."Scheduled Task Name" -ne "") { $_."Scheduled Task Name" } elseif ($_.PSObject.Properties.Name -contains "Threat Path" -and $_."Threat Path" -ne "") { $_."Threat Path" } elseif ($_.PSObject.Properties.Name -contains "Information" -and $_."Information" -ne "") { $_."Information" } elseif ($_.PSObject.Properties.Name -contains "HostApplication" -and $_."HostApplication" -ne "") { $_."HostApplication" } elseif ($_.PSObject.Properties.Name -contains "Service File Name" -and $_."Service File Name" -ne "") { $_."Service File Name" } elseif ($_.PSObject.Properties.Name -contains "Event Data" -and $_."Event Data" -ne "") { $_."Event Data" } else { "" }
        $OrderedObject["Data Details"] = if ($_.PSObject.Properties.Name -contains "Threat Name" -and $_."Threat Name" -ne "") { $_."Threat Name" } elseif ($_.PSObject.Properties.Name -contains "Service Name" -and $_."Service Name" -ne "") { $_."Service Name" } else { "" }
        $OrderedObject["User"] = if ($_.PSObject.Properties.Name -contains "User Name") { $_."User Name" } else { $_."User" }
		$OrderedObject["Computer"] = $_."Computer"
        $OrderedObject["User SID"] = $_."User SID"
		$OrderedObject["Member SID"] = $_."Member SID"
        $OrderedObject["Process Name"] = $_."Process Name"
        $OrderedObject["IP Address"] = $_."IP Address"
        $OrderedObject["Logon Type"] = $_."Logon Type"
		$OrderedObject["Count"] = $_."count"
        $OrderedObject["Source Address"] = $_."Source Address"
        $OrderedObject["Destination Address"] = $_."Dest Address"
        $OrderedObject["Service Type"] = $_."Service Type"
        $OrderedObject["CommandLine"] = $_."CommandLine"
        $OrderedObject["SHA1"] = $_."SHA1"	
        $OrderedObject["Evidence Path"] = $_."path"

        [PSCustomObject]$OrderedObject
    }

    # Append to Master Timeline
    $MasterTimeline += $Data
}

# Process webResults.csv separately
if (Test-Path $WebResultsPath) {
    Write-Host "Processing - WebHistory View Data: Output WebResults.csv"
    $WebResults = Import-Csv -Path $WebResultsPath

    $WebResults = $WebResults | ForEach-Object {
        $WebFormattedDate = try {
            [datetime]::Parse($_."Visit Time").ToString("yyyy/MM/dd HH:mm:ss")
        } catch {
            $_."Visit Time"
        }
        [PSCustomObject]@{
            "Date/Time"     = $WebFormattedDate
            "Artifact Name" = "Web History"
            "User"          = $_."User Profile"  # Mapping User Profile to User
            "Data Path"     = $_."URL"
            "Data Details"  = $_."Title"
            "Visit Count"   = $_."Visit Count"
            "Visit Type"    = $_."Visit Type"
            "Web Browser"   = $_."Web Browser"
        }
    }

    $MasterTimeline += $WebResults
}

# Process Registry artifacts from KAPE if the folder exists
$RegistryPath = "$KapeDirectory\Registry"
if (Test-Path $RegistryPath) {
    $RegistryFiles = Get-ChildItem -Path $RegistryPath -Filter "*_RECmd_Batch_Kroll_Batch_Output.csv" | Where-Object { -not $_.PSIsContainer }

    foreach ($RegistryFile in $RegistryFiles) {
        Write-Host "Processing - Kape: Batch Registry Data"
        $RegistryData = Import-Csv -Path $RegistryFile.FullName

        $RegistryData = $RegistryData | ForEach-Object {
            $OrderedObject = [ordered]@{}

            $RegistryFormattedDate = try {
                [datetime]::Parse($_."LastWriteTimestamp").ToString("yyyy/MM/dd HH:mm:ss")
            } catch {
                $_."LastWriteTimestamp"
            }

            $OrderedObject["Date/Time"] = $RegistryFormattedDate
            $OrderedObject["Artifact Name"] = "Registry Update"
            $OrderedObject["Data Path"] = $_."ValueData"
            $OrderedObject["Data Details"] = $_."Description"
            $OrderedObject["Event ID"] = $_."HiveType"
            $OrderedObject["Channel"] = $_."Description"
            $OrderedObject["Detections"] = $_."Category"

            $OrderedObject["Evidence Path"] = $_."HivePath"

            [PSCustomObject]$OrderedObject
        }

        $MasterTimeline += $RegistryData
    }
}


# Process File Deletion artifacts from KAPE
$FileDeletionFiles = Get-ChildItem -Path $KapeDirectory -Recurse | Where-Object { $_.Extension -eq ".csv" -and $_.Name -match "RBCmd" }

foreach ($FileDeletionFile in $FileDeletionFiles) {
    Write-Host "Processing - Kape: File Deletion Data"
    $FileDeletionData = Import-Csv -Path $FileDeletionFile.FullName

    $FileDeletionData = $FileDeletionData | ForEach-Object {
        $OrderedObject = [ordered]@{}

        $OrderedObject["Date/Time"] = $_."DeletedOn"
        $OrderedObject["Artifact Name"] = "File Deletion"
        $OrderedObject["Data Path"] = $_."FileName"
        $OrderedObject["Data Details"] = $_."FileSize"

        [PSCustomObject]$OrderedObject
    }

    $MasterTimeline += $FileDeletionData
}

# Process Amcache artifacts from KAPE if the folder exists
$AmCachePath = "$KapeDirectory\ProgramExecution"

if (Test-Path $AmCachePath) {
    $AmcacheFiles = Get-ChildItem -Path $AmCachePath -Filter "*_Amcache_AssociatedFileEntries.csv" | Where-Object { -not $_.PSIsContainer }

    # Check if any files were found
    if ($AmcacheFiles.Count -eq 0) {
        Write-Host "No Amcache files found in $AmCachePath. Skipping..." -ForegroundColor Yellow
    } else {
        foreach ($AmCacheFile in $AmcacheFiles) {
            Write-Host "Processing - Kape: Amcache Data"

            # Ensure file exists before attempting to import
            if (Test-Path $AmCacheFile.FullName) {
                $AmcacheData = Import-Csv -Path $AmCacheFile.FullName

                # Check if the file contains data
                if ($AmcacheData.Count -eq 0) {
                    Write-Host "Warning: No data found in $($AmCacheFile.Name). Skipping..." -ForegroundColor Red
                    continue
                }

                $AmcacheData = $AmcacheData | ForEach-Object {
                    $OrderedObject = [ordered]@{}
                
                    $AmcacheFormattedDate = try {
                        [datetime]::Parse($_."FileKeyLastWriteTimestamp").ToString("yyyy/MM/dd HH:mm:ss")
                    } catch {
                        $_."FileKeyLastWriteTimestamp"
                    }        
                    $OrderedObject["Date/Time"] = $AmcacheFormattedDate
                    $OrderedObject["Artifact Name"] = "Program Execution - Amcache"
                    $OrderedObject["Data Path"] = $_."FullPath"
                    $OrderedObject["Data Details"] = $_."Name"
                    $OrderedObject["SHA1"] = $_."SHA1"

                    [PSCustomObject]$OrderedObject
                }

                # Append data to Master Timeline
                $MasterTimeline += $AmcacheData
            } else {
                Write-Host "Error: File not found - $($AmCacheFile.FullName). Skipping..." -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "Amcache directory not found: $AmCachePath. Skipping..." -ForegroundColor Yellow
}


# Process LNK Files from KAPE if the folder exists
$LNKFilePath = "$KapeDirectory\FileFolderAccess"

if (Test-Path $LNKFilePath) {
    $LNKFiles = Get-ChildItem -Path $LNKFilePath -Filter "*_LECmd_Output.csv" | Where-Object { -not $_.PSIsContainer }

    # Check if any files were found
    if ($LNKFiles.Count -eq 0) {
        Write-Host "No LNK files found in $LNKFilePath. Skipping..." -ForegroundColor Yellow
    } else {
        foreach ($LNKFile in $LNKFiles) {
            Write-Host "Processing - Kape: LNK Target Created Data"

            # Ensure file exists before attempting to import
            if (Test-Path $LNKFile.FullName) {
                $LNKData = Import-Csv -Path $LNKFile.FullName

                # Check if the file contains data
                if ($LNKData.Count -eq 0) {
                    Write-Host "Warning: No data found in $($LNKFile.Name). Skipping..." -ForegroundColor Red
                    continue
                }

                $LNKData = $LNKData | ForEach-Object {
                    $OrderedObject = [ordered]@{}

                    $OrderedObject["Date/Time"] = $_."TargetCreated"
                    $OrderedObject["Artifact Name"] = "LNK Files"
                    $OrderedObject["Data Path"] = $_."LocalPath"

                    [PSCustomObject]$OrderedObject
                }

                # Append data to Master Timeline
                $MasterTimeline += $LNKData
            } else {
                Write-Host "Error: File not found - $($LNKFile.FullName). Skipping..." -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "LNK directory not found: $LNKFilePath. Skipping..." -ForegroundColor Yellow
}

# Process Shellbags artifacts from KAPE if the folder exists
$ShellbagsPath = "$KapeDirectory\FileFolderAccess"

if (Test-Path $ShellbagsPath) {
    $ShellbagsFiles = Get-ChildItem -Path $ShellbagsPath -Filter "*_UsrClass.csv" | Where-Object { -not $_.PSIsContainer }

    # Check if any Shellbags files were found
    if ($ShellbagsFiles.Count -eq 0) {
        Write-Host "No Shellbags (UsrClass) files found in $ShellbagsPath. Skipping..." -ForegroundColor Yellow
    } else {
        foreach ($ShellbagFile in $ShellbagsFiles) {
            Write-Host "Processing - Kape: Shellbag Data"

            # Ensure file exists before attempting to import
            if (Test-Path $ShellbagFile.FullName) {
                $ShellbagData = Import-Csv -Path $ShellbagFile.FullName

                # Check if the file contains data
                if ($ShellbagData.Count -eq 0) {
                    Write-Host "Warning: No data found in $($ShellbagFile.Name). Skipping..." -ForegroundColor Red
                    continue
                }

                $ShellbagData = $ShellbagData | ForEach-Object {
                    $OrderedObject = [ordered]@{}

                    $OrderedObject["Date/Time"] = $_."LastWriteTime"
                    $OrderedObject["Artifact Name"] = "File/Folder Access - Shellbags"
                    $OrderedObject["Data Path"] = $_."AbsolutePath"
                    $OrderedObject["Data Details"] = $_."Value"

                    [PSCustomObject]$OrderedObject
                }

                # Append data to Master Timeline
                $MasterTimeline += $ShellbagData
            } else {
                Write-Host "Error: File not found - $($ShellbagFile.FullName). Skipping..." -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "Shellbags directory not found: $ShellbagsPath. Skipping..." -ForegroundColor Yellow
}

# Process MFT artifacts for executables & archives in C:\Users, and C:\tmp
$MFTFilePath = "$KapeDirectory\FileSystem"

if (Test-Path $MFTFilePath) {
    $MFTFiles = Get-ChildItem -Path $MFTFilePath -Filter "*MFT_Out*.csv" | Where-Object { -not $_.PSIsContainer }


    if ($MFTFiles.Count -eq 0) {
        Write-Host "No MFT output files found. Skipping..." -ForegroundColor Yellow
    } else {
        # Define watchlist extensions (you can expand this)
        $ExtensionWatchlist = @(
            ".exe", ".dll", ".zip", ".rar", ".7z", ".ps1", ".cmd", ".bat", ".js"
            # ".docx", ".pdf", ".xlsx", ".csv", "  ## Uncomment to include more file extensions or add your own!
        )

        foreach ($MFT in $MFTFiles) {
            Write-Host "Processing - Kape: MFT File Data"

            if (Test-Path $MFT.FullName) {
                $MFTData = Import-Csv -Path $MFT.FullName

                $MFTFilteredData = $MFTData | Where-Object {
					($_.Extension -match "^\.(zip|7z|rar|exe|dll)$") -and
					($_.ParentPath -like "*\Users\*" -or $_.ParentPath -like "*\tmp\*") ## add more folders -or $_.ParentPath -like "*\temp\*
				} | ForEach-Object {
					$MFTformattedDate = try {
						[datetime]::Parse($_."Created0x10").ToString("yyyy/MM/dd HH:mm:ss")
					} catch {
						$_."Created0x10"
					}

					[PSCustomObject]@{
						"Date/Time"     = $MFTformattedDate
						"Artifact Name" = "MFT - Created" 
						"Data Path"     = $_."ParentPath"
						"Data Details"  = $_."FileName"
					}
				}

				
				

                if ($MFTFilteredData.Count -eq 0) {
                    Write-Host "No matching executables or archives found in $($MFT.Name). Skipping..." -ForegroundColor Yellow
                } else {
                    $MasterTimeline += $MFTFilteredData
                    Write-Host "Added $($MFTFilteredData.Count) entries from $($MFT.Name) to Master Timeline." -ForegroundColor Green
                }
            } else {
                Write-Host "Error: File not found - $($MFT.FullName). Skipping..." -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "MFT directory not found: $MFTFilePath. Skipping..." -ForegroundColor Yellow
}

# Process EVTX artifacts for Timeline
$EVTFilePath = "$KapeDirectory\EventLogs"

# Define filtering criteria per channel
$EventChannelFilters = @{
    "Application" = @(1000, 1001)
    "Microsoft-Windows-PowerShell/Operational" = @(4100, 4103, 4104)
    "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational" = @(72, 98, 104, 131, 140)
    "Microsoft-Windows-Sysmon/Operational" = @()
    "Microsoft-Windows-TaskScheduler/Operational" = @(106, 140, 141, 129, 200, 201)
    "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" = @(261, 1149)
    "Microsoft-Windows-WinRM/Operational" = @(169)
    "Security" = @(1102, 4624, 4625, 4648, 4698, 4702, 4720, 4722, 4723, 4724, 4725, 4726, 4732, 4756)
    "SentinelOne/Firewall" = @()
    "SentinelOne/Operational" = @()
    "System" = @(7045)
    "Windows-PowerShell/Operational" = @(400, 403, 600)
}

if (Test-Path $EVTFilePath) {
    $EVTFiles = Get-ChildItem -Path $EVTFilePath -Filter "*EvtxECmd*.csv" | Where-Object { -not $_.PSIsContainer }

    foreach ($EVT in $EVTFiles) {
        Write-Host "Processing - Kape: EVT File Data"

        if (Test-Path $EVT.FullName) {
            $EVTData = Import-Csv -Path $EVT.FullName

            $EVTFilteredData = $EVTData | Where-Object {
                $channel = $_.Channel
                $eventId = [int]$_.EventId

                if ($EventChannelFilters.ContainsKey($channel)) {
                    $allowedIDs = $EventChannelFilters[$channel]
                    ($allowedIDs.Count -eq 0) -or ($allowedIDs -contains $eventId)
                } else {
                    $false
                }
            } | ForEach-Object {
                $EVTformattedDate = try {
                    [datetime]::Parse($_."TimeCreated").ToString("yyyy/MM/dd HH:mm:ss")
                } catch {
                    $_."TimeCreated"
                }

                [PSCustomObject]@{
                    "Date/Time"     = $EVTformattedDate
                    "Artifact Name" = "Event Logs"
                    "Event Id"      = $_."EventId"
                    "Detections"     = $_."MapDescription"
                    "Data Path"     = $_."PayloadData1"
                    "Data Details"  = $_."PayloadData2"
                    "Computer"      = $_."Computer"
                    "Channel"       = $_."Channel"
                    "Evidence Path" = $_."SourceFile"
                }
            }

            if ($EVTFilteredData.Count -eq 0) {
                Write-Host "No matching Event IDs found in $($EVT.Name). Skipping..." -ForegroundColor Yellow
            } else {
                $MasterTimeline += $EVTFilteredData
                Write-Host "Added $($EVTFilteredData.Count) entries from $($EVT.Name) to Master Timeline." -ForegroundColor Green
            }
        } else {
            Write-Host "Error: File not found - $($EVT.FullName). Skipping..." -ForegroundColor Red
        }
    }
} else {
    Write-Host "Event Log directory not found: $EVTFilePath. Skipping..." -ForegroundColor Yellow
}

# =============================================
# Export Data Formatting
# =============================================


switch ($ExportFormat) {
    "xlsx" {
        # Default: Excel Export
        $MaxRowsPerSheet = 1000000
        $TotalRows = $MasterTimeline.Count
        $SheetNumber = 1

        if ($TotalRows -le $MaxRowsPerSheet) {
            $MasterTimeline | Export-Excel -Path $OutputFile -WorksheetName "Timeline_1" -AutoSize -BoldTopRow -FreezeTopRow -TableName "MasterTimeline"
        } else {
            Write-Host "Master Timeline exceeds $MaxRowsPerSheet rows. Splitting into multiple sheets..."
            
            for ($i = 0; $i -lt $TotalRows; $i += $MaxRowsPerSheet) {
                $SheetData = $MasterTimeline[$i..($i + $MaxRowsPerSheet - 1)]
                $SheetName = "Timeline_$SheetNumber"

                $SheetData | Export-Excel -Path $OutputFile -WorksheetName $SheetName -AutoSize -BoldTopRow -FreezeTopRow -TableName "MasterTimeline" -Append
                Write-Host "Saved $SheetName with $($SheetData.Count) rows."
                $SheetNumber++
            }
        }

        # Optional: adjust column widths
        $excelPackage = Open-ExcelPackage -Path $OutputFile
        foreach ($sheet in $excelPackage.Workbook.Worksheets) {
            $usedRange = $sheet.Dimension.Address
            if ($usedRange) {
                $maxColumn = $sheet.Dimension.End.Column
                for ($col = 1; $col -le $maxColumn; $col++) {
                    $sheet.Column($col).Width = 30
                }
            }
        }
        Close-ExcelPackage $excelPackage

        Write-Host "Excel export complete. Fields set to width 30." -ForegroundColor Green
    }

    "csv" {
        $MasterTimeline | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        Write-Host "CSV export complete: $OutputFile" -ForegroundColor Green
    }

    "json" {
        $MasterTimeline | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "JSON export complete: $OutputFile" -ForegroundColor Green
    }
}

Write-Host "Master Timeline exported successfully to $OutputFile as $ExportFormat." -ForegroundColor Cyan
