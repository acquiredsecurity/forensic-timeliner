# ============================================
# Deploy KAPE Chainsaw and Sigma with SentinelOne RemoteOps or build a local collector Interactively
# Author: @acquiredsecurity
# Description: Deploys KAPE (Kroll Artifact Parser and Extractor), BrowsingHistoryView $ Chainsaw + Built in Rules + Sigma Rules on Event Logs & MFT
# Remote Script Type: Triage Collection, parsing and mini-timeline
# Required Permissions: RemoteOps execution
# ============================================

# ============================================
# Parameters Inputs that this script will take
# ============================================
param(
    
    [Parameter(Mandatory=$false)]
    [switch]$Help,

    [Parameter(Mandatory=$false)]
    [string]$KapePathOverride, # Optional: manually override script default directory

    [Parameter(Mandatory = $false, HelpMessage = "KAPE Targets (default: !SANS_Triage,WebBrowsers)")]
    [string]$Targets = "!SANS_Triage,WebBrowsers",

    [Parameter(Mandatory = $false, HelpMessage = "KAPE Modules (default: !EZParser)")]
    [string]$Modules = "!EZParser",

    [Parameter(Mandatory = $false, HelpMessage = "Target source directory (default: C:)")]
    [string]$TargetSource = "C:",

    [Parameter(Mandatory = $false, HelpMessage = "Root output folder (default: C:\kape)")]
    [string]$OutputDir = "C:\kape",

    [Parameter(Mandatory = $false, HelpMessage = "Include Volume Shadow Copies in KAPE Collection")]
    [switch]$VSS,

    [Parameter(Mandatory = $false, HelpMessage = "Overwrite existing output in destination folder")]
    [switch]$Overwrite,
    
    [Parameter(Mandatory = $false, HelpMessage = "Enable Chainsaw analysis on Event Logs and MFT")]
    [switch]$Chainsaw,

    [Parameter(Mandatory = $false, HelpMessage = "Change Chainsaw analysis rules directory path")]
    [string]$RulesDirOverride,

    [Parameter(Mandatory = $false, HelpMessage = "Optional path to custom Sigma rules directory. Ideally add your rules inside modules\bin\chainsaw")]
    [string]$SigmaDir,

    [Parameter(Mandatory = $false, HelpMessage = "Run forensic_timeliner.ps1 after collection")]
    [switch]$RunTimeliner,

    [Parameter(Mandatory = $false)]
    [string]$TimelinerPath,  # Optional: custom path to forensic_timeliner.ps1 to timeline your artifact output from eztools and chainsaw
   
    [Parameter(Mandatory = $false)]
    [string]$ZipOutputOverride,

    [Parameter(Mandatory=$false)]
    [switch]$Use7Zip,

    [Parameter(Mandatory=$false, HelpMessage = "Remove the Source Collection Folder 'c:\kape and it's subfolders'" )]
    [switch]$CleanupAfterZip,

    [Parameter(Mandatory = $false)]
    [switch]$Interactive

)

# ============================================
# No-Args Guard: Prevent unintentional execution
# ============================================
if ($PSCmdlet.MyInvocation.BoundParameters.Count -eq 0) {
    Write-Warning "No arguments provided. Please use -Help to see options or -Interactive to build a command."
    exit 1
}

# ============================================
# Resolve Script Directory & Default Binaries
# ============================================

# Try to get script directory intelligently
if ($KapePathOverride -and (Test-Path $KapePathOverride)) {
    $scriptDir = Split-Path -Path $KapePathOverride -Parent
    Write-Host "Using overridden script directory: $scriptDir"
}
elseif ($Env:S1_PACKAGE_DIR_PATH -and (Test-Path $Env:S1_PACKAGE_DIR_PATH)) {
    $scriptDir = $Env:S1_PACKAGE_DIR_PATH
    Write-Host "Using SentinelOne script directory: $scriptDir"
}
else {
    # Fallback: Use path where script is currently executing
    $scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    Write-Host "Using local script execution path: $scriptDir"
}

# Now continue with binary discovery using this resolved $scriptDir
$defaultKapePath = ""
$defaultBrowsingHistoryPath = ""
$defaultChainsawRulesPath = ""
$defaultTimelinerPath = ""
$defaultZipOutput = ""

if ($scriptDir) {
    $defaultKapeExe = Get-ChildItem -Path $scriptDir -Filter "kape.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $defaultKapePath = if ($defaultKapeExe) { $defaultKapeExe.FullName } else { "" }

    $defaultBrowsingHistoryExe = Get-ChildItem -Path $scriptDir -Filter "BrowsingHistoryView.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $defaultBrowsingHistoryPath = if ($defaultBrowsingHistoryExe) { $defaultBrowsingHistoryExe.FullName } else { "" }

# Discover default Chainsaw rules directory
    $defaultChainsawRulesDir = Get-ChildItem -Path $scriptDir -Directory -Filter "rules" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $defaultChainsawRulesPath = if ($defaultChainsawRulesDir) { $defaultChainsawRulesDir.FullName } else { "" }

# Discover default Sigma rules directory 
    $defaultSigmaDir = Get-ChildItem -Path $scriptDir -Directory -Filter "sigma" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { $_.FullName }

    # Discover default Sigma rules directory 
    $defaultTimelinerScript = Get-ChildItem -Path $scriptDir -Filter "forensic_timeliner.ps1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $defaultTimelinerPath = if ($defaultTimelinerScript) { $defaultTimelinerScript.FullName } else { "" }

    if ($Env:S1_OUTPUT_DIR_PATH -and (Test-Path $Env:S1_OUTPUT_DIR_PATH)) {
        $defaultZipOutput = Join-Path -Path $Env:S1_OUTPUT_DIR_PATH -ChildPath "KAPE-Output.zip"
    } else {
        $defaultZipOutput = "C:\ProgramData\Sentinel\RSO\KAPE-Output.zip"
    }
}


# ============================================
# ASCII ARt Banner 
# ============================================


$bannerLines = @(
" _  __             									",                                   
 "| |/ /   ___    _ __     ___   ___    __ _  __      __ ",
 "| ' /   / _` | | '_ \   / _ \ / __|  / _` | \ \ /\ / /",
 "| . \  | (_| | | |_) | |  __/ \__ \ | (_| |  \ V  V / ",
 "|_|\_\  \__,_| | .__/   \___| |___/  \__,_|   \_/\_/",
  "              |__|									",
"",  
"Run Kape, Chainsaw +Sigma Forensic Mini-Timeline Builder, Interactive Parameter Menu to build script command line and more!", 
"| Made by https://github.com/acquiredsecurity",
"| with help from the robots [o_o] ",
"- Build a quick mini-timeline with Kape and Chainsaw run Rules and Sigma!",
"Shoutouts: ", 
"@EricZimmerman https://github.com/EricZimmerman  ",
"WithSecure Countercept (@FranticTyping, @AlexKornitzer) For making Chainsaw, @ https://github.com/WithSecureLabs/chainsaw ",
"Happy Timelining!"
)

# ============================================
# Loop through each line and apply conditional formatting
# ============================================

for ($i = 0; $i -lt $bannerLines.Count; $i++) {
    if ($i -eq 0 -or $i -eq 4 -or $i -eq 5) {
        Write-Host $bannerLines[$i] -ForegroundColor Cyan  # Top and bottom lines
    }
    elseif ($i -ge 1 -and $i -le 3) {
        Write-Host $bannerLines[$i] -ForegroundColor White  # Inner lines
    }
    else {
        Write-Host $bannerLines[$i] -ForegroundColor DarkGray  # Tagline or extra info
    }
}

# ============================================
# Help Menu 
# ============================================
if ($Help) {
    Write-Host ""
    Write-Host "==========================================================================================================" -ForegroundColor Cyan
    Write-Host "                           KapeSaw.ps1 Help Menu                 " -ForegroundColor Cyan
    Write-Host "==========================================================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ""
    Write-Host "Description:" -ForegroundColor Yellow
    Write-Host "  KapeSaw.ps1 is a forensic automation script that runs KAPE," -ForegroundColor Gray
    Write-Host "  Chainsaw, BrowsingHistoryView, and optionally generates a timeline using forensic_timeliner.ps1." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\KapeSaw.ps1 [-Chainsaw] [-RunTimeliner] [-Targets <targets>]" 
    Write-Host "                [-SigmaDir <path>] [-VSS] [-Overwrite]"
    Write-Host "                [-ZipOutputOverride <path>] [-TimelinerPath <path>]"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host '  .\KapeSaw.ps1 -Chainsaw -RunTimeliner'
    Write-Host '  .\KapeSaw.ps1 -Chainsaw -SigmaDir "C:\rules\sigma"'
    Write-Host '  .\KapeSaw.ps1 -Targets "!SANS_Triage" -Modules "!EZParser" -VSS'
    Write-Host '  .\KapeSaw.ps1 -KapePathOverride "C:\Dev\KapeSaw\Files" -ZipOutputOverride "C:\Output\KAPE.zip"'
    Write-Host '  .\KapeSaw.ps1 -KapePathOverride ".\kape.exe" -Chainsaw -SigmaDir "C:\sigma-master\rules\windows" -RunTimeliner -TimelinerPath "C:\Users\admin0x\Desktop\forensic_timeliner.ps1" -ZipOutputOverride "C:\kapeout.zip"'
    Write-Host ""
    Write-Host "" 
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -KapePathOverride       " -NoNewline; Write-Host "Override the default path to kape.exe" -ForegroundColor Gray
    Write-Host "  -Targets                " -NoNewline; Write-Host "Specify KAPE target list (default: '!SANS_Triage,WebBrowsers')" -ForegroundColor Gray
    Write-Host "  -Modules                " -NoNewline; Write-Host "Specify KAPE module list (default: '!EZParser')" -ForegroundColor Gray
    Write-Host "  -TargetSource           " -NoNewline; Write-Host "Drive to collect from (default: C:)" -ForegroundColor Gray
    Write-Host "  -OutputDir              " -NoNewline; Write-Host "Root directory for collection output (default: C:\kape)" -ForegroundColor Gray
    Write-Host "  -VSS                    " -NoNewline; Write-Host "Include Volume Shadow Copies in KAPE run" -ForegroundColor Gray
    Write-Host "  -Overwrite              " -NoNewline; Write-Host "Overwrite existing output folders" -ForegroundColor Gray
    Write-Host "  -Chainsaw               " -NoNewline; Write-Host "Enable Chainsaw event log and MFT analysis" -ForegroundColor Gray
    Write-Host "  -SigmaDir               " -NoNewline; Write-Host "Custom path to Sigma rules (required if using Chainsaw + Sigma)" -ForegroundColor Gray
    Write-Host "  -RulesDirOverride       " -NoNewline; Write-Host "Override default Chainsaw rules directory" -ForegroundColor Gray
    Write-Host "  -RunTimeliner           " -NoNewline; Write-Host "Run forensic_timeliner.ps1 to create Excel timeline" -ForegroundColor Gray
    Write-Host "  -TimelinerPath          " -NoNewline; Write-Host "Override the path to forensic_timeliner.ps1" -ForegroundColor Gray
    Write-Host "  -ZipOutputOverride      " -NoNewline; Write-Host "Custom output path for final zipped results" -ForegroundColor Gray
    Write-Host "  -Use7Zip                " -NoNewline; Write-Host "Use bundled 7-Zip to compress output instead of Compress-Archive" -ForegroundColor Gray
    Write-Host "  -CleanupAfterZip        " -NoNewline; Write-Host "Delete C:\kape after zipping (local mode only)" -ForegroundColor Gray
    Write-Host "  -Interactive            " -NoNewline; Write-Host "Launch interactive parameter setup" -ForegroundColor Gray
    Write-Host "  -Help                   " -NoNewline; Write-Host "Display this help menu" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==========================================================================================================" -ForegroundColor Cyan
    exit

}


# ============================================
# Interactive Help Menu 
# ============================================


if ($Interactive) {
    Write-Host "====== KapeSaw Interactive Configuration ======" -ForegroundColor Cyan

    function Prompt-Path($label, $default) {
        $input = Read-Host "$label [`Default: $default`]"
        if ([string]::IsNullOrWhiteSpace($input)) { return $default }
        while (-not (Test-Path $input)) {
            Write-Warning "Path does not exist: $input"
            $input = Read-Host "$label [`Default: $default`]"
            if ([string]::IsNullOrWhiteSpace($input)) { return $default }
        }
        return $input
    }

    function Prompt-String($label, $default) {
        $input = Read-Host "$label [`Default: $default`]"
        if ([string]::IsNullOrWhiteSpace($input)) {
            return $default
        } else {
            return $input
        }
    }

    function Prompt-YesNo($label, [bool]$default = $false) {
        $defaultStr = if ($default) { "Y" } else { "N" }
        $input = Read-Host "$label (Y/N) [`Default: $defaultStr`]"
        if ([string]::IsNullOrWhiteSpace($input)) { return $default }
        return $input.ToLower() -eq 'y'
    }

    function Prompt-Select($label, $options, $defaultIndex = 0) {
        Write-Host "$label"
        for ($i = 0; $i -lt $options.Count; $i++) {
            Write-Host " [$i] $($options[$i])"
        }
        $input = Read-Host "Choose number [`Default: $defaultIndex`]"
        if ([string]::IsNullOrWhiteSpace($input)) { return $options[$defaultIndex] }
        return $options[[int]$input]
    }

    # Confirm or override KAPE path
if ($defaultKapePath) {
    $useDefaultKape = Prompt-YesNo "KAPE was found at: $defaultKapePath Use this path?" $true
    if ($useDefaultKape) {
        $KapePathOverride = $defaultKapePath
    } else {
        $KapePathOverride = Prompt-Path "Enter custom path to kape.exe" $defaultKapePath
    }
} else {
    $KapePathOverride = Prompt-Path "Path to kape.exe" ""
}

    $Targets = Prompt-Select "Select KAPE Targets" @("!SANS_Triage,WebBrowsers", "!SANS_Triage", "!BasicCollection") 0
    $Modules = Prompt-Select "Select KAPE Modules" @("!EZParser", "!MFTECmd", "!Amcache", "!LECmd") 0
    $TargetSource = Prompt-String "Source Drive for Collection" $TargetSource
    $OutputDir = Prompt-String "Output Directory for Collection" $OutputDir
    $VSS = Prompt-YesNo "Include Volume Shadow Copies?" $VSS
    $Overwrite = Prompt-YesNo "Overwrite existing KAPE output?" $Overwrite

    $Chainsaw = Prompt-YesNo "Enable Chainsaw analysis?" $Chainsaw
if ($Chainsaw) {
    # Confirm or override Chainsaw rules directory
    if ($defaultChainsawRulesPath) {
        $useDefaultRules = Prompt-YesNo "Chainsaw rules found at: $defaultChainsawRulesPath Use this path?" $true
        if ($useDefaultRules) {
            $RulesDirOverride = $defaultChainsawRulesPath
        } else {
            $RulesDirOverride = Prompt-Path "Enter custom path to Chainsaw rules directory" $defaultChainsawRulesPath
        }
    } else {
        $RulesDirOverride = Prompt-Path "Path to Chainsaw rules directory" ""
    }
    
    # Confirm or override Sigma rules directory
    if ($defaultSigmaDir) {
        $useDefaultSigma = Prompt-YesNo "Sigma rules found at: $defaultSigmaDir Use this path?" $true
        if ($useDefaultSigma) {
            $SigmaDir = $defaultSigmaDir
        } else {
            $SigmaDir = Prompt-Path "Enter custom path to Sigma rules (optional)" $defaultSigmaDir
        }
    } else {
        $SigmaDir = Prompt-Path "Path to Sigma rules (optional)" ""
    }
}

    $RunTimeliner = Prompt-YesNo "Run forensic_timeliner.ps1 after collection?" $RunTimeliner
    if ($RunTimeliner) {
        if ($defaultTimelinerPath -ne "") {
            $useDefaultTimeliner = Prompt-YesNo "Forensic Timeliner found at: $defaultTimelinerPath. Use this path?" $true
            if ($useDefaultTimeliner) {
                $TimelinerPath = $defaultTimelinerPath
            }
            else {
                $TimelinerPath = Prompt-Path "Enter custom path to forensic_timeliner.ps1" $defaultTimelinerPath
            }
        }
        else {
            $TimelinerPath = Prompt-Path "Path to forensic_timeliner.ps1" ""
        }
        if (-not ($TimelinerPath -like "*.ps1")) {
            Write-Warning "Timeliner path does not point to a .ps1 script. Please verify it's a valid script file."
        }
}


    $ZipOutputOverride = Prompt-String "Path to output zip file" $ZipOutputOverride
    $Use7Zip = Prompt-YesNo "Use 7-Zip instead of Compress-Archive?" $Use7Zip
    $CleanupAfterZip = Prompt-YesNo "Delete C:\\kape after zipping?" $CleanupAfterZip

    Write-Host "Interactive configuration complete." -ForegroundColor Green
}




# ============================================
# Directory Cleanup 
# ============================================


# ============================================
# Remove c:\kape directory if it exists
# ============================================

$TriagefolderPath = "C:\kape"

if (Test-Path $TriagefolderPath) {
    Write-Host "Folder $TriagefolderPath exists. Deleting..."
    Remove-Item -Path $TriagefolderPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Folder deleted successfully."
} else {
    Write-Host "Folder $TriagefolderPath does not exist. No action needed."
}


# ============================================
# Output paths for debugging
# ============================================

Write-Host "Final script directory set to: $scriptDir"
Write-Host "Checking for KAPE executable in: $scriptDir"

# ============================================
# KAPE CHECKER - Check if KAPE exists in the S1 Directory 
# ============================================

$kapeExe = Get-ChildItem -Path $scriptDir -Filter "kape.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1


if ($kapeExe) {
    Write-Host "KAPE binary found at: $($kapeExe.FullName)"
} else {
    Write-Host "KAPE binary not found in: $scriptDir"
}

# ============================================
# Prepare KAPE output directories and set paths
# ============================================
$TriageDir = Join-Path -Path $OutputDir -ChildPath "triage"
$ModuleDestination = Join-Path -Path $OutputDir -ChildPath "timeline"
$ModuleSource = Join-Path -Path $OutputDir -ChildPath "triage"
$browsingHistoryOutput = Join-Path -Path $OutputDir -ChildPath "browsinghistory"
$chainsawOutput = Join-Path -Path $OutputDir -ChildPath "chainsaw"

# ============================================
# Create and Ensure output directories exist 
# ============================================

Write-Host "Output Directories being created....."
New-Item -Path $triageDir -ItemType Directory -Force | Out-Null
New-Item -Path $ModuleDestination -ItemType Directory -Force | Out-Null
New-Item -Path $browsingHistoryOutput -ItemType Directory -Force | Out-Null
New-Item -Path $chainsawOutput -ItemType Directory -Force | Out-Null

Write-Host "KAPE binary found at: $($kapeExe.FullName)"
Write-Host "KAPE output directories prepared: $triageDir, $ModuleDestination"

if (-not $kapeExe) {
    Write-Error "ERROR: KAPE executable not found. Exiting."
    exit 1
}
# ============================================
# Execute KAPE Targets Collection
# ============================================

Write-Host "Running KAPE Targets Collection..."
$kapeTargetArgs = @(
    "--tsource", $TargetSource,
    "--tdest", $triageDir,
    "--tflush",
    "--target", $Targets
)

$process = Start-Process -FilePath $kapeExe.FullName -ArgumentList $kapeTargetArgs -Wait -NoNewWindow -PassThru

if ($process.ExitCode -ne 0) {
    Write-Error "KAPE target collection failed with exit code $($process.ExitCode)."
    exit 2
}

Write-Host "KAPE Targets Collection Completed Successfully."

# ============================================
# Execute KAPE Modules Processing
# ============================================

Write-Host "Running KAPE Module Execution..."
$kapeModuleArgs = @(
    "--msource", $triageDir,
    "--mdest", $ModuleDestination,
    "--mflush",
    "--module", $Modules
)

$process = Start-Process -FilePath $kapeExe.FullName -ArgumentList $kapeModuleArgs -Wait -NoNewWindow -PassThru

if ($process.ExitCode -ne 0) {
    Write-Error "KAPE module execution failed with exit code $($process.ExitCode)."
    exit 2
}

Write-Host "KAPE Module Execution Completed Successfully."

# ============================================
# Begin Secondary Modules 
# ============================================


# ============================================
# Dynamically locate BrowsingHistoryView executable
# ============================================

$browsingHistoryViewExe = Get-ChildItem -Path $scriptDir -Filter "BrowsingHistoryView.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($browsingHistoryViewExe) {
    Write-Host "BrowsingHistoryView binary found at: $($browsingHistoryViewExe.FullName)"
    
    # Ensure the output directory exists

    if (-not (Test-Path $browsingHistoryOutput)) {
        New-Item -Path $browsingHistoryOutput -ItemType Directory -Force | Out-Null
    }


    # Construct Browsing History arguments
    $browsingHistoryArgs = @(
        "-h",
        "/scomma", "$browsingHistoryOutput\WebResults.csv",
        "/SaveDirect",
        "/HistorySourceFolder", "C:\kape\triage\C\Users"
    )

    # Execute the process
    $process = Start-Process -FilePath $browsingHistoryViewExe.FullName -ArgumentList $browsingHistoryArgs -Wait -NoNewWindow -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Host "BrowsingHistoryView execution completed successfully."
    } else {
        Write-Error "BrowsingHistoryView execution failed with exit code $($process.ExitCode)."
    }
} else {
    Write-Error "BrowsingHistoryView.exe not found in package directory: $scriptDir"
}


## Verify WebResults was collected
$browsingHistoryResults = Join-Path -Path $browsingHistoryOutput -ChildPath "WebResults.csv"
if (-not (Test-Path $browsingHistoryResults)) {
    Write-Warning "BrowsingHistoryView did not produce output file: $browsingHistoryResults"
}


# ============================================
#  Begin Chainsaw Module 
# ============================================

if ($Chainsaw) {
    Write-Host "Chainsaw flag detected running Chainsaw module..." -ForegroundColor Cyan

    # Ensure output directory exists
    if (-not (Test-Path $chainsawOutput)) {
        New-Item -Path $chainsawOutput -ItemType Directory -Force | Out-Null
    }

    # Locate Chainsaw executable
    $chainsawExe = Get-ChildItem -Path $scriptDir -Filter "chainsaw.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $mappingsFile = Get-ChildItem -Path $scriptDir -Filter "sigma-event-logs-all.yml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

    # Allow RulesDirOverride if provided
    if ($RulesDirOverride -and (Test-Path $RulesDirOverride)) {
        $rulesDir = Get-Item $RulesDirOverride
        if ($rulesDir -and $rulesDir.PSIsContainer) {
            Write-Host "Using rules directory override"
        } else {
            Write-Warning "Provided RulesDirOverride is not a valid directory: $RulesDirOverride"
            $rulesDir = $null
        }
    } else {
        $rulesDir = Get-ChildItem -Path $scriptDir -Directory -Filter "rules" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($rulesDir) {
            Write-Host "Found default Chainsaw rules directory"
        }
    }

    if ($chainsawExe -and $mappingsFile -and $rulesDir) {
        Write-Host "Running Chainsaw Event Log Hunt..."

        $chainsawEVTArgs = @(
            "hunt",
            "C:\kape\triage\C\Windows\System32\winevt\Logs",
            "--mapping", $mappingsFile.FullName,
            "--rule", $rulesDir.FullName,
            "--csv",
            "--output", $chainsawOutput,
            "--skip-errors"
        )

        if ($SigmaDir -and (Test-Path $SigmaDir)) {
            Write-Host "Adding Sigma rules directory to Chainsaw args: $SigmaDir"
            $chainsawEVTArgs += @("--sigma", $SigmaDir)
        }

        $process = Start-Process -FilePath $chainsawExe.FullName -ArgumentList $chainsawEVTArgs -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host " Chainsaw Event Log Analysis completed successfully."
        } else {
            Write-Warning "Chainsaw Event Log Analysis failed with exit code $($process.ExitCode)."
        }

        Write-Host "Running Chainsaw on MFT..."

        $chainsawMFTArgs = @(
            "hunt",
            "C:\kape\triage\C\$MFT",
            "--rule", $rulesDir.FullName,
            "--csv",
            "--output", $chainsawOutput,
            "--skip-errors"
        )

        $process = Start-Process -FilePath $chainsawExe.FullName -ArgumentList $chainsawMFTArgs -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "Chainsaw MFT Analysis completed successfully."
        } else {
            Write-Warning "Chainsaw MFT Analysis failed with exit code $($process.ExitCode)."
        }

        # Final validation
        $chainsawResults = Join-Path -Path $chainsawOutput -ChildPath "chainsaw_results.csv"
        if (-not (Test-Path $chainsawResults)) {
            Write-Warning "Chainsaw did not produce expected results at: $chainsawResults"
        } else {
            Write-Host "Chainsaw results saved to: $chainsawResults"
        }
    } else {
        Write-Warning "One or more Chainsaw dependencies not found. Skipping Chainsaw module."
    }
} else {
    Write-Host "Chainsaw flag not set skipping Chainsaw module." -ForegroundColor DarkGray
}


# ============================================
# Run Forensic Timeliner if Enabled 
# ============================================

if ($RunTimeliner) {
    Write-Host "Running Forensic Timeliner..."

    try {
        if ($TimelinerPath -and (Test-Path $TimelinerPath)) {
            $resolvedTimeliner = Resolve-Path -Path $TimelinerPath
            $timelinerScript = $resolvedTimeliner.Path
            Write-Host "Using overridden timeliner script: $timelinerScript"
        } else {
            $timelinerScript = Join-Path -Path $scriptDir -ChildPath "Modules\bin\forensic_timeliner\forensic_timeliner.ps1"
            Write-Host "Using default timeliner path: $timelinerScript"
        }

        if (Test-Path $timelinerScript) {
            & $timelinerScript
            Write-Host "Forensic Timeliner executed successfully."
        } else {
            Write-Error "Forensic Timeliner script not found at: $timelinerScript"
        }
    } catch {
        Write-Error "Error while executing forensic_timeliner: $_"
    }
}

# ============================================
# Begin Zipping Function 
# ============================================

# Determine zip output path
if ($ZipOutputOverride -and (Test-Path -Path (Split-Path $ZipOutputOverride -Parent))) {
    $zipOutput = $ZipOutputOverride
    Write-Host "Using overridden zip output path: $zipOutput"
} elseif ($Env:S1_OUTPUT_DIR_PATH -and (Test-Path -Path $Env:S1_OUTPUT_DIR_PATH)) {
    $zipOutput = Join-Path -Path $Env:S1_OUTPUT_DIR_PATH -ChildPath "KAPE-Output.zip"
    Write-Host "Using SentinelOne output path: $zipOutput"
} else {
    $zipOutput = "C:\ProgramData\Sentinel\RSO\KAPE-Output.zip"
    Write-Host "Using fallback zip output path: $zipOutput"
}

# Try zipping
try {
    if ($Use7Zip) {
        Write-Host "Using 7-Zip for compression..."
        $sevenZipPath = Join-Path -Path $scriptDir -ChildPath "Modules\bin\7-Zip\7z.exe"
        if (-not (Test-Path $sevenZipPath)) {
            throw "7-Zip executable not found at: $sevenZipPath"
        }

        $sevenZipArgs = @(
    "a", "-tzip", "$zipOutput",
    (Join-Path -Path $OutputDir -ChildPath "*"),
    "-mx9"
)
        $process = Start-Process -FilePath $sevenZipPath -ArgumentList $sevenZipArgs -Wait -NoNewWindow -PassThru

        if ($process.ExitCode -ne 0) {
            throw "7-Zip failed "
        }

        Write-Host "Files successfully zipped using 7-Zip to: $zipOutput"
    }
    else {
        Write-Host "Zipping with Compress-Archive..."
        Compress-Archive -Path "$OutputDir\*" -DestinationPath $zipOutput -Force -ErrorAction Stop
        Write-Host "Files successfully zipped to: $zipOutput"
    }
}
catch {
    Write-Error "Zipping failed: $($_.Exception.Message)"
}

#Waiting
Write-Host "Waiting for SentinelOne to collect output..... [o_o] We hope you have enjoyd this experience."
Start-Sleep -Seconds 90

# ============================================
# Deletion / Cleanup  Block 
# ============================================


# Final Cleanup Logic
$shouldDelete = $false

if ($Env:S1_OUTPUT_DIR_PATH) {
    $shouldDelete = $true
    Write-Host "S1 environment detected - cleanup will run automatically."
} elseif ($CleanupAfterZip) {
    $shouldDelete = $true
    Write-Host "CleanupAfterZip flag set - cleaning up local C:\kape folder."
}

if ($shouldDelete) {
    if (Test-Path "C:\kape") {
        Write-Host "Deleting C:\kape..."

        try {
            Remove-Item -Path "C:\kape" -Recurse -Force -ErrorAction Stop
            Write-Host "C:\kape directory deleted successfully."
        } catch {
            Write-Warning "Failed to delete C:\kape: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Cleanup requested but C:\kape not found."
    }
} else {
    Write-Host "Skipping cleanup - neither SentinelOne nor CleanupAfterZip set."
}
