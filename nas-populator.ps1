<#
NAS-Populator
https://github.com/cosmickatamari/nas-populator

Created by: cosmickatamari
Updated: 03/08/2026
#>

param(
    [ValidateSet('Raw', 'Zip')]
    [string]$Mode = 'Zip',
    [switch]$Help,
    [switch]$RawOrg,
    [switch]$RawNoOrg,
    [switch]$ZipOrg,
    [switch]$ZipNoOrg,
    [switch]$Cleanup,
    [string]$DestinationRoot,
    [string]$TempRoot
)

Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'nas-populator-helpers.ps1')

if ($PSVersionTable.PSVersion.Major -ne 7) {
    Write-Fail "PowerShell 7.x is required."
}

Clear-Host
Write-Host "=== [ $script:ScriptName ]===" -ForegroundColor Blue
Write-Host "=== [ Version $script:ScriptVersion ] ===" -ForegroundColor Blue
Write-Host ""

if ($Help) {
    Show-Help
}

$scriptRoot = $PSScriptRoot
$settingsPath = Join-Path $scriptRoot 'nas-populator-settings.json'
$consolePath = Join-Path $scriptRoot 'nas-populator-sources.psd1'
$consoleNamesPath = Join-Path $scriptRoot 'nas-populator-console-names.json'
$settingsTemplatePath = Join-Path $scriptRoot 'nas-populator-settings.template.json'
$consoleTemplatePath = Join-Path $scriptRoot 'nas-populator-sources.template.psd1'
$consoleNamesTemplatePath = Join-Path $scriptRoot 'nas-populator-console-names.template.json'

$configRecreatedFromTemplate = $false

if (-not (Test-Path -LiteralPath $settingsPath)) {
    Write-Host "Settings file not found: " -NoNewline -ForegroundColor Yellow
    Write-Host ([System.IO.Path]::GetFileName($settingsPath)) -ForegroundColor White
    if (Read-YesNoDefaultYes "Recreate the settings file now?") {
        if (-not (Test-Path -LiteralPath $settingsTemplatePath)) {
            Write-Host "Settings template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($settingsTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
        $configRecreatedFromTemplate = $true
    } else {
        Write-Fail "Settings file is required."
    }
}
if (-not (Test-Path -LiteralPath $consolePath)) {
    Write-Host "Console sources file not found: " -NoNewline -ForegroundColor Yellow
    Write-Host ([System.IO.Path]::GetFileName($consolePath)) -ForegroundColor White
    if (Read-YesNoDefaultYes "Recreate the console sources file now?") {
        if (-not (Test-Path -LiteralPath $consoleTemplatePath)) {
            Write-Host "Console template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($consoleTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $consoleTemplatePath -Destination $consolePath -Force
        $configRecreatedFromTemplate = $true
    } else {
        Write-Fail "Console sources file is required."
    }
}
if (-not (Test-Path -LiteralPath $consoleNamesPath)) {
    Write-Host "Console names file not found: " -NoNewline -ForegroundColor Yellow
    Write-Host ([System.IO.Path]::GetFileName($consoleNamesPath)) -ForegroundColor White
    if (Read-YesNoDefaultYes "Recreate the console names file now?") {
        if (-not (Test-Path -LiteralPath $consoleNamesTemplatePath)) {
            Write-Host "Console names template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($consoleNamesTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $consoleNamesTemplatePath -Destination $consoleNamesPath -Force
        $configRecreatedFromTemplate = $true
    } else {
        Write-Fail "Console names file is required."
    }
}

$settings = $null
try {
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "Settings file is invalid: " -NoNewline -ForegroundColor Yellow
    Write-Host ([System.IO.Path]::GetFileName($settingsPath)) -ForegroundColor White
    Write-Warn "Details: $($_.Exception.Message)"
    $rawSettings = Get-Content -LiteralPath $settingsPath -Raw
    $repaired = Repair-JsonPathValues -JsonText $rawSettings -Keys @('DestinationRoot', 'TempRoot', 'SevenZipExe')
    if ($repaired -ne $rawSettings) {
        try {
            $repaired | ConvertFrom-Json | Out-Null
            $repaired | Set-Content -Path $settingsPath -Encoding UTF8
            Write-Warn "Settings file contained unescaped backslashes and was auto-corrected."
            Write-Info "Restarting script to load corrected settings."
            & $PSCommandPath @PSBoundParameters
            exit $LASTEXITCODE
        } catch {
            $settings = $null
        }
    }
    if (-not $settings) {
        if (Read-YesNoDefaultYes "Recreate the settings file now?") {
            if (-not (Test-Path -LiteralPath $settingsTemplatePath)) {
                Write-Host "Settings template not found: " -NoNewline -ForegroundColor Yellow
                Write-Host ([System.IO.Path]::GetFileName($settingsTemplatePath)) -ForegroundColor White
                exit 1
            }
            Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
            $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
            $configRecreatedFromTemplate = $true
        } else {
            Write-Fail "Settings file is required."
        }
    }
}

$allConsoles = $null
try {
    $consoleData = Import-PowerShellDataFile -LiteralPath $consolePath
    $allConsoles = $consoleData.Sources
} catch {
    Write-Host "Console sources file is invalid: " -NoNewline -ForegroundColor Yellow
    Write-Host ([System.IO.Path]::GetFileName($consolePath)) -ForegroundColor White
    Write-Warn "Details: $($_.Exception.Message)"
    if (Read-YesNoDefaultYes "Recreate the console sources file now?") {
        if (-not (Test-Path -LiteralPath $consoleTemplatePath)) {
            Write-Host "Console template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($consoleTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $consoleTemplatePath -Destination $consolePath -Force
        $consoleData = Import-PowerShellDataFile -LiteralPath $consolePath
        $allConsoles = $consoleData.Sources
        $configRecreatedFromTemplate = $true
    } else {
        Write-Fail "Console sources file is required."
    }
}

$consoleNames = $null
try {
    $consoleNames = Get-Content -LiteralPath $consoleNamesPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "Console names file is invalid: " -NoNewline -ForegroundColor Yellow
    Write-Host ([System.IO.Path]::GetFileName($consoleNamesPath)) -ForegroundColor White
    Write-Warn "Details: $($_.Exception.Message)"
    if (Read-YesNoDefaultYes "Recreate the console names file now?") {
        if (-not (Test-Path -LiteralPath $consoleNamesTemplatePath)) {
            Write-Host "Console names template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($consoleNamesTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $consoleNamesTemplatePath -Destination $consoleNamesPath -Force
        $consoleNames = Get-Content -LiteralPath $consoleNamesPath -Raw | ConvertFrom-Json
        $configRecreatedFromTemplate = $true
    } else {
        Write-Fail "Console names file is required."
    }
}

if (-not $settings.SevenZipExe -or -not $settings.ArchiveExtensions) {
    Write-Warn "Settings file is missing required values."
    if (Read-YesNoDefaultYes "Recreate the settings file now?") {
        if (-not (Test-Path -LiteralPath $settingsTemplatePath)) {
            Write-Host "Settings template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($settingsTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $configRecreatedFromTemplate = $true
    } else {
        Write-Fail "Settings file is required."
    }
}

if ($configRecreatedFromTemplate) {
    Write-Info "Restarting script to load recreated config."
    & $PSCommandPath @PSBoundParameters
    exit $LASTEXITCODE
}

if ($settings -and $settings.PSObject.Properties['SharePassword'] -and $null -ne $settings.SharePassword -and $settings.SharePassword -isnot [SecureString]) {
    $pwdStr = $settings.SharePassword.ToString()
    if (-not [string]::IsNullOrWhiteSpace($pwdStr)) {
        $settings.SharePassword = ConvertTo-SecureString $pwdStr -AsPlainText -Force
    }
}

$consoleNameMap = @{}
$consoleSubDirMap = @{}
$consoleDisplayNameMap = @{}
$consoleExtensionsMap = @{}
$consoleOpticalSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $consoleNames) {
    if (-not $entry.Name) { continue }
    $key = $entry.Name.ToLowerInvariant()
    if ($entry.ShortName) {
        $consoleNameMap[$key] = $entry.ShortName
    }
    $consoleDisplayNameMap[$key] = $entry.Name
    if ($entry.PSObject.Properties['SubDir'] -and $entry.SubDir) {
        $consoleSubDirMap[$key] = $entry.SubDir
    }
    if ($entry.PSObject.Properties['Optical'] -and $entry.Optical -eq 'yes') {
        $consoleOpticalSet.Add($entry.Name) | Out-Null
    }
    $extSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $extSet.Add('.rom') | Out-Null
    if ($entry.PSObject.Properties['Extensions'] -and $null -ne $entry.Extensions) {
        foreach ($e in @($entry.Extensions)) {
            $ex = $e.Trim()
            if (-not $ex.StartsWith('.')) { $ex = '.' + $ex }
            $extSet.Add($ex) | Out-Null
        }
    }
    $consoleExtensionsMap[$key] = $extSet
}

function Get-ConsoleDestinationPathByKey {
    param([Parameter(Mandatory = $true)][string]$ConsoleKey)
    if (-not $consoleNameMap.ContainsKey($ConsoleKey) -or -not $consoleNameMap[$ConsoleKey]) { return $null }
    $destPath = Join-Path $DestinationRoot $consoleNameMap[$ConsoleKey]
    if ($consoleSubDirMap.ContainsKey($ConsoleKey) -and $consoleSubDirMap[$ConsoleKey]) {
        $destPath = Join-Path $destPath $consoleSubDirMap[$ConsoleKey]
    }
    return $destPath
}

function Test-SgbRedirectForConsoleItem {
    param(
        [Parameter(Mandatory = $true)][string]$ConsoleKey,
        [Parameter(Mandatory = $true)][string]$ItemName
    )
    return (($ConsoleKey -eq 'nintendo game boy' -or $ConsoleKey -eq 'nintendo game boy color') -and $ItemName -imatch '\(SGB')
}

$organizeRegions = $false
$doCleanup = $false
$doProcessing = $true
$doRecreateConfig = $false

if (-not $PSBoundParameters.ContainsKey('DestinationRoot') -and $settings.DestinationRoot) {
    $DestinationRoot = Resolve-DestinationPath -Path $settings.DestinationRoot
}
if (-not $PSBoundParameters.ContainsKey('TempRoot') -and $settings.TempRoot) {
    $TempRoot = $settings.TempRoot
}

if (-not $DestinationRoot) {
    Write-Host 'Edit the settings file ' -NoNewline -ForegroundColor DarkYellow
    Write-Host 'nas-populator-settings.json' -NoNewline -ForegroundColor White
    Write-Host ', or pass the ' -NoNewline -ForegroundColor DarkYellow
    Write-Host '-DestinationRoot' -NoNewline -ForegroundColor White
    Write-Host ' parameter.' -ForegroundColor DarkYellow
    Write-Fail 'DestinationRoot is required.'
}
$DestinationRoot = Resolve-DestinationPath -Path $DestinationRoot
if (-not $TempRoot) {
    Write-Host 'Edit the settings file ' -NoNewline -ForegroundColor DarkYellow
    Write-Host 'nas-populator-settings.json' -NoNewline -ForegroundColor White
    Write-Host ', or pass the ' -NoNewline -ForegroundColor DarkYellow
    Write-Host '-TempRoot' -NoNewline -ForegroundColor White
    Write-Host ' parameter.' -ForegroundColor DarkYellow
    Write-Fail 'TempRoot is required.'
}
if ($TempRoot -and -not (Test-Path -LiteralPath $TempRoot)) {
    New-Item -Path $TempRoot -ItemType Directory -Force | Out-Null
}

Write-Host "Settings:" -ForegroundColor DarkYellow
Write-Host "  - Destination:    " -NoNewline -ForegroundColor White
Write-Host $DestinationRoot -ForegroundColor Yellow
Write-Host "  - Temp:           " -NoNewline -ForegroundColor White
Write-Host $TempRoot -ForegroundColor Yellow
Write-Host ""

$menuOptions = @($RawOrg, $RawNoOrg, $ZipOrg, $ZipNoOrg, $Cleanup) | Where-Object { $_ }
if ($menuOptions -isnot [System.Array]) { $menuOptions = @($menuOptions) }
if ($menuOptions.Count -gt 1) {
    Write-Fail "Multiple mode switches passed. Use only one."
}

if ($RawOrg) {
    $Mode = 'Raw'
    $organizeRegions = $true
    $doCleanup = $true
} elseif ($RawNoOrg) {
    $Mode = 'Raw'
    $organizeRegions = $false
    $doCleanup = $true
} elseif ($ZipOrg) {
    $Mode = 'Zip'
    $organizeRegions = $true
    $doCleanup = $true
} elseif ($ZipNoOrg) {
    $Mode = 'Zip'
    $organizeRegions = $false
    $doCleanup = $true
} elseif ($Cleanup) {
    $doProcessing = $false
    $organizeRegions = $false
    $doCleanup = $true
} else {
    Write-Host "Select an option:" -ForegroundColor DarkYellow
    Write-Host "  1. Archive extraction, copying dumps and images, with region organization."
    Write-Host "  2. Archive extraction, copying dumps and images, without region organization."
    Write-Host "  3. Compress ROMs, copying dumps and disc images (ZIP files copied as-is), with region organization."
    Write-Host "  4. Compress ROMs, copying dumps and disc images (ZIP files copied as-is), without region organization."
    Write-Host "  5. Destination file/folder cleanup."
    Write-Host "  6. Recreate config files from templates."
    Write-Host "  E. Exit"

    Write-Host ""
    Write-Host "Options 1-4 will also perform empty destination folder cleanup."
    $menuValid = $false
    while (-not $menuValid) {
        $choice = (Read-Host "Enter option (1-6 or E to exit)").Trim()
        if ($choice -match '^(e|exit)$') { exit 0 }
        switch ($choice) {
            '1' { $Mode = 'Raw'; $organizeRegions = $true; $doCleanup = $true; $menuValid = $true }
            '2' { $Mode = 'Raw'; $organizeRegions = $false; $doCleanup = $true; $menuValid = $true }
            '3' { $Mode = 'Zip'; $organizeRegions = $true; $doCleanup = $true; $menuValid = $true }
            '4' { $Mode = 'Zip'; $organizeRegions = $false; $doCleanup = $true; $menuValid = $true }
            '5' { $doProcessing = $false; $organizeRegions = $false; $doCleanup = $true; $menuValid = $true }
            '6' { $doRecreateConfig = $true; $menuValid = $true }
            Default {
                Write-Warn "Invalid selection. Please enter a value from above, or E to exit."
            }
        }
    }
}

if ($doRecreateConfig) {
    $missingTemplates = @()
    if (Read-YesNoDefaultYes "`nRecreate settings file (nas-populator-settings.json) from template?") {
        if (Test-Path -LiteralPath $settingsTemplatePath) {
            Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
            Write-Info "Recreated: nas-populator-settings.json"
        } else {
            $missingTemplates += 'nas-populator-settings.template.json'
        }
    }
    if (Read-YesNoDefaultYes "Recreate console sources file (nas-populator-sources.psd1) from template?") {
        if (Test-Path -LiteralPath $consoleTemplatePath) {
            Copy-Item -LiteralPath $consoleTemplatePath -Destination $consolePath -Force
            Write-Info "Recreated: nas-populator-sources.psd1"
        } else {
            $missingTemplates += 'nas-populator-sources.template.psd1'
        }
    }
    if (Read-YesNoDefaultYes "Recreate console names file (nas-populator-console-names.json) from template?") {
        if (Test-Path -LiteralPath $consoleNamesTemplatePath) {
            Copy-Item -LiteralPath $consoleNamesTemplatePath -Destination $consoleNamesPath -Force
            Write-Info "Recreated: nas-populator-console-names.json"
        } else {
            $missingTemplates += 'nas-populator-console-names.template.json'
        }
    }
    if ($missingTemplates.Count -gt 0) {
        Write-Host ""
        Write-Host "One or more template files are missing. Please redownload the required files from the project repository: " -NoNewline -ForegroundColor Yellow
        Write-Host ($missingTemplates -join ', ') -ForegroundColor White
        Write-Host "Opening: https://github.com/cosmickatamari/nas-populator" -ForegroundColor Yellow
        try {
            Start-Process "https://github.com/cosmickatamari/nas-populator"
        } catch {
            Write-Host "Could not open browser. Visit the URL above to download the missing template(s)." -ForegroundColor Yellow
        }
        exit 1
    }
    Write-Host ""
    Write-Info "Config files recreated from templates. Run the script again to continue."
    exit 0
}

$cleanupOnly = (-not $doProcessing -and $doCleanup)

if ($settings.SevenZipExe) {
    $script:SevenZipExe = $settings.SevenZipExe
}

$destDrive = $null
$destinationPathDisplay = $DestinationRoot
try {
    $destInfo = Initialize-DestinationRoot -Path $DestinationRoot -User $settings.ShareUser -Password $settings.SharePassword
    $DestinationRoot = $destInfo.Path
    $destDrive = $destInfo.Drive
} catch {
    Write-Host "Failed to connect to destination: " -NoNewline -ForegroundColor Yellow
    Write-Host $DestinationRoot -NoNewline -ForegroundColor White
    Write-Host " ($($_.Exception.Message))" -ForegroundColor Yellow
    exit 1
}

$ConsoleSources = @($allConsoles)

if (-not $cleanupOnly) {
    if (-not $ConsoleSources -or $ConsoleSources.Count -eq 0) {
        Write-Host "No consoles were configured. Uncomment a console entry in " -NoNewline -ForegroundColor Yellow
        Write-Host "nas-populator-sources.psd1" -NoNewline -ForegroundColor White
        Write-Host "." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
    Write-Host "Sources loaded: " -NoNewline -ForegroundColor Yellow
    Write-Host $ConsoleSources.Count -ForegroundColor White
    foreach ($src in $ConsoleSources) {
        if ($src.Name) {
            Write-Info ("  - {0}" -f $src.Name)
        }
    }
    Write-Host ""
}

$archiveExts = if ($settings.ArchiveExtensions) { @($settings.ArchiveExtensions) } else { @('.zip', '.7z', '.rar') }
$zipCompressionArgs = if ($settings.ZipCompressionArgs) { @($settings.ZipCompressionArgs) } else { @('-tzip', '-mx=9', '-mm=Deflate64', '-mfb=258', '-mpass=15', '-md=256m') }
$zipCompressionArgs = ConvertTo-ZipCompressionArgs -Args $zipCompressionArgs
$script:totalBytes = 0L
$script:totalFiles = 0
$script:compressedFiles = 0
$script:compressedBytes = 0L
$script:consoleSummaries = New-Object System.Collections.Generic.List[object]
$script:regionTotals = @{}
$overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:organizeElapsed = [TimeSpan]::Zero
$script:didOrganizeExisting = $false

if ($doProcessing) {
    $organizeTotalElapsed = [TimeSpan]::Zero
    $organizeTargets = @()
    foreach ($src in $ConsoleSources) {
        if (-not $src.Name) { continue }
        $consoleKey = $src.Name.ToLowerInvariant()
        if (-not $consoleNameMap.ContainsKey($consoleKey)) { continue }
        $base = Join-Path $DestinationRoot $consoleNameMap[$consoleKey]
        if ($consoleSubDirMap.ContainsKey($consoleKey) -and $consoleSubDirMap[$consoleKey]) {
            $base = Join-Path $base $consoleSubDirMap[$consoleKey]
        }
        if (Test-Path -LiteralPath $base -PathType Container) {
            $organizeTargets += @(@{ Name = $src.Name; Path = $base })
        }
    }
    $organizeTotal = $organizeTargets.Count
    if ($organizeTotal -gt 0) { $script:didOrganizeExisting = $true }
    foreach ($target in $organizeTargets) {
        $consoleOrganizeTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $script:organizeLastTick = @{}
        Update-OrganizeProgress -ConsoleName $target.Name -Stopwatch $consoleOrganizeTimer
        if ($organizeRegions) {
            # BIN/CUE must always stay in per-game folders (Console/Region/GameName), never on region or console root.
            Move-RegionInFolder -FolderPath $target.Path -ProgressConsoleName $target.Name -ProgressStopwatch $consoleOrganizeTimer -AllowBinCue:$true
        } else {
            # When flattening (no region), BIN/CUE must always stay in per-game folders; never move them to console root.
            Convert-ConsoleFolder -FolderPath $target.Path -AllowBinCue:$true -ProgressConsoleName $target.Name -ProgressStopwatch $consoleOrganizeTimer
        }
        $targetKey = $target.Name.ToLowerInvariant()
        if (($targetKey -eq 'nintendo game boy' -or $targetKey -eq 'nintendo game boy color') -and $consoleNameMap.ContainsKey('nintendo super game boy & super game boy 2')) {
            $sgbDest = Get-ConsoleDestinationPathByKey -ConsoleKey 'nintendo super game boy & super game boy 2'
            if ($sgbDest) {
                Move-SgbTaggedFilesToDestination -SourceFolderPath $target.Path -DestFolderPath $sgbDest -Organize $organizeRegions -ProgressConsoleName $target.Name -ProgressStopwatch $consoleOrganizeTimer
            }
        }
        $consoleOrganizeTimer.Stop()
        $organizeTotalElapsed = $organizeTotalElapsed.Add($consoleOrganizeTimer.Elapsed)
        Write-OrganizeProgressLine -ConsoleName $target.Name -Elapsed $consoleOrganizeTimer.Elapsed
        Write-Host ""
    }
    $script:organizeElapsed = $organizeTotalElapsed
}

if ($doProcessing) {
foreach ($console in $ConsoleSources) {
    $name = $console.Name
    $sourceRoot = $console.SourcePath
    $user = $settings.ShareUser
    $pass = $settings.SharePassword

    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($sourceRoot)) {
        Write-Warn "Skipping console with missing Name or SourcePath."
        continue
    }

    $consoleKey = $name.ToLowerInvariant()
    $shortName = $consoleNameMap[$consoleKey]
    if (-not $shortName) {
        Write-Host "Console short name missing for '" -NoNewline -ForegroundColor Yellow
        Write-Host $name -NoNewline -ForegroundColor White
        Write-Host "' in " -NoNewline -ForegroundColor Yellow
        Write-Host "nas-populator-console-names.json" -ForegroundColor White
        $script:errors.Add("Console short name missing for '$name' in nas-populator-console-names.json") | Out-Null
        continue
    }
    $displayName = if ($consoleDisplayNameMap[$consoleKey]) { $consoleDisplayNameMap[$consoleKey] } else { $name }

    $drivePath = $null
    try {
        $drivePath = New-ShareDrive -Root $sourceRoot -User $user -Password $pass
    } catch {
        Add-Error "Failed to connect to share for ${name}: $sourceRoot ($($_.Exception.Message))"
        continue
    }

    try {
        $script:currentConsoleStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        # Connection verified by PSDrive
        $items = @(Get-ChildItem -LiteralPath $drivePath -Force -Recurse -ErrorAction Stop)
        $fileItems = @($items | Where-Object { -not $_.PSIsContainer })
        if (-not $items -or $items.Count -eq 0) {
            Write-Warn ("Source contains no items: {0}" -f $sourceRoot)
            Remove-ShareDrive -DrivePath $drivePath
            continue
        }

        if ($script:lastLineLength -gt 0) {
            Write-Host ""
            $script:lastLineLength = 0
        }
        Write-Host "Console: $displayName" -ForegroundColor DarkCyan

        $consoleDest = Join-Path $DestinationRoot $shortName
        $subDir = $consoleSubDirMap[$consoleKey]
        if ($subDir) {
            $consoleDest = Join-Path $consoleDest $subDir
        }
        $consoleMode = $Mode
        if ($consoleOpticalSet.Contains($displayName)) {
            $consoleMode = 'Raw'
            if ($Mode -eq 'Zip') {
                Write-Warn "Optical console '$displayName' does not support ZIP; using RAW."
            }
        }
        Invoke-ExistingDestination -FolderPath $consoleDest -Mode $consoleMode -Organize $organizeRegions -ArchiveExtensions $archiveExts
        $sgbConsoleKey = 'nintendo super game boy & super game boy 2'
        $sgbDest = $null
        $sgbAllowedExtSet = $null
        $sgbDestNameSet = $null
        if (($consoleKey -eq 'nintendo game boy' -or $consoleKey -eq 'nintendo game boy color') -and $consoleNameMap.ContainsKey($sgbConsoleKey)) {
            $sgbDest = Get-ConsoleDestinationPathByKey -ConsoleKey $sgbConsoleKey
            if ($sgbDest) {
                Move-SgbTaggedFilesToDestination -SourceFolderPath $consoleDest -DestFolderPath $sgbDest -Organize $organizeRegions
                $sgbAllowedExtSet = $consoleExtensionsMap[$sgbConsoleKey]
                if (-not $sgbAllowedExtSet) {
                    $sgbAllowedExtSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                    $sgbAllowedExtSet.Add('.rom') | Out-Null
                }
                $sgbDestNameSet = Get-DestinationFileNameSet -FolderPath $sgbDest
                $sgbDestNameSet = if ($sgbDestNameSet) { Convert-NameSet -NameSet $sgbDestNameSet } else { New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
            }
        }
        $destNameSet = Get-DestinationFileNameSet -FolderPath $consoleDest
        $destNameSet = if ($destNameSet) { Convert-NameSet -NameSet $destNameSet } else { New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
        $createdConsoleDir = $false
        $consoleFiles = 0
        $consoleBytes = 0L
        $processedDirs = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $consoleRegionCounts = @{}

        $allowedExtSet = $consoleExtensionsMap[$consoleKey]
        if (-not $allowedExtSet) { $allowedExtSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase); $allowedExtSet.Add('.rom') | Out-Null }

        if ($consoleOpticalSet.Contains($displayName)) {
            $chdFiles = @($fileItems | Where-Object { $_.Extension -ieq '.chd' })
            foreach ($chd in $chdFiles) {
                if (-not $allowedExtSet.Contains('.chd')) { continue }
                $chdRoot = Get-RegionDestRoot -BasePath $consoleDest -Name $chd.Name -Organize $organizeRegions
                $destFile = Join-Path $chdRoot $chd.Name
                if (Test-Path -LiteralPath $destFile) { continue }
                if (-not $createdConsoleDir) {
                    New-Item -Path $consoleDest -ItemType Directory -Force | Out-Null
                    $createdConsoleDir = $true
                }
                if (-not (Test-Path -LiteralPath $chdRoot)) {
                    New-Item -Path $chdRoot -ItemType Directory -Force | Out-Null
                }
                Write-ProgressLine -Action "Copying CHD" -ItemName $chd.Name -Bytes $chd.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                Copy-Item -LiteralPath $chd.FullName -Destination $destFile
                $script:totalBytes += $chd.Length
                $script:totalFiles += 1
                $consoleBytes += $chd.Length
                $consoleFiles += 1
                Add-NameToSet -Set ([ref]$destNameSet) -Name $chd.Name
                Add-RegionCount -Counts $consoleRegionCounts -Name $chd.Name -Organize $organizeRegions | Out-Null
                Add-RegionCount -Counts $script:regionTotals -Name $chd.Name -Organize $organizeRegions | Out-Null
            }

            $binCueFolders = Get-BinCueFoldersFromItems -Items $fileItems
            foreach ($dirPath in $binCueFolders) {
                $dir = Get-Item -LiteralPath $dirPath -ErrorAction SilentlyContinue
                if (-not $dir) { continue }
                $processedDirs.Add($dir.FullName) | Out-Null

                $binRoot = Get-RegionDestRoot -BasePath $consoleDest -Name $dir.Name -Organize $organizeRegions
                $destFolder = Join-Path $binRoot $dir.Name
                if ($consoleMode -eq 'Raw') {
                    if (-not $createdConsoleDir) {
                        New-Item -Path $consoleDest -ItemType Directory -Force | Out-Null
                        $createdConsoleDir = $true
                    }
                    $dirItems = @($fileItems | Where-Object {
                        $_.FullName.StartsWith($dir.FullName, [System.StringComparison]::OrdinalIgnoreCase)
                    })
                    if ($dirItems.Count -eq 0) { continue }
                    Write-ProgressLine -Action "Copying folder" -ItemName $dir.Name -Bytes 0 -Elapsed $script:currentConsoleStopwatch.Elapsed
                    $copyResult = Copy-ItemsNoOverwrite -Items $dirItems -SourceRoot $dir.FullName -DestRoot $destFolder
                    $script:totalBytes += $copyResult.Bytes
                    $script:totalFiles += $copyResult.Files
                    $consoleBytes += $copyResult.Bytes
                    $consoleFiles += $copyResult.Files
                    foreach ($file in $dirItems | Where-Object { -not $_.PSIsContainer }) {
                        Add-RegionCount -Counts $consoleRegionCounts -Name $file.Name -Organize $organizeRegions | Out-Null
                        Add-RegionCount -Counts $script:regionTotals -Name $file.Name -Organize $organizeRegions | Out-Null
                    }
                } else {
                    $destGameFolder = Join-Path $binRoot $dir.Name
                    if (Test-Path -LiteralPath $destGameFolder) { continue }
                    if (-not (Test-Path -LiteralPath $binRoot)) {
                        New-Item -Path $binRoot -ItemType Directory -Force | Out-Null
                    }
                    if (-not $createdConsoleDir) {
                        New-Item -Path $consoleDest -ItemType Directory -Force | Out-Null
                        $createdConsoleDir = $true
                    }
                    $dirItems = @(Get-ChildItem -LiteralPath $dir.FullName -Force -Recurse -ErrorAction SilentlyContinue)
                    if (-not $dirItems -or $dirItems.Count -eq 0) { continue }
                    Write-ProgressLine -Action "Copying folder" -ItemName $dir.Name -Bytes 0 -Elapsed $script:currentConsoleStopwatch.Elapsed
                    $copyResult = Copy-ItemsNoOverwrite -Items $dirItems -SourceRoot $dir.FullName -DestRoot $destGameFolder
                    $script:totalBytes += $copyResult.Bytes
                    $script:totalFiles += $copyResult.Files
                    $consoleBytes += $copyResult.Bytes
                    $consoleFiles += $copyResult.Files
                    $dirItemsForRegion = @($dirItems | Where-Object { -not $_.PSIsContainer })
                    $region = Get-RegionFromFiles -Files $dirItemsForRegion
                    Add-RegionCountWithRegion -Counts $consoleRegionCounts -Region $region -Organize $organizeRegions
                    Add-RegionCountWithRegion -Counts $script:regionTotals -Region $region -Organize $organizeRegions
                }
            }
        }

        $archiveLookup = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $archiveItems = @()
        $otherItems = @()
        foreach ($item in $fileItems) {
            if ($processedDirs.Contains($item.DirectoryName)) { continue }
            $ext = $item.Extension.ToLowerInvariant()
            if (-not $ext.StartsWith('.')) { $ext = '.' + $ext }
            $isArchive = $archiveExts -contains $ext
            if (-not $isArchive -and $consoleMode -eq 'Raw') {
                try {
                    $isArchive = Test-ArchiveFile -Path $item.FullName
                } catch {
                    $isArchive = $false
                }
            }
            if ($isArchive) {
                $archiveLookup.Add($item.FullName) | Out-Null
                $archiveItems += $item
            } elseif ($allowedExtSet.Contains($ext)) {
                $otherItems += $item
            }
        }
        $zipArchives = @($archiveItems | Where-Object { $_.Extension -ieq '.zip' })
        $otherArchives = @($archiveItems | Where-Object { $_.Extension -ine '.zip' })
        $orderedItems = @($zipArchives + $otherArchives + $otherItems)

        foreach ($item in $orderedItems) {
            try {
            $ext = $item.Extension.ToLowerInvariant()
            if (-not $ext.StartsWith('.')) { $ext = '.' + $ext }
            $itemConsoleDest = $consoleDest
            $itemAllowedExtSet = $allowedExtSet
            $itemDestNameSet = $destNameSet
            if ($sgbDest -and (Test-SgbRedirectForConsoleItem -ConsoleKey $consoleKey -ItemName $item.Name)) {
                $itemConsoleDest = $sgbDest
                $itemAllowedExtSet = $sgbAllowedExtSet
                $itemDestNameSet = $sgbDestNameSet
            }
            if ($ext -eq '.chd') {
                if (-not $itemAllowedExtSet.Contains('.chd')) { continue }
                $chdRoot = Get-RegionDestRoot -BasePath $itemConsoleDest -Name $item.Name -Organize $organizeRegions
                $destFile = Join-Path $chdRoot $item.Name
                if ($itemDestNameSet -and $itemDestNameSet.Contains($item.Name)) { continue }
                if (Test-Path -LiteralPath $destFile) { continue }

                if (-not (Test-Path -LiteralPath $itemConsoleDest -PathType Container)) {
                    New-Item -Path $itemConsoleDest -ItemType Directory -Force | Out-Null
                }
                if (-not (Test-Path -LiteralPath $chdRoot)) {
                    New-Item -Path $chdRoot -ItemType Directory -Force | Out-Null
                }

                Write-ProgressLine -Action "Copying CHD" -ItemName $item.Name -Bytes $item.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                Copy-Item -LiteralPath $item.FullName -Destination $destFile
                Add-NameToSet -Set ([ref]$itemDestNameSet) -Name $item.Name
                $script:totalBytes += $item.Length
                $script:totalFiles += 1
                $consoleBytes += $item.Length
                $consoleFiles += 1
                Add-RegionCount -Counts $consoleRegionCounts -Name $item.Name -Organize $organizeRegions | Out-Null
                Add-RegionCount -Counts $script:regionTotals -Name $item.Name -Organize $organizeRegions | Out-Null
                continue
            }

            $isArchive = $archiveLookup.Contains($item.FullName)

            if ($isArchive) {
                if ($consoleMode -eq 'Zip' -and $ext -eq '.zip') {
                    if (-not $itemAllowedExtSet.Contains('.zip')) { continue }
                    if ($itemDestNameSet -and $itemDestNameSet.Contains($item.Name)) { continue }
                    if (-not (Test-Path -LiteralPath $itemConsoleDest -PathType Container)) {
                        New-Item -Path $itemConsoleDest -ItemType Directory -Force | Out-Null
                    }

                    $archiveRoot = Get-RegionDestRoot -BasePath $itemConsoleDest -Name $item.Name -Organize $organizeRegions
                    if (-not (Test-Path -LiteralPath $archiveRoot)) {
                        New-Item -Path $archiveRoot -ItemType Directory -Force | Out-Null
                    }
                    $destFile = Join-Path $archiveRoot $item.Name
                    if (Test-Path -LiteralPath $destFile) { continue }

                    Write-ProgressLine -Action "Copying archive" -ItemName $item.Name -Bytes $item.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                    Copy-Item -LiteralPath $item.FullName -Destination $destFile
                    Add-NameToSet -Set ([ref]$itemDestNameSet) -Name $item.Name
                    $script:totalBytes += $item.Length
                    $script:totalFiles += 1
                    $consoleBytes += $item.Length
                    $consoleFiles += 1
                    Add-RegionCount -Counts $consoleRegionCounts -Name $item.Name -Organize $organizeRegions | Out-Null
                    Add-RegionCount -Counts $script:regionTotals -Name $item.Name -Organize $organizeRegions | Out-Null
                    continue
                }
                Initialize-7z
                $tempExtract = Join-Path $TempRoot ([Guid]::NewGuid().ToString('N'))
                New-Item -Path $tempExtract -ItemType Directory -Force | Out-Null
                try {
                    Invoke-7z -Arguments @('x', '-y', '-bso1', '-bse1', '-bsp1', "-o$tempExtract", $item.FullName) -ProgressLabel "Extracting" -ProgressName $item.Name
                    $extractedItems = @(Get-ChildItem -LiteralPath $tempExtract -Force -ErrorAction SilentlyContinue)
                    if (-not $extractedItems -or $extractedItems.Count -eq 0) {
                        Write-Host "Archive contained no files: " -NoNewline -ForegroundColor Yellow
                        Write-Host $item.Name -ForegroundColor White
                        continue
                    }
                    if ($consoleMode -eq 'Raw') {
                        if (-not (Test-Path -LiteralPath $itemConsoleDest -PathType Container)) {
                            New-Item -Path $itemConsoleDest -ItemType Directory -Force | Out-Null
                        }

                        $allExtractedFiles = @(Get-ChildItem -LiteralPath $tempExtract -Recurse -File -ErrorAction SilentlyContinue)
                        $hasBin = @($allExtractedFiles | Where-Object { $_.Extension -ieq '.bin' }).Count -gt 0
                        $hasCue = @($allExtractedFiles | Where-Object { $_.Extension -ieq '.cue' }).Count -gt 0
                        $isBinCueArchive = ($hasBin -and $hasCue)

                        if ($isBinCueArchive) {
                            $gameFolderName = $item.BaseName
                            $region = Get-RegionFromFiles -Files $allExtractedFiles
                            $archiveRoot = Get-RegionDestRootFromRegion -BasePath $itemConsoleDest -Region $region -Organize $organizeRegions
                            if (-not (Test-Path -LiteralPath $archiveRoot)) {
                                New-Item -Path $archiveRoot -ItemType Directory -Force | Out-Null
                            }
                            $destGameFolder = Join-Path $archiveRoot $gameFolderName
                            $nameSet = if ($itemDestNameSet) { $itemDestNameSet } else { (New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)) }
                            if (-not $nameSet) { $nameSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                            $filteredItems = @()
                            foreach ($extracted in $allExtractedFiles) {
                                $extractedName = $extracted.Name
                                if (-not $extractedName) { continue }
                                if ($nameSet -and $nameSet.Contains($extractedName)) { continue }
                                $filteredItems += $extracted
                            }
                            if (-not $filteredItems -or $filteredItems.Count -eq 0) { continue }
                            $extractedSize = Get-DirectorySize -Path $tempExtract
                            Write-ProgressLine -Action "Copying extracted" -ItemName $gameFolderName -Bytes $extractedSize -Elapsed $script:currentConsoleStopwatch.Elapsed
                            if (-not (Test-Path -LiteralPath $destGameFolder)) {
                                New-Item -Path $destGameFolder -ItemType Directory -Force | Out-Null
                            }
                            $copyResult = Copy-ItemsFlatNoOverwrite -Items $filteredItems -DestRoot $destGameFolder
                            $script:totalBytes += $copyResult.Bytes
                            $script:totalFiles += $copyResult.Files
                            $consoleBytes += $copyResult.Bytes
                            $consoleFiles += $copyResult.Files
                            $itemDestNameSet = if ($itemDestNameSet) { Convert-NameSet -NameSet $itemDestNameSet } else { New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                            foreach ($file in $filteredItems) {
                                Add-NameToSet -Set ([ref]$itemDestNameSet) -Name $file.Name
                                Add-RegionCount -Counts $consoleRegionCounts -Name $file.Name -Organize $organizeRegions | Out-Null
                                Add-RegionCount -Counts $script:regionTotals -Name $file.Name -Organize $organizeRegions | Out-Null
                            }
                        } else {
                            $extractedSize = Get-DirectorySize -Path $tempExtract
                            Write-ProgressLine -Action "Copying extracted" -ItemName $item.BaseName -Bytes $extractedSize -Elapsed $script:currentConsoleStopwatch.Elapsed
                            $region = Get-RegionFromFiles -Files $extractedItems
                            $archiveRoot = Get-RegionDestRootFromRegion -BasePath $itemConsoleDest -Region $region -Organize $organizeRegions
                            if (-not (Test-Path -LiteralPath $archiveRoot)) {
                                New-Item -Path $archiveRoot -ItemType Directory -Force | Out-Null
                            }
                            $nameSet = if ($itemDestNameSet) { $itemDestNameSet } else { (New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)) }
                            if (-not $nameSet) { $nameSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                            $filteredItems = @()
                            foreach ($extracted in $extractedItems) {
                                if (-not $extracted -or $extracted.PSIsContainer) { continue }
                                $extractedName = $extracted.Name
                                if (-not $extractedName) { continue }
                                if ($nameSet -and $nameSet.Contains($extractedName)) { continue }
                                $filteredItems += $extracted
                            }
                            if (-not $filteredItems -or $filteredItems.Count -eq 0) { continue }
                            $copyResult = Copy-ItemsFlatNoOverwrite -Items $filteredItems -DestRoot $archiveRoot
                            $script:totalBytes += $copyResult.Bytes
                            $script:totalFiles += $copyResult.Files
                            $consoleBytes += $copyResult.Bytes
                            $consoleFiles += $copyResult.Files
                            $itemDestNameSet = if ($itemDestNameSet) { Convert-NameSet -NameSet $itemDestNameSet } else { New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                            foreach ($file in $filteredItems) {
                                Add-NameToSet -Set ([ref]$itemDestNameSet) -Name $file.Name
                                Add-RegionCount -Counts $consoleRegionCounts -Name $file.Name -Organize $organizeRegions | Out-Null
                                Add-RegionCount -Counts $script:regionTotals -Name $file.Name -Organize $organizeRegions | Out-Null
                            }
                        }
                    } else {
                        $allExtractedFilesZip = @(Get-ChildItem -LiteralPath $tempExtract -Recurse -File -ErrorAction SilentlyContinue)
                        $hasBinZip = @($allExtractedFilesZip | Where-Object { $_.Extension -ieq '.bin' }).Count -gt 0
                        $hasCueZip = @($allExtractedFilesZip | Where-Object { $_.Extension -ieq '.cue' }).Count -gt 0
                        $isBinCueArchiveZip = ($hasBinZip -and $hasCueZip)

                        if ($isBinCueArchiveZip) {
                            $gameFolderNameZip = $item.BaseName
                            $region = Get-RegionFromFiles -Files $allExtractedFilesZip
                            $archiveRootZip = Get-RegionDestRootFromRegion -BasePath $itemConsoleDest -Region $region -Organize $organizeRegions
                            if (-not (Test-Path -LiteralPath $archiveRootZip)) {
                                New-Item -Path $archiveRootZip -ItemType Directory -Force | Out-Null
                            }
                            $destGameFolderZip = Join-Path $archiveRootZip $gameFolderNameZip
                            if (Test-Path -LiteralPath $destGameFolderZip) { continue }
                            if (-not (Test-Path -LiteralPath $itemConsoleDest -PathType Container)) {
                                New-Item -Path $itemConsoleDest -ItemType Directory -Force | Out-Null
                            }
                            $nameSetZip = if ($itemDestNameSet) { $itemDestNameSet } else { (New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)) }
                            if (-not $nameSetZip) { $nameSetZip = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                            $filteredItemsZip = @()
                            foreach ($extracted in $allExtractedFilesZip) {
                                $extractedName = $extracted.Name
                                if (-not $extractedName) { continue }
                                if ($nameSetZip -and $nameSetZip.Contains($extractedName)) { continue }
                                $filteredItemsZip += $extracted
                            }
                            if (-not $filteredItemsZip -or $filteredItemsZip.Count -eq 0) { continue }
                            $extractedSizeZip = Get-DirectorySize -Path $tempExtract
                            Write-ProgressLine -Action "Copying extracted" -ItemName $gameFolderNameZip -Bytes $extractedSizeZip -Elapsed $script:currentConsoleStopwatch.Elapsed
                            New-Item -Path $destGameFolderZip -ItemType Directory -Force | Out-Null
                            $copyResultZip = Copy-ItemsFlatNoOverwrite -Items $filteredItemsZip -DestRoot $destGameFolderZip
                            $script:totalBytes += $copyResultZip.Bytes
                            $script:totalFiles += $copyResultZip.Files
                            $consoleBytes += $copyResultZip.Bytes
                            $consoleFiles += $copyResultZip.Files
                            $itemDestNameSet = if ($itemDestNameSet) { Convert-NameSet -NameSet $itemDestNameSet } else { New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                            foreach ($file in $filteredItemsZip) {
                                Add-NameToSet -Set ([ref]$itemDestNameSet) -Name $file.Name
                                Add-RegionCount -Counts $consoleRegionCounts -Name $file.Name -Organize $organizeRegions | Out-Null
                                Add-RegionCount -Counts $script:regionTotals -Name $file.Name -Organize $organizeRegions | Out-Null
                            }
                        } else {
                            $region = Get-RegionFromFiles -Files $extractedItems
                            $zipRoot = Get-RegionDestRootFromRegion -BasePath $itemConsoleDest -Region $region -Organize $organizeRegions
                            if (-not (Test-Path -LiteralPath $zipRoot)) {
                                New-Item -Path $zipRoot -ItemType Directory -Force | Out-Null
                            }
                            $destFile = Join-Path $zipRoot ($item.BaseName + '.zip')
                            if ($itemDestNameSet -and $itemDestNameSet.Contains([System.IO.Path]::GetFileName($destFile))) { continue }
                            if (Test-Path -LiteralPath $destFile) { continue }

                            if (-not (Test-Path -LiteralPath $itemConsoleDest -PathType Container)) {
                                New-Item -Path $itemConsoleDest -ItemType Directory -Force | Out-Null
                            }

                            $tempZip = Join-Path $TempRoot ([Guid]::NewGuid().ToString('N') + '.zip')
                            try {
                                Write-ProgressLine -Action "Zipping" -ItemName ($item.BaseName + '.zip') -Bytes $item.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                                Invoke-7z -Arguments (@('a') + $zipCompressionArgs + @(
                                    '-mmt=on'
                                    '-bso1'
                                    '-bse1'
                                    '-bsp1'
                                    $tempZip
                                    (Join-Path $tempExtract '*')
                                )) -ProgressLabel "Compressing" -ProgressName ($item.BaseName + '.zip')
                                Copy-Item -LiteralPath $tempZip -Destination $destFile
                                if (Test-Path -LiteralPath $destFile) {
                                    Add-NameToSet -Set ([ref]$itemDestNameSet) -Name ([System.IO.Path]::GetFileName($destFile))
                                    $newSize = (Get-Item -LiteralPath $destFile).Length
                                    $script:totalBytes += $newSize
                                    $script:totalFiles += 1
                                    $consoleBytes += $newSize
                                    $consoleFiles += 1
                                    $script:compressedFiles += 1
                                    $script:compressedBytes += $newSize
                                    Add-RegionCountWithRegion -Counts $consoleRegionCounts -Region $region -Organize $organizeRegions
                                    Add-RegionCountWithRegion -Counts $script:regionTotals -Region $region -Organize $organizeRegions
                                }
                            } finally {
                                if (Test-Path -LiteralPath $tempZip) {
                                    Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
                                }
                            }
                        }
                    }
                } finally {
                    if (Test-Path -LiteralPath $tempExtract) {
                        Remove-Item -LiteralPath $tempExtract -Recurse -Force
                    }
                }
                continue
            }

            if ($consoleMode -eq 'Zip') {
                if ($ext -eq '.chd') {
                    if (-not $itemAllowedExtSet.Contains('.chd')) { continue }
                    $chdRootZip = Get-RegionDestRoot -BasePath $itemConsoleDest -Name $item.Name -Organize $organizeRegions
                    $destFileChd = Join-Path $chdRootZip $item.Name
                    if ($itemDestNameSet -and $itemDestNameSet.Contains($item.Name)) { continue }
                    if (Test-Path -LiteralPath $destFileChd) { continue }
                    if (-not (Test-Path -LiteralPath $itemConsoleDest -PathType Container)) {
                        New-Item -Path $itemConsoleDest -ItemType Directory -Force | Out-Null
                    }
                    if (-not (Test-Path -LiteralPath $chdRootZip)) {
                        New-Item -Path $chdRootZip -ItemType Directory -Force | Out-Null
                    }
                    Write-ProgressLine -Action "Copying CHD" -ItemName $item.Name -Bytes $item.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                    Copy-Item -LiteralPath $item.FullName -Destination $destFileChd
                    Add-NameToSet -Set ([ref]$itemDestNameSet) -Name $item.Name
                    $script:totalBytes += $item.Length
                    $script:totalFiles += 1
                    $consoleBytes += $item.Length
                    $consoleFiles += 1
                    Add-RegionCount -Counts $consoleRegionCounts -Name $item.Name -Organize $organizeRegions | Out-Null
                    Add-RegionCount -Counts $script:regionTotals -Name $item.Name -Organize $organizeRegions | Out-Null
                    continue
                }
                Initialize-7z
                $region = Get-RegionFolderName -Name $item.Name
                $zipRoot = Get-RegionDestRootFromRegion -BasePath $itemConsoleDest -Region $region -Organize $organizeRegions
                if (-not (Test-Path -LiteralPath $zipRoot)) {
                    New-Item -Path $zipRoot -ItemType Directory -Force | Out-Null
                }
                $destFile = Join-Path $zipRoot ($item.BaseName + '.zip')
                if ($itemDestNameSet -and $itemDestNameSet.Contains([System.IO.Path]::GetFileName($destFile))) { continue }
                if (Test-Path -LiteralPath $destFile) { continue }

                if (-not (Test-Path -LiteralPath $itemConsoleDest -PathType Container)) {
                    New-Item -Path $itemConsoleDest -ItemType Directory -Force | Out-Null
                }

                $tempZip = Join-Path $TempRoot ([Guid]::NewGuid().ToString('N') + '.zip')
                try {
                    Write-ProgressLine -Action "Zipping" -ItemName ($item.BaseName + '.zip') -Bytes $item.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                    Invoke-7z -Arguments (@('a') + $zipCompressionArgs + @(
                        '-mmt=on'
                        '-bso1'
                        '-bse1'
                        '-bsp1'
                        $tempZip
                        $item.FullName
                    )) -ProgressLabel "Compressing" -ProgressName ($item.BaseName + '.zip')
                    Copy-Item -LiteralPath $tempZip -Destination $destFile
                if (Test-Path -LiteralPath $destFile) {
                    Add-NameToSet -Set ([ref]$itemDestNameSet) -Name ([System.IO.Path]::GetFileName($destFile))
                        $newSize = (Get-Item -LiteralPath $destFile).Length
                        $script:totalBytes += $newSize
                        $script:totalFiles += 1
                        $consoleBytes += $newSize
                        $consoleFiles += 1
                        $script:compressedFiles += 1
                        $script:compressedBytes += $newSize
                        Add-RegionCountWithRegion -Counts $consoleRegionCounts -Region $region -Organize $organizeRegions
                        Add-RegionCountWithRegion -Counts $script:regionTotals -Region $region -Organize $organizeRegions
                    }
                } finally {
                    if (Test-Path -LiteralPath $tempZip) {
                        Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
                    }
                }
            } else {
                if (-not (Test-Path -LiteralPath $itemConsoleDest -PathType Container)) {
                    New-Item -Path $itemConsoleDest -ItemType Directory -Force | Out-Null
                }
                $flatRoot = Get-RegionDestRoot -BasePath $itemConsoleDest -Name $item.Name -Organize $organizeRegions
                if (-not (Test-Path -LiteralPath $flatRoot)) {
                    New-Item -Path $flatRoot -ItemType Directory -Force | Out-Null
                }
                if ($itemDestNameSet -and $itemDestNameSet.Contains($item.Name)) { continue }
                $copyResult = Copy-ItemsFlatNoOverwrite -Items @($item) -DestRoot $flatRoot
                if ($copyResult.Files -gt 0) {
                    Write-ProgressLine -Action "Copying" -ItemName $item.Name -Bytes $item.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                    $script:totalBytes += $copyResult.Bytes
                    $script:totalFiles += $copyResult.Files
                    $consoleBytes += $copyResult.Bytes
                    $consoleFiles += $copyResult.Files
                    Add-NameToSet -Set ([ref]$itemDestNameSet) -Name $item.Name
                    Add-RegionCount -Counts $consoleRegionCounts -Name $item.Name -Organize $organizeRegions | Out-Null
                    Add-RegionCount -Counts $script:regionTotals -Name $item.Name -Organize $organizeRegions | Out-Null
                }
            }
            } catch {
                $lineInfo = $_.InvocationInfo.ScriptLineNumber
                $msg = Get-CopyErrorMessage -ExceptionMessage $_.Exception.Message
                Add-Error ("{0}: {1} (line {2})" -f $item.Name, $msg, $lineInfo)
            }
        }

        if ($sgbDest) {
            Move-SgbTaggedFilesToDestination -SourceFolderPath $consoleDest -DestFolderPath $sgbDest -Organize $organizeRegions
        }

        if ($script:lastLineLength -gt 0) {
            Write-Host ""
            $script:lastLineLength = 0
        }
        if ($script:currentConsoleStopwatch) {
            $script:currentConsoleStopwatch.Stop()
            $script:consoleSummaries.Add(@{
                Name = $displayName
                Elapsed = $script:currentConsoleStopwatch.Elapsed
                Files = $consoleFiles
                Bytes = $consoleBytes
                Regions = $consoleRegionCounts
            }) | Out-Null
            $script:currentConsoleStopwatch = $null
        }
        Write-Host ""
    } catch {
        Add-Error ("Failed to read source {0}: {1}" -f $sourceRoot, $_.Exception.Message)
    } finally {
        if ($script:currentConsoleStopwatch) {
            $script:currentConsoleStopwatch.Stop()
            $script:currentConsoleStopwatch = $null
        }
        if ($drivePath) {
            Remove-ShareDrive -DrivePath $drivePath
        }
    }
}
}

$destCleanup = $destDrive
$overallStopwatch.Stop()
# Destination check: remove any files not in the console's allowed extensions list (.rom and .zip always allowed).
if ($doCleanup) {
    foreach ($entry in $consoleNames) {
        if (-not $entry.ShortName) { continue }
        $consoleDestPath = Join-Path $DestinationRoot $entry.ShortName
        if ($entry.PSObject.Properties['SubDir'] -and $entry.SubDir) {
            $consoleDestPath = Join-Path $consoleDestPath $entry.SubDir
        }
        if (-not (Test-Path -LiteralPath $consoleDestPath -PathType Container)) { continue }
        $extList = @()
        if ($entry.PSObject.Properties['Extensions'] -and $null -ne $entry.Extensions) {
            $extList = @($entry.Extensions)
        }
        if ($extList.Count -eq 0) {
            Write-Warn "Console '$($entry.ShortName)' has no Extensions in nas-populator-console-names.json; skipping cleanup for that folder (no files removed)."
            continue
        }
        Remove-DestinationFilesNotMatchingExtensions -FolderPath $consoleDestPath -AllowedExtensions $extList
    }
    Remove-EmptyFolders -RootPath $DestinationRoot
}
Write-Summary "`n`n===[ Completion Summary ]==="
Write-Host "     Destination path:    " -NoNewline -ForegroundColor DarkCyan
Write-Host $destinationPathDisplay -ForegroundColor White
Write-Host "     Total time:          " -NoNewline -ForegroundColor DarkCyan
Write-Host (Format-Elapsed $overallStopwatch.Elapsed) -ForegroundColor White
if (-not $cleanupOnly) {
    if ($script:didOrganizeExisting) {
        Write-Host "     Organize time:       " -NoNewline -ForegroundColor DarkCyan
        Write-Host (Format-Elapsed $script:organizeElapsed) -ForegroundColor White
    }
    Write-Host "     Files copied:        " -NoNewline -ForegroundColor DarkCyan
    Write-Host ($script:totalFiles.ToString('N0')) -ForegroundColor White
    Write-Host "     Total size copied:   " -NoNewline -ForegroundColor DarkCyan
    Write-Host (Format-Size $script:totalBytes) -ForegroundColor White
    if ($script:compressedFiles -gt 0) {
        Write-Host "     Compressed created:  " -NoNewline -ForegroundColor DarkCyan
        Write-Host ($script:compressedFiles.ToString('N0')) -ForegroundColor White
        Write-Host "     Compressed size:     " -NoNewline -ForegroundColor DarkCyan
        Write-Host (Format-Size $script:compressedBytes) -ForegroundColor White
    }
    if ($script:errors.Count -gt 0) {
        $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $logFileName = "errorlog-$timestamp.log"
        $logPath = Join-Path (Get-Location) $logFileName
        $logStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $header = "[$logStamp] $($script:errors.Count) error(s) occurred."
        $content = @($header) + $script:errors
        try {
            $content | Set-Content -Path $logPath -Encoding UTF8
            Write-Host "     Errors:              " -NoNewline -ForegroundColor Red
            Write-Host ($script:errors.Count.ToString('N0')) -NoNewline -ForegroundColor Red
            Write-Host (" (see {0})" -f $logFileName) -ForegroundColor Red
        } catch {
            Write-Host "Failed to write error log: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($logPath)) -ForegroundColor White
            Write-Host "     Errors:              " -NoNewline -ForegroundColor Red
            Write-Host ($script:errors.Count.ToString('N0')) -NoNewline -ForegroundColor Red
            Write-Host " (log write failed)" -ForegroundColor Red
        }
    }
}
Write-Host ""

if ($script:consoleSummaries.Count -gt 0) {
    Write-Host "===[ Console Summary ]===" -ForegroundColor DarkCyan
    foreach ($summary in $script:consoleSummaries) {
        Write-Host ("{0} " -f $summary.Name) -NoNewline -ForegroundColor White
        Write-Host ("completed in {0} copying " -f (Format-Elapsed $summary.Elapsed)) -NoNewline -ForegroundColor White
        Write-Host ($summary.Files.ToString('N0')) -NoNewline -ForegroundColor DarkCyan
        Write-Host " files using " -NoNewline -ForegroundColor White
        Write-Host (Format-Size $summary.Bytes) -NoNewline -ForegroundColor DarkCyan
        Write-Host "." -ForegroundColor White
    }
    Write-Host ""
}

if ($organizeRegions) {
    $regionTotalsFromDest = @{}
    $regionSummaryShown = $false
    foreach ($entry in $consoleNames) {
        if (-not $entry.ShortName) { continue }
        $consoleDestPath = Join-Path $DestinationRoot $entry.ShortName
        if ($entry.PSObject.Properties['SubDir'] -and $entry.SubDir) {
            $consoleDestPath = Join-Path $consoleDestPath $entry.SubDir
        }
        $regionCounts = Get-RegionCountsFromDestination -FolderPath $consoleDestPath
        if (-not $regionCounts -or $regionCounts.Count -eq 0) { continue }
        if (-not $regionSummaryShown) {
            Write-Host "===[ Region Summary ]===" -ForegroundColor DarkCyan
            $regionSummaryShown = $true
        }
        $displayName = if ($entry.Name) { $entry.Name } else { $entry.ShortName }
        Write-Host $displayName -ForegroundColor White
        foreach ($key in (Get-OrderedRegionKeys -Keys $regionCounts.Keys)) {
            $regionLabel = ($key -replace '^\d+\s*-\s*', '')
            Write-Host ("    {0} - {1}" -f $regionLabel, $regionCounts[$key].ToString('N0')) -ForegroundColor White
            if (-not $regionTotalsFromDest.ContainsKey($key)) { $regionTotalsFromDest[$key] = 0 }
            $regionTotalsFromDest[$key] += $regionCounts[$key]
        }
        Write-Host ""
    }

    if ($regionTotalsFromDest.Count -gt 0) {
        Write-Host "===[ Region Totals ]===" -ForegroundColor DarkCyan
        foreach ($key in (Get-OrderedRegionKeys -Keys $regionTotalsFromDest.Keys)) {
            $regionLabel = ($key -replace '^\d+\s*-\s*', '')
            Write-Host ("    {0} - {1}" -f $regionLabel, $regionTotalsFromDest[$key].ToString('N0')) -ForegroundColor White
        }
    }
}
Write-Host ""

if ($destCleanup) {
    Remove-PSDrive -Name $destCleanup -ErrorAction SilentlyContinue
}
