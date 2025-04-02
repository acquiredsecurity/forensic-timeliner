# Parameter Block
param (
    [string]$BaseDir = "C:\kape", 
    [string]$KapeDirectory = "$BaseDir\timeline",                                            # Path to main KAPE timeline folder and csv output from EZ Tools
    [string]$WebResultsPath = "$BaseDir\browsinghistory\webResults.csv",                     # Path to webResults.csv
    [string]$ChainsawDirectory = "$BaseDir\chainsaw",                                        # Directory containing Chainsaw CSV files
    [string]$OutputFile = "$BaseDir\timeline\Master_Timeline.csv",                           # Output timeline file
    [ValidateSet("xlsx", "csv", "json")]
    [string]$ExportFormat = "csv",                                                           # Output Format  CSV for timeline creation with Json and Xlsx Options
    [switch]$SkipEventLogs,                                                                  # Skip event logs processing
    [string]$RegistrySubDir = "Registry",                                                    # Registry subdirectory under KapeDirectory
    [string]$ProgramExecSubDir = "ProgramExecution",                                         # Program execution subdirectory
    [string]$FileFolderSubDir = "FileFolderAccess",                                          # File/Folder access subdirectory
    [string]$FileSystemSubDir = "FileSystem",                                                # FileSystem subdirectory
    [string]$EventLogsSubDir = "EventLogs",                                                  # Event logs subdirectory
    [string[]]$MFTExtensionFilter = @(".identifier", ".exe", ".ps1", ".zip", ".rar", ".7z"), # MFT File Extension Filter
    [string[]]$MFTPathFilter = @("Users", "tmp"),                                            # MFT Path Filter
    [int]$BatchSize = 10000,                                                                 # Batch per line size for largr files
    [datetime]$StartDate,                                                                    # Start date for filtering (inclusive)
    [datetime]$EndDate,                                                                      # End date for filtering (inclusive)
    [switch]$Deduplicate,                                                                    # Enable deduplication of timeline entries
    [switch]$Interactive,                                                                    # Launch interactive prompt
    [switch]$Help                                                                            # Show help menu
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
    Write-Host "  .\forensic_timeliner.ps1 -ChainsawDirectory '$BaseDir\chainsaw' -OutputFile '$BaseDir\timeline\Master_Timeline.csv'"
    Write-Host "  .\forensic_timeliner.ps1 -Interactive" 
    Write-Host "" 
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -KapeDirectory       Default path for Kape CSV Output Registry/FileSystem/EventLogs/etc.. (default: $BaseDir\timeline)"
    Write-Host "  -ChainsawDirectory   Default path to Chainsaw CSVs (default: $BaseDir\chainsaw)"
    Write-Host "  -WebResultsPath      Default path to webResults.csv **Include file name** (default: $BaseDir\browsinghistory\webResults.csv)"
    Write-Host "  -RegistrySubDir      Default name of Registry subdirectory under KapeDirectory (default: Registry)"
    Write-Host "  -ProgramExecSubDir   Default name of Program Execution subdirectory under KapeDirectory (default: ProgramExecution)"
    Write-Host "  -FileFolderSubDir    Default name of File/Folder access subdirectory under KapeDirectory (default: FileFolderAccess)"
    Write-Host "  -FileSystemSubDir    Default name of FileSystem subdirectory under KapeDirectory (default: FileSystem)"
    Write-Host "  -EventLogsSubDir     Default name of Event logs subdirectory under KapeDirectory (default: EventLogs)"
    Write-Host "  -OutputFile          Default path to timeline output file (default: $BaseDir\timeline\Master_Timeline.csv)"
    Write-Host "  -BatchSize           Batch processing chunk size for large datasets (default: 10,000 records per batch - increase for" 
               "                       faster processing on powerful systems or decrease for memory-constrained environments)(default: 10,000)"
    Write-Host "  -Interactive         Get assistance with the setup process when running this script locally"
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
    $defaultOutputPath = "$BaseDir\timeline\Master_Timeline$fileExtension"
    
    $KapeDirectory = Read-Host "Path to KAPE Processed CSV Files [Default: $BaseDir\timeline]"
    if (-not $KapeDirectory) { $KapeDirectory = "$BaseDir\timeline" }

    $ChainsawDirectory = Read-Host "Path to Chainsaw CSVs [Default: $BaseDir\chainsaw]"
    if (-not $ChainsawDirectory) { $ChainsawDirectory = "$BaseDir\chainsaw" }

    $WebResultsPath = Read-Host "Path to BrowsingHistoryView output file webResults.csv [Default: $BaseDir\browsinghistory\webResults.csv]"
    if (-not $WebResultsPath) { 
        $WebResultsPath = "$BaseDir\browsinghistory\webResults.csv" 
    }
    
    # Validate the web history path to ensure it includes a filename
    if (-not [string]::IsNullOrEmpty($WebResultsPath) -and (Test-Path $WebResultsPath -PathType Container)) {
        # If user entered a directory, append the default filename
        $WebResultsPath = Join-Path $WebResultsPath "webResults.csv"
        Write-Host "  Note: Directory path detected. Using file: $WebResultsPath" -ForegroundColor Yellow
    }
    
    # Handle output file path validation
    $OutputFile = Read-Host "Path to Forensic Timeline output file [Default: $defaultOutputPath]"
    if (-not $OutputFile) { 
        $OutputFile = $defaultOutputPath 
    }

    # Check if the path is a directory
    if (Test-Path $OutputFile -PathType Container) {
        # User provided only a directory, append default filename
        $OutputFile = Join-Path $OutputFile "Master_Timeline.$ExportFormat"
        Write-Host "  Note: Directory path detected. Using file: $OutputFile" -ForegroundColor Yellow
    }
    # Ask if User would like t process Event Logs
        $processEventLogsPrompt = Read-Host "Include Windows Event Log processing? (Chainsaw with Sigma already provides analysis for these logs. Enabling this will significantly increase processing time and timeline size) (y/n) [Default: y]"
    if ($processEventLogsPrompt -eq "n") {
        $SkipEventLogs = $true
        Write-Host "  Event log processing will be skipped" -ForegroundColor Yellow
    } else {
        $SkipEventLogs = $false
    }
    # Ask is the user would like to filter the MFT by file extension 
        $currentExtensions = $MFTExtensionFilter -join ", "
        Write-Host "  Current MFT extension filter: $currentExtensions" -ForegroundColor Yellow
        $customizeMFTExtensions = Read-Host "Customize MFT file extension filter? (y/n) [Default: n]"
        if ($customizeMFTExtensions -eq "y") {
            $addExtensions = Read-Host "Enter additional extensions to include (comma-separated, include the dot, e.g. '.pdf,.docx,.bat')"
            if (-not [string]::IsNullOrWhiteSpace($addExtensions)) {
                $newExtensions = $addExtensions -split ',' | ForEach-Object { $_.Trim() }
                $MFTExtensionFilter = $MFTExtensionFilter + $newExtensions
                Write-Host "  Updated MFT extension filter: $($MFTExtensionFilter -join ", ")" -ForegroundColor Green
            }
        }
    
    # Ask is the user would like to filter the MFT by file path
        $currentPaths = $MFTPathFilter -join ", "
        Write-Host "  Current MFT path filter: $currentPaths" -ForegroundColor Yellow
        $customizeMFTPaths = Read-Host "Customize MFT path filters? (y/n) [Default: n]"
        if ($customizeMFTPaths -eq "y") {
            $addPaths = Read-Host "Enter additional paths to include (comma-separated, e.g. 'Windows\System32,Program Files')"
            if (-not [string]::IsNullOrWhiteSpace($addPaths)) {
                $newPaths = $addPaths -split ',' | ForEach-Object { $_.Trim() }
                $MFTPathFilter = $MFTPathFilter + $newPaths
                Write-Host "  Updated MFT path filter: $($MFTPathFilter -join ", ")" -ForegroundColor Green
            }
        }

        # safely change the extension if needed
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
if (-not $ChainsawDirectory) { $ChainsawDirectory = "$BaseDir\chainsaw" }
if (-not $OutputFile) { $OutputFile = "$BaseDir\timeline\Master_Timeline.csv" }
if (-not $WebResultsPath) { $WebResultsPath = "$BaseDir\browsinghistory\webResults.csv" }
if (-not $KapeDirectory) { $KapeDirectory = "$BaseDir\timeline" }

# Adjust extension based on export format
$desiredExtension = "." + $ExportFormat.ToLower()
$OutputFile = [System.IO.Path]::ChangeExtension($OutputFile, $desiredExtension)



# Set Timeline Log Path
$TimelineDirectory = "$BaseDir\timeline\"
$LogFilePath = Join-Path -Path $TimelineDirectory -ChildPath "ForensicTimeliner_Log_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"

# Start transcript to capture console output
Start-Transcript -Path $LogFilePath -Append


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
                                                                                           
Mini Timeline Builder for Kape Output, Chainsaw +Sigma & WebhistoryView
| Made by https://github.com/acquiredsecurity 
| with help from the robots [o_o] 
- Build powerful timelines from digital forensic artifacts!
=) Happy Timelining!
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
    "DateTime", "ArtifactName", "EventId", "Description", "Info", "DataPath", "DataDetails",
    "User", "Computer", "FileSize", "FileExtension", "UserSID", "MemberSID", "ProcessName", "IPAddress", "LogonType", "Count",
    "SourceAddress", "DestinationAddress", "ServiceType", "CommandLine", "SHA1", "EvidencePath"
    
)

# Define preferred field order for output
$PreferredFieldOrder = @(
    "DateTime", 
    "ArtifactName",
    "Description",
    "Info",
    "DataDetails",
    "DataPath",
    "FileExtension",
    "EvidencePath",
    "EventId", 
    "User",
    "Computer",
    "CommandLine",
    "ProcessName",
    "FileSize",
    "IPAddress", 
    "SourceAddress",
    "DestinationAddress",
    "LogonType",
    "UserSID", 
    "MemberSID",
    "ServiceType", 
    "SHA1", 
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
            $dt = try { [datetime]::Parse($entry.TimeCreated).ToString("yyyy-MM-dd HH:mm:ss") } catch { $entry.TimeCreated }
            $row = @{
                DateTime       = $dt
                EventId        = $entry."EventId"
                Description    = $entry."Channel"
                Info           = $entry."MapDescription"
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
    $AmcacheFiles = @(Get-ChildItem -Path $AmCachePath -Filter "*ssociatedFileEntries.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $AmcacheFiles.Count
}

# Check AppCompatCache
$AppCompatCachePath = Join-Path $KapeDirectory $ProgramExecSubDir
if (Test-Path $AppCompatCachePath) {
    $AppCompatCacheFiles = @(Get-ChildItem -Path $AppCompatCachePath -Filter "*AppCompatCache*.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $AppCompatCacheFiles.Count
}

# Check AutomaticDestinations
$AutoDestPath = Join-Path $KapeDirectory $FileFolderSubDir
if (Test-Path $AutoDestPath) {
    $AutoDestFiles = @(Get-ChildItem -Path $AutoDestPath -Filter "*AutomaticDestinations*.csv" -ErrorAction SilentlyContinue)
    $script:totalSources += $AutoDestFiles.Count
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

# Check for Chainsaw Files
$ChainsawFiles = @(Get-ChildItem -Path $ChainsawDirectory -Recurse -Filter *.csv -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "webResults.csv" })
$script:totalSources += $ChainsawFiles.Count

# Start overall progress tracking
Write-Progress -Activity "Building Forensic Timeline" -Status "Initializing" -PercentComplete 0 -Id 0

# Process Amcache
Write-Host "Processing Amcache" -ForegroundColor Cyan
$AmCachePath = Join-Path $KapeDirectory $ProgramExecSubDir
if (Test-Path $AmCachePath) {
    $AmcacheFiles = Get-ChildItem -Path $AmCachePath -Filter "*ssociatedFileEntries.csv" -ErrorAction SilentlyContinue
    $fileCount = $AmcacheFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $AmcacheFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing Amcache Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
                # Use streaming approach for large files
                $reader = New-Object System.IO.StreamReader($file.FullName)
                $headerLine = $reader.ReadLine()
                $batchCount = 0
                $totalProcessed = 0
                $totalAdded = 0
                $batch = New-Object System.Collections.ArrayList
                
                # Process the file line by line in batches
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    
                    # Skip empty lines
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    
                    [void]$batch.Add($line)
                    $batchCount++
                    $totalProcessed++
                    
                    # Process in batches of the specified size
                    if ($batchCount -ge $BatchSize) {
                        # Create temp CSV file for the batch
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        
                        try {
                            # Write header and batch to temp file
                            $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                            $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                            
                            # Import batch data
                            $batchData = Import-Csv $tempFile
                            
                            # Process batch data
                            $amRows = $batchData | ForEach-Object {
                                $row = @{
                                    DateTime       = $_."FileKeyLastWriteTimestamp"
                                    DataPath       = $_."FullPath"
                                    Info           = $_."Last Write"
                                    Description    = "Program Execution"
                                    DataDetails    = $_."ApplicationName"
                                    FileExtension  = $_."FileExtension"
                                    SHA1           = $_."SHA1"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Amcache"
                            }
                            
                            # Add to master timeline
                            $MasterTimeline += $amRows
                            $totalAdded += $amRows.Count
                            
                            # Update progress
                            Show-ProcessingProgress -Activity "Processing Amcache: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                        }
                        catch {
                            Write-Host "    Error processing batch: $_" -ForegroundColor Red
                        }
                        finally {
                            # Clean up temp file
                            if (Test-Path $tempFile) {
                                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                            }
                        }
                        
                        # Reset batch
                        $batch.Clear()
                        $batchCount = 0
                    }
                }
                
                # Process any remaining lines
                if ($batch.Count -gt 0) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        $batchData = Import-Csv $tempFile
                        
                        $amRows = $batchData | ForEach-Object {
                            $row = @{
                                DateTime       = $_."FileKeyLastWriteTimestamp"
                                DataPath       = $_."FullPath"
                                Info           = $_."Last Write"
                                Description    = "Program Execution"
                                DataDetails    = $_."ApplicationName"
                                FileExtension  = $_."FileExtension"
                                SHA1           = $_."SHA1"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Amcache"
                        }
                        
                        $MasterTimeline += $amRows
                        $totalAdded += $amRows.Count
                    }
                    catch {
                        Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                    }
                    finally {
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                
                $reader.Close()
                
                # Report on processing results
                Write-Host "  Added $totalAdded Amcache entries from $($file.Name)" -ForegroundColor Green
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


# Process AppCompatCache
Write-Host "Processing AppCompatCache" -ForegroundColor Cyan
$AppCompatCachePath = Join-Path $KapeDirectory $ProgramExecSubDir
if (Test-Path $AppCompatCachePath) {
    $AppCompatCacheFiles = Get-ChildItem -Path $AppCompatCachePath -Filter "*AppCompatCache*.csv" -ErrorAction SilentlyContinue
    $fileCount = $AppCompatCacheFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $AppCompatCacheFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing AppCompatCache Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
                # Use streaming approach for large files
                $reader = New-Object System.IO.StreamReader($file.FullName)
                $headerLine = $reader.ReadLine()
                
                $batchCount = 0
                $totalProcessed = 0
                $totalAdded = 0
                $batch = New-Object System.Collections.ArrayList
                
                # Process the file line by line in batches
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    
                    # Skip empty lines
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    
                    [void]$batch.Add($line)
                    $batchCount++
                    $totalProcessed++
                    
                    # Process in batches of the specified size
                    if ($batchCount -ge $BatchSize) {
                        # Create temp CSV file for the batch
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        
                        try {
                            # Write header and batch to temp file
                            $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                            $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                            
                            # Import batch data
                            $batchData = Import-Csv $tempFile
                            
                            # Process batch data - using exact field mappings from your original code
                            $accRows = $batchData | ForEach-Object {
                                $row = @{
                                    DateTime       = $_."LastModifiedTimeUTC"
                                    DataPath       = $_."Path"
                                    DataDetails    = $_."Path" -replace '.*\\([^\\]+)$', '$1'
                                    Info           = "Last Modified"
                                    EvidencePath   = $_."SourceFile"
                                    Description    = "Program Execution"
                                }
                                Normalize-Row -Fields $row -ArtifactName "AppCompatCache"
                            }
                            
                            # Add to master timeline
                            $MasterTimeline += $accRows
                            $totalAdded += $accRows.Count
                            
                            # Update progress
                            if ($totalProcessed % 5000 -eq 0) {
                                Show-ProcessingProgress -Activity "Processing AppCompatCache: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                            }
                        }
                        catch {
                            Write-Host "    Error processing batch: $_" -ForegroundColor Red
                        }
                        finally {
                            # Clean up temp file
                            if (Test-Path $tempFile) {
                                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                            }
                        }
                        
                        # Reset batch
                        $batch.Clear()
                        $batchCount = 0
                    }
                }
                
                # Process any remaining lines
                if ($batch.Count -gt 0) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        $batchData = Import-Csv $tempFile
                        
                        # Use exact same field mappings as above and in your original code
                        $accRows = $batchData | ForEach-Object {
                            $row = @{
                                DateTime       = $_."LastModifiedTimeUTC"
                                DataPath       = $_."Path"
                                DataDetails    = $_."Path" -replace '.*\\([^\\]+)$', '$1'
                                Info           = "Last Modified"
                                EvidencePath   = $_."SourceFile"
                                Description    = "Program Execution"
                            }
                            Normalize-Row -Fields $row -ArtifactName "AppCompatCache"
                        }
                        
                        $MasterTimeline += $accRows
                        $totalAdded += $accRows.Count
                    }
                    catch {
                        Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                    }
                    finally {
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                
                $reader.Close()
                
                # Report on processing results
                Write-Host "  Added $totalAdded AppCompatCache entries from $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "AppCompatCache"
        }
    } else {
        Write-Host "  No AppCompatCache files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  AppCompatCache path not found: $AppCompatCachePath" -ForegroundColor Yellow
}

# Define filtering criteria per channel for Event Logs
$EventChannelFilters = @{
    "Application" = @(1000, 1001)
    "Microsoft-Windows-PowerShell/Operational" = @(4100, 4103, 4104)
    "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational" = @(72, 98, 104, 131, 140)
    "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" = @(21, 22)
    "Microsoft-Windows-TaskScheduler/Operational" = @(106, 140, 141, 129, 200, 201)
    "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" = @(261, 1149)
    "Microsoft-Windows-WinRM/Operational" = @(169)
    "Security" = @(1102, 4624, 4625, 4648, 4698, 4702, 4720, 4722, 4723, 4724, 4725, 4726, 4732, 4756)
    "SentinelOne/Operational" = @(1, 31, 55, 57, 67, 68, 77, 81, 93, 97, 100, 101, 104, 110)
    "System" = @(7045)
}

# process event logs
if (!$SkipEventLogs) {
    Write-Host "Processing Event Logs" -ForegroundColor Cyan
    
    # Display current event log filter settings
    Write-Host "  Current Event Log Filters:" -ForegroundColor Yellow
    Write-Host "  (You can customize these filters by editing the `$EventChannelFilters hashtable in the script)" -ForegroundColor Yellow
    Write-Host "  -----------------------------------------" -ForegroundColor Yellow
    foreach ($channel in $EventChannelFilters.Keys | Sort-Object) {
        $eventIds = $EventChannelFilters[$channel]
        if ($eventIds.Count -eq 0) {
            Write-Host "    $channel : All Events" -ForegroundColor Gray
        } else {
            $eventIdList = $eventIds -join ", "
            Write-Host "    $channel : Events $eventIdList" -ForegroundColor Gray
        }
    }
    Write-Host "  -----------------------------------------" -ForegroundColor Yellow
    
    Write-Host "  Warning: Event log processing may take significantly longer than other artifacts." -ForegroundColor Yellow
    Write-Host "  Consider using -SkipEventLogs in the future if this step takes too long." -ForegroundColor Yellow
    Write-Host "  Note: Some event log entries may be skipped due to formatting issues in the CSV." -ForegroundColor Yellow
    
    $EVTPath = Join-Path $KapeDirectory $EventLogsSubDir
    if (Test-Path $EVTPath) {
        $evtFiles = Get-ChildItem $EVTPath -Filter "*EvtxECmd*.csv" -ErrorAction SilentlyContinue
        $fileCount = $evtFiles.Count
        
        if ($fileCount -gt 0) {
            $fileCounter = 0
            foreach ($file in $evtFiles) {
                $fileCounter++
                Show-ProcessingProgress -Activity "Processing Event Logs" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
                
                # Create a hashtable to track matches by channel
                $channelMatches = @{}
                foreach ($channel in $EventChannelFilters.Keys) {
                    $channelMatches[$channel] = 0
                }
                
                try {
                    # Use streaming approach for large files
                    $reader = New-Object System.IO.StreamReader($file.FullName)
                    $headerLine = $reader.ReadLine()
                    
                    $batchCount = 0
                    $totalProcessed = 0
                    $totalAdded = 0
                    $skippedEntries = 0
                    $totalFiltered = 0
                    $batch = New-Object System.Collections.ArrayList
                    $progressUpdateFrequency = 5000  # Update progress less frequently
                    
                    # Process the file line by line in batches
                    while (-not $reader.EndOfStream) {
                        $line = $reader.ReadLine()
                        
                        # Skip empty lines
                        if ([string]::IsNullOrWhiteSpace($line)) { continue }
                        
                        [void]$batch.Add($line)
                        $batchCount++
                        $totalProcessed++
                        
                        # Process in batches of 500 lines
                        if ($batchCount -ge 500) {
                            # Create temp CSV file for the batch
                            $tempFile = [System.IO.Path]::GetTempFileName()
                            
                            try {
                                # Write header and batch to temp file
                                $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                                $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                                
                                # Import batch data
                                $batchData = Import-Csv $tempFile
                                
                                # Filter for events of interest with error handling
                                $filteredBatch = @()
                                foreach ($entry in $batchData) {
                                    # Check for null channel
                                    $channel = $entry.Channel
                                    if ([string]::IsNullOrWhiteSpace($channel)) {
                                        $skippedEntries++
                                        continue
                                    }
                                    
                                    $eventIdString = $entry.EventId
                                    
                                    # Only process entries with valid event IDs and channels
                                    $validEventId = $false
                                    $eventId = 0
                                    try {
                                        $eventId = [int]$eventIdString
                                        $validEventId = $true
                                    } catch {
                                        $validEventId = $false
                                    }
                                    
                                    if ($validEventId -and 
                                        $EventChannelFilters.ContainsKey($channel) -and 
                                        ($EventChannelFilters[$channel].Count -eq 0 -or 
                                         $EventChannelFilters[$channel] -contains $eventId)) {
                                        $filteredBatch += $entry
                                        $totalFiltered++
                                        
                                        # Track which channel matched
                                        if ($channelMatches.ContainsKey($channel)) {
                                            $channelMatches[$channel]++
                                        }
                                    } else {
                                        $skippedEntries++
                                    }
                                }
                                
                                # Report filter efficiency periodically with channel information
                                $batchSize = $batchData.Count
                                if ($batchSize -gt 0 -and $totalProcessed % ($progressUpdateFrequency * 10) -eq 0) {
                                    $filterRatio = [math]::Round(($totalFiltered / $totalProcessed) * 100, 1)
                                    
                                    # Find most matched channel so far
                                    $topChannel = $channelMatches.GetEnumerator() | Where-Object { $_.Value -gt 0 } | Sort-Object -Property Value -Descending | Select-Object -First 1
                                    
                                    if ($topChannel) {
                                        Write-Host "    Filter efficiency: $totalFiltered of $totalProcessed entries. Filtering $($topChannel.Key) ($filterRatio%) matched filters" -ForegroundColor Gray
                                    } else {
                                        Write-Host "    Filter efficiency: $totalFiltered of $totalProcessed entries ($filterRatio%) matched filters" -ForegroundColor Gray
                                    }
                                }
                                
                                # Create timeline entries from filtered batch
                                $evtRows = @()
                                foreach ($entry in $filteredBatch) {
                                    # Extract TimeCreated and handle the timestamps
                                    $dateTimeString = $entry.TimeCreated
                                    
                                    # Format timestamps consistently with other artifacts
                                    $dateTimeFormatted = $dateTimeString
                                    try {
                                        if ([string]::IsNullOrWhiteSpace($dateTimeString)) {
                                            $dateTimeFormatted = "Unknown"
                                        } 
                                        # Handle partial timestamps like "28:04.8"
                                        elseif ($dateTimeString -match '^\d+:\d+\.\d+$') {
                                            $dateTimeFormatted = "Time: $dateTimeString"
                                        } 
                                        # Format full timestamps and drop microseconds
                                        else {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        }
                                    } catch {
                                        # Keep original string if parsing fails
                                    }
                                    
                                    $row = @{
                                        DateTime     = $dateTimeFormatted
                                        EventId      = $entry."EventId"
                                        Description  = $entry."Channel"
                                        Info         = $entry."MapDescription"
                                        DataDetails  = $entry."PayloadData1"
                                        DataPath     = $entry."PayloadData2"
                                        Computer     = $entry."Computer"
                                        EvidencePath = $entry."SourceFile"
                                    }
                                    $evtRows += Normalize-Row -Fields $row -ArtifactName "EventLogs"
                                }
                                
                                # Add to master timeline
                                $MasterTimeline += $evtRows
                                $totalAdded += $evtRows.Count
                                
                                # Update progress less frequently
                                if ($totalProcessed % $progressUpdateFrequency -eq 0) {
                                    Show-ProcessingProgress -Activity "Processing Event Log: $($file.Name)" -Status "Processed $totalProcessed lines, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                                }
                            }
                            catch {
                                Write-Host "    Error processing batch: $_" -ForegroundColor Red
                            }
                            finally {
                                # Clean up temp file
                                if (Test-Path $tempFile) {
                                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                                }
                            }
                            
                            # Reset batch
                            $batch.Clear()
                            $batchCount = 0
                        }
                    }
                    
                    # Process any remaining lines
                    if ($batch.Count -gt 0) {
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        try {
                            $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                            $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                            
                            $batchData = Import-Csv $tempFile
                            
                            # Filter for events of interest with error handling
                            $filteredBatch = @()
                            foreach ($entry in $batchData) {
                                # Check for null channel
                                $channel = $entry.Channel
                                if ([string]::IsNullOrWhiteSpace($channel)) {
                                    $skippedEntries++
                                    continue
                                }
                                
                                $eventIdString = $entry.EventId
                                
                                # Only process entries with valid event IDs and channels
                                $validEventId = $false
                                $eventId = 0
                                try {
                                    $eventId = [int]$eventIdString
                                    $validEventId = $true
                                } catch {
                                    $validEventId = $false
                                }
                                
                                if ($validEventId -and 
                                    $EventChannelFilters.ContainsKey($channel) -and 
                                    ($EventChannelFilters[$channel].Count -eq 0 -or 
                                     $EventChannelFilters[$channel] -contains $eventId)) {
                                    $filteredBatch += $entry
                                    $totalFiltered++
                                    
                                    # Track which channel matched
                                    if ($channelMatches.ContainsKey($channel)) {
                                        $channelMatches[$channel]++
                                    }
                                } else {
                                    $skippedEntries++
                                }
                            }
                            
                            # Create timeline entries from filtered batch
                            $evtRows = @()
                            foreach ($entry in $filteredBatch) {
                                # Extract TimeCreated and handle the timestamps
                                $dateTimeString = $entry.TimeCreated
                                
                                # Format timestamps consistently with other artifacts
                                $dateTimeFormatted = $dateTimeString
                                try {
                                    if ([string]::IsNullOrWhiteSpace($dateTimeString)) {
                                        $dateTimeFormatted = "Unknown"
                                    } 
                                    # Handle partial timestamps like "28:04.8"
                                    elseif ($dateTimeString -match '^\d+:\d+\.\d+$') {
                                        $dateTimeFormatted = "Time: $dateTimeString"
                                    } 
                                    # Format full timestamps and drop microseconds
                                    else {
                                        $dateTime = [datetime]::Parse($dateTimeString)
                                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                    }
                                } catch {
                                    # Keep original string if parsing fails
                                }
                                
                                $row = @{
                                    DateTime     = $dateTimeFormatted
                                    EventId      = $entry."EventId"
                                    Description  = $entry."Channel"
                                    Info         = $entry."MapDescription"
                                    DataDetails  = $entry."PayloadData1"
                                    DataPath     = $entry."PayloadData2"
                                    Computer     = $entry."Computer"
                                    EvidencePath = $entry."SourceFile"
                                }
                                $evtRows += Normalize-Row -Fields $row -ArtifactName "EventLogs"
                            }
                            
                            # Add to master timeline
                            $MasterTimeline += $evtRows
                            $totalAdded += $evtRows.Count
                        }
                        catch {
                            Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                        }
                        finally {
                            if (Test-Path $tempFile) {
                                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                    
                    $reader.Close()
                    
                    # Report on processing results
                    Write-Host "  Added $totalAdded event log entries from $($file.Name)" -ForegroundColor Green
                    
                    # Report final filter efficiency with channel breakdown
                    if ($totalProcessed -gt 0) {
                        $filterRatio = [math]::Round(($totalFiltered / $totalProcessed) * 100, 1)
                        Write-Host "  Filter efficiency: $totalFiltered of $totalProcessed entries ($filterRatio%) matched filters" -ForegroundColor Green
                        
                        # Show breakdown by channel
                        Write-Host "  Channel matches:" -ForegroundColor Yellow
                        foreach ($channel in $channelMatches.Keys | Sort-Object) {
                            $count = $channelMatches[$channel]
                            if ($count -gt 0) {
                                Write-Host "    $channel : $count matches" -ForegroundColor Gray
                            }
                        }
                    }
                    
                    if ($skippedEntries -gt 0) {
                        Write-Host "  Skipped $skippedEntries entries due to formatting issues or non-matching event IDs" -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
                }
                
                Update-OverallProgress -CurrentSource "Event Logs"
            }
        }
        else {
            Write-Host "  No Event Log files found" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  Event Log path not found: $EVTPath" -ForegroundColor Yellow
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
            # Use streaming approach for large files
            $reader = New-Object System.IO.StreamReader($file.FullName)
            $headerLine = $reader.ReadLine()
            
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList
            
            # Process the file line by line in batches
            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                
                # Skip empty lines
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                
                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++
                
                # Process in batches of the specified size
                if ($batchCount -ge $BatchSize) {
                    # Create temp CSV file for the batch
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    
                    try {
                        # Write header and batch to temp file
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        # Import batch data
                        $batchData = Import-Csv $tempFile
                        
                        # Process batch data using exact same logic as original code
                        $delRows = $batchData | ForEach-Object {
                            # Check if the path has a file extension (indicating it's a file, not a folder)
                            $isFile = $_."FileName" -match '.*\\[^\\]+\.[^\\\.]+$'
                            
                            $dataDetails = if ($isFile) {
                                # Extract just the filename if it's a file
                                $_."FileName" -replace '.*\\([^\\]+)$', '$1'
                            } else {
                                # It's a folder
                                "Folder Deletion"
                            }
                            
                            $row = @{
                                DateTime      = $_."DeletedOn"
                                DataPath      = $_."FileName"
                                Description   = "File System"
                                DataDetails   = $dataDetails
                                Info          = $_."FileType"
                                FileSize      = $_."FileSize"
                                EvidencePath  = $_."SourceName"
                            }
                            Normalize-Row -Fields $row -ArtifactName "FileDeletion"
                        }
                        
                        # Add to master timeline
                        $MasterTimeline += $delRows
                        $totalAdded += $delRows.Count
                        
                        # Update progress
                        if ($totalProcessed % 5000 -eq 0) {
                            Show-ProcessingProgress -Activity "Processing File Deletion: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                        }
                    }
                    catch {
                        Write-Host "    Error processing batch: $_" -ForegroundColor Red
                    }
                    finally {
                        # Clean up temp file
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                    
                    # Reset batch
                    $batch.Clear()
                    $batchCount = 0
                }
            }
            
            # Process any remaining lines
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    
                    $batchData = Import-Csv $tempFile
                    
                    # Process remaining batch with same logic
                    $delRows = $batchData | ForEach-Object {
                        # Check if the path has a file extension (indicating it's a file, not a folder)
                        $isFile = $_."FileName" -match '.*\\[^\\]+\.[^\\\.]+$'
                        
                        $dataDetails = if ($isFile) {
                            # Extract just the filename if it's a file
                            $_."FileName" -replace '.*\\([^\\]+)$', '$1'
                        } else {
                            # It's a folder
                            "Folder Deletion"
                        }
                        
                        $row = @{
                            DateTime      = $_."DeletedOn"
                            DataPath      = $_."FileName"
                            Description   = "File System"
                            DataDetails   = $dataDetails
                            Info          = $_."FileType"
                            FileSize      = $_."FileSize"
                            EvidencePath  = $_."SourceName"
                        }
                        Normalize-Row -Fields $row -ArtifactName "FileDeletion"
                    }
                    
                    $MasterTimeline += $delRows
                    $totalAdded += $delRows.Count
                }
                catch {
                    Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                }
                finally {
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            
            $reader.Close()
            
            # Report on processing results
            Write-Host "  Added $totalAdded file deletion entries from $($file.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
        }
        
        Update-OverallProgress -CurrentSource "File Deletion"
    }
} else {
    Write-Host "  No file deletion records found" -ForegroundColor Yellow
}

# Process LNK Files
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
                # Use streaming approach for large files
                $reader = New-Object System.IO.StreamReader($file.FullName)
                $headerLine = $reader.ReadLine()
                
                $batchCount = 0
                $totalProcessed = 0
                $totalAdded = 0
                $batch = New-Object System.Collections.ArrayList
                
                # Process the file line by line in batches
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    
                    # Skip empty lines
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    
                    [void]$batch.Add($line)
                    $batchCount++
                    $totalProcessed++
                    
                    # Process in batches of the specified size
                    if ($batchCount -ge $BatchSize) {
                        # Create temp CSV file for the batch
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        
                        try {
                            # Write header and batch to temp file
                            $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                            $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                            
                            # Import batch data
                            $batchData = Import-Csv $tempFile
                            
                            # First pass - Target Created
                            $lnkRows = $batchData | ForEach-Object {
                                $dataPathValue = $(if ($_."LocalPath") { 
                                                    $_."LocalPath" 
                                                } elseif ($_."TargetIDAbsolutePath") { 
                                                    $_."TargetIDAbsolutePath" 
                                                } else { 
                                                    $_."NetworkPath" 
                                                })
                                
                                $row = @{
                                    DateTime       = $_."TargetCreated"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    Info           = "Target Created"
                                    DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                        "Unknown Path" 
                                     } else { 
                                        Split-Path -Leaf $dataPathValue 
                                     })
                                    FileSize       = $_."FileSize"
                                    EvidencePath   = $_."SourceFile"
                                }
                                Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                            }
                            $MasterTimeline += $lnkRows
                            $totalAdded += $lnkRows.Count
                            
                            # Second pass - Source Created
                            $lnkRows = $batchData | ForEach-Object {
                                $dataPathValue = $(if ($_."LocalPath") { 
                                                    $_."LocalPath" 
                                                } elseif ($_."TargetIDAbsolutePath") { 
                                                    $_."TargetIDAbsolutePath" 
                                                } else { 
                                                    $_."NetworkPath" 
                                                })
                                
                                $row = @{
                                    DateTime       = $_."SourceCreated"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    Info           = "Source Created"
                                    DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                        "Unknown Path" 
                                     } else { 
                                        Split-Path -Leaf $dataPathValue 
                                     })
                                    FileSize       = $_."FileSize"
                                    EvidencePath   = $_."SourceFile"
                                }
                                Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                            }
                            $MasterTimeline += $lnkRows
                            $totalAdded += $lnkRows.Count
                            
                            # Third pass - Target Modified
                            $lnkRows = $batchData | ForEach-Object {
                                $dataPathValue = $(if ($_."LocalPath") { 
                                                    $_."LocalPath" 
                                                } elseif ($_."TargetIDAbsolutePath") { 
                                                    $_."TargetIDAbsolutePath" 
                                                } else { 
                                                    $_."NetworkPath" 
                                                })
                                
                                $row = @{
                                    DateTime       = $_."TargetModified"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    Info           = "Target Modified"
                                    DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                        "Unknown Path" 
                                     } else { 
                                        Split-Path -Leaf $dataPathValue 
                                     })
                                    FileSize       = $_."FileSize"
                                    EvidencePath   = $_."SourceFile"
                                }
                                Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                            }
                            $MasterTimeline += $lnkRows
                            $totalAdded += $lnkRows.Count
                            
                            # Update progress
                            if ($totalProcessed % 1000 -eq 0) {
                                Show-ProcessingProgress -Activity "Processing LNK Files: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                            }
                        }
                        catch {
                            Write-Host "    Error processing batch: $_" -ForegroundColor Red
                        }
                        finally {
                            # Clean up temp file
                            if (Test-Path $tempFile) {
                                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                            }
                        }
                        
                        # Reset batch
                        $batch.Clear()
                        $batchCount = 0
                    }
                }
                
                # Process any remaining lines
                if ($batch.Count -gt 0) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        $batchData = Import-Csv $tempFile
                        
                        # First pass - Target Created (for remaining batch)
                        $lnkRows = $batchData | ForEach-Object {
                            $dataPathValue = $(if ($_."LocalPath") { 
                                                $_."LocalPath" 
                                            } elseif ($_."TargetIDAbsolutePath") { 
                                                $_."TargetIDAbsolutePath" 
                                            } else { 
                                                $_."NetworkPath" 
                                            })
                            
                            $row = @{
                                DateTime       = $_."TargetCreated"
                                DataPath       = $dataPathValue
                                Description    = "File & Folder Access"
                                Info           = "Target Created"
                                DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                    "Unknown Path" 
                                 } else { 
                                    Split-Path -Leaf $dataPathValue 
                                 })
                                FileSize       = $_."FileSize"
                                EvidencePath   = $_."SourceFile"
                            }
                            Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                        }
                        $MasterTimeline += $lnkRows
                        $totalAdded += $lnkRows.Count
                        
                        # Second pass - Source Created (for remaining batch)
                        $lnkRows = $batchData | ForEach-Object {
                            $dataPathValue = $(if ($_."LocalPath") { 
                                                $_."LocalPath" 
                                            } elseif ($_."TargetIDAbsolutePath") { 
                                                $_."TargetIDAbsolutePath" 
                                            } else { 
                                                $_."NetworkPath" 
                                            })
                            
                            $row = @{
                                DateTime       = $_."SourceCreated"
                                DataPath       = $dataPathValue
                                Description    = "File & Folder Access"
                                Info           = "Source Created"
                                DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                    "Unknown Path" 
                                 } else { 
                                    Split-Path -Leaf $dataPathValue 
                                 })
                                FileSize       = $_."FileSize"
                                EvidencePath   = $_."SourceFile"
                            }
                            Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                        }
                        $MasterTimeline += $lnkRows
                        $totalAdded += $lnkRows.Count
                        
                        # Third pass - Target Modified (for remaining batch)
                        $lnkRows = $batchData | ForEach-Object {
                            $dataPathValue = $(if ($_."LocalPath") { 
                                                $_."LocalPath" 
                                            } elseif ($_."TargetIDAbsolutePath") { 
                                                $_."TargetIDAbsolutePath" 
                                            } else { 
                                                $_."NetworkPath" 
                                            })
                            
                            $row = @{
                                DateTime       = $_."TargetModified"
                                DataPath       = $dataPathValue
                                Description    = "File & Folder Access"
                                Info           = "Target Modified"
                                DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                    "Unknown Path" 
                                 } else { 
                                    Split-Path -Leaf $dataPathValue 
                                 })
                                FileSize       = $_."FileSize"
                                EvidencePath   = $_."SourceFile"
                            }
                            Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                        }
                        $MasterTimeline += $lnkRows
                        $totalAdded += $lnkRows.Count
                    }
                    catch {
                        Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                    }
                    finally {
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                
                $reader.Close()
                
                # Report on processing results
                Write-Host "  Added $totalAdded LNK entries from $($file.Name)" -ForegroundColor Green
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


# Display current MFT filter settings - ensure this completes before other output begins
Write-Host ""
Write-Host "  Current MFT Filters:" -ForegroundColor Yellow
Write-Host "  (You can customize these filters by editing the MFT filter variables in the script)" -ForegroundColor Yellow
Write-Host "  -----------------------------------------" -ForegroundColor Yellow
Write-Host "  File Extension Filters:" -ForegroundColor Gray
foreach ($ext in $MFTExtensionFilter | Sort-Object) {
    Write-Host "    $ext" -ForegroundColor Gray
}
Write-Host ""
Write-Host "  Path Filters:" -ForegroundColor Gray
foreach ($path in $MFTPathFilter | Sort-Object) {
    Write-Host "    $path" -ForegroundColor Gray
}
Write-Host "  -----------------------------------------" -ForegroundColor Yellow
Write-Host ""

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
                $extensionMatches = @{}
                $pathMatches = @{}
                
                # Initialize counters for each filter
                foreach ($ext in $MFTExtensionFilter) {
                    $extensionMatches[$ext] = 0
                }
                foreach ($path in $MFTPathFilter) {
                    $pathMatches[$path] = 0
                }
                
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
                        
                        # Convert array to regex pattern
                        $extensionPattern = "^(" + ($MFTExtensionFilter -join "|").Replace(".", "\.") + ")$"
                        $pathPattern = "(" + ($MFTPathFilter -join "|") + ")"

                        # Filter for relevant files
                        $filteredData = $batchData | Where-Object {
                            $extensionMatch = $_.Extension -match $extensionPattern
                            $pathMatch = $_.ParentPath -match $pathPattern
                            
                            # Track which filters matched
                            if ($extensionMatch) {
                                foreach ($ext in $MFTExtensionFilter) {
                                    if ($_.Extension -eq $ext) {
                                        $extensionMatches[$ext]++
                                        break
                                    }
                                }
                            }
                            
                            if ($pathMatch) {
                                foreach ($path in $MFTPathFilter) {
                                    if ($_.ParentPath -match $path) {
                                        $pathMatches[$path]++
                                        break
                                    }
                                }
                            }
                            
                            return ($extensionMatch -and $pathMatch)
                        }
                        
                        # Process filtered entries
                        $mftRows = $filteredData | ForEach-Object {
                            $dt = try { [datetime]::Parse($_.Created0x10).ToString("yyyy-MM-dd HH:mm:ss") } catch { $_.Created0x10 }
                            $row = @{
                                DateTime       = $dt
                                DataPath       = $_."ParentPath"
                                DataDetails    = $_."FileName"
                                Description    = "File System"
                                Info           = "File Created"
                                FileSize       = $_."FileSize"
                                FileExtension  = $_."Extension"
                            }
                            Normalize-Row -Fields $row -ArtifactName "MFT"
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
                        $extensionMatch = $_.Extension -match $extensionPattern
                        $pathMatch = $_.ParentPath -match $pathPattern
                        
                        # Track which filters matched
                        if ($extensionMatch) {
                            foreach ($ext in $MFTExtensionFilter) {
                                if ($_.Extension -eq $ext) {
                                    $extensionMatches[$ext]++
                                    break
                                }
                            }
                        }
                        
                        if ($pathMatch) {
                            foreach ($path in $MFTPathFilter) {
                                if ($_.ParentPath -match $path) {
                                    $pathMatches[$path]++
                                    break
                                }
                            }
                        }
                        
                        return ($extensionMatch -and $pathMatch)
                    }
                    
                    $mftRows = $filteredData | ForEach-Object {
                        $dt = try { [datetime]::Parse($_.Created0x10).ToString("yyyy-MM-dd HH:mm:ss") } catch { $_.Created0x10 }
                        $row = @{
                            DateTime       = $dt
                            DataPath       = $_."ParentPath"
                            DataDetails    = $_."FileName"
                            Description    = "File System"
                            Info           = "File Created"
                            FileSize       = $_."FileSize"
                            FileExtension  = $_."Extension"
                        }
                        Normalize-Row -Fields $row -ArtifactName "MFT"
                    }
                    
                    $MasterTimeline += $mftRows
                    $totalRowsAdded += $mftRows.Count
                    $totalEntriesProcessed += $batch.Count
                    
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
                
                $reader.Close()
                
                # Report on filter matches
                Write-Host "  Processed $totalEntriesProcessed MFT entries, added $totalRowsAdded to timeline from $($file.Name)" -ForegroundColor Green
                
                Write-Host "  MFT Filter Matches:" -ForegroundColor Yellow
                
                Write-Host "  Extension Filter Matches:" -ForegroundColor Gray
                foreach ($ext in $extensionMatches.Keys | Sort-Object) {
                    $count = $extensionMatches[$ext]
                    if ($count -gt 0) {
                        Write-Host "    $ext : $count matches" -ForegroundColor Gray
                    }
                }
                
                Write-Host "  Path Filter Matches:" -ForegroundColor Gray
                foreach ($path in $pathMatches.Keys | Sort-Object) {
                    $count = $pathMatches[$path]
                    if ($count -gt 0) {
                        Write-Host "    $path : $count matches" -ForegroundColor Gray
                    }
                }
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
# Process Prefetch Files
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
                # Use streaming approach for large files
                $reader = New-Object System.IO.StreamReader($file.FullName)
                $headerLine = $reader.ReadLine()
                
                $batchCount = 0
                $totalProcessed = 0
                $totalAdded = 0
                $batch = New-Object System.Collections.ArrayList
                
                # Process the file line by line in batches
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    
                    # Skip empty lines
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    
                    [void]$batch.Add($line)
                    $batchCount++
                    $totalProcessed++
                    
                    # Process in batches of the specified size
                    if ($batchCount -ge $BatchSize) {
                        # Create temp CSV file for the batch
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        
                        try {
                            # Write header and batch to temp file
                            $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                            $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                            
                            # Import batch data
                            $batchData = Import-Csv $tempFile
                            
                            # Process batch data using exact same field mappings as your original code
                            $peRows = $batchData | ForEach-Object {
                                $row = @{
                                    DateTime     = $_."LastRun"
                                    DataPath     = $_."SourceFilename"
                                    Info         = "Last Run"
                                    DataDetails  = $_."ExecutableName"
                                    Description  = "Program Execution"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Prefetch Files"
                            }
                            
                            # Add to master timeline
                            $MasterTimeline += $peRows
                            $totalAdded += $peRows.Count
                            
                            # Update progress
                            if ($totalProcessed % 5000 -eq 0) {
                                Show-ProcessingProgress -Activity "Processing Prefetch Files: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                            }
                        }
                        catch {
                            Write-Host "    Error processing batch: $_" -ForegroundColor Red
                        }
                        finally {
                            # Clean up temp file
                            if (Test-Path $tempFile) {
                                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                            }
                        }
                        
                        # Reset batch
                        $batch.Clear()
                        $batchCount = 0
                    }
                }
                
                # Process any remaining lines
                if ($batch.Count -gt 0) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        $batchData = Import-Csv $tempFile
                        
                        # Process remaining batch with same field mappings
                        $peRows = $batchData | ForEach-Object {
                            $row = @{
                                DateTime     = $_."LastRun"
                                DataPath     = $_."SourceFilename"
                                Info         = "Last Run"
                                DataDetails  = $_."ExecutableName"
                                Description  = "Program Execution"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Prefetch Files"
                        }
                        
                        $MasterTimeline += $peRows
                        $totalAdded += $peRows.Count
                    }
                    catch {
                        Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                    }
                    finally {
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                
                $reader.Close()
                
                # Report on processing results
                Write-Host "  Added $totalAdded prefetch entries from $($file.Name)" -ForegroundColor Green
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
                                Description  =  $_."Category"
                                DataDetails  = $_."Description"
                                Info         = "Last Write"
                                EvidencePath = $_."HivePath"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Registry"
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
                                Description  =  $_."Category"
                                DataDetails  = $_."Description"
                                Info         = "Last Write"
                                EvidencePath = $_."HivePath"
                        }
                        Normalize-Row -Fields $row -ArtifactName "Registry"
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
                # Use streaming approach for large files
                $reader = New-Object System.IO.StreamReader($file.FullName)
                $headerLine = $reader.ReadLine()
                
                $batchCount = 0
                $totalProcessed = 0
                $totalAdded = 0
                $batch = New-Object System.Collections.ArrayList
                
                # Process the file line by line in batches
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    
                    # Skip empty lines
                    if ([string]::IsNullOrWhiteSpace($line)) { continue }
                    
                    [void]$batch.Add($line)
                    $batchCount++
                    $totalProcessed++
                    
                    # Process in batches of the specified size
                    if ($batchCount -ge $BatchSize) {
                        # Create temp CSV file for the batch
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        
                        try {
                            # Write header and batch to temp file
                            $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                            $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                            
                            # Import batch data
                            $batchData = Import-Csv $tempFile
                            
                            # First pass - Last Write Time
                            $shellRows = $batchData | ForEach-Object {
                                $row = @{
                                    DateTime    = $_."LastWriteTime"
                                    DataPath    = $_."AbsolutePath"
                                    DataDetails = $_."Value"
                                    Description = "File & Folder Access"
                                    Info        = "Last Write"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Shellbags"
                            }
                            $MasterTimeline += $shellRows
                            $totalAdded += $shellRows.Count
                            
                            # Second pass - First Interacted
                            $shellRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."FirstInteracted") } | ForEach-Object {
                                $row = @{
                                    DateTime    = $_."FirstInteracted"
                                    DataPath    = $_."AbsolutePath"
                                    DataDetails = $_."Value"
                                    Description = "File & Folder Access"
                                    Info        = "First Interacted"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Shellbags"
                            }
                            $MasterTimeline += $shellRows
                            $totalAdded += $shellRows.Count
                            
                            # Third pass - Last Interacted
                            $shellRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."LastInteracted") } | ForEach-Object {
                                $row = @{
                                    DateTime    = $_."LastInteracted"
                                    DataPath    = $_."AbsolutePath"
                                    DataDetails = $_."Value"
                                    Description = "File & Folder Access"
                                    Info        = "Last Interacted"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Shellbags"
                            }
                            $MasterTimeline += $shellRows
                            $totalAdded += $shellRows.Count
                            
                            # Update progress
                            if ($totalProcessed % 1000 -eq 0) {
                                Show-ProcessingProgress -Activity "Processing Shellbags: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                            }
                        }
                        catch {
                            Write-Host "    Error processing batch: $_" -ForegroundColor Red
                        }
                        finally {
                            # Clean up temp file
                            if (Test-Path $tempFile) {
                                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                            }
                        }
                        
                        # Reset batch
                        $batch.Clear()
                        $batchCount = 0
                    }
                }
                
                # Process any remaining lines
                if ($batch.Count -gt 0) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        $batchData = Import-Csv $tempFile
                        
                        # First pass - Last Write Time (for remaining batch)
                        $shellRows = $batchData | ForEach-Object {
                            $row = @{
                                DateTime    = $_."LastWriteTime"
                                DataPath    = $_."AbsolutePath"
                                DataDetails = $_."Value"
                                Description = "File & Folder Access"
                                Info        = "Last Write"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Shellbags"
                        }
                        $MasterTimeline += $shellRows
                        $totalAdded += $shellRows.Count
                        
                        # Second pass - First Interacted (for remaining batch)
                        $shellRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."FirstInteracted") } | ForEach-Object {
                            $row = @{
                                DateTime    = $_."FirstInteracted"
                                DataPath    = $_."AbsolutePath"
                                DataDetails = $_."Value"
                                Description = "File & Folder Access"
                                Info        = "First Interacted"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Shellbags"
                        }
                        $MasterTimeline += $shellRows
                        $totalAdded += $shellRows.Count
                        
                        # Third pass - Last Interacted (for remaining batch)
                        $shellRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."LastInteracted") } | ForEach-Object {
                            $row = @{
                                DateTime    = $_."LastInteracted"
                                DataPath    = $_."AbsolutePath"
                                DataDetails = $_."Value"
                                Description = "File & Folder Access"
                                Info        = "Last Interacted"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Shellbags"
                        }
                        $MasterTimeline += $shellRows
                        $totalAdded += $shellRows.Count
                    }
                    catch {
                        Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                    }
                    finally {
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                
                $reader.Close()
                
                # Report on processing results
                Write-Host "  Added $totalAdded shellbag entries from $($file.Name)" -ForegroundColor Green
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
# Web History
Write-Host "Processing Web History" -ForegroundColor Cyan
if (Test-Path $WebResultsPath) {
    Show-ProcessingProgress -Activity "Processing Web History" -Status "File: $([System.IO.Path]::GetFileName($WebResultsPath))" -Current 1 -Total 1 -NestedLevel 1
    
    try {
        # Use streaming approach for large files
        $reader = New-Object System.IO.StreamReader($WebResultsPath)
        $headerLine = $reader.ReadLine()
        
        $batchCount = 0
        $totalProcessed = 0
        $totalAdded = 0
        $batch = New-Object System.Collections.ArrayList
        
        # Process the file line by line in batches
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            [void]$batch.Add($line)
            $batchCount++
            $totalProcessed++
            
            # Process in batches of the specified size
            if ($batchCount -ge $BatchSize) {
                # Create temp CSV file for the batch
                $tempFile = [System.IO.Path]::GetTempFileName()
                
                try {
                    # Write header and batch to temp file
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    
                    # Import batch data
                    $batchData = Import-Csv $tempFile
                    
                    # Process batch data with special URL handling
                    $webRows = $batchData | ForEach-Object {
                        # Extract filename if URL starts with file://
                        $dataDetails = $_."Title"
                        $url = $_."URL"
                        
                        # Default description
                        $description = "Web Activity"
                        
                        # Check if the URL starts with file:// and extract the filename
                        if ($url -match "^file:///") {
                            # Extract filename after the last slash
                            if ($url -match "/([^/]+)$") {
                                $filename = $matches[1]
                                # Use the filename as DataDetails
                                $dataDetails = $filename
                            }
                            # Change description to File & Folder Access for file:// URLs
                            $description = "File & Folder Access"
                        }
                        # Check for search URLs
                        elseif ($url -match "search|query|q=|p=|find|lookup|google\.com/search|bing\.com/search|duckduckgo\.com/\?q=|yahoo\.com/search") {
                            $description = "Web Search"
                        }
                        # Check for download URLs
                        elseif ($url -match "download|\.exe$|\.zip$|\.rar$|\.7z$|\.msi$|\.iso$|\.pdf$|\.dll$|\/downloads\/") {
                            $description = "Web Download"
                        }
                        
                        $row = @{
                            DateTime     = $_."Visit Time"
                            DataPath     = $url
                            Info         = $_."Web Browser"
                            DataDetails  = $dataDetails
                            Description  = $description
                            User         = $_."User Profile"
                        }
                        Normalize-Row -Fields $row -ArtifactName "WebHistory"
                    }
                    
                    # Add to master timeline
                    $MasterTimeline += $webRows
                    $totalAdded += $webRows.Count
                    
                    # Update progress
                    if ($totalProcessed % 5000 -eq 0) {
                        Show-ProcessingProgress -Activity "Processing Web History" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                    }
                }
                catch {
                    Write-Host "    Error processing batch: $_" -ForegroundColor Red
                }
                finally {
                    # Clean up temp file
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
                
                # Reset batch
                $batch.Clear()
                $batchCount = 0
            }
        }
        
        # Process any remaining lines
        if ($batch.Count -gt 0) {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                
                $batchData = Import-Csv $tempFile
                
                # Process remaining batch with same logic
                $webRows = $batchData | ForEach-Object {
                    # Extract filename if URL starts with file://
                    $dataDetails = $_."Title"
                    $url = $_."URL"
                    
                    # Default description
                    $description = "Web Activity"
                    
                    # Check if the URL starts with file:// and extract the filename
                    if ($url -match "^file:///") {
                        # Extract filename after the last slash
                        if ($url -match "/([^/]+)$") {
                            $filename = $matches[1]
                            # Use the filename as DataDetails
                            $dataDetails = $filename
                        }
                        # Change description to File & Folder Access for file:// URLs
                        $description = "File & Folder Access"
                    }
                    # Check for search URLs
                    elseif ($url -match "search|query|q=|p=|find|lookup|google\.com/search|bing\.com/search|duckduckgo\.com/\?q=|yahoo\.com/search") {
                        $description = "Web Search"
                    }
                    # Check for download URLs
                    elseif ($url -match "download|\.exe$|\.zip$|\.rar$|\.7z$|\.msi$|\.iso$|\.pdf$|\.dll$|\/downloads\/") {
                        $description = "Web Download"
                    }
                    
                    $row = @{
                        DateTime     = $_."Visit Time"
                        DataPath     = $url
                        Info         = $_."Web Browser"
                        DataDetails  = $dataDetails
                        Description  = $description
                        User         = $_."User Profile"
                    }
                    Normalize-Row -Fields $row -ArtifactName "WebHistory"
                }
                
                $MasterTimeline += $webRows
                $totalAdded += $webRows.Count
            }
            catch {
                Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
            }
            finally {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        $reader.Close()
        
        # Report on processing results
        Write-Host "  Added $totalAdded web history entries from $([System.IO.Path]::GetFileName($WebResultsPath))" -ForegroundColor Green
    } catch {
        Write-Host "  Error processing web history: $_" -ForegroundColor Red
    }
    
    Update-OverallProgress -CurrentSource "Web History"
} else {
    Write-Host "  Web history file not found: $WebResultsPath" -ForegroundColor Yellow
}
# Process Chainsaw CSV files
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
        
            # Check if this is an MFT file based on filename only
            $isMFTFile = $chainsawFile.Name -like "*MFT*"
            
            # Use streaming approach for large files
            $reader = New-Object System.IO.StreamReader($chainsawFile.FullName)
            $headerLine = $reader.ReadLine()
            
            # If not determined by filename, check column headers
            $headers = $headerLine -split ','
            if (-not $isMFTFile) {
                $isMFTFile = $headers -contains "FileNameCreated0x30"
            }
            
            # Select appropriate timestamp field
            $timestampField = if ($isMFTFile) { "FileNameCreated0x30" } else { "timestamp" }
            
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList
            
            # Process the file line by line in batches
            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                
                # Skip empty lines
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                
                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++
                
                # Process in batches of the specified size
                if ($batchCount -ge $BatchSize) {
                    # Create temp CSV file for the batch
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    
                    try {
                        # Write header and batch to temp file
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        # Import batch data
                        $batchData = Import-Csv $tempFile
                        
                        # Process batch data
                        $chainsawRows = $batchData | ForEach-Object {
                            # Improved timestamp parsing that handles ISO 8601 format with timezone info
                            $dt = if ($_.$timestampField) {
                                try { 
                                    # Try parsing with timezone handling
                                    $dateObj = [datetime]::Parse($_.$timestampField, [System.Globalization.CultureInfo]::InvariantCulture, 
                                        [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                                    $dateObj.ToString("yyyy-MM-dd HH:mm:ss")
                                } 
                                catch { 
                                    # If parsing fails, keep the original string
                                    $_.$timestampField 
                                }
                            } else {
                                # If no timestamp, use current date/time
                                (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            }
                        
                            $row = @{
                                DateTime           = $dt
                                EventId            = $_."Event ID"
                                Description        = "Chainsaw"
                                Info               = $_."detections"
                                DataPath = $(if ($_."Threat Path") { 
                                    $_."Threat Path" 
                                } elseif ($_."Scheduled Task Name") { 
                                    $_."Scheduled Task Name" 
                                } elseif ($_."FileNamePath") { 
                                    $_."FileNamePath" 
                                } elseif ($_."Information") { 
                                    $_."Information" 
                                } elseif ($_."HostApplication") { 
                                    $_."HostApplication" 
                                } elseif ($_."Service File Name") { 
                                    $_."Service File Name" 
                                } elseif ($_."Event Data") { 
                                    $_."Event Data" 
                                } else {
                                    ""
                                })
                                DataDetails = $(if ($_."Threat Name") { 
                                    $_."Threat Name" 
                                } elseif ($_."Service Name") { 
                                    $_."Service Name" 
                                } else {
                                    ""  
                                })
                                User = $(if ($_."User") { 
                                    $_."User" 
                                } elseif ($_."User Name") { 
                                    $_."User Name" 
                                } else {
                                    "Unknown User"
                                })
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
                        
                        # Add to master timeline
                        $MasterTimeline += $chainsawRows
                        $totalAdded += $chainsawRows.Count
                        
                        # Update progress
                        if ($totalProcessed % 5000 -eq 0) {
                            Show-ProcessingProgress -Activity "Processing Chainsaw: $($chainsawFile.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                        }
                    }
                    catch {
                        Write-Host "    Error processing batch: $_" -ForegroundColor Red
                    }
                    finally {
                        # Clean up temp file
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                    
                    # Reset batch
                    $batch.Clear()
                    $batchCount = 0
                }
            }
            
            # Process any remaining lines
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    
                    $batchData = Import-Csv $tempFile
                    
                    # Process remaining batch with same logic
                    $chainsawRows = $batchData | ForEach-Object {
                        # Improved timestamp parsing that handles ISO 8601 format with timezone info
                        $dt = if ($_.$timestampField) {
                            try { 
                                # Try parsing with timezone handling
                                $dateObj = [datetime]::Parse($_.$timestampField, [System.Globalization.CultureInfo]::InvariantCulture, 
                                    [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                                $dateObj.ToString("yyyy-MM-dd HH:mm:ss")
                            } 
                            catch { 
                                # If parsing fails, keep the original string
                                $_.$timestampField 
                            }
                        } else {
                            # If no timestamp, use current date/time
                            (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    
                        $row = @{
                            DateTime           = $dt
                            EventId            = $_."Event ID"
                            Description        = "Chainsaw"
                            Info               = $_."detections"
                            DataPath = $(if ($_."Threat Path") { 
                                $_."Threat Path" 
                            } elseif ($_."Scheduled Task Name") { 
                                $_."Scheduled Task Name" 
                            } elseif ($_."FileNamePath") { 
                                $_."FileNamePath" 
                            } elseif ($_."Information") { 
                                $_."Information" 
                            } elseif ($_."HostApplication") { 
                                $_."HostApplication" 
                            } elseif ($_."Service File Name") { 
                                $_."Service File Name" 
                            } elseif ($_."Event Data") { 
                                $_."Event Data" 
                            } else {
                                ""
                            })
                            DataDetails = $(if ($_."Threat Name") { 
                                $_."Threat Name" 
                            } elseif ($_."Service Name") { 
                                $_."Service Name" 
                            } else {
                                ""  
                            })
                            User = $(if ($_."User") { 
                                $_."User" 
                            } elseif ($_."User Name") { 
                                $_."User Name" 
                            } else {
                                "Unknown User"
                            })
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
                    $totalAdded += $chainsawRows.Count
                }
                catch {
                    Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                }
                finally {
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            
            $reader.Close()
            
            # Report on processing results
            Write-Host "  Added $totalAdded entries from $($chainsawFile.Name)" -ForegroundColor Green
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

# Filter out rows with empty DateTime values
Write-Host "Removing entries with missing timestamps..." -ForegroundColor Cyan
$originalCount = $MasterTimeline.Count
$MasterTimeline = $MasterTimeline | Where-Object { 
    -not [string]::IsNullOrWhiteSpace($_.DateTime) 
}
$filteredCount = $MasterTimeline.Count
$removedCount = $originalCount - $filteredCount
Write-Host "  Removed $removedCount entries with missing timestamps, $filteredCount entries remaining" -ForegroundColor Green

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
    $totalRows = $OrderedTimeline.Count
    $maxRowsPerFile = 1000000000  # 1 Million row max per CSV Export
    
    if ($totalRows -le $maxRowsPerFile) {
        # If under the threshold, just create a single file
        $OrderedTimeline | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        Write-Host "CSV timeline written to: $OutputFile" -ForegroundColor Green
    } else {
        # Need to split into multiple files
        $fileCounter = 1
        $fileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($OutputFile)
        $fileExtension = [System.IO.Path]::GetExtension($OutputFile)
        $fileDirectory = [System.IO.Path]::GetDirectoryName($OutputFile)
        
        for ($i = 0; $i -lt $totalRows; $i += $maxRowsPerFile) {
            $endIndex = [Math]::Min($i + $maxRowsPerFile - 1, $totalRows - 1)
            $chunk = $OrderedTimeline[$i..$endIndex]
            
            $chunkFileName = if ($fileDirectory) {
                Join-Path -Path $fileDirectory -ChildPath "$fileBaseName-part$fileCounter$fileExtension"
            } else {
                "$fileBaseName-part$fileCounter$fileExtension"
            }
            
            $chunk | Export-Csv -Path $chunkFileName -NoTypeInformation -Encoding UTF8
            Write-Host "CSV timeline part $fileCounter written to: $chunkFileName" -ForegroundColor Green
            $fileCounter++
        }
        
        Write-Host "CSV timeline split into $($fileCounter-1) parts due to large size" -ForegroundColor Yellow
    }

    }
    "json" {
    # Ensure proper array format for SDL
    $jsonContent = $OrderedTimeline | ConvertTo-Json -Depth 4
    
    # If it's not already an array (starts with [), wrap it in brackets
    if (-not $jsonContent.TrimStart().StartsWith('[')) {
        $jsonContent = "[$jsonContent]"
    }
    
    # Use UTF8NoBOM encoding for SIEM compatibility
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($OutputFile, $jsonContent, $utf8NoBom)
    
    Write-Host "JSON timeline written to: $OutputFile" -ForegroundColor Green
}
}

Write-Host "Timeline export complete. Total entries: $($MasterTimeline.Count)" -ForegroundColor Cyan
Write-Host "Output file: $OutputFile" -ForegroundColor Green
# Logfile
Write-Host "Script completed. Log file saved to: $LogFilePath" -ForegroundColor Cyan
Stop-Transcript
