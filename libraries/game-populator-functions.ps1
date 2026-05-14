<#
Dot-sourced by game-populator.ps1 after settings bootstrap.
Game Populator — console/source maps init and menu/migrate helper functions.
#>
if ([string]::IsNullOrWhiteSpace($script:EntryScriptPath) -or
    [string]::IsNullOrWhiteSpace($script:GamePopulatorLibrariesRoot) -or
    ((Split-Path -Leaf $script:EntryScriptPath) -ne 'game-populator.ps1')) {
    Write-Host "This library script must be loaded by game-populator.ps1." -ForegroundColor Yellow
    return
}

function Get-PsdImportedSourcesArray {
    param([object]$RootData)
    if ($null -eq $RootData) {
        return @()
    }
    if ($RootData -is [hashtable]) {
        if (-not $RootData.ContainsKey('Sources')) {
            return @()
        }
        $raw = $RootData['Sources']
        if ($null -eq $raw) {
            return @()
        }
        return @($raw)
    }
    foreach ($prop in @($RootData.PSObject.Properties)) {
        if ($prop.Name -eq 'Sources') {
            if ($null -eq $prop.Value) {
                return @()
            }
            return @($prop.Value)
        }
    }
    return @()
}

function Import-GamePopulatorMergedSourcesArray {
    param([Parameter(Mandatory)][string[]]$LiteralPaths)
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $LiteralPaths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $d = Import-PowerShellDataFile -LiteralPath $p -ErrorAction Stop
        foreach ($item in @(Get-PsdImportedSourcesArray $d)) {
            if ($item) { [void]$list.Add($item) }
        }
    }
    return $list.ToArray()
}

function Import-GamePopulatorMergedConsoleNamesArray {
    param([Parameter(Mandatory)][string[]]$LiteralPaths)
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $LiteralPaths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $parsed = Get-Content -LiteralPath $p -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($e in @($parsed)) {
            if ($e) { [void]$list.Add($e) }
        }
    }
    return $list.ToArray()
}

function Test-GamePopulatorMergedSourceEntryEnabled {
    param([AllowNull()][object]$Item)
    if (-not $Item) {
        return $false
    }
    foreach ($prop in @($Item.PSObject.Properties)) {
        if ($prop.Name -ne 'Enabled') {
            continue
        }
        try {
            return [bool]$prop.Value
        }
        catch {
            return $false
        }
    }
    return $true
}

function Test-GamePopulatorResolvedShareFolderPrecheckOk {
    param([Parameter(Mandatory)][string]$PathResolvedOrRaw)
    $rp = Resolve-DestinationPath -Path ($PathResolvedOrRaw.Trim())
    if (-not $rp) {
        return $false
    }
    if (-not (Test-DestinationLocationReachable -Path $rp)) {
        return $false
    }
    return [bool](Test-Path -LiteralPath $rp -PathType Container)
}

function Disable-GamePopulatorActiveConsoleAcrossSourcePsd1Files {
    param([Parameter(Mandatory)][string]$ConsoleName)
    $didAny = $false
    foreach ($lit in @($script:GamePopulatorSourcesPaths)) {
        if ([string]::IsNullOrWhiteSpace($lit)) {
            continue
        }
        if (-not (Test-Path -LiteralPath $lit -PathType Leaf)) {
            continue
        }
        $foundHere = $false
        try {
            $parsed = Import-PowerShellDataFile -LiteralPath $lit -ErrorAction Stop
            foreach ($item in @(Get-PsdImportedSourcesArray $parsed)) {
                if (-not $item -or [string]::IsNullOrWhiteSpace([string]$item.Name)) {
                    continue
                }
                if ([string]::Equals([string]$item.Name, $ConsoleName, [StringComparison]::OrdinalIgnoreCase)) {
                    $foundHere = $true
                    break
                }
            }
        }
        catch {
            continue
        }
        if (-not $foundHere) {
            continue
        }
        $sourcesLeaf = Split-Path $lit -Leaf
        $dispForWarn = ('libraries\{0}' -f $sourcesLeaf)
        if (Disable-SourcesPsd1ConsoleBlock -LiteralPath $lit -ConsoleName ([string]$ConsoleName) -SourcesFileDisplayName $dispForWarn) {
            $didAny = $true
        }
    }
    return [bool]$didAny
}
$configRecreatedFromTemplate = $false
$allConsoles = $null
try {
    $allConsoles = Import-GamePopulatorMergedSourcesArray -LiteralPaths $script:GamePopulatorSourcesPaths
}
catch {
    Write-Host 'Sources PSD1 under libraries is invalid (console-, hacks-, trans-, or addons-sources.psd1): ' -NoNewline -ForegroundColor Yellow 
    Write-Warn $_.Exception.Message
    if (Read-YesNoDefaultYes 'Recreate libraries\console-sources.psd1 from template now? (other files: use menu option 7.)') {
        if (-not (Test-Path -LiteralPath $consoleTemplatePath)) {
            Write-Host "Template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($consoleTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $consoleTemplatePath -Destination $consolePath -Force
        $allConsoles = Import-GamePopulatorMergedSourcesArray -LiteralPaths $script:GamePopulatorSourcesPaths
        $configRecreatedFromTemplate = $true
    }
    else {
        Write-Fail "Sources files are required."
    }
}

$consoleNames = $null
try {
    $consoleNames = Import-GamePopulatorMergedConsoleNamesArray -LiteralPaths $script:GamePopulatorNamesPaths
}
catch {
    Write-Host 'A names file is invalid under libraries (console-, hacks-, trans-, or addons-names.json).' -ForegroundColor Yellow
    Write-Warn "Details: $($_.Exception.Message)"
    if (Read-YesNoDefaultYes 'Recreate libraries\console-names.json from template now? (other names files: use menu option 7.)') {
        if (-not (Test-Path -LiteralPath $consoleNamesTemplatePath)) {
            Write-Host "Console names template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($consoleNamesTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $consoleNamesTemplatePath -Destination $consoleNamesPath -Force
        $consoleNames = Import-GamePopulatorMergedConsoleNamesArray -LiteralPaths $script:GamePopulatorNamesPaths
        $configRecreatedFromTemplate = $true
    }
    else {
        Write-Fail "Names files are required."
    }
}
if ($null -eq $consoleNames -or @($consoleNames).Count -eq 0) {
    Write-Fail "No console definitions loaded from names JSON files."
}

if (-not $settings.SevenZipExe -or -not $settings.ArchiveExtensions) {
    Write-Warn "Settings file is missing required values."
    if (Read-YesNoDefaultYes 'Recreate libraries\settings.json now?') {
        if (-not (Test-Path -LiteralPath $settingsTemplatePath)) {
            Write-Host "Settings template not found: " -NoNewline -ForegroundColor Yellow
            Write-Host ([System.IO.Path]::GetFileName($settingsTemplatePath)) -ForegroundColor White
            exit 1
        }
        Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $configRecreatedFromTemplate = $true
    }
    else {
        Write-Fail "Settings file is required."
    }
}

if ($configRecreatedFromTemplate) {
    Write-Info "Restarting script to load recreated config."
    Invoke-GamePopulatorScriptRestart
    exit $LASTEXITCODE
}

if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    try {
        $capRawSettings = Get-Content -LiteralPath $settingsPath -Raw
        $capParsed = $capRawSettings | ConvertFrom-Json
        $capExceeded = $false
        if ($null -ne $capParsed -and ($capParsed.PSObject.Properties.Name -contains 'MaxConcurrentFileCopies')) {
            $parsedCapExceeded = $null
            if ([int]::TryParse((([string]$capParsed.MaxConcurrentFileCopies)).Trim(), [ref]$parsedCapExceeded)) {
                if ($parsedCapExceeded -gt 4) {
                    $capExceeded = $true
                }
            }
        }
        $stripMaxParallelKey = ($null -ne $capParsed) -and ($capParsed.PSObject.Properties.Name -contains 'MaxParallelConsoles')

        $mutRaw = [string]$capRawSettings
        if ($stripMaxParallelKey) {
            $opt = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            $next = [regex]::Replace($mutRaw, ',\s*"MaxParallelConsoles"\s*:\s*-?\d+(\.\d+)?', '', $opt)
            if (-not ([string]::Equals($next, $mutRaw, [StringComparison]::Ordinal))) {
                $mutRaw = $next
            }
            else {
                $mutRaw = [regex]::Replace($mutRaw, '"MaxParallelConsoles"\s*:\s*-?\d+(\.\d+)?\s*,?', '', $opt)
            }
            $mutRaw = [regex]::Replace($mutRaw, ',\s*,', ',')
        }
        if ($capExceeded) {
            $mutRaw = [regex]::Replace($mutRaw, '"MaxConcurrentFileCopies"\s*:\s*\d+(\.\d+)?', '"MaxConcurrentFileCopies": 4')
        }
        if (-not ([string]::Equals($mutRaw, $capRawSettings, [StringComparison]::Ordinal))) {
            Set-Content -LiteralPath $settingsPath -Encoding utf8 -Value $mutRaw
            if ($stripMaxParallelKey) {
                Write-Info 'Removed deprecated MaxParallelConsoles from libraries\settings.json. Consoles run one at a time; use MaxConcurrentFileCopies (1-4) for parallel file copies.'
            }
            if ($capExceeded) {
                Write-Info 'MaxConcurrentFileCopies was above 4; reset to 4 in libraries\settings.json.'
            }
            $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        }
    }
    catch {
    }
}

if ($settings -and ($settings.PSObject.Properties.Name -contains 'SharePassword') -and $null -ne $settings.SharePassword -and $settings.SharePassword -isnot [SecureString]) {
    $pwdStr = $settings.SharePassword.ToString()
    if (-not [string]::IsNullOrWhiteSpace($pwdStr)) {
        $settings.SharePassword = ConvertTo-SecureString $pwdStr -AsPlainText -Force
    }
}

$maxConcurrentFileCopies = 4
if ($settings.PSObject.Properties.Name -contains 'MaxConcurrentFileCopies' -and $null -ne $settings.MaxConcurrentFileCopies -and $settings.MaxConcurrentFileCopies -ne '') {
    try {
        $maxConcurrentFileCopies = [int]$settings.MaxConcurrentFileCopies
    }
    catch {
        $maxConcurrentFileCopies = 4
    }
}
if ($maxConcurrentFileCopies -lt 1) { $maxConcurrentFileCopies = 1 }
if ($maxConcurrentFileCopies -gt 4) { $maxConcurrentFileCopies = 4 }
$script:GamePopulatorMaxConcurrentFileCopies = $maxConcurrentFileCopies

$maxFilesPerFolder = 256
if ($settings.PSObject.Properties.Name -contains 'MaxFilesPerFolder' -and $null -ne $settings.MaxFilesPerFolder -and $settings.MaxFilesPerFolder -ne '') {
    try {
        $maxFilesPerFolder = [int]$settings.MaxFilesPerFolder
    }
    catch {
        $maxFilesPerFolder = 256
    }
}
if ($maxFilesPerFolder -lt 0) { $maxFilesPerFolder = 0 }
$script:GamePopulatorMaxFilesPerFolder = $maxFilesPerFolder

$structuredRunLog = $true
if (($settings.PSObject.Properties.Name -contains 'StructuredRunLog') -and ($null -ne $settings.StructuredRunLog)) {
    try { $structuredRunLog = [bool]$settings.StructuredRunLog } catch {}
}
$settings.StructuredRunLog = $structuredRunLog

$useRunCheckpointDefault = $true
if (($settings.PSObject.Properties.Name -contains 'UseRunCheckpoint') -and ($null -ne $settings.UseRunCheckpoint)) {
    try { $useRunCheckpointDefault = [bool]$settings.UseRunCheckpoint } catch {}
}
Set-Variable -Scope Script -Name useRunCheckpointSetting -Value $useRunCheckpointDefault
$settings.UseRunCheckpoint = $useRunCheckpointDefault

$consoleNameMap = @{}
$consoleSubDirMap = @{}
$consoleDisplayNameMap = @{}
$consoleExtensionsMap = @{}
Write-ScriptDiag "Building console maps from merged names JSON (console-, hacks-, trans-, addons-)"
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
$hacksOpticalPerArchiveGameFolderDisplaySet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$hacksNamesLiteralForOpticalLayout = Join-Path $script:GamePopulatorLibrariesRoot 'hacks-names.json'
if (Test-Path -LiteralPath $hacksNamesLiteralForOpticalLayout -PathType Leaf) {
    try {
        $hacksArrOpt = Get-Content -LiteralPath $hacksNamesLiteralForOpticalLayout -Raw -Encoding utf8 | ConvertFrom-Json
        foreach ($he in @($hacksArrOpt)) {
            if ($null -eq $he) { continue }
            if (($he.Optical -eq 'yes') -and -not [string]::IsNullOrWhiteSpace($he.Name)) {
                [void]$hacksOpticalPerArchiveGameFolderDisplaySet.Add([string]$he.Name)
            }
        }
    }
    catch {
    }
}
function Get-Sha256HexOfUtf8Text {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $alg = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $alg.ComputeHash($bytes)
        $sb = [System.Text.StringBuilder]::new(($hash.Length * 2))
        foreach ($b in $hash) {
            [void]$sb.AppendFormat('{0:x2}', $b)
        }
        return $sb.ToString()
    }
    finally {
        $alg.Dispose()
    }
}

function Get-GpFingerprintPathNormalized {
    param([Parameter(Mandatory)][string]$LiteralPathResolvedOrRaw)
    $pTrim = Resolve-DestinationPath -Path (($LiteralPathResolvedOrRaw.ToString()).Trim())
    try {
        return ([System.IO.Path]::GetFullPath($pTrim).TrimEnd('\', '/')).ToLowerInvariant()
    }
    catch {
        return ($pTrim.TrimEnd('\', '/')).ToLowerInvariant()
    }
}

function Get-GpRunPlanFingerprintSha256Hex {
    param(
        [object[]]$ReachableSources,
        [Parameter(Mandatory)][bool]$OrganizeRegions,
        [Parameter(Mandatory)][bool]$CopyInvokedViaParameter,
        [string]$AssetMode = 'extract',
        [string]$OptionalSingleConsoleKeyLower = ''
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($s in @($ReachableSources)) {
        if (-not $s -or [string]::IsNullOrWhiteSpace($s.Name)) { continue }
        $nk = ([string]$s.Name).Trim().ToLowerInvariant()
        $spath = ''
        if ($null -ne $s.SourcePath) {
            $spath = Get-GpFingerprintPathNormalized -LiteralPathResolvedOrRaw ($s.SourcePath.ToString())
        }
        [void]$lines.Add(('{0}|{1}' -f $nk, $spath))
    }
    $sorted = @(($lines | Sort-Object))
    $singleSeg = (($OptionalSingleConsoleKeyLower.ToString()).Trim().ToLowerInvariant())
    $plain = (($sorted | ForEach-Object { $_ }) -join "`n") + "`nmister_game_populator_run_v2|`norganizeRegions=$($OrganizeRegions.ToString().ToLowerInvariant())|`ncopyViaParameter=$($CopyInvokedViaParameter.ToString().ToLowerInvariant())|`nassetMode=$($AssetMode.ToString().ToLowerInvariant())|`nsingleConsoleKey=$singleSeg`n"
    return Get-Sha256HexOfUtf8Text -Text $plain
}

function Get-GpSourcePsd1LastWriteUtcTicksCombined {
    $ticks = New-Object System.Collections.Generic.List[string]
    foreach ($sp in @($script:GamePopulatorSourcesPaths)) {
        $tStr = '0'
        try {
            if ($sp -and (Test-Path -LiteralPath $sp -PathType Leaf)) {
                $tStr = ((Get-Item -LiteralPath $sp -ErrorAction Stop).LastWriteTimeUtc.Ticks).ToString([System.Globalization.CultureInfo]::InvariantCulture)
            }
        }
        catch { }
        $ticks.Add(('src=' + [System.IO.Path]::GetFileName($sp) + '=' + $tStr)) | Out-Null
    }
    @(($ticks.ToArray()) | Sort-Object) -join '|'
}

function Get-GpSourceVerificationGuardFingerprintSha256Hex {
    param(
        [Parameter(Mandatory)][object[]]$Sources,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ShareUserRaw,
        [Parameter(Mandatory)][string]$GamePopulatorSettingsLiteralPath
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($s in @($Sources)) {
        if (-not $s -or [string]::IsNullOrWhiteSpace($s.Name) -or [string]::IsNullOrWhiteSpace($s.SourcePath)) {
            continue
        }
        $nk = ([string]$s.Name).Trim().ToLowerInvariant()
        $spath = Get-GpFingerprintPathNormalized -LiteralPathResolvedOrRaw ($s.SourcePath.ToString())
        [void]$lines.Add(('{0}|{1}' -f $nk, $spath))
    }
    $sorted = @(($lines.ToArray()) | Sort-Object)

    $userSeg = '$empty'
    if (-not [string]::IsNullOrWhiteSpace($ShareUserRaw)) {
        try {
            $userSeg = (($ShareUserRaw.ToString()).Trim())
        }
        catch {
            $userSeg = '$empty'
        }
    }

    $settingsTicksSeg = '0'
    try {
        if (-not [string]::IsNullOrWhiteSpace($GamePopulatorSettingsLiteralPath) -and (Test-Path -LiteralPath $GamePopulatorSettingsLiteralPath -PathType Leaf)) {
            $settingsTicksSeg = ((Get-Item -LiteralPath $GamePopulatorSettingsLiteralPath).LastWriteTimeUtc.Ticks).ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }
    }
    catch { }

    $sortedLines = (($sorted | ForEach-Object { $_ }) -join "`n")
    $combined = 'guard_v1|' + $sortedLines + '|shareUser|' + (Get-Sha256HexOfUtf8Text -Text $userSeg) + '|settingsTicks|' + $settingsTicksSeg + '|' + (Get-GpSourcePsd1LastWriteUtcTicksCombined)
    return (Get-Sha256HexOfUtf8Text -Text $combined)
}

function Remove-GpSourceVerificationGuardCacheSilently {
    param([Parameter(Mandatory)][string]$CacheLiteralPath)
    Remove-Item -LiteralPath $CacheLiteralPath -Force -ErrorAction SilentlyContinue
}

function Test-GpSourceVerificationGuardCacheHit {
    param(
        [Parameter(Mandatory)][string]$CacheLiteralPath,
        [Parameter(Mandatory)][string]$ExpectedFingerprint
    )
    if ([string]::IsNullOrWhiteSpace($ExpectedFingerprint)) {
        return $false
    }
    if (-not (Test-Path -LiteralPath $CacheLiteralPath -PathType Leaf)) {
        return $false
    }
    try {
        $raw = Get-Content -LiteralPath $CacheLiteralPath -Raw -Encoding utf8 -ErrorAction Stop | ConvertFrom-Json
        $got = ''
        try {
            if ($null -ne $raw.PSObject.Properties['guardFingerprintSha256']) {
                $got = (($raw.guardFingerprintSha256).ToString()).Trim().ToLowerInvariant()
            }
        }
        catch {
            return $false
        }
        if ([string]::IsNullOrWhiteSpace($got)) {
            return $false
        }
        if (-not ($raw.PSObject.Properties.Name -contains 'schemaVersion')) {
            return $false
        }
        $schParsed = 0
        if (-not [int]::TryParse((([string]$raw.schemaVersion)).Trim(), [ref]$schParsed)) {
            return $false
        }
        if ($schParsed -lt 1) {
            return $false
        }
        return (($ExpectedFingerprint.Trim()).ToLowerInvariant() -eq $got)
    }
    catch {
        return $false
    }
}

function Save-GpSourceVerificationGuardCache {
    param(
        [Parameter(Mandatory)][string]$CacheLiteralPath,
        [Parameter(Mandatory)][string]$FingerprintSha256Hex
    )
    try {
        $container = Split-Path -Parent $CacheLiteralPath
        if (-not (Test-Path -LiteralPath $container -PathType Container)) {
            New-Item -Path $container -ItemType Directory -Force | Out-Null
        }
        $payload = @{
            schemaVersion          = [int]1
            guardFingerprintSha256 = (($FingerprintSha256Hex.ToString()).Trim().ToLowerInvariant())
            writtenUtc             = ([System.DateTime]::UtcNow.ToString('o'))
        }
        $tmp = ($CacheLiteralPath + '.tmp')
        $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $tmp -Encoding utf8 -Force
        Move-Item -LiteralPath $tmp -Destination $CacheLiteralPath -Force -ErrorAction Stop
    }
    catch {
    }
}

function Invoke-GpTestEnabledConsoleSharesReachability {
    param(
        [Parameter(Mandatory)][object[]]$Sources,
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ShareUserArg,
        [AllowNull()][SecureString]$SharePasswordArg
    )
    $reachableList = [System.Collections.Generic.List[object]]::new()
    $unreachableList = New-Object System.Collections.Generic.List[hashtable]
    $didDisableUnreachableDuringProbe = $false

    foreach ($src in @($Sources)) {
        if (-not $src) { continue }
        if ([string]::IsNullOrWhiteSpace([string]$src.Name) -or [string]::IsNullOrWhiteSpace([string]$src.SourcePath)) {
            continue
        }
        $rp = Resolve-DestinationPath -Path (($src.SourcePath.ToString()).Trim())
        $folderPrecheckBad = -not (Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $rp)
        if ($folderPrecheckBad) {
            [void]$unreachableList.Add(@{
                    Name       = $src.Name
                    SourcePath = $src.SourcePath
                    Error      = 'Folder unreachable (offline, wrong path, or no SMB visibility)'
                })
            if (Disable-GamePopulatorActiveConsoleAcrossSourcePsd1Files -ConsoleName ([string]$src.Name)) {
                $didDisableUnreachableDuringProbe = $true
            }
            continue
        }
        $probe = Test-ConsoleSourcePath -Root $src.SourcePath -User $ShareUserArg -Password $SharePasswordArg
        if ($probe.OK) {
            [void]$reachableList.Add($src)
        }
        else {
            $errText = [string]$probe.Error
            if ([string]::IsNullOrWhiteSpace($errText)) {
                $errText = 'Could not access share with configured credentials.'
            }
            [void]$unreachableList.Add(@{
                    Name       = $src.Name
                    SourcePath = $src.SourcePath
                    Error      = $errText
                })
        }
    }

    return @{
        Reachable                        = @($reachableList)
        Unreachable                      = @($unreachableList)
        DidDisableUnreachableDuringProbe = [bool]$didDisableUnreachableDuringProbe
    }
}

function Import-GpRunCheckpointObject {
    param([Parameter(Mandatory)][string]$CheckpointLiteralPath)
    if (-not (Test-Path -LiteralPath $CheckpointLiteralPath -PathType Leaf)) {
        return $null
    }
    try {
        return (Get-Content -LiteralPath $CheckpointLiteralPath -Raw -Encoding utf8 | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Save-GpRunCheckpointSilently {
    param(
        [Parameter(Mandatory)][string]$CheckpointLiteralPath,
        [hashtable]$State
    )
    try {
        if (-not (Test-Path -LiteralPath ([System.IO.Path]::GetDirectoryName($CheckpointLiteralPath)) -PathType Container)) {
            New-Item -Path ([System.IO.Path]::GetDirectoryName($CheckpointLiteralPath)) -ItemType Directory -Force | Out-Null
        }
        $tmp = $CheckpointLiteralPath + '.tmp'
        $uniqDoneLines = @(foreach ($xDone in @([array]$State['completedConsoleKeys'])) {
                ([string]$xDone).Trim().ToLowerInvariant()
            })
        $uniqDoneLines = @(($uniqDoneLines | Sort-Object -Unique))

        $payload = @{
            schemaVersion            = [int]$State['schemaVersion']
            runId                    = [string]$State['runId']
            updatedUtc               = ((Get-Date).ToUniversalTime().ToString('o'))
            plannedFingerprintSha256 = [string]$State['plannedFingerprintSha256']
            destinationCanonical     = [string]$State['destinationCanonical']
            organizeRegions          = [bool]$State['organizeRegions']
            copyInvokedViaParameter  = [bool]$State['copyInvokedViaParameter']
            completedConsoleKeys     = @($uniqDoneLines)
        }
        $payload | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $tmp -Encoding utf8 -Force
        Move-Item -LiteralPath $tmp -Destination $CheckpointLiteralPath -Force -ErrorAction Stop
    }
    catch {
        # Checkpoints must never terminate the migration.
    }
}

function Remove-GpRunCheckpointSilently {
    param([Parameter(Mandatory)][string]$CheckpointLiteralPath)
    Remove-Item -LiteralPath $CheckpointLiteralPath -Force -ErrorAction SilentlyContinue
}

function Invoke-GpWriteStructuredNdjson {
    param(
        [string]$StructuredLogLiteralPath,
        [hashtable]$RunBasics,
        [Parameter(Mandatory)][string]$Evt,
        [hashtable]$Data = @{}
    )
    if (-not [string]::IsNullOrWhiteSpace($StructuredLogLiteralPath)) {
        try {
            if (-not (Test-Path -LiteralPath ([System.IO.Path]::GetDirectoryName($StructuredLogLiteralPath)) -PathType Container)) {
                New-Item -Path ([System.IO.Path]::GetDirectoryName($StructuredLogLiteralPath)) -ItemType Directory -Force | Out-Null
            }
            $merged = @{ evt = [string]$Evt }
            if ($null -ne $RunBasics) {
                foreach ($k in $RunBasics.Keys) { $merged[$k] = $RunBasics[$k] }
            }
            foreach ($k in @($Data.Keys)) { $merged[$k] = $Data[$k] }
            Add-StructuredNdjsonLine -LiteralPath $StructuredLogLiteralPath -Record $merged
        }
        catch {}
    }
}

function Test-GpCheckpointCompatibleWithResume {
    param(
        [object]$Ck,
        [Parameter(Mandatory)][string]$PlannedFingerprintHex,
        [Parameter(Mandatory)][string]$DestinationCanonical,
        [Parameter(Mandatory)][bool]$OrganizeRegions,
        [Parameter(Mandatory)][bool]$CopyInvokedViaParameter
    )
    if ($null -eq $Ck -or (-not ($Ck.psobject.Properties.Name))) {
        return $false
    }
    if (-not ($Ck.psobject.Properties.Name -contains 'schemaVersion') -or $null -eq $Ck.schemaVersion) {
        return $false
    }
    if ([int]$Ck.schemaVersion -ne 1) { return $false }
    try {
        if ([string]$Ck.plannedFingerprintSha256 -cne $PlannedFingerprintHex) { return $false }
        $ckeys = @()
        if ($Ck.psobject.Properties.Name -contains 'completedConsoleKeys' -and $null -ne $Ck.completedConsoleKeys) {
            $rawCk = @(foreach ($qCk in @($Ck.completedConsoleKeys)) {
                    ([string]$qCk).Trim().ToLowerInvariant()
                })
            $ckeys = @(@($rawCk) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        if ($ckeys.Count -lt 1) { return $false }
        $destCanonicalFromCk = if ($Ck.psobject.Properties.Name -contains 'destinationCanonical' -and $null -ne $Ck.destinationCanonical) { [string]$Ck.destinationCanonical } else { '' }
        if (-not ([string]::Equals($destCanonicalFromCk.Trim(), ($DestinationCanonical.Trim()), [System.StringComparison]::OrdinalIgnoreCase))) { return $false }
        if (($Ck.psobject.Properties.Name -contains 'organizeRegions') -and ([bool]$Ck.organizeRegions -ne $OrganizeRegions)) { return $false }
        elseif (-not ($Ck.psobject.Properties.Name -contains 'organizeRegions')) { return $false }
        if (($Ck.psobject.Properties.Name -contains 'copyInvokedViaParameter') -and ([bool]$Ck.copyInvokedViaParameter -ne $CopyInvokedViaParameter)) { return $false }
        elseif (-not ($Ck.psobject.Properties.Name -contains 'copyInvokedViaParameter')) { return $false }
    }
    catch {
        return $false
    }
    return $true
}

function Get-DestinationPathForConsoleSource {
    param(
        [Parameter(Mandatory = $true)][string]$DestinationRoot,
        [Parameter(Mandatory = $true)][string]$ConsoleKey,
        [Parameter(Mandatory = $true)][string]$ShortName
    )
    $joined = Join-Path $DestinationRoot $ShortName
    $subDir = $consoleSubDirMap[$ConsoleKey]
    if ($subDir) {
        return (Join-Path $joined $subDir)
    }
    return $joined
}

function Initialize-TempRootDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    Write-ScriptDiag "Initialize-TempRootDirectory: $Path"
    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-ScriptDiag "Created temp folder"
        }
        else {
            Write-ScriptDiag "Temp folder exists"
        }
    }
    catch {
        Write-Fail ("Temp folder is not reachable: {0} ({1})" -f (Format-PathForDisplay $Path), $_.Exception.Message)
    }
}

function Get-SourcesPsd1EnabledEntries {
    param([Parameter(Mandatory)][string]$LiteralPath)
    $list = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return $list.ToArray()
    }
    try {
        $d = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
        foreach ($item in (Get-PsdImportedSourcesArray $d)) {
            if (-not $item) { continue }
            if ([string]::IsNullOrWhiteSpace($item.Name)) { continue }
            $list.Add([pscustomobject]@{
                    Name       = [string]$item.Name
                    SourcePath = $item.SourcePath
                    Enabled    = $true
                }) | Out-Null
        }
    }
    catch {
        Write-Warn $_.Exception.Message
    }
    return $list.ToArray()
}

function Get-SourcesPsd1CommentedBlocks {
    param([Parameter(Mandatory)][string]$LiteralPath)
    $result = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return $result.ToArray()
    }
    try {
        $lines = [string[]](Get-Content -LiteralPath $LiteralPath)
    }
    catch {
        return $result.ToArray()
    }
    $i = 0
    while ($i -lt $lines.Length) {
        $line = $lines[$i]
        if ($line -match '^\s*#\s+\@\{' ) {
            $start = $i
            $close = -1
            for ($j = $i + 1; $j -lt $lines.Length; $j++) {
                if (Test-Psd1SourcesBlockClosingLine -Line $lines[$j] -Commented) {
                    $close = $j
                    break
                }
            }
            if ($close -lt 0) {
                $i++
                continue
            }
            $blk = ($lines[$start..$close] -join "`n")
            $norm = $blk -replace '(?m)^\s*#\s*', ''
            $name = $null
            $src = $null
            if ($norm -match "Name\s*=\s*'((?:[^']|'')*)'") {
                $name = $Matches[1] -replace "''", "'"
            }
            if ($norm -match "SourcePath\s*=\s*'((?:[^']|'')*)'") {
                $src = $Matches[1] -replace "''", "'"
            }
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $result.Add([pscustomobject]@{
                        Name       = $name
                        SourcePath = $src
                        Enabled    = $false
                    }) | Out-Null
            }
            $i = $close + 1
            continue
        }
        if ($line -match '^\s+\@\{' ) {
            $start = $i
            $close = -1
            for ($j = $i + 1; $j -lt $lines.Length; $j++) {
                if (Test-Psd1SourcesBlockClosingLine -Line $lines[$j]) {
                    $close = $j
                    break
                }
            }
            if ($close -lt 0) {
                $i++
                continue
            }
            $i = $close + 1
            continue
        }
        $i++
    }
    return $result.ToArray()
}

function Get-SourcesPsd1UnifiedAlphabetical {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [hashtable]$DisplayNameMap
    )
    $byKey = @{}

    function Add-One {
        param(
            [Parameter(Mandatory)][object]$Item,
            [Parameter(Mandatory)][bool]$IsEnabled
        )
        if (-not $Item) { return }
        if ([string]::IsNullOrWhiteSpace($Item.Name)) { return }
        $nk = ([string]$Item.Name).ToLowerInvariant()
        if ($byKey.ContainsKey($nk)) { return }
        $disp = [string]$Item.Name
        if ($DisplayNameMap -and -not [string]::IsNullOrWhiteSpace($disp)) {
            $kk = $disp.ToLowerInvariant()
            if ($DisplayNameMap[$kk]) {
                $disp = [string]$DisplayNameMap[$kk]
            }
        }
        $byKey[$nk] = [pscustomobject]@{
            Name       = [string]$Item.Name
            Display    = $disp
            SortKey    = $disp.ToLowerInvariant()
            Enabled    = $IsEnabled
            SourcePath = $Item.SourcePath
        }
    }

    foreach ($item in @(Get-SourcesPsd1EnabledEntries -LiteralPath $LiteralPath)) {
        Add-One $item $true
    }
    foreach ($item in @(Get-SourcesPsd1CommentedBlocks -LiteralPath $LiteralPath)) {
        Add-One $item $false
    }
    @($byKey.Values | Sort-Object SortKey, Name)
}

function Get-GpNumberedSortedSourceBlocksForConsoleList {
    param(
        [AllowEmptyCollection()][object[]]$Blocks,
        [hashtable]$DisplayNameMap
    )

    # Undo mistaken outer wrap (e.g. return ,$arr) so we get N blocks, not one element whose .Name is all names.
    if ($null -ne $Blocks -and $Blocks.Count -eq 1 -and $Blocks[0] -is [object[]]) {
        $Blocks = $Blocks[0]
    }

    $entryList = [System.Collections.Generic.List[object]]::new()
    foreach ($b in @($Blocks)) {
        if (-not $b) { continue }
        if ([string]::IsNullOrWhiteSpace($b.Name)) { continue }
        $disp = [string]$b.Name
        if ($DisplayNameMap -and -not [string]::IsNullOrWhiteSpace($disp)) {
            $k = $disp.ToLowerInvariant()
            if ($DisplayNameMap[$k]) { $disp = [string]$DisplayNameMap[$k] }
        }
        $entryList.Add([pscustomobject]@{
                Block   = $b
                Display = $disp
                SortKey = $disp.ToLowerInvariant()
            }) | Out-Null
    }
    $sorted = @($entryList.ToArray() | Sort-Object -Property SortKey, { [string]$_.Block.Name })
    $n = $sorted.Count
    $numList = [System.Collections.Generic.List[object]]::new()
    if ($n -eq 0) {
        return [pscustomobject]@{ Numbered = @(); Count = 0 }
    }

    for ($ri = 0; $ri -lt $n; $ri++) {
        $numList.Add([pscustomobject]@{
                Num     = $ri + 1
                Display = [string]$sorted[$ri].Display
                Block   = $sorted[$ri].Block
            }) | Out-Null
    }
    $numbered = $numList.ToArray()
    return [pscustomobject]@{ Numbered = $numbered; Count = [int]$n }
}

function Write-GpNumberedSourceConsoleList {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Numbered,
        [switch]$ShowSourcePaths,
        [switch]$ColorEnabledState
    )

    $n = @($Numbered).Count
    if ($n -eq 0) {
        return
    }

    $numbered = @($Numbered)

    $getDisplayFg = {
        param($blk)
        if (-not $ColorEnabledState) { return 'White' }
        foreach ($p in @($blk.PSObject.Properties)) {
            if ($p.Name -eq 'Enabled' -and -not [bool]$p.Value) { return 'Red' }
        }
        return 'White'
    }

    $writePath = {
        param($blk)
        $pathRaw = $blk.SourcePath
        if ($null -eq $pathRaw) { return }
        $pathStr = if ($pathRaw -is [string]) { $pathRaw.Trim() } else { ([string]$pathRaw).Trim() }
        if (-not [string]::IsNullOrWhiteSpace($pathStr)) {
            Write-Host ("       {0}" -f (Format-PathForDisplay $pathStr)) -ForegroundColor DarkGray
        }
    }

    if ($ShowSourcePaths -or $n -le 10) {
        for ($ri = 0; $ri -lt $n; $ri++) {
            $e = $numbered[$ri]
            if ($ColorEnabledState) {
                $nmFg = & $getDisplayFg $e.Block
                $pf = ('  {0,3}. ' -f $e.Num)
                Write-Host $pf -NoNewline -ForegroundColor White
                Write-Host ([string]$e.Display) -ForegroundColor $nmFg
            }
            else {
                Write-Host (('  {0,3}. ' -f $e.Num) + [string]$e.Display) -ForegroundColor White
            }
            if ($ShowSourcePaths) {
                & $writePath $e.Block
            }
        }
        Write-Host ""
        return
    }

    # Multi-column (n > 10, no paths): at most 3 columns; width from console buffer/window so lines do not wrap.
    $usableWidth = 120
    try {
        $bw = $Host.UI.RawUI.BufferSize.Width
        if ($bw -gt 0) { $usableWidth = $bw }
    }
    catch { }
    try {
        $ww = $Host.UI.RawUI.WindowSize.Width
        if ($ww -gt 0 -and $ww -lt $usableWidth) { $usableWidth = $ww }
    }
    catch { }
    if ($env:COLUMNS) {
        $ec = 0
        if ([int]::TryParse($env:COLUMNS, [ref]$ec) -and $ec -gt 0) {
            $usableWidth = [Math]::Min($usableWidth, $ec)
        }
    }
    $usableWidth = [Math]::Max(48, $usableWidth - 2)

    $truncateCell = {
        param([string]$Text, [int]$MaxChars)
        if ($MaxChars -le 0) { return '' }
        if ($Text.Length -le $MaxChars) { return $Text }
        if ($MaxChars -le 3) { return $Text.Substring(0, [Math]::Min($Text.Length, $MaxChars)) }
        return $Text.Substring(0, $MaxChars - 3) + '...'
    }

    # Target ~15 rows per column when possible; cap at 3 columns; reduce column count if cells would be too narrow.
    $gap = '  '
    $gapLen = $gap.Length
    $minCellChars = 20
    $idealCols = [int][Math]::Ceiling($n / 15.0)
    $colCount = [Math]::Max(2, [Math]::Min(3, $idealCols))
    while ($colCount -gt 2) {
        $testMax = [int][Math]::Floor(($usableWidth - ($colCount - 1) * $gapLen) / $colCount)
        if ($testMax -ge $minCellChars) { break }
        $colCount--
    }
    $cellMax = [int][Math]::Floor(($usableWidth - ($colCount - 1) * $gapLen) / $colCount)
    if ($colCount -eq 2 -and $cellMax -lt $minCellChars) {
        $colCount = 1
        $cellMax = $usableWidth
    }

    if ($colCount -le 1) {
        for ($ri = 0; $ri -lt $n; $ri++) {
            $e = $numbered[$ri]
            $prefix = ('  {0,3}. ' -f $e.Num)
            $maxDisp = [Math]::Max(0, $cellMax - $prefix.Length)
            $dispTrunc = & $truncateCell ([string]$e.Display) $maxDisp
            if ($ColorEnabledState) {
                $nmFg = & $getDisplayFg $e.Block
                Write-Host $prefix -NoNewline -ForegroundColor White
                Write-Host $dispTrunc -ForegroundColor $nmFg
            }
            else {
                Write-Host ($prefix + $dispTrunc) -ForegroundColor White
            }
        }
        Write-Host ""
        return
    }

    $base = [int][Math]::Floor($n / $colCount)
    $rem = $n % $colCount
    $columnArrays = [System.Collections.Generic.List[object[]]]::new()
    $off = 0
    for ($ci = 0; $ci -lt $colCount; $ci++) {
        $h = $base + ($(if ($ci -lt $rem) { 1 } else { 0 }))
        if ($h -le 0) { continue }
        $end = $off + $h - 1
        $colArr = @($numbered[$off..$end])
        $columnArrays.Add($colArr) | Out-Null
        $off += $h
    }
    $activeCols = $columnArrays.Count
    if ($activeCols -eq 0) {
        Write-Host ""
        return
    }
    $maxRows = 0
    foreach ($colArr in $columnArrays) {
        if ($colArr.Length -gt $maxRows) { $maxRows = $colArr.Length }
    }
    for ($row = 0; $row -lt $maxRows; $row++) {
        for ($ci = 0; $ci -lt $activeCols; $ci++) {
            if ($ci -gt 0) { Write-Host $gap -NoNewline }
            $colArr = $columnArrays[$ci]
            if ($row -lt $colArr.Length) {
                $e = $colArr[$row]
                $prefix = ('  {0,3}. ' -f $e.Num)
                $maxDisp = [Math]::Max(0, $cellMax - $prefix.Length)
                $dispTrunc = & $truncateCell ([string]$e.Display) $maxDisp
                if ($ColorEnabledState) {
                    $nmFg = & $getDisplayFg $e.Block
                    $used = $prefix.Length + $dispTrunc.Length
                    $pad = [Math]::Max(0, $cellMax - $used)
                    Write-Host $prefix -NoNewline -ForegroundColor White
                    Write-Host $dispTrunc -NoNewline -ForegroundColor $nmFg
                    Write-Host (' ' * $pad) -NoNewline
                }
                else {
                    $cell = $prefix + $dispTrunc
                    $padded = $cell.PadRight($cellMax)
                    Write-Host $padded -NoNewline -ForegroundColor White
                }
            }
            else {
                Write-Host (''.PadRight($cellMax)) -NoNewline
            }
        }
        Write-Host ''
    }
    Write-Host ""
}

function Write-NumberedSourcesConsoleBlockList {
    param(
        [AllowEmptyCollection()][object[]]$Blocks,
        [hashtable]$DisplayNameMap,
        [switch]$ShowSourcePaths,
        [switch]$ColorEnabledState
    )
    $prep = Get-GpNumberedSortedSourceBlocksForConsoleList -Blocks $Blocks -DisplayNameMap $DisplayNameMap
    if ($prep.Count -eq 0) {
        Write-Host "  (none)" -ForegroundColor DarkYellow
        Write-Host ""
        return
    }
    Write-GpNumberedSourceConsoleList -Numbered $prep.Numbered -ShowSourcePaths:$ShowSourcePaths -ColorEnabledState:$ColorEnabledState
}

function Test-Psd1SourcesBlockClosingLine {
    param(
        [Parameter(Mandatory)][string]$Line,
        [switch]$Commented
    )
    if ($Commented) {
        return $Line -match '^\s*#\s*\}\s*,?\s*$'
    }
    $t = $Line.Trim()
    return ($t -eq '}' -or $t -eq '},')
}

function Disable-SourcesPsd1ConsoleBlock {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][string]$ConsoleName,
        [string]$SourcesFileDisplayName = 'libraries\console-sources.psd1'
    )
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        Write-Warn "sources file not found: $LiteralPath"
        return $false
    }
    try {
        $lines = [System.Collections.Generic.List[string]]::new([string[]](Get-Content -LiteralPath $LiteralPath))
    }
    catch {
        Write-Warn $_.Exception.Message
        return $false
    }
    $i = 0
    while ($i -lt $lines.Count) {
        $trim = $lines[$i].TrimStart()
        if ($trim.StartsWith('#')) {
            $i++
            continue
        }
        if ($lines[$i] -match '^\s+\@\{' ) {
            $start = $i
            $close = -1
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if (Test-Psd1SourcesBlockClosingLine -Line $lines[$j]) {
                    $close = $j
                    break
                }
            }
            if ($close -lt 0) {
                Write-Warn ("Unclosed Sources hashtable block near line {0}." -f ($start + 1))
                return $false
            }
            $seg = $lines[$start..$close]
            $blk = $seg -join "`n"
            $parsed = $null
            if ($blk -match "Name\s*=\s*'((?:[^']|'')*)'") {
                $parsed = $Matches[1] -replace "''", "'"
            }
            $nameMatch = $false
            if ($null -ne $parsed) {
                if ($parsed -ceq $ConsoleName) {
                    $nameMatch = $true
                }
                elseif ([string]::Equals($parsed, $ConsoleName, [StringComparison]::OrdinalIgnoreCase)) {
                    $nameMatch = $true
                }
            }
            if ($nameMatch) {
                for ($k = $start; $k -le $close; $k++) {
                    $ln = $lines[$k]
                    if (-not $ln.TrimStart().StartsWith('#')) {
                        $lines[$k] = '#' + $ln
                    }
                }
                try {
                    $lines | Set-Content -LiteralPath $LiteralPath -Encoding utf8
                }
                catch {
                    Write-Warn $_.Exception.Message
                    return $false
                }
                try {
                    $null = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
                }
                catch {
                    Write-Warn ("{0} may be invalid after edit: {1}" -f $SourcesFileDisplayName, $_.Exception.Message)
                    return $false
                }
                return $true
            }
            $i = $close + 1
            continue
        }
        $i++
    }
    Write-Warn ("No active Sources block matched Name = '{0}'." -f $ConsoleName)
    return $false
}

function Enable-SourcesPsd1ConsoleBlock {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][string]$ConsoleName,
        [string]$SourcesFileDisplayName = 'libraries\console-sources.psd1'
    )
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        Write-Warn "sources file not found: $LiteralPath"
        return $false
    }
    try {
        $lines = [System.Collections.Generic.List[string]]::new([string[]](Get-Content -LiteralPath $LiteralPath))
    }
    catch {
        Write-Warn $_.Exception.Message
        return $false
    }
    $i = 0
    while ($i -lt $lines.Count) {
        if ($lines[$i] -notmatch '^\s*#\s+\@\{' ) {
            $i++
            continue
        }
        $start = $i
        $close = -1
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if (Test-Psd1SourcesBlockClosingLine -Line $lines[$j] -Commented) {
                $close = $j
                break
            }
        }
        if ($close -lt 0) {
            $i++
            continue
        }
        $seg = $lines[$start..$close]
        $blk = $seg -join "`n"
        $norm = $blk -replace '(?m)^\s*#\s*', ''
        $parsed = $null
        if ($norm -match "Name\s*=\s*'((?:[^']|'')*)'") {
            $parsed = $Matches[1] -replace "''", "'"
        }
        $nameMatch = $false
        if ($null -ne $parsed) {
            if ($parsed -ceq $ConsoleName) {
                $nameMatch = $true
            }
            elseif ([string]::Equals($parsed, $ConsoleName, [StringComparison]::OrdinalIgnoreCase)) {
                $nameMatch = $true
            }
        }
        if ($nameMatch) {
            for ($k = $start; $k -le $close; $k++) {
                $ln = $lines[$k]
                if ($ln.TrimStart().StartsWith('#')) {
                    $lines[$k] = $ln.Substring(1)
                }
            }
            try {
                $lines | Set-Content -LiteralPath $LiteralPath -Encoding utf8
            }
            catch {
                Write-Warn $_.Exception.Message
                return $false
            }
            try {
                $null = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
            }
            catch {
                Write-Warn ("{0} may be invalid after edit: {1}" -f $SourcesFileDisplayName, $_.Exception.Message)
                return $false
            }
            return $true
        }
        $i = $close + 1
    }
    Write-Warn ("No commented Sources block matched Name = '{0}'." -f $ConsoleName)
    return $false
}

function Update-SourcesPsd1ConsoleSourcePath {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath,
        [Parameter(Mandatory = $true)][string]$ConsoleName,
        [Parameter(Mandatory = $true)][string]$NewSourcePath,
        [string]$SourcesFileDisplayName = 'libraries\console-sources.psd1'
    )

    function Test-ConsoleNameAgainstMatch {
        param([string]$MatchedNameInner)
        if ($null -eq $MatchedNameInner) { return $false }
        if ($MatchedNameInner -ceq $ConsoleName) {
            return $true
        }
        return [string]::Equals($MatchedNameInner, $ConsoleName, [StringComparison]::OrdinalIgnoreCase)
    }

    function Set-SourcesPathLineInSpan {
        param(
            [System.Collections.Generic.List[string]]$LineList,
            [int]$StartIndex,
            [int]$CloseIndex,
            [string]$ReplacementPathEscaped
        )
        for ($k = $StartIndex; $k -le $CloseIndex; $k++) {
            $raw = [string]$LineList[$k]
            $idx = $raw.IndexOf('SourcePath', [System.StringComparison]::Ordinal)
            if ($idx -lt 0) { continue }
            $tail = $raw.Substring($idx)
            if (($tail.TrimStart()) -notmatch '^SourcePath\s*=') {
                continue
            }
            $LineList[$k] = $raw.Substring(0, $idx) + ('SourcePath = ''{0}''' -f $ReplacementPathEscaped)
            return $true
        }
        return $false
    }

    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        Write-Warn "sources file not found: $LiteralPath"
        return $false
    }
    $trimmedPath = ($NewSourcePath.Trim())
    try {
        $lines = [System.Collections.Generic.List[string]]::new([string[]](Get-Content -LiteralPath $LiteralPath))
    }
    catch {
        Write-Warn $_.Exception.Message
        return $false
    }

    # Active (uncommented) blocks
    $iActive = 0
    while ($iActive -lt $lines.Count) {
        $trim = $lines[$iActive].TrimStart()
        if ($trim.StartsWith('#')) {
            $iActive++
            continue
        }
        if ($lines[$iActive] -match '^\s+\@\{' ) {
            $start = $iActive
            $close = -1
            for ($j = $iActive + 1; $j -lt $lines.Count; $j++) {
                if (Test-Psd1SourcesBlockClosingLine -Line $lines[$j]) {
                    $close = $j
                    break
                }
            }
            if ($close -lt 0) {
                Write-Warn ("Unclosed Sources hashtable block near line {0}." -f ($start + 1))
                return $false
            }
            $seg = $lines[$start..$close]
            $blk = $seg -join "`n"
            $parsedName = $null
            if ($blk -match "Name\s*=\s*'((?:[^']|'')*)'") {
                $parsedName = $Matches[1] -replace "''", "'"
            }
            if (-not ($parsedName)) {
                # ignore malformed block
                $iActive = $close + 1
                continue
            }
            if (Test-ConsoleNameAgainstMatch $parsedName) {
                $esc = ($trimmedPath -replace "'", "''")
                if (-not (Set-SourcesPathLineInSpan -LineList $lines -StartIndex $start -CloseIndex $close -ReplacementPathEscaped $esc)) {
                    Write-Warn ("No SourcePath line inside active block for '{0}'." -f $ConsoleName)
                    return $false
                }
                try {
                    $lines | Set-Content -LiteralPath $LiteralPath -Encoding utf8
                }
                catch {
                    Write-Warn $_.Exception.Message
                    return $false
                }
                try {
                    $null = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
                }
                catch {
                    Write-Warn ("{0} may be invalid after edit: {1}" -f $SourcesFileDisplayName, $_.Exception.Message)
                    return $false
                }
                return $true
            }
            $iActive = $close + 1
            continue
        }
        $iActive++
    }

    # Commented (# line-prefixed) blocks
    $iCom = 0
    while ($iCom -lt $lines.Count) {
        if ($lines[$iCom] -notmatch '^\s*#\s+\@\{' ) {
            $iCom++
            continue
        }
        $start = $iCom
        $close = -1
        for ($j = $iCom + 1; $j -lt $lines.Count; $j++) {
            if (Test-Psd1SourcesBlockClosingLine -Line $lines[$j] -Commented) {
                $close = $j
                break
            }
        }
        if ($close -lt 0) {
            $iCom++
            continue
        }
        $blk = ($lines[$start..$close] -join "`n")
        $norm = $blk -replace '(?m)^\s*#\s*', ''
        $parsedName = $null
        if ($norm -match "Name\s*=\s*'((?:[^']|'')*)'") {
            $parsedName = $Matches[1] -replace "''", "'"
        }
        if (($parsedName) -and (Test-ConsoleNameAgainstMatch $parsedName)) {
            $esc = ($trimmedPath -replace "'", "''")
            if (-not (Set-SourcesPathLineInSpan -LineList $lines -StartIndex $start -CloseIndex $close -ReplacementPathEscaped $esc)) {
                Write-Warn ("No SourcePath line inside commented block for '{0}'." -f $ConsoleName)
                return $false
            }
            try {
                $lines | Set-Content -LiteralPath $LiteralPath -Encoding utf8
            }
            catch {
                Write-Warn $_.Exception.Message
                return $false
            }
            try {
                $null = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
            }
            catch {
                Write-Warn ("{0} may be invalid after edit: {1}" -f $SourcesFileDisplayName, $_.Exception.Message)
                return $false
            }
            return $true
        }
        $iCom = $close + 1
    }

    Write-Warn ("No Sources block matched Name = '{0}' for SourcePath update." -f $ConsoleName)
    return $false
}

function Update-GamePopulatorConsoleSourcesState {
    try {
        $script:allConsoles = Import-GamePopulatorMergedSourcesArray -LiteralPaths $script:GamePopulatorSourcesPaths
        $script:activeConsoleSourceCount = 0
        if ($null -ne $script:allConsoles) {
            $script:activeConsoleSourceCount = @($script:allConsoles | Where-Object {
                    $_ `
                        -and (Test-GamePopulatorMergedSourceEntryEnabled $_) `
                        -and -not [string]::IsNullOrWhiteSpace($_.Name) `
                        -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
                }).Count
        }
    }
    catch {
        Write-Warn $_.Exception.Message
    }
}

function Format-ApproximateTransferDuration {
    param(
        [long]$TotalBytes,
        [double]$BytesPerSecond
    )
    if ($TotalBytes -le 0) {
        return '—'
    }
    if ($BytesPerSecond -le 0) {
        return '—'
    }
    $sec = [double]$TotalBytes / $BytesPerSecond
    if ($sec -lt 90) {
        return ('about {0:N0} seconds' -f [math]::Round($sec))
    }
    $min = $sec / 60.0
    if ($min -lt 120) {
        return ('about {0:N1} minutes' -f $min)
    }
    $hours = [int][math]::Floor($min / 60.0)
    $remMin = [int][math]::Round($min - $hours * 60.0)
    if ($remMin -ge 60) {
        $remMin = 0
        $hours++
    }
    if ($hours -le 0) {
        return ('about {0:N1} minutes' -f $min)
    }
    return ('about {0} hour(s) {1} minutes' -f $hours, $remMin)
}

function Write-GamePopulatorEnabledSystemsStorageMeasurements {
    param(
        [Parameter(Mandatory)][object[]]$EnabledSystems,
        [Parameter(Mandatory)][string]$SevenZipResolved,
        [Parameter(Mandatory)][string[]]$ArchiveExtensionsResolved,
        [Parameter(Mandatory)][bool]$UseUnpack,
        [Parameter(Mandatory)][System.Globalization.CultureInfo]$ReportCulture,
        [Parameter(Mandatory)][int]$FilesColW,
        [Parameter(Mandatory)][int]$MbColW,
        [Parameter(Mandatory)][ref]$GrandFilesLongRef,
        [Parameter(Mandatory)][ref]$GrandBytesLongRef,
        [Parameter(Mandatory)][hashtable]$ConsoleExtensionsMap,
        [AllowNull()]
        [System.Collections.Generic.List[string]]$LogLines
    )
    $gapAfterFiles = '    '
    $gapAfterMb = '    '
    foreach ($sys in @($EnabledSystems)) {
        $srcRaw = ''
        if ($null -ne $sys.SourcePath) {
            $srcRaw = ([string]$sys.SourcePath).Trim()
        }
        $fc = 0
        $tb = [long]0
        if (-not [string]::IsNullOrWhiteSpace($srcRaw)) {
            $resolved = Resolve-DestinationPath -Path $srcRaw
            $ck = ([string]$sys.Name).ToLowerInvariant()
            $allowedExtSet = $ConsoleExtensionsMap[$ck]
            if (-not $allowedExtSet) {
                $allowedExtSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                $allowedExtSet.Add('.rom') | Out-Null
            }
            $dispForOptical = [string]$sys.Display
            $szInnerListing = Resolve-GpSevenZipExePathWithFallbacks -Preferred $SevenZipResolved
            $stats = Measure-DirectoryFileCountAndBytes `
                -LiteralDirectoryPath $resolved `
                -SevenZipExeForUnpackedEstimate $(if ($UseUnpack) { $SevenZipResolved } else { '' }) `
                -ArchiveExtensionsForUnpackedEstimate @($ArchiveExtensionsResolved) `
                -AllowedExtensionsForEligibility $allowedExtSet `
                -UseOpticalCopySemantics:($consoleOpticalSet.Contains($dispForOptical)) `
                -ConsoleKeyLowerForRomNamingRules $ck `
                -SevenZipExeForSgbArchiveInnerListing $szInnerListing
            $fc = $stats.FileCount
            $tb = $stats.TotalBytes
        }
        $GrandFilesLongRef.Value += $fc
        $GrandBytesLongRef.Value += $tb
        $mb = [math]::Round($tb / 1MB, 2)
        $filesDisp = $fc.ToString('N0', $ReportCulture).PadLeft($FilesColW)
        $mbDisp = $mb.ToString('N2', $ReportCulture).PadLeft($MbColW)
        $mbSuffix = if ($UseUnpack) { ' est. MB' } else { ' MB' }
        if ($null -ne $LogLines) {
            $plain = ('{0} files{1}{2}{3}{4}{5}' -f $filesDisp, $gapAfterFiles, $mbDisp, $mbSuffix, $gapAfterMb, [string]$sys.Display)
            $LogLines.Add($plain) | Out-Null
        }
        Write-Host $filesDisp -NoNewline -ForegroundColor DarkCyan
        Write-Host ' files' -NoNewline -ForegroundColor White
        Write-Host $gapAfterFiles -NoNewline
        Write-Host $mbDisp -NoNewline -ForegroundColor DarkCyan
        Write-Host $mbSuffix -NoNewline -ForegroundColor White
        Write-Host $gapAfterMb -NoNewline
        Write-Host $sys.Display -ForegroundColor White
        Invoke-OutputFlush
    }
}

function Invoke-GamePopulatorGroupedEnabledSourcesStorageReport {
    param(
        [Parameter(Mandatory)][string]$ScriptRoot,
        [hashtable]$DisplayNameMap,
        [object]$SettingsForArchive = $null,
        [Parameter(Mandatory)][string]$ConsoleSourcesLiteralPath,
        [Parameter(Mandatory)][string]$HacksSourcesLiteralPath,
        [Parameter(Mandatory)][string]$TransSourcesLiteralPath,
        [Parameter(Mandatory)][string]$AddonsSourcesLiteralPath,
        [Parameter(Mandatory)][hashtable]$ConsoleExtensionsMap
    )
    $szResolved = ''
    if ($SettingsForArchive -and $SettingsForArchive.PSObject.Properties['SevenZipExe'] -and $null -ne $SettingsForArchive.SevenZipExe) {
        $szResolved = ([string]$SettingsForArchive.SevenZipExe).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($szResolved)) {
        $szResolved = if ($null -ne $script:SevenZipExe) { [string]$script:SevenZipExe } else { '' }
    }
    $extResolved = @('.zip', '.7z', '.rar')
    if ($SettingsForArchive -and $SettingsForArchive.PSObject.Properties['ArchiveExtensions'] -and $null -ne $SettingsForArchive.ArchiveExtensions) {
        $extResolved = @($SettingsForArchive.ArchiveExtensions)
    }
    $useUnpack = (Test-Path -LiteralPath $szResolved -PathType Leaf) -and ($extResolved.Count -gt 0)
    Write-Host ''
    Write-Host ' - Analyzing files and gathering sizes from each enabled SourcePath (all categories).' -ForegroundColor DarkYellow
    Write-Host ' - Only files matching each merged names Extensions list apply (same as copy), plus ArchiveExtensions from settings (.zip /.7z /.rar by default).' -ForegroundColor DarkYellow
    Write-Host ' - Each line appears when that system finishes (large libraries will take a while).' -ForegroundColor DarkYellow
    if ($useUnpack) {
        Write-Host ' - Archive types use 7z list metadata (uncompressed sum per archive).' -ForegroundColor DarkYellow
        Write-Host ' - Failing listings fall back to the archive file size on disk.' -ForegroundColor DarkYellow
    }
    else {
        Write-Host (' - Archives use compressed size on disk (7z not found at ''{0}'' — set SevenZipExe in settings for uncompressed estimates).' -f $szResolved) -ForegroundColor DarkYellow
    }
    Write-Host ' - Optical (disc) systems: counts include all files under BIN+CUE game folders (same as copy).' -ForegroundColor DarkYellow
    Write-Host ''

    $logLines = [System.Collections.Generic.List[string]]::new()
    $logLines.Add("Game Populator — enabled sources storage report — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
    $logLines.Add('') | Out-Null

    foreach ($explain in @(
            '- Analyzing files from each enabled SourcePath (recursive).',
            '- File counts use merged *.json Extensions plus ArchiveExtensions (+ optical BIN+CUE trees for disc systems).',
            '- Each source line appears when that system finishes scanning.',
            '- Totals at the bottom aggregate every enabled entry across Official consoles, Game Hacks + Improvements, Game Translations, and Add-ons.'
        )) {
        $logLines.Add($explain) | Out-Null
    }
    if ($useUnpack) {
        $logLines.Add('- Archive entries use 7-Zip list totals when available (estimated uncompressed).') | Out-Null
        $logLines.Add('- Listing failures fall back to compressed size on disk.') | Out-Null
    }
    else {
        $logLines.Add(('- Archive sizes use on-disk footprint (SevenZipExe missing at ''{0}'' — set SevenZipExe for estimates).' -f $szResolved)) | Out-Null
    }
    $logLines.Add('') | Out-Null

    $reportCulture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
    $filesColW = 14
    $mbColW = 14
    $grandFilesLong = [long]0
    $grandBytesLong = [long]0

    $categoryDefs = @(
        @{ Title = 'Official consoles'; Path = $ConsoleSourcesLiteralPath }
        @{ Title = 'Game Hacks + Improvements'; Path = $HacksSourcesLiteralPath }
        @{ Title = 'Game Translations'; Path = $TransSourcesLiteralPath }
        @{ Title = 'Add-ons (music files)'; Path = $AddonsSourcesLiteralPath }
    )

    $reportSw = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($cat in @($categoryDefs)) {
        $title = [string]$cat.Title
        $lit = [string]$cat.Path

        Write-Host '' 
        Write-Host $title -ForegroundColor Cyan
        $logLines.Add($title) | Out-Null

        $enabled = @(
            Get-SourcesPsd1UnifiedAlphabetical -LiteralPath $lit -DisplayNameMap $DisplayNameMap |
                Where-Object { $_.Enabled } |
                Sort-Object SortKey, Name
        )

        if ($enabled.Count -eq 0) {
            $noneMsg = '  (no enabled sources in this category)'
            Write-Host $noneMsg -ForegroundColor DarkGray
            $logLines.Add($noneMsg) | Out-Null
        }
        else {
            Write-GamePopulatorEnabledSystemsStorageMeasurements `
                -EnabledSystems @($enabled) `
                -SevenZipResolved $szResolved `
                -ArchiveExtensionsResolved @($extResolved) `
                -UseUnpack $useUnpack `
                -ReportCulture $reportCulture `
                -FilesColW $filesColW `
                -MbColW $mbColW `
                -GrandFilesLongRef ([ref]$grandFilesLong) `
                -GrandBytesLongRef ([ref]$grandBytesLong) `
                -ConsoleExtensionsMap $ConsoleExtensionsMap `
                -LogLines $logLines
        }

        Write-Host ''
        $logLines.Add('') | Out-Null
    }

    $reportSw.Stop()

    $tMb = [math]::Round($grandBytesLong / 1MB, 2)
    $gapAfterFiles = '    '
    $totalMbSuffix = if ($useUnpack) { ' est. MB total space required.' } else { ' MB total space required.' }

    Write-Host '[ Totals — all enabled sources ]' -ForegroundColor Cyan
    Write-Host ''

    $tFilesDisp = $grandFilesLong.ToString('N0', $reportCulture).PadLeft($filesColW)
    $tMbDisp = $tMb.ToString('N2', $reportCulture).PadLeft($mbColW)
    $totalPlain = ('{0} files{1}{2}{3}' -f $tFilesDisp, $gapAfterFiles, $tMbDisp, $totalMbSuffix)
    $logLines.Add('[ Totals — all enabled sources ]') | Out-Null
    $logLines.Add('') | Out-Null
    $logLines.Add($totalPlain) | Out-Null

    Write-Host $tFilesDisp -NoNewline -ForegroundColor DarkCyan
    Write-Host ' files' -NoNewline -ForegroundColor White
    Write-Host $gapAfterFiles -NoNewline
    Write-Host $tMbDisp -NoNewline -ForegroundColor DarkCyan
    Write-Host $totalMbSuffix -ForegroundColor White
    Write-Host ''

    $elapsedStr = (Format-Elapsed -Elapsed $reportSw.Elapsed)
    $timeLine = (' - Measured in {0}.' -f $elapsedStr)
    Write-Host $timeLine -ForegroundColor DarkGray
    $logLines.Add('') | Out-Null
    $logLines.Add($timeLine) | Out-Null

    if ($useUnpack) {
        $timeNote = ' - Timing includes full directory scan, 7z list per matching archive (slow on huge libraries).'
        Write-Host $timeNote -ForegroundColor DarkGray
        $logLines.Add($timeNote) | Out-Null
    }
    Write-Host ''

    $usb2bps = 35.0 * 1MB
    $usb30bps = 200.0 * 1MB
    $usb31bps = 400.0 * 1MB
    $lan1gBps = 100.0 * 1MB
    Write-Host 'Approximate full copy times (does not have extraction times into account):' -ForegroundColor DarkGray
    Write-Host '  USB 2.0 device (~35 MB/s): ' -NoNewline -ForegroundColor White
    Write-Host (Format-ApproximateTransferDuration -TotalBytes $grandBytesLong -BytesPerSecond $usb2bps) -ForegroundColor DarkCyan
    Write-Host '  USB 3.0 device (~200 MB/s): ' -NoNewline -ForegroundColor White
    Write-Host (Format-ApproximateTransferDuration -TotalBytes $grandBytesLong -BytesPerSecond $usb30bps) -ForegroundColor DarkCyan
    Write-Host '  USB 3.1 device (~400 MB/s): ' -NoNewline -ForegroundColor White
    Write-Host (Format-ApproximateTransferDuration -TotalBytes $grandBytesLong -BytesPerSecond $usb31bps) -ForegroundColor DarkCyan
    Write-Host '  1 Gbit network (~100 MB/s): ' -NoNewline -ForegroundColor White
    Write-Host (Format-ApproximateTransferDuration -TotalBytes $grandBytesLong -BytesPerSecond $lan1gBps) -ForegroundColor DarkCyan
    Write-Host ''

    $logLines.Add('') | Out-Null
    $logLines.Add('Approximate full copy times (does not have extraction times into account):') | Out-Null
    $logLines.Add(('  USB 2.0 device (~35 MB/s): ' + (Format-ApproximateTransferDuration -TotalBytes $grandBytesLong -BytesPerSecond $usb2bps))) | Out-Null
    $logLines.Add(('  USB 3.0 device (~200 MB/s): ' + (Format-ApproximateTransferDuration -TotalBytes $grandBytesLong -BytesPerSecond $usb30bps))) | Out-Null
    $logLines.Add(('  USB 3.1 device (~400 MB/s): ' + (Format-ApproximateTransferDuration -TotalBytes $grandBytesLong -BytesPerSecond $usb31bps))) | Out-Null
    $logLines.Add(('  1 Gbit network (~100 MB/s): ' + (Format-ApproximateTransferDuration -TotalBytes $grandBytesLong -BytesPerSecond $lan1gBps))) | Out-Null

    $summaryDir = Join-Path $ScriptRoot 'summaries'
    if (-not (Test-Path -LiteralPath $summaryDir -PathType Container)) {
        New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
    }
    $logFileName = ('enabled-{0}.log' -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
    $summaryPath = Join-Path $summaryDir $logFileName
    try {
        $logLines | Set-Content -LiteralPath $summaryPath -Encoding utf8
        Write-Host ('Summary log: ' + (Format-PathForDisplay $summaryPath)) -ForegroundColor DarkCyan
    }
    catch {
        Write-Warn ("Could not write summary log: {0}" -f $_.Exception.Message)
    }
    Write-Host ''
}

function Invoke-GamePopulatorSourceManagementMenu {
    while ($true) {
        Write-Host ""
        Write-Host "Source management:" -ForegroundColor Cyan
        Write-Host "  1. Official consoles" -ForegroundColor White
        Write-Host "  2. Game Hacks + Improvements" -ForegroundColor White
        Write-Host "  3. Game Translations" -ForegroundColor White
        Write-Host "  4. Add-ons (music files)" -ForegroundColor White
        Write-Host "  5. Estimated file counts and disk space (enabled systems)" -ForegroundColor White
        Write-Host ""
        Invoke-OutputFlush
        $pickCat = (Read-Host "Select 1-5 or [Enter] to go back").Trim()
        if ([string]::IsNullOrWhiteSpace($pickCat) -or $pickCat -match '^(?i)q$') {
            Write-Host ""
            return
        }
        switch ($pickCat) {
            '1' {
                Invoke-TurnOnOffSystemsMenu -SourcesLiteralPath $consolePath -SourcesFileDisplayName 'libraries\console-sources.psd1' -DisplayNameMap $consoleDisplayNameMap
            }
            '2' {
                Invoke-TurnOnOffSystemsMenu -SourcesLiteralPath $hacksSourcesPath -SourcesFileDisplayName 'libraries\hacks-sources.psd1' -DisplayNameMap $consoleDisplayNameMap
            }
            '3' {
                Invoke-TurnOnOffSystemsMenu -SourcesLiteralPath $transSourcesPath -SourcesFileDisplayName 'libraries\trans-sources.psd1' -DisplayNameMap $consoleDisplayNameMap
            }
            '4' {
                Invoke-TurnOnOffSystemsMenu -SourcesLiteralPath $addonsSourcesPath -SourcesFileDisplayName 'libraries\addons-sources.psd1' -DisplayNameMap $consoleDisplayNameMap
            }
            '5' {
                Invoke-GamePopulatorGroupedEnabledSourcesStorageReport `
                    -ScriptRoot $scriptRoot `
                    -DisplayNameMap $consoleDisplayNameMap `
                    -SettingsForArchive $settings `
                    -ConsoleSourcesLiteralPath $consolePath `
                    -HacksSourcesLiteralPath $hacksSourcesPath `
                    -TransSourcesLiteralPath $transSourcesPath `
                    -AddonsSourcesLiteralPath $addonsSourcesPath `
                    -ConsoleExtensionsMap $consoleExtensionsMap
            }
            default {
                Write-Warn "Invalid selection. Enter 1, 2, 3, 4, 5, or Q."
            }
        }
    }
}

function Invoke-TurnOnOffSystemsMenu {
    param(
        [Parameter(Mandatory)][string]$SourcesLiteralPath,
        [Parameter(Mandatory)][string]$SourcesFileDisplayName,
        [hashtable]$DisplayNameMap
    )
    while ($true) {
        $enabledBlocks = @(Get-SourcesPsd1EnabledEntries -LiteralPath $SourcesLiteralPath)
        $disabledBlocks = @(Get-SourcesPsd1CommentedBlocks -LiteralPath $SourcesLiteralPath)
        Write-Host ""
        Write-Host ("  {0,-21}" -f "Enabled systems:") -NoNewline -ForegroundColor DarkCyan
        Write-Host $enabledBlocks.Count -ForegroundColor DarkYellow
        Write-Host ("  {0,-21}" -f "Disabled systems:") -NoNewline -ForegroundColor DarkCyan
        Write-Host $disabledBlocks.Count -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host "  1. Toggle systems on or off." -ForegroundColor White
        Write-Host "  2. Change a system's source path." -ForegroundColor White
        Write-Host "  Q. Previous Menu" -ForegroundColor White
        Write-Host ""
        Invoke-OutputFlush
        $sub = (Read-Host "Select 1-2, [Enter] to go back").Trim()
        if ([string]::IsNullOrWhiteSpace($sub) -or $sub -match '^(?i)q$') {
            Write-Host ""
            Write-Host ""
            break
        }
        switch ($sub) {
            '1' {
                $snapToggle = @()
                $paintToggleList = $true
                while ($true) {
                    if ($paintToggleList) {
                        Write-Host ''
                        Write-Host '  Enabled   = white' -ForegroundColor White
                        Write-Host '  Disabled  = red' -ForegroundColor Red
                        Write-Host ''
                        Write-Host '  Defined Systems:' -ForegroundColor DarkCyan
                        $snapToggle = @(Get-SourcesPsd1UnifiedAlphabetical -LiteralPath $SourcesLiteralPath -DisplayNameMap $DisplayNameMap)
                        if ($snapToggle.Count -eq 0) {
                            Write-Warn "No consoles found in sources file."
                            break
                        }
                        Write-NumberedSourcesConsoleBlockList -Blocks $snapToggle -DisplayNameMap $DisplayNameMap -ColorEnabledState
                        $paintToggleList = $false
                    }
                    Write-Host 'Numbers (comma-separated)' -NoNewline -ForegroundColor White
                    Write-Host ' toggle enabled/disabled status. ' -NoNewline -ForegroundColor DarkCyan
                    Write-Host '(ex. ' -NoNewline -ForegroundColor DarkCyan
                    Write-Host '1, 4, 16...' -NoNewline -ForegroundColor White
                    Write-Host ')' -ForegroundColor DarkCyan
                    Write-Host 'AO' -NoNewline -ForegroundColor White
                    Write-Host ' enables all systems · ' -NoNewline -ForegroundColor DarkCyan
                    Write-Host 'AF' -NoNewline -ForegroundColor White
                    Write-Host ' disables all systems' -ForegroundColor DarkCyan
                    Write-Host 'R' -NoNewline -ForegroundColor White
                    Write-Host ' refreshes the list · ' -NoNewline -ForegroundColor DarkCyan
                    Write-Host 'Q' -NoNewline -ForegroundColor White
                    Write-Host ' returns to the previous menu.' -ForegroundColor DarkCyan
                    Write-Host ''
                    Invoke-OutputFlush
                    $rawMain = Read-Host 'Number(s), AO, AF, R, Q, or [Enter] to [Q]uit'
                    if ($null -eq $rawMain) { $rawMain = '' }
                    $rawTrim = $rawMain.Trim()
                    if ([string]::IsNullOrWhiteSpace($rawTrim) -or $rawTrim -match '^(?i)q$') {
                        break
                    }
                    if ($rawTrim -match '^(?i)r$') {
                        $paintToggleList = $true
                        continue
                    }
                    if ($rawTrim -match '^(?i)ao$') {
                        $nOn = 0
                        foreach ($picked in $snapToggle) {
                            if ($picked.Enabled) { continue }
                            if (Enable-SourcesPsd1ConsoleBlock -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$picked.Name) -SourcesFileDisplayName $SourcesFileDisplayName) {
                                $picked.Enabled = $true
                                $nOn++
                            }
                        }
                        if ($nOn -gt 0) {
                            Update-GamePopulatorConsoleSourcesState
                            Write-Info ("Enabled {0} system(s)." -f $nOn)
                        }
                        else {
                            Write-Info 'All systems were already enabled.'
                        }
                        Write-Host ''
                        continue
                    }
                    if ($rawTrim -match '^(?i)af$') {
                        $nOff = 0
                        foreach ($picked in $snapToggle) {
                            if (-not $picked.Enabled) { continue }
                            if (Disable-SourcesPsd1ConsoleBlock -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$picked.Name) -SourcesFileDisplayName $SourcesFileDisplayName) {
                                $picked.Enabled = $false
                                $nOff++
                            }
                        }
                        if ($nOff -gt 0) {
                            Update-GamePopulatorConsoleSourcesState
                            Write-Info ("Disabled {0} system(s)." -f $nOff)
                        }
                        else {
                            Write-Info 'All systems were already disabled.'
                        }
                        Write-Host ''
                        continue
                    }
                    $parts = @($rawTrim -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                    if (@($parts).Count -eq 0) {
                        Write-Warn 'Enter numbers separated by commas, AO or AF for all on/off, R to refresh the list, or Q / Enter for the previous menu.'
                        continue
                    }
                    foreach ($tok in @($parts)) {
                        $num = 0
                        if (-not [int]::TryParse($tok, [ref]$num)) {
                            Write-Warn ('Not a whole number (skipped): "{0}".' -f $tok)
                            continue
                        }
                        if ($num -lt 1 -or $num -gt $snapToggle.Count) {
                            Write-Warn ('"{0}" is out of range; use 1-{1}.' -f $tok, $snapToggle.Count)
                            continue
                        }
                        $picked = $snapToggle[$num - 1]
                        if ($picked.Enabled) {
                            if (Disable-SourcesPsd1ConsoleBlock -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$picked.Name) -SourcesFileDisplayName $SourcesFileDisplayName) {
                                Write-Info ('Disabled System: {0}' -f $picked.Display)
                                Update-GamePopulatorConsoleSourcesState
                                $picked.Enabled = $false
                            }
                        }
                        elseif (Enable-SourcesPsd1ConsoleBlock -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$picked.Name) -SourcesFileDisplayName $SourcesFileDisplayName) {
                            Write-Info ('Enabled System: {0}' -f $picked.Display)
                            Update-GamePopulatorConsoleSourcesState
                            $picked.Enabled = $true
                        }
                    }
                    Write-Host ''
                }
            }
            '2' {
                $snapPath = @()
                $paintPathList = $true
                while ($true) {
                    if ($paintPathList) {
                        Write-Host ''
                        Write-Host '  Enabled   = white' -ForegroundColor White
                        Write-Host '  Disabled  = red' -ForegroundColor Red
                        Write-Host ''
                        Write-Host '  Defined Systems:' -ForegroundColor DarkCyan
                        $snapPath = @(Get-SourcesPsd1UnifiedAlphabetical -LiteralPath $SourcesLiteralPath -DisplayNameMap $DisplayNameMap)
                        if ($snapPath.Count -eq 0) {
                            Write-Warn 'No consoles found in sources file.'
                            break
                        }
                        Write-NumberedSourcesConsoleBlockList -Blocks $snapPath -DisplayNameMap $DisplayNameMap -ColorEnabledState
                        $paintPathList = $false
                    }
                    Write-Host 'Enter ' -NoNewline -ForegroundColor DarkCyan
                    Write-Host 'console number' -NoNewline -ForegroundColor White
                    Write-Host ' · ' -NoNewline -ForegroundColor DarkCyan
                    Write-Host 'R' -NoNewline -ForegroundColor White
                    Write-Host ' refreshes the list · ' -NoNewline -ForegroundColor DarkCyan
                    Write-Host 'Q' -NoNewline -ForegroundColor White
                    Write-Host ' returns to the previous menu.' -ForegroundColor DarkCyan
                    Write-Host ''
                    Invoke-OutputFlush
                    $rawPick = Read-Host 'Number, R, Q, or [Enter] to [Q]uit'
                    if ($null -eq $rawPick) { $rawPick = '' }
                    $pickTrim = $rawPick.Trim()
                    if ([string]::IsNullOrWhiteSpace($pickTrim) -or $pickTrim -match '^(?i)q$') {
                        break
                    }
                    if ($pickTrim -match '^(?i)r$') {
                        $paintPathList = $true
                        continue
                    }
                    $numPick = 0
                    if (-not [int]::TryParse($pickTrim, [ref]$numPick)) {
                        Write-Warn 'Enter a whole number, R, Q, or [Enter] to go back.'
                        continue
                    }
                    if ($numPick -lt 1 -or $numPick -gt $snapPath.Count) {
                        Write-Warn ('Only 1-{0} are valid numbers, R, Q, or [Enter] to go back.' -f $snapPath.Count)
                        continue
                    }
                    $sys = $snapPath[$numPick - 1]
                    $abortOption4AfterPathMenu = $false
                    while ($true) {
                        Write-Host ''
                        Write-Host ('  {0}' -f $sys.Display) -ForegroundColor DarkCyan
                        $pathDisp = ''
                        if ($null -ne $sys.SourcePath) {
                            $pathDisp = ([string]$sys.SourcePath).Trim()
                        }
                        if ([string]::IsNullOrWhiteSpace($pathDisp)) {
                            Write-Host '  Current SourcePath: (none)' -ForegroundColor DarkYellow
                        }
                        else {
                            Write-Host ('  Current SourcePath: {0}' -f (Format-PathForDisplay $pathDisp)) -ForegroundColor White
                        }
                        Write-Host '  Pressing Enter (without a value) returns to the list without changes · [Q] returns to the previous menu.' -ForegroundColor DarkGray
                        Invoke-OutputFlush
                        $newSrc = Read-Host '  New SourcePath'
                        if ($null -eq $newSrc) { $newSrc = '' }
                        $nts = $newSrc.Trim()
                        if ([string]::IsNullOrWhiteSpace($nts)) {
                            Write-Host ''
                            break
                        }
                        if ($nts -match '^(?i)q$') {
                            $abortOption4AfterPathMenu = $true
                            break
                        }
                        if (Update-SourcesPsd1ConsoleSourcePath -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$sys.Name) -NewSourcePath $nts -SourcesFileDisplayName $SourcesFileDisplayName) {
                            Write-Host ('  Updated SourcePath for {0}' -f $sys.Display) -ForegroundColor Yellow
                            Write-Host ''
                            Update-GamePopulatorConsoleSourcesState
                            $sys.SourcePath = [string]$nts
                            break
                        }
                    }
                    if ($abortOption4AfterPathMenu) {
                        break
                    }
                }
            }
            default {
                Write-Warn "Select 1-2, [Enter] to go back."
            }
        }
    }
}

function Format-SettingsJsonValueForDisplay {
    param($Value)
    if ($null -eq $Value) { return '(null)' }
    if ($Value -is [SecureString]) {
        $bptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
        try {
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bptr)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bptr)
        }
        if ([string]::IsNullOrWhiteSpace($plain)) { return '(empty)' }
        return $plain
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @(foreach ($x in $Value) { $x.ToString().Trim() })
        return '[' + (($items | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ']'
    }
    $t = $Value.ToString()
    if ([string]::IsNullOrWhiteSpace($t)) { return '(empty)' }
    return $t
}

function Set-GamePopulatorSharePasswordAsSecure {
    param([Parameter(Mandatory)][object]$SettingsObj)
    if (-not ($SettingsObj.PSObject.Properties.Name -contains 'SharePassword')) { return }
    $v = $SettingsObj.SharePassword
    if ($null -eq $v) { return }
    if ($v -is [SecureString]) { return }
    $pwdStr = $v.ToString()
    if ([string]::IsNullOrWhiteSpace($pwdStr)) { return }
    $SettingsObj.SharePassword = ConvertTo-SecureString $pwdStr -AsPlainText -Force
}

function Get-GamePopulatorSettingsFieldLabel {
    param([Parameter(Mandatory)][string]$PropertyName)
    switch ($PropertyName) {
        'DestinationRoot' { return 'Destination' }
        'TempRoot' { return 'Temporary Files' }
        'MaxFilesPerFolder' { return 'Max Files Per Folder' }
        'MaxConcurrentFileCopies' { return 'Concurrent file copies per console (1-4)' }
        'StructuredRunLog' { return 'Enable Write Structured NDJSON' }
        'UseRunCheckpoint' { return 'Enable Resume Checkpoint Log' }
        'ShareUser' { return 'Network Share Name' }
        'SharePassword' { return 'Network Share Password' }
        default { return $PropertyName }
    }
}

function Invoke-EditSettingsJsonMenu {
    param(
        [Parameter(Mandatory = $true)][string]$SettingsLiteralPath,
        [Parameter(Mandatory = $true)][ref]$SettingsRef
    )
    while ($true) {
        Write-Host ""
        $rawJson = $null
        try {
            $rawJson = Get-Content -LiteralPath $SettingsLiteralPath -Raw
        }
        catch {
            Write-Warn "Could not read settings file: $($_.Exception.Message)"
            return
        }
        $view = $null
        try {
            $view = $rawJson | ConvertFrom-Json
        }
        catch {
            Write-Warn "Settings JSON is invalid: $($_.Exception.Message)"
            return
        }
        $ordered = [ordered]@{}
        foreach ($p in @($view.PSObject.Properties)) {
            $ordered[$p.Name] = $p.Value
        }
        if (@($ordered.Keys) -contains 'MaxParallelConsoles') {
            $null = $ordered.Remove('MaxParallelConsoles')
            try {
                ($ordered | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $SettingsLiteralPath -Encoding utf8
                Write-Info 'Removed deprecated MaxParallelConsoles from libraries\settings.json. Use MaxConcurrentFileCopies (1-4) for parallel file copies within each console.'
                try {
                    $freshDep = Get-Content -LiteralPath $SettingsLiteralPath -Raw | ConvertFrom-Json
                    Set-GamePopulatorSharePasswordAsSecure -SettingsObj $freshDep
                    $SettingsRef.Value = $freshDep
                }
                catch {
                }
                continue
            }
            catch {
                Write-Warn ('Could not remove deprecated MaxParallelConsoles key: {0}' -f $_.Exception.Message)
            }
        }
        if (@($ordered.Keys) -contains 'MaxConcurrentFileCopies') {
            try {
                $capMenuProbe = ([string]$ordered['MaxConcurrentFileCopies']).Trim()
                if (-not [string]::IsNullOrWhiteSpace($capMenuProbe)) {
                    $capMenuParsed = [int]$ordered['MaxConcurrentFileCopies']
                    if ($capMenuParsed -gt 4) {
                        $ordered['MaxConcurrentFileCopies'] = 4
                        try {
                            $jsonCapMenu = $ordered | ConvertTo-Json -Depth 10
                            $jsonCapMenu | Set-Content -LiteralPath $SettingsLiteralPath -Encoding utf8
                            Write-Info 'MaxConcurrentFileCopies exceeded 4; saved corrected value (4) to settings.'
                            try {
                                $freshCap = Get-Content -LiteralPath $SettingsLiteralPath -Raw | ConvertFrom-Json
                                Set-GamePopulatorSharePasswordAsSecure -SettingsObj $freshCap
                                $SettingsRef.Value = $freshCap
                            }
                            catch {
                            }
                            continue
                        }
                        catch {
                            Write-Warn "Could not save corrected MaxConcurrentFileCopies: $($_.Exception.Message)"
                        }
                    }
                }
            }
            catch {
            }
        }
        $skipEditKeys = [string[]]@('SevenZipExe', 'ArchiveExtensions')
        $names = [string[]]@(
            foreach ($k in [string[]]@($ordered.Keys)) {
                if ($k -in $skipEditKeys) { continue }
                $k
            }
        )
        $nameColW = 0
        foreach ($kn in $names) {
            $lab = Get-GamePopulatorSettingsFieldLabel -PropertyName $kn
            if ($lab.Length -gt $nameColW) { $nameColW = $lab.Length }
        }
        if ($nameColW -lt 8) { $nameColW = 8 }
        for ($i = 0; $i -lt $names.Count; $i++) {
            $n = $names[$i]
            $num = $i + 1
            $disp = Format-SettingsJsonValueForDisplay -Value $ordered[$n]
            $label = Get-GamePopulatorSettingsFieldLabel -PropertyName $n
            Write-Host ('  ' + ([string]$num).PadLeft(2) + '. ' + ([string]$label).PadRight($nameColW) + '  ') -NoNewline -ForegroundColor White
            Write-Host $disp -ForegroundColor Green
        }
        Write-Host ""
        Invoke-OutputFlush
        $pick = (Read-Host "Number, or [Enter] to [Q]uit").Trim()
        if ([string]::IsNullOrWhiteSpace($pick) -or $pick -match '^(?i)q(uit)?$') {
            return
        }
        if ($pick -notmatch '^\d+$') {
            Write-Warn "Enter a number, or Q to go back."
            continue
        }
        $sel = [int]$pick
        if ($sel -lt 1 -or $sel -gt $names.Count) {
            Write-Warn ("Choose 1-{0}, or Q." -f $names.Count)
            continue
        }
        $propName = $names[$sel - 1]
        $dirty = $false
        switch ($propName) {
            'MaxConcurrentFileCopies' {
                Write-Host 'Whole number from 1 to 4 ([Enter] leaves unchanged).' -ForegroundColor DarkGray
                $fieldLabelCc = Get-GamePopulatorSettingsFieldLabel -PropertyName $propName
                $inpCc = Read-Host ("New value for {0}" -f $fieldLabelCc)
                if ($null -eq $inpCc) { $inpCc = '' }
                $inpCc = $inpCc.Trim()
                if ([string]::IsNullOrWhiteSpace($inpCc)) {
                    continue
                }
                $enteredCc = 0
                if (-not ([int]::TryParse($inpCc, [ref]$enteredCc))) {
                    Write-Warn 'Enter a whole number from 1 to 4.'
                    continue
                }
                $clampedCc = [Math]::Max(1, [Math]::Min(4, $enteredCc))
                if ($clampedCc -ne $enteredCc) {
                    Write-Host ("Entered {0} is outside 1-4 — using {1}." -f $enteredCc, $clampedCc) -ForegroundColor DarkYellow
                }
                $ordered[$propName] = $clampedCc
                $dirty = $true
            }
            'SharePassword' {
                Write-Host 'Stored as plain text in JSON. Type clear to remove the password. [Enter] leaves it unchanged.' -ForegroundColor DarkGray
                $inp = Read-Host 'New Network Share Password'
                if ($null -eq $inp) {
                    continue
                }
                $inp = $inp.Trim()
                if (($inp.Length -eq 0)) {
                    # unchanged
                }
                elseif ($inp -match '^(?i)clear$') {
                    $ordered[$propName] = ''
                    $dirty = $true
                }
                else {
                    $ordered[$propName] = $inp
                    $dirty = $true
                }
            }
            default {
                $fieldLabel = Get-GamePopulatorSettingsFieldLabel -PropertyName $propName
                $inp = Read-Host ("New value for {0} [Enter unchanged]" -f $fieldLabel)
                if ($null -eq $inp) { $inp = '' }
                $inp = $inp.Trim()
                if (-not [string]::IsNullOrWhiteSpace($inp)) {
                    $ordered[$propName] = $inp
                    $dirty = $true
                }
            }
        }
        if (-not $dirty) {
            continue
        }
        try {
            $jsonOut = $ordered | ConvertTo-Json -Depth 10
            $jsonOut | Set-Content -LiteralPath $SettingsLiteralPath -Encoding utf8
        }
        catch {
            Write-Warn "Could not save settings: $($_.Exception.Message)"
            continue
        }
        try {
            $fresh = Get-Content -LiteralPath $SettingsLiteralPath -Raw | ConvertFrom-Json
            Set-GamePopulatorSharePasswordAsSecure -SettingsObj $fresh
            $SettingsRef.Value = $fresh
        }
        catch {
            Write-Warn "Saved file, but reload failed: $($_.Exception.Message)"
        }
        Write-Info "Changes saved."
    }
}

function Invoke-GamePopulatorConfigurationValidationReport {
    Write-Host ''
    Write-Host '=== Configuration validation ===' -ForegroundColor Cyan
    $issueCount = 0
    $helpersLit = Join-Path $librariesRoot 'helpers.ps1'
    if (-not (Test-Path -LiteralPath $helpersLit -PathType Leaf)) {
        Write-Host '[x] Missing libraries\helpers.ps1' -ForegroundColor Red
        $issueCount++
    }
    else {
        Write-Host '[ok] libraries\helpers.ps1' -ForegroundColor DarkGreen
    }
    foreach ($pp in @($script:GamePopulatorSourcesPaths)) {
        $leaf = Split-Path $pp -Leaf
        if (-not (Test-Path -LiteralPath $pp -PathType Leaf)) {
            Write-Host ("[x] Missing {0}" -f $leaf) -ForegroundColor Red
            $issueCount++
            continue
        }
        try {
            $null = Import-PowerShellDataFile -LiteralPath $pp -ErrorAction Stop
            Write-Host ("[ok] {0} (valid PSD1)" -f $leaf) -ForegroundColor DarkGreen
        }
        catch {
            Write-Host ("[x] {0} — {1}" -f $leaf, $_.Exception.Message) -ForegroundColor Red
            $issueCount++
        }
    }
    foreach ($pp in @($script:GamePopulatorNamesPaths)) {
        $leaf = Split-Path $pp -Leaf
        if (-not (Test-Path -LiteralPath $pp -PathType Leaf)) {
            Write-Host ("[x] Missing {0}" -f $leaf) -ForegroundColor Red
            $issueCount++
            continue
        }
        try {
            $null = Get-Content -LiteralPath $pp -Raw -ErrorAction Stop | ConvertFrom-Json
            Write-Host ("[ok] {0} (valid JSON)" -f $leaf) -ForegroundColor DarkGreen
        }
        catch {
            Write-Host ("[x] {0} — {1}" -f $leaf, $_.Exception.Message) -ForegroundColor Red
            $issueCount++
        }
    }
    $szPath = ''
    if ($settings.PSObject.Properties['SevenZipExe'] -and $null -ne $settings.SevenZipExe) {
        $szPath = ([string]$settings.SevenZipExe).Trim()
    }
    if ($szPath -and -not (Test-Path -LiteralPath $szPath -PathType Leaf)) {
        Write-Host '[!] SevenZipExe path not found — reports use archive size on disk.' -ForegroundColor DarkYellow
    }
    elseif ($szPath) {
        Write-Host '[ok] SevenZipExe' -ForegroundColor DarkGreen
    }
    if (-not (Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $DestinationRoot)) {
        Write-Host '[x] Destination root is not reachable' -ForegroundColor Red
        Write-Host ("       {0}" -f (Format-PathForDisplay $DestinationRoot)) -ForegroundColor DarkYellow
        Write-Host ("       Set DestinationRoot in {0} (labeled Destination in the editor)." -f (Format-PathForDisplay $settingsPath)) -ForegroundColor DarkGray
        Write-Host '       Use main menu 2 (Define script settings). For UNC/SMB shares, try main menu 6 (Reset network SMB connections).' -ForegroundColor DarkGray
        $issueCount++
    }
    else {
        Write-Host '[ok] Destination root reachable' -ForegroundColor DarkGreen
    }
    foreach ($c in @($allConsoles | Where-Object {
                $_ `
                    -and (Test-GamePopulatorMergedSourceEntryEnabled $_) `
                    -and -not [string]::IsNullOrWhiteSpace($_.Name) `
                    -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
            })) {
        $ck = $c.Name.ToLowerInvariant()
        if (-not $consoleNameMap.ContainsKey($ck)) {
            Write-Host ("[x] Source '{0}' has no matching Name in merged names JSON" -f $c.Name) -ForegroundColor Red
            $issueCount++
        }
    }
    Write-Host ''
    if ($issueCount -eq 0) {
        Write-Host 'Validation finished with no blocking issues.' -ForegroundColor Cyan
    }
    else {
        Write-Host ("Validation reported {0} blocking issue(s)." -f $issueCount) -ForegroundColor Yellow
    }
    Write-Host ''
}

function Invoke-GamePopulatorActiveSourceLocationsValidationReport {
    Write-Host ''
    Write-Host '=== Active sources (folder preflight + SMB, same as migrate preflight) ===' -ForegroundColor Cyan

    $nameMapIssueCount = 0
    $folderUnreachableMsg = 'Folder unreachable (offline, wrong path, or no SMB visibility)'

    $logsParentDir = Join-Path $scriptRoot 'logs'
    if (-not (Test-Path -LiteralPath $logsParentDir -PathType Container)) {
        New-Item -Path $logsParentDir -ItemType Directory -Force | Out-Null
    }
    $gpVcGuardCacheLit = Join-Path $logsParentDir 'gp-source-verification-cache.json'

    $checked = @($allConsoles | Where-Object {
            $_ `
                -and (Test-GamePopulatorMergedSourceEntryEnabled $_) `
                -and -not [string]::IsNullOrWhiteSpace($_.Name) `
                -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
        })
    if ($checked.Count -eq 0) {
        Write-Host '[i] No enabled sources with paths (nothing to validate).' -ForegroundColor DarkGray
        Remove-GpSourceVerificationGuardCacheSilently -CacheLiteralPath $gpVcGuardCacheLit
        Write-Host ''
        return
    }

    $validatedForProbe = [System.Collections.Generic.List[object]]::new()
    foreach ($c in @($checked)) {
        $ck = $c.Name.ToLowerInvariant()
        $disp = if ($consoleDisplayNameMap.ContainsKey($ck) -and $consoleDisplayNameMap[$ck]) {
            [string]$consoleDisplayNameMap[$ck]
        }
        else {
            $c.Name
        }
        if (-not $consoleNameMap.ContainsKey($ck)) {
            Write-Host ("[x] {0}: source Name is missing from merged names JSON" -f $disp) -ForegroundColor Red
            $nameMapIssueCount++
            continue
        }
        $validatedForProbe.Add($c) | Out-Null
    }

    if ($validatedForProbe.Count -eq 0) {
        Remove-GpSourceVerificationGuardCacheSilently -CacheLiteralPath $gpVcGuardCacheLit
        Write-Host '[i] No sources could be validated (every enabled entry lacks a merged names mapping).' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    Write-Host '[i] Using Share credentials from libraries\settings.json (SMB probe matches migrate).' -ForegroundColor DarkYellow
    Invoke-OutputFlush

    $probePack = Invoke-GpTestEnabledConsoleSharesReachability -Sources @($validatedForProbe) `
        -ShareUserArg ($settings.ShareUser) `
        -SharePasswordArg $settings.SharePassword

    if ($probePack.DidDisableUnreachableDuringProbe) {
        Update-GamePopulatorConsoleSourcesState
        Write-Host '[i] Commented-out (disabled) unreachable sources were written to libraries\*-sources.psd1; merged lists reloaded.' -ForegroundColor DarkGray
    }

    $unreachableByCk = @{}
    foreach ($u in @($probePack.Unreachable)) {
        $nkKey = (($u['Name']).ToString()).Trim().ToLowerInvariant()
        $unreachableByCk[$nkKey] = $u
    }
    $reachableNameSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($rItem in @($probePack.Reachable)) {
        [void]$reachableNameSet.Add((($rItem.Name).ToString()).Trim().ToLowerInvariant())
    }

    foreach ($c in @($validatedForProbe)) {
        $rk = (($c.Name).ToString()).Trim().ToLowerInvariant()
        $disp = if ($consoleDisplayNameMap.ContainsKey($rk) -and $consoleDisplayNameMap[$rk]) {
            [string]$consoleDisplayNameMap[$rk]
        }
        else {
            $c.Name
        }
        $rpDisp = Resolve-DestinationPath -Path (($c.SourcePath.ToString()).Trim())
        $pathDisp = Format-PathForDisplay $rpDisp
        if ($null -ne $unreachableByCk[$rk]) {
            $ur = $unreachableByCk[$rk]
            $errPart = if ($null -ne $ur.Error -and -not [string]::IsNullOrWhiteSpace(([string]$ur.Error))) {
                ': ' + [string]$ur.Error
            }
            else {
                ''
            }
            Write-Host ("[x] {0}{1}" -f $disp, $errPart) -ForegroundColor Red
            Write-Host ('       {0}' -f $pathDisp) -ForegroundColor DarkYellow
        }
        elseif ($reachableNameSet.Contains($rk)) {
            Write-Host ("[ok] {0}" -f $disp) -ForegroundColor DarkGreen
            Write-Host ('       {0}' -f $pathDisp) -ForegroundColor DarkGray
        }
        else {
            Write-Host ("[x] {0}: could not classify probe result." -f $disp) -ForegroundColor Red
        }
    }

    Write-Host ''

    $autoDisabledListed = @(foreach ($uq in @($probePack.Unreachable)) {
            if (($uq['Error']).ToString() -eq $folderUnreachableMsg) {
                ($uq['Name']).ToString()
            }
        })
    $autoDisabledCount = $autoDisabledListed.Count
    if (-not ([bool]$probePack.DidDisableUnreachableDuringProbe)) {
        $autoDisabledCount = 0
    }

    $issueTotal = $nameMapIssueCount + @($probePack.Unreachable).Count
    $snapSourcesForSeal = @( $script:allConsoles | Where-Object {
            $_ `
                -and (Test-GamePopulatorMergedSourceEntryEnabled $_) `
                -and -not [string]::IsNullOrWhiteSpace($_.Name) `
                -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
        })
    $fingerSeal = Get-GpSourceVerificationGuardFingerprintSha256Hex -Sources $snapSourcesForSeal -ShareUserRaw $settings.ShareUser -GamePopulatorSettingsLiteralPath $settingsPath
    if (($nameMapIssueCount -eq 0) -and (@($probePack.Unreachable).Count -eq 0) -and (-not $probePack.DidDisableUnreachableDuringProbe)) {
        Save-GpSourceVerificationGuardCache -CacheLiteralPath $gpVcGuardCacheLit -FingerprintSha256Hex $fingerSeal
        Write-Host 'All enabled sources passed folder checks and SMB access. Verification cached for migrate preflight reuse (until any enabled SourcePath or settings change).' -ForegroundColor DarkYellow
        Write-Host ("       Cache file: {0}" -f (Format-PathForDisplay $gpVcGuardCacheLit)) -ForegroundColor DarkGray
    }
    else {
        Remove-GpSourceVerificationGuardCacheSilently -CacheLiteralPath $gpVcGuardCacheLit
        if (($nameMapIssueCount -eq 0) -and (@($probePack.Unreachable).Count -gt 0)) {
            Write-Host ("{0} source(s) failed folder or SMB checks." -f @($probePack.Unreachable).Count) -ForegroundColor Yellow
            if ($autoDisabledCount -gt 0) {
                Write-Host ('Folder-unreachable entries: {0} (comment/disable in PSD1 attempted where possible).' -f $autoDisabledCount) -ForegroundColor DarkGray
            }
            Write-Host 'Adjust paths via main menu 1, libraries\settings.json, or reset SMB/network (main menu 6).' -ForegroundColor DarkGray
        }
        else {
            Write-Host ('{0} issue(s): names-mapping problems and/or connectivity failures — fix merged names JSON and rerun.' -f $issueTotal) -ForegroundColor Yellow
        }
    }
    Write-Host ''
}

function Get-GpUniqueMergedSourcesRowsForInteractivePick {
    param(
        [Parameter(Mandatory)][AllowNull()]$AllConsolesValue
    )
    $lookup = @{}
    foreach ($row in @($AllConsolesValue)) {
        if (-not $row -or [string]::IsNullOrWhiteSpace(([string]$row.Name))) {
            continue
        }
        $k = ([string]$row.Name).Trim().ToLowerInvariant()
        if (-not $lookup.ContainsKey($k)) {
            $lookup[$k] = $row
            continue
        }
        $ex = $lookup[$k]
        $exPathRaw = ''
        if ($null -ne $ex.SourcePath) {
            try {
                $exPathRaw = ($ex.SourcePath.ToString()).Trim()
            }
            catch { }
        }
        $newPathRaw = ''
        if ($null -ne $row.SourcePath) {
            try {
                $newPathRaw = ($row.SourcePath.ToString()).Trim()
            }
            catch { }
        }
        if ([string]::IsNullOrWhiteSpace($exPathRaw) -and -not [string]::IsNullOrWhiteSpace($newPathRaw)) {
            $lookup[$k] = $row
        }
    }
    @(foreach ($k in ($lookup.Keys | Sort-Object)) { $lookup[$k] })
}

function Invoke-GpSingleSystemMigrateInteractiveWizard {
    param(
        [Parameter(Mandatory)][hashtable]$DisplayNameMap,
        [Parameter(Mandatory)][string]$DestinationRootRaw,
        [Parameter(Mandatory)][string]$ShareUser,
        [Parameter(Mandatory)][SecureString]$SharePassword,
        [Parameter(Mandatory)][AllowNull()]$ConsoleOpticalDisplaySetHashSetObj,
        [Parameter(Mandatory)][AllowNull()]$AllConsolesMerged
    )
    $rowsRaw = @(Get-GpUniqueMergedSourcesRowsForInteractivePick -AllConsolesValue $AllConsolesMerged)
    if ($null -eq $rowsRaw -or @($rowsRaw).Count -eq 0) {
        Write-Host '[i] No systems are defined under libraries\*-sources.psd1.' -ForegroundColor DarkYellow
        return $null
    }
    $rows = @(foreach ($rw in @($rowsRaw)) {
            $sx = ''
            if ($null -ne $rw.SourcePath) { $sx = ($rw.SourcePath.ToString()).Trim() }
            if ([string]::IsNullOrWhiteSpace($sx)) { continue }
            [pscustomobject]@{
                Name       = ([string]$rw.Name).Trim()
                SourcePath = $rw.SourcePath
                Enabled    = [bool](Test-GamePopulatorMergedSourceEntryEnabled $rw)
            }
        })
    if ($rows.Count -eq 0) {
        Write-Host '[i] Every merged PSD1 row is missing SourcePath.' -ForegroundColor DarkYellow
        return $null
    }
    $prepPickSs = Get-GpNumberedSortedSourceBlocksForConsoleList -Blocks $rows -DisplayNameMap $DisplayNameMap
    if ($prepPickSs.Count -eq 0) {
        Write-Host '[i] No systems listed for single-system picker.' -ForegroundColor DarkYellow
        return $null
    }

    Write-Host ''
    Write-Host '=== Single system populate ===' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host '  Defined Systems:' -ForegroundColor DarkCyan
    Write-GpNumberedSourceConsoleList -Numbered $prepPickSs.Numbered -ColorEnabledState
    Invoke-OutputFlush

    $pickSsCount = [int]$prepPickSs.Count
    $numberedPickSs = @($prepPickSs.Numbered)
    $pickIx = -1
    while ($pickIx -lt 1 -or $pickIx -gt $pickSsCount) {
        $tok = (Read-Host ('Pick 1-{0}, Q, or [Enter] to [Q]uit' -f $pickSsCount)).Trim()
        if ([string]::IsNullOrWhiteSpace($tok) -or $tok -match '^(?i)q(uit)?$') { return $null }
        try {
            $pickIx = [int]::Parse($tok.Trim())
        }
        catch {
            $pickIx = -1
        }
        if ($pickIx -lt 1 -or $pickIx -gt $pickSsCount) {
            Write-Warn ('Pick a whole number from 1 to {0}, Q to cancel, or [Enter] for the previous menu.' -f $pickSsCount)
        }
    }
    $picked = $numberedPickSs[$pickIx - 1].Block
    $pickedKey = (($picked.Name).ToString()).Trim().ToLowerInvariant()
    $dispName = $picked.Name.ToString()
    if ($DisplayNameMap -and -not [string]::IsNullOrWhiteSpace(($DisplayNameMap[$pickedKey]))) {
        $dispName = [string]$DisplayNameMap[$pickedKey]
    }
    $isOpticalPick = $false
    try {
        if ($null -ne $ConsoleOpticalDisplaySetHashSetObj) {
            $isOpticalPick = [bool]$ConsoleOpticalDisplaySetHashSetObj.Contains(($dispName))
        }
    }
    catch { }

    Write-Host ''
    $orgRg = Read-YesNoDefaultYes 'Organize the destination layout by region?'
    $assetModeSel = 'extract'
    if ($isOpticalPick) {
        Write-Host '[i] Optical system detected — archives are unpacked on the destination like options 9/10 (cores need loose disc files).' -ForegroundColor DarkYellow
        $assetModeSel = 'extract'
    }
    elseif (Read-YesNoDefaultYes 'Store non-archive games as .zip files on MiSTer (leave loose files unpacked if No)?') {
        $assetModeSel = 'zipDest'
    }

    Write-Host ''
    if (-not (Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $DestinationRootRaw)) {
        Write-Warn ('Destination folder is not reachable locally (same probe as migrate): ' + (Format-PathForDisplay (Resolve-DestinationPath -Path (($DestinationRootRaw.ToString()).Trim()))))
        Write-Warn 'Use main menu 2 (Define script settings) or fix the path before migrating.'
        return $null
    }
    Write-Host '[i] Probing SMB for the chosen SourcePath…' -ForegroundColor DarkYellow
    $spi = ($picked.SourcePath.ToString()).Trim()
    $spr = Resolve-DestinationPath -Path $spi
    if (-not (Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $spr)) {
        Write-Warn ('Cannot see source folder offline (preflight failed): ' + (Format-PathForDisplay $spr))
        return $null
    }
    $probe = Test-ConsoleSourcePath -Root $picked.SourcePath -User $ShareUser -Password $SharePassword
    if (-not $probe.OK) {
        $detail = [string]$probe.Error
        if ([string]::IsNullOrWhiteSpace($detail)) { $detail = 'SMB handshake failed.' }
        Write-Warn ('Chosen source is not reachable with configured credentials: ' + $detail + ' Try main menu 4 or 6.')
        return $null
    }

    $fileCountGuess = '(unknown)'
    $driveHold = $null
    try {
        $driveHold = New-ShareDrive -Root $picked.SourcePath -User $ShareUser -Password $SharePassword
        $enumerated = @(Get-ChildItem -LiteralPath $driveHold -Force -Recurse -File -ErrorAction SilentlyContinue)
        $fileCountGuess = $enumerated.Count.ToString('N0', [System.Globalization.CultureInfo]::GetCultureInfo('en-US'))
    }
    catch {
        $fileCountGuess = '(could not enumerate — still may copy)'
    }
    finally {
        if ($driveHold) {
            Remove-ShareDrive -DrivePath $driveHold
        }
    }

    Write-Host ''
    Write-Host '===[ Migrate summary ]===' -ForegroundColor DarkCyan
    Write-Host ('System:                 {0}' -f $dispName) -ForegroundColor White
    Write-Host ('Organize regions:       {0}' -f ($(if ($orgRg) { 'yes' } else { 'no' }))) -ForegroundColor White
    Write-Host ('Assets on destination:  {0}' -f ($(if ($assetModeSel -eq 'zipDest') { 'ZIP bundles for non-optical cores' } else { 'Unpack like options 9/10' }))) -ForegroundColor White
    Write-Host ('Source files (guess):    {0}' -f $fileCountGuess) -ForegroundColor DarkGray

    Write-Host ''
    if (-not (Read-YesNoDefaultYes 'Start this single-system copy now?')) {
        return $null
    }

    return @{
        PickedConsoleName     = ([string]$picked.Name)
        PickedDisplayName     = [string]$dispName
        PickedConsoleKeyLower = ([string]$pickedKey)
        PickedSourcePath      = ([string]($picked.SourcePath.ToString()).Trim())
        OrganizeRegions       = [bool]$orgRg
        MigrateAssetMode      = [string]$assetModeSel
    }
}

function Invoke-GpApplySingleSystemWizardResult {
    param(
        [Parameter(Mandatory)][hashtable]$WizSs
    )
    Set-Variable -Name organizeRegions -Scope Script -Value ([bool]$WizSs.OrganizeRegions)
    $script:GpMigrateAssetMode = [string]$WizSs.MigrateAssetMode
    $script:GpPendingSingleConsoleForMigrate = @{
        Name       = [string]$WizSs.PickedConsoleName
        SourcePath = [string]$WizSs.PickedSourcePath
    }
    $script:GpSingleSystemInteractiveSession = $true
    $script:GpPostMigrateInteractiveRepeatKind = 'SingleSystem'
    Set-Variable -Name doCleanup -Scope Script -Value $true
    Set-Variable -Name doProcessing -Scope Script -Value $true
    Set-Variable -Name doRecreateConfig -Scope Script -Value $false
}

function Invoke-GpApplyCustomRunInteractiveResult {
    param(
        [Parameter(Mandatory)]$Crx
    )
    $script:CustomRunActive = $true
    $script:PostMenuDestinationInit = $null
    $script:CustomRunSourcePath = $Crx.SourcePath
    $script:CustomRunDestDisplay = (Format-PathForDisplay $Crx.DestinationPath)
    $script:CustomRunDestUser = $Crx.DestinationShareUser
    $script:CustomRunDestPassword = $Crx.DestinationSharePassword
    Set-Variable -Name DestinationRoot -Scope Script -Value $Crx.DestinationPath
    Set-Variable -Name TempRoot -Scope Script -Value $Crx.TempPath
    Set-Variable -Name organizeRegions -Scope Script -Value ([bool]$Crx.OrganizeRegions)
    $script:CustomRunOrganizeExisting = [bool]$Crx.OrganizeExistingDestination
    Set-Variable -Name doCleanup -Scope Script -Value ([bool]$Crx.DoCleanup)
    Set-Variable -Name doProcessing -Scope Script -Value $true
    Set-Variable -Name doRecreateConfig -Scope Script -Value $false
    $script:GpPostMigrateInteractiveRepeatKind = 'CustomRun'
    $script:GpMigrateAssetMode = 'extract'

    $extUnionCx = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($kv in $consoleExtensionsMap.GetEnumerator()) {
        if ($null -eq $kv.Value) { continue }
        foreach ($ex in @($kv.Value)) {
            $extUnionCx.Add($ex) | Out-Null
        }
    }
    if ($extUnionCx.Count -eq 0) {
        $extUnionCx.Add('.rom') | Out-Null
    }
    $consoleNameMap['custom run'] = 'Custom'
    $consoleDisplayNameMap['custom run'] = 'Custom run'
    $consoleExtensionsMap['custom run'] = $extUnionCx
    Initialize-TempRootDirectory -Path $TempRoot
}

function Read-CustomRunConfigurationWithConnectivityRetries
{
    [CmdletBinding()]
    param()

    while ($true) {
        Write-Host ''
        Write-Host ('=== Custom run configuration ===') -ForegroundColor Cyan
        Write-Host ''

        while ($true) {
            $rawSrc = (Read-Host 'What is the source folder').Trim()
            if (-not [string]::IsNullOrWhiteSpace($rawSrc)) { break }
            Write-Warn 'Source folder is required.'
        }
        while ($true) {
            $rawDest = (Read-Host 'What is the destination folder').Trim()
            if (-not [string]::IsNullOrWhiteSpace($rawDest)) { break }
            Write-Warn 'Destination folder is required.'
        }
        Write-Host ""
        Write-Host "Destination share credentials (UNC only; blank user skips password; enter a user name to be prompted for password)." -ForegroundColor DarkGray
        $destUserIn = (Read-Host 'Destination user name').Trim()
        $destPassSec = $null
        if (-not [string]::IsNullOrWhiteSpace($destUserIn)) {
            $destPassSec = Read-Host 'Destination password' -AsSecureString
            if ($null -ne $destPassSec) {
                $bptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($destPassSec)
                try {
                    $passPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bptr)
                    if ([string]::IsNullOrWhiteSpace($passPlain)) {
                        $destPassSec = $null
                    }
                }
                finally {
                    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bptr)
                }
            }
        }
        Write-Host ''
        while ($true) {
            $rawTmp = (Read-Host 'What is the temp directory').Trim()
            if (-not [string]::IsNullOrWhiteSpace($rawTmp)) { break }
            Write-Warn 'Temp directory is required.'
        }
        Write-Host ''
        $orgRegions = Read-YesNoDefaultYes 'Do you want to organize the images by region?'
        $orgExisting = Read-YesNoDefaultNo 'Organize files already on the destination folder before copying (layout / region rules)?'
        $cleanupAfter = Read-YesNoDefaultYes 'Run destination cleanup after copying (invalid extensions, empty folders)?'

        $resolvedSrc = Resolve-DestinationPath -Path $rawSrc
        $resolvedDest = Resolve-DestinationPath -Path $rawDest
        $resolvedDest = Resolve-DestinationGamesSubfolder -Path $resolvedDest
        $resolvedTmp = Resolve-DestinationPath -Path $rawTmp

        Write-Host ''
        Write-Host '===[ Confirm Settings ]===' -ForegroundColor DarkCyan
        Write-Host ('  {0,-26}' -f 'Source:') -NoNewline -ForegroundColor White
        Write-Host (Format-PathForDisplay $resolvedSrc) -ForegroundColor DarkGray
        Write-Host ('  {0,-26}' -f 'Destination:') -NoNewline -ForegroundColor White
        Write-Host (Format-PathForDisplay $resolvedDest) -ForegroundColor DarkGray
        Write-Host ('  {0,-26}' -f 'Destination user:') -NoNewline -ForegroundColor White
        Write-Host ($(if ([string]::IsNullOrWhiteSpace($destUserIn)) { '(none)' } else { $destUserIn })) -ForegroundColor DarkGray
        Write-Host ('  {0,-26}' -f 'Temp Directory:') -NoNewline -ForegroundColor White
        Write-Host (Format-PathForDisplay $resolvedTmp) -ForegroundColor DarkGray
        Write-Host ('  {0,-26}' -f 'Organize images by region:') -NoNewline -ForegroundColor White
        Write-Host ($(if ($orgRegions) { 'Yes' } else { 'No' })) -ForegroundColor DarkGray
        Write-Host ('  {0,-26}' -f 'Organize existing on dest:') -NoNewline -ForegroundColor White
        Write-Host ($(if ($orgExisting) { 'Yes' } else { 'No' })) -ForegroundColor DarkGray
        Write-Host ('  {0,-26}' -f 'Cleanup after copy:') -NoNewline -ForegroundColor White
        Write-Host ($(if ($cleanupAfter) { 'Yes' } else { 'No' })) -ForegroundColor DarkGray
        Write-Host ''

        if (-not (Read-YesNoDefaultYes 'Proceed with this custom run after verification?')) {
            Write-Info 'Restarting script...'
            Invoke-GamePopulatorScriptRestart
        }

        Write-Host '[i] Verifying destination visibility + SMB handshake…' -ForegroundColor DarkYellow
        $folderOkDest = Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $resolvedDest
        if (-not $folderOkDest) {
            Write-Warn ('Destination is not reachable: ' + (Format-PathForDisplay $resolvedDest))
            Write-Host 'Press Enter to retry the questionnaire, or type Q then Enter to quit to the menu.' -ForegroundColor DarkYellow
            $rej = Read-Host
            if ($null -eq $rej) { continue }
            if (($rej.Trim()) -match '^(?i)q') { return $null }
            continue
        }
        $spr = Resolve-DestinationPath -Path (($resolvedSrc.ToString()).Trim())
        $folderOkSrcFolder = Test-GamePopulatorResolvedShareFolderPrecheckOk -PathResolvedOrRaw $spr
        if (-not $folderOkSrcFolder) {
            Write-Warn ('Source folder cannot be seen offline: ' + (Format-PathForDisplay $spr))
            Write-Host 'Press Enter to retry, or Q to quit to the menu.' -ForegroundColor DarkYellow
            $rej = Read-Host
            if ($null -eq $rej) { continue }
            if (($rej.Trim()) -match '^(?i)q') { return $null }
            continue
        }
        $credUser = ''
        try {
            if ($null -ne $settings.ShareUser) {
                $credUser = ($settings.ShareUser.ToString()).Trim()
            }
        }
        catch {
            $credUser = ''
        }
        $credPassForSrc = $settings.SharePassword

        $probeSrc = Test-ConsoleSourcePath -Root $resolvedSrc -User $credUser -Password $credPassForSrc
        if (-not $probeSrc.OK) {
            $detailSrc = ([string]$probeSrc.Error).Trim()
            if ([string]::IsNullOrWhiteSpace($detailSrc)) { $detailSrc = 'Could not authenticate to the SMB source share.' }
            Write-Warn ("Source handshake failed ({0})." -f $detailSrc)
            Write-Host 'Press Enter to retry, or Q then Enter to abandon this custom run.' -ForegroundColor DarkYellow
            $rej = Read-Host
            if ($null -eq $rej) { continue }
            if (($rej.Trim()) -match '^(?i)q') { return $null }
            continue
        }

        Write-Host '[ok] Connectivity checks passed.' -ForegroundColor DarkGreen
        Write-Host ''

        return @{
            SourcePath                  = $resolvedSrc
            DestinationPath             = $resolvedDest
            TempPath                    = $resolvedTmp
            OrganizeRegions             = $orgRegions
            OrganizeExistingDestination = $orgExisting
            DoCleanup                   = $cleanupAfter
            DestinationShareUser        = $destUserIn
            DestinationSharePassword    = $destPassSec
        }
    }
}

function Show-MainMenu {
    Write-Host "Maintenance:" -ForegroundColor Cyan
    Write-Host "  1. Toggle visibility and/or edit source paths." -ForegroundColor White
    Write-Host "  2. Define script settings." -ForegroundColor White
    Write-Host "  3. Validate configuration libraries." -ForegroundColor White
    Write-Host "  4. Validate active sources (folders + SMB, same check at migrate time)." -ForegroundColor White
    Write-Host "  5. Destination file & folder cleanup." -ForegroundColor White
    Write-Host "  6. Reset network SMB connections." -ForegroundColor White
    Write-Host '  7. Recreate config files under libraries from templates.' -ForegroundColor White
    Write-Host "  8. Install latest files from GitHub." -ForegroundColor White
    Write-Host ""

    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  9. Archive extraction and file copying, with region organization." -ForegroundColor White
    Write-Host "  10. Archive extraction and file copying, without region organization." -ForegroundColor White
    Write-Host '  11. Zip archive creation and file copying, with region organization (non-optical cores).' -ForegroundColor White
    Write-Host '  12. Zip archive creation and file copying, without region organization (non-optical cores).' -ForegroundColor White
    Write-Host '  13. Single system copy (guided process).' -ForegroundColor White
    Write-Host '  14. Custom run (folders and paths as you specify, with verified connectivity).' -ForegroundColor White
    Write-Host ""

    Write-Host "  H. Help" -ForegroundColor White
    Write-Host "  E. Exit" -ForegroundColor White

    Write-Host ""
    Write-Host "Note:" -ForegroundColor Cyan
    Write-Host ' - Submenu 5 under menu 1 shows enabled-system counts/sizes (estimates).' -ForegroundColor DarkYellow
    Write-Host ' - Migrate skips repeated folder + SMB verification when enabled SourcePaths and ' -NoNewline -ForegroundColor DarkYellow
    Write-Host 'libraries\settings.json' -NoNewline -ForegroundColor Green
    Write-Host ' are unchanged.' -ForegroundColor DarkYellow
    Write-Host ' - Successful menu 4 preflight refreshes ' -NoNewline -ForegroundColor DarkYellow
    Write-Host 'logs\gp-source-verification-cache.json' -NoNewline -ForegroundColor Green
    Write-Host '.' -ForegroundColor DarkYellow
    Write-Host " - Most maintenance choices restart the script when finished so new values are loaded." -ForegroundColor DarkYellow
}
