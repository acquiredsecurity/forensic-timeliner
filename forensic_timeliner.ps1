# Parameter Block
param (
    [string]$BaseDir = "C:\triage", 
    [string]$KapeDirectory = "$BaseDir\kape_out",                                            # Path to main KAPE timeline folder and csv output from EZ Tools
    [string]$ChainsawDirectory = "$BaseDir\chainsaw",                                        # Directory containing Chainsaw CSV files
    [string]$HayabusaDirectory = "$BaseDir\hayabusa", 
    [string]$NirsoftDirectory = "$BaseDir\browsinghistory",                                  # Directory containing Hayabusa CSV files                                                                # Skip Hayabusa processing
	 [string]$AxiomDirectory = "$BaseDir\axiom",
    [string]$OutputFile = "$BaseDir\timeline\Forensic_Timeliner.csv",                        # Output timeline file
    [ValidateSet("xlsx", "csv", "json")]
    [string]$ExportFormat = "csv",                                                           # Output Format  CSV for timeline creation with Json and Xlsx Options
    [switch]$SkipEventLogs,                                                                  # Skip event logs processing in EZ tools
    [switch]$ProcessKape,
    [switch]$ProcessChainsaw,
    [switch]$ProcessHayabusa,	
    [switch]$ProcessAxiom,                                                                   # Process Axiom CSV output
    [switch]$ProcessNirsoftWebHistory,
    [string]$FileDeletionSubDir = "FileDeletion", 
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
    [Alias("h")]
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


function Show-Help {
    Write-Host ""
    Write-Host "Forensic Timeliner Help Menu" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------" -ForegroundColor Cyan
    Write-Host "This tool consolidates and normalizes digital forensic artifact data"
    Write-Host "from multiple tools (Axiom, EZ Tools, Chainsaw, Hayabusa, Nirsoft)"
    Write-Host "into a single forensic timeline."
    Write-Host ""

    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -BaseDir <path>              Base output path (Default: C:\triage)"
    Write-Host "  -OutputFile <path>           Timeline output file (Default: $BaseDir\timeline\Forensic_Timeliner.csv)"
    Write-Host "  -ExportFormat <csv|json|xlsx> Output format (Default: csv)"
    Write-Host "  -BatchSize <int>             Number of lines to process per batch (Default: 10000)"
    Write-Host "  -StartDate <datetime>        Only include events after this date"
    Write-Host "  -EndDate <datetime>          Only include events before this date"
    Write-Host "  -Deduplicate                 Enable deduplication of timeline entries"
    Write-Host "  -Interactive                 Launch interactive configuration menu"
    Write-Host "  -Help                        Display this help menu"
    Write-Host ""

    Write-Host "Tool Switches:" -ForegroundColor Yellow
    Write-Host "  -ProcessKape                 Process EZ Tools KAPE output"
    Write-Host "  -ProcessChainsaw             Process Chainsaw CSV exports"
    Write-Host "  -ProcessHayabusa             Process Hayabusa CSV exports"
    Write-Host "  -ProcessAxiom                Process Magnet Axiom CSV exports"
    Write-Host "  -ProcessNirsoftWebHistory    Process Nirsoft BrowsingHistoryView CSV"
    Write-Host "  -SkipEventLogs               Skip EZ Tools Event Log processing"
    Write-Host ""

    Write-Host "Supported Artifacts:" -ForegroundColor Yellow
    Write-Host "  EZ Tools (KAPE):"
    Write-Host "      Artifact                                         Searches default path for:" -ForegroundColor Yellow
    Write-Host "    - Amcache (AmcacheParser)                          $BaseDir\kape_out\ProgramExecution\*ssociatedFileEntries.csv"
    Write-Host "    - AppCompatCache (Shim)                            $BaseDir\kape_out\ProgramExecution\*AppCompatCache*.csv"
    Write-Host "    - Deleted Files (RBCmd)                            $BaseDir\kape_out\FileDeletion\*RBCmd*.csv"
    Write-Host "    - Event Logs (EvtxECmd)                            $BaseDir\kape_out\EventLogs\*.csv"
    Write-Host "    - Jump Lists (JLECmd)                              $BaseDir\kape_out\FileFolderAccess\*_AutomaticDestinations.csv"
    Write-Host "    - LNK Files (LECmd)                                $BaseDir\kape_out\FileFolderAccess\*_LECmd_Output.csv"
    Write-Host "    - MFT (MFTECmd)                                    $BaseDir\kape_out\FileSystem\*MFT_Out*.csv"
    Write-Host "    - Prefetch (PECmd)                                 $BaseDir\kape_out\ProgramExecution\*_PECmd_Output.csv"
    Write-Host "    - Registry (RECmd)                                 $BaseDir\kape_out\Registry\*_RECmd_Batch_Kroll_Batch_Output.csv"
    Write-Host "    - Shellbags (SBECmd)                               $BaseDir\kape_out\FileFolderAccess\*_UsrClass\.csv OR _NTUSER\.csv"
    
    Write-Host ""

    Write-Host "  Axiom (Magnet):"
    Write-Host "      Artifact                                         Searches default path for:" -ForegroundColor Yellow
    Write-Host "    - Amcache                                          $BaseDir\axiom\AmCache File Entries.csv"
    Write-Host "    - AppCompatCache (Shim)                            $BaseDir\axiom\Shim Cache.csv"
    Write-Host "    - AutoRuns                                         $BaseDir\axiom\AutoRun Items.csv"
    Write-Host "    - Chrome Web History                               $BaseDir\axiom\Chrome Web History.csv"
    Write-Host "    - Edge/IE Main History                             $BaseDir\axiom\Edge-Internet Explorer 10-11 Main History.csv"
    Write-Host "    - Jump Lists                                       $BaseDir\axiom\Jump Lists.csv"
    Write-Host "    - LNK Files                                        $BaseDir\axiom\LNK Files.csv"
    Write-Host "    - MRU (Folder Access)                              $BaseDir\axiom\MRU Folder Access.csv"
    Write-Host "    - MRU (Open-Saved Files)                           $BaseDir\axiom\MRU Opened-Saved Files.csv"
    Write-Host "    - MRU (Recent Files, Folder Access)                $BaseDir\axiom\MRU Recent Files & Folders.csv"
    Write-Host "    - Prefetch                                         $BaseDir\axiom\Prefetch Files*.csv"
    Write-Host "    - Recycle Bin                                      $BaseDir\axiom\Recycle Bin.csv"
    Write-Host "    - Shellbags                                        $BaseDir\axiom\Shellbags.csv"
    Write-Host "    - UserAssist                                       $BaseDir\axiom\UserAssist.csv"
    Write-Host ""

    Write-Host "  Hayabusa:"
    Write-Host "    - Event Logs with Sigma rule matching              $BaseDir\hayabusa\hayabusa.csv"
    Write-Host ""

    Write-Host "  Chainsaw:"
    Write-Host "    - Sigma-correlated event logs                      $BaseDir\chainsaw\*.csv"
    Write-Host ""

    Write-Host "  Nirsoft:"
    Write-Host "    - Web Browsing History (via BrowsingHistoryView)   $BaseDir\nirsoft\*.csv"
    Write-Host ""

    Write-Host "Other Info:" -ForegroundColor Yellow
    Write-Host "  - Supports batch processing for large CSVs"
    Write-Host "  - Progress indicators for each source"
    Write-Host "  - Source count and export stats included"
    Write-Host ""

    Write-Host "Example Usage:" -ForegroundColor Cyan
    Write-Host "  .\forensic_timeliner.ps1 -i"
    Write-Host "  .\forensic_timeliner.ps1 -ProcessKape -ProcessAxiom -ExportFormat json"
    Write-Host ""

    Write-Host "For best results, organize tool exports into the default paths under BaseDir, and use interactive mode to specify custom paths."
    Write-Host ""
}

# Help Menu function
if ($Help) {
    Show-Help
    return
}

# Interactive Mode
if ($Interactive) {
    Write-Host "" -ForegroundColor Cyan
    Write-Host "====== Forensic Timeliner Interactive Configuration - which sources you would like to process and where they are located! ======" -ForegroundColor Cyan

    # Ask for export format first
    $exportFormatPrompt = Read-Host "Select output format: xlsx, csv, or json [Default: csv]"
    if ($exportFormatPrompt -and $exportFormatPrompt -in @("xlsx", "csv", "json")) {
        $ExportFormat = $exportFormatPrompt
    } else {
        $ExportFormat = "csv"
    }

    $fileExtension = ".$ExportFormat"
    $defaultOutputPath = "$BaseDir\timeline\Forensic_Timeliner$fileExtension"
    
    # Ask if User would like to process Kape/EZ Tool CSV Output
    $processKapePrompt = Read-Host "Include Kape / EZ Tool CSV Output? (y/n) [Default: n]"
    if ($processKapePrompt -eq "y") {
        $ProcessKape = $true
        
        # Prompt for Kape/EZ Tool directory
        $KapeDirectory = Read-Host "Enter the path to the Kape/EZ Tool CSV files"
        
        # Validate directory exists
        if (-not (Test-Path $KapeDirectory)) {
            Write-Host "  Warning: Kape/EZ Tool directory not found: $KapeDirectory" -ForegroundColor Yellow
            $createDir = Read-Host "  Create directory? (y/n) [Default: n]"
            if ($createDir -eq "y") {
                New-Item -Path $KapeDirectory -ItemType Directory -Force | Out-Null
                Write-Host "  Directory created: $KapeDirectory" -ForegroundColor Green
            } else {
                Write-Host "  Kape/EZ Tool processing will be skipped as directory doesn't exist" -ForegroundColor Yellow
                $ProcessKape = $false
            }
        } else {
            Write-Host "  Kape/EZ Tool processing will be included" -ForegroundColor Green
            
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
            
            # Ask if User would like to process Event Logs
            $processEventLogsPrompt = Read-Host "Include Windows Event Log processing from EZ/Kape tool output? (Chainsaw with Sigma already provides analysis for these logs. Enabling this will significantly increase processing time and timeline size) (y/n) [Default: y]"
            if ($processEventLogsPrompt -eq "n") {
                $SkipEventLogs = $true
                Write-Host "  Event log processing will be skipped" -ForegroundColor Yellow
            } else {
                $SkipEventLogs = $false
            }
        }
    } else {
        $ProcessKape = $false
        Write-Host "  Kape/EZ Tool processing will be skipped" -ForegroundColor Yellow
    }


# Ask if User would like to process Chainsaw CSV Output
$processChainsawPrompt = Read-Host "Include Chainsaw CSV Output? (y/n) [Default: n]"
if ($processChainsawPrompt -eq "y") {
    $ProcessChainsaw = $true
    
    # Prompt for Chainsaw directory
    $ChainsawDirectory = Read-Host "Enter the path to the Chainsaw CSV files"
    
    # Validate directory exists
    if (-not (Test-Path $ChainsawDirectory)) {
        Write-Host "  Warning: Chainsaw directory not found: $ChainsawDirectory" -ForegroundColor Yellow
        $createDir = Read-Host "  Create directory? (y/n) [Default: n]"
        if ($createDir -eq "y") {
            New-Item -Path $ChainsawDirectory -ItemType Directory -Force | Out-Null
            Write-Host "  Directory created: $ChainsawDirectory" -ForegroundColor Green
        } else {
            Write-Host "  Chainsaw processing will be skipped as directory doesn't exist" -ForegroundColor Yellow
            $ProcessChainsaw = $false
        }
    } else {
        Write-Host "  Chainsaw processing will be included" -ForegroundColor Green
    }
} else {
    $ProcessChainsaw = $false
    Write-Host "  Chainsaw processing will be skipped" -ForegroundColor Yellow
}

# Ask if User would like to process Hayabusa CSV Output
$processHayabusaPrompt = Read-Host "Include Hayabusa CSV Output? (y/n) [Default: n]"
if ($processHayabusaPrompt -eq "y") {
    $ProcessHayabusa = $true
    
    # Prompt for Hayabusa directory
    $HayabusaDirectory = Read-Host "Enter the path to the Hayabusa CSV files"
    
    # Validate directory exists
    if (-not (Test-Path $HayabusaDirectory)) {
        Write-Host "  Warning: Hayabusa directory not found: $HayabusaDirectory" -ForegroundColor Yellow
        $createDir = Read-Host "  Create directory? (y/n) [Default: n]"
        if ($createDir -eq "y") {
            New-Item -Path $HayabusaDirectory -ItemType Directory -Force | Out-Null
            Write-Host "  Directory created: $HayabusaDirectory" -ForegroundColor Green
        } else {
            Write-Host "  Hayabusa processing will be skipped as directory doesn't exist" -ForegroundColor Yellow
            $ProcessHayabusa = $false
        }
    } else {
        Write-Host "  Hayabusa processing will be included" -ForegroundColor Green
    }
} else {
    $ProcessHayabusa = $false
    Write-Host "  Hayabusa processing will be skipped" -ForegroundColor Yellow
}

# Ask if User would like to process Nirsoft Web History
$ProcessNirsoftWebHistoryPrompt = Read-Host "Include Nirsoft Web History (Nirsoft BrowsingHistoryView)? (y/n) [Default: n]"
if ($ProcessNirsoftWebHistoryPrompt -eq "y") {
    $ProcessNirsoftWebHistory = $true

    # Prompt for Nirsoft directory
    $NirsoftDirectory = Read-Host "Enter the path to the Nirsoft output directory"
    if (-not $NirsoftDirectory) {
        $NirsoftDirectory = "$BaseDir\browsinghistory"
    }

    # Try to find a CSV file and set WebResultsPath
    $fileMatch = Get-ChildItem -Path $NirsoftDirectory -Filter "*.csv" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($fileMatch) {
        $WebResultsPath = $fileMatch.FullName
        Write-Host "  Nirsoft Web History processing will be included" -ForegroundColor Green
    } else {
        Write-Host "  Warning: No CSV file found in: $NirsoftDirectory" -ForegroundColor Yellow
        $ProcessNirsoftWebHistory = $false
    }
} else {
    $ProcessNirsoftWebHistory = $false
    Write-Host "  Nirsoft Web History processing will be skipped" -ForegroundColor Yellow
}


# Ask if User would like to process Axiom CSV Output
$processAxiomPrompt = Read-Host "Include Axiom CSV Output? (y/n) [Default: n]"
if ($processAxiomPrompt -eq "y") {
    $ProcessAxiom = $true
    
    # Prompt for Axiom directory
    $AxiomDirectory = Read-Host "Enter the path to the Axiom CSV files"
    
    # Validate directory exists
    if (-not (Test-Path $AxiomDirectory)) {
        Write-Host "  Warning: Axiom directory not found: $AxiomDirectory" -ForegroundColor Yellow
        $createDir = Read-Host "  Create directory? (y/n) [Default: n]"
        if ($createDir -eq "y") {
            New-Item -Path $AxiomDirectory -ItemType Directory -Force | Out-Null
            Write-Host "  Directory created: $AxiomDirectory" -ForegroundColor Green
        } else {
            Write-Host "  Axiom processing will be skipped as directory doesn't exist" -ForegroundColor Yellow
            $ProcessAxiom = $false
        }
    } else {
        Write-Host "  Axiom processing will be included" -ForegroundColor Green
        

    }
} else {
    $ProcessAxiom = $false
    Write-Host "  Axiom processing will be skipped" -ForegroundColor Yellow
}
    

# safely change the extension if needed
    if (-not $OutputFile.EndsWith($fileExtension)) {
        $OutputFile = [System.IO.Path]::ChangeExtension($OutputFile, $fileExtension.TrimStart('.'))
    }

    # Advanced directory configuration (optional)
    $configureSubDirs = Read-Host "Configure Kape/EZ Tool subdirectories? Expected Kape/EZ Tool subdirectories are EventLogs, FileDeletion, FileFolderAccess, FileSystem, ProgramExecution, Registry (y/n) [Default: n]"
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

        # Path to save timeline to
        Write-Host "Where would you like to Save your Forensic Timeline to?? [Default: $defaultOutputPath]" -ForegroundColor Yellow

        # Actual input
        $OutputFile = Read-Host 
        if (-not $OutputFile) {
            $OutputFile = $defaultOutputPath
        } 
        }
        # Check if the path is a directory
        if (Test-Path $OutputFile -PathType Container) {
            # User provided only a directory, append default filename
            $OutputFile = Join-Path $OutputFile "Forensic_Timeliner.$ExportFormat"
            Write-Host "  Note: Directory path detected. Using file: $OutputFile" -ForegroundColor Yellow
        }

        # Set Log File Path to the same directory as the OutputFile
        $LogFilePath = Join-Path -Path (Split-Path $OutputFile -Parent) -ChildPath "ForensicTimeliner_Log_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt"
        Write-Host "Log file will be saved to: $LogFilePath" -ForegroundColor Cyan

        Write-Host "Interactive configuration complete. Running timeline build..." -ForegroundColor Green

        # Adjust extension based on export format
        $desiredExtension = "." + $ExportFormat.ToLower()
        $OutputFile = [System.IO.Path]::ChangeExtension($OutputFile, $desiredExtension)




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
                                                                                           
Mini Timeline Builder for Kape Output, Chainsaw +Sigma, WebhistoryView, Axiom and more ?!?!
| Made by https://github.com/acquiredsecurity 
| with help from the robots [o_o] 
| Review your evidence for unkown unknowns :-] !!!
- Build powerful timelines by combining output from digital forensic tools into a single timeline!!!
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
    "DateTime", "Tool", "ArtifactName", "EventId", "Description", "TimestampInfo", "DataPath", "DataDetails",
    "User", "Computer", "FileSize", "FileExtension", "UserSID", "MemberSID", "ProcessName", "IPAddress", "LogonType", "Count",
    "SourceAddress", "DestinationAddress", "ServiceType", "CommandLine", "SHA1", "EvidencePath"
    
)

# Define preferred field order for output
$PreferredFieldOrder = @(
    "DateTime",
    "TimestampInfo", 
    "ArtifactName",
    "Tool",
    "Description",
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

# Count the number of sources to process for overall progress tracking
$script:totalSources = 0

# Count EZ Tools CSV sources (matching Axiom-style block)
if ($ProcessKape) {
    $ezToolsCsvFiles = @(Get-ChildItem -Path $KapeDirectory -Recurse -Filter *.csv -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match "Amcache.*ssociatedFileEntries\.csv" -or
        $_.Name -match "AppCompatCache.*\.csv" -or
        $_.Name -match "_PECmd_Output\.csv" -or
        $_.Name -match "_LECmd_Output\.csv" -or
        $_.Name -match "_UsrClass\.csv" -or
        $_.Name -match "AutomaticDestinations.*\.csv" -or
        $_.Name -match "_RECmd_Batch_Kroll_Batch_Output\.csv" -or
        $_.Name -match "EvtxECmd.*\.csv" -or
        $_.Name -match "MFT_Out.*\.csv" -or
        $_.Name -match "RBCmd.*\.csv"
    })
    $script:totalSources += $ezToolsCsvFiles.Count
}

# Check Nirsoft
if (-not $SkipNirsoftWebHistory) {
    $NirsoftFiles = @(Get-ChildItem -Path $NirsoftDirectory -Filter *.csv -ErrorAction SilentlyContinue)
    $script:totalSources += $NirsoftFiles.Count
}

# Check for Chainsaw Files
$ChainsawFiles = @(Get-ChildItem -Path $ChainsawDirectory -Recurse -Filter *.csv -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "webResults.csv" })
$script:totalSources += $ChainsawFiles.Count


# Check Hayabusa
if (-not $SkipHayabusa) {
    $HayabusaFiles = @(Get-ChildItem -Path $HayabusaDirectory -Recurse -Filter *.csv -ErrorAction SilentlyContinue)
    $script:totalSources += $HayabusaFiles.Count
}

# Check Axiom - Count each artifact individually for accurate progress tracking
if ($ProcessAxiom) {
    $axiomArtifactFilters = @(
        "LNK Files.csv",
        "Jump Lists.csv",
        "UserAssist.csv",
        "Prefetch*.csv",
        "Shim Cache.csv",
        "Shellbags.csv",
        "AutoRun Items.csv",
        "MRU Opened-Saved Files.csv",
        "MRU Recent Files & Folders.csv",
        "MRU Folder Access.csv",
        "Chrome History.csv",
        "Edge History.csv",
        "Amcache.csv",
        "Recycle Bin.csv"
    )

    foreach ($filter in $axiomArtifactFilters) {
        $files = @(Get-ChildItem -Path $AxiomDirectory -Filter $filter -ErrorAction SilentlyContinue)
        $script:totalSources += $files.Count
    }
}

# Start overall progress tracking
Write-Progress -Activity "Building Forensic Timeline" -Status "Initializing" -PercentComplete 0 -Id 0

# Nirsoft Web History
if ($ProcessNirsoftWebHistory -and (Test-Path $WebResultsPath)) {
    Write-Host "Processing Nirsoft Web History" -ForegroundColor Cyan
    Show-ProcessingProgress -Activity "Processing Web History" -Status "File: $([System.IO.Path]::GetFileName($WebResultsPath))" -Current 1 -Total 1 -NestedLevel 1

    try {
        $reader = New-Object System.IO.StreamReader($WebResultsPath)
        $headerLine = $reader.ReadLine()
        $batchCount = 0
        $totalProcessed = 0
        $totalAdded = 0
        $batch = New-Object System.Collections.ArrayList

        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            [void]$batch.Add($line)
            $batchCount++
            $totalProcessed++

            if ($batchCount -ge $BatchSize) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    $batchData = Import-Csv $tempFile

                    $webRows = $batchData | ForEach-Object {
                        $url = $_."URL"
                        $dataDetails = $_."Title"
                        $dateTimeString = $_."Visit Time"

                        try {
                            $dateTime = [datetime]::ParseExact($dateTimeString, "M/d/yyyy h:mm:ss tt", $null)
                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        catch {
                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                            $dateTimeFormatted = ""
                        }

                        $description = "Web Activity"
                        if ($url -match "^file:///") {
                            if ($url -match "/([^/]+)$") {
                                $filename = $matches[1]
                                $dataDetails = $filename
                            }
                            $description = "File & Folder Access"
                        } elseif ($url -match "search|query|q=|p=|find|lookup|google\.com/search|bing\.com/search|duckduckgo\.com/\?q=|yahoo\.com/search") {
                            $description = "Web Search"
                        } elseif ($url -match "download|\.exe$|\.zip$|\.rar$|\.7z$|\.msi$|\.iso$|\.pdf$|\.dll$|\/downloads\/") {
                            $description = "Web Download"
                        }

                        $row = @{
                            DateTime      = $dateTimeFormatted
                            Tool          = "Nirsoft"
                            DataPath      = $url
                            TimestampInfo = "EventTime"
                            DataDetails   = $dataDetails
                            Description   = $description
                            User          = $_."User Profile"
                            EvidencePath  = $_."History File"
                        }

                        $browser = $_."Web Browser"
                        $artifactName = if ($browser) { "WebHistory - $browser" } else { "WebHistory" }
                        
                        Normalize-Row -Fields $row -ArtifactName $artifactName
                    }

                    $MasterTimeline += $webRows
                    $totalAdded += $webRows.Count
                }
                finally {
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }

                $batch.Clear()
                $batchCount = 0
            }
        }

        # Process remaining lines
        if ($batch.Count -gt 0) {
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                $batchData = Import-Csv $tempFile

                $webRows = $batchData | ForEach-Object {
                    $url = $_."URL"
                    $dataDetails = $_."Title"
                    $dateTimeString = $_."Visit Time"

                    try {
                        $dateTime = [datetime]::ParseExact($dateTimeString, "M/d/yyyy h:mm:ss tt", $null)
                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                    catch {
                        Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                        $dateTimeFormatted = ""
                    }

                    $description = "Web Activity"
                    if ($url -match "^file:///") {
                        if ($url -match "/([^/]+)$") {
                            $filename = $matches[1]
                            $dataDetails = $filename
                        }
                        $description = "File & Folder Access"
                    } elseif ($url -match "search|query|q=|p=|find|lookup|google\.com/search|bing\.com/search|duckduckgo\.com/\?q=|yahoo\.com/search") {
                        $description = "Web Search"
                    } elseif ($url -match "download|\.exe$|\.zip$|\.rar$|\.7z$|\.msi$|\.iso$|\.pdf$|\.dll$|\/downloads\/") {
                        $description = "Web Download"
                    }

                    $row = @{
                        DateTime      = $dateTimeFormatted
                        Tool          = "Nirsoft"
                        DataPath      = $url
                        TimestampInfo = "EventTime"
                        DataDetails   = $dataDetails
                        Description   = $description
                        User          = $_."User Profile"
                        EvidencePath  = $_."History File"
                    }

                        $browser = $_."Web Browser"
                        $artifactName = if ($browser) { "WebHistory - $browser" } else { "WebHistory" }

                        Normalize-Row -Fields $row -ArtifactName $artifactName
                }

                $MasterTimeline += $webRows
                $totalAdded += $webRows.Count
            }
            finally {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        }

        $reader.Close()
        Write-Host "  Added $totalAdded web history entries from $([System.IO.Path]::GetFileName($WebResultsPath))" -ForegroundColor Green
        Update-OverallProgress -CurrentSource "Web History"
    }
    catch {
        Write-Host "  Error processing Nirsoft Web History: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "Skipping Nirsoft Web History processing (either disabled or file not found)" -ForegroundColor Yellow
}



# Process ez Amcache 


if ($ProcessKape) {
Write-Host "Processing EZ Tools Amcache" -ForegroundColor Cyan
$AmCachePath = Join-Path $KapeDirectory $ProgramExecSubDir
if (Test-Path $AmCachePath) {
    $AmcacheFiles = Get-ChildItem -Path $AmCachePath -Filter "*ssociatedFileEntries.csv" -ErrorAction SilentlyContinue
    $fileCount = $AmcacheFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $AmcacheFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing EZ Tools Amcache Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
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
                                # Format the DateTime properly
                                $dateTimeString = $_."FileKeyLastWriteTimestamp"
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                }
                                catch {
                                    # Handle potential parsing errors
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString # Keep original if parsing fails
                                }
                                
                                $row = @{
                                    DateTime       = $dateTimeFormatted 
                                    Tool           = "EZ Tools"
                                    DataPath       = $_."FullPath"
                                    TimestampInfo  = "Last Write"
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
                            # Format the DateTime properly
                            $dateTimeString = $_."FileKeyLastWriteTimestamp"
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            }
                            catch {
                                # Handle potential parsing errors
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString # Keep original if parsing fails
                            }

                            $row = @{
                                DateTime       = $dateTimeFormatted 
                                Tool           = "EZ Tools"
                                DataPath       = $_."FullPath"
                                TimestampInfo  = "Last Write"
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
} else {
Write-Host "Skipping EZ Tools Amcache (ProcessKape is disabled)" -ForegroundColor Yellow
}

# Process ez AppCompatCache -Shim
if ($ProcessKape) {
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
                                    Tool           = "EZ Tools"
                                    DataPath       = $_."Path"
                                    DataDetails    = $_."Path" -replace '.*\\([^\\]+)$', '$1'
                                    TimestampInfo  = "Last Modified"
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
                                Tool           = "EZ Tools"
                                DataPath       = $_."Path"
                                DataDetails    = $_."Path" -replace '.*\\([^\\]+)$', '$1'
                                TimestampInfo  = "Last Modified"
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
} else {
Write-Host "Skipping EZ Tools AppCompatCache (ProcessKape is disabled)" -ForegroundColor Yellow
}


# Define filtering criteria per channel for ez Event Logs
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


# process ez event logs

if ($ProcessKape) {
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
    Write-Host "  Consider choosing NO in the interactive menu or using -SkipEventLogs in the future to skip event log processing." -ForegroundColor Yellow
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
                                        DateTime        = $dateTimeFormatted
                                        Tool            = "EZ Tools"
                                        EventId         = $entry."EventId"
                                        Description     = $entry."Channel"
                                        TimestampInfo   = "Event Time"
                                        DataDetails     = $entry."MapDescription"
                                        DataPath        = $entry."PayloadData1"
                                        Computer        = $entry."Computer"
                                        EvidencePath    = $entry."SourceFile"
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
                                    DateTime         = $dateTimeFormatted
                                    Tool             = "EZ Tools"
                                    EventId          = $entry."EventId"
                                    Description      = $entry."Channel"
                                    TimestampInfo    = "Event Time"
                                    DataDetails      = $entry."MapDescription"
                                    DataPath         = $entry."PayloadData1"
                                    Computer         = $entry."Computer"
                                    EvidencePath     = $entry."SourceFile"
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
else {
    Write-Host "Skipping EZ Tools EventLogs (ProcessKape is disabled)" -ForegroundColor Yellow
}


# After processing each artifact, perform garbage collection to free up resources
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()


# Process ez File Deletion records
if ($ProcessKape) {
    Write-Host "Processing File Deletion Records" -ForegroundColor Cyan
    $fileDeletionPath = Join-Path $KapeDirectory $FileDeletionSubDir
    if (Test-Path $fileDeletionPath) {
        $fileDeletionFiles = Get-ChildItem $fileDeletionPath -Filter "*RBCmd*" -Recurse -ErrorAction SilentlyContinue
        $fileCount = $fileDeletionFiles.Count
        
        if ($fileCount -gt 0) {
            $fileCounter = 0
            foreach ($file in $fileDeletionFiles) {
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
                                
                                # Process File Deletion entries
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
                                        DateTime       = $_."DeletedOn"
                                        Tool           = "EZ Tools"
                                        DataPath       = $_."FileName"
                                        Description    = "File System"
                                        TimestampInfo  = "File Deleted On"
                                        DataDetails    = $dataDetails
                                        FileSize       = $_."FileSize"
                                        EvidencePath   = $_."SourceName"
                                    }
                                    Normalize-Row -Fields $row -ArtifactName "FileDeletion"
                                }
                                $MasterTimeline += $delRows
                                $totalAdded += $delRows.Count
                               
                                
                                # Update progress
                                if ($totalProcessed % 1000 -eq 0) {
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
                                    DateTime       = $_."DeletedOn"
                                    Tool           = "EZ Tools"
                                    DataPath       = $_."FileName"
                                    Description    = "File System"
                                    TimestampInfo  = "File Deleted On"
                                    DataDetails    = $dataDetails
                                    FileSize       = $_."FileSize"
                                    EvidencePath   = $_."SourceName"
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
    } else {
        Write-Host "  File deletion records path not found: $fileDeletionPath" -ForegroundColor Yellow
        }
    } else { Write-Host "Skipping EZ Tools File Deletions (ProcessKape is disabled)" -ForegroundColor Yellow }
        
# Process ez Jump Lists
if ($ProcessKape) {
Write-Host "Processing Jump Lists" -ForegroundColor Cyan
$jumpListPath = Join-Path $KapeDirectory $FileFolderSubDir
if (Test-Path $jumpListPath) {
    $jumpListFiles = Get-ChildItem $jumpListPath -Filter "*_AutomaticDestinations.csv" -ErrorAction SilentlyContinue
    $fileCount = $jumpListFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $jumpListFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing Jump Lists" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
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
                            
                            # First pass - Creation Time
                            $jumpListRows = $batchData | ForEach-Object {
                                $dataPathValue = $(if ($_."LocalPath") { 
                                                    $_."LocalPath" 
                                                } elseif ($_."TargetIDAbsolutePath") { 
                                                    $_."TargetIDAbsolutePath" 
                                                } else { 
                                                    "" 
                                                })
                            
                                $dateTimeString = $_."CreationTime"
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        } catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                            $dateTimeFormatted = $dateTimeString
                                        }

                                $row = @{
                                    DateTime       = $dateTimeFormatted
                                    Tool           = "EZ Tools"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    TimestampInfo  = "Creation Time"
                                    DataDetails    = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                        "" 
                                     } else { 
                                        Split-Path -Leaf $dataPathValue 
                                     })
                                    FileSize       = $_."FileSize"
                                    EvidencePath   = $_."SourceFile"
                                }
                                Normalize-Row -Fields $row -ArtifactName "JumpLists"
                            }
                            $MasterTimeline += $jumpListRows
                            $totalAdded += $jumpListRows.Count
                            
                            # Second pass - Last Modified
                            $jumpListRows = $batchData | ForEach-Object {
                                $dataPathValue = $(if ($_."LocalPath") { 
                                                    $_."LocalPath" 
                                                } elseif ($_."TargetIDAbsolutePath") { 
                                                    $_."TargetIDAbsolutePath" 
                                                } else { 
                                                    "" 
                                                })
                                
                            $dateTimeString = $_."LastModified"
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        } catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                            $dateTimeFormatted = $dateTimeString
                                        }

                                $row = @{
                                    DateTime       = $dateTimeFormatted
                                    Tool           = "EZ Tools"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    TimestampInfo  = "Last Modified"
                                    DataDetails    = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                        "" 
                                     } else { 
                                        Split-Path -Leaf $dataPathValue 
                                     })
                                    FileSize       = $_."FileSize"
                                    EvidencePath   = $_."SourceFile"
                                }
                                Normalize-Row -Fields $row -ArtifactName "JumpLists"
                            }
                            $MasterTimeline += $jumpListRows
                            $totalAdded += $jumpListRows.Count
                            
                            # Update progress
                            if ($totalProcessed % 1000 -eq 0) {
                                Show-ProcessingProgress -Activity "Processing Jump Lists: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
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
                        
                        # First pass - Creation Time (for remaining batch)
                        $jumpListRows = $batchData | ForEach-Object {
                            $dataPathValue = $(if ($_."LocalPath") { 
                                                $_."LocalPath" 
                                            } elseif ($_."TargetIDAbsolutePath") { 
                                                $_."TargetIDAbsolutePath" 
                                            } else { 
                                                "" 
                                            })
                            
                            $dateTimeString = $_."CreationTime"
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        } catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                            $dateTimeFormatted = $dateTimeString
                                        }

                                $row = @{
                                    DateTime       = $dateTimeFormatted
                                    Tool           = "EZ Tools"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    TimestampInfo  = "Creation Time"
                                DataDetails    = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                    "" 
                                 } else { 
                                    Split-Path -Leaf $dataPathValue 
                                 })
                                FileSize       = $_."FileSize"
                                EvidencePath   = $_."SourceFile"
                            }
                            Normalize-Row -Fields $row -ArtifactName "JumpLists"
                        }
                        $MasterTimeline += $jumpListRows
                        $totalAdded += $jumpListRows.Count
                        
                        # Second pass - Last Modified (for remaining batch)
                        $jumpListRows = $batchData | ForEach-Object {
                            $dataPathValue = $(if ($_."LocalPath") { 
                                                $_."LocalPath" 
                                            } elseif ($_."TargetIDAbsolutePath") { 
                                                $_."TargetIDAbsolutePath" 
                                            } else { 
                                                "" 
                                            })
                            $dateTimeString = $_."LastModified"
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        } catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                            $dateTimeFormatted = $dateTimeString
                                        }

                                $row = @{
                                    DateTime       = $dateTimeFormatted
                                    Tool           = "EZ Tools"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    TimestampInfo  = "Last Modified"
                                    DataDetails    = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                    "" 
                                 } else { 
                                    Split-Path -Leaf $dataPathValue 
                                 })
                                FileSize       = $_."FileSize"
                                EvidencePath   = $_."SourceFile"
                            }
                            Normalize-Row -Fields $row -ArtifactName "JumpLists"
                        }
                        $MasterTimeline += $jumpListRows
                        $totalAdded += $jumpListRows.Count
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
                Write-Host "  Added $totalAdded Jump List entries from $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "Jump Lists"
        }
    } else {
        Write-Host "  No Jump List files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Jump List files path not found: $jumpListPath" -ForegroundColor Yellow
    }
} else { Write-Host "Skipping EZ Tools Jump Lists (ProcessKape is disabled)" -ForegroundColor Yellow }


# Process ez LNK Files
if ($ProcessKape) {
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
                                    Tool           = "EZ Tools"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    TimestampInfo  = "Target Created"
                                    DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                        "" 
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
                                    Tool           = "EZ Tools"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    TimestampInfo  = "Source Created"
                                    DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                        "" 
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
                                    Tool           = "EZ Tools"
                                    DataPath       = $dataPathValue
                                    Description    = "File & Folder Access"
                                    TimestampInfo  = "Target Modified"
                                    DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                        "" 
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
                                Tool           = "EZ Tools"
                                DataPath       = $dataPathValue
                                Description    = "File & Folder Access"
                                TimestampInfo  = "Target Created"
                                DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                    "" 
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
                                Tool           = "EZ Tools"
                                DataPath       = $dataPathValue
                                Description    = "File & Folder Access"
                                TimestampInfo  = "Source Created"
                                DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                    "h" 
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
                                Tool           = "EZ Tools"
                                DataPath       = $dataPathValue
                                Description    = "File & Folder Access"
                                TimestampInfo  = "Target Modified"
                                DataDetails = $(if ([string]::IsNullOrEmpty($dataPathValue)) { 
                                    "" 
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
} else { Write-Host "Skipping EZ Tools LNK Files (ProcessKape is disabled)" -ForegroundColor Yellow }
    

# Process MFT Created with batching for large files

if ($ProcessKape) {
Write-Host "Processing MFT File" -ForegroundColor Cyan


# Display current EZ MFT filter settings - ensure this completes before other output begins
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
                            $dt = try { [datetime]::Parse($_.Created0x30).ToString("yyyy-MM-dd HH:mm:ss") } catch { $_.Created0x30}
                            $row = @{
                                DateTime       = $dt
                                Tool           = "EZ Tools"
                                DataPath       = $_."ParentPath"
                                DataDetails    = $_."FileName"
                                Description    = "File System"
                                TimestampInfo  = "File Created"
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
                        $dt = try { [datetime]::Parse($_.Created0x30).ToString("yyyy-MM-dd HH:mm:ss") } catch { $_.Created0x30 }
                        $row = @{
                            DateTime       = $dt
                            Tool           = "EZ Tools"
                            DataPath       = $_."ParentPath"
                            DataDetails    = $_."FileName"
                            Description    = "File System"
                            TimestampInfo  = "File Created"
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
} else {
Write-Host "Skipping EZ Tools MFT (ProcessKape is disabled)" -ForegroundColor Yellow
}


# After processing each artifact, perform garbage collection to free up resources
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()



# Process EZ Prefetch Files
if ($ProcessKape) {
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
                            
                            # First pass - LastRun timestamp
                            $peRows = $batchData | ForEach-Object {
                                # Format the DateTime properly
                                $dateTimeString = $_."LastRun"
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                }
                                catch {
                                    # Handle potential parsing errors
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString # Keep original if parsing fails
                                }

                                $row = @{
                                    DateTime     = $dateTimeFormatted
                                    Tool           = "EZ Tools"
                                    DataPath     = $_."SourceFilename"
                                    TimestampInfo =  "Last Run"
                                    DataDetails  = $_."ExecutableName"
                                    Description  = "Program Execution"
                                    EvidencePath = $file.Name
                                    Count        = $_."RunCount"
                                }
                                Normalize-Row -Fields $row -ArtifactName "PrefetchFiles"
                            }
                            
                            # Add to master timeline
                            $MasterTimeline += $peRows
                            $totalAdded += $peRows.Count
                            
                            # Second pass - SourceCreated timestamp
                            $peRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."SourceCreated") } | ForEach-Object {
                                # Format the DateTime properly
                                $dateTimeString = $_."SourceCreated"
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                }
                                catch {
                                    # Handle potential parsing errors
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString # Keep original if parsing fails
                                }

                                $row = @{
                                    DateTime     = $dateTimeFormatted
                                    Tool           = "EZ Tools"
                                    DataPath     = $_."SourceFilename"
                                    TimestampInfo = "File Created"
                                    DataDetails  = $_."ExecutableName"
                                    Description  = "Program Execution"
                                    EvidencePath = $file.Name
                                    Count        = $_."RunCount"
                                }
                                Normalize-Row -Fields $row -ArtifactName "PrefetchFiles"
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
                        
                        # First pass - LastRun (for remaining batch)
                        $peRows = $batchData | ForEach-Object {
                            # Format the DateTime properly
                            $dateTimeString = $_."LastRun"
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            }
                            catch {
                                # Handle potential parsing errors
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString # Keep original if parsing fails
                            }

                            $row = @{
                                DateTime     = $dateTimeFormatted 
                                Tool           = "EZ Tools"
                                DataPath     = $_."SourceFilename"
                                TimestampInfo = "Last Run"
                                DataDetails  = $_."ExecutableName"
                                Description  = "Program Execution"
                                EvidencePath = $file.Name
                                Count        = $_."RunCount"
                            }
                            Normalize-Row -Fields $row -ArtifactName "PrefetchFiles"
                        }
                        
                        $MasterTimeline += $peRows
                        $totalAdded += $peRows.Count
                        
                        # Second pass - SourceCreated (for remaining batch)
                        $peRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."SourceCreated") } | ForEach-Object {
                            # Format the DateTime properly
                            $dateTimeString = $_."SourceCreated"
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            }
                            catch {
                                # Handle potential parsing errors
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString # Keep original if parsing fails
                            }

                            $row = @{
                                DateTime     = $dateTimeFormatted
                                Tool           = "EZ Tools"
                                DataPath     = $_."SourceFilename"
                                TimestampInfo = "File Created"
                                DataDetails  = $_."ExecutableName"
                                Description  = "Program Execution"
                                EvidencePath = $file.Name
                                Count        = $_."RunCount"
                            }
                            Normalize-Row -Fields $row -ArtifactName "PrefetchFiles"
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
} else {
Write-Host "Skipping EZ Tools Prefetch (ProcessKape is disabled)" -ForegroundColor Yellow
}


# Process Registry
if ($ProcessKape) {
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
                        
                        try {
                            $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                            $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                            
                            $batchData = Import-Csv $tempFile
                            
                            $regRows = $batchData | ForEach-Object {
                                # Format the DateTime properly
                               $dateTimeString = $_."LastWriteTimestamp"
								try {
									# Only attempt to parse if the string is not empty
									if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
										$dateTime = [datetime]::Parse($dateTimeString)
										$dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
									} else {
										# Handle empty date strings
										$dateTimeFormatted = ""
									}
								}
								catch {
									# Handle potential parsing errors with more detail
									Write-Host "    Error parsing date: '$dateTimeString' in registry entry" -ForegroundColor Yellow
									$dateTimeFormatted = $dateTimeString # Keep original if parsing fails
									}                       
                                $row = @{
                                    DateTime     = $dateTimeFormatted
                                    Tool           = "EZ Tools"
                                    DataPath     = $_."ValueData"
                                    Description  = $_."Category"
                                    DataDetails  = $_."Description"
                                    TimestampInfo = "Last Write"
                                    EvidencePath = $_."HivePath"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Registry"
                            }
                            
                            $MasterTimeline += $regRows
                            $totalRowsAdded += $regRows.Count
                            $totalProcessed += $batchCount
                        }
                        catch {
                            Write-Host "    Error processing batch: $_" -ForegroundColor Red
                        }
                        finally {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                        
                        $batch.Clear()
                        $batchCount = 0
                        
                        # Show progress
                        Show-ProcessingProgress -Activity "Processing Registry: $($file.Name)" -Status "Processed $totalProcessed entries" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                    }
                }
                
                # Process remaining entries
                if ($batch.Count -gt 0) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        
                        $batchData = Import-Csv $tempFile
                        
                        $regRows = $batchData | ForEach-Object {
                            # Format the DateTime properly
                             $dateTimeString = $_."LastWriteTimestamp"
								try {
									# Only attempt to parse if the string is not empty
									if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
										$dateTime = [datetime]::Parse($dateTimeString)
										$dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
									} else {
										# Handle empty date strings
										$dateTimeFormatted = ""
									}
								}
								catch {
									# Handle potential parsing errors with more detail
									Write-Host "    Error parsing date: '$dateTimeString' in registry entry" -ForegroundColor Yellow
									$dateTimeFormatted = $dateTimeString # Keep original if parsing fails
									}
                            
                            $row = @{
                                DateTime     = $dateTimeFormatted
                                Tool           = "EZ Tools"
                                DataPath     = $_."ValueData"
                                Description  = $_."Category"
                                DataDetails  = $_."Description"
                                TimestampInfo = "Last Write"
                                EvidencePath = $_."HivePath"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Registry"
                        }
                        
                        $MasterTimeline += $regRows
                        $totalRowsAdded += $regRows.Count
                        $totalProcessed += $batch.Count
                    }
                    catch {
                        Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                    }
                    finally {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
                
                $reader.Close()
                
                Write-Host "  Processed $totalProcessed registry entries, added $totalRowsAdded to timeline from $($file.Name)" -ForegroundColor Green
            } 
            catch {
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
} else {
Write-Host "Skipping EZ Tools Registry (ProcessKape is disabled)" -ForegroundColor Yellow
}


# After processing each artifact, perform garbage collection to free up resources
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()




# Process ez Shellbags
if ($ProcessKape) {
Write-Host "Processing Shellbags" -ForegroundColor Cyan
$lnkPath = Join-Path $KapeDirectory $FileFolderSubDir
if (Test-Path $lnkPath) {
    # Get ALL CSV files first
    $allCsvFiles = Get-ChildItem $lnkPath -Filter "*.csv" -Recurse -ErrorAction SilentlyContinue
    
    # Then filter for both types with explicit conditions
    $allShellbags = $allCsvFiles | Where-Object { 
        $_.Name -match '_UsrClass\.csv$' -or $_.Name -match '_NTUSER\.csv$'
    }
    
    # Log what we found
    Write-Host "Found $($allShellbags.Count) shellbag files:" -ForegroundColor Green
    $allShellbags | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
    
    $fileCount = $allShellbags.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $allShellbags) {
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
                                    Tool           = "EZ Tools"
                                    DataPath    = $_."AbsolutePath"
                                    DataDetails = $_."Value"
                                    Description = "File & Folder Access"
                                    TimestampInfo = "Last Write"
									EvidencePath = $file.Name 
                                }
                                Normalize-Row -Fields $row -ArtifactName "Shellbags"
                            }
                            $MasterTimeline += $shellRows
                            $totalAdded += $shellRows.Count
                            
                            # Second pass - First Interacted
                            $shellRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."FirstInteracted") } | ForEach-Object {
                                $row = @{
                                    DateTime    = $_."FirstInteracted"
                                    Tool           = "EZ Tools"
                                    DataPath    = $_."AbsolutePath"
                                    DataDetails = $_."Value"
                                    Description = "File & Folder Access"
                                    TimestampInfo = "First Interaction"
									EvidencePath = $file.Name 
                                }
                                Normalize-Row -Fields $row -ArtifactName "Shellbags"
                            }
                            $MasterTimeline += $shellRows
                            $totalAdded += $shellRows.Count
                            
                            # Third pass - Last Interacted
                            $shellRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."LastInteracted") } | ForEach-Object {
                                $row = @{
                                    DateTime    = $_."LastInteracted"
                                    Tool           = "EZ Tools"
                                    DataPath    = $_."AbsolutePath"
                                    DataDetails = $_."Value"
                                    Description = "File & Folder Access"
                                    TimestampInfo       = "Last Interacted"
									EvidencePath = $file.Name 
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
                                Tool           = "EZ Tools"
                                DataPath    = $_."AbsolutePath"
                                DataDetails = $_."Value"
                                Description = "File & Folder Access"
                                TimestampInfo = "Last Write"
								EvidencePath = $file.Name 
                            }
                            Normalize-Row -Fields $row -ArtifactName "Shellbags"
                        }
                        $MasterTimeline += $shellRows
                        $totalAdded += $shellRows.Count
                        
                        # Second pass - First Interacted (for remaining batch)
                        $shellRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."FirstInteracted") } | ForEach-Object {
                            $row = @{
                                DateTime    = $_."FirstInteracted"
                                Tool           = "EZ Tools"
                                DataPath    = $_."AbsolutePath"
                                DataDetails = $_."Value"
                                Description = "File & Folder Access"
                                TimestampInfo = "First Interaction"
								EvidencePath = $file.Name 
                            }
                            Normalize-Row -Fields $row -ArtifactName "Shellbags"
                        }
                        $MasterTimeline += $shellRows
                        $totalAdded += $shellRows.Count
                        
                        # Third pass - Last Interacted (for remaining batch)
                        $shellRows = $batchData | Where-Object { -not [string]::IsNullOrEmpty($_."LastInteracted") } | ForEach-Object {
                            $row = @{
                                DateTime    = $_."LastInteracted"
                                Tool           = "EZ Tools"
                                DataPath    = $_."AbsolutePath"
                                DataDetails = $_."Value"
                                Description = "File & Folder Access"
                                TimestampInfo = "Last Interacted"
								EvidencePath = $file.Name 
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
} else {
    Write-Host "Skipping EZ Tools Shellbags (ProcessKape is disabled)" -ForegroundColor Yellow
}



# Process Chainsaw CSV files
if ($ProcessChainsaw) {
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
                                Tool               = "Chainsaw"
                                EventId            = $_."Event ID"
                                TimestampInfo      = "EventTime"
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
                                DataDetails = $_."detections"
                                User = $(if ($_."User") { 
                                    $_."User" 
                                } elseif ($_."User Name") { 
                                    $_."User Name" 
                                } else {
                                    ""
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
                            Tool               = "Chainsaw"
                            EventId            = $_."Event ID"
                            TimestampInfo      = "EventTime"
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
                            DataDetails = $_."detections"
                            User = $(if ($_."User") { 
                                $_."User" 
                            } elseif ($_."User Name") { 
                                $_."User Name" 
                            } else {
                                ""
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
} else {
Write-Host "  Chainsaw directory not found: $ChainsawDirectory" -ForegroundColor Yellow
}
} else {
Write-Host "Skipping Chainsaw processing (ProcessChainsaw is disabled)" -ForegroundColor Yellow
}

# Process Hayabusa CSV files
if ($ProcessHayabusa) {
    Write-Host "Processing Hayabusa CSV Files" -ForegroundColor Cyan
    $HayabusaFiles = Get-ChildItem -Path $HayabusaDirectory -Recurse -Filter *.csv -ErrorAction SilentlyContinue
    $fileCount = $HayabusaFiles.Count

    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($hayabusaFile in $HayabusaFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing Hayabusa Files" -Status "File: $($hayabusaFile.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
            try {
               $artifactName = "EventLogs"
                
                # Use streaming approach for large files
                $reader = New-Object System.IO.StreamReader($hayabusaFile.FullName)
                $headerLine = $reader.ReadLine()
                
                # Check column headers to determine format
                $headers = $headerLine -split ','
                # Select appropriate timestamp field - will need adjustment for actual Hayabusa format
                $timestampField = "Timestamp" # Default field name, adjust as needed for Hayabusa
                
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
                            
                            # Process batch data - this is placeholder code, you'll need to adjust for actual Hayabusa fields
                            $hayabusaRows = $batchData | ForEach-Object {
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
                            
                                # These field mappings will need to be adjusted based on actual Hayabusa CSV format
                                $row = @{
                                    DateTime          = $dt
                                    Tool                = "Hayabusa"
                                    EventId           = $_."EventID"
                                    Description       = $_."Channel"
                                    TimestampInfo     = "Event Time"
                                    DataPath          = $_."Details" 
                                    DataDetails       = $_."RuleTitle" 
                                    Computer          = $_."Computer"
                                }
                                Normalize-Row -Fields $row -ArtifactName "EventLogs"
                            }
                            
                            # Add to master timeline
                            $MasterTimeline += $hayabusaRows
                            $totalAdded += $hayabusaRows.Count
                            
                            # Update progress
                            if ($totalProcessed % 5000 -eq 0) {
                                Show-ProcessingProgress -Activity "Processing Hayabusa: $($hayabusaFile.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
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
                        
                        # Process remaining batch with same logic - placeholder code
                        $hayabusaRows = $batchData | ForEach-Object {
                            # Timestamp parsing
                            $dt = if ($_.$timestampField) {
                                try { 
                                    $dateObj = [datetime]::Parse($_.$timestampField, [System.Globalization.CultureInfo]::InvariantCulture, 
                                        [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                                    $dateObj.ToString("yyyy-MM-dd HH:mm:ss")
                                } 
                                catch { 
                                    $_.$timestampField 
                                }
                            } else {
                                (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            }
                        
                            # These field mappings will need to be adjusted based on actual Hayabusa CSV format
                            $row = @{
									DateTime          = $dt
                                    Tool              = "Hayabusa"
                                    EventId           = $_."EventID"
                                    Description       = $_."Channel"
                                    TimestampInfo     = "Event Time" 
                                    DataPath          = $_."Details" 
                                    DataDetails       = $_."RuleTitle" 
                                    Computer          = $_."Computer"
                                 
                            }
                            Normalize-Row -Fields $row -ArtifactName "EventLogs"
                        }
                        
                        $MasterTimeline += $hayabusaRows
                        $totalAdded += $hayabusaRows.Count
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
               Write-Host "  Added $totalAdded entries from $($hayabusaFile.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($hayabusaFile.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "Hayabusa"
        }
    } else {
        Write-Host "  No Hayabusa CSV files found in $HayabusaDirectory" -ForegroundColor Yellow
    }
} else {
    Write-Host "Skipping Hayabusa processing (ProcessHayabusa is disabled)" -ForegroundColor Yellow
}

# After processing each artifact, perform garbage collection to free up resources
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()


#Axiom Processing Starts Here


# Process Axiom AmCache
if ($ProcessAxiom) {
Write-Host "Processing Axiom AmCache" -ForegroundColor Cyan
$AxiomAmCachePath = $AxiomDirectory
if (Test-Path $AxiomAmCachePath) {
    $AmcacheFiles = Get-ChildItem -Path $AxiomAmCachePath -Filter "AmCache File Entries.csv" -ErrorAction SilentlyContinue
    $fileCount = $AmcacheFiles.Count
    
    if ($fileCount -gt 0) {
        $fileCounter = 0
        foreach ($file in $AmcacheFiles) {
            $fileCounter++
            Show-ProcessingProgress -Activity "Processing Axiom AmCache Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
            
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
                                # Format the DateTime properly
                                $dateTimeString = $_."Key Last Updated Date/Time - UTC+00:00 (M/d/yyyy)"
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                }
                                catch {
                                    # Handle potential parsing errors
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString # Keep original if parsing fails
                                }
                                
                                $row = @{
                                    DateTime       = $dateTimeFormatted
                                    Tool           = "Axiom" 
                                    DataPath       = $_."Full Path"
                                    TimestampInfo  = "Last Write"
                                    Description    = "Program Execution"
                                    DataDetails    = $_."Associated Application Name"
                                    FileExtension  = $_."File Extension"
                                    SHA1           = $_."SHA1 Hash"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Amcache"
                            }
                            
                            # Add to master timeline
                            $MasterTimeline += $amRows
                            $totalAdded += $amRows.Count
                            
                            # Update progress
                            Show-ProcessingProgress -Activity "Processing Axiom AmCache: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
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
                            # Format the DateTime properly
                            $dateTimeString = $_."Key Last Updated Date/Time - UTC+00:00 (M/d/yyyy)"
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            }
                            catch {
                                # Handle potential parsing errors
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString # Keep original if parsing fails
                            }

                            $row = @{
                                DateTime       = $dateTimeFormatted 
                                Tool           = "Axiom"
                                DataPath       = $_."Full Path"
                                TimestampInfo  = "Last Write"
                                Description    = "Program Execution"
                                DataDetails    = $_."Associated Application Name"
                                FileExtension  = $_."File Extension"
                                SHA1           = $_."SHA1 Hash"
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
                Write-Host "  Added $totalAdded Axiom Amcache entries from $($file.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
            }
            
            Update-OverallProgress -CurrentSource "Axiom Amcache"
        }
    } else {
        Write-Host "  No Axiom Amcache files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Axiom Amcache path not found: $AxiomAmCachePath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom Amcache Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow 
    }

# Process Axiom Jump Lists Artifacts
if ($ProcessAxiom) {
    Write-Host "Processing Axiom Jump Lists" -ForegroundColor Cyan
    $JumpListPath = Join-Path $AxiomDirectory "Jump Lists.csv"

    if (Test-Path $JumpListPath) {
        try {
            $reader = New-Object System.IO.StreamReader($JumpListPath)
            $headerLine = $reader.ReadLine()
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList

            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++

                if ($batchCount -ge $BatchSize) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                        $batchData = Import-Csv $tempFile
                        $jlRows = @()
                        foreach ($entry in $batchData) {
                            $targetPath = $entry."Linked Path"
                            if ([string]::IsNullOrWhiteSpace($targetPath)) { continue }

                            $fileName = Split-Path -Leaf $targetPath

                            # Created Timestamp
                            $createdString = $entry."Target File Created Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""

                            if (![string]::IsNullOrWhiteSpace($createdString)) {
                                try {
                                    $created = [datetime]::Parse($createdString)
                                    $dateTimeFormatted = $created.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $createdString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $createdString
                                }
                            }

                            if ($dateTimeFormatted -ne "") {
                                $row = @{
                                    DateTime      = $dateTimeFormatted
                                    Tool          = "Axiom"
                                    DataPath      = $targetPath
                                    Description   = "File & Folder Access"
                                    TimestampInfo = "Creation Time"
                                    DataDetails   = $entry."Potential App Name"
                                    FileSize      = $entry."Target File Size (Bytes)"
                                    EvidencePath  = $entry."Source"
                                }
                                $jlRows += Normalize-Row -Fields $row -ArtifactName "JumpLists"
                            }


                            # Modified Timestamp
                            $modifiedString = $entry."Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""

                            if (![string]::IsNullOrWhiteSpace($modifiedString)) {
                                try {
                                    $modified = [datetime]::Parse($modifiedString)
                                    $dateTimeFormatted = $modified.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $modifiedString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $modifiedString
                                }
                            }

                            if ($dateTimeFormatted -ne "") {
                                $row = @{
                                    DateTime      = $dateTimeFormatted
                                    Tool          = "Axiom"
                                    DataPath      = $targetPath
                                    Description   = "File & Folder Access"
                                    TimestampInfo = "Last Modified Time"
                                    DataDetails   = $fileName
                                    FileSize      = $entry."Target File Size (Bytes)"
                                    EvidencePath  = $entry."Source"
                                }
                                $jlRows += Normalize-Row -Fields $row -ArtifactName "JumpLists"
                            }


                            # Last Access Timestamp
                            $accessedString = $entry."Last Access Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""

                            if (![string]::IsNullOrWhiteSpace($accessedString)) {
                                try {
                                    $accessed = [datetime]::Parse($accessedString)
                                    $dateTimeFormatted = $accessed.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $accessedString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $accessedString
                                }
                            }

                            if ($dateTimeFormatted -ne "") {
                                $row = @{
                                    DateTime      = $dateTimeFormatted
                                    Tool          = "Axiom"
                                    DataPath      = $targetPath
                                    Description   = "File & Folder Access"
                                    TimestampInfo = "Last Access Time"
                                    DataDetails   = $fileName
                                    FileSize      = $entry."Target File Size (Bytes)"
                                    EvidencePath  = $entry."Source"
                                }
                                $jlRows += Normalize-Row -Fields $row -ArtifactName "JumpLists"
                            }

                        }
                        $MasterTimeline += $jlRows
                        $totalAdded += $jlRows.Count
                    } finally {
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                    $batch.Clear()
                    $batchCount = 0
                }
            }

            # Process remaining
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                    $batchData = Import-Csv $tempFile
                    $jlRows = @()
                    foreach ($entry in $batchData) {
                        $targetPath = $entry."Linked Path"
                        if ([string]::IsNullOrWhiteSpace($targetPath)) { continue }

                        $fileName = Split-Path -Leaf $targetPath

                        # Created Timestamp
                        $createdString = $entry."Target File Created Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""

                            if (![string]::IsNullOrWhiteSpace($createdString)) {
                                try {
                                    $created = [datetime]::Parse($createdString)
                                    $dateTimeFormatted = $created.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $createdString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $createdString
                                }
                            }

                            if ($dateTimeFormatted -ne "") {
                                $row = @{
                                    DateTime      = $dateTimeFormatted
                                    Tool          = "Axiom"
                                    DataPath      = $targetPath
                                    Description   = "File & Folder Access"
                                    TimestampInfo = "Creation Time"
                                    DataDetails   = $entry."Potential App Name"
                                    FileSize      = $entry."Target File Size (Bytes)"
                                    EvidencePath  = $entry."Source"
                                }
                                $jlRows += Normalize-Row -Fields $row -ArtifactName "JumpLists"
                            }

                        # Modified Timestamp
                         $modifiedString = $entry."Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                         $dateTimeFormatted = ""

                         if (![string]::IsNullOrWhiteSpace($modifiedString)) {
                             try {
                                 $modified = [datetime]::Parse($modifiedString)
                                 $dateTimeFormatted = $modified.ToString("yyyy-MM-dd HH:mm:ss")
                             } catch {
                                 Write-Host "    Error parsing date: $modifiedString" -ForegroundColor Yellow
                                 $dateTimeFormatted = $modifiedString
                             }
                         }

                         if ($dateTimeFormatted -ne "") {
                             $row = @{
                                 DateTime      = $dateTimeFormatted
                                 Tool          = "Axiom"
                                 DataPath      = $targetPath
                                 Description   = "File & Folder Access"
                                 TimestampInfo = "Last Modified Time"
                                 DataDetails   = $fileName
                                 FileSize      = $entry."Target File Size (Bytes)"
                                 EvidencePath  = $entry."Source"
                             }
                             $jlRows += Normalize-Row -Fields $row -ArtifactName "JumpLists"
                         }

                        # Last Access Timestamp
                        $accessedString = $entry."Last Access Date/Time - UTC+00:00 (M/d/yyyy)"
                        $dateTimeFormatted = ""

                        if (![string]::IsNullOrWhiteSpace($accessedString)) {
                            try {
                                $accessed = [datetime]::Parse($accessedString)
                                $dateTimeFormatted = $accessed.ToString("yyyy-MM-dd HH:mm:ss")
                            } catch {
                                Write-Host "    Error parsing date: $accessedString" -ForegroundColor Yellow
                                $dateTimeFormatted = $accessedString
                            }
                        }

                        if ($dateTimeFormatted -ne "") {
                            $row = @{
                                DateTime      = $dateTimeFormatted
                                Tool          = "Axiom"
                                DataPath      = $targetPath
                                Description   = "File & Folder Access"
                                TimestampInfo = "Last Access Time"
                                DataDetails   = $fileName
                                FileSize      = $entry."Target File Size (Bytes)"
                                EvidencePath  = $entry."Source"
                            }
                            $jlRows += Normalize-Row -Fields $row -ArtifactName "JumpLists"
                        }
                    }
                    $MasterTimeline += $jlRows
                    $totalAdded += $jlRows.Count
                } finally {
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            $reader.Close()
            Write-Host "  Added $totalAdded Axiom Jump List entries to timeline" -ForegroundColor Green
            Update-OverallProgress -CurrentSource "Axiom Jump Lists"

        } catch {
            Write-Host "  Error processing Axiom Jump Lists: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Axiom Jump Lists file not found: $JumpListPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom Jump List Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow
}



# Process Axiom LNK Files
if ($ProcessAxiom) {
    Write-Host "Processing Axiom LNK Files" -ForegroundColor Cyan
    $AxiomLNKPath = $AxiomDirectory
    if (Test-Path $AxiomLNKPath) {
        $LNKFiles = Get-ChildItem -Path $AxiomLNKPath -Filter "*LNK Files.csv" -ErrorAction SilentlyContinue
        $fileCount = $LNKFiles.Count

        if ($fileCount -gt 0) {
            $fileCounter = 0
            foreach ($file in $LNKFiles) {
                $fileCounter++
                Show-ProcessingProgress -Activity "Processing Axiom LNK Files" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1

                try {
                    $reader = New-Object System.IO.StreamReader($file.FullName)
                    $headerLine = $reader.ReadLine()
                    $batchCount = 0
                    $totalProcessed = 0
                    $totalAdded = 0
                    $batch = New-Object System.Collections.ArrayList

                    while (-not $reader.EndOfStream) {
                        $line = $reader.ReadLine()
                        if ([string]::IsNullOrWhiteSpace($line)) { continue }

                        [void]$batch.Add($line)
                        $batchCount++
                        $totalProcessed++

                        if ($batchCount -ge $BatchSize) {
                            $tempFile = [System.IO.Path]::GetTempFileName()
                            try {
                                $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                                $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                                $batchData = Import-Csv $tempFile

                                # First pass - Target Created Date/Time
                                $lnkRows = $batchData | ForEach-Object {
                                    $dateTimeString = $_."Target File Created Date/Time - UTC+00:00 (M/d/yyyy)"
                                    $dateTimeFormatted = ""

                                    if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        } catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                        }
                                    }

                                    $row = @{
                                        DateTime       = $dateTimeFormatted
                                        Tool           = "Axiom"
                                        DataPath       = $_."Linked Path"
                                        TimestampInfo  = "Target Created"
                                        Description    = "File & Folder Access"
                                    }
                                    Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                                }
                                $MasterTimeline += $lnkRows
                                $totalAdded += $lnkRows.Count

                                # Second pass - Target Last Modified Date/Time
                                $lnkRows = $batchData | ForEach-Object {
                                    $dateTimeString = $_."Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                                    $dateTimeFormatted = ""

                                    if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        } catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                        }
                                    }

                                    $row = @{
                                        DateTime       = $dateTimeFormatted
                                        Tool           = "Axiom"
                                        DataPath       = $_."Linked Path"
                                        TimestampInfo  = "Target Modified"
                                        Description    = "File & Folder Access"
                                    }
                                    Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                                }
                                $MasterTimeline += $lnkRows
                                $totalAdded += $lnkRows.Count

                                # Third pass - Source Created Date/Time
                                $lnkRows = $batchData | ForEach-Object {
                                    $dateTimeString = $_."Created Date/Time - UTC+00:00 (M/d/yyyy)"
                                    $dateTimeFormatted = ""

                                    if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        } catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                        }
                                    }

                                    $row = @{
                                        DateTime       = $dateTimeFormatted
                                        Tool           = "Axiom"
                                        DataPath       = $_."Linked Path"
                                        TimestampInfo  = "Source Created"
                                        Description    = "File & Folder Access"
                                    }
                                    Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                                }
                                $MasterTimeline += $lnkRows
                                $totalAdded += $lnkRows.Count

                                Show-ProcessingProgress -Activity "Processing Axiom LNK Files: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
                            } catch {
                                Write-Host "    Error processing batch: $_" -ForegroundColor Red
                            } finally {
                                if (Test-Path $tempFile) {
                                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                                }
                            }

                            $batch.Clear()
                            $batchCount = 0
                        }
                    }

                    # Final batch
                    if ($batch.Count -gt 0) {
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        try {
                            $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                            $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                            $batchData = Import-Csv $tempFile

                            # First pass - Target Created Date/Time
                            $lnkRows = $batchData | ForEach-Object {
                                $dateTimeString = $_."Target File Created Date/Time - UTC+00:00 (M/d/yyyy)"
                                $dateTimeFormatted = ""

                                if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                    try {
                                        $dateTime = [datetime]::Parse($dateTimeString)
                                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                    } catch {
                                        Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    }
                                }

                                $row = @{
                                    DateTime       = $dateTimeFormatted
                                    Tool           = "Axiom"
                                    DataPath       = $_."Linked Path"
                                    TimestampInfo  = "Target Created"
                                    Description    = "File & Folder Access"
                                }
                                Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                            }
                            $MasterTimeline += $lnkRows
                            $totalAdded += $lnkRows.Count

                            # Second pass - Target Last Modified Date/Time
                            $lnkRows = $batchData | ForEach-Object {
                                $dateTimeString = $_."Target File Last Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                                $dateTimeFormatted = ""

                                if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                    try {
                                        $dateTime = [datetime]::Parse($dateTimeString)
                                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                    } catch {
                                        Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    }
                                }

                                $row = @{
                                    DateTime       = $dateTimeFormatted
                                    Tool           = "Axiom"
                                    DataPath       = $_."Linked Path"
                                    TimestampInfo  = "Target Modified"
                                    Description    = "File & Folder Access"
                                }
                                Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                            }
                            $MasterTimeline += $lnkRows
                            $totalAdded += $lnkRows.Count

                            # Third pass - Source Created Date/Time
                            $lnkRows = $batchData | ForEach-Object {
                                $dateTimeString = $_."Created Date/Time - UTC+00:00 (M/d/yyyy)"
                                $dateTimeFormatted = ""

                                if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                    try {
                                        $dateTime = [datetime]::Parse($dateTimeString)
                                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                    } catch {
                                        Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    }
                                }

                                $row = @{
                                    DateTime       = $dateTimeFormatted
                                    Tool           = "Axiom"
                                    DataPath       = $_."Linked Path"
                                    TimestampInfo  = "Source Created"
                                    Description    = "File & Folder Access"
                                }
                                Normalize-Row -Fields $row -ArtifactName "LNKFiles"
                            }
                            $MasterTimeline += $lnkRows
                            $totalAdded += $lnkRows.Count
                        } catch {
                            Write-Host "    Error processing remaining batch: $_" -ForegroundColor Red
                        } finally {
                            if (Test-Path $tempFile) {
                                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }

                    $reader.Close()
                    Write-Host "  Added $totalAdded Axiom LNK file entries from $($file.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
                }

                Update-OverallProgress -CurrentSource "Axiom LNK Files"
            }
        } else {
            Write-Host "  No Axiom LNK files found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Axiom LNK path not found: $AxiomLNKPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom LNK File Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow
}

# Process Axiom MRU Opened-Saved Files
if ($ProcessAxiom) {
    Write-Host "Processing Axiom MRU Opened-Saved Files" -ForegroundColor Cyan
    $mruPath = Join-Path $AxiomDirectory "MRU Opened-Saved Files.csv"

    if (Test-Path $mruPath) {
        try {
            $reader = New-Object System.IO.StreamReader($mruPath)
            $headerLine = $reader.ReadLine()
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList

            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++

                if ($batchCount -ge $BatchSize) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                        $batchData = Import-Csv $tempFile
                        $rows = $batchData | ForEach-Object {
                            $dateTimeString = $_."Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""

                            if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString
                                }
                            }

                            if ($dateTimeFormatted -eq "") { return }

                            $row = @{
                                DateTime      = $dateTimeFormatted
                                Tool          = "Axiom"
                                DataPath      = $_."File Path"
                                DataDetails   = $_."File Name"
                                Description   = "File & Folder Access"
                                TimestampInfo = "Registry Modified"
                                EvidencePath  = $_."Source"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Registry - MRU Opened-Saved Files"
                        }

                        $MasterTimeline += $rows
                        $totalAdded += $rows.Count
                    } finally {
                        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                    }

                    $batch.Clear()
                    $batchCount = 0
                }
            }

            # Final batch
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    $batchData = Import-Csv $tempFile

                    $rows = $batchData | ForEach-Object {
                        $dateTimeString = $_."Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                        $dateTimeFormatted = ""

                        if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            } catch {
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString
                            }
                        }

                        if ($dateTimeFormatted -eq "") { return }

                        $row = @{
                            DateTime      = $dateTimeFormatted
                            Tool          = "Axiom"
                            DataPath      = $_."File Path"
                            DataDetails   = $_."File Name"
                            Description   = "File & Folder Access"
                            TimestampInfo = "Registry Modified"
                            EvidencePath  = $_."Source"
                        }
                        Normalize-Row -Fields $row -ArtifactName "Registry - MRU Opened-Saved Files"
                    }

                    $MasterTimeline += $rows
                    $totalAdded += $rows.Count
                } finally {
                    if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                }
            }

            $reader.Close()
            Write-Host "  Added $totalAdded Axiom MRU entries to timeline" -ForegroundColor Green
            Update-OverallProgress -CurrentSource "Axiom MRU Opened-Saved Files"

        } catch {
            Write-Host "  Error processing Axiom MRU Opened-Saved Files: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Axiom MRU CSV not found in: $AxiomDirectory" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom MRU Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow
}


# Process Axiom MRU Recent Files & Folders
if ($ProcessAxiom) {
    Write-Host "Processing Axiom MRU Recent Files & Folders" -ForegroundColor Cyan
    $recentPath = Join-Path $AxiomDirectory "MRU Recent Files & Folders.csv"

    if (Test-Path $recentPath) {
        try {
            $reader = New-Object System.IO.StreamReader($recentPath)
            $headerLine = $reader.ReadLine()
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList

            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++

                if ($batchCount -ge $BatchSize) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                        $batchData = Import-Csv $tempFile
                        $rows = $batchData | ForEach-Object {
                            $dateTimeString = $_."Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""

                            if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString
                                }
                            }

                            if ($dateTimeFormatted -eq "") { return }

                            $row = @{
                                DateTime      = $dateTimeFormatted
                                Tool          = "Axiom"
                                DataPath      = $_."File/Folder Link"
                                DataDetails   = $_."File/Folder Name"
                                Description   = "File & Folder Access"
                                TimestampInfo = "Registry Modified"
                                EvidencePath  = $_."Source"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Registry - MRU Recent Files & Folders"
                        }

                        $MasterTimeline += $rows
                        $totalAdded += $rows.Count
                    } finally {
                        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                    }

                    $batch.Clear()
                    $batchCount = 0
                }
            }

            # Final batch
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    $batchData = Import-Csv $tempFile

                    $rows = $batchData | ForEach-Object {
                        $dateTimeString = $_."Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                        $dateTimeFormatted = ""

                        if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            } catch {
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString
                            }
                        }

                        if ($dateTimeFormatted -eq "") { return }

                        $row = @{
                            DateTime      = $dateTimeFormatted
                            Tool          = "Axiom"
                            DataPath      = $_."File/Folder Link"
                            DataDetails   = $_."File/Folder Name"
                            Description   = "File & Folder Access"
                            TimestampInfo = "Registry Modified"
                            EvidencePath  = $_."Source"
                        }
                        Normalize-Row -Fields $row -ArtifactName "Registry - MRU Recent Files & Folders"
                    }

                    $MasterTimeline += $rows
                    $totalAdded += $rows.Count
                } finally {
                    if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                }
            }

            $reader.Close()
            Write-Host "  Added $totalAdded Axiom Recent MRU entries to timeline" -ForegroundColor Green
            Update-OverallProgress -CurrentSource "Axiom MRU Recent Files & Folders"

        } catch {
            Write-Host "  Error processing Axiom MRU Recent Files & Folders: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Axiom MRU Recent Files & Folders CSV not found in: $AxiomDirectory" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom MRU Recent Files & Folders (ProcessAxiom is disabled)" -ForegroundColor Yellow
}

# Process Axiom MRU Folder Access
if ($ProcessAxiom) {
    Write-Host "Processing Axiom MRU Folder Access" -ForegroundColor Cyan
    $folderPath = Join-Path $AxiomDirectory "MRU Folder Access.csv"

    if (Test-Path $folderPath) {
        try {
            $reader = New-Object System.IO.StreamReader($folderPath)
            $headerLine = $reader.ReadLine()
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList

            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++

                if ($batchCount -ge $BatchSize) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                        $batchData = Import-Csv $tempFile
                        $rows = $batchData | ForEach-Object {
                            $dateTimeString = $_."Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""

                            if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString
                                }
                            }

                            if ($dateTimeFormatted -eq "") { return }

                            $row = @{
                                DateTime      = $dateTimeFormatted
                                Tool          = "Axiom"
                                DataPath      = $_."Folder Accessed"
                                DataDetails   = $_."Application Name"
                                Description   = "File & Folder Access"
                                TimestampInfo = "Registry Modified"
                                EvidencePath  = $_."Source"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Registry - MRU Folder Access"
                        }

                        $MasterTimeline += $rows
                        $totalAdded += $rows.Count
                    } finally {
                        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                    }

                    $batch.Clear()
                    $batchCount = 0
                }
            }

            # Final batch
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    $batchData = Import-Csv $tempFile

                    $rows = $batchData | ForEach-Object {
                        $dateTimeString = $_."Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                        $dateTimeFormatted = ""

                        if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            } catch {
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString
                            }
                        }

                        if ($dateTimeFormatted -eq "") { return }

                        $row = @{
                            DateTime      = $dateTimeFormatted
                            Tool          = "Axiom"
                            DataPath      = $_."Folder Accessed"
                            DataDetails   = $_."Application Name"
                            Description   = "File & Folder Access"
                            TimestampInfo = "Registry Modified"
                            EvidencePath  = $_."Source"
                        }
                        Normalize-Row -Fields $row -ArtifactName "Registry - MRU Folder Access"
                    }

                    $MasterTimeline += $rows
                    $totalAdded += $rows.Count
                } finally {
                    if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                }
            }

            $reader.Close()
            Write-Host "  Added $totalAdded Axiom MRU Folder Access entries to timeline" -ForegroundColor Green
            Update-OverallProgress -CurrentSource "Axiom MRU Folder Access"

        } catch {
            Write-Host "  Error processing Axiom MRU Folder Access: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Axiom MRU Folder Access CSV not found in: $AxiomDirectory" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom MRU Folder Access (ProcessAxiom is disabled)" -ForegroundColor Yellow
}


# Process Axiom Prefetch Artifacts
if ($ProcessAxiom) {
    Write-Host "Processing Axiom Prefetch" -ForegroundColor Cyan
    $pfFile = Get-ChildItem -Path $AxiomDirectory -Filter "Prefetch*.csv" | Select-Object -First 1

    if ($pfFile) {
        try {
            $reader = New-Object System.IO.StreamReader($pfFile.FullName)
            $headerLine = $reader.ReadLine()
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList

            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++

                if ($batchCount -ge $BatchSize) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                        $batchData = Import-Csv $tempFile
                        $pfRows = $batchData | ForEach-Object {
                            $dateTimeString = $_."Last Run Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""
                        
                            if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString
                                }
                            }
                        
                            if ($dateTimeFormatted -eq "") { return }
                        
                            $row = @{
                                DateTime      = $dateTimeFormatted
                                Tool          = "Axiom"
                                DataPath      = $_."Application Path"
                                TimestampInfo = "Last Run"
                                DataDetails   = $_."Application Name"
                                Description   = "Program Execution"
                                EvidencePath  = $_."Source"
                                Count         = $_."Application Run Count"
                            }
                            Normalize-Row -Fields $row -ArtifactName "PrefetchFiles"
                        }

                        $MasterTimeline += $pfRows
                        $totalAdded += $pfRows.Count
                    } finally {
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }

                    $batch.Clear()
                    $batchCount = 0
                }
            }

            # Process remaining
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                    $batchData = Import-Csv $tempFile
                    $pfRows = $batchData | ForEach-Object {
                        $dateTimeString = $_."Last Run Date/Time - UTC+00:00 (M/d/yyyy)"
                        $dateTimeFormatted = ""
                    
                        if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            } catch {
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString
                            }
                        }
                    
                        if ($dateTimeFormatted -eq "") { return }
                    
                        $row = @{
                            DateTime      = $dateTimeFormatted
                            Tool          = "Axiom"
                            DataPath      = $_."Application Path"
                            TimestampInfo = "Last Run"
                            DataDetails   = $_."Application Name"
                            Description   = "Program Execution"
                            EvidencePath  = $_."Source"
                            Count         = $_."Application Run Count"
                        }
                        Normalize-Row -Fields $row -ArtifactName "PrefetchFiles"
                    }

                    $MasterTimeline += $pfRows
                    $totalAdded += $pfRows.Count
                } finally {
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            $reader.Close()
            Write-Host "  Added $totalAdded Axiom Prefetch entries to timeline" -ForegroundColor Green
            Update-OverallProgress -CurrentSource "Axiom Prefetch"

        } catch {
            Write-Host "  Error processing Axiom Prefetch: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Axiom Prefetch CSV not found in: $AxiomDirectory" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom Prefetch Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow
}



# Process Axiom Chrome Web History
if ($ProcessAxiom) {
    Write-Host "Processing Axiom Chrome Web History" -ForegroundColor Cyan
    $AxiomChromeHistoryPath = $AxiomDirectory
    if (Test-Path $AxiomChromeHistoryPath) {
        $ChromeHistoryFiles = Get-ChildItem -Path $AxiomChromeHistoryPath -Filter "Chrome Web History.csv" -ErrorAction SilentlyContinue
        $fileCount = $ChromeHistoryFiles.Count
        
        if ($fileCount -gt 0) {
            $fileCounter = 0
            foreach ($file in $ChromeHistoryFiles) {
                $fileCounter++
                Show-ProcessingProgress -Activity "Processing Axiom Chrome Web History" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
                
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
                                
                                # Process Last Visited Date/Time
                                $chromeHistoryRows = $batchData | ForEach-Object {
                                    $dateTimeString = $_."Last Visited Date/Time - UTC+00:00 (M/d/yyyy)"
                                    $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                    
                                    if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        }
                                        catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                           
                                        }
                                    }
                                    
                                    # Determine description based on URL content
                                    $url = $_."URL"
                                    $description = "Web Activity"
                                    
                                    # Check if the URL starts with file:// and extract the filename
                                    if ($url -match "^file:///") {
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
                                        DateTime     = $dateTimeFormatted
                                        Tool         = "Axiom"
                                        DataPath     = $url
                                        TimestampInfo = "Last Visited"
                                        DataDetails  = $_."Title"
                                        Description  = $description
                                        Count        = $_."Visit Count"
                                    }
                                    Normalize-Row -Fields $row -ArtifactName "ChromeHistory"
                                }
                                
                                # Add to master timeline
                                $MasterTimeline += $chromeHistoryRows
                                $totalAdded += $chromeHistoryRows.Count
                                
                                # Update progress
                                Show-ProcessingProgress -Activity "Processing Axiom Chrome History: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
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
                            
                            # Process Last Visited Date/Time
                            $chromeHistoryRows = $batchData | ForEach-Object {
                                $dateTimeString = $_."Last Visited Date/Time - UTC+00:00 (M/d/yyyy)"
                                $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                
                                if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                    try {
                                        $dateTime = [datetime]::Parse($dateTimeString)
                                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                    }
                                    catch {
                                        Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                        
                                    }
                                }
                                
                                # Determine description based on URL content
                                $url = $_."URL"
                                $description = "Web Activity"
                                
                                # Check if the URL starts with file:// and extract the filename
                                if ($url -match "^file:///") {
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
                                    DateTime     = $dateTimeFormatted
                                    Tool         = "Axiom"
                                    DataPath     = $url
                                    TimestampInfo = "Last Visited"
                                    DataDetails  = $_."Title"
                                    Description  = $description
                                    Count        = $_."Visit Count"
                                }
                                Normalize-Row -Fields $row -ArtifactName "ChromeHistory"
                            }
                            
                            # Add to master timeline
                            $MasterTimeline += $chromeHistoryRows
                            $totalAdded += $chromeHistoryRows.Count
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
                    Write-Host "  Added $totalAdded Axiom Chrome web history entries from $($file.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
                }
                
                Update-OverallProgress -CurrentSource "Axiom Chrome Web History"
            }
        } else {
            Write-Host "  No Axiom Chrome Web History files found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Axiom Chrome Web History path not found: $AxiomChromeHistoryPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom Chrome Web History (ProcessAxiom is disabled)" -ForegroundColor Yellow
}

# Process Axiom Edge/IE History
if ($ProcessAxiom) {
    Write-Host "Processing Axiom Edge/IE History" -ForegroundColor Cyan
    $AxiomEdgeIEPath = $AxiomDirectory
    if (Test-Path $AxiomEdgeIEPath) {
        $EdgeIEHistoryFiles = Get-ChildItem -Path $AxiomEdgeIEPath -Filter "Edge-Internet Explorer 10-11 Main History.csv" -ErrorAction SilentlyContinue
        $fileCount = $EdgeIEHistoryFiles.Count
        
        if ($fileCount -gt 0) {
            $fileCounter = 0
            foreach ($file in $EdgeIEHistoryFiles) {
                $fileCounter++
                Show-ProcessingProgress -Activity "Processing Axiom Edge/IE History" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
                
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
                                
                                # Process Accessed Date/Time
                                $edgeIEHistoryRows = $batchData | ForEach-Object {
                                    $dateTimeString = $_."Accessed Date/Time - UTC+00:00 (M/d/yyyy)"
                                    $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                    
                                    if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        }
                                        catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                            
                                        }
                                    }
                                    
                                    # Determine description based on URL content
                                    $url = $_."URL"
                                    $description = "Web Activity"
                                    
                                    # Check if the URL starts with file:// and extract the filename
                                    if ($url -match "^file:///") {
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
                                        DateTime      = $dateTimeFormatted
                                        Tool          = "Axiom"
                                        DataPath      = $url
                                        TomestampInfo = "Last Accessed"
                                        DataDetails   = $_."Page Title"
                                        Description   = $description
                                        User          = $_."User"
                                        Count         = $_."Access Count"
                                    }
                                    Normalize-Row -Fields $row -ArtifactName "EdgeIEHistory"
                                }
                                
                                # Add to master timeline
                                $MasterTimeline += $edgeIEHistoryRows
                                $totalAdded += $edgeIEHistoryRows.Count
                                
                                # Update progress
                                Show-ProcessingProgress -Activity "Processing Axiom Edge/IE History: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
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
                            
                            # Process Accessed Date/Time
                            $edgeIEHistoryRows = $batchData | ForEach-Object {
                                $dateTimeString = $_."Accessed Date/Time - UTC+00:00 (M/d/yyyy)"
                                $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                
                                if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                    try {
                                        $dateTime = [datetime]::Parse($dateTimeString)
                                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                    }
                                    catch {
                                        Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                        
                                    }
                                }
                                
                                # Determine description based on URL content
                                $url = $_."URL"
                                $description = "Web Activity"
                                
                                # Check if the URL starts with file:// and extract the filename
                                if ($url -match "^file:///") {
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
                                    DateTime              = $dateTimeFormatted
                                    Tool                  = "Axiom"
                                    DataPath              = $url
                                    TimestampInfo         = "Last Accessed"
                                    DataDetails           = $_."Page Title"
                                    Description           = $description
                                    User                  = $_."User"
                                    Count                 = $_."Access Count"
                                }
                                Normalize-Row -Fields $row -ArtifactName "EdgeIEHistory"
                            }
                            
                            # Add to master timeline
                            $MasterTimeline += $edgeIEHistoryRows
                            $totalAdded += $edgeIEHistoryRows.Count
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
                    Write-Host "  Added $totalAdded Axiom Edge/IE web history entries from $($file.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
                }
                
                Update-OverallProgress -CurrentSource "Axiom Edge/IE History"
            }
        } else {
            Write-Host "  No Axiom Edge/IE History files found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Axiom Edge/IE History path not found: $AxiomEdgeIEPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom Edge/IE History (ProcessAxiom is disabled)" -ForegroundColor Yellow
}

# Process Axiom Recycle Bin Artifacts
if ($ProcessAxiom) {
    Write-Host "Processing Axiom Recycle Bin" -ForegroundColor Cyan
    $RecycleBinPath = Join-Path $AxiomDirectory "Recycle Bin.csv"

    if (Test-Path $RecycleBinPath) {
        try {
            $reader = New-Object System.IO.StreamReader($RecycleBinPath)
            $headerLine = $reader.ReadLine()
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList

            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++

                if ($batchCount -ge $BatchSize) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                        $batchData = Import-Csv $tempFile
                        $rbRows = $batchData | ForEach-Object {
                            $dateTimeString = $_."Deleted Date/Time - UTC+00:00 (M/d/yyyy)"
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            } catch {
                                $dateTimeFormatted = $dateTimeString
                            }

                            $row = @{
                                DateTime       = $dateTimeFormatted
                                Tool           = "Axiom"
                                DataPath       = $_."Original Path"
                                TimestampInfo  = "Deleted Time"
                                Description    = "File System"
                                DataDetails    = $_."Current Location"
                                FileExtension  = [System.IO.Path]::GetExtension($_."File Name")
                                EvidencePath   = $_."Source"
                            }
                            Normalize-Row -Fields $row -ArtifactName "RecycleBin"
                        }

                        $MasterTimeline += $rbRows
                        $totalAdded += $rbRows.Count
                    } finally {
                        if (Test-Path $tempFile) {
                            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }

                    $batch.Clear()
                    $batchCount = 0
                }
            }

            # Process remaining
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                    $batchData = Import-Csv $tempFile
                    $rbRows = $batchData | ForEach-Object {
                        $dateTimeString = $_."Deleted Date/Time - UTC+00:00 (M/d/yyyy)"
                        try {
                            $dateTime = [datetime]::Parse($dateTimeString)
                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                        } catch {
                            $dateTimeFormatted = $dateTimeString
                        }

                        $row = @{
                            DateTime       = $dateTimeFormatted
                            Tool           = "Axiom"
                            DataPath       = $_."Original Path"
                            TimestampInfo  = "Deleted Time"
                            Description    = "File System"
                            DataDetails    = $_."Current Location"
                            FileExtension  = [System.IO.Path]::GetExtension($_."File Name")
                            EvidencePath   = $_."Source"
                        }
                        Normalize-Row -Fields $row -ArtifactName "RecycleBin"
                    }

                    $MasterTimeline += $rbRows
                    $totalAdded += $rbRows.Count
                } finally {
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            $reader.Close()
            Write-Host "  Added $totalAdded Axiom Recycle Bin entries to timeline" -ForegroundColor Green
            Update-OverallProgress -CurrentSource "Axiom Recycle Bin"

        } catch {
            Write-Host "  Error processing Axiom Recycle Bin: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Axiom Recycle Bin file not found: $RecycleBinPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom Recycle Bin Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow
}

# Process Axiom Shellbags
if ($ProcessAxiom) {
    Write-Host "Processing Axiom Shellbags" -ForegroundColor Cyan
    $AxiomShellbagsPath = $AxiomDirectory
    if (Test-Path $AxiomShellbagsPath) {
        $ShellbagFiles = Get-ChildItem -Path $AxiomShellbagsPath -Filter "*Shellbags.csv" -ErrorAction SilentlyContinue
        $fileCount = $ShellbagFiles.Count
        
        if ($fileCount -gt 0) {
            $fileCounter = 0
            foreach ($file in $ShellbagFiles) {
                $fileCounter++
                Show-ProcessingProgress -Activity "Processing Axiom Shellbags" -Status "File: $($file.Name)" -Current $fileCounter -Total $fileCount -NestedLevel 1
                
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
                                
                                # First Interaction Date/Time
                                $shellbagRows = $batchData | ForEach-Object {
                                    $dateTimeString = $_."First Interaction Date/Time - UTC+00:00 (M/d/yyyy)"
                                    $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                    
                                    if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        }
                                        catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                           
                                        }
                                    }
                                    
                                    $row = @{
                                        DateTime       = $dateTimeFormatted 
                                        Tool           = "Axiom"
                                        DataPath       = $_."Path"
                                        TimestampInfo  = "First Interaction"
                                        Description    = "File & Folder Access"
                                        EvidencePath   = $_."Source"
                                        
                                    }
                                    Normalize-Row -Fields $row -ArtifactName "Shellbags"
                                }
                                $MasterTimeline += $shellbagRows
                                $totalAdded += $shellbagRows.Count
                                
                                # Last Interaction Date/Time
                                $shellbagRows = $batchData | ForEach-Object {
                                    $dateTimeString = $_."Last Interaction Date/Time - UTC+00:00 (M/d/yyyy)"
                                    $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                    
                                    if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        }
                                        catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                            
                                        }
                                    }
                                    
                                    $row = @{
                                        DateTime       = $dateTimeFormatted 
                                        Tool           = "Axiom"
                                        DataPath       = $_."Path"
                                        TimestampInfo  = "Last Interacted"
                                        Description    = "File & Folder Access"
                                        EvidencePath   = $_."Source"
                                    }
                                    Normalize-Row -Fields $row -ArtifactName "Shellbags"
                                }
                                $MasterTimeline += $shellbagRows
                                $totalAdded += $shellbagRows.Count
                                
                                # File System Last Modified Date/Time
                                $shellbagRows = $batchData | ForEach-Object {
                                    $dateTimeString = $_."File System Last Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                                    $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                    
                                    if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                        try {
                                            $dateTime = [datetime]::Parse($dateTimeString)
                                            $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                        }
                                        catch {
                                            Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                           
                                        }
                                    }
                                    
                                    $row = @{
                                        DateTime       = $dateTimeFormatted 
                                        Tool           = "Axiom"
                                        DataPath       = $_."Path"
                                        TimestampInfo  = "Last Modified"
                                        Description    = "File & Folder Access"
                                        EvidencePath   = $_."Source"
                                    }
                                    Normalize-Row -Fields $row -ArtifactName "Shellbags"
                                }
                                $MasterTimeline += $shellbagRows
                                $totalAdded += $shellbagRows.Count
                                
                                # Update progress
                                Show-ProcessingProgress -Activity "Processing Axiom Shellbags: $($file.Name)" -Status "Processed $totalProcessed entries, added $totalAdded events" -Current $totalProcessed -Total $totalProcessed -NestedLevel 2
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
                            
                            # First Interaction Date/Time for remaining lines
                            $shellbagRows = $batchData | ForEach-Object {
                                $dateTimeString = $_."First Interaction Date/Time - UTC+00:00 (M/d/yyyy)"
                                $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                
                                if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                    try {
                                        $dateTime = [datetime]::Parse($dateTimeString)
                                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                    }
                                    catch {
                                        Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                        
                                    }
                                }
                                
                                $row = @{
                                    DateTime       = $dateTimeFormatted 
                                        Tool           = "Axiom"
                                        DataPath       = $_."Path"
                                        TimestampInfo  = "First Interaction"
                                        Description    = "File & Folder Access"
                                        EvidencePath   = $_."Source"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Shellbags"
                            }
                            $MasterTimeline += $shellbagRows
                            $totalAdded += $shellbagRows.Count
                            
                            # Last Interaction Date/Time for remaining lines
                            $shellbagRows = $batchData | ForEach-Object {
                                $dateTimeString = $_."Last Interaction Date/Time - UTC+00:00 (M/d/yyyy)"
                                $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                
                                if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                    try {
                                        $dateTime = [datetime]::Parse($dateTimeString)
                                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                    }
                                    catch {
                                        Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                        
                                    }
                                }
                                
                                $row = @{
                                    DateTime       = $dateTimeFormatted
                                        Tool           = "Axiom"
                                        DataPath       = $_."Path"
                                        TimestampInfo  = "Last Interacted"
                                        Description    = "File & Folder Access"
                                        EvidencePath   = $_."Source"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Shellbags"
                            }
                            $MasterTimeline += $shellbagRows
                            $totalAdded += $shellbagRows.Count
                            
                            # File System Last Modified Date/Time for remaining lines
                            $shellbagRows = $batchData | ForEach-Object {
                                $dateTimeString = $_."File System Last Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                                $dateTimeFormatted = ""  # Default value if date is invalid or empty
                                
                                if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                    try {
                                        $dateTime = [datetime]::Parse($dateTimeString)
                                        $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                    }
                                    catch {
                                        Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                        
                                    }
                                }
                                
                                $row = @{
                                    DateTime       = $dateTimeFormatted 
                                    Tool           = "Axiom"
                                    DataPath       = $_."Path"
                                    TimestampInfo  = "Last Modified"
                                    Description    = "File & Folder Access"
                                    EvidencePath   = $_."Source"
                                }
                                Normalize-Row -Fields $row -ArtifactName "Shellbags"
                            }
                            $MasterTimeline += $shellbagRows
                            $totalAdded += $shellbagRows.Count
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
                    Write-Host "  Added $totalAdded Axiom Shellbag entries from $($file.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "  Error processing $($file.Name): $_" -ForegroundColor Red
                }
                
                Update-OverallProgress -CurrentSource "Axiom Shellbags"
            }
        } else {
            Write-Host "  No Axiom Shellbag files found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Axiom Shellbags path not found: $AxiomShellbagsPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom Shellbags Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow 
}

# Process Axiom Shim Cache Artifacts AppCompat
if ($ProcessAxiom) {
    Write-Host "Processing Axiom Shim Cache" -ForegroundColor Cyan
    $shimPath = Join-Path $AxiomDirectory "Shim Cache.csv"

    if (Test-Path $shimPath) {
        try {
            $reader = New-Object System.IO.StreamReader($shimPath)
            $headerLine = $reader.ReadLine()
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList

            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++

                if ($batchCount -ge $BatchSize) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        $batchData = Import-Csv $tempFile

                        $rows = $batchData | ForEach-Object {
                            $path = $_."File Path"
                            if ([string]::IsNullOrWhiteSpace($path) -or $path -like "*\x*") { return }
                        
                            $dateTimeString = $_."Key Last Updated Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""
                        
                            if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString
                                }
                            }
                        
                            if ($dateTimeFormatted -eq "") { return }
                        
                            $fileName = $path -replace '.*\\([^\\]+)$', '$1'
                        
                            $row = @{
                                DateTime       = $dateTimeFormatted
                                Tool           = "Axiom"
                                DataPath       = $path
                                DataDetails    = $fileName
                                TimestampInfo  = "Last Modified"
                                EvidencePath   = $_."Source"
                                Description    = "Program Execution"
                            }
                            Normalize-Row -Fields $row -ArtifactName "AppCompatCache"
                        }
                        
                        $MasterTimeline += $rows
                        $totalAdded += $rows.Count
                    } finally {
                        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                    }
                    $batch.Clear()
                    $batchCount = 0
                }
            }

            # Final batch
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    $batchData = Import-Csv $tempFile

                    $rows = $batchData | ForEach-Object {
                        $path = $_."File Path"
                        if ([string]::IsNullOrWhiteSpace($path) -or $path -like "*\x*") { return }
                    
                        $dateTimeString = $_."Key Last Updated Date/Time - UTC+00:00 (M/d/yyyy)"
                        $dateTimeFormatted = ""
                    
                        if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            } catch {
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString
                            }
                        }
                    
                        if ($dateTimeFormatted -eq "") { return }
                    
                        $fileName = $path -replace '.*\\([^\\]+)$', '$1'
                    
                        $row = @{
                            DateTime       = $dateTimeFormatted
                            Tool           = "Axiom"
                            DataPath       = $path
                            DataDetails    = $fileName
                            TimestampInfo  = "Last Modified"
                            EvidencePath   = $_."Source"
                            Description    = "Program Execution"
                        }
                        Normalize-Row -Fields $row -ArtifactName "AppCompatCache"
                    }                    

                    $MasterTimeline += $rows
                    $totalAdded += $rows.Count
                } finally {
                    if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                }
            }

            $reader.Close()
            Write-Host "  Added $totalAdded Axiom Shim Cache entries to timeline" -ForegroundColor Green
            Update-OverallProgress -CurrentSource "Axiom Shim Cache"
        } catch {
            Write-Host "  Error processing Axiom Shim Cache: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Axiom Shim Cache file not found: $shimPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom Shim Cache Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow
}

# Process Axiom AutoRun Items
if ($ProcessAxiom) {
    Write-Host "Processing Axiom AutoRun Items" -ForegroundColor Cyan
    $autoRunPath = Join-Path $AxiomDirectory "AutoRun Items.csv"

    if (Test-Path $autoRunPath) {
        try {
            $reader = New-Object System.IO.StreamReader($autoRunPath)
            $headerLine = $reader.ReadLine()
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList

            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++

                if ($batchCount -ge $BatchSize) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append

                        $batchData = Import-Csv $tempFile
                        $rows = $batchData | ForEach-Object {
                            $dateTimeString = $_."Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                            $dateTimeFormatted = ""

                            if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                } catch {
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString
                                }
                            }

                            if ($dateTimeFormatted -eq "") { return }

                            $row = @{
                                DateTime      = $dateTimeFormatted
                                Tool          = "Axiom"
                                DataPath      = $_."File Path"
                                DataDetails   = $_."File Name"
                                CommandLine   = $_."Command"
                                Description   = "Program Execution"
                                TimestampInfo = "Registry Modified"
                                EvidencePath  = $_."Source"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Registry - AutoRun Items"
                        }

                        $MasterTimeline += $rows
                        $totalAdded += $rows.Count
                    } finally {
                        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                    }

                    $batch.Clear()
                    $batchCount = 0
                }
            }

            # Final batch
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    $batchData = Import-Csv $tempFile

                    $rows = $batchData | ForEach-Object {
                        $dateTimeString = $_."Registry Key Modified Date/Time - UTC+00:00 (M/d/yyyy)"
                        $dateTimeFormatted = ""

                        if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            } catch {
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString
                            }
                        }

                        if ($dateTimeFormatted -eq "") { return }

                        $row = @{
                            DateTime      = $dateTimeFormatted
                            Tool          = "Axiom"
                            DataPath      = $_."File Path"
                            DataDetails   = $_."File Name"
                            Description   = "Program Execution"
                            TimestampInfo = "Registry Modified"
                            EvidencePath  = $_."Source"
                        }
                        Normalize-Row -Fields $row -ArtifactName "Registry - AutoRun Items"
                    }

                    $MasterTimeline += $rows
                    $totalAdded += $rows.Count
                } finally {
                    if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                }
            }

            $reader.Close()
            Write-Host "  Added $totalAdded Axiom AutoRun entries to timeline" -ForegroundColor Green
            Update-OverallProgress -CurrentSource "Axiom AutoRun Items"

        } catch {
            Write-Host "  Error processing Axiom AutoRun Items: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Axiom AutoRun CSV not found in: $AxiomDirectory" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom AutoRun Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow
}



# Process Axiom UserAssist Artifacts
if ($ProcessAxiom) {
    Write-Host "Processing Axiom UserAssist" -ForegroundColor Cyan
    $userAssistPath = Join-Path $AxiomDirectory "UserAssist.csv"

    if (Test-Path $userAssistPath) {
        try {
            $reader = New-Object System.IO.StreamReader($userAssistPath)
            $headerLine = $reader.ReadLine()
            $batchCount = 0
            $totalProcessed = 0
            $totalAdded = 0
            $batch = New-Object System.Collections.ArrayList

            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                [void]$batch.Add($line)
                $batchCount++
                $totalProcessed++

                if ($batchCount -ge $BatchSize) {
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    try {
                        $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                        $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                        $batchData = Import-Csv $tempFile
                        
                        $uaRows = $batchData | ForEach-Object {
                            $dateTimeString = $_."Last Run Date/Time - UTC+00:00 (M/d/yyyy)"
                            if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                                try {
                                    $dateTime = [datetime]::Parse($dateTimeString)
                                    $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                                }
                                catch {
                                    Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                    $dateTimeFormatted = $dateTimeString
                                }
                            } else {
                                $dateTimeFormatted = ""
                            }
                            $row = @{
                                DateTime      = $dateTimeFormatted
                                Tool          = "Axiom"
                                DataPath      = $_."File Name"
                                Description   = "Program Execution"
                                TimestampInfo = "Last Run"
                                User          = $_."User Name"
                                Count         = $_."Application Run Count"
                                EvidencePath  = $_."Source"
                            }
                            Normalize-Row -Fields $row -ArtifactName "Registry - UserAssist"
                        }

                        $MasterTimeline += $uaRows
                        $totalAdded += $uaRows.Count
                    } finally {
                        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                    }
                    $batch.Clear()
                    $batchCount = 0
                }
            }

            # Process remaining rows
            if ($batch.Count -gt 0) {
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    $headerLine | Out-File -FilePath $tempFile -Encoding utf8
                    $batch | Out-File -FilePath $tempFile -Encoding utf8 -Append
                    $batchData = Import-Csv $tempFile

                    $uaRows = $batchData | ForEach-Object {
                        $dateTimeString = $_."Last Run Date/Time - UTC+00:00 (M/d/yyyy)"
                        if (![string]::IsNullOrWhiteSpace($dateTimeString)) {
                            try {
                                $dateTime = [datetime]::Parse($dateTimeString)
                                $dateTimeFormatted = $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
                            }
                            catch {
                                Write-Host "    Error parsing date: $dateTimeString" -ForegroundColor Yellow
                                $dateTimeFormatted = $dateTimeString
                            }
                        } else {
                            $dateTimeFormatted = ""
                        }

                        $row = @{
                            DateTime      = $dateTimeFormatted
                            Tool          = "Axiom"
                            DataPath      = $_."File Name"
                            Description   = "Program Execution"
                            TimestampInfo = "Last Run"
                            User          = $_."User Name"
                            Count         = $_."Application Run Count"
                            EvidencePath  = $_."Source"
                        }
                        Normalize-Row -Fields $row -ArtifactName "Registry - UserAssist"
                    }

                    $MasterTimeline += $uaRows
                    $totalAdded += $uaRows.Count
                } finally {
                    if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
                }
            }

            $reader.Close()
            Write-Host "  Added $totalAdded Axiom UserAssist entries to timeline" -ForegroundColor Green
            Update-OverallProgress -CurrentSource "Axiom UserAssist"
        } catch {
            Write-Host "  Error processing Axiom UserAssist: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  Axiom UserAssist file not found: $userAssistPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Skipping Axiom UserAssist Processing (ProcessAxiom is disabled)" -ForegroundColor Yellow
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
    $uniqueTimeline = [System.Collections.Generic.List[object]]::new()
    
    # Batch processing parameters
    $batchSize = 1000
    $totalBatches = [Math]::Ceiling($MasterTimeline.Count / $batchSize)
    
    # Create a progress bar
    for ($batch = 0; $batch -lt $totalBatches; $batch++) {
        # Calculate the start and end indices for the current batch
        $startIndex = $batch * $batchSize
        $endIndex = [Math]::Min($startIndex + $batchSize - 1, $MasterTimeline.Count - 1)
        
        # Progress bar
        $percentComplete = [Math]::Floor(($batch / $totalBatches) * 100)
        Write-Progress -Activity "Deduplicating Timeline" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
        
        # Process the current batch
        for ($i = $startIndex; $i -le $endIndex; $i++) {
            $entry = $MasterTimeline[$i]
            
            # Create a key based on date, path, and event details
            $key = "$($entry.DateTime)_$($entry.DataPath)_$($entry.DataDetails)_$($entry.EventID)_$($entry.ArtifactName)"
            
            # Only add unique entries
            if (-not $uniqueEntries.ContainsKey($key)) {
                $uniqueEntries[$key] = $true
                $uniqueTimeline.Add($entry)
            }
        }
    }
    
    # Complete the progress bar
    Write-Progress -Activity "Deduplicating Timeline" -Status "Complete" -Completed
    
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
