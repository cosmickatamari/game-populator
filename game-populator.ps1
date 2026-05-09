<#
Game Populator
https://github.com/cosmickatamari/game-populator

Created by: cosmickatamari
Updated: 05/04/2026
#>

param(
    [switch]$Help,
    [switch]$Diag
)

$script:GamePopulatorCliDiag = [bool]$Diag
$scriptRoot = $PSScriptRoot
$librariesRoot = Join-Path $scriptRoot 'libraries'
$script:GamePopulatorLibrariesRoot = $librariesRoot

$libraryConfigLeaves = @(
    'helpers.ps1',
    'game-populator-functions.ps1',
    'settings.json',
    'settings.template.json',
    'console-sources.psd1',
    'console-sources.template.psd1',
    'hacks-sources.psd1',
    'hacks-sources.template.psd1',
    'trans-sources.psd1',
    'trans-sources.template.psd1',
    'addons-sources.psd1',
    'addons-sources.template.psd1',
    'console-names.json',
    'console-names.template.json',
    'hacks-names.json',
    'hacks-names.template.json',
    'trans-names.json',
    'trans-names.template.json',
    'addons-names.json',
    'addons-names.template.json',
    'sources.psd1',
    'sources.template.psd1'
)
try {
    if (-not (Test-Path -LiteralPath $librariesRoot -PathType Container)) {
        New-Item -Path $librariesRoot -ItemType Directory -Force | Out-Null
    }
    foreach ($leaf in $libraryConfigLeaves) {
        $src = Join-Path $scriptRoot $leaf
        $dst = Join-Path $librariesRoot $leaf
        if ((Test-Path -LiteralPath $src -PathType Leaf) -and -not (Test-Path -LiteralPath $dst)) {
            Move-Item -LiteralPath $src -Destination $dst -Force -ErrorAction SilentlyContinue
        }
    }
}
catch {
}

$gameEntry = Join-Path $scriptRoot 'game-populator.ps1'
$script:EntryScriptPath = if (Test-Path -LiteralPath $gameEntry -PathType Leaf) {
    $gameEntry
}
else {
    $PSCommandPath
}

Set-StrictMode -Version Latest
$script:ScriptDiag = $false
$script:GamePopulatorLeavesUnderLibraries = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($leaf in @($libraryConfigLeaves)) {
    [void]$script:GamePopulatorLeavesUnderLibraries.Add($leaf)
}
$helpersPath = Join-Path $librariesRoot 'helpers.ps1'
if (-not (Test-Path -LiteralPath $helpersPath -PathType Leaf)) {
    Write-Host "Required file not found: " -NoNewline -ForegroundColor Red
    Write-Host ('libraries\{0}' -f 'helpers.ps1') -ForegroundColor White
    exit 1
}
. $helpersPath

$script:ScriptDiag = [bool]$Diag
function Write-ScriptDiag {
    param([Parameter(Mandatory = $true)][string]$Message)
    if (-not $script:ScriptDiag) { return }
    Write-Host "[diag] $Message" -ForegroundColor Magenta
    try { [Console]::Out.Flush() } catch { }
}

function Set-GamePopulatorConsoleWindowSize {
    param(
        [int]$TargetWidth = 175
    )
    try {
        $raw = $Host.UI.RawUI
        if ($null -eq $raw) { return }

        $maxWidth = $raw.MaxPhysicalWindowSize.Width
        $maxHeight = $raw.MaxPhysicalWindowSize.Height
        if ($maxWidth -lt 1 -or $maxHeight -lt 1) { return }

        $width = [Math]::Min($TargetWidth, $maxWidth)
        if ($width -lt 1) { return }

        $buffer = $raw.BufferSize
        if ($buffer.Width -lt $width -or $buffer.Height -lt $maxHeight) {
            $raw.BufferSize = New-Object System.Management.Automation.Host.Size(
                [Math]::Max($buffer.Width, $width),
                [Math]::Max($buffer.Height, $maxHeight)
            )
        }

        $raw.WindowSize = New-Object System.Management.Automation.Host.Size($width, $maxHeight)
    }
    catch {
    }
}

if ($PSVersionTable.PSVersion.Major -ne 7) {
    Write-Fail "PowerShell 7.x is required."
}

Set-GamePopulatorConsoleWindowSize -TargetWidth 175
try {
    Clear-Host
}
catch {
    Write-Host ""
}
Write-Host "=== [ $script:ScriptName ]===" -ForegroundColor DarkGreen
Write-Host "=== [ Version $script:ScriptVersion ] ===" -ForegroundColor DarkGreen
Write-Host ""
Write-ScriptDiag "Script: $PSCommandPath"
Write-ScriptDiag "After banner"

if ($Help) {
    Show-Help
}

$settingsPath = Join-Path $librariesRoot 'settings.json'
$consolePath = Join-Path $librariesRoot 'console-sources.psd1'
$hacksSourcesPath = Join-Path $librariesRoot 'hacks-sources.psd1'
$transSourcesPath = Join-Path $librariesRoot 'trans-sources.psd1'
$addonsSourcesPath = Join-Path $librariesRoot 'addons-sources.psd1'
$consoleNamesPath = Join-Path $librariesRoot 'console-names.json'
$hacksNamesPath = Join-Path $librariesRoot 'hacks-names.json'
$transNamesPath = Join-Path $librariesRoot 'trans-names.json'
$addonsNamesPath = Join-Path $librariesRoot 'addons-names.json'
$settingsTemplatePath = Join-Path $librariesRoot 'settings.template.json'
$consoleTemplatePath = Join-Path $librariesRoot 'console-sources.template.psd1'
$hacksSourcesTemplatePath = Join-Path $librariesRoot 'hacks-sources.template.psd1'
$transSourcesTemplatePath = Join-Path $librariesRoot 'trans-sources.template.psd1'
$addonsSourcesTemplatePath = Join-Path $librariesRoot 'addons-sources.template.psd1'
$consoleNamesTemplatePath = Join-Path $librariesRoot 'console-names.template.json'
$hacksNamesTemplatePath = Join-Path $librariesRoot 'hacks-names.template.json'
$transNamesTemplatePath = Join-Path $librariesRoot 'trans-names.template.json'
$addonsNamesTemplatePath = Join-Path $librariesRoot 'addons-names.template.json'
$legacySourcesPath = Join-Path $librariesRoot 'sources.psd1'
$legacySourcesTemplatePath = Join-Path $librariesRoot 'sources.template.psd1'

if (-not (Test-Path -LiteralPath $consolePath) -and (Test-Path -LiteralPath $legacySourcesPath)) {
    Move-Item -LiteralPath $legacySourcesPath -Destination $consolePath -Force
}
if (-not (Test-Path -LiteralPath $consoleTemplatePath) -and (Test-Path -LiteralPath $legacySourcesTemplatePath)) {
    Move-Item -LiteralPath $legacySourcesTemplatePath -Destination $consoleTemplatePath -Force
}

$script:GamePopulatorSourcesPaths = @($consolePath, $hacksSourcesPath, $transSourcesPath, $addonsSourcesPath)
$script:GamePopulatorNamesPaths = @($consoleNamesPath, $hacksNamesPath, $transNamesPath, $addonsNamesPath)

$templateBootstrapNames = @(
    'settings.template.json',
    'console-sources.template.psd1',
    'hacks-sources.template.psd1',
    'trans-sources.template.psd1',
    'addons-sources.template.psd1',
    'console-names.template.json',
    'hacks-names.template.json',
    'trans-names.template.json',
    'addons-names.template.json'
)
$missingTemplatesBootstrap = @()
foreach ($tn in $templateBootstrapNames) {
    $tp = Join-Path $librariesRoot $tn
    if (-not (Test-Path -LiteralPath $tp -PathType Leaf)) {
        $missingTemplatesBootstrap += $tn
    }
}
if ($missingTemplatesBootstrap.Count -gt 0) {
    Write-Info "Rebuilding template files from GitHub source..."
    if (-not (Restore-GamePopulatorTemplatesFromGitHub -ScriptRoot $scriptRoot -LibrariesRoot $librariesRoot -TemplateFileNames @($missingTemplatesBootstrap))) {
        Write-Fail "Could not download missing template files from GitHub. Check your network connection."
    }
    Write-Info "Restarting script after restoring templates."
    Invoke-GamePopulatorScriptRestart
    exit $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $settingsPath)) {
    Write-Host "Settings file not found: " -NoNewline -ForegroundColor Yellow
    Write-Host ([System.IO.Path]::GetFileName($settingsPath)) -ForegroundColor White
    if (Read-YesNoDefaultYes 'Recreate libraries\settings.json now?') {
        if (-not (Test-Path -LiteralPath $settingsTemplatePath)) {
            Write-Host "Settings template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($settingsTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
    }
    else {
        Write-Fail "Settings file is required."
    }
}
if (-not (Test-Path -LiteralPath $consolePath)) {
    Write-Host 'libraries\console-sources.psd1 not found: ' -NoNewline -ForegroundColor Yellow
    Write-Host ([System.IO.Path]::GetFileName($consolePath)) -ForegroundColor White
    if (Read-YesNoDefaultYes 'Recreate libraries\console-sources.psd1 from template now?') {
        if (-not (Test-Path -LiteralPath $consoleTemplatePath)) {
            Write-Host "Template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($consoleTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $consoleTemplatePath -Destination $consolePath -Force
    }
    else {
        Write-Fail 'libraries\console-sources.psd1 is required.'
    }
}
if (-not (Test-Path -LiteralPath $consoleNamesPath)) {
    Write-Host "Console names file not found: " -NoNewline -ForegroundColor Yellow
    Write-Host ([System.IO.Path]::GetFileName($consoleNamesPath)) -ForegroundColor White
    if (Read-YesNoDefaultYes 'Recreate libraries\console-names.json now?') {
        if (-not (Test-Path -LiteralPath $consoleNamesTemplatePath)) {
            Write-Host "Console names template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($consoleNamesTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $consoleNamesTemplatePath -Destination $consoleNamesPath -Force
    }
    else {
        Write-Fail "Console names file is required."
    }
}

$optionalConfigSeeds = @(
    @{ Path = $hacksSourcesPath; Template = $hacksSourcesTemplatePath }
    @{ Path = $transSourcesPath; Template = $transSourcesTemplatePath }
    @{ Path = $addonsSourcesPath; Template = $addonsSourcesTemplatePath }
    @{ Path = $hacksNamesPath; Template = $hacksNamesTemplatePath }
    @{ Path = $transNamesPath; Template = $transNamesTemplatePath }
    @{ Path = $addonsNamesPath; Template = $addonsNamesTemplatePath }
)
foreach ($seed in $optionalConfigSeeds) {
    if (-not (Test-Path -LiteralPath $seed.Path) -and (Test-Path -LiteralPath $seed.Template)) {
        Copy-Item -LiteralPath $seed.Template -Destination $seed.Path -Force
    }
}

$settings = $null
try {
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
}
catch {
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
            Invoke-GamePopulatorScriptRestart
            exit $LASTEXITCODE
        }
        catch {
            $settings = $null
        }
    }
    if (-not $settings) {
        if (Read-YesNoDefaultYes 'Recreate libraries\settings.json now?') {
            if (-not (Test-Path -LiteralPath $settingsTemplatePath)) {
                Write-Host "Settings template not found: " -NoNewline -ForegroundColor Yellow
                Write-Host ([System.IO.Path]::GetFileName($settingsTemplatePath)) -ForegroundColor White
                exit 1
            }
            Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
            $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        }
        else {
            Write-Fail "Settings file is required."
        }
    }
}

$gamePopulatorFunctionsPath = Join-Path $librariesRoot 'game-populator-functions.ps1'
if (-not (Test-Path -LiteralPath $gamePopulatorFunctionsPath -PathType Leaf)) {
    Write-Host "Required file not found: " -NoNewline -ForegroundColor Red
    Write-Host ('libraries\{0}' -f 'game-populator-functions.ps1') -ForegroundColor White
    exit 1
}
. $gamePopulatorFunctionsPath


$script:PostMenuDestinationInit = $null
$script:CustomRunActive = $false
$script:CustomRunOrganizeExisting = $false
$organizeRegions = $false
$doCleanup = $false
$doProcessing = $true
$doRecreateConfig = $false
$script:RestartAfterInteractiveCleanup = $false
$script:GpMigrateAssetMode = 'extract'
$script:GpPendingSingleConsoleForMigrate = $null
$script:GpSingleSystemInteractiveSession = $false
$script:GpPostMigrateInteractiveRepeatKind = ''

$gpLaunchIntent = Read-GamePopulatorLaunchIntent
$Org = [bool]$gpLaunchIntent.Org
$NoOrg = [bool]$gpLaunchIntent.NoOrg
$Cleanup = [bool]$gpLaunchIntent.Cleanup
$Resume = [bool]$gpLaunchIntent.Resume
$SingleSystemInteractive = [bool]$gpLaunchIntent.SingleSystemInteractive
$CustomRunInteractive = [bool]$gpLaunchIntent.CustomRunInteractive
$OnlyConsoles = $gpLaunchIntent.OnlyConsoles

if (-not [string]::IsNullOrWhiteSpace([string]$gpLaunchIntent.DestinationRoot)) {
    $DestinationRoot = Resolve-DestinationPath -Path (($gpLaunchIntent.DestinationRoot).ToString().Trim())
}
elseif ($settings.DestinationRoot) {
    $DestinationRoot = Resolve-DestinationPath -Path $settings.DestinationRoot
}

if (-not [string]::IsNullOrWhiteSpace([string]$gpLaunchIntent.TempRoot)) {
    $TempRoot = ($gpLaunchIntent.TempRoot).ToString().Trim()
}
elseif ($settings.TempRoot) {
    $TempRoot = $settings.TempRoot
}

if (-not $DestinationRoot) {
    Write-Host 'Destination root is not set. Edit ' -NoNewline -ForegroundColor DarkYellow
    Write-Host 'libraries\settings.json' -NoNewline -ForegroundColor White
    Write-Host ' (DestinationRoot).' -ForegroundColor DarkYellow
    Write-Fail 'DestinationRoot is required.'
}
$DestinationRoot = Resolve-DestinationPath -Path $DestinationRoot
$DestinationRoot = Resolve-DestinationGamesSubfolder -Path $DestinationRoot
if (-not $TempRoot) {
    Write-Host 'Temp folder is not set. Edit ' -NoNewline -ForegroundColor DarkYellow
    Write-Host 'libraries\settings.json' -NoNewline -ForegroundColor White
    Write-Host ' (TempRoot).' -ForegroundColor DarkYellow
    Write-Fail 'TempRoot is required.'
}
if ($TempRoot) {
    Initialize-TempRootDirectory -Path $TempRoot
}

$activeConsoleSourceCount = 0
if ($null -ne $allConsoles) {
    $activeConsoleSourceCount = @($allConsoles | Where-Object {
            $_ `
                -and (Test-GamePopulatorMergedSourceEntryEnabled $_) `
                -and -not [string]::IsNullOrWhiteSpace($_.Name) `
                -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
        }).Count
}

$settingsLabelWidth = 26

Write-Host "Settings:" -ForegroundColor Cyan
Write-Host ("  - {0,-$settingsLabelWidth}" -f 'Destination:') -NoNewline -ForegroundColor White
Write-Host $DestinationRoot -ForegroundColor Green
Write-Host ("  - {0,-$settingsLabelWidth}" -f 'Temp Folder:') -NoNewline -ForegroundColor White
Write-Host (Format-PathForDisplay $TempRoot) -ForegroundColor Green
Write-Host ("  - {0,-$settingsLabelWidth}" -f 'Active components:') -NoNewline -ForegroundColor White
Write-Host $activeConsoleSourceCount.ToString() -ForegroundColor Green
Write-Host ""

$menuOptions = @($Org, $NoOrg, $Cleanup) | Where-Object { $_ }
if ($menuOptions -isnot [System.Array]) { $menuOptions = @($menuOptions) }
if ($menuOptions.Count -gt 1) {
    Write-Fail "Multiple mode switches passed. Use only one."
}

if (($Org -or $NoOrg -or $Cleanup) -and ($SingleSystemInteractive -or $CustomRunInteractive)) {
    Write-Fail "Do not combine Org/NoOrg/Cleanup with a guided migrate in the same launch intent."
}

if ($SingleSystemInteractive -and $CustomRunInteractive) {
    Write-Fail "Use only one guided migrate mode (single-system or custom run) per launch intent."
}

if ($Org) {
    $organizeRegions = $true
    $doCleanup = $true
    $script:GpMigrateAssetMode = 'extract'
}
elseif ($NoOrg) {
    $organizeRegions = $false
    $doCleanup = $true
    $script:GpMigrateAssetMode = 'extract'
}
elseif ($Cleanup) {
    $doProcessing = $false
    $organizeRegions = $false
    $doCleanup = $true
    $stdinRedirected = $false
    try { $stdinRedirected = [Console]::IsInputRedirected } catch { $stdinRedirected = $false }
    if (-not $stdinRedirected) {
        $script:RestartAfterInteractiveCleanup = $true
    }
}
elseif ($SingleSystemInteractive) {
    Clear-Host | Out-Null
    $wizSs = Invoke-GpSingleSystemMigrateInteractiveWizard -DisplayNameMap $consoleDisplayNameMap -DestinationRootRaw $DestinationRoot -ShareUser ($settings.ShareUser) -SharePassword $settings.SharePassword -ConsoleOpticalDisplaySetHashSetObj $consoleOpticalSet -AllConsolesMerged $allConsoles
    if ($null -eq $wizSs) {
        Write-Info 'Restarting script to return to the main menu...'
        Invoke-GamePopulatorScriptRestart
    }
    Invoke-GpApplySingleSystemWizardResult -WizSs $wizSs
}
elseif ($CustomRunInteractive) {
    $crx = Read-CustomRunConfigurationWithConnectivityRetries
    if ($null -eq $crx) {
        Write-Info 'Restarting script to return to the main menu...'
        Invoke-GamePopulatorScriptRestart
    }
    Invoke-GpApplyCustomRunInteractiveResult -Crx $crx
}
else {
    $menuValid = $false
    $mainMenuPrinted = $false
    while (-not $menuValid) {
        if (-not $mainMenuPrinted) {
            Show-MainMenu
            Write-Host ""
            $mainMenuPrinted = $true
        }
        Invoke-OutputFlush
        Write-ScriptDiag "Read-Host menu (waiting for 1-14, H, E, or [Enter] to exit)"
        if (-not (Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $DestinationRoot)) {
            Write-Host 'Warning:' -ForegroundColor DarkRed
            Write-Host ' - The destination location is not reachable.' -ForegroundColor Red
            Write-Host ' -- Reestablish the connection or define another destination (option 2 from main menu).' -ForegroundColor Red
            Write-Host ""
        }
        $choice = (Read-Host "Select 1-14, H for help, or [Enter] to exit").Trim()
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match '^(?i)(e|exit)$') { exit 0 }
        switch ($choice) {
            '1' {
                Invoke-GamePopulatorSourceManagementMenu
                Write-Info "Restarting script to reload configuration..."
                Invoke-GamePopulatorScriptRestart
                exit $LASTEXITCODE
            }
            '2' {
                Invoke-EditSettingsJsonMenu -SettingsLiteralPath $settingsPath -SettingsRef ([ref]$settings)
                Write-Info "Restarting script to reload configuration..."
                Invoke-GamePopulatorScriptRestart
                exit $LASTEXITCODE
            }
            '3' {
                Invoke-GamePopulatorConfigurationValidationReport
                Write-Host "Press " -NoNewline -ForegroundColor White
                Write-Host "[Enter]" -NoNewline -ForegroundColor Green
                Write-Host " to restart and return to the menu." -ForegroundColor White
                Invoke-OutputFlush
                try {
                    do {
                        $k = [Console]::ReadKey($true)
                    } while ($k.Key -ne [ConsoleKey]::Enter)
                }
                catch {
                    $null = Read-Host 'Press Enter to restart the script.'
                }
                Write-Info 'Restarting script...'
                Invoke-GamePopulatorScriptRestart
                exit $LASTEXITCODE
            }
            '4' {
                Invoke-GamePopulatorActiveSourceLocationsValidationReport
                Write-Host "Press " -NoNewline -ForegroundColor White
                Write-Host "[Enter]" -NoNewline -ForegroundColor Green
                Write-Host " to restart and return to the menu." -ForegroundColor White
                Invoke-OutputFlush
                try {
                    do {
                        $k = [Console]::ReadKey($true)
                    } while ($k.Key -ne [ConsoleKey]::Enter)
                }
                catch {
                    $null = Read-Host 'Press Enter to restart the script.'
                }
                Write-Info 'Restarting script...'
                Invoke-GamePopulatorScriptRestart
                exit $LASTEXITCODE
            }
            '5' {
                $script:RestartAfterInteractiveCleanup = $true
                $doProcessing = $false; $organizeRegions = $false; $doCleanup = $true; $menuValid = $true
            }
            '6' {
                Write-Host ""
                Write-Host "Disconnects SMB mappings managed by this script, then reconnects the destination folder from " -NoNewline -ForegroundColor White
                Write-Host "libraries\settings.json" -NoNewline -ForegroundColor Green
                Write-Host "." -ForegroundColor White
                $option6NetworkRan = $false
                if (Read-YesNoDefaultNo "Proceed?") {
                    $option6NetworkRan = $true
                    $destReconnect = Resolve-DestinationGamesSubfolder -Path (Resolve-DestinationPath -Path $settings.DestinationRoot)
                    $pathList = [System.Collections.Generic.List[string]]::new()
                    if ($settings.DestinationRoot) {
                        $pathList.Add((Resolve-DestinationPath -Path $settings.DestinationRoot)) | Out-Null
                    }
                    $pathList.Add($destReconnect) | Out-Null
                    foreach ($c in @($allConsoles)) {
                        if ($c -and $c.SourcePath) {
                            $pathList.Add(($c.SourcePath.Trim())) | Out-Null
                        }
                    }
                    try {
                        Write-Host ""
                        Disconnect-GamePopulatorNetworkMappings -UncPathCandidates @($pathList) -Quiet
                        Write-Info "Disconnected script SMB connections."
                        $reInfo = Initialize-DestinationRoot -Path $destReconnect -User $settings.ShareUser -Password $settings.SharePassword -Quiet
                        if ($destReconnect.StartsWith('\\')) {
                            $script:PostMenuDestinationInit = $reInfo
                            Write-Info ("Destination share connected: {0}" -f $reInfo.Path)
                        }
                        else {
                            $script:PostMenuDestinationInit = $null
                            Write-Info ("Destination folder ready (local path): {0}" -f $reInfo.Path)
                        }
                        Write-Host ""
                    }
                    catch {
                        $script:PostMenuDestinationInit = $null
                        $msg = $_.Exception.Message
                        $hint = Expand-SmbConnectErrorHint -RawMessage $msg -UncPath $destReconnect
                        Write-Warn ("Could not connect to destination share: {0}" -f $msg)
                        if ($hint) { Write-Host $hint -ForegroundColor DarkYellow }
                        Write-Host ""
                    }
                }
                if ($option6NetworkRan) {
                    Write-Host ""
                    Write-Host "Press " -NoNewline -ForegroundColor White
                    Write-Host "[Enter]" -NoNewline -ForegroundColor Green
                    Write-Host " when ready to continue." -ForegroundColor White
                    Invoke-OutputFlush
                    try {
                        do {
                            $k = [Console]::ReadKey($true)
                        } while ($k.Key -ne [ConsoleKey]::Enter)
                    }
                    catch {
                        $null = Read-Host "Press Enter to restart the script."
                    }
                    Write-Host ""
                }
                Write-Info "Restarting script to reload configuration..."
                Invoke-GamePopulatorScriptRestart
                exit $LASTEXITCODE
            }
            '7' { $doRecreateConfig = $true; $menuValid = $true }
            '8' {
                $null = Invoke-GamePopulatorSelfUpdate -ScriptRoot $scriptRoot -LibrariesRoot $librariesRoot
                Write-Info "Restarting script..."
                Invoke-GamePopulatorScriptRestart
                exit $LASTEXITCODE
            }
            '9' { $script:GpMigrateAssetMode = 'extract'; $organizeRegions = $true; $doCleanup = $true; $menuValid = $true }
            '10' { $script:GpMigrateAssetMode = 'extract'; $organizeRegions = $false; $doCleanup = $true; $menuValid = $true }
            '11' {
                if (-not (Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $DestinationRoot)) {
                    Write-Warn 'The destination configured in libraries\settings.json is not reachable. Use main menu option 2 before running archive→ZIP migration.'
                    continue
                }
                $organizeRegions = $true
                $script:GpMigrateAssetMode = 'zipDest'
                $doCleanup = $true
                $menuValid = $true
            }
            '12' {
                if (-not (Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $DestinationRoot)) {
                    Write-Warn 'The destination configured in libraries\settings.json is not reachable. Use main menu option 2 before running archive→ZIP migration.'
                    continue
                }
                $organizeRegions = $false
                $script:GpMigrateAssetMode = 'zipDest'
                $doCleanup = $true
                $menuValid = $true
            }
            '13' {
                if (-not (Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $DestinationRoot)) {
                    Write-Warn 'The destination configured in libraries\settings.json is not reachable. Use main menu option 2 before single-system copy.'
                    continue
                }
                Clear-Host | Out-Null
                $wizSsMn = Invoke-GpSingleSystemMigrateInteractiveWizard -DisplayNameMap $consoleDisplayNameMap -DestinationRootRaw $DestinationRoot -ShareUser ($settings.ShareUser) -SharePassword $settings.SharePassword -ConsoleOpticalDisplaySetHashSetObj $consoleOpticalSet -AllConsolesMerged $allConsoles
                if ($null -eq $wizSsMn) {
                    Write-Info 'Restarting script to return to the main menu...'
                    Invoke-GamePopulatorScriptRestart
                    exit $LASTEXITCODE
                }
                Invoke-GpApplySingleSystemWizardResult -WizSs $wizSsMn
                $menuValid = $true
                break
            }
            { $_ -match '^(?i)h$' } {
                Show-Help -NoExit
                Write-Host ""
                Write-Host "Press " -NoNewline -ForegroundColor White
                Write-Host "[Enter]" -NoNewline -ForegroundColor Green
                Write-Host " to restart the script and return to the main menu." -ForegroundColor White
                Invoke-OutputFlush
                try {
                    do {
                        $k = [Console]::ReadKey($true)
                    } while ($k.Key -ne [ConsoleKey]::Enter)
                }
                catch {
                    $null = Read-Host "Press Enter to restart"
                }
                Write-Host ""
                Invoke-GamePopulatorScriptRestart
            }
            '14' {
                $crxMn = Read-CustomRunConfigurationWithConnectivityRetries
                if ($null -eq $crxMn) {
                    Write-Info 'Restarting script to return to the main menu...'
                    Invoke-GamePopulatorScriptRestart
                    exit $LASTEXITCODE
                }
                Invoke-GpApplyCustomRunInteractiveResult -Crx $crxMn
                $menuValid = $true
                break
            }
            default {
                Write-Warn "Invalid selection. Enter 1-14, H for help, E to exit, or press Enter to exit."
            }
        }
    }
}

if ($script:CustomRunActive) {
    Initialize-TempRootDirectory -Path $TempRoot
}

if ($doRecreateConfig) {
    $missingTemplates = @()
    if (Read-YesNoDefaultNo "`nRecreate settings file (libraries\settings.json) from template?") {
        if (Test-Path -LiteralPath $settingsTemplatePath) {
            Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $settingsPath
            Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
            Write-Info 'Recreated: libraries\settings.json'
        }
        else {
            $missingTemplates += 'settings.template.json'
        }
    }
    if (Read-YesNoDefaultNo "Recreate libraries\console-sources.psd1 from template?") {
        if (Test-Path -LiteralPath $consoleTemplatePath) {
            Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $consolePath
            Copy-Item -LiteralPath $consoleTemplatePath -Destination $consolePath -Force
            Write-Info 'Recreated: libraries\console-sources.psd1'
        }
        else {
            $missingTemplates += 'console-sources.template.psd1'
        }
    }
    if (Read-YesNoDefaultNo "Recreate libraries\hacks-sources.psd1 from template?") {
        if (Test-Path -LiteralPath $hacksSourcesTemplatePath) {
            Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $hacksSourcesPath
            Copy-Item -LiteralPath $hacksSourcesTemplatePath -Destination $hacksSourcesPath -Force
            Write-Info 'Recreated: libraries\hacks-sources.psd1'
        }
        else {
            $missingTemplates += 'hacks-sources.template.psd1'
        }
    }
    if (Read-YesNoDefaultNo "Recreate libraries\trans-sources.psd1 from template?") {
        if (Test-Path -LiteralPath $transSourcesTemplatePath) {
            Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $transSourcesPath
            Copy-Item -LiteralPath $transSourcesTemplatePath -Destination $transSourcesPath -Force
            Write-Info 'Recreated: libraries\trans-sources.psd1'
        }
        else {
            $missingTemplates += 'trans-sources.template.psd1'
        }
    }
    if (Read-YesNoDefaultNo "Recreate libraries\addons-sources.psd1 from template?") {
        if (Test-Path -LiteralPath $addonsSourcesTemplatePath) {
            Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $addonsSourcesPath
            Copy-Item -LiteralPath $addonsSourcesTemplatePath -Destination $addonsSourcesPath -Force
            Write-Info 'Recreated: libraries\addons-sources.psd1'
        }
        else {
            $missingTemplates += 'addons-sources.template.psd1'
        }
    }
    if (Read-YesNoDefaultNo "Recreate libraries\console-names.json from template?") {
        if (Test-Path -LiteralPath $consoleNamesTemplatePath) {
            Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $consoleNamesPath
            Copy-Item -LiteralPath $consoleNamesTemplatePath -Destination $consoleNamesPath -Force
            Write-Info 'Recreated: libraries\console-names.json'
        }
        else {
            $missingTemplates += 'console-names.template.json'
        }
    }
    if (Read-YesNoDefaultNo "Recreate libraries\hacks-names.json from template?") {
        if (Test-Path -LiteralPath $hacksNamesTemplatePath) {
            Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $hacksNamesPath
            Copy-Item -LiteralPath $hacksNamesTemplatePath -Destination $hacksNamesPath -Force
            Write-Info 'Recreated: libraries\hacks-names.json'
        }
        else {
            $missingTemplates += 'hacks-names.template.json'
        }
    }
    if (Read-YesNoDefaultNo "Recreate libraries\trans-names.json from template?") {
        if (Test-Path -LiteralPath $transNamesTemplatePath) {
            Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $transNamesPath
            Copy-Item -LiteralPath $transNamesTemplatePath -Destination $transNamesPath -Force
            Write-Info 'Recreated: libraries\trans-names.json'
        }
        else {
            $missingTemplates += 'trans-names.template.json'
        }
    }
    if (Read-YesNoDefaultNo "Recreate libraries\addons-names.json from template?") {
        if (Test-Path -LiteralPath $addonsNamesTemplatePath) {
            Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $addonsNamesPath
            Copy-Item -LiteralPath $addonsNamesTemplatePath -Destination $addonsNamesPath -Force
            Write-Info 'Recreated: libraries\addons-names.json'
        }
        else {
            $missingTemplates += 'addons-names.template.json'
        }
    }
    if ($missingTemplates.Count -gt 0) {
        Write-Host ""
        Write-Info "Rebuilding template files from GitHub source..."
        if (-not (Restore-GamePopulatorTemplatesFromGitHub -ScriptRoot $scriptRoot -LibrariesRoot $librariesRoot -TemplateFileNames @($missingTemplates))) {
            Write-Warn ("Could not restore templates from GitHub. Missing: {0}" -f ($missingTemplates -join ', '))
            exit 1
        }
        foreach ($fn in $missingTemplates) {
            if ($fn -eq 'settings.template.json') {
                Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $settingsPath
                Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
                Write-Info 'Recreated: libraries\settings.json'
            }
            elseif ($fn -eq 'console-sources.template.psd1') {
                Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $consolePath
                Copy-Item -LiteralPath $consoleTemplatePath -Destination $consolePath -Force
                Write-Info 'Recreated: libraries\console-sources.psd1'
            }
            elseif ($fn -eq 'hacks-sources.template.psd1') {
                Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $hacksSourcesPath
                Copy-Item -LiteralPath $hacksSourcesTemplatePath -Destination $hacksSourcesPath -Force
                Write-Info 'Recreated: libraries\hacks-sources.psd1'
            }
            elseif ($fn -eq 'trans-sources.template.psd1') {
                Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $transSourcesPath
                Copy-Item -LiteralPath $transSourcesTemplatePath -Destination $transSourcesPath -Force
                Write-Info 'Recreated: libraries\trans-sources.psd1'
            }
            elseif ($fn -eq 'addons-sources.template.psd1') {
                Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $addonsSourcesPath
                Copy-Item -LiteralPath $addonsSourcesTemplatePath -Destination $addonsSourcesPath -Force
                Write-Info 'Recreated: libraries\addons-sources.psd1'
            }
            elseif ($fn -eq 'console-names.template.json') {
                Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $consoleNamesPath
                Copy-Item -LiteralPath $consoleNamesTemplatePath -Destination $consoleNamesPath -Force
                Write-Info 'Recreated: libraries\console-names.json'
            }
            elseif ($fn -eq 'hacks-names.template.json') {
                Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $hacksNamesPath
                Copy-Item -LiteralPath $hacksNamesTemplatePath -Destination $hacksNamesPath -Force
                Write-Info 'Recreated: libraries\hacks-names.json'
            }
            elseif ($fn -eq 'trans-names.template.json') {
                Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $transNamesPath
                Copy-Item -LiteralPath $transNamesTemplatePath -Destination $transNamesPath -Force
                Write-Info 'Recreated: libraries\trans-names.json'
            }
            elseif ($fn -eq 'addons-names.template.json') {
                Backup-GamePopulatorLibraryFileIfPresent -LiteralPath $addonsNamesPath
                Copy-Item -LiteralPath $addonsNamesTemplatePath -Destination $addonsNamesPath -Force
                Write-Info 'Recreated: libraries\addons-names.json'
            }
        }
        Write-Host ""
        Write-Info "Restarting script to load recreated config."
        Invoke-GamePopulatorScriptRestart
        exit $LASTEXITCODE
    }
    Write-Host ""
    Write-Info "Restarting script to reload configuration..."
    Invoke-GamePopulatorScriptRestart
    exit $LASTEXITCODE
}

$cleanupOnly = (-not $doProcessing -and $doCleanup)

if ($settings.SevenZipExe) {
    $script:SevenZipExe = $settings.SevenZipExe
}

$destDrive = $null
$destinationPathDisplay = $DestinationRoot
$destUserForInit = $settings.ShareUser
$destPassForInit = $settings.SharePassword
if ($script:CustomRunActive) {
    $destUserForInit = $script:CustomRunDestUser
    $destPassForInit = $script:CustomRunDestPassword
}
if ($null -eq $script:PostMenuDestinationInit) {
    if (-not (Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $DestinationRoot)) {
        Write-Host ''
        Write-Host 'Destination folder is not reachable before SMB connection (same check as Validate configuration).' -ForegroundColor Red
        Write-Host ('       {0}' -f (Format-PathForDisplay (Resolve-DestinationPath -Path (($DestinationRoot.ToString()).Trim())))) -ForegroundColor DarkYellow
        if ($script:CustomRunActive) {
            Write-Host '       For custom runs, verify the chosen destination path exists and reconnect network/SMB.' -ForegroundColor DarkGray
        }
        else {
            Write-Host ("       Set DestinationRoot in {0} (main menu 2). UNC/SMB: try main menu 6." -f (Format-PathForDisplay $settingsPath)) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host "Press " -NoNewline -ForegroundColor White
        Write-Host "[Enter]" -NoNewline -ForegroundColor Green
        Write-Host " to restart the script." -ForegroundColor White
        Invoke-OutputFlush
        try {
            do {
                $k = [Console]::ReadKey($true)
            } while ($k.Key -ne [ConsoleKey]::Enter)
        }
        catch {
            $null = Read-Host 'Press Enter to restart the script'
        }
        Write-Host ''
        Write-Info 'Restarting script...'
        Invoke-GamePopulatorScriptRestart
        exit $LASTEXITCODE
    }
}
Write-ScriptDiag "Before Initialize-DestinationRoot (UNC share mapping can hang if the server is unreachable)"
Invoke-OutputFlush
$uncCountdownJob = $null
if ($null -eq $script:PostMenuDestinationInit) {
    $resolvedCountdownPath = Resolve-DestinationPath -Path $DestinationRoot
    if ($cleanupOnly -and $script:RestartAfterInteractiveCleanup -and $resolvedCountdownPath.StartsWith('\\')) {
        $uncCountdownJob = Start-DestinationUncConnectionCountdownDisplay -AdvisoryLimitSeconds 30
    }
}
try {
    if ($null -ne $script:PostMenuDestinationInit) {
        Write-ScriptDiag "Using destination PSDrive from menu option 6 (network reset)"
        $destInfo = $script:PostMenuDestinationInit
        $script:PostMenuDestinationInit = $null
    }
    else {
        $destInfo = Initialize-DestinationRoot -Path $DestinationRoot -User $destUserForInit -Password $destPassForInit
    }
    $DestinationRoot = $destInfo.Path
    $destDrive = $destInfo.Drive
}
catch {
    $msg = $_.Exception.Message
    $hint = Expand-SmbConnectErrorHint -RawMessage $msg -UncPath $DestinationRoot
    Write-Host "Failed to connect to destination: " -NoNewline -ForegroundColor Yellow
    Write-Host $DestinationRoot -NoNewline -ForegroundColor White
    Write-Host " ($msg)" -ForegroundColor Yellow
    if ($hint) {
        Write-Host ''
        Write-Host $hint -ForegroundColor DarkYellow
    }
    exit 1
}
finally {
    if ($uncCountdownJob) {
        Stop-GamePopulatorBackgroundStatusDisplay -Job $uncCountdownJob
    }
}

if ($script:CustomRunActive -and $script:CustomRunDestDisplay) {
    $destinationPathDisplay = $script:CustomRunDestDisplay
}

$ConsoleSources = @($allConsoles | Where-Object {
        $_ `
            -and (Test-GamePopulatorMergedSourceEntryEnabled $_) `
            -and -not [string]::IsNullOrWhiteSpace($_.Name) `
            -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
    })
if ($null -ne $script:GpPendingSingleConsoleForMigrate) {
    $pendingPick = $script:GpPendingSingleConsoleForMigrate
    $script:GpPendingSingleConsoleForMigrate = $null
    $ConsoleSources = @([pscustomobject]@{
            Name       = [string]$pendingPick.Name
            SourcePath = [string]$pendingPick.SourcePath
        })
}
$ConsoleSourcesReachable = @()

if (-not $cleanupOnly) {
    if (-not $script:CustomRunActive) {
        if ((-not ($script:GpSingleSystemInteractiveSession)) -and (-not $ConsoleSources -or $ConsoleSources.Count -eq 0)) {
            Write-Host ""
            Write-Host "No consoles were configured. Run option 1 to setup consoles." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press " -NoNewline -ForegroundColor White
            Write-Host "[Enter]" -NoNewline -ForegroundColor Green
            Write-Host " to restart the script." -ForegroundColor White
            Invoke-OutputFlush
            try {
                do {
                    $k = [Console]::ReadKey($true)
                } while ($k.Key -ne [ConsoleKey]::Enter)
            }
            catch {
                $null = Read-Host "Press Enter to restart the script"
            }
            Write-Host ""
            Write-Info "Restarting script..."
            Invoke-GamePopulatorScriptRestart
            exit $LASTEXITCODE
        }
    }
    $srcUser = $settings.ShareUser
    $srcPass = $settings.SharePassword

    if ($script:CustomRunActive) {
        Write-Host ""
        Write-Host 'Verifying custom source path...' -ForegroundColor DarkGray
        Invoke-OutputFlush
        $probe = Test-ConsoleSourcePath -Root $script:CustomRunSourcePath -User $srcUser -Password $srcPass
        if (-not $probe.OK) {
            $detail = if ($probe.Error) { " ($($probe.Error))" } else { '' }
            Write-Fail ("Custom source is not reachable: {0}{1}" -f (Format-PathForDisplay $script:CustomRunSourcePath), $detail)
        }
        $ConsoleSourcesReachable = @([pscustomobject]@{ Name = 'Custom run'; SourcePath = $script:CustomRunSourcePath })
        Write-Host ""
    }
    else {
        $logsParentEarly = Join-Path $scriptRoot 'logs'
        if (-not (Test-Path -LiteralPath $logsParentEarly -PathType Container)) {
            New-Item -Path $logsParentEarly -ItemType Directory -Force | Out-Null
        }
        $gpVcGuardStartup = Join-Path $logsParentEarly 'gp-source-verification-cache.json'

        $guardFingerprintStartup = Get-GpSourceVerificationGuardFingerprintSha256Hex `
            -Sources @($ConsoleSources) `
            -ShareUserRaw $settings.ShareUser `
            -GamePopulatorSettingsLiteralPath $settingsPath

        Write-Host ''

        $skipRepeatedProbe = $false
        if (-not $script:GpSingleSystemInteractiveSession) {
            $skipRepeatedProbe = (Test-GpSourceVerificationGuardCacheHit -CacheLiteralPath $gpVcGuardStartup -ExpectedFingerprint $guardFingerprintStartup)
        }
        $reachableList = $null
        $unreachableList = $null
        $didDisableUnreachableDuringProbe = $false

        if ($skipRepeatedProbe) {
            Write-Host 'Using saved source connectivity verification (manual menu 4 or last migrate preflight succeeded with no failures; rerun after any enabled SourcePath or libraries\settings.json change).' -ForegroundColor DarkYellow
            Write-Host ('       Cache: {0}' -f (Format-PathForDisplay $gpVcGuardStartup)) -ForegroundColor DarkGray
            $reachableList = [System.Collections.Generic.List[object]]::new()
            foreach ($x in @($ConsoleSources)) {
                $reachableList.Add($x) | Out-Null
            }
            $unreachableList = [System.Collections.Generic.List[hashtable]]::new()
            $didDisableUnreachableDuringProbe = $false
        }
        else {
            Write-Host 'Verifying each enabled console SourcePath (folder preflight, then SMB credentials as used for copying)...' -ForegroundColor DarkYellow
            Invoke-OutputFlush

            $probeStartup = Invoke-GpTestEnabledConsoleSharesReachability -Sources @($ConsoleSources) `
                -ShareUserArg ($settings.ShareUser) `
                -SharePasswordArg $settings.SharePassword

            $reachableList = [System.Collections.Generic.List[object]](@($probeStartup.Reachable))
            $unreachableList = New-Object System.Collections.Generic.List[hashtable]
            foreach ($uh in @($probeStartup.Unreachable)) {
                $unreachableList.Add($uh) | Out-Null
            }
            $didDisableUnreachableDuringProbe = [bool]$probeStartup.DidDisableUnreachableDuringProbe

            if ((@($probeStartup.Unreachable).Count -eq 0) -and (-not $didDisableUnreachableDuringProbe) -and (-not $script:GpSingleSystemInteractiveSession)) {
                $snapSeal = @( $script:allConsoles | Where-Object {
                        $_ `
                            -and (Test-GamePopulatorMergedSourceEntryEnabled $_) `
                            -and -not [string]::IsNullOrWhiteSpace($_.Name) `
                            -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
                    })
                $fingerSealRun = Get-GpSourceVerificationGuardFingerprintSha256Hex `
                    -Sources $snapSeal `
                    -ShareUserRaw $settings.ShareUser `
                    -GamePopulatorSettingsLiteralPath $settingsPath
                Save-GpSourceVerificationGuardCache -CacheLiteralPath $gpVcGuardStartup -FingerprintSha256Hex $fingerSealRun
            }
            else {
                Remove-GpSourceVerificationGuardCacheSilently -CacheLiteralPath $gpVcGuardStartup
            }
        }

        if ($didDisableUnreachableDuringProbe) {
            Update-GamePopulatorConsoleSourcesState
            Write-Host '  Commented-out (disabled) unreachable sources were written to libraries\*-sources.psd1; merged lists reloaded.' -ForegroundColor DarkGray
        }
        $ConsoleSourcesReachable = @($reachableList)

        Write-Host ""
        Write-Host "Sources loaded: " -NoNewline -ForegroundColor Yellow
        Write-Host $ConsoleSourcesReachable.Count -ForegroundColor White
        foreach ($src in $ConsoleSourcesReachable) {
            if ($src.Name) {
                Write-Info ("  - {0}" -f $src.Name)
            }
        }
        if ($unreachableList.Count -gt 0) {
            Write-Host ""
            Write-Host 'Some enabled sources cannot be copied and were skipped. Folder unreachable entries are commented out (disabled). Credential/other SMB errors remain enabled:' -ForegroundColor Red
            foreach ($entry in $unreachableList) {
                $pathDisp = Format-PathForDisplay ([string]$entry.SourcePath)
                $errPart = if ($entry.Error) { (' — ' + [string]$entry.Error) } else { '' }
                Write-Host ('  - ' + [string]$entry.Name + ': ' + $pathDisp + $errPart) -ForegroundColor Red
            }
        }
        Write-Host ""
    }
}

if ($doProcessing -and -not $script:CustomRunActive) {
    $sourcesWithSharePath = @($ConsoleSources | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.Name) -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
        })
    if ($sourcesWithSharePath.Count -gt 0 -and $ConsoleSourcesReachable.Count -eq 0) {
        Write-Host ""
        Write-Host "No source shares are reachable; nothing to migrate. Check network paths and credentials." -ForegroundColor Red
        Write-Host ""
        Write-Host "Press " -NoNewline -ForegroundColor White
        Write-Host "[Enter]" -NoNewline -ForegroundColor Green
        Write-Host " to restart the script." -ForegroundColor White
        Invoke-OutputFlush
        try {
            do {
                $k = [Console]::ReadKey($true)
            } while ($k.Key -ne [ConsoleKey]::Enter)
        }
        catch {
            $null = Read-Host "Press Enter to restart the script"
        }
        Write-Host ""
        Write-Info "Restarting script..."
        Invoke-GamePopulatorScriptRestart
        exit $LASTEXITCODE
    }
}

$archiveExts = if ($settings.ArchiveExtensions) { @($settings.ArchiveExtensions) } else { @('.zip', '.7z', '.rar') }

$logsDir = Join-Path $scriptRoot 'logs'
if (-not (Test-Path -LiteralPath $logsDir -PathType Container)) {
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
}
$checkpointPath = Join-Path $logsDir 'game-populator-checkpoint.json'

$copyInvokedViaParameter = ([bool]$Org) -or ([bool]$NoOrg)
$stdinRedirectedGlob = $false
try { $stdinRedirectedGlob = [Console]::IsInputRedirected } catch { }

$plannedFingerprintHexForRun = ''
$destinationCanonicalForRun = ''
$checkpointRunGuid = [guid]::NewGuid().ToString('N')
$gpResumeBootstrapCompleted = @()
$resumeSucceededGlob = $false
$gpStructuredNdjsonLiteralPathForRun = ''

$script:GamePopulatorStructuredNdjsonLiteralPath = $null
$script:GpStructuredRunBasics = $null

$onlyConsolesScratch = @(foreach ($xc in @($OnlyConsoles)) {
        $t = ''
        if ($null -ne $xc) {
            try {
                $t = ($xc.ToString()).Trim()
            }
            catch {
                $t = ''
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($t)) {
            ($t.Trim().ToLowerInvariant())
        }
    })
$onlyConsolesFilterVals = @(($onlyConsolesScratch | Sort-Object -Unique))

$runOrchestrationEligible = ($doProcessing -and (-not $cleanupOnly) -and (-not $script:CustomRunActive))

if ($runOrchestrationEligible) {
    if ($onlyConsolesFilterVals.Count -gt 0) {
        $wantOnly = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($w in @($onlyConsolesFilterVals)) {
            [void]$wantOnly.Add($w)
        }
        $ConsoleSourcesReachable = @($ConsoleSourcesReachable | Where-Object { $wantOnly.Contains(([string]$_.Name).Trim().ToLowerInvariant()) })
        if ($ConsoleSourcesReachable.Count -eq 0) {
            Write-Host ''
            Write-Warn 'The OnlyConsoles filter did not match any reachable PSD1-enabled systems.'
            Invoke-OutputFlush
            try {
                Read-Host 'Press Enter to restart the script'
            }
            catch { }
            Invoke-GamePopulatorScriptRestart
        }
    }
    elseif ((-not $copyInvokedViaParameter) -and (-not ($script:GpSingleSystemInteractiveSession))) {
        $ConsoleSourcesReachable = @(Invoke-GpSelectReachableSubsetInteractive -ReachableSources $ConsoleSourcesReachable -DisplayNameMapForKeys $consoleDisplayNameMap)
    }

    $fpSingleConsoleKeySeg = ''
    if ($script:GpSingleSystemInteractiveSession -and ($null -ne $ConsoleSourcesReachable) -and (@($ConsoleSourcesReachable).Count -gt 0)) {
        try {
            $fpSingleConsoleKeySeg = (([string]$ConsoleSourcesReachable[0].Name).Trim().ToLowerInvariant())
        }
        catch {
            $fpSingleConsoleKeySeg = ''
        }
    }
    $plannedFingerprintHexForRun = Get-GpRunPlanFingerprintSha256Hex `
        -ReachableSources $ConsoleSourcesReachable `
        -OrganizeRegions $organizeRegions `
        -CopyInvokedViaParameter $copyInvokedViaParameter `
        -AssetMode ([string]$script:GpMigrateAssetMode) `
        -OptionalSingleConsoleKeyLower $fpSingleConsoleKeySeg
    $destinationCanonicalForRun = Get-GpFingerprintPathNormalized -LiteralPathResolvedOrRaw $DestinationRoot

    $resumeRequested = $false
    if ($useRunCheckpointSetting -and $ConsoleSourcesReachable.Count -gt 0 -and (-not [string]::IsNullOrWhiteSpace($plannedFingerprintHexForRun))) {
        if ([bool]$Resume) {
            $resumeRequested = $true
        }
        elseif ((-not $copyInvokedViaParameter) -and (-not $stdinRedirectedGlob) -and (Test-Path -LiteralPath $checkpointPath -PathType Leaf)) {
            if (Read-YesNoDefaultNo 'Checkpoint found — resume the last interrupted migrate run (remaining systems)?') {
                $resumeRequested = $true
            }
            else {
                Remove-GpRunCheckpointSilently -CheckpointLiteralPath $checkpointPath
            }
        }
    }

    if ($resumeRequested) {
        if (-not (Test-Path -LiteralPath $checkpointPath -PathType Leaf)) {
            if ([bool]$Resume) {
                Write-Fail ('Non-interactive resume was requested but checkpoint was not found ({0}).' -f (Format-PathForDisplay $checkpointPath))
            }
        }
        else {
            $ckObj = Import-GpRunCheckpointObject -CheckpointLiteralPath $checkpointPath
            if (-not (Test-GpCheckpointCompatibleWithResume -Ck $ckObj -PlannedFingerprintHex $plannedFingerprintHexForRun -DestinationCanonical $destinationCanonicalForRun -OrganizeRegions $organizeRegions -CopyInvokedViaParameter $copyInvokedViaParameter)) {
                if ([bool]$Resume) {
                    Write-Fail ('Checkpoint at {0} does not match the current migrate plan (resume failed). Adjust settings or delete this file.' -f (Format-PathForDisplay $checkpointPath))
                }
                Write-Warn 'Checkpoint mismatch for the current migrate plan — cleared.'
                Remove-GpRunCheckpointSilently -CheckpointLiteralPath $checkpointPath
            }
            else {
                $checkpointRunGuid = [string]$ckObj.runId
                $completedFromCkListRaw = @()
                if ($null -ne $ckObj.completedConsoleKeys) {
                    $scratchCk = @(foreach ($q in @($ckObj.completedConsoleKeys)) {
                            ([string]$q).Trim().ToLowerInvariant()
                        })
                    $completedFromCkListRaw = @( @($scratchCk) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } )
                }
                $completedSetCk = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($x in @($completedFromCkListRaw)) {
                    [void]$completedSetCk.Add($x)
                }
                $gpResumeBootstrapCompleted = @(($completedSetCk.ToArray()) | Sort-Object)
                $ConsoleSourcesReachable = @($ConsoleSourcesReachable | Where-Object { -not $completedSetCk.Contains(([string]$_.Name).Trim().ToLowerInvariant()) })
                if ($ConsoleSourcesReachable.Count -eq 0) {
                    Write-Host ''
                    Write-Info 'Checkpoint reports every system was already copied for this migrate plan.'
                    Remove-GpRunCheckpointSilently -CheckpointLiteralPath $checkpointPath | Out-Null
                    Invoke-OutputFlush
                    try {
                        Read-Host 'Press Enter to restart the script'
                    }
                    catch { }
                    Invoke-GamePopulatorScriptRestart
                }
                $resumeSucceededGlob = $true
                Write-Info ('Resuming migrate run {0} ({1} system(s) pending).' -f $checkpointRunGuid, $ConsoleSourcesReachable.Count)
            }
        }
    }

    if ($structuredRunLog) {
        $logTsGp = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $gpStructuredNdjsonLiteralPathForRun = Join-Path $logsDir ('run-{0}.ndjson' -f $logTsGp)
        $script:GamePopulatorStructuredNdjsonLiteralPath = $gpStructuredNdjsonLiteralPathForRun
        $script:GpStructuredRunBasics = [ordered]@{ runId = [string]$checkpointRunGuid; script = $script:ScriptName; scriptVersion = [string]$script:ScriptVersion }
        Invoke-GpWriteStructuredNdjson -StructuredLogLiteralPath $gpStructuredNdjsonLiteralPathForRun -RunBasics $script:GpStructuredRunBasics -Evt 'run_start' -Data @{
            destinationCanonical     = [string]$destinationCanonicalForRun
            plannedFingerprintSha256 = [string]$plannedFingerprintHexForRun
            organizeRegions          = [bool]$organizeRegions
            resumed                  = [bool]$resumeSucceededGlob
            copyInvokedViaParameter  = [bool]$copyInvokedViaParameter
            reachableConsoleCount    = @(@($ConsoleSourcesReachable)).Count
        }
    }
    else {
        $gpStructuredNdjsonLiteralPathForRun = ''
        $script:GamePopulatorStructuredNdjsonLiteralPath = $null
        $script:GpStructuredRunBasics = $null
    }
}
elseif (-not ($doProcessing -and $script:CustomRunActive)) {
    # Copy pipeline not orchestrated (cleanup-only menu or migrate custom run paths); keep structured NDJSON off.
    $script:GamePopulatorStructuredNdjsonLiteralPath = $null
    $script:GpStructuredRunBasics = $null
}

$script:totalBytes = 0L
$script:totalFiles = 0
$script:consoleSummaries = New-Object System.Collections.Generic.List[object]
$script:regionTotals = @{}
$overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:organizeElapsed = [TimeSpan]::Zero
$script:didOrganizeExisting = $false

if ($doProcessing) {
    $gpCheckpointAccumulator = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($bk in @($gpResumeBootstrapCompleted)) {
        [void]$gpCheckpointAccumulator.Add(([string]$bk).Trim().ToLowerInvariant())
    }

    $organizeTotalElapsed = [TimeSpan]::Zero
    $organizeTargets = @()
    if (-not $script:CustomRunActive) {
        $organizePathSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($src in $ConsoleSourcesReachable) {
            if (-not $src.Name) { continue }
            $consoleKey = $src.Name.ToLowerInvariant()
            if (-not $consoleNameMap.ContainsKey($consoleKey)) { continue }
            $shortName = $consoleNameMap[$consoleKey]
            $base = Get-DestinationPathForConsoleSource -DestinationRoot $DestinationRoot -ConsoleKey $consoleKey -ShortName $shortName
            if (Test-Path -LiteralPath $base -PathType Container) {
                $pk = [System.IO.Path]::GetFullPath($base).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).ToLowerInvariant()
                if ($organizePathSeen.Add($pk)) {
                    $organizeTargets += @(@{ Name = $src.Name; Path = $base })
                }
            }
        }
    }
    elseif ($script:CustomRunOrganizeExisting) {
        if (Test-Path -LiteralPath $DestinationRoot -PathType Container) {
            $organizeTargets = @(@{ Name = 'Custom run'; Path = $DestinationRoot })
        }
    }
    $organizeTotal = $organizeTargets.Count
    if ($organizeTotal -gt 0) { $script:didOrganizeExisting = $true }
    if ($organizeTotal -gt 0) {
        if ($script:CustomRunActive) {
            Write-Host 'Organizing files already on destination (custom run folder; can take a while on large folders)...' -ForegroundColor DarkGray
        }
        else {
            Write-Host 'Organizing files already on destination (layout / region rules; can take a while on large folders)...' -ForegroundColor DarkGray
        }
        Invoke-OutputFlush
    }
    foreach ($target in $organizeTargets) {
        Invoke-GpWriteStructuredNdjson -StructuredLogLiteralPath $gpStructuredNdjsonLiteralPathForRun -RunBasics $script:GpStructuredRunBasics -Evt 'organize_destination_start' -Data @{
            console         = [string]$target.Name
            folderDisplay   = (Format-PathForDisplay ([string]$target.Path))
            organizeRegions = [bool]$organizeRegions
        }
        $consoleOrganizeTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $script:organizeLastTick = @{}
        Update-OrganizeProgress -ConsoleName $target.Name -Stopwatch $consoleOrganizeTimer
        if ($organizeRegions) {
            # BIN/CUE must always stay in per-game folders (Console/Region/GameName), never on region or console root.
            Move-RegionInFolder -FolderPath $target.Path -ProgressConsoleName $target.Name -ProgressStopwatch $consoleOrganizeTimer -AllowBinCue:$true
        }
        else {
            # When flattening (no region), BIN/CUE must always stay in per-game folders; never move them to console root.
            Convert-ConsoleFolder -FolderPath $target.Path -AllowBinCue:$true -ProgressConsoleName $target.Name -ProgressStopwatch $consoleOrganizeTimer
        }
        if ($maxFilesPerFolder -gt 0) {
            Invoke-Everdrive256FolderChunking -RootPath $target.Path -MaxFiles $maxFilesPerFolder
        }
        $organizeKey = $target.Name.ToLowerInvariant()
        if ($organizeKey -eq 'nintendo game boy' -or $organizeKey -eq 'nintendo game boy color') {
            Remove-SgbEnhancedFilesUnderFolder -FolderPath $target.Path
        }
        $consoleOrganizeTimer.Stop()
        $organizeTotalElapsed = $organizeTotalElapsed.Add($consoleOrganizeTimer.Elapsed)
        Write-OrganizeProgressLine -ConsoleName $target.Name -Elapsed $consoleOrganizeTimer.Elapsed
        Invoke-GpWriteStructuredNdjson -StructuredLogLiteralPath $gpStructuredNdjsonLiteralPathForRun -RunBasics $script:GpStructuredRunBasics -Evt 'organize_destination_done' -Data @{
            console                    = [string]$target.Name
            elapsedMillisecondsRounded = ([math]::Round($consoleOrganizeTimer.Elapsed.TotalMilliseconds))
            organizeRegions            = [bool]$organizeRegions
        }
        Write-Host ""
    }
    $script:organizeElapsed = $organizeTotalElapsed

    foreach ($console in $ConsoleSourcesReachable) {
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
            Write-Host 'libraries\*-names.json (console, hacks, trans, addons)' -ForegroundColor White
            $script:errors.Add("Console short name missing for '$name' in merged names JSON (console-, hacks-, trans-, addons-names).") | Out-Null
            continue
        }
        $displayName = if ($consoleDisplayNameMap[$consoleKey]) { $consoleDisplayNameMap[$consoleKey] } else { $name }

        $drivePath = $null
        try {
            $drivePath = New-ShareDrive -Root $sourceRoot -User $user -Password $pass
        }
        catch {
            $rawErr = $_.Exception.Message
            $hint = Expand-SmbConnectErrorHint -RawMessage $rawErr -UncPath $sourceRoot
            $detail = $rawErr
            if ($hint) { $detail = $detail + ' ' + $hint }
            Add-Error "Failed to connect to share for ${name}: $sourceRoot ($detail)"
            continue
        }

        try {
            Invoke-GpWriteStructuredNdjson -StructuredLogLiteralPath $gpStructuredNdjsonLiteralPathForRun -RunBasics $script:GpStructuredRunBasics -Evt 'console_share_connected' -Data @{
                consoleKey         = [string]$consoleKey
                displayName        = [string]$displayName
                sourceRootDisplay  = Format-PathForDisplay (($sourceRoot.ToString()).Trim())
                destinationDisplay = Format-PathForDisplay (($DestinationRoot.ToString()))
            }

            if ($script:lastLineLength -gt 0) {
                Write-Host ""
                $script:lastLineLength = 0
            }
            if (-not ($script:CustomRunActive -and $consoleKey -eq 'custom run')) {
                Write-Host "Console: $displayName" -ForegroundColor DarkCyan
            }
            Write-Host "Scanning files on source library (recursive scan of every file; large libraries can take awhile)..." -ForegroundColor DarkGray
            Invoke-OutputFlush
            Write-ScriptDiag "Get-ChildItem -Recurse -File on source (enumerates entire tree)"

            $fileItems = @(Get-ChildItem -LiteralPath $drivePath -Force -Recurse -File -ErrorAction Stop)

            $nFilesStr = $fileItems.Count.ToString('N0', [System.Globalization.CultureInfo]::GetCultureInfo('en-US'))
            Write-Host "Found " -NoNewline -ForegroundColor DarkGray
            Write-Host $nFilesStr -NoNewline -ForegroundColor White
            Write-Host " file(s) on source." -ForegroundColor DarkGray
            Invoke-OutputFlush

            if ($fileItems.Count -eq 0) {
                Write-Warn ("Source contains no files: {0}" -f $sourceRoot)
                Remove-ShareDrive -DrivePath $drivePath
                continue
            }

            $consoleDest = if ($script:CustomRunActive -and $consoleKey -eq 'custom run') {
                $DestinationRoot
            }
            else {
                Get-DestinationPathForConsoleSource -DestinationRoot $DestinationRoot -ConsoleKey $consoleKey -ShortName $shortName
            }

            $isSgbConsole = (
                $consoleKey -eq 'nintendo super game boy (gb original)' -or
                $consoleKey -eq 'nintendo super game boy (gbc original)')
            $isGbOrGbc = ($consoleKey -eq 'nintendo game boy' -or $consoleKey -eq 'nintendo game boy color')

            Write-Host "Preparing the destination console folder and building a filename index." -ForegroundColor DarkGray
            Invoke-OutputFlush
            Invoke-ExistingDestination -FolderPath $consoleDest -Organize $organizeRegions -ArchiveExtensions $archiveExts
            if ($isGbOrGbc) {
                Remove-SgbEnhancedFilesUnderFolder -FolderPath $consoleDest
            }
            $destNameSet = Get-DestinationFileNameSet -FolderPath $consoleDest
            $destNameSet = if ($destNameSet) { Convert-NameSet -NameSet $destNameSet } else { New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }

            # Timer starts after source listing and destination prep so progress lines reflect copy work, not full-tree scans.
            $script:currentConsoleStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            $createdConsoleDir = $false
            $consoleFiles = 0
            $consoleBytes = 0L
            $processedDirs = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            $consoleRegionCounts = @{}

            $allowedExtSet = $consoleExtensionsMap[$consoleKey]
            if (-not $allowedExtSet) { $allowedExtSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase); $allowedExtSet.Add('.rom') | Out-Null }

            $useZipDestForNonOptical = (($script:GpMigrateAssetMode -eq 'zipDest') -and -not ($consoleOpticalSet.Contains($displayName)))

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
                if (-not $isArchive) {
                    try {
                        $isArchive = Test-ArchiveFile -Path $item.FullName
                    }
                    catch {
                        $isArchive = $false
                    }
                }
                if ($isArchive) {
                    $archiveLookup.Add($item.FullName) | Out-Null
                    $archiveItems += $item
                }
                elseif ($allowedExtSet.Contains($ext)) {
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
                    $isArchiveItem = $archiveLookup.Contains($item.FullName)
                    if ($isSgbConsole -and -not $isArchiveItem -and $ext -ne '.chd') {
                        if (-not (Test-IncludeSgbEnhancedForConsole -Name $item.Name -Extension $ext -ConsoleKeyLower $consoleKey)) { continue }
                    }
                    if ($isGbOrGbc -and -not $isArchiveItem -and $ext -ne '.chd') {
                        if (Test-IsSgbEnhancedRomName -Name $item.Name) { continue }
                    }
                    if ($ext -eq '.chd') {
                        if (-not $allowedExtSet.Contains('.chd')) { continue }
                        $chdRoot = Get-RegionDestRoot -BasePath $consoleDest -Name $item.Name -Organize $organizeRegions
                        $destFile = Join-Path $chdRoot $item.Name
                        if ($destNameSet -and $destNameSet.Contains($item.Name)) { continue }
                        if (Test-Path -LiteralPath $destFile) { continue }

                        if (-not (Test-Path -LiteralPath $consoleDest -PathType Container)) {
                            New-Item -Path $consoleDest -ItemType Directory -Force | Out-Null
                        }
                        if (-not (Test-Path -LiteralPath $chdRoot)) {
                            New-Item -Path $chdRoot -ItemType Directory -Force | Out-Null
                        }

                        Write-ProgressLine -Action "Copying CHD" -ItemName $item.Name -Bytes $item.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                        Copy-Item -LiteralPath $item.FullName -Destination $destFile
                        Add-NameToSet -Set ([ref]$destNameSet) -Name $item.Name
                        $script:totalBytes += $item.Length
                        $script:totalFiles += 1
                        $consoleBytes += $item.Length
                        $consoleFiles += 1
                        Add-RegionCount -Counts $consoleRegionCounts -Name $item.Name -Organize $organizeRegions | Out-Null
                        Add-RegionCount -Counts $script:regionTotals -Name $item.Name -Organize $organizeRegions | Out-Null
                        continue
                    }

                    $isArchive = $archiveLookup.Contains($item.FullName)

                    if ($useZipDestForNonOptical -and (-not $isArchive)) {
                        if (-not (Test-Path -LiteralPath $consoleDest -PathType Container)) {
                            New-Item -Path $consoleDest -ItemType Directory -Force | Out-Null
                        }
                        $flatRootLooseZ = Get-RegionDestRoot -BasePath $consoleDest -Name $item.Name -Organize $organizeRegions
                        if (-not (Test-Path -LiteralPath $flatRootLooseZ)) {
                            New-Item -Path $flatRootLooseZ -ItemType Directory -Force | Out-Null
                        }
                        $bundleZipName = (($item.BaseName) + '.zip')
                        if ($destNameSet -and $destNameSet.Contains($bundleZipName)) { continue }
                        $bundleZipPath = Join-Path $flatRootLooseZ $bundleZipName
                        if (Test-Path -LiteralPath $bundleZipPath) { continue }
                        Initialize-7z
                        Invoke-Gp7zCompressSingleFileToNewZipMax -SourceFileLiteralPath $item.FullName -DestinationZipLiteralPath $bundleZipPath -ProgressName $bundleZipName
                        $bundleLen = (Get-Item -LiteralPath $bundleZipPath).Length
                        Write-ProgressLine -Action "Compressed to ZIP" -ItemName $bundleZipName -Bytes $bundleLen -Elapsed $script:currentConsoleStopwatch.Elapsed
                        Add-NameToSet -Set ([ref]$destNameSet) -Name $bundleZipName
                        $script:totalBytes += $bundleLen
                        $script:totalFiles += 1
                        $consoleBytes += $bundleLen
                        $consoleFiles += 1
                        Add-RegionCount -Counts $consoleRegionCounts -Name $bundleZipName -Organize $organizeRegions | Out-Null
                        Add-RegionCount -Counts $script:regionTotals -Name $bundleZipName -Organize $organizeRegions | Out-Null
                        continue
                    }

                    if ($useZipDestForNonOptical -and $isArchive -and ($ext -eq '.zip')) {
                        if (-not (Test-Path -LiteralPath $consoleDest -PathType Container)) {
                            New-Item -Path $consoleDest -ItemType Directory -Force | Out-Null
                        }
                        $flatRootSrcZip = Get-RegionDestRoot -BasePath $consoleDest -Name $item.Name -Organize $organizeRegions
                        if (-not (Test-Path -LiteralPath $flatRootSrcZip)) {
                            New-Item -Path $flatRootSrcZip -ItemType Directory -Force | Out-Null
                        }
                        if ($destNameSet -and $destNameSet.Contains($item.Name)) { continue }
                        $copyZp = Copy-ItemsFlatNoOverwrite -Items @($item) -DestRoot $flatRootSrcZip
                        if ($copyZp.Files -gt 0) {
                            Write-ProgressLine -Action "Copying ZIP bundle" -ItemName $item.Name -Bytes $item.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                            $script:totalBytes += $copyZp.Bytes
                            $script:totalFiles += $copyZp.Files
                            $consoleBytes += $copyZp.Bytes
                            $consoleFiles += $copyZp.Files
                            Add-NameToSet -Set ([ref]$destNameSet) -Name $item.Name
                            Add-RegionCount -Counts $consoleRegionCounts -Name $item.Name -Organize $organizeRegions | Out-Null
                            Add-RegionCount -Counts $script:regionTotals -Name $item.Name -Organize $organizeRegions | Out-Null
                        }
                        continue
                    }

                    if ($useZipDestForNonOptical -and $isArchive -and ($ext -ne '.zip')) {
                        $outZipName = (($item.BaseName) + '.zip')
                        if ($destNameSet -and $destNameSet.Contains($outZipName)) { continue }
                        if (-not (Test-Path -LiteralPath $consoleDest -PathType Container)) {
                            New-Item -Path $consoleDest -ItemType Directory -Force | Out-Null
                        }
                        $flatRootRepack = Get-RegionDestRoot -BasePath $consoleDest -Name $item.Name -Organize $organizeRegions
                        if (-not (Test-Path -LiteralPath $flatRootRepack)) {
                            New-Item -Path $flatRootRepack -ItemType Directory -Force | Out-Null
                        }
                        $outZipPath = Join-Path $flatRootRepack $outZipName
                        if (Test-Path -LiteralPath $outZipPath) { continue }
                        Initialize-7z
                        $tempRepack = Join-Path $TempRoot ([Guid]::NewGuid().ToString('N'))
                        New-Item -Path $tempRepack -ItemType Directory -Force | Out-Null
                        try {
                            Invoke-7z -Arguments @('x', '-y', '-bso1', '-bse1', '-bsp1', "-o$tempRepack", $item.FullName) -ProgressLabel "Extracting" -ProgressName $item.Name
                            $outZipAbs = [System.IO.Path]::GetFullPath($outZipPath)
                            Invoke-Gp7zCompressFlatWorkingDirToNewZipMax -WorkingLiteralDirectoryWithFiles $tempRepack -DestinationZipLiteralPath $outZipAbs -ProgressName $outZipName
                            $outLen = (Get-Item -LiteralPath $outZipAbs).Length
                            Write-ProgressLine -Action "Repacked to ZIP" -ItemName $outZipName -Bytes $outLen -Elapsed $script:currentConsoleStopwatch.Elapsed
                            Add-NameToSet -Set ([ref]$destNameSet) -Name $outZipName
                            $script:totalBytes += $outLen
                            $script:totalFiles += 1
                            $consoleBytes += $outLen
                            $consoleFiles += 1
                            Add-RegionCount -Counts $consoleRegionCounts -Name $outZipName -Organize $organizeRegions | Out-Null
                            Add-RegionCount -Counts $script:regionTotals -Name $outZipName -Organize $organizeRegions | Out-Null
                        }
                        finally {
                            if (Test-Path -LiteralPath $tempRepack) {
                                Remove-Item -LiteralPath $tempRepack -Recurse -Force
                            }
                        }
                        continue
                    }

                    if ($isArchive) {
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
                            if (-not (Test-Path -LiteralPath $consoleDest -PathType Container)) {
                                New-Item -Path $consoleDest -ItemType Directory -Force | Out-Null
                            }

                            $allExtractedFiles = @(Get-ChildItem -LiteralPath $tempExtract -Recurse -File -ErrorAction SilentlyContinue)
                            $hasBin = @($allExtractedFiles | Where-Object { $_.Extension -ieq '.bin' }).Count -gt 0
                            $hasCue = @($allExtractedFiles | Where-Object { $_.Extension -ieq '.cue' }).Count -gt 0
                            $isBinCueArchive = ($hasBin -and $hasCue)

                            if ($isBinCueArchive) {
                                $gameFolderName = $item.BaseName
                                $region = Get-RegionFromFiles -Files $allExtractedFiles
                                $archiveRoot = Get-RegionDestRootFromRegion -BasePath $consoleDest -Region $region -Organize $organizeRegions
                                if (-not (Test-Path -LiteralPath $archiveRoot)) {
                                    New-Item -Path $archiveRoot -ItemType Directory -Force | Out-Null
                                }
                                $destGameFolder = Join-Path $archiveRoot $gameFolderName
                                $nameSet = if ($destNameSet) { $destNameSet } else { (New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)) }
                                if (-not $nameSet) { $nameSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                                $filteredItems = @()
                                foreach ($extracted in $allExtractedFiles) {
                                    $extractedName = $extracted.Name
                                    if (-not $extractedName) { continue }
                                    if ($isGbOrGbc -and (Test-IsSgbEnhancedRomName -Name $extractedName)) { continue }
                                    if ($isSgbConsole -and -not (Test-IncludeSgbEnhancedForConsole -Name $extractedName -Extension $extracted.Extension -ConsoleKeyLower $consoleKey)) { continue }
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
                                $destNameSet = if ($destNameSet) { Convert-NameSet -NameSet $destNameSet } else { New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                                foreach ($file in $filteredItems) {
                                    Add-NameToSet -Set ([ref]$destNameSet) -Name $file.Name
                                    Add-RegionCount -Counts $consoleRegionCounts -Name $file.Name -Organize $organizeRegions | Out-Null
                                    Add-RegionCount -Counts $script:regionTotals -Name $file.Name -Organize $organizeRegions | Out-Null
                                }
                            }
                            else {
                                $extractedSize = Get-DirectorySize -Path $tempExtract
                                Write-ProgressLine -Action "Copying extracted" -ItemName $item.BaseName -Bytes $extractedSize -Elapsed $script:currentConsoleStopwatch.Elapsed
                                $region = Get-RegionFromFiles -Files $extractedItems
                                $archiveRoot = Get-RegionDestRootFromRegion -BasePath $consoleDest -Region $region -Organize $organizeRegions
                                if (-not (Test-Path -LiteralPath $archiveRoot)) {
                                    New-Item -Path $archiveRoot -ItemType Directory -Force | Out-Null
                                }
                                $nameSet = if ($destNameSet) { $destNameSet } else { (New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)) }
                                if (-not $nameSet) { $nameSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                                $filteredItems = @()
                                foreach ($extracted in $extractedItems) {
                                    if (-not $extracted -or $extracted.PSIsContainer) { continue }
                                    $extractedName = $extracted.Name
                                    if (-not $extractedName) { continue }
                                    if ($isGbOrGbc -and (Test-IsSgbEnhancedRomName -Name $extractedName)) { continue }
                                    if ($isSgbConsole -and -not (Test-IncludeSgbEnhancedForConsole -Name $extractedName -Extension $extracted.Extension -ConsoleKeyLower $consoleKey)) { continue }
                                    if ($nameSet -and $nameSet.Contains($extractedName)) { continue }
                                    $filteredItems += $extracted
                                }
                                if (-not $filteredItems -or $filteredItems.Count -eq 0) { continue }
                                $copyResult = Copy-ItemsFlatNoOverwrite -Items $filteredItems -DestRoot $archiveRoot
                                $script:totalBytes += $copyResult.Bytes
                                $script:totalFiles += $copyResult.Files
                                $consoleBytes += $copyResult.Bytes
                                $consoleFiles += $copyResult.Files
                                $destNameSet = if ($destNameSet) { Convert-NameSet -NameSet $destNameSet } else { New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase) }
                                foreach ($file in $filteredItems) {
                                    Add-NameToSet -Set ([ref]$destNameSet) -Name $file.Name
                                    Add-RegionCount -Counts $consoleRegionCounts -Name $file.Name -Organize $organizeRegions | Out-Null
                                    Add-RegionCount -Counts $script:regionTotals -Name $file.Name -Organize $organizeRegions | Out-Null
                                }
                            }
                        }
                        finally {
                            if (Test-Path -LiteralPath $tempExtract) {
                                Remove-Item -LiteralPath $tempExtract -Recurse -Force
                            }
                        }
                        continue
                    }

                    if (-not (Test-Path -LiteralPath $consoleDest -PathType Container)) {
                        New-Item -Path $consoleDest -ItemType Directory -Force | Out-Null
                    }
                    $flatRoot = Get-RegionDestRoot -BasePath $consoleDest -Name $item.Name -Organize $organizeRegions
                    if (-not (Test-Path -LiteralPath $flatRoot)) {
                        New-Item -Path $flatRoot -ItemType Directory -Force | Out-Null
                    }
                    if ($destNameSet -and $destNameSet.Contains($item.Name)) { continue }
                    $copyResult = Copy-ItemsFlatNoOverwrite -Items @($item) -DestRoot $flatRoot
                    if ($copyResult.Files -gt 0) {
                        Write-ProgressLine -Action "Copying" -ItemName $item.Name -Bytes $item.Length -Elapsed $script:currentConsoleStopwatch.Elapsed
                        $script:totalBytes += $copyResult.Bytes
                        $script:totalFiles += $copyResult.Files
                        $consoleBytes += $copyResult.Bytes
                        $consoleFiles += $copyResult.Files
                        Add-NameToSet -Set ([ref]$destNameSet) -Name $item.Name
                        Add-RegionCount -Counts $consoleRegionCounts -Name $item.Name -Organize $organizeRegions | Out-Null
                        Add-RegionCount -Counts $script:regionTotals -Name $item.Name -Organize $organizeRegions | Out-Null
                    }
                }
                catch {
                    $lineInfo = $_.InvocationInfo.ScriptLineNumber
                    $msg = Get-CopyErrorMessage -ExceptionMessage $_.Exception.Message
                    Add-Error ("{0}: {1} (line {2})" -f $item.Name, $msg, $lineInfo)
                }
            }

            if ($maxFilesPerFolder -gt 0 -and -not ($script:CustomRunActive -and $consoleKey -eq 'custom run')) {
                Invoke-Everdrive256FolderChunking -RootPath $consoleDest -MaxFiles $maxFilesPerFolder
            }

            if ($script:lastLineLength -gt 0) {
                Write-Host ""
                $script:lastLineLength = 0
            }
            if ($script:currentConsoleStopwatch) {
                $script:currentConsoleStopwatch.Stop()
                $elapsedMsRounded = ([math]::Round($script:currentConsoleStopwatch.Elapsed.TotalMilliseconds))
                $script:consoleSummaries.Add(@{
                        Name    = $displayName
                        Elapsed = $script:currentConsoleStopwatch.Elapsed
                        Files   = $consoleFiles
                        Bytes   = $consoleBytes
                        Regions = $consoleRegionCounts
                    }) | Out-Null
                Invoke-GpWriteStructuredNdjson -StructuredLogLiteralPath $gpStructuredNdjsonLiteralPathForRun -RunBasics $script:GpStructuredRunBasics -Evt 'console_copy_done' -Data @{
                    consoleKey                 = [string]$consoleKey
                    displayName                = [string]$displayName
                    bytesCopied                = [long]$consoleBytes
                    filesCopied                = [long]$consoleFiles
                    elapsedMillisecondsRounded = [long]$elapsedMsRounded
                    destinationFolderDisplay   = (Format-PathForDisplay (($consoleDest.ToString())))
                }
                if ($useRunCheckpointSetting -and $runOrchestrationEligible -and (-not [string]::IsNullOrWhiteSpace($plannedFingerprintHexForRun))) {
                    [void]$gpCheckpointAccumulator.Add([string]$consoleKey)
                    $completedArrCk = @(($gpCheckpointAccumulator.ToArray()) | Sort-Object)
                    Save-GpRunCheckpointSilently -CheckpointLiteralPath $checkpointPath -State @{
                        schemaVersion            = 1
                        runId                    = [string]$checkpointRunGuid
                        plannedFingerprintSha256 = [string]$plannedFingerprintHexForRun
                        destinationCanonical     = [string]$destinationCanonicalForRun
                        organizeRegions          = [bool]$organizeRegions
                        copyInvokedViaParameter  = [bool]$copyInvokedViaParameter
                        completedConsoleKeys     = @($completedArrCk)
                    }
                }

                $script:currentConsoleStopwatch = $null
            }
            Write-Host ""
        }
        catch {
            Add-Error ("Failed to read source {0}: {1}" -f $sourceRoot, $_.Exception.Message)
        }
        finally {
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

$runFinishedErrorCountNdjson = 0
if ($null -ne $script:errors) {
    try {
        $runFinishedErrorCountNdjson = [int]$script:errors.Count
    }
    catch {
        $runFinishedErrorCountNdjson = 0
    }
}
$runFinishedConsoleSummariesCountNdjson = 0
if ($null -ne $script:consoleSummaries) {
    try {
        $runFinishedConsoleSummariesCountNdjson = [int]$script:consoleSummaries.Count
    }
    catch {
        $runFinishedConsoleSummariesCountNdjson = 0
    }
}

Invoke-GpWriteStructuredNdjson -StructuredLogLiteralPath $gpStructuredNdjsonLiteralPathForRun -RunBasics $script:GpStructuredRunBasics -Evt 'run_finished' -Data @{
    organizedExisting        = [bool]$script:didOrganizeExisting
    totalFilesCopied         = [long]$script:totalFiles
    totalBytesCopied         = [long]$script:totalBytes
    totalElapsedMilliseconds = ([math]::Round($overallStopwatch.Elapsed.TotalMilliseconds))
    errorCount               = $runFinishedErrorCountNdjson
    consolesSummarizedCount  = $runFinishedConsoleSummariesCountNdjson
}

if ($useRunCheckpointSetting -and $runOrchestrationEligible -and (-not [string]::IsNullOrWhiteSpace($plannedFingerprintHexForRun)) -and ($script:errors.Count -eq 0)) {
    Remove-GpRunCheckpointSilently -CheckpointLiteralPath $checkpointPath | Out-Null
}

$cleanupFilesRemoved = 0
$cleanupFoldersRemoved = 0
$cleanupSkippedDestinationUnreachable = $false
# Destination check: remove any files not in the console's allowed extensions list (.rom and .zip always allowed).
# Scans: each games\<ShortName>[\SubDir] from merged names JSON (including music players from addons-names), and loose files directly under games\ (union of all configured extensions).
if ($doCleanup) {
    $cleanupStatusJob = $null
    if ($script:RestartAfterInteractiveCleanup) {
        $cleanupStatusJob = Start-CleanupActivityElapsedDisplay
    }
    try {
        if (-not (Test-GamePopulatorCleanupDestinationAccessible -DestinationRoot $DestinationRoot)) {
            $cleanupSkippedDestinationUnreachable = $true
            Write-Info " "
            Write-Warn "Cleanup was not run. The destination is not available."
            Write-Warn "The drive letter isn't mounted or the network share is offline."
            Write-Warn "Connect the destination and try again."
        }
        else {
            Write-Info " "
            Write-Host '[i] Cleanup keeps only allowed extensions per system folder; files loose not in system folders are always removed.' -ForegroundColor DarkYellow
            if ($script:CustomRunActive -and $consoleExtensionsMap.ContainsKey('custom run') -and $consoleExtensionsMap['custom run']) {
                $customAllowed = @($consoleExtensionsMap['custom run'])
                $fr = Remove-DestinationFilesNotMatchingExtensions -FolderPath $DestinationRoot -AllowedExtensions $customAllowed
                $cleanupFilesRemoved += $fr.FilesRemoved
            }
            elseif (-not $script:CustomRunActive) {
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
                        Write-Warn "Console '$($entry.ShortName)' has no Extensions in merged names JSON; skipping cleanup for that folder (no files removed)."
                        continue
                    }
                    $fr = Remove-DestinationFilesNotMatchingExtensions -FolderPath $consoleDestPath -AllowedExtensions $extList
                    $cleanupFilesRemoved += $fr.FilesRemoved
                }
                $frGamesRootStray = Remove-DestinationFilesNotMatchingExtensions -FolderPath $DestinationRoot -TopLevelOnly -DeleteAllFiles
                $cleanupFilesRemoved += $frGamesRootStray.FilesRemoved
            }
            $er = Remove-EmptyFolders -RootPath $DestinationRoot
            $cleanupFoldersRemoved = $er.FoldersRemoved
        }
    }
    finally {
        if ($cleanupStatusJob) {
            Stop-GamePopulatorBackgroundStatusDisplay -Job $cleanupStatusJob
        }
    }
}

$suppressCleanupUnreachableRunSummary = ($cleanupOnly -and $cleanupSkippedDestinationUnreachable)

if (-not $suppressCleanupUnreachableRunSummary) {

    $logsDir = Join-Path $scriptRoot 'logs'
    if (-not (Test-Path -LiteralPath $logsDir -PathType Container)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }
    $runSummaryLogLines = [System.Collections.Generic.List[string]]::new()
    $runSummaryLogLines.Add("Game Populator run summary — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $runSummaryLogLines.Add('')

    $runSummaryLogLines.Add('===[ Completion Summary ]===')
    Write-Summary "===[ Completion Summary ]==="
    $runSummaryLogLines.Add(("     Destination path:    {0}" -f $destinationPathDisplay))
    Write-Host "     Destination path:    " -NoNewline -ForegroundColor DarkCyan
    Write-Host $destinationPathDisplay -ForegroundColor White
    $elapsedTotal = Format-Elapsed $overallStopwatch.Elapsed
    $runSummaryLogLines.Add(("     Total time:          {0}" -f $elapsedTotal))
    Write-Host "     Total time:          " -NoNewline -ForegroundColor DarkCyan
    Write-Host $elapsedTotal -ForegroundColor White
    if ($doCleanup) {
        if ($cleanupSkippedDestinationUnreachable) {
            $runSummaryLogLines.Add('     Cleanup:             skipped (destination not available)')
            Write-Host "     Cleanup:             " -NoNewline -ForegroundColor DarkCyan
            Write-Host "skipped (destination not available)" -ForegroundColor DarkYellow
        }
        else {
            $runSummaryLogLines.Add(("     Files removed:       {0}" -f $cleanupFilesRemoved.ToString('N0')))
            $runSummaryLogLines.Add(("     Empty folders:       {0}" -f $cleanupFoldersRemoved.ToString('N0')))
            Write-Host "     Files removed:       " -NoNewline -ForegroundColor DarkCyan
            Write-Host ($cleanupFilesRemoved.ToString('N0')) -ForegroundColor White
            Write-Host "     Empty folders:       " -NoNewline -ForegroundColor DarkCyan
            Write-Host ($cleanupFoldersRemoved.ToString('N0')) -ForegroundColor White
        }
    }
    if (-not $cleanupOnly) {
        if ($script:didOrganizeExisting) {
            $orgEl = Format-Elapsed $script:organizeElapsed
            $runSummaryLogLines.Add(("     Organize time:       {0}" -f $orgEl))
            Write-Host "     Organize time:       " -NoNewline -ForegroundColor DarkCyan
            Write-Host $orgEl -ForegroundColor White
        }
        $runSummaryLogLines.Add(("     Files copied:        {0}" -f $script:totalFiles.ToString('N0')))
        $runSummaryLogLines.Add(("     Total size copied:   {0}" -f (Format-Size $script:totalBytes)))
        Write-Host "     Files copied:        " -NoNewline -ForegroundColor DarkCyan
        Write-Host ($script:totalFiles.ToString('N0')) -ForegroundColor White
        Write-Host "     Total size copied:   " -NoNewline -ForegroundColor DarkCyan
        Write-Host (Format-Size $script:totalBytes) -ForegroundColor White
        if ($script:errors.Count -gt 0) {
            $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
            $logFileName = "errorlog-$timestamp.log"
            $logPath = Join-Path $logsDir $logFileName
            $logStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            $header = "[$logStamp] $($script:errors.Count) error(s) occurred."
            $content = @($header) + $script:errors
            try {
                $content | Set-Content -Path $logPath -Encoding UTF8
                $runSummaryLogLines.Add(("     Errors:              {0} (log: {1})" -f $script:errors.Count.ToString('N0'), $logFileName))
                Write-Host "     An error log was written with " -NoNewline -ForegroundColor DarkYellow
                Write-Host ($script:errors.Count.ToString('N0')) -NoNewline -ForegroundColor DarkYellow
                Write-Host " error(s): " -NoNewline -ForegroundColor DarkYellow
                Write-Host $logFileName -ForegroundColor Red
            }
            catch {
                Write-Host "Failed to write error log: " -NoNewline -ForegroundColor Yellow
                Write-Host ([System.IO.Path]::GetFileName($logPath)) -ForegroundColor White
                $runSummaryLogLines.Add(("     Errors:              {0} (log write failed)" -f $script:errors.Count.ToString('N0')))
                Write-Host "     Errors:              " -NoNewline -ForegroundColor Red
                Write-Host ($script:errors.Count.ToString('N0')) -NoNewline -ForegroundColor Red
                Write-Host " (log write failed)" -ForegroundColor Red
            }
        }
    }
    $runSummaryLogLines.Add('')
    Write-Host ""

    if ($script:consoleSummaries.Count -gt 0) {
        $runSummaryLogLines.Add('===[ Console Summary ]===')
        Write-Host "===[ Console Summary ]===" -ForegroundColor DarkCyan
        foreach ($summary in $script:consoleSummaries) {
            $csLine = "{0} completed in {1} copying {2} files using {3}." -f $summary.Name, (Format-Elapsed $summary.Elapsed), $summary.Files.ToString('N0'), (Format-Size $summary.Bytes)
            $runSummaryLogLines.Add($csLine)
            Write-Host ("{0} " -f $summary.Name) -NoNewline -ForegroundColor White
            Write-Host ("completed in {0} copying " -f (Format-Elapsed $summary.Elapsed)) -NoNewline -ForegroundColor White
            Write-Host ($summary.Files.ToString('N0')) -NoNewline -ForegroundColor DarkCyan
            Write-Host " files using " -NoNewline -ForegroundColor White
            Write-Host (Format-Size $summary.Bytes) -NoNewline -ForegroundColor DarkCyan
            Write-Host "." -ForegroundColor White
        }
        $runSummaryLogLines.Add('')
        Write-Host ""
    }

    if ($organizeRegions) {
        $regionTotalsFromDest = @{}
        $regionSummaryShown = $false
        $regionUsCulture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
        $regionLineIndent = '    '
        # Pad labels so counts align (same style as Region Totals).
        $regionLabelColumn = 14
        $regionSummaryPathSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $consoleNames) {
            if (-not $entry.ShortName) { continue }
            $consoleDestPath = Join-Path $DestinationRoot $entry.ShortName
            if ($entry.PSObject.Properties['SubDir'] -and $entry.SubDir) {
                $consoleDestPath = Join-Path $consoleDestPath $entry.SubDir
            }
            $pathKey = [System.IO.Path]::GetFullPath($consoleDestPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).ToLowerInvariant()
            if (-not $regionSummaryPathSeen.Add($pathKey)) { continue }
            $regionCounts = Get-RegionCountsFromDestination -FolderPath $consoleDestPath
            if (-not $regionCounts -or $regionCounts.Count -eq 0) { continue }
            if (-not $regionSummaryShown) {
                $runSummaryLogLines.Add('===[ Region Summary ]===')
                Write-Host "===[ Region Summary ]===" -ForegroundColor DarkCyan
                $regionSummaryShown = $true
            }
            $displayName = if ($entry.Name) { $entry.Name } else { $entry.ShortName }
            $runSummaryLogLines.Add([string]$displayName)
            Write-Host $displayName -ForegroundColor White
            foreach ($key in (Get-OrderedRegionKeys -Keys $regionCounts.Keys)) {
                $regionLabel = ($key -replace '^\d+\s*-\s*', '')
                $countText = $regionCounts[$key].ToString('N0', $regionUsCulture)
                $rLine = $regionLineIndent + $regionLabel.PadRight($regionLabelColumn) + ' - ' + $countText
                $runSummaryLogLines.Add($rLine)
                Write-Host $rLine -ForegroundColor White
                if (-not $regionTotalsFromDest.ContainsKey($key)) { $regionTotalsFromDest[$key] = 0 }
                $regionTotalsFromDest[$key] += $regionCounts[$key]
            }
            $runSummaryLogLines.Add('')
            Write-Host ""
        }

        if ($regionTotalsFromDest.Count -gt 0) {
            $runSummaryLogLines.Add('===[ Region Totals ]===')
            Write-Host "===[ Region Totals ]===" -ForegroundColor DarkCyan
            foreach ($key in (Get-OrderedRegionKeys -Keys $regionTotalsFromDest.Keys)) {
                $regionLabel = ($key -replace '^\d+\s*-\s*', '')
                $countText = $regionTotalsFromDest[$key].ToString('N0', $regionUsCulture)
                $totLine = $regionLineIndent + $regionLabel.PadRight($regionLabelColumn) + ' - ' + $countText
                $runSummaryLogLines.Add($totLine)
                Write-Host $totLine -ForegroundColor White
            }
            $regionGrandTotal = [long]0
            foreach ($gk in $regionTotalsFromDest.Keys) {
                $regionGrandTotal += [long]$regionTotalsFromDest[$gk]
            }
            $grandLine = $regionLineIndent + 'Grand Total'.PadRight($regionLabelColumn) + ' - ' + $regionGrandTotal.ToString('N0', $regionUsCulture)
            $runSummaryLogLines.Add('')
            $runSummaryLogLines.Add($grandLine)
            Write-Host ""
            Write-Host $grandLine -ForegroundColor White
        }
    }

    $gamerunFileName = ('gamerun-{0}.log' -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
    $gamerunPath = Join-Path $logsDir $gamerunFileName
    try {
        $runSummaryLogLines | Set-Content -LiteralPath $gamerunPath -Encoding UTF8
        Write-Host ""
        Write-Host "Run summary log: " -NoNewline -ForegroundColor DarkCyan
        Write-Host $gamerunFileName -ForegroundColor White
        if (-not [string]::IsNullOrWhiteSpace($gpStructuredNdjsonLiteralPathForRun) -and (Test-Path -LiteralPath $gpStructuredNdjsonLiteralPathForRun -PathType Leaf)) {
            Write-Host "Structured NDJSON: " -NoNewline -ForegroundColor DarkCyan
            Write-Host ([System.IO.Path]::GetFileName($gpStructuredNdjsonLiteralPathForRun)) -ForegroundColor White
        }
    }
    catch {
        Write-Warn ("Could not write run summary log: {0}" -f $_.Exception.Message)
    }

} # end -not $suppressCleanupUnreachableRunSummary

if ($destCleanup) {
    Remove-PSDrive -Name $destCleanup -ErrorAction SilentlyContinue
}

if ($script:GpPostMigrateInteractiveRepeatKind -eq 'SingleSystem' -or $script:GpPostMigrateInteractiveRepeatKind -eq 'CustomRun') {
    Write-Host ""
    $againMsg = if ($script:GpPostMigrateInteractiveRepeatKind -eq 'SingleSystem') {
        'Run another single-system copy?'
    }
    else {
        'Run another custom destination copy?'
    }
    if (Read-YesNoDefaultNo $againMsg) {
        if ($script:GpPostMigrateInteractiveRepeatKind -eq 'SingleSystem') {
            Invoke-GamePopulatorScriptRestart -Intent @{ SingleSystemInteractive = $true }
        }
        else {
            Invoke-GamePopulatorScriptRestart -Intent @{ CustomRunInteractive = $true }
        }
    }
    else {
        Write-Info "Restarting script to return to the main menu..."
        Invoke-GamePopulatorScriptRestart
    }
}

if ($script:RestartAfterInteractiveCleanup) {
    Write-Host ""
    Write-Host "Press " -NoNewline -ForegroundColor White
    Write-Host "[Enter]" -NoNewline -ForegroundColor Green
    Write-Host " to return to the main menu." -ForegroundColor White
    Invoke-OutputFlush
    try {
        do {
            $k = [Console]::ReadKey($true)
        } while ($k.Key -ne [ConsoleKey]::Enter)
    }
    catch {
        $null = Read-Host "Press Enter to return to the main menu"
    }
    Write-Host ""
    Write-Info "Restarting script..."
    Invoke-GamePopulatorScriptRestart
}
