# Parameter Block
param (
    [string]$KapeDirectory = "C:\kape\timeline",              # Path to main KAPE timeline folder
    [string]$WebResultsPath = "C:\kape\browsinghistory\webResults.csv", # Path to webResults.csv
    [string]$ChainsawDirectory = "C:\kape\chainsaw",          # Directory containing Chainsaw CSV files
    [string]$OutputFile = "C:\kape\timeline\Master_Timeline.csv", # Output timeline file
    [ValidateSet("xlsx", "csv", "json")]
    [string]$ExportFormat = "csv",                            # Default to CSV for cloud ingestion
    [string]$RegistrySubDir = "Registry",                     # Registry subdirectory under KapeDirectory
    [string]$ProgramExecSubDir = "ProgramExecution",          # Program execution subdirectory
    [string]$FileFolderSubDir = "FileFolderAccess",           # File/Folder access subdirectory
    [string]$FileSystemSubDir = "FileSystem",                 # FileSystem subdirectory
    [string]$EventLogsSubDir = "EventLogs",                   # Event logs subdirectory
    [int]$BatchSize = 10000,                                  # Batch size for processing large files
    [datetime]$StartDate,                                     # Start date for filtering (inclusive)
    [datetime]$EndDate,                                       # End date for filtering (inclusive)
    [switch]$Deduplicate,                                     # Enable deduplication of timeline entries
    [switch]$Interactive,                                     # Launch interactive prompt
    [switch]$Help                                             # Show help menu
)

# Progress Reporting Function
function Show-ProcessingProgress {
    param (
        [string]$Activity,
        [string]$Status,
        [int]$Current,
        [int]$Total,
        [int]$NestedLevel = 0
    )
    
    $percentComplete = 0
    if ($Total -gt 0) {
        $percentComplete = [math]::Min(100, [math]::Round(($Current / $Total) * 100))
    }
    
    if ($NestedLevel -eq 0) {
        # Main progress bar
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $percentComplete -CurrentOperation "$Current of $Total ($percentComplete%)"
    }
    else {
        # Nested progress bar
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $percentComplete -CurrentOperation "$Current of $Total ($percentComplete%)" -Id $NestedLevel
    }
}

# Counter for tracking overall progress
$script:totalSources = 0
$script:processedSources = 0

# Function to update overall progress
function Update-OverallProgress {
    param (
        [string]$CurrentSource
    )
    $script:processedSources++
    $overallPercent = [math]::Min(100, [math]::Round(($script:processedSources / $script:totalSources) * 100))
    Write-Progress -Activity "Building Forensic Timeline" -Status "Processing $CurrentSource" -PercentComplete $overallPercent -Id 0
}

# Help menu
if ($Help) {
    Write-Host "" -ForegroundColor Cyan
    Write-Host "========================= Forensic Timeliner Help =========================" -ForegroundColor Cyan
    Write-Host "" 
    Write-Host "Description:" -ForegroundColor Yellow
    Write-Host "  This script builds a mini forensic timeline from Chainsaw, EZTools/KAPE,"
    Write-Host "  and optional web history CSVs. Use it after running KapeSaw.ps1 or stand-alone."
    Write-Host "" 
    Write-Host "Usage Examples:" -ForegroundColor Yellow
    Write-Host "  .\forensic_timeliner.ps1 -ChainsawDirectory 'C:\kape\chainsaw' -OutputFile 'C:\kape\timeline\Master_Timeline.csv'"
    Write-Host "  .\forensic_timeliner.ps1 -Interactive" 
    Write-Host "" 
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -KapeDirectory       Root folder for Registry/FileSystem/EventLogs/etc (default: C:\kape\timeline)"
    Write-Host "  -ChainsawDirectory   Path to Chainsaw CSVs (default: C:\kape\chainsaw)"
    Write-Host "  -WebResultsPath      Full Path to webResults.csv **Include file name** (default: C:\kape\browsinghistory\webResults.csv)"
    Write-Host "  -RegistrySubDir      Registry subdirectory under KapeDirectory (default: Registry)"
    Write-Host "  -ProgramExecSubDir   Program execution subdirectory under KapeDirectory (default: ProgramExecution)"
    Write-Host "  -FileFolderSubDir    File/Folder access subdirectory under KapeDirectory (default: FileFolderAccess)"
    Write-Host "  -FileSystemSubDir    FileSystem subdirectory under KapeDirectory (default: FileSystem)"
    Write-Host "  -EventLogsSubDir     Event logs subdirectory under KapeDirectory (default: EventLogs)"
    Write-Host "  -OutputFile          Path for final Excel file (default: C:\kape\timeline\Master_Timeline.csv)"
    Write-Host "  -BatchSize           Number of records to process at once for large files (default: 10,000)"
    Write-Host "  -Interactive         Launches local-friendly guided setup"
    Write-Host "  -Help                Display this help screen"
    Write-Host "" 
    exit 0
}

# Interactive Mode
if ($Interactive) {
    Write-Host "" -ForegroundColor Cyan
    Write-Host "====== Forensic Timeliner Interactive Configuration ======" -ForegroundColor Cyan

    # Ask for export format first
    $exportFormatPrompt = Read-Host "Select output format: xlsx, csv, or json [Default: csv]"
    if ($exportFormatPrompt -and $exportFormatPrompt -in @("xlsx", "csv", "json")) {
        $ExportFormat = $exportFormatPrompt
    } else {
        $ExportFormat = "csv"
    }
    
    # Set default extension based on selected format
    $fileExtension = ".$ExportFormat"
    $defaultOutputPath = "C:\kape\timeline\Master_Timeline$fileExtension"
    
    $KapeDirectory = Read-Host "Path to KAPE Processed CSV Files [Default: C:\kape\timeline]"
    if (-not $KapeDirectory) { $KapeDirectory = "C:\kape\timeline" }

    $ChainsawDirectory = Read-Host "Path to Chainsaw CSVs [Default: C:\kape\chainsaw]"
    if (-not $ChainsawDirectory) { $ChainsawDirectory = "C:\kape\chainsaw" }

    $WebResultsPath = Read-Host "Path to BrowsingHistoryView output file webResults.csv [Default: C:\kape\browsinghistory\webResults.csv]"
    if (-not $WebResultsPath) { 
        $WebResultsPath = "C:\kape\browsinghistory\webResults.csv" 
    }
    
    # Validate the web history path to ensure it includes a filename
    if (-not [string]::IsNullOrEmpty($WebResultsPath) -and (Test-Path $WebResultsPath -PathType Container)) {
        # If user entered a directory, append the default filename
        $WebResultsPath = Join-Path $WebResultsPath "webResults.csv"
        Write-Host "  Note: Directory path detected. Using file: $WebResultsPath" -ForegroundColor Yellow
    }
    
    $OutputFile = Read-Host "Path to Forensic Timeline output file [Default: $defaultOutputPath]"
    if (-not $OutputFile) { $OutputFile = $defaultOutputPath }
    
    # Ensure the output file has the correct extension
    if (-not $OutputFile.EndsWith($fileExtension)) {
        $OutputFile = [System.IO.Path]::ChangeExtension($OutputFile, $fileExtension.TrimStart('.'))
    }

    # Advanced directory configuration (optional)
    $configureSubDirs = Read-Host "Configure subdirectories? This script expects you will be using standard kape !SansTriage output with EZParsers.. (y/n) [Default: n]"
    if ($configureSubDirs -eq "y") {
        $RegistrySubDir = Read-Host "Registry subdirectory [Default: Registry]"
        if (-not $RegistrySubDir) { $RegistrySubDir = "Registry" }
        
        $ProgramExecSubDir = Read-Host "Program execution subdirectory [Default: ProgramExecution]"
        if (-not $ProgramExecSubDir) { $ProgramExecSubDir = "ProgramExecution" }
        
        $FileFolderSubDir = Read-Host "File/Folder access subdirectory [Default: FileFolderAccess]"
        if (-not $FileFolderSubDir) { $FileFolderSubDir = "FileFolderAccess" }
        
        $FileSystemSubDir = Read-Host "FileSystem subdirectory [Default: FileSystem]"
        if (-not $FileSystemSubDir) { $FileSystemSubDir = "FileSystem" }
        
        $EventLogsSubDir = Read-Host "Event logs subdirectory [Default: EventLogs]"
        if (-not $EventLogsSubDir) { $EventLogsSubDir = "EventLogs" }
    } else {
        $RegistrySubDir = "Registry"
        $ProgramExecSubDir = "ProgramExecution"
        $FileFolderSubDir = "FileFolderAccess"
        $FileSystemSubDir = "FileSystem"
        $EventLogsSubDir = "EventLogs"
    }
    
    $batchSizeInput = Read-Host "Batch size for processing large files [Default: 10,000]"
    if ($batchSizeInput -match '^\d+$') {
        $BatchSize = [int]$batchSizeInput
    }
    
    # Ask for deduplication
    $deduplicateInput = Read-Host "Enable deduplication of timeline entries? (y/n) [Default: n]"
    if ($deduplicateInput -eq "y") {
        $Deduplicate = $true
    } else {
        $Deduplicate = $false
    }
    
    # Ask for date filtering
    $dateFilterInput = Read-Host "Apply date range filtering? (y/n) [Default: n]"
    if ($dateFilterInput -eq "y") {
        $startDateInput = Read-Host "Enter start date (yyyy-MM-dd) [Leave blank for no start date]"
        if (-not [string]::IsNullOrWhiteSpace($startDateInput)) {
            try {
                $StartDate = [datetime]::ParseExact($startDateInput, "yyyy-MM-dd", $null)
                Write-Host "  Start date set to: $($StartDate.ToString('yyyy-MM-dd'))" -ForegroundColor Green
            } catch {
                Write-Host "  Invalid date format. Start date not set." -ForegroundColor Yellow
            }
        }
        
        $endDateInput = Read-Host "Enter end date (yyyy-MM-dd) [Leave blank for no end date]"
        if (-not [string]::IsNullOrWhiteSpace($endDateInput)) {
            try {
                $EndDate = [datetime]::ParseExact($endDateInput, "yyyy-MM-dd", $null)
                Write-Host "  End date set to: $($EndDate.ToString('yyyy-MM-dd'))" -ForegroundColor Green
            } catch {
                Write-Host "  Invalid date format. End date not set." -ForegroundColor Yellow
            }
        }
        
        # Validate date range if both dates are set
        if ($StartDate -and $EndDate -and ($StartDate -gt $EndDate)) {
            Write-Host "  Warning: Start date is after end date. Swapping dates." -ForegroundColor Yellow
            $tempDate = $StartDate
            $StartDate = $EndDate
            $EndDate = $tempDate
        }
    }

    Write-Host "Interactive configuration complete. Running timeline build..." -ForegroundColor Green
}

# SentinelOne Auto Mode - Identifies if running by SentinelOne remote ops
$calledWithArgs = ($PSBoundParameters.Count -gt 0)
$s1EnvDetected = $Env:S1_PACKAGE_DIR_PATH -and (Test-Path $Env:S1_PACKAGE_DIR_PATH)

if (-not $calledWithArgs -and -not $s1EnvDetected -and -not $Interactive) {
    Write-Host "" -ForegroundColor Yellow
    Write-Warning "No parameters provided and not running in SentinelOne."
    Write-Host "Use -Interactive for guided setup or -Help for options."
    exit 1
}

# Default Fallbacks if Running in S1 or Param Partial
if (-not $ChainsawDirectory) { $ChainsawDirectory = "C:\kape\chainsaw" }
if (-not $OutputFile) { $OutputFile = "C:\kape\timeline\Master_Timeline.csv" }
if (-not $WebResultsPath) { $WebResultsPath = "C:\kape\browsinghistory\webResults.csv" }
if (-not $KapeDirectory) { $KapeDirectory = "C:\kape\timeline" }

# Adjust extension based on export format
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

# Initialize the MasterTimeline array
$MasterTimeline = @()

# Ensure ImportExcel module is installed if needed
if ($ExportFormat -eq "xlsx" -and -not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "Installing ImportExcel module..." -ForegroundColor Yellow
    Install-Module ImportExcel -Force -Scope CurrentUser
}

# Load ImportExcel module if needed
if ($ExportFormat -eq "xlsx") {
    Import-Module ImportExcel
}

# Standard field order
$StandardFields = @(
    "DateTime", "ArtifactName", "EventID", "Channel", "Detections", "DataPath", "DataDetails",
    "User", "Computer", "FileSize", "FileExtension", "UserSID", "MemberSID", "ProcessName", "IPAddress", "LogonType", "Count",
    "SourceAddress", "DestinationAddress", "ServiceType", "ShellType", "CommandLine", "SHA1", "EvidencePath",
    "VisitCount", "VisitFrom", "VisitType", "WebBrowser"
)

# Define preferred field order for output
$PreferredFieldOrder = @(
    "DateTime", 
    "ArtifactName",
    "EventID",
    "Channel", 
    "User",
    "Computer",
    "DataPath", 
    "DataDetails",
    "CommandLine",
    "ProcessName",
    "Detections",
    "FileSize",
    "FileExtension",
    "IPAddress", 
    "SourceAddress",
    "DestinationAddress",
    "LogonType",
    "UserSID", 
    "MemberSID",
    "ServiceType", 
    "ShellType",
    "SHA1", 
    "EvidencePath",
    "VisitCount", 
    "VisitFrom", 
    "VisitType", 
    "WebBrowser",
    "Count"
)

# Function to normalize row data
function Normalize-Row {
    param (
        [hashtable]$Fields,
        [string]$ArtifactName = "Generic"
    )
    $row = @{}
    foreach ($key in $StandardFields) {
        $row[$key] = $Fields[$key]
    }
    $row["ArtifactName"] = $ArtifactName
    return [PSCustomObject]$row
}

# Function to process event log batches
function Process-EventLogBatch {
    param (
        [string]$HeaderLine,
        [System.Collections.ArrayList]$DataLines,
        [hashtable]$HeaderMap
    )
    
    # Create temp file for Import-Csv
    $tempFile = [System.IO.Path]::GetTempFileName()
    
    try {
        # Write header and data to temp file
        $HeaderLine | Out-File -FilePath $tempFile -Encoding utf8
        $DataLines | Out-File -FilePath $tempFile -Encoding utf8 -Append
        
        # Import and filter
        $batchData = Import-Csv $tempFile
        $filtered = $batchData | Where-Object {
            $channel = $_.Channel
            $eventId = [int]$_.EventId
            if ($EventChannelFilters.ContainsKey($channel)) {
                $allowed = $EventChannelFilters[$channel]
                ($allowed.Count -eq 0) -or ($allowed -contains $eventId)
            } else {
                $false
            }
        }
        
        # Process filtered entries
        $results = @()
        foreach ($entry in $filtered) {
            $dt = try { [datetime]::Parse($entry.TimeCreated).ToString("yyyy/MM/dd HH:mm:ss") } catch { $entry.TimeCreated }
            $row = @{
                DateTime       = $dt
                EventID        = $entry."EventId"
                Channel        = $entry."Channel"
                Detections     = $entry."MapDescription"
                DataPath       = $entry."PayloadData1"
                DataDetails    = $entry."PayloadData2"
                Computer       = $entry."Computer"
                EvidencePath   = $entry."SourceFile"
            }
            $results += Normalize-Row -Fields $row -ArtifactName "EventLogs"
        }
        
        return $results
    }
    finally {
        # Clean up temp file
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }
}

# Count the number of sources to process for overall progress tracking
$script:totalSources = 0

# Check Amcache
$AmCachePath = Join-Path $KapeDirectory $ProgramExecSubDir
if (Test-Path $AmCachePath) {
    $AmcacheFiles = @(Get-ChildItem -Path $AmCachePath -Filter "*_Amcache_AssociatedFileEntries.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $AmcacheFiles.Count
}

# Check Event Logs
$EVTPath = Join-Path $KapeDirectory $EventLogsSubDir
if (Test-Path $EVTPath) {
    $evtFiles = @(Get-ChildItem $EVTPath -Filter "*EvtxECmd*.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $evtFiles.Count
}

# Check File Deletion
$FileDeletionFiles = @(Get-ChildItem -Path $KapeDirectory -Recurse -Filter "*RBCmd*.csv" -ErrorAction SilentlyContinue)
$script:totalSources += $FileDeletionFiles.Count

# Check LNK Files
$lnkPath = Join-Path $KapeDirectory $FileFolderSubDir
if (Test-Path $lnkPath) {
    $lnkFiles = @(Get-ChildItem $lnkPath -Filter "*_LECmd_Output.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $lnkFiles.Count
}

# Check MFT Files
$MFTPath = Join-Path $KapeDirectory $FileSystemSubDir
if (Test-Path $MFTPath) {
    $mftFiles = @(Get-ChildItem $MFTPath -Filter "*MFT_Out*.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $mftFiles.Count
}

# Check Prefetch Files
$PECmdPath = Join-Path $KapeDirectory $ProgramExecSubDir
if (Test-Path $PECmdPath) {
    $PECmdFiles = @(Get-ChildItem -Path $PECmdPath -Filter "*_PECmd_Output.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $PECmdFiles.Count
}

# Check Registry
$RegistryPath = Join-Path $KapeDirectory $RegistrySubDir
if (Test-Path $RegistryPath) {
    $RegistryFiles = @(Get-ChildItem -Path $RegistryPath -Filter "*_RECmd_Batch_Kroll_Batch_Output.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $RegistryFiles.Count
}

# Check Shellbags
if (Test-Path $lnkPath) {
    $shellbags = @(Get-ChildItem $lnkPath -Filter "*_UsrClass.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $shellbags.Count
}

# Check Web History
if (Test-Path $WebResultsPath) {
    $script:totalSources++
}

# Check Chainsaw
$ChainsawFiles = @(Get-ChildItem -Path $ChainsawDirectory -Recurse -Filter *.csv -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "webResults.csv" })
$script:totalSources += $ChainsawFiles.Count

# Start overall progress tracking
Write-Progress -Activity "Building Forensic Timeline" -Status "Initializing" -PercentComplete 0 -Id 0

# Process Amcache
Write-Host "Processing Amcache" -ForegroundColor Cyan
$AmCachePath = Join-Path $KapeDirectory $ProgramExecSubDir
if (Test-Path $AmCachePath) {
    $AmcacheFiles = Get-ChildItem -Path $AmCachePath -Filter "*_Amcache_AssociatedFileEntries.csv" -ErrorAction SilentlyContinue
    $fileCount = $AmcacheFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $AmcacheFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing Amcache Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
                $amRows = Import-Csv $file.FullName | ForEach-Object {
                    $row = @{
                        DateTime       = $_."FileKeyLastWriteTimestamp"
                        DataPath       = $_."FullPath"
                        DataDetails    = $_."Name"
                        FileExtension  = $_."FileExtension"
                        SHA1           = $_."SHA1"
                    }
                    Normalize-Row -Fields $row -ArtifactName "AmcacheExecution"
                }
                $MasterTimeline += $amRows
                Write-Host "  Added $($amRows.Count) Amcache entries from $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "Amcache"
        }
    } else {
        Write-Host "  No Amcache files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Amcache path not found: $AmCachePath" -ForegroundColor Yellow
}

# Define filtering criteria per channel for Event Logs
$EventChannelFilters = @{
    "Application" = @(1000, 1001)
    "Microsoft-Windows-PowerShell/Operational" = @(4100, 4103, 4104)
    "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational" = @(72, 98, 104, 131, 140)
    "Microsoft-Windows-TaskScheduler/Operational" = @(106, 140, 141, 129, 200, 201)
    "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" = @(261, 1149)
    "Microsoft-Windows-WinRM/Operational" = @(169)
    "Security" = @(1102, 4624, 4625, 4648, 4698, 4702, 4720, 4722, 4723, 4724, 4725, 4726, 4732, 4756)
    "SentinelOne/Operational" = @(1, 31, 55, 57, 67, 68, 77, 81, 93, 97, 100, 101, 104, 110)
    "System" = @(7045)
}

# Process Event Logs with batching
Write-Host "Processing Event Logs" -ForegroundColor Cyan
$EVTPath = Join-Path $KapeDirectory $EventLogsSubDir
if (Test-Path $EVTPath) {
    $evtFiles = Get-ChildItem $EVTPath -Filter "*EvtxECmd*.csv" -ErrorAction SilentlyContinue
    $fileCount = $evtFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $evtFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing Event Logs" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
                # Using a simpler approach for event logs to avoid potential issues
                $data = Import-Csv $file.FullName
                
                # Filter for relevant event IDs
                $filtered = $data | Where-Object {
                    $channel = $_.Channel
                    $eventId = [int]$_.EventId
                    if ($EventChannelFilters.ContainsKey($channel)) {
                        $allowed = $EventChannelFilters[$channel]
                        ($allowed.Count -eq 0) -or ($allowed -contains $eventId)
                    } else {
                        $false
                    }
                }
                
                if ($filtered.Count -gt 0) {
                    # Process in batches of 1000 for memory efficiency
                    $batchSize = 1000
                    $totalBatches = [math]::Ceiling($filtered.Count / $batchSize)
                    $totalAdded = 0
                    
                    for ($i = 0; $i -lt $totalBatches; $i++) {
                        # Get current batch
                        $currentBatch = $filtered | Select-Object -Skip ($i * $batchSize) -First $batchSize
                        
                        # Process batch
                        $evtRows = $currentBatch | ForEach-Object {
                            $dt = try { [datetime]::Parse($_.TimeCreated).ToString("yyyy/MM/dd HH:mm:ss") } catch { $_.TimeCreated }
                            $row = @{
                                DateTime       = $dt
                                EventID        = $_."EventId"
                                Channel        = $_."Channel"
                                Detections     = $_."MapDescription"
                                DataPath       = $_."PayloadData1"
                                DataDetails    = $_."PayloadData2"
                                Computer       = $_."Computer"
                                EvidencePath   = $_."SourceFile"
                            }
                            Normalize-Row -Fields $row -ArtifactName "EventLogs"
                        }
                        
                        $MasterTimeline += $evtRows
                        $totalAdded += $evtRows.Count
                        
                        # Show progress
                        $percentComplete = [math]::Min(100, [math]::Round((($i + 1) / $totalBatches) * 100))
                        Show-ProcessingProgress -Activity "Processing Event Logs: $($file.Name)" -Status "Batch $($i+1) of $totalBatches ($percentComplete%)" -Current ($i+1) -Total $totalBatches -NestedLevel 2
                    }
                    
                    Write-Host "  Added $totalAdded event log entries from $($file.Name)" -ForegroundColor Green
                } else {
                    Write-Host "  No matching Event IDs found in $($file.Name). Skipping..." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "Event Logs"
        }
    } else {
        Write-Host "  No Event Log files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Event Log directory not found: $EVTPath" -ForegroundColor Yellow
}

# Function to process event log batches
function Process-EventLogBatch {
    param (
        [string]$HeaderLine,
        [System.Collections.ArrayList]$DataLines,
        [hashtable]$HeaderMap
    )
    
    # Create temp file for Import-Csv
    $tempFile = [System.IO.Path]::GetTempFileName()
    
    try {
        # Write header and data to temp file
        $HeaderLine | Out-File -FilePath $tempFile -Encoding utf8
        $DataLines | Out-File -FilePath $tempFile -Encoding utf8 -Append
        
        # Import and filter
        $batchData = Import-Csv $tempFile
        $filtered = $batchData | Where-Object {
            $channel = $_.Channel
            $eventId = [int]$_.EventId
            if ($EventChannelFilters.ContainsKey($channel)) {
                $allowed = $EventChannelFilters[$channel]
                ($allowed.Count -eq 0) -or ($allowed -contains $eventId)
            } else {
                $false
            }
        }
        
        # Process filtered entries
        $results = @()
        foreach ($entry in $filtered) {
            $dt = try { [datetime]::Parse($entry.TimeCreated).ToString("yyyy/MM/dd HH:mm:ss") } catch { $entry.TimeCreated }
            $row = @{
                DateTime       = $dt
                EventID        = $entry."EventId"
                Channel        = $entry."Channel"
                Detections     = $entry."MapDescription"
                DataPath       = $entry."PayloadData1"
                DataDetails    = $entry."PayloadData2"
                Computer       = $entry."Computer"
                EvidencePath   = $entry."SourceFile"
            }
            $results += Normalize-Row -Fields $row -ArtifactName "EventLogs"
        }
        
        return $results
    }
    finally {
        # Clean up temp file
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }
}

# Process File Deletion records
Write-Host "Processing Deleted Files" -ForegroundColor Cyan
$FileDeletionFiles = Get-ChildItem -Path $KapeDirectory -Recurse -Filter "*RBCmd*.csv" -ErrorAction SilentlyContinue
$fileCount = $FileDeletionFiles.Count

if ($fileCount -gt 0) {
    $fileCounter = 0
    foreach ($file in $FileDeletionFiles) {
        $fileCounter++
        Show-ProcessingProgress -Activity "Processing File Deletion Records" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
        
        try {
            $delRows = Import-Csv $file.FullName | ForEach-Object {
                $row = @{
                    DateTime     = $_."DeletedOn"
                    DataPath     = $_."FileName"
                    DataDetails  = $_."FileType"
                    FileSize     = $_."FileSize"
                    EvidencePath = $_."SourceName"
                }
                Normalize-Row -Fields $row -ArtifactName "FileDeletion"
            }
            $MasterTimeline += $delRows
            Write-Host "  Added $($delRows.Count) file deletion entries from $($file.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
        }
        
        Update-OverallProgress -CurrentSource "File Deletion"
    }
} else {
    Write-Host "  No file deletion records found" -ForegroundColor Yellow
}

# Process LNK Files
Write-Host "Processing LNK Files" -ForegroundColor Cyan
$lnkPath = Join-Path $KapeDirectory $FileFolderSubDir
if (Test-Path $lnkPath) {
    $lnkFiles = Get-ChildItem $lnkPath -Filter "*_LECmd_Output.csv" -ErrorAction SilentlyContinue
    $fileCount = $lnkFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $lnkFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing LNK Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
                $lnkRows = Import-Csv $file.FullName | ForEach-Object {
                    $row = @{
                        DateTime     = $_."TargetCreated"
                        DataPath     = $_."LocalPath"
                        FileSize     = $_."FileSize"
                        EvidencePath = $_."SourceFile"
                    }
                    Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                }
                $MasterTimeline += $lnkRows
                Write-Host "  Added $($lnkRows.Count) LNK file entries from $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "LNK Files"
        }
    } else {
        Write-Host "  No LNK files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  LNK files path not found: $lnkPath" -ForegroundColor Yellow
}

# Process MFT Created with batching for large files
Write-Host "Processing MFT File" -ForegroundColor Cyan
$MFTPath = Join-Path $KapeDirectory $FileSystemSubDir
if (Test-Path $MFTPath) {
    $mftFiles = Get-ChildItem $MFTPath -Filter "*MFT_Out*.csv" -ErrorAction SilentlyContinue
    $fileCount = $mftFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $mftFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing MFT Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
                # Process MFT files in batches due to potentially large size
                $totalEntriesProcessed = 0
                $totalRowsAdded = 0
                
                # Get number of lines for progress reporting
                $totalLines = (Get-Content $file.FullName | Measure-Object -Line).Lines
                
                # Stream reading approach
                $reader = New-Object System.IO.StreamReader($file.FullName)
                
                # Read header
                $headerLine = $reader.ReadLine()
                $headers = $headerLine -split ','
                
                # Process file in batches
                $batch = New-Object System.Collections.ArrayList
                $lineCount = 0
                $processedLines = 1  # Start at 1 because we already read header
                
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    $processedLines++
                    
                    # Show nested progress every 10000 lines
                    if ($processedLines % 10000 -eq 0) {
                        $percentDone = [math]::Round(($processedLines / $totalLines) * 100, 1)
                        Show-ProcessingProgress -Activity "Processing MFT: $($file.Name)" -Status "$processedLines of $totalLines lines ($percentDone%)" -Current $processedLines -Total $totalLines -NestedLevel 2
                    }
                    
                    # Skip empty lines
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    
                    # Add to batch
                    [void]$batch.Add($line)
                    $lineCount++
                    
                    # Process batch when it reaches batch size
                    if ($lineCount -ge $BatchSize) {
                        # Process this batch
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        # Import data from temp file
                        $batchData = Import-Csv $tempFile
                        
                        # Filter for relevant files
                        $filteredData = $batchData | Where-Object {
                            ($_.Extension -match "^(\.Identifier|\.exe|\.dll|\.zip|\.rar|\.7z)$") -and
                            ($_.ParentPath -like "*\\Users\\*" -or $_.ParentPath -like "*\\tmp\\*")
                        }
                        
                        # Process filtered entries
                        $mftRows = $filteredData | ForEach-Object {
                            $dt = try { [datetime]::Parse($_.Created0x10).ToString("yyyy/MM/dd HH:mm:ss") } catch { $_.Created0x10 }
                            $row = @{
                                DateTime       = $dt
                                DataPath       = $_."ParentPath"
                                DataDetails    = $_."FileName"
                                FileSize       = $_."FileSize"
                                FileExtension  = $_."Extension"
                            }
                            Normalize-Row -Fields $row -ArtifactName "MFTCreated"
                        }
                        
                        $MasterTimeline += $mftRows
                        $totalRowsAdded += $mftRows.Count
                        $totalEntriesProcessed += $lineCount
                        
                        # Clean up
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        
                        # Clear batch and reset counter
                        $batch.Clear()
                        $lineCount = 0
                    }
                }
                
                # Process remaining lines
                if ($batch.Count -gt 0) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    
                    $batchData = Import-Csv $tempFile
                    
                    $filteredData = $batchData | Where-Object {
                        ($_.Extension -match "^(\.Identifier|\.exe|\.dll|\.zip|\.rar|\.7z)$") -and
                        ($_.ParentPath -like "*\\Users\\*" -or $_.ParentPath -like "*\\tmp\\*")
                    }
                    
                    $mftRows = $filteredData | ForEach-Object {
                        $dt = try { [datetime]::Parse($_.Created0x10).ToString("yyyy/MM/dd HH:mm:ss") } catch { $_.Created0x10 }
                        $row = @{
                            DateTime       = $dt
                            DataPath       = $_."ParentPath"
                            DataDetails    = $_."FileName"
                            FileSize       = $_."FileSize"
                            FileExtension  = $_."Extension"
                        }
                        Normalize-Row -Fields $row -ArtifactName "MFTCreated"
                    }
                    
                    $MasterTimeline += $mftRows
                    $totalRowsAdded += $mftRows.Count
                    $totalEntriesProcessed += $batch.Count
                    
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
                
                $reader.Close()
                
                Write-Host "  Processed $totalEntriesProcessed MFT entries, added $totalRowsAdded to timeline from $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "MFT Files"
        }
    } else {
        Write-Host "  No MFT files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  MFT path not found: $MFTPath" -ForegroundColor Yellow
}

# Process PECmd (Prefetch Files)
Write-Host "Processing Prefetch Files" -ForegroundColor Cyan
$PECmdPath = Join-Path $KapeDirectory $ProgramExecSubDir
if (Test-Path $PECmdPath) {
    $PECmdFiles = Get-ChildItem -Path $PECmdPath -Filter "*_PECmd_Output.csv" -ErrorAction SilentlyContinue
    $fileCount = $PECmdFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $PECmdFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing Prefetch Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
                $peRows = Import-Csv $file.FullName | ForEach-Object {
                    $row = @{
                        DateTime     = $_."LastRun"
                        DataPath     = $_."SourceFilename"
                        DataDetails  = $_."ExecutableName"
                    }
                    Normalize-Row -Fields $row -ArtifactName "PECmdExecution"
                }
                $MasterTimeline += $peRows
                Write-Host "  Added $($peRows.Count) prefetch entries from $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "Prefetch Files"
        }
    } else {
        Write-Host "  No prefetch files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Prefetch path not found: $PECmdPath" -ForegroundColor Yellow
}

# Process Registry
Write-Host "Processing Registry" -ForegroundColor Cyan
$RegistryPath = Join-Path $KapeDirectory $RegistrySubDir
if (Test-Path $RegistryPath) {
    $RegistryFiles = Get-ChildItem -Path $RegistryPath -Filter "*_RECmd_Batch_Kroll_Batch_Output.csv" -ErrorAction SilentlyContinue
    $fileCount = $RegistryFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $RegistryFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing Registry Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
                # Registry files can be very large, process in batches
                $reader = New-Object System.IO.StreamReader($file.FullName)
                $headerLine = $reader.ReadLine()
                
                $batch = New-Object System.Collections.ArrayList
                $batchCount = 0
                $totalProcessed = 0
                $totalRowsAdded = 0
                
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    
                    # Skip empty lines
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    
                    [void]$batch.Add($line)
                    $batchCount++
                    
                    if ($batchCount -ge $BatchSize) {
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        $batchData = Import-Csv $tempFile
                        
                        $regRows = $batchData | ForEach-Object {
                            $row = @{
                                DateTime     = $_."LastWriteTimestamp"
                                DataPath     = $_."ValueData"
                                DataDetails  = $_."Description"
                                EventID      = $_."HiveType"
                                Detections   = $_."Category"
                                EvidencePath = $_."HivePath"
                            }
                            Normalize-Row -Fields $row -ArtifactName "RegistryUpdate"
                        }
                        
                        $MasterTimeline += $regRows
                        $totalRowsAdded += $regRows.Count
                        $totalProcessed += $batchCount
                        
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        $batch.Clear()
                        $batchCount = 0
                        
                        # Show progress
                        Show-ProcessingProgress -Activity "Processing Registry: $($file.Name)" -Status "Processed $totalProcessed entries" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                    }
                }
                
                # Process remaining entries
                if ($batch.Count -gt 0) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    
                    $batchData = Import-Csv $tempFile
                    
                    $regRows = $batchData | ForEach-Object {
                        $row = @{
                            DateTime     = $_."LastWriteTimestamp"
                            DataPath     = $_."ValueData"
                            DataDetails  = $_."Description"
                            EventID      = $_."HiveType"
                            Detections   = $_."Category"
                            EvidencePath = $_."HivePath"
                        }
                        Normalize-Row -Fields $row -ArtifactName "RegistryUpdate"
                    }
                    
                    $MasterTimeline += $regRows
                    $totalRowsAdded += $regRows.Count
                    $totalProcessed += $batch.Count
                    
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
                
                $reader.Close()
                
                Write-Host "  Processed $totalProcessed registry entries, added $totalRowsAdded to timeline from $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "Registry Files"
        }
    } else {
        Write-Host "  No registry files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Registry path not found: $RegistryPath" -ForegroundColor Yellow
}

# Process Shellbags
Write-Host "Processing Shellbags" -ForegroundColor Cyan
$lnkPath = Join-Path $KapeDirectory $FileFolderSubDir
if (Test-Path $lnkPath) {
    $shellbags = Get-ChildItem $lnkPath -Filter "*_UsrClass.csv" -ErrorAction SilentlyContinue
    $fileCount = $shellbags.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $shellbags) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing Shellbags" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
                $shellRows = Import-Csv $file.FullName | ForEach-Object {
                    $row = @{
                        DateTime    = $_."LastWriteTime"
                        DataPath    = $_."AbsolutePath"
                        DataDetails = $_."Value"
                        ShellType   = $_."ShellType"
                    }
                    Normalize-Row -Fields $row -ArtifactName "Shellbags"
                }
                $MasterTimeline += $shellRows
                Write-Host "  Added $($shellRows.Count) shellbag entries from $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "Shellbags"
        }
    } else {
        Write-Host "  No shellbag files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Shellbags path not found: $lnkPath" -ForegroundColor Yellow
}

# Web History
Write-Host "Processing Web History" -ForegroundColor Cyan
if (Test-Path $WebResultsPath) {
    Show-ProcessingProgress -Activity "Processing Web History" -Status "File: $([System.IO.Path]::GetFileName($WebResultsPath))" -Current 1 -Total 1 -NestedLevel 1
    
    try {
        $webRows = Import-Csv $WebResultsPath | ForEach-Object {
            $row = @{
                DateTime     = $_."Visit Time"
                DataPath     = $_."URL"
                DataDetails  = $_."Title"
                VisitCount   = $_."Visit Count"
                VisitType    = $_."Visit Type"
                VisitFrom    = $_."Visit From"
                WebBrowser   = $_."Web Browser"
                User         = $_."User Profile"
            }
            Normalize-Row -Fields $row -ArtifactName "WebHistory"
        }
        $MasterTimeline += $webRows
        Write-Host "  Added $($webRows.Count) web history entries from $([System.IO.Path]::GetFileName($WebResultsPath))" -ForegroundColor Green
    } catch {
        Write-Host "  Error processing web history: $_" -ForegroundColor Red
    }
    
    Update-OverallProgress -CurrentSource "Web History"
} else {
    Write-Host "  Web history file not found: $WebResultsPath" -ForegroundColor Yellow
}

# Process Chainsaw CSV files
Write-Host "Processing Chainsaw CSV Files" -ForegroundColor Cyan
$ChainsawFiles = Get-ChildItem -Path $ChainsawDirectory -Recurse -Filter *.csv -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "webResults.csv" }
$fileCount = $ChainsawFiles.Count

if ($fileCount -gt 0) {
    $fileCounter = 0
    foreach ($chainsawFile in $ChainsawFiles) {
        $fileCounter++
        Show-ProcessingProgress -Activity "Processing Chainsaw Files" -Status "File: $($chainsawFile.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
        
        try {
            $artifactName = $chainsawFile.BaseName
            $chainsawRows = Import-Csv -Path $chainsawFile.FullName | ForEach-Object {
                $row = @{
                    DateTime           = $_."timestamp"
                    EventID            = $_."Event ID"
                    Channel            = $_."Channel"
                    Detections         = $_."detections"
                    DataPath           = $_."Threat Path"
                    DataDetails        = $_."Threat Name"
                    User               = $_."User"
                    Computer           = $_."Computer"
                    UserSID            = $_."User SID"
                    MemberSID          = $_."Member SID"
                    ProcessName        = $_."Process Name"
                    IPAddress          = $_."IP Address"
                    LogonType          = $_."Logon Type"
                    Count              = $_."count"
                    SourceAddress      = $_."Source Address"
                    DestinationAddress = $_."Dest Address"
                    ServiceType        = $_."Service Type"
                    CommandLine        = $_."CommandLine"
                    SHA1               = $_."SHA1"
                    EvidencePath       = $_."path"
                }
                Normalize-Row -Fields $row -ArtifactName $artifactName
            }
            $MasterTimeline += $chainsawRows
            Write-Host "  Added $($chainsawRows.Count) entries from $($chainsawFile.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  Error processing $($chainsawFile.Name): $_" -ForegroundColor Red
        }
        
        Update-OverallProgress -CurrentSource "Chainsaw"
    }
} else {
    Write-Host "  No Chainsaw CSV files found in $ChainsawDirectory" -ForegroundColor Yellow
}

# Complete the overall progress bar
Write-Progress -Activity "Building Forensic Timeline" -Status "Processing Complete" -PercentComplete 100 -Id 0 -Completed

# Report on timeline status
Write-Host "Timeline entries collected: $($MasterTimeline.Count)" -ForegroundColor Cyan

# Skip export if no data
if (-not $MasterTimeline -or $MasterTimeline.Count -eq 0) {
    Write-Warning "Timeline is empty. No export was performed."
    exit 1
}

# Sort the timeline by DateTime
Write-Host "Sorting timeline by DateTime..." -ForegroundColor Cyan
$MasterTimeline = $MasterTimeline | Sort-Object -Property DateTime

# Apply date range filtering if specified
if ($StartDate -or $EndDate) {
    Write-Host "Applying date range filtering..." -ForegroundColor Cyan
    $originalCount = $MasterTimeline.Count
    
    # Filter for entries within date range
    $MasterTimeline = $MasterTimeline | Where-Object {
        $entryDate = $null
        
        # Try to parse the date from the DateTime field
        if ($_.DateTime -and (-not [string]::IsNullOrWhiteSpace($_.DateTime))) {
            try {
                $entryDate = [datetime]::Parse($_.DateTime)
            } catch {
                # If parsing fails, keep the entry (don't filter it out)
                return $true
            }
        } else {
            # If no date, keep the entry (don't filter it out)
            return $true
        }
        
        # Apply start date filter if specified
        $afterStart = (-not $StartDate) -or ($entryDate -ge $StartDate)
        
        # Apply end date filter if specified
        $beforeEnd = (-not $EndDate) -or ($entryDate -le $EndDate)
        
        # Include only entries that meet both conditions
        return $afterStart -and $beforeEnd
    }
    
    $filteredCount = $MasterTimeline.Count
    $removedCount = $originalCount - $filteredCount
    
    Write-Host "  Date range filtering: $removedCount entries removed, $filteredCount entries remaining" -ForegroundColor Green
    if ($StartDate) { Write-Host "  Start date: $($StartDate.ToString('yyyy-MM-dd'))" -ForegroundColor Green }
    if ($EndDate) { Write-Host "  End date: $($EndDate.ToString('yyyy-MM-dd'))" -ForegroundColor Green }
}

# Apply deduplication if enabled
if ($Deduplicate) {
    Write-Host "Applying deduplication..." -ForegroundColor Cyan
    $originalCount = $MasterTimeline.Count
    
    # Create a hashtable to track unique entries
    $uniqueEntries = @{}
    $uniqueTimeline = @()
    
    foreach ($entry in $MasterTimeline) {
        # Create a key based on date, path, and event details
        $key = "$($entry.DateTime)_$($entry.DataPath)_$($entry.DataDetails)_$($entry.EventID)_$($entry.ArtifactName)"
        
        # Only add unique entries
        if (-not $uniqueEntries.ContainsKey($key)) {
            $uniqueEntries[$key] = $true
            $uniqueTimeline += $entry
        }
    }
    
    # Replace the master timeline with the deduplicated version
    $MasterTimeline = $uniqueTimeline
    
    $deduplicatedCount = $MasterTimeline.Count
    $removedCount = $originalCount - $deduplicatedCount
    
    Write-Host "  Deduplication: $removedCount duplicate entries removed, $deduplicatedCount unique entries remaining" -ForegroundColor Green
}

# Apply the field order to the timeline
Write-Host "Formatting timeline for export..." -ForegroundColor Cyan
$OrderedTimeline = $MasterTimeline | Select-Object -Property $PreferredFieldOrder

# Output
Write-Host "Exporting timeline in $ExportFormat format..." -ForegroundColor Cyan
switch ($ExportFormat) {
    "xlsx" {
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Install-Module ImportExcel -Force -Scope CurrentUser
        }
        Import-Module ImportExcel
        $OrderedTimeline | Export-Excel -Path $OutputFile -WorksheetName "Timeline" -AutoSize -BoldTopRow -FreezeTopRow -TableName "MasterTimeline"
        Write-Host "Excel timeline written to: $OutputFile" -ForegroundColor Green
    }
    "csv" {
        $OrderedTimeline | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        Write-Host "CSV timeline written to: $OutputFile" -ForegroundColor Green
    }
    "json" {
        $OrderedTimeline | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "JSON timeline written to: $OutputFile" -ForegroundColor Green
    }
}

Write-Host "Timeline export complete. Total entries: $($MasterTimeline.Count)" -ForegroundColor Cyan
Write-Host "Output file: $OutputFile" -ForegroundColor Green
