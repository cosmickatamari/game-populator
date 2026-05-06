<#
Game Populator
https://github.com/cosmickatamari/game-populator

Created by: cosmickatamari
Updated: 05/04/2026
#>

param(
    [switch]$Help,
    [switch]$Org,
    [switch]$NoOrg,
    [switch]$Cleanup,
    [switch]$Diag,
    [string]$DestinationRoot,
    [string]$TempRoot
)

$scriptRoot = $PSScriptRoot

$gameEntry = Join-Path $scriptRoot 'game-populator.ps1'
$script:EntryScriptPath = if (Test-Path -LiteralPath $gameEntry -PathType Leaf) {
    $gameEntry
} else {
    $PSCommandPath
}

$script:GamePopulatorBoundParameters = $PSBoundParameters
Set-StrictMode -Version Latest
$script:ScriptDiag = $false
$helpersPath = Join-Path $scriptRoot 'helpers.ps1'
if (-not (Test-Path -LiteralPath $helpersPath -PathType Leaf)) {
    Write-Host "Required file not found beside this script: " -NoNewline -ForegroundColor Red
    Write-Host "helpers.ps1" -ForegroundColor White
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

if ($PSVersionTable.PSVersion.Major -ne 7) {
    Write-Fail "PowerShell 7.x is required."
}

try {
    Clear-Host
} catch {
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

$settingsPath = Join-Path $scriptRoot 'settings.json'
$consolePath = Join-Path $scriptRoot 'sources.psd1'
$consoleNamesPath = Join-Path $scriptRoot 'console-names.json'
$settingsTemplatePath = Join-Path $scriptRoot 'settings.template.json'
$consoleTemplatePath = Join-Path $scriptRoot 'sources.template.psd1'
$consoleNamesTemplatePath = Join-Path $scriptRoot 'console-names.template.json'

$configRecreatedFromTemplate = $false

$templateBootstrapNames = @(
    'settings.template.json',
    'sources.template.psd1',
    'console-names.template.json'
)
$missingTemplatesBootstrap = @()
foreach ($tn in $templateBootstrapNames) {
    $tp = Join-Path $scriptRoot $tn
    if (-not (Test-Path -LiteralPath $tp -PathType Leaf)) {
        $missingTemplatesBootstrap += $tn
    }
}
if ($missingTemplatesBootstrap.Count -gt 0) {
    Write-Info "Rebuilding template files from GitHub source..."
    if (-not (Restore-GamePopulatorTemplatesFromGitHub -ScriptRoot $scriptRoot -TemplateFileNames @($missingTemplatesBootstrap))) {
        Write-Fail "Could not download missing template files from GitHub. Check your network connection."
    }
    Write-Info "Restarting script after restoring templates."
    & $script:EntryScriptPath @PSBoundParameters
    exit $LASTEXITCODE
}

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
            & $script:EntryScriptPath @PSBoundParameters
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

$allConsoles = $null
try {
    $consoleData = Import-PowerShellDataFile -LiteralPath $consolePath -ErrorAction Stop
    $allConsoles = @(Get-PsdImportedSourcesArray $consoleData)
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
        $consoleData = Import-PowerShellDataFile -LiteralPath $consolePath -ErrorAction Stop
        $allConsoles = @(Get-PsdImportedSourcesArray $consoleData)
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
    & $script:EntryScriptPath @PSBoundParameters
    exit $LASTEXITCODE
}

if ($settings -and ($settings.PSObject.Properties.Name -contains 'SharePassword') -and $null -ne $settings.SharePassword -and $settings.SharePassword -isnot [SecureString]) {
    $pwdStr = $settings.SharePassword.ToString()
    if (-not [string]::IsNullOrWhiteSpace($pwdStr)) {
        $settings.SharePassword = ConvertTo-SecureString $pwdStr -AsPlainText -Force
    }
}

$consoleNameMap = @{}
$consoleSubDirMap = @{}
$consoleDisplayNameMap = @{}
$consoleExtensionsMap = @{}
Write-ScriptDiag "Building console maps from console-names JSON"
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

function Initialize-TempRootDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    Write-ScriptDiag "Initialize-TempRootDirectory: $Path"
    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-ScriptDiag "Created temp folder"
        } else {
            Write-ScriptDiag "Temp folder exists"
        }
    } catch {
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
    } catch {
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
    } catch {
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

function Write-NumberedSourcesConsoleBlockList {
    param(
        [AllowEmptyCollection()][object[]]$Blocks,
        [hashtable]$DisplayNameMap,
        [switch]$ShowSourcePaths,
        [switch]$ColorEnabledState
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
    if ($n -eq 0) {
        Write-Host "  (none)" -ForegroundColor DarkYellow
        Write-Host ""
        return
    }

    $numList = [System.Collections.Generic.List[object]]::new()
    for ($ri = 0; $ri -lt $n; $ri++) {
        $numList.Add([pscustomobject]@{
            Num     = $ri + 1
            Display = [string]$sorted[$ri].Display
            Block   = $sorted[$ri].Block
        }) | Out-Null
    }
    $numbered = $numList.ToArray()

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
            } else {
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
    } catch { }
    try {
        $ww = $Host.UI.RawUI.WindowSize.Width
        if ($ww -gt 0 -and $ww -lt $usableWidth) { $usableWidth = $ww }
    } catch { }
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
            } else {
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
                } else {
                    $cell = $prefix + $dispTrunc
                    $padded = $cell.PadRight($cellMax)
                    Write-Host $padded -NoNewline -ForegroundColor White
                }
            } else {
                Write-Host (''.PadRight($cellMax)) -NoNewline
            }
        }
        Write-Host ''
    }
    Write-Host ""
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
        [Parameter(Mandatory = $true)][string]$ConsoleName
    )
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        Write-Warn "sources file not found: $LiteralPath"
        return $false
    }
    try {
        $lines = [System.Collections.Generic.List[string]]::new([string[]](Get-Content -LiteralPath $LiteralPath))
    } catch {
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
                } elseif ([string]::Equals($parsed, $ConsoleName, [StringComparison]::OrdinalIgnoreCase)) {
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
                } catch {
                    Write-Warn $_.Exception.Message
                    return $false
                }
                try {
                    $null = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
                } catch {
                    Write-Warn ("sources.psd1 may be invalid after edit: {0}" -f $_.Exception.Message)
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
        [Parameter(Mandatory = $true)][string]$ConsoleName
    )
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        Write-Warn "sources file not found: $LiteralPath"
        return $false
    }
    try {
        $lines = [System.Collections.Generic.List[string]]::new([string[]](Get-Content -LiteralPath $LiteralPath))
    } catch {
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
            } elseif ([string]::Equals($parsed, $ConsoleName, [StringComparison]::OrdinalIgnoreCase)) {
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
            } catch {
                Write-Warn $_.Exception.Message
                return $false
            }
            try {
                $null = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
            } catch {
                Write-Warn ("sources.psd1 may be invalid after edit: {0}" -f $_.Exception.Message)
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
        [Parameter(Mandatory = $true)][string]$NewSourcePath
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
    } catch {
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
                } catch {
                    Write-Warn $_.Exception.Message
                    return $false
                }
                try {
                    $null = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
                } catch {
                    Write-Warn ("sources.psd1 may be invalid after edit: {0}" -f $_.Exception.Message)
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
            } catch {
                Write-Warn $_.Exception.Message
                return $false
            }
            try {
                $null = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
            } catch {
                Write-Warn ("sources.psd1 may be invalid after edit: {0}" -f $_.Exception.Message)
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
    param([Parameter(Mandatory)][string]$LiteralPath)
    try {
        $d = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
        $script:allConsoles = @(Get-PsdImportedSourcesArray $d)
        $script:activeConsoleSourceCount = 0
        if ($null -ne $script:allConsoles) {
            $script:activeConsoleSourceCount = @($script:allConsoles | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.Name) -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
            }).Count
        }
    } catch {
        Write-Warn $_.Exception.Message
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
        $sub = (Read-Host "Select 1-2, Q, or [Enter] to [Q]uit").Trim()
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
                    Write-Host '1, 3, 4, 16...' -NoNewline -ForegroundColor White
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
                            if (Enable-SourcesPsd1ConsoleBlock -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$picked.Name)) {
                                $picked.Enabled = $true
                                $nOn++
                            }
                        }
                        if ($nOn -gt 0) {
                            Update-GamePopulatorConsoleSourcesState -LiteralPath $SourcesLiteralPath
                            Write-Info ("Enabled {0} system(s)." -f $nOn)
                        } else {
                            Write-Info 'All systems were already enabled.'
                        }
                        Write-Host ''
                        continue
                    }
                    if ($rawTrim -match '^(?i)af$') {
                        $nOff = 0
                        foreach ($picked in $snapToggle) {
                            if (-not $picked.Enabled) { continue }
                            if (Disable-SourcesPsd1ConsoleBlock -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$picked.Name)) {
                                $picked.Enabled = $false
                                $nOff++
                            }
                        }
                        if ($nOff -gt 0) {
                            Update-GamePopulatorConsoleSourcesState -LiteralPath $SourcesLiteralPath
                            Write-Info ("Disabled {0} system(s)." -f $nOff)
                        } else {
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
                            if (Disable-SourcesPsd1ConsoleBlock -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$picked.Name)) {
                                Write-Info ('Disabled System: {0}' -f $picked.Display)
                                Update-GamePopulatorConsoleSourcesState -LiteralPath $SourcesLiteralPath
                                $picked.Enabled = $false
                            }
                        } elseif (Enable-SourcesPsd1ConsoleBlock -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$picked.Name)) {
                            Write-Info ('Enabled System: {0}' -f $picked.Display)
                            Update-GamePopulatorConsoleSourcesState -LiteralPath $SourcesLiteralPath
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
                        } else {
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
                        if (Update-SourcesPsd1ConsoleSourcePath -LiteralPath $SourcesLiteralPath -ConsoleName ([string]$sys.Name) -NewSourcePath $nts) {
                            Write-Host ('  Updated SourcePath for {0}' -f $sys.Display) -ForegroundColor Yellow
                            Write-Host ''
                            Update-GamePopulatorConsoleSourcesState -LiteralPath $SourcesLiteralPath
                            $sys.SourcePath = [string]$nts
                            break
                        }
                    }
                    if ($abortOption4AfterPathMenu) {
                        break
                    }
                }
            }
            Default {
                Write-Warn "Select 1-2, Q, or Enter for the previous menu."
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
        } finally {
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
        } catch {
            Write-Warn "Could not read settings file: $($_.Exception.Message)"
            return
        }
        $view = $null
        try {
            $view = $rawJson | ConvertFrom-Json
        } catch {
            Write-Warn "Settings JSON is invalid: $($_.Exception.Message)"
            return
        }
        $ordered = [ordered]@{}
        foreach ($p in @($view.PSObject.Properties)) {
            $ordered[$p.Name] = $p.Value
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
            if ($kn.Length -gt $nameColW) { $nameColW = $kn.Length }
        }
        if ($nameColW -lt 8) { $nameColW = 8 }
        for ($i = 0; $i -lt $names.Count; $i++) {
            $n = $names[$i]
            $num = $i + 1
            $disp = Format-SettingsJsonValueForDisplay -Value $ordered[$n]
            Write-Host ('  ' + ([string]$num).PadLeft(2) + '. ' + ([string]$n).PadRight($nameColW) + '  ') -NoNewline -ForegroundColor White
            Write-Host $disp -ForegroundColor Yellow
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
            'SharePassword' {
                Write-Host 'Stored as plain text in JSON. Type clear to remove the password. [Enter] leaves it unchanged.' -ForegroundColor DarkGray
                $inp = Read-Host "New SharePassword"
                if ($null -eq $inp) {
                    continue
                }
                $inp = $inp.Trim()
                if (($inp.Length -eq 0)) {
                    # unchanged
                } elseif ($inp -match '^(?i)clear$') {
                    $ordered[$propName] = ''
                    $dirty = $true
                } else {
                    $ordered[$propName] = $inp
                    $dirty = $true
                }
            }
            Default {
                $inp = Read-Host ("New value for $propName [Enter unchanged]")
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
        } catch {
            Write-Warn "Could not save settings: $($_.Exception.Message)"
            continue
        }
        try {
            $fresh = Get-Content -LiteralPath $SettingsLiteralPath -Raw | ConvertFrom-Json
            Set-GamePopulatorSharePasswordAsSecure -SettingsObj $fresh
            $SettingsRef.Value = $fresh
        } catch {
            Write-Warn "Saved file, but reload failed: $($_.Exception.Message)"
        }
        Write-Info "Changes saved."
    }
}

function Show-MainMenu {
    Write-Host "Maintenance:" -ForegroundColor Cyan
    Write-Host "  1. Toggle visibility and/or edit system source paths." -ForegroundColor White
    Write-Host "  2. Edit network share mapping." -ForegroundColor White
    Write-Host "  3. Destination file & folder cleanup." -ForegroundColor White
    Write-Host "  4. Recreate config files from template files." -ForegroundColor White
    Write-Host "  5. Install latest files from GitHub." -ForegroundColor White
    Write-Host "  6. Reset network SMB connections." -ForegroundColor White
    Write-Host ""

    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  7. Archive extraction and file copying, with region organization." -ForegroundColor White
    Write-Host "  8. Archive extraction and file copying, without region organization." -ForegroundColor White
    Write-Host "  9. Custom run (folders and paths as you specify)." -ForegroundColor White
    Write-Host ""

    Write-Host "  E. Exit." -ForegroundColor White

    Write-Host ""
    Write-Host "Note:" -ForegroundColor Cyan
    Write-Host "All options under Maintenance restart the script automatically when finished so new values are loaded." -ForegroundColor DarkYellow
}

function Read-CustomRunConfiguration {
    Write-Host ""
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
    Write-Host "Destination share credentials (UNC only; press Enter for no user/password, e.g. a public share)." -ForegroundColor DarkGray
    $destUserIn = (Read-Host 'Destination user name').Trim()
    $destPassSec = Read-Host 'Destination password' -AsSecureString
    if ($null -ne $destPassSec) {
        $bptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($destPassSec)
        try {
            $passPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bptr)
            if ([string]::IsNullOrWhiteSpace($passPlain)) {
                $destPassSec = $null
            }
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bptr)
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

    if (-not (Read-YesNoDefaultYes 'Proceed with this custom run?')) {
        & $script:EntryScriptPath @script:GamePopulatorBoundParameters
        exit $LASTEXITCODE
    }

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

$script:PostMenuDestinationInit = $null
$script:CustomRunActive = $false
$script:CustomRunOrganizeExisting = $false
$organizeRegions = $false
$doCleanup = $false
$doProcessing = $true
$doRecreateConfig = $false
$script:RestartAfterInteractiveCleanup = $false

if (-not $PSBoundParameters.ContainsKey('DestinationRoot') -and $settings.DestinationRoot) {
    $DestinationRoot = Resolve-DestinationPath -Path $settings.DestinationRoot
}
if (-not $PSBoundParameters.ContainsKey('TempRoot') -and $settings.TempRoot) {
    $TempRoot = $settings.TempRoot
}

if (-not $DestinationRoot) {
    Write-Host 'Edit the settings file ' -NoNewline -ForegroundColor DarkYellow
    Write-Host 'settings.json' -NoNewline -ForegroundColor White
    Write-Host ', or pass the ' -NoNewline -ForegroundColor DarkYellow
    Write-Host '-DestinationRoot' -NoNewline -ForegroundColor White
    Write-Host ' parameter.' -ForegroundColor DarkYellow
    Write-Fail 'DestinationRoot is required.'
}
$DestinationRoot = Resolve-DestinationPath -Path $DestinationRoot
$DestinationRoot = Resolve-DestinationGamesSubfolder -Path $DestinationRoot
if (-not $TempRoot) {
    Write-Host 'Edit the settings file ' -NoNewline -ForegroundColor DarkYellow
    Write-Host 'settings.json' -NoNewline -ForegroundColor White
    Write-Host ', or pass the ' -NoNewline -ForegroundColor DarkYellow
    Write-Host '-TempRoot' -NoNewline -ForegroundColor White
    Write-Host ' parameter.' -ForegroundColor DarkYellow
    Write-Fail 'TempRoot is required.'
}
if ($TempRoot) {
    Initialize-TempRootDirectory -Path $TempRoot
}

$activeConsoleSourceCount = 0
if ($null -ne $allConsoles) {
    $activeConsoleSourceCount = @($allConsoles | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.Name) -and -not [string]::IsNullOrWhiteSpace($_.SourcePath)
    }).Count
}

$settingsLabelWidth = 26

Write-Host "Settings:" -ForegroundColor Cyan
Write-Host ("  - {0,-$settingsLabelWidth}" -f 'Destination:') -NoNewline -ForegroundColor White
Write-Host $DestinationRoot -ForegroundColor Green
Write-Host ("  - {0,-$settingsLabelWidth}" -f 'Temp Folder:') -NoNewline -ForegroundColor White
Write-Host (Format-PathForDisplay $TempRoot) -ForegroundColor Green
Write-Host ("  - {0,-$settingsLabelWidth}" -f 'Active consoles:') -NoNewline -ForegroundColor White
Write-Host $activeConsoleSourceCount.ToString() -ForegroundColor Green
Write-Host ""

$menuOptions = @($Org, $NoOrg, $Cleanup) | Where-Object { $_ }
if ($menuOptions -isnot [System.Array]) { $menuOptions = @($menuOptions) }
if ($menuOptions.Count -gt 1) {
    Write-Fail "Multiple mode switches passed. Use only one."
}

if ($Org) {
    $organizeRegions = $true
    $doCleanup = $true
} elseif ($NoOrg) {
    $organizeRegions = $false
    $doCleanup = $true
} elseif ($Cleanup) {
    $doProcessing = $false
    $organizeRegions = $false
    $doCleanup = $true
    $stdinRedirected = $false
    try { $stdinRedirected = [Console]::IsInputRedirected } catch { $stdinRedirected = $false }
    if (-not $stdinRedirected) {
        $script:RestartAfterInteractiveCleanup = $true
    }
} else {
    $menuValid = $false
    $mainMenuPrinted = $false
    while (-not $menuValid) {
        if (-not $mainMenuPrinted) {
            Show-MainMenu
            Write-Host ""
            $mainMenuPrinted = $true
        }
        Invoke-OutputFlush
        Write-ScriptDiag "Read-Host menu (waiting for 1-9, E, or [Enter] to exit)"
        $choice = (Read-Host "Select options 1-9 or [Enter] to exit").Trim()
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match '^(?i)(e|exit)$') { exit 0 }
        switch ($choice) {
            '1' {
                Invoke-TurnOnOffSystemsMenu -SourcesLiteralPath $consolePath -SourcesFileDisplayName 'sources.psd1' -DisplayNameMap $consoleDisplayNameMap
                Write-Info "Restarting script to reload configuration..."
                & $script:EntryScriptPath @PSBoundParameters
                exit $LASTEXITCODE
            }
            '2' {
                Invoke-EditSettingsJsonMenu -SettingsLiteralPath $settingsPath -SettingsRef ([ref]$settings)
                Write-Info "Restarting script to reload configuration..."
                & $script:EntryScriptPath @PSBoundParameters
                exit $LASTEXITCODE
            }
            '3' {
                $script:RestartAfterInteractiveCleanup = $true
                $doProcessing = $false; $organizeRegions = $false; $doCleanup = $true; $menuValid = $true
            }
            '4' { $doRecreateConfig = $true; $menuValid = $true }
            '5' {
                $null = Invoke-GamePopulatorSelfUpdate -ScriptRoot $scriptRoot
                Write-Info "Restarting script..."
                & $script:EntryScriptPath @PSBoundParameters
                exit $LASTEXITCODE
            }
            '6' {
                Write-Host ""
                Write-Host "Disconnects SMB mappings managed by this script, then reconnects the destination folder from " -NoNewline -ForegroundColor White
                Write-Host "settings.json" -NoNewline -ForegroundColor Green
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
                        } else {
                            $script:PostMenuDestinationInit = $null
                            Write-Info ("Destination folder ready (local path): {0}" -f $reInfo.Path)
                        }
                        Write-Host ""
                    } catch {
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
                    } catch {
                        $null = Read-Host "Press Enter to restart the script."
                    }
                    Write-Host ""
                }
                Write-Info "Restarting script to reload configuration..."
                & $script:EntryScriptPath @PSBoundParameters
                exit $LASTEXITCODE
            }
            '7' { $organizeRegions = $true; $doCleanup = $true; $menuValid = $true }
            '8' { $organizeRegions = $false; $doCleanup = $true; $menuValid = $true }
            '9' {
                $script:PostMenuDestinationInit = $null
                $cr = Read-CustomRunConfiguration
                if ($null -eq $cr) { continue }
                $script:CustomRunSourcePath = $cr.SourcePath
                $script:CustomRunDestDisplay = (Format-PathForDisplay $cr.DestinationPath)
                $script:CustomRunDestUser = $cr.DestinationShareUser
                $script:CustomRunDestPassword = $cr.DestinationSharePassword
                $DestinationRoot = $cr.DestinationPath
                $TempRoot = $cr.TempPath
                $organizeRegions = [bool]$cr.OrganizeRegions
                $script:CustomRunOrganizeExisting = [bool]$cr.OrganizeExistingDestination
                $doCleanup = [bool]$cr.DoCleanup
                $doProcessing = $true
                $doRecreateConfig = $false

                $extUnion = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($kv in $consoleExtensionsMap.GetEnumerator()) {
                    if ($null -eq $kv.Value) { continue }
                    foreach ($ex in $kv.Value) {
                        $extUnion.Add($ex) | Out-Null
                    }
                }
                if ($extUnion.Count -eq 0) {
                    $extUnion.Add('.rom') | Out-Null
                }
                $consoleNameMap['custom run'] = 'Custom'
                $consoleDisplayNameMap['custom run'] = 'Custom run'
                $consoleExtensionsMap['custom run'] = $extUnion
                $script:CustomRunActive = $true
                $menuValid = $true
            }
            Default {
                Write-Warn "Invalid selection. Enter 1-9, E to exit, or press Enter to exit."
            }
        }
    }
}

if ($script:CustomRunActive) {
    Initialize-TempRootDirectory -Path $TempRoot
}

if ($doRecreateConfig) {
    $missingTemplates = @()
    if (Read-YesNoDefaultNo "`nRecreate settings file (settings.json) from template?") {
        if (Test-Path -LiteralPath $settingsTemplatePath) {
            Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
            Write-Info "Recreated: settings.json"
        } else {
            $missingTemplates += 'settings.template.json'
        }
    }
    if (Read-YesNoDefaultNo "Recreate console sources file (sources.psd1) from template?") {
        if (Test-Path -LiteralPath $consoleTemplatePath) {
            Copy-Item -LiteralPath $consoleTemplatePath -Destination $consolePath -Force
            Write-Info "Recreated: sources.psd1"
        } else {
            $missingTemplates += 'sources.template.psd1'
        }
    }
    if (Read-YesNoDefaultNo "Recreate console names file (console-names.json) from template?") {
        if (Test-Path -LiteralPath $consoleNamesTemplatePath) {
            Copy-Item -LiteralPath $consoleNamesTemplatePath -Destination $consoleNamesPath -Force
            Write-Info "Recreated: console-names.json"
        } else {
            $missingTemplates += 'console-names.template.json'
        }
    }
    if ($missingTemplates.Count -gt 0) {
        Write-Host ""
        Write-Info "Rebuilding template files from GitHub source..."
        if (-not (Restore-GamePopulatorTemplatesFromGitHub -ScriptRoot $scriptRoot -TemplateFileNames @($missingTemplates))) {
            Write-Warn ("Could not restore templates from GitHub. Missing: {0}" -f ($missingTemplates -join ', '))
            exit 1
        }
        foreach ($fn in $missingTemplates) {
            if ($fn -eq 'settings.template.json') {
                Copy-Item -LiteralPath $settingsTemplatePath -Destination $settingsPath -Force
                Write-Info "Recreated: settings.json"
            } elseif ($fn -eq 'sources.template.psd1') {
                Copy-Item -LiteralPath $consoleTemplatePath -Destination $consolePath -Force
                Write-Info "Recreated: sources.psd1"
            } elseif ($fn -eq 'console-names.template.json') {
                Copy-Item -LiteralPath $consoleNamesTemplatePath -Destination $consoleNamesPath -Force
                Write-Info "Recreated: console-names.json"
            }
        }
        Write-Host ""
        Write-Info "Restarting script to load recreated config."
        & $script:EntryScriptPath @PSBoundParameters
        exit $LASTEXITCODE
    }
    Write-Host ""
    Write-Info "Restarting script to reload configuration..."
    & $script:EntryScriptPath @PSBoundParameters
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
    } else {
        $destInfo = Initialize-DestinationRoot -Path $DestinationRoot -User $destUserForInit -Password $destPassForInit
    }
    $DestinationRoot = $destInfo.Path
    $destDrive = $destInfo.Drive
} catch {
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
} finally {
    if ($uncCountdownJob) {
        Stop-GamePopulatorBackgroundStatusDisplay -Job $uncCountdownJob
    }
}

if ($script:CustomRunActive -and $script:CustomRunDestDisplay) {
    $destinationPathDisplay = $script:CustomRunDestDisplay
}

$ConsoleSources = @($allConsoles)
$ConsoleSourcesReachable = @($allConsoles)

if (-not $cleanupOnly) {
    if (-not $script:CustomRunActive) {
        if (-not $ConsoleSources -or $ConsoleSources.Count -eq 0) {
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
            } catch {
                $null = Read-Host "Press Enter to restart the script"
            }
            Write-Host ""
            Write-Info "Restarting script..."
            & $script:EntryScriptPath @PSBoundParameters
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
    } else {
        $reachableList = [System.Collections.Generic.List[object]]::new()
        $unreachableList = [System.Collections.Generic.List[object]]::new()
        Write-Host ""
        Write-Host 'Verifying each console SourcePath is reachable (same credentials as copy pass)...' -ForegroundColor DarkGray
        foreach ($src in $ConsoleSources) {
            if ([string]::IsNullOrWhiteSpace($src.Name) -or [string]::IsNullOrWhiteSpace($src.SourcePath)) { continue }
            $probe = Test-ConsoleSourcePath -Root $src.SourcePath -User $srcUser -Password $srcPass
            if ($probe.OK) {
                $reachableList.Add($src)
            } else {
                $unreachableList.Add(@{
                    Name       = $src.Name
                    SourcePath = $src.SourcePath
                    Error      = $probe.Error
                })
            }
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
            Write-Host "These enabled console share paths could not be reached; they will be skipped:" -ForegroundColor Red
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
        } catch {
            $null = Read-Host "Press Enter to restart the script"
        }
        Write-Host ""
        Write-Info "Restarting script..."
        & $script:EntryScriptPath @PSBoundParameters
        exit $LASTEXITCODE
    }
}

$archiveExts = if ($settings.ArchiveExtensions) { @($settings.ArchiveExtensions) } else { @('.zip', '.7z', '.rar') }
$script:totalBytes = 0L
$script:totalFiles = 0
$script:consoleSummaries = New-Object System.Collections.Generic.List[object]
$script:regionTotals = @{}
$overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:organizeElapsed = [TimeSpan]::Zero
$script:didOrganizeExisting = $false

if ($doProcessing) {
    $organizeTotalElapsed = [TimeSpan]::Zero
    $organizeTargets = @()
    if (-not $script:CustomRunActive) {
        foreach ($src in $ConsoleSourcesReachable) {
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
    } elseif ($script:CustomRunOrganizeExisting) {
        if (Test-Path -LiteralPath $DestinationRoot -PathType Container) {
            $organizeTargets = @(@{ Name = 'Custom run'; Path = $DestinationRoot })
        }
    }
    $organizeTotal = $organizeTargets.Count
    if ($organizeTotal -gt 0) { $script:didOrganizeExisting = $true }
    if ($organizeTotal -gt 0) {
        if ($script:CustomRunActive) {
            Write-Host 'Organizing files already on destination (custom run folder; can take a while on large folders)...' -ForegroundColor DarkGray
        } else {
            Write-Host 'Organizing files already on destination (layout / region rules; can take a while on large folders)...' -ForegroundColor DarkGray
        }
        Invoke-OutputFlush
    }
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
        $consoleOrganizeTimer.Stop()
        $organizeTotalElapsed = $organizeTotalElapsed.Add($consoleOrganizeTimer.Elapsed)
        Write-OrganizeProgressLine -ConsoleName $target.Name -Elapsed $consoleOrganizeTimer.Elapsed
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
            Write-Host "console-names.json" -ForegroundColor White
            $script:errors.Add("Console short name missing for '$name' in console-names.json") | Out-Null
            continue
        }
        $displayName = if ($consoleDisplayNameMap[$consoleKey]) { $consoleDisplayNameMap[$consoleKey] } else { $name }

        $drivePath = $null
        try {
            $drivePath = New-ShareDrive -Root $sourceRoot -User $user -Password $pass
        } catch {
            $rawErr = $_.Exception.Message
            $hint = Expand-SmbConnectErrorHint -RawMessage $rawErr -UncPath $sourceRoot
            $detail = $rawErr
            if ($hint) { $detail = $detail + ' ' + $hint }
            Add-Error "Failed to connect to share for ${name}: $sourceRoot ($detail)"
            continue
        }

        try {
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
            } else {
                $joined = Join-Path $DestinationRoot $shortName
                $subDir = $consoleSubDirMap[$consoleKey]
                if ($subDir) {
                    Join-Path $joined $subDir
                } else {
                    $joined
                }
            }

            Write-Host "Preparing the destination console folder and building a filename index." -ForegroundColor DarkGray
            Invoke-OutputFlush
            Invoke-ExistingDestination -FolderPath $consoleDest -Organize $organizeRegions -ArchiveExtensions $archiveExts
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
                            } else {
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
                        } finally {
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
                } catch {
                    $lineInfo = $_.InvocationInfo.ScriptLineNumber
                    $msg = Get-CopyErrorMessage -ExceptionMessage $_.Exception.Message
                    Add-Error ("{0}: {1} (line {2})" -f $item.Name, $msg, $lineInfo)
                }
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
$cleanupFilesRemoved = 0
$cleanupFoldersRemoved = 0
# Destination check: remove any files not in the console's allowed extensions list (.rom and .zip always allowed).
if ($doCleanup) {
    $cleanupStatusJob = $null
    if ($script:RestartAfterInteractiveCleanup) {
        $cleanupStatusJob = Start-CleanupActivityElapsedDisplay
    }
    try {
        if ($script:CustomRunActive -and $consoleExtensionsMap.ContainsKey('custom run') -and $consoleExtensionsMap['custom run']) {
            $customAllowed = @($consoleExtensionsMap['custom run'])
            $fr = Remove-DestinationFilesNotMatchingExtensions -FolderPath $DestinationRoot -AllowedExtensions $customAllowed
            $cleanupFilesRemoved += $fr.FilesRemoved
        } elseif (-not $script:CustomRunActive) {
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
                    Write-Warn "Console '$($entry.ShortName)' has no Extensions in console-names.json; skipping cleanup for that folder (no files removed)."
                    continue
                }
                $fr = Remove-DestinationFilesNotMatchingExtensions -FolderPath $consoleDestPath -AllowedExtensions $extList
                $cleanupFilesRemoved += $fr.FilesRemoved
            }
        }
        $er = Remove-EmptyFolders -RootPath $DestinationRoot
        $cleanupFoldersRemoved = $er.FoldersRemoved
    } finally {
        if ($cleanupStatusJob) {
            Stop-GamePopulatorBackgroundStatusDisplay -Job $cleanupStatusJob
        }
    }
}
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
    $runSummaryLogLines.Add(("     Files removed:       {0}" -f $cleanupFilesRemoved.ToString('N0')))
    $runSummaryLogLines.Add(("     Empty folders:       {0}" -f $cleanupFoldersRemoved.ToString('N0')))
    Write-Host "     Files removed:       " -NoNewline -ForegroundColor DarkCyan
    Write-Host ($cleanupFilesRemoved.ToString('N0')) -ForegroundColor White
    Write-Host "     Empty folders:       " -NoNewline -ForegroundColor DarkCyan
    Write-Host ($cleanupFoldersRemoved.ToString('N0')) -ForegroundColor White
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
        } catch {
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
    foreach ($entry in $consoleNames) {
        if (-not $entry.ShortName) { continue }
        $consoleDestPath = Join-Path $DestinationRoot $entry.ShortName
        if ($entry.PSObject.Properties['SubDir'] -and $entry.SubDir) {
            $consoleDestPath = Join-Path $consoleDestPath $entry.SubDir
        }
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
} catch {
    Write-Warn ("Could not write run summary log: {0}" -f $_.Exception.Message)
}
Write-Host ""

if ($destCleanup) {
    Remove-PSDrive -Name $destCleanup -ErrorAction SilentlyContinue
}

if ($script:RestartAfterInteractiveCleanup) {
    Write-Host ""
    Write-Host "Completed. Press " -NoNewline -ForegroundColor White
    Write-Host "[Enter]" -NoNewline -ForegroundColor Green
    Write-Host " to return to the main menu." -ForegroundColor White
    Invoke-OutputFlush
    try {
        do {
            $k = [Console]::ReadKey($true)
        } while ($k.Key -ne [ConsoleKey]::Enter)
    } catch {
        $null = Read-Host "Press Enter to return to the main menu"
    }
    Write-Host ""
    Write-Info "Restarting script..."
    & $script:EntryScriptPath @PSBoundParameters
    exit $LASTEXITCODE
}
