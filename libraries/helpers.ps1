<#
Game Populator - helper functions
https://github.com/cosmickatamari/game-populator

Created by: cosmickatamari
Updated: 05/04/2026
#>

if ([string]::IsNullOrWhiteSpace($script:EntryScriptPath) -or
    [string]::IsNullOrWhiteSpace($script:GamePopulatorLibrariesRoot) -or
    ((Split-Path -Leaf $script:EntryScriptPath) -ne 'game-populator.ps1')) {
    Write-Host "This library script must be loaded by game-populator.ps1." -ForegroundColor Yellow
    return
}

# Single source for name and version; change here only.
$script:ScriptName = 'Game Populator'
$script:ScriptVersion = '2026.5.9'
$script:GamePopulatorRepoUrl = 'https://github.com/cosmickatamari/game-populator'
$script:GamePopulatorMainZipUrl = 'https://github.com/cosmickatamari/game-populator/archive/refs/heads/main.zip'
# Tracks last SMB auth fingerprint per UNC server so mismatch can fail fast before long timeouts.
$script:SmbEstablishedAuthFingerprintsByUncServer = @{}

function Write-Info {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Warn {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor DarkYellow
}

function Write-Summary {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor DarkCyan
}

function Write-Fail {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Red
    Write-Host ""
    exit 1
}

function Invoke-OutputFlush {
    try { [Console]::Out.Flush() } catch { }
}

function Get-GpLaunchIntentLiteralPath {
    $lib = $script:GamePopulatorLibrariesRoot
    if ([string]::IsNullOrWhiteSpace($lib)) {
        $entry = $script:EntryScriptPath
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            $scriptDir = Split-Path -Parent $entry
            if (-not [string]::IsNullOrWhiteSpace($scriptDir)) {
                $lib = Join-Path $scriptDir 'libraries'
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($lib)) {
        return $null
    }
    return (Join-Path $lib 'gp-launch-intent.json')
}

function Write-GamePopulatorLaunchIntent {
    param([Parameter(Mandatory = $true)][hashtable]$Intent)
    $p = Get-GpLaunchIntentLiteralPath
    if ([string]::IsNullOrWhiteSpace($p)) { return }
    try {
        ($Intent | ConvertTo-Json -Depth 8 -Compress) | Set-Content -LiteralPath $p -Encoding UTF8
    }
    catch {
        Write-Warn ("Could not write launch intent file: {0}" -f $_.Exception.Message)
    }
}

function Read-GamePopulatorLaunchIntent {
    $defaults = [ordered]@{
        Org                     = $false
        NoOrg                   = $false
        Cleanup                 = $false
        Resume                  = $false
        SingleSystemInteractive = $false
        CustomRunInteractive    = $false
        OnlyConsoles            = $null
        DestinationRoot         = $null
        TempRoot                = $null
    }
    $p = Get-GpLaunchIntentLiteralPath
    if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path -LiteralPath $p)) {
        return [hashtable]$defaults
    }
    try {
        $txt = Get-Content -LiteralPath $p -Raw -Encoding UTF8
        Remove-Item -LiteralPath $p -Force -ErrorAction Stop
        $o = $txt | ConvertFrom-Json
        if ($null -ne $o.Org) { $defaults.Org = [bool]$o.Org }
        if ($null -ne $o.NoOrg) { $defaults.NoOrg = [bool]$o.NoOrg }
        if ($null -ne $o.Cleanup) { $defaults.Cleanup = [bool]$o.Cleanup }
        if ($null -ne $o.Resume) { $defaults.Resume = [bool]$o.Resume }
        if ($null -ne $o.SingleSystemInteractive) { $defaults.SingleSystemInteractive = [bool]$o.SingleSystemInteractive }
        if ($null -ne $o.CustomRunInteractive) { $defaults.CustomRunInteractive = [bool]$o.CustomRunInteractive }
        if ($null -ne $o.DestinationRoot -and -not [string]::IsNullOrWhiteSpace([string]$o.DestinationRoot)) {
            $defaults.DestinationRoot = [string]$o.DestinationRoot
        }
        if ($null -ne $o.TempRoot -and -not [string]::IsNullOrWhiteSpace([string]$o.TempRoot)) {
            $defaults.TempRoot = [string]$o.TempRoot
        }
        if ($null -ne $o.OnlyConsoles) {
            $defaults.OnlyConsoles = @(@($o.OnlyConsoles) | ForEach-Object { "$_" })
        }
    }
    catch {
        try { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue } catch { }
    }
    return [hashtable]$defaults
}

function Invoke-GamePopulatorScriptRestart {
    param([hashtable]$Intent = @{})
    if ($null -ne $Intent -and $Intent.Count -gt 0) {
        Write-GamePopulatorLaunchIntent -Intent $Intent
    }
    & $script:EntryScriptPath -Diag:([bool]$script:GamePopulatorCliDiag)
    exit $LASTEXITCODE
}

function Show-Help {
    param(
        [switch]$NoExit
    )
    Clear-Host
    Write-Host "=== [ $script:ScriptName ]===" -ForegroundColor Blue
    Write-Host "=== [ Version $script:ScriptVersion ] ===`n" -ForegroundColor Blue

    Write-Info "Organizes game images for copying to MiSTer (network shares or local/USB drives)."
    Write-Info "By default, the script extracts archives to loose files on the destination. Menu 11-12 and single-system zip-on-destination mode use max-compression .zip on the destination for non-optical systems; optical cores keep CHD and BIN+CUE behavior.`n"

    Write-Host "Parameters (command line):" -ForegroundColor DarkYellow
    Write-Host "  -Help    Show this help." -ForegroundColor White
    Write-Host "  -Diag    Print startup progress (use if the script seems to hang)." -ForegroundColor White
    Write-Host ""
    Write-Host "Migrate modes, cleanup, destination/temp paths, console filters, resume, guided single-system and custom runs, is done through the " -NoNewline -ForegroundColor White
    Write-Host "interactive menu." -NoNewline -ForegroundColor DarkYellow
    Write-Host "`nCarefully editing " -NoNewline -ForegroundColor White
    Write-Host "libraries\settings.json" -NoNewline -ForegroundColor Green
    Write-Host " and the files under " -NoNewline -ForegroundColor White
    Write-Host "libraries\ " -NoNewline -ForegroundColor Green
    Write-Host "is not preferred." -ForegroundColor White

    Write-Host ""
    Write-Host "Interactive menu:" -ForegroundColor DarkYellow
    Write-Host "  Maintenance" -ForegroundColor DarkYellow
    Write-Host "    1. Toggle visibility and/or edit source paths." -ForegroundColor White
    Write-Host "    2. Define script settings." -ForegroundColor White
    Write-Host "    3. Validate configuration libraries." -ForegroundColor White
    Write-Host "    4. Validate active sources (folders + SMB, same check as migrate)." -ForegroundColor White
    Write-Host "    5. Destination file & folder cleanup." -ForegroundColor White
    Write-Host "    6. Reset network SMB connections." -ForegroundColor White
    Write-Host "    7. Recreate config files under libraries from templates." -ForegroundColor White
    Write-Host "    8. Install latest files from GitHub.`n" -ForegroundColor White

    Write-Host "  Actions" -ForegroundColor DarkYellow
    Write-Host "    9.  Archive extraction and file copying, with region organization." -ForegroundColor White
    Write-Host "    10. Archive extraction and file copying, without region organization." -ForegroundColor White
    Write-Host "    11. Zip on destination (non-optical cores), with region organization — see Notes." -ForegroundColor White
    Write-Host "    12. Zip on destination (non-optical cores), without region organization." -ForegroundColor White
    Write-Host "    13. Single system copy (guided process)." -ForegroundColor White
    Write-Host "    14. Custom run (folders and paths as you specify, with verified connectivity).`n" -ForegroundColor White

    Write-Host "    H. Help" -ForegroundColor White

    Write-Host "    E. Exit`n" -ForegroundColor White

    Write-Host "Config files (under " -NoNewline -ForegroundColor DarkYellow
    Write-Host "libraries\" -NoNewline -ForegroundColor Green
    Write-Host "):" -ForegroundColor DarkYellow
    Write-Host "  Changing these through this script (maintenance 1, 2, and 7) is prefer over manuaklly editing." -ForegroundColor DarkGray
    Write-Host "  Hand-editing JSON or PSD1 is easy to break validation or merge rules." -ForegroundColor DarkGray
    Write-Host "  Each source Name must match an entry in the merged names JSON files." -ForegroundColor DarkGray
    Write-Host ""
    $cfIndent = '    '
    Write-Host $cfIndent -NoNewline
    Write-Host ('{0,-30}' -f 'settings.json') -NoNewline -ForegroundColor Green
    Write-Host 'Paths, 7-Zip, and share credentials.' -ForegroundColor White
    Write-Host $cfIndent -NoNewline
    Write-Host ('{0,-30}' -f 'console-sources.psd1') -NoNewline -ForegroundColor Green
    Write-Host 'Standard console share list (uncomment to enable).' -ForegroundColor White
    Write-Host $cfIndent -NoNewline
    Write-Host ('{0,-30}' -f 'hacks-sources.psd1') -NoNewline -ForegroundColor Green
    Write-Host 'Game Hacks + Improvements (MSU-MD, MSU-1, speed hacks, etc.).' -ForegroundColor White
    Write-Host $cfIndent -NoNewline
    Write-Host ('{0,-30}' -f 'trans-sources.psd1') -NoNewline -ForegroundColor Green
    Write-Host 'Game translations ([T-En] dumps, paired with ' -NoNewline -ForegroundColor White
    Write-Host 'trans-names.json' -NoNewline -ForegroundColor Green
    Write-Host ').' -ForegroundColor White
    Write-Host $cfIndent -NoNewline
    Write-Host ('{0,-30}' -f 'addons-sources.psd1') -NoNewline -ForegroundColor Green
    Write-Host 'Music players (NSF/SPC -> ' -NoNewline -ForegroundColor White
    Write-Host 'games\' -NoNewline -ForegroundColor Green
    Write-Host ' per ' -NoNewline -ForegroundColor White
    Write-Host 'addons-names.json' -NoNewline -ForegroundColor Green
    Write-Host ' ShortName/SubDir).' -ForegroundColor White
    Write-Host $cfIndent -NoNewline
    Write-Host ('{0,-30}' -f 'console-names.json') -NoNewline -ForegroundColor Green
    Write-Host 'Standard console definitions (names, short names, subdirs, extensions).' -ForegroundColor White
    Write-Host $cfIndent -NoNewline
    Write-Host ('{0,-30}' -f 'hacks-names.json') -NoNewline -ForegroundColor Green
    Write-Host 'Hacks / improvements definitions.' -ForegroundColor White
    Write-Host $cfIndent -NoNewline
    Write-Host ('{0,-30}' -f 'trans-names.json') -NoNewline -ForegroundColor Green
    Write-Host 'Translation systems (paired with trans-sources).' -ForegroundColor White
    Write-Host $cfIndent -NoNewline
    Write-Host ('{0,-30}' -f 'addons-names.json') -NoNewline -ForegroundColor Green
    Write-Host 'Music player definitions (Music: yes).' -ForegroundColor White
    
    Write-Host "`nTemplates (under " -NoNewline -ForegroundColor DarkYellow
    Write-Host "libraries\" -NoNewline -ForegroundColor Green
    Write-Host "):" -ForegroundColor DarkYellow
    Write-Host "  Recreated by maintenance option 7 (or when a file is missing); avoid editing templates by hand unless you are copying layout from upstream." -ForegroundColor DarkGray
    Write-Host ""
    $tpIndent = '    '
    foreach ($tpl in @(
            'settings.template.json',
            'console-sources.template.psd1',
            'hacks-sources.template.psd1',
            'trans-sources.template.psd1',
            'addons-sources.template.psd1',
            'console-names.template.json',
            'hacks-names.template.json',
            'trans-names.template.json',
            'addons-names.template.json'
        )) {
        Write-Host $tpIndent -NoNewline
        Write-Host $tpl -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor DarkYellow
    Write-Host "  - Existing destination files are never overwritten." -ForegroundColor White
    Write-Host "  - Set destination and temp paths via " -NoNewline -ForegroundColor White
    Write-Host "maintenance menu 2" -NoNewline -ForegroundColor DarkYellow
    Write-Host " (" -NoNewline -ForegroundColor White
    Write-Host "settings.json" -NoNewline -ForegroundColor Green
    Write-Host " under " -NoNewline -ForegroundColor White
    Write-Host "libraries\" -NoNewline -ForegroundColor Green
    Write-Host ")." -ForegroundColor White
    Write-Host "  - If a template is missing locally, the script can fetch it from GitHub." -ForegroundColor White
    Write-Host '  - UNC per server (\\host): destination and sources on the same hostname must share one SMB login.' -ForegroundColor White
    Write-Host "  - If the folder name at the destination path end is not " -NoNewline -ForegroundColor White
    Write-Host "games" -NoNewline -ForegroundColor Green
    Write-Host ", " -NoNewline -ForegroundColor White
    Write-Host "\games" -NoNewline -ForegroundColor Green
    Write-Host " is appended so layouts match MiSTer's expected games folder." -ForegroundColor White
    Write-Host "  - CHD files are copied as-is." -ForegroundColor White
    Write-Host "  - Folders with extracted BIN/CUE are copied as-is in a separate game folder." -ForegroundColor White
    Write-Host "  - Zip-on-destination (menu 11-12 or single-system zip):" -ForegroundColor White
    Write-Host "    -- For non-optical systems, loose roms become .zip on the destination only." -ForegroundColor White
    Write-Host "    -- Existing .zip sources copy as files." -ForegroundColor White
    Write-Host "    -- Other archives (7z and rar) unpack to temp then re-zipped to destination." -ForegroundColor White
    Write-Host "    -- Optical cores unchanged." -ForegroundColor White
    Write-Host "  - Region organization moves files into region folders during processing." -ForegroundColor White
    Write-Host "  - Cleanup removes destination files whose extension is not in the console allow list (.rom and .zip always allowed)." -ForegroundColor White
    Write-Host "  - One structured NDJSON line per migrate event lives under " -NoNewline -ForegroundColor White
    Write-Host ".\logs" -NoNewline -ForegroundColor Green
    Write-Host " (run-<timestamp>.ndjson) while " -NoNewline -ForegroundColor White
    Write-Host "StructuredRunLog" -NoNewline -ForegroundColor DarkYellow
    Write-Host " is true." -ForegroundColor White
    Write-Host "  - With " -NoNewline -ForegroundColor White
    Write-Host "UseRunCheckpoint" -NoNewline -ForegroundColor DarkYellow
    Write-Host ", resume data is " -NoNewline -ForegroundColor White
    Write-Host "logs\game-populator-checkpoint.json" -NoNewline -ForegroundColor Green
    Write-Host " — the menu can prompt to resume after an interrupted migrate.`n" -ForegroundColor White

    if (-not $NoExit) {
        exit 0
    }
}

function Read-YesNoDefaultYes {
    param([Parameter(Mandatory = $true)][string]$Prompt)
    while ($true) {
        # Read-Host works across hosts; [Console]::ReadLine() can block indefinitely in some consoles
        # or when no stdin is attached (looks like a hang with no prompt).
        Invoke-OutputFlush
        $answer = Read-Host ($Prompt + ' (Y/N) [Y]')
        if ($null -eq $answer) { $answer = '' }
        $answer = $answer.Trim()
        if ([string]::IsNullOrWhiteSpace($answer)) { return $true }
        if ($answer -match '^(y|yes)$') { return $true }
        if ($answer -match '^(n|no)$') { return $false }
        Write-Warn "Please enter Y or N."
    }
}

function Read-YesNoDefaultNo {
    param([Parameter(Mandatory = $true)][string]$Prompt)
    while ($true) {
        Invoke-OutputFlush
        $answer = Read-Host ($Prompt + ' (Y/N) [N]')
        if ($null -eq $answer) { $answer = '' }
        $answer = $answer.Trim()
        if ([string]::IsNullOrWhiteSpace($answer)) { return $false }
        if ($answer -match '^(y|yes)$') { return $true }
        if ($answer -match '^(n|no)$') { return $false }
        Write-Warn "Please enter Y or N."
    }
}

function Format-PathForDisplay {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $bs = '\'
    $unc2 = $bs + $bs
    if ($Path.StartsWith($unc2, [StringComparison]::Ordinal)) {
        return $unc2 + (($Path.Substring(2)) -replace '\\+', '\')
    }
    return ($Path -replace '\\+', '\')
}

function Repair-JsonPathValues {
    param(
        [Parameter(Mandatory = $true)][string]$JsonText,
        [Parameter(Mandatory = $true)][string[]]$Keys
    )
    $output = $JsonText
    foreach ($key in $Keys) {
        $pattern = '"' + [regex]::Escape($key) + '"\s*:\s*"([^"]*)"'
        $output = [regex]::Replace($output, $pattern, {
                param($m)
                $value = $m.Groups[1].Value
                $fixed = ($value -replace '(?<!\\)\\(?!\\)', '\\\\')
                return '"' + $key + '": "' + $fixed + '"'
            })
    }
    return $output
}

function Invoke-GamePopulatorSelfUpdate {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptRoot,
        [string]$LibrariesRoot = ''
    )
    if ([string]::IsNullOrWhiteSpace($LibrariesRoot)) {
        $LibrariesRoot = Join-Path $ScriptRoot 'libraries'
    }
    $protectedLeaves = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($leaf in @(
            'settings.json',
            'console-sources.psd1',
            'hacks-sources.psd1',
            'trans-sources.psd1',
            'addons-sources.psd1',
            'console-names.json',
            'hacks-names.json',
            'trans-names.json',
            'addons-names.json'
        )) {
        $protectedLeaves.Add($leaf) | Out-Null
    }
    Write-Host "`nThis will download the latest script files from " -NoNewline -ForegroundColor Yellow
    Write-Host $script:GamePopulatorRepoUrl -NoNewline -ForegroundColor Green
    Write-Host "?" -ForegroundColor Yellow
    Write-Info ("Existing config under `{0}` (settings, all source lists, all names JSON) is not overwritten." -f ($LibrariesRoot -replace '/', '\'))
    if (-not (Read-YesNoDefaultNo 'OK to proceed?')) {
        return $false
    }

    $gitDir = Join-Path $ScriptRoot '.git'
    if ((Test-Path -LiteralPath $gitDir) -and (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Info "Updating via git..."
        $pullOutput = & git -C $ScriptRoot pull --ff-only 2>&1
        if ($LASTEXITCODE -ne 0) {
            $pullOutput = & git -C $ScriptRoot pull --ff-only origin main 2>&1
        }
        $pullOutput | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Git update completed."
            return $true
        }
        Write-Warn "Git pull failed (exit code $LASTEXITCODE). Trying ZIP download from GitHub..."
    }

    $tempBase = [System.IO.Path]::GetTempPath()
    $zipPath = Join-Path $tempBase ('game-populator-update-' + [Guid]::NewGuid().ToString('N') + '.zip')
    $extractRoot = Join-Path $tempBase ('game-populator-update-' + [Guid]::NewGuid().ToString('N'))

    try {
        Write-Info "Downloading: $script:GamePopulatorMainZipUrl"
        try {
            Invoke-WebRequest -Uri $script:GamePopulatorMainZipUrl -OutFile $zipPath -UseBasicParsing
        }
        catch {
            Write-Warn "Download failed: $($_.Exception.Message)"
            return $false
        }

        if (-not (Test-Path -LiteralPath $zipPath)) {
            Write-Warn "Download did not produce an archive file."
            return $false
        }

        New-Item -Path $extractRoot -ItemType Directory -Force | Out-Null
        try {
            Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force
        }
        catch {
            Write-Warn "Could not extract archive: $($_.Exception.Message)"
            return $false
        }

        $innerFolder = @(Get-ChildItem -LiteralPath $extractRoot -Directory -ErrorAction SilentlyContinue) | Select-Object -First 1
        if (-not $innerFolder) {
            Write-Warn "Update archive had an unexpected layout."
            return $false
        }

        Write-Info ("Installing into:`n  {0}`n    (core script + repo files)`nand`n  {1}`n    (libraries\ - helpers, JSON, PSD1, templates)." -f $ScriptRoot, $LibrariesRoot)

        foreach ($item in @(Get-ChildItem -LiteralPath $innerFolder.FullName -Force -ErrorAction SilentlyContinue)) {
            $nm = [string]$item.Name
            if ($item.PSIsContainer -and ($nm -ieq 'libraries')) {
                try {
                    if (-not (Test-Path -LiteralPath $LibrariesRoot -PathType Container)) {
                        New-Item -Path $LibrariesRoot -ItemType Directory -Force | Out-Null
                    }
                    Copy-Item -LiteralPath "$($item.FullName)\*" -Destination $LibrariesRoot -Recurse -Force
                }
                catch {
                    Write-Warn "Could not merge libraries folder from archive: $($_.Exception.Message)"
                }
                continue
            }

            if ($item.PSIsContainer) {
                $destRootDir = Join-Path $ScriptRoot $nm
                try {
                    Copy-Item -LiteralPath $item.FullName -Destination $destRootDir -Recurse -Force
                }
                catch {
                    Write-Warn "Skipping folder $($item.Name): $($_.Exception.Message)"
                }
                continue
            }

            $destLeaf = $nm
            if ($nm -eq 'game-populator.ps1') {
                $destParent = $ScriptRoot
            }
            elseif ($null -ne $script:GamePopulatorLeavesUnderLibraries -and ($script:GamePopulatorLeavesUnderLibraries.Contains($destLeaf))) {
                if (-not (Test-Path -LiteralPath $LibrariesRoot -PathType Container)) {
                    New-Item -Path $LibrariesRoot -ItemType Directory -Force | Out-Null
                }
                $destParent = $LibrariesRoot
            }
            else {
                $destParent = $ScriptRoot
            }
            $destPath = Join-Path $destParent $destLeaf

            if ($protectedLeaves.Contains($destLeaf) -and (Test-Path -LiteralPath $destPath)) {
                Write-Host 'Keeping existing: ' -NoNewline -ForegroundColor DarkGray
                $dispExisting = if ($destParent.TrimEnd('\') -ieq $LibrariesRoot.TrimEnd('\')) {
                    ('libraries\{0}' -f $destLeaf)
                }
                else {
                    $destLeaf
                }
                Write-Host $dispExisting -ForegroundColor Gray
                continue
            }

            Copy-Item -LiteralPath $item.FullName -Destination $destPath -Force
        }

        Write-Info "Update from ZIP completed."
        return $true
    }
    finally {
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Restore-GamePopulatorTemplatesFromGitHub {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptRoot,
        [Parameter(Mandatory = $true)][string[]]$TemplateFileNames,
        [string]$LibrariesRoot = ''
    )
    if ([string]::IsNullOrWhiteSpace($LibrariesRoot)) {
        $LibrariesRoot = Join-Path $ScriptRoot 'libraries'
    }
    if (-not $TemplateFileNames -or $TemplateFileNames.Count -eq 0) {
        return $true
    }

    $tempBase = [System.IO.Path]::GetTempPath()
    $zipPath = Join-Path $tempBase ('game-populator-templates-' + [Guid]::NewGuid().ToString('N') + '.zip')
    $extractRoot = Join-Path $tempBase ('game-populator-templates-' + [Guid]::NewGuid().ToString('N'))

    try {
        Write-Info "Downloading: $script:GamePopulatorMainZipUrl"
        try {
            Invoke-WebRequest -Uri $script:GamePopulatorMainZipUrl -OutFile $zipPath -UseBasicParsing
        }
        catch {
            Write-Warn "Download failed: $($_.Exception.Message)"
            return $false
        }

        if (-not (Test-Path -LiteralPath $zipPath)) {
            Write-Warn "Download did not produce an archive file."
            return $false
        }

        New-Item -Path $extractRoot -ItemType Directory -Force | Out-Null
        try {
            Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force
        }
        catch {
            Write-Warn "Could not extract archive: $($_.Exception.Message)"
            return $false
        }

        $innerFolder = @(Get-ChildItem -LiteralPath $extractRoot -Directory -ErrorAction SilentlyContinue) | Select-Object -First 1
        if (-not $innerFolder) {
            Write-Warn "Archive had an unexpected layout."
            return $false
        }

        if (-not (Test-Path -LiteralPath $LibrariesRoot -PathType Container)) {
            New-Item -Path $LibrariesRoot -ItemType Directory -Force | Out-Null
        }

        foreach ($requestedName in $TemplateFileNames) {
            $libsSub = Join-Path $innerFolder.FullName 'libraries'
            $srcFile = Join-Path $innerFolder.FullName $requestedName
            if (-not (Test-Path -LiteralPath $srcFile -PathType Leaf)) {
                $tryAlt = Join-Path $libsSub $requestedName
                if (-not (Test-Path -LiteralPath $tryAlt -PathType Leaf)) {
                    Write-Warn "Template not found in GitHub archive: $requestedName"
                    return $false
                }
                $srcFile = $tryAlt
            }
            $destFile = Join-Path $LibrariesRoot $requestedName
            Copy-Item -LiteralPath $srcFile -Destination $destFile -Force
            Write-Info ('Restored template: libraries\{0}' -f $requestedName)
        }
        return $true
    }
    finally {
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Format-TextPreview {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$MaxLength
    )
    if ($MaxLength -le 0) { return '' }
    if ($Text.Length -le $MaxLength) { return $Text }
    if ($MaxLength -le 3) { return $Text.Substring(0, $MaxLength) }
    return $Text.Substring(0, $MaxLength - 3) + '...'
}

function Format-Size {
    param([Parameter(Mandatory = $true)][long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ([double]$Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ([double]$Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ([double]$Bytes / 1KB)) }
    return ("$Bytes B")
}

function Format-Elapsed {
    param([Parameter(Mandatory = $true)][TimeSpan]$Elapsed)
    if ($Elapsed.Days -gt 0) {
        $dayWord = if ($Elapsed.Days -eq 1) { 'day' } else { 'days' }
        return ("{0} {1} {2:00}:{3:00}:{4:00}" -f $Elapsed.Days, $dayWord, $Elapsed.Hours, $Elapsed.Minutes, $Elapsed.Seconds)
    }
    return ("{0:00}:{1:00}:{2:00}" -f $Elapsed.Hours, $Elapsed.Minutes, $Elapsed.Seconds)
}

function Get-ConsoleWidth {
    $default = 120
    try { return [Math]::Max(1, $Host.UI.RawUI.WindowSize.Width) } catch { return $default }
}

$script:lastLineLength = 0
$script:currentConsoleStopwatch = $null
function Write-ProgressLine {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$ItemName,
        [Parameter(Mandatory = $true)][long]$Bytes,
        [Parameter(Mandatory = $true)][TimeSpan]$Elapsed
    )

    $elapsedText = Format-Elapsed -Elapsed $Elapsed
    $sizeText = Format-Size -Bytes $Bytes
    $prefix = "$Action ($elapsedText) - "
    $suffix = " ($sizeText)"

    $consoleWidth = Get-ConsoleWidth
    $maxNameLength = [Math]::Max(8, $consoleWidth - ($prefix.Length + $suffix.Length))
    $nameText = Format-TextPreview -Text $ItemName -MaxLength $maxNameLength

    $lineLength = $prefix.Length + $nameText.Length + $suffix.Length
    $pad = ' ' * [Math]::Max(0, $script:lastLineLength - $lineLength)

    Write-Host "`r$prefix" -NoNewline -ForegroundColor White
    Write-Host $nameText -NoNewline -ForegroundColor DarkCyan
    Write-Host "$suffix$pad" -NoNewline -ForegroundColor Gray
    $script:lastLineLength = $lineLength
}

function Write-OrganizeProgressLine {
    param(
        [Parameter(Mandatory = $true)][string]$ConsoleName,
        [Parameter(Mandatory = $true)][TimeSpan]$Elapsed
    )

    $elapsedText = Format-Elapsed -Elapsed $Elapsed
    $prefix = "Organizing existing files for console: "
    $suffix = " (" + $elapsedText + ")"

    $consoleWidth = Get-ConsoleWidth
    $maxNameLength = [Math]::Max(8, $consoleWidth - ($prefix.Length + $suffix.Length))
    $nameText = Format-TextPreview -Text $ConsoleName -MaxLength $maxNameLength

    $lineLength = $prefix.Length + $nameText.Length + $suffix.Length
    $pad = ' ' * [Math]::Max(0, $script:lastLineLength - $lineLength)

    Write-Host "`r$prefix" -NoNewline -ForegroundColor White
    Write-Host $nameText -NoNewline -ForegroundColor White
    Write-Host "$suffix$pad" -NoNewline -ForegroundColor Blue
    $script:lastLineLength = $lineLength
}

function Update-OrganizeProgress {
    param(
        [Parameter(Mandatory = $true)][string]$ConsoleName,
        [Parameter(Mandatory = $true)][System.Diagnostics.Stopwatch]$Stopwatch
    )
    if (-not $script:organizeLastTick) { $script:organizeLastTick = @{} }
    $tick = [int][Math]::Floor($Stopwatch.Elapsed.TotalSeconds)
    $key = $ConsoleName.ToLowerInvariant()
    if (-not $script:organizeLastTick.ContainsKey($key) -or $script:organizeLastTick[$key] -ne $tick) {
        $script:organizeLastTick[$key] = $tick
        Write-OrganizeProgressLine -ConsoleName $ConsoleName -Elapsed $Stopwatch.Elapsed
    }
}

function Write-7zProgressLine {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][int]$Percent,
        [Parameter(Mandatory = $true)][string]$ItemName,
        [string]$Entry,
        [Parameter(Mandatory = $true)][TimeSpan]$Elapsed
    )

    $elapsedText = Format-Elapsed -Elapsed $Elapsed
    $prefix = "$Action $Percent% ($elapsedText) - "
    $consoleWidth = Get-ConsoleWidth
    $maxNameLength = [Math]::Max(8, $consoleWidth - $prefix.Length)
    $nameText = Format-TextPreview -Text $ItemName -MaxLength $maxNameLength

    if ($Entry -match '\|?\s*archive:\s*.+') {
        $Entry = ($Entry -replace '\|?\s*archive:\s*.+', '').Trim()
    }
    $entryText = if ([string]::IsNullOrWhiteSpace($Entry)) { '' } else { " | $Entry" }
    $maxEntryLength = [Math]::Max(0, $consoleWidth - ($prefix.Length + $nameText.Length + 3))
    $entryDisplay = if ($entryText) { Format-TextPreview -Text $entryText -MaxLength $maxEntryLength } else { '' }

    $lineLength = $prefix.Length + $nameText.Length + $entryDisplay.Length
    $pad = ' ' * [Math]::Max(0, $script:lastLineLength - $lineLength)

    Write-Host "`r$prefix" -NoNewline -ForegroundColor White
    Write-Host $nameText -NoNewline -ForegroundColor DarkCyan
    Write-Host "$entryDisplay$pad" -NoNewline -ForegroundColor Gray
    $script:lastLineLength = $lineLength
}

$script:SevenZipExe = 'C:\Program Files\7-Zip\7z.exe'
function Initialize-7z {
    if (Test-Path -LiteralPath $script:SevenZipExe) { return }
    Write-Host "7z.exe was not found at " -NoNewline -ForegroundColor Yellow
    Write-Host $script:SevenZipExe -ForegroundColor White
    Write-Info "Enter the full path to 7z.exe, or type Q to quit and open the download page."
    while ($true) {
        $inputPath = (Read-Host "7z.exe path or Q").Trim()
        if ($inputPath -match '^(q|quit)$') {
            Start-Process "https://www.7-zip.org/"
            exit 0
        }
        if (Test-Path -LiteralPath $inputPath) {
            $resolved = (Resolve-Path -LiteralPath $inputPath).Path
            if (Test-Path -LiteralPath $resolved -PathType Container) {
                $resolved = Join-Path $resolved '7z.exe'
            }
            if (Test-Path -LiteralPath $resolved -PathType Leaf) {
                $script:SevenZipExe = $resolved
                return
            }
        }
        Write-Host "Path does not exist: " -NoNewline -ForegroundColor Yellow
        Write-Host $inputPath -ForegroundColor White
    }
}

function Invoke-7z {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$ProgressLabel,
        [string]$ProgressName
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:SevenZipExe
    $psi.Arguments = ($Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($psi)

    $showProgress = -not [string]::IsNullOrWhiteSpace($ProgressLabel)
    $lastPercent = -1
    $currentEntry = ''
    $lastOutput = New-Object System.Collections.Generic.Queue[string]

    while (-not $process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        if ($line) {
            if ($lastOutput.Count -ge 10) { $null = $lastOutput.Dequeue() }
            $lastOutput.Enqueue($line)
        }
        if (-not $showProgress) { continue }
        if ($line -match '(\d{1,3})%') {
            $lastPercent = [int]$matches[1]
            $elapsed = if ($script:currentConsoleStopwatch) { $script:currentConsoleStopwatch.Elapsed } else { [TimeSpan]::Zero }
            Write-7zProgressLine -Action $ProgressLabel -Percent $lastPercent -ItemName $ProgressName -Entry $currentEntry -Elapsed $elapsed
        }
        elseif ($line -match '^(Extracting|Compressing|Updating)\s+(.+)$') {
            $currentEntry = $matches[2].Trim()
            if ($lastPercent -ge 0) {
                $elapsed = if ($script:currentConsoleStopwatch) { $script:currentConsoleStopwatch.Elapsed } else { [TimeSpan]::Zero }
                Write-7zProgressLine -Action $ProgressLabel -Percent $lastPercent -ItemName $ProgressName -Entry $currentEntry -Elapsed $elapsed
            }
        }
    }

    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        $err = $process.StandardError.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($err)) {
            Write-Host $err.Trim() -ForegroundColor Red
        }
        $errText = if ($err) { $err.Trim() } else { "No stderr output." }
        $stdoutText = if ($lastOutput.Count -gt 0) { ($lastOutput.ToArray() -join ' | ') } else { "No stdout output." }
        $argText = $psi.Arguments
        throw "7z failed (exit code $($process.ExitCode)). $errText Stdout: $stdoutText Args: $argText"
    }

    if ($showProgress) {
        if ($lastPercent -lt 100) {
            $elapsed = if ($script:currentConsoleStopwatch) { $script:currentConsoleStopwatch.Elapsed } else { [TimeSpan]::Zero }
            Write-7zProgressLine -Action $ProgressLabel -Percent 100 -ItemName $ProgressName -Entry $currentEntry -Elapsed $elapsed
        }
        $script:lastLineLength = 0
    }
}

function Invoke-Gp7zCompressSingleFileToNewZipMax {
    param(
        [Parameter(Mandatory = $true)][string]$SourceFileLiteralPath,
        [Parameter(Mandatory = $true)][string]$DestinationZipLiteralPath,
        [string]$ProgressName = ''
    )
    Initialize-7z
    $srcDir = [System.IO.Path]::GetDirectoryName($SourceFileLiteralPath)
    $leaf = [System.IO.Path]::GetFileName($SourceFileLiteralPath)
    if (-not ($srcDir) -or -not $leaf -or [string]::IsNullOrWhiteSpace($srcDir) -or [string]::IsNullOrWhiteSpace($leaf)) {
        throw "Resolve source path failed for Invoke-Gp7zCompressSingleFileToNewZipMax: $SourceFileLiteralPath"
    }
    $dzDir = [System.IO.Path]::GetDirectoryName($DestinationZipLiteralPath)
    if (-not [string]::IsNullOrWhiteSpace($dzDir) -and -not (Test-Path -LiteralPath $dzDir -PathType Container)) {
        New-Item -LiteralPath $dzDir -ItemType Directory -Force | Out-Null
    }
    if (Test-Path -LiteralPath $DestinationZipLiteralPath) {
        Remove-Item -LiteralPath $DestinationZipLiteralPath -Force -ErrorAction Stop
    }
    $prior = Get-Location
    try {
        Set-Location -LiteralPath $srcDir
        $pn = if (-not [string]::IsNullOrWhiteSpace($ProgressName)) {
            $ProgressName
        }
        else {
            $leaf + ' → .zip'
        }
        Invoke-7z -Arguments @(
            'a', '-tzip', '-mx=9', '-mm=Deflate', '-bd',
            '-bso1', '-bse1', '-bsp1',
            $DestinationZipLiteralPath,
            $leaf
        ) -ProgressLabel 'Compressing' -ProgressName $pn
    }
    finally {
        Set-Location $prior
    }
}

function Invoke-Gp7zCompressFlatWorkingDirToNewZipMax {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingLiteralDirectoryWithFiles,
        [Parameter(Mandatory = $true)][string]$DestinationZipLiteralPath,
        [string]$ProgressName = ''
    )
    Initialize-7z
    $dzDir = [System.IO.Path]::GetDirectoryName($DestinationZipLiteralPath)
    if (-not [string]::IsNullOrWhiteSpace($dzDir) -and -not (Test-Path -LiteralPath $dzDir -PathType Container)) {
        New-Item -LiteralPath $dzDir -ItemType Directory -Force | Out-Null
    }
    if (Test-Path -LiteralPath $DestinationZipLiteralPath) {
        Remove-Item -LiteralPath $DestinationZipLiteralPath -Force -ErrorAction Stop
    }
    $prior = Get-Location
    try {
        Set-Location -LiteralPath $WorkingLiteralDirectoryWithFiles
        $pn = if (-not [string]::IsNullOrWhiteSpace($ProgressName)) {
            $ProgressName
        }
        else {
            'Folder → .zip'
        }
        Invoke-7z -Arguments @(
            'a', '-tzip', '-mx=9', '-mm=Deflate', '-bd',
            '-bso1', '-bse1', '-bsp1',
            '-r',
            $DestinationZipLiteralPath,
            '*'
        ) -ProgressLabel 'Compressing' -ProgressName $pn
    }
    finally {
        Set-Location $prior
    }
}

function Test-ArchiveFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:SevenZipExe
    $psi.Arguments = ('t', '-y', '-bso0', '-bse0', $Path | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($psi)
    $process.WaitForExit()
    return ($process.ExitCode -eq 0)
}

function Copy-ItemsNoOverwrite {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileSystemInfo[]]$Items,
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$DestRoot,
        [int]$MaxConcurrentCopies = -1
    )
    $mc = $MaxConcurrentCopies
    if ($mc -lt 1) {
        $mc = 4
        if ($null -ne $script:GamePopulatorMaxConcurrentFileCopies) {
            try {
                $mc = [int]$script:GamePopulatorMaxConcurrentFileCopies
            }
            catch {
                $mc = 4
            }
        }
    }
    if ($mc -lt 1) { $mc = 1 }
    if ($mc -gt 4) { $mc = 4 }

    $dirsEnsure = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $todo = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Items) {
        $relative = [System.IO.Path]::GetRelativePath($SourceRoot, $item.FullName)
        $destPath = Join-Path $DestRoot $relative
        if ($item.PSIsContainer) {
            [void]$dirsEnsure.Add([string]$destPath)
            continue
        }
        if (Test-Path -LiteralPath $destPath) { continue }
        $destDir = Split-Path -Parent $destPath
        if (-not [string]::IsNullOrEmpty($destDir)) {
            [void]$dirsEnsure.Add([string]$destDir)
        }
        $todo.Add([pscustomobject]@{
                Src = [string]$item.FullName
                Dst = [string]$destPath
                Len = [long]$item.Length
            }) | Out-Null
    }
    foreach ($d in @($dirsEnsure)) {
        if (-not (Test-Path -LiteralPath $d)) {
            New-Item -Path $d -ItemType Directory -Force | Out-Null
        }
    }
    if ($todo.Count -eq 0) {
        return @{ Bytes = 0L; Files = 0 }
    }

    if ($mc -le 1 -or $todo.Count -eq 1) {
        $copiedBytes = 0L
        $copiedFiles = 0
        foreach ($w in $todo) {
            Copy-Item -LiteralPath $w.Src -Destination $w.Dst
            $copiedBytes += $w.Len
            $copiedFiles++
        }
        return @{ Bytes = $copiedBytes; Files = $copiedFiles }
    }

    $throttle = [Math]::Min([int]$mc, [int]$todo.Count)
    $parts = $todo.ToArray() | ForEach-Object -Parallel {
        $w = $_
        try {
            Copy-Item -LiteralPath $w.Src -Destination $w.Dst -ErrorAction Stop
            [pscustomobject]@{ Ok = $true; Bytes = $w.Len; Files = 1; Err = ''; Src = [string]$w.Src }
        }
        catch {
            [pscustomobject]@{ Ok = $false; Bytes = [long]0; Files = 0; Err = $_.Exception.Message; Src = [string]$w.Src }
        }
    } -ThrottleLimit $throttle

    $bad = @($parts | Where-Object { $_.Ok -eq $false })
    if ($bad.Count -gt 0) {
        $b0 = $bad[0]
        $leaf = [System.IO.Path]::GetFileName([string]$b0.Src)
        throw ('Copy failed for {0}: {1}' -f $leaf, $b0.Err)
    }

    $sumB = ($parts | Measure-Object -Property Bytes -Sum).Sum
    $sumF = ($parts | Measure-Object -Property Files -Sum).Sum
    if ($null -eq $sumB) { $sumB = [long]0 }
    if ($null -eq $sumF) { $sumF = 0 }
    return @{
        Bytes = [long]$sumB
        Files = [int]$sumF
    }
}

function New-ShareDrive {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$User,
        [SecureString]$Password
    )
    Test-SmbEstablishedCredentialCompatibility -UncRoot $Root -Purpose 'this console source' -ShareUser $User -SharePassword $Password
    $driveName = "SRC{0}" -f ([Guid]::NewGuid().ToString('N').Substring(0, 6))
    if ([string]::IsNullOrWhiteSpace($User) -or $null -eq $Password) {
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $Root -ErrorAction Stop -Scope Global | Out-Null
    }
    else {
        $cred = New-Object System.Management.Automation.PSCredential ($User, $Password)
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $Root -Credential $cred -ErrorAction Stop -Scope Global | Out-Null
    }
    Register-SmbEstablishmentForUncPath -UncRoot $Root -ShareUser $User -SharePassword $Password
    return "$driveName`:\"
}

function Test-ConsoleSourcePath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$User,
        [SecureString]$Password
    )
    $drivePath = $null
    try {
        $drivePath = New-ShareDrive -Root $Root -User $User -Password $Password
        if (-not (Test-Path -LiteralPath $drivePath)) {
            return @{ OK = $false; Error = 'Mapped drive root is not accessible.' }
        }
        return @{ OK = $true; Error = $null }
    }
    catch {
        $hint = Expand-SmbConnectErrorHint -RawMessage $_.Exception.Message -UncPath $Root
        $combined = $_.Exception.Message
        if ($hint) { $combined = $combined + ' ' + $hint }
        return @{ OK = $false; Error = $combined }
    }
    finally {
        if ($drivePath) {
            Remove-ShareDrive -DrivePath $drivePath
        }
    }
}

function Copy-ItemsFlatNoOverwrite {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileSystemInfo[]]$Items,
        [Parameter(Mandatory = $true)][string]$DestRoot,
        [int]$MaxConcurrentCopies = -1
    )
    $mc = $MaxConcurrentCopies
    if ($mc -lt 1) {
        $mc = 4
        if ($null -ne $script:GamePopulatorMaxConcurrentFileCopies) {
            try {
                $mc = [int]$script:GamePopulatorMaxConcurrentFileCopies
            }
            catch {
                $mc = 4
            }
        }
    }
    if ($mc -lt 1) { $mc = 1 }
    if ($mc -gt 4) { $mc = 4 }

    $todo = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Items) {
        if ($item.PSIsContainer) { continue }
        $destPath = Join-Path $DestRoot $item.Name
        if (Test-Path -LiteralPath $destPath) { continue }
        $todo.Add([pscustomobject]@{
                Src = [string]$item.FullName
                Dst = [string]$destPath
                Len = [long]$item.Length
            }) | Out-Null
    }
    if ($todo.Count -eq 0) {
        return @{ Bytes = 0L; Files = 0 }
    }
    if (-not (Test-Path -LiteralPath $DestRoot)) {
        New-Item -Path $DestRoot -ItemType Directory -Force | Out-Null
    }

    if ($mc -le 1 -or $todo.Count -eq 1) {
        $copiedBytes = 0L
        $copiedFiles = 0
        foreach ($w in $todo) {
            Copy-Item -LiteralPath $w.Src -Destination $w.Dst
            $copiedBytes += $w.Len
            $copiedFiles++
        }
        return @{ Bytes = $copiedBytes; Files = $copiedFiles }
    }

    $throttle = [Math]::Min([int]$mc, [int]$todo.Count)
    $parts = $todo.ToArray() | ForEach-Object -Parallel {
        $w = $_
        try {
            Copy-Item -LiteralPath $w.Src -Destination $w.Dst -ErrorAction Stop
            [pscustomobject]@{ Ok = $true; Bytes = $w.Len; Files = 1; Err = ''; Src = [string]$w.Src }
        }
        catch {
            [pscustomobject]@{ Ok = $false; Bytes = [long]0; Files = 0; Err = $_.Exception.Message; Src = [string]$w.Src }
        }
    } -ThrottleLimit $throttle

    $bad = @($parts | Where-Object { $_.Ok -eq $false })
    if ($bad.Count -gt 0) {
        $b0 = $bad[0]
        $leaf = [System.IO.Path]::GetFileName([string]$b0.Src)
        throw ('Copy failed for {0}: {1}' -f $leaf, $b0.Err)
    }

    $sumB = ($parts | Measure-Object -Property Bytes -Sum).Sum
    $sumF = ($parts | Measure-Object -Property Files -Sum).Sum
    if ($null -eq $sumB) { $sumB = [long]0 }
    if ($null -eq $sumF) { $sumF = 0 }
    return @{
        Bytes = [long]$sumB
        Files = [int]$sumF
    }
}

function Get-BinCueFoldersFromItems {
    param([Parameter(Mandatory = $true)][System.IO.FileSystemInfo[]]$Items)
    $folders = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Items) {
        if ($item.PSIsContainer) { continue }
        if ($item.Extension -ieq '.bin' -or $item.Extension -ieq '.cue') {
            $folders.Add($item.DirectoryName) | Out-Null
        }
    }
    return $folders
}

function Get-RegionFolderName {
    param([Parameter(Mandatory = $true)][string]$Name)
    # Ordered by return value, then by pattern name
    if ($Name -match '\(World\)') { return '00 - World' }
    elseif ($Name -match '\(Canada\)') { return '01 - USA' }
    elseif ($Name -match '\(USA\)') { return '01 - USA' }
    elseif ($Name -match '\(USA,\s*Europe\)') { return '01 - USA' }
    elseif ($Name -match '\(USA,\s*Japan\)') { return '01 - USA' }
    elseif ($Name -match '\(Japan\)') { return '02 - Japan' }
    elseif ($Name -match '\(Japan,\s*USA\)') { return '02 - Japan' }
    elseif ($Name -match '\(Europe\)') { return '03 - Europe' }
    elseif ($Name -match '\(France\)') { return '03 - Europe' }
    elseif ($Name -match '\(Germany\)') { return '03 - Europe' }
    elseif ($Name -match '\(Italy\)') { return '03 - Europe' }
    elseif ($Name -match '\(Spain\)') { return '03 - Europe' }
    elseif ($Name -match '\(Brazil\)') { return '04 - S. America' }
    elseif ($Name -match '\(Latin America\)') { return '04 - S. America' }
    elseif ($Name -match '\(Australia\)') { return '05 - Oceania' }
    elseif ($Name -match '\(Asia\)') { return '06 - Asia' }
    elseif ($Name -match '\(China\)') { return '06 - Asia' }
    elseif ($Name -match '\(Korea\)') { return '06 - Asia' }
    elseif ($Name -match '\(Taiwan\)') { return '06 - Asia' }
    return '99 - Unknown'
}

function Get-RegionFromFiles {
    param([Parameter(Mandatory = $true)][System.IO.FileSystemInfo[]]$Files)
    foreach ($file in $Files) {
        if ($file.PSIsContainer) { continue }
        $region = Get-RegionFolderName -Name $file.Name
        if ($region) { return $region }
    }
    return $null
}

function Get-RegionDestRootFromRegion {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [string]$Region,
        [Parameter(Mandatory = $true)][bool]$Organize
    )
    if (-not $Organize -or -not $Region) { return $BasePath }
    return (Join-Path $BasePath $Region)
}

function Get-OrderedRegionKeys {
    param([Parameter(Mandatory = $true)][string[]]$Keys)
    return @(
        foreach ($key in $Keys) {
            $code = [int]::MaxValue
            $name = $key
            if ($key -match '^\s*(\d+)\s*-\s*(.+?)\s*$') {
                $code = [int]$Matches[1]
                $name = $Matches[2].Trim()
            }
            [pscustomobject]@{
                Key  = $key
                Code = $code
                Name = $name
            }
        }
    ) | Sort-Object Code, Name | ForEach-Object { $_.Key }
}

function Get-RegionCountsFromDestination {
    param([Parameter(Mandatory = $true)][string]$FolderPath)
    $counts = @{}
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return $counts }
    $directories = @(Get-ChildItem -LiteralPath $FolderPath -Directory -ErrorAction SilentlyContinue)
    foreach ($dir in $directories) {
        if ($dir.Name -match '^\d+\s*-\s*') {
            $items = @(Get-ChildItem -LiteralPath $dir.FullName -ErrorAction SilentlyContinue)
            $counts[$dir.Name] = $items.Count
        }
    }
    return $counts
}

function Add-RegionCount {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Counts,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Organize
    )
    if (-not $Organize) { return $null }
    $region = Get-RegionFolderName -Name $Name
    if (-not $region) { return $null }
    if (-not $Counts.ContainsKey($region)) { $Counts[$region] = 0 }
    $Counts[$region]++
    return $region
}

function Get-RegionDestRoot {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Organize
    )
    if (-not $Organize) { return $BasePath }
    if ($Name -match '\.rom$' -and $Name -imatch 'boot') { return $BasePath }
    $region = Get-RegionFolderName -Name $Name
    if (-not $region) { return $BasePath }
    return (Join-Path $BasePath $region)
}

function Get-ContainingRegionFolderName {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$ItemPath
    )
    $rootFull = [System.IO.Path]::GetFullPath($RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $current = Get-Item -LiteralPath $ItemPath -ErrorAction SilentlyContinue
    if (-not $current) { return $null }
    if (-not $current.PSIsContainer) {
        $current = $current.Directory
    }
    while ($current) {
        $currentFull = [System.IO.Path]::GetFullPath($current.FullName).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        if ($currentFull -ieq $rootFull) { break }
        if ($current.Name -match '^\d+\s*-\s*') { return $current.Name }
        $current = $current.Parent
    }
    return $null
}

function Move-RegionInFolder {
    param(
        [Parameter(Mandatory = $true)][string]$FolderPath,
        [string]$ProgressConsoleName,
        [System.Diagnostics.Stopwatch]$ProgressStopwatch,
        [bool]$AllowBinCue = $false
    )
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return }
    $binCueDirs = @()
    $binCueDirPaths = @()
    $binCueDestPaths = @()
    if ($AllowBinCue) {
        $binCueDirs = @(Get-ChildItem -LiteralPath $FolderPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { Test-BinCueFolder -FolderPath $_.FullName })
        $binCueDirPaths = @($binCueDirs | ForEach-Object { [System.IO.Path]::GetFullPath($_.FullName) })
    }

    foreach ($dir in $binCueDirs) {
        if ($ProgressConsoleName -and $ProgressStopwatch) {
            Update-OrganizeProgress -ConsoleName $ProgressConsoleName -Stopwatch $ProgressStopwatch
        }
        if ($ProgressConsoleName -and $ProgressStopwatch) {
            Write-OrganizeProgressLine -ConsoleName $ProgressConsoleName -Elapsed $ProgressStopwatch.Elapsed
        }
        $dirFiles = @(Get-ChildItem -LiteralPath $dir.FullName -File -Recurse -ErrorAction SilentlyContinue)
        $region = Get-RegionFromFiles -Files $dirFiles
        if (-not $region) { continue }
        $currentRegion = Get-ContainingRegionFolderName -RootPath $FolderPath -ItemPath $dir.FullName
        $targetFolder = Join-Path $FolderPath $region
        if (-not (Test-Path -LiteralPath $targetFolder)) {
            New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null
        }
        $destDir = Join-Path $targetFolder $dir.Name
        $sourceFull = [System.IO.Path]::GetFullPath($dir.FullName)
        $destFull = [System.IO.Path]::GetFullPath($destDir)
        if ($currentRegion -ieq $region -and $sourceFull -ieq $destFull) {
            $binCueDestPaths += $destFull
            continue
        }
        if ($sourceFull -ieq $destFull -or $destFull.StartsWith($sourceFull + [System.IO.Path]::DirectorySeparatorChar)) {
            $binCueDestPaths += $destFull
            continue
        }
        if (Test-Path -LiteralPath $destDir) {
            Merge-FolderNoOverwrite -SourcePath $dir.FullName -DestPath $destDir
            $binCueDestPaths += $destFull
            continue
        }
        Move-Item -LiteralPath $dir.FullName -Destination $destDir
        $binCueDestPaths += $destFull
    }

    # Skip files that live inside a BIN/CUE folder (original or moved); they must stay in the per-game folder.
    $sep = [System.IO.Path]::DirectorySeparatorChar
    $pathsToSkipForFiles = @($binCueDirPaths + $binCueDestPaths | ForEach-Object { $_.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) } | Select-Object -Unique)
    $files = @(Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        if ($ProgressConsoleName -and $ProgressStopwatch) {
            Update-OrganizeProgress -ConsoleName $ProgressConsoleName -Stopwatch $ProgressStopwatch
        }
        $fileFull = [System.IO.Path]::GetFullPath($file.FullName)
        $fileDir = [System.IO.Path]::GetFullPath((Split-Path -Parent $file.FullName)).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $skipAsInBinCueFolder = $AllowBinCue -and ($pathsToSkipForFiles | Where-Object {
                $p = $_.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
                $fileDir -eq $p -or $fileDir.StartsWith($p + $sep, [StringComparison]::OrdinalIgnoreCase)
            })
        if ($skipAsInBinCueFolder) { continue }
        if ($ProgressConsoleName -and $ProgressStopwatch) {
            Write-OrganizeProgressLine -ConsoleName $ProgressConsoleName -Elapsed $ProgressStopwatch.Elapsed
        }
        if ($file.Extension -ieq '.rom' -and $file.Name -imatch 'boot') {
            $destAtRoot = Join-Path $FolderPath $file.Name
            $destFullRoot = [System.IO.Path]::GetFullPath($destAtRoot)
            if ($fileFull -ine $destFullRoot -and -not (Test-Path -LiteralPath $destAtRoot)) {
                Move-Item -LiteralPath $file.FullName -Destination $destAtRoot
            }
            continue
        }
        $region = Get-RegionFolderName -Name $file.Name
        if (-not $region) { continue }
        $targetFolder = Join-Path $FolderPath $region
        if (-not (Test-Path -LiteralPath $targetFolder)) {
            New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null
        }
        $destFile = Join-Path $targetFolder $file.Name
        $destFull = [System.IO.Path]::GetFullPath($destFile)
        # Never move .bin/.cue files directly into region folder; they must stay in a per-game folder (Console/Region/GameName).
        if ($AllowBinCue -and ($file.Extension -ieq '.bin' -or $file.Extension -ieq '.cue')) { continue }
        if ($fileFull -ieq $destFull) { continue }
        if (Test-Path -LiteralPath $destFile) { continue }
        Move-Item -LiteralPath $file.FullName -Destination $destFile
    }
}

function Test-BinCueFolder {
    param([Parameter(Mandatory = $true)][string]$FolderPath)
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return $false }
    $files = @(Get-ChildItem -LiteralPath $FolderPath -File -ErrorAction SilentlyContinue)
    if (-not $files -or $files.Count -eq 0) { return $false }
    $hasBinCue = $false
    foreach ($file in $files) {
        if ($file.Extension -ieq '.bin' -or $file.Extension -ieq '.cue') {
            $hasBinCue = $true
        }
        else {
            return $false
        }
    }
    return $hasBinCue
}

function Merge-FolderNoOverwrite {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestPath
    )
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) { return }
    if (-not (Test-Path -LiteralPath $DestPath -PathType Container)) {
        New-Item -Path $DestPath -ItemType Directory -Force | Out-Null
    }
    $files = @(Get-ChildItem -LiteralPath $SourcePath -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        $relative = [System.IO.Path]::GetRelativePath($SourcePath, $file.FullName)
        $destFile = Join-Path $DestPath $relative
        $destDir = Split-Path -Parent $destFile
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        if (Test-Path -LiteralPath $destFile) { continue }
        Move-Item -LiteralPath $file.FullName -Destination $destFile
    }
    Remove-EmptyFolders -RootPath $SourcePath
    $hasItems = (Get-ChildItem -LiteralPath $SourcePath -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
    if (-not $hasItems) {
        Remove-Item -LiteralPath $SourcePath -Force -ErrorAction SilentlyContinue
    }
}

function Convert-ConsoleFolder {
    param(
        [Parameter(Mandatory = $true)][string]$FolderPath,
        [bool]$AllowBinCue = $false,
        [string]$ProgressConsoleName,
        [System.Diagnostics.Stopwatch]$ProgressStopwatch
    )
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return }

    $binCueDirs = @()
    $binCueDestPaths = @()
    if ($AllowBinCue) {
        $binCueDirs = @(Get-ChildItem -LiteralPath $FolderPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { Test-BinCueFolder -FolderPath $_.FullName })
        # Process deepest BIN/CUE folders first so whole per-game folders are moved, not flattened to root.
        $binCueDirs = @($binCueDirs | Sort-Object { $_.FullName.Length } -Descending)
    }

    foreach ($dir in $binCueDirs) {
        if ($ProgressConsoleName -and $ProgressStopwatch) {
            Update-OrganizeProgress -ConsoleName $ProgressConsoleName -Stopwatch $ProgressStopwatch
        }
        if (-not (Test-Path -LiteralPath $dir.FullName -PathType Container)) { continue }
        $destDir = Join-Path $FolderPath $dir.Name
        $sourceFull = [System.IO.Path]::GetFullPath($dir.FullName)
        $destFull = [System.IO.Path]::GetFullPath($destDir)
        if ($sourceFull -ieq $destFull -or $destFull.StartsWith($sourceFull + [System.IO.Path]::DirectorySeparatorChar)) {
            $binCueDestPaths += $destFull
            continue
        }
        if (Test-Path -LiteralPath $destDir) {
            Merge-FolderNoOverwrite -SourcePath $dir.FullName -DestPath $destDir
            $binCueDestPaths += $destFull
            continue
        }
        Move-Item -LiteralPath $dir.FullName -Destination $destDir
        $binCueDestPaths += $destFull
    }

    # Re-scan BIN/CUE folder locations after moves so we skip files that belong in them (files must stay in folder).
    $pathsToSkipForFiles = @()
    $folderPathNorm = [System.IO.Path]::GetFullPath($FolderPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if ($AllowBinCue) {
        $pathsToSkipForFiles = @(Get-ChildItem -LiteralPath $FolderPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { Test-BinCueFolder -FolderPath $_.FullName } | ForEach-Object {
                $p = [System.IO.Path]::GetFullPath($_.FullName).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
                $p
            } | Select-Object -Unique)
    }

    $files = @(Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        if ($ProgressConsoleName -and $ProgressStopwatch) {
            Update-OrganizeProgress -ConsoleName $ProgressConsoleName -Stopwatch $ProgressStopwatch
        }
        if (-not (Test-Path -LiteralPath $file.FullName -PathType Leaf)) { continue }
        $fileFull = [System.IO.Path]::GetFullPath($file.FullName)
        $fileDir = [System.IO.Path]::GetFullPath((Split-Path -Parent $file.FullName)).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $sep = [System.IO.Path]::DirectorySeparatorChar
        $skipAsInBinCueFolder = $AllowBinCue -and ($pathsToSkipForFiles | Where-Object {
                $p = $_.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
                $fileDir -eq $p -or $fileDir.StartsWith($p + $sep, [StringComparison]::OrdinalIgnoreCase)
            })
        if ($skipAsInBinCueFolder) { continue }
        # Never move .bin/.cue files to console root; they must stay in a per-game folder.
        $destFile = Join-Path $FolderPath $file.Name
        $destFull = [System.IO.Path]::GetFullPath($destFile)
        if ($AllowBinCue -and ($file.Extension -ieq '.bin' -or $file.Extension -ieq '.cue')) {
            $destParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $destFull)).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            if ($destParent -ieq $folderPathNorm) { continue }
        }
        if ($fileFull -ieq $destFull) { continue }
        if (Test-Path -LiteralPath $destFile) { continue }
        Move-Item -LiteralPath $file.FullName -Destination $destFile
    }

    Remove-EmptyFolders -RootPath $FolderPath
}

function Remove-DestinationFilesNotMatchingExtensions {
    param(
        [Parameter(Mandatory = $true)][string]$FolderPath,
        [string[]]$AllowedExtensions = @(),
        # When set, only files in FolderPath itself are scanned (not subfolders). Used for stray files under games\.
        [switch]$TopLevelOnly,
        # When set, every discovered file is removed regardless of extension.
        [switch]$DeleteAllFiles
    )
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        return [pscustomobject]@{ FilesRemoved = 0 }
    }
    $allowedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($ext in $AllowedExtensions) {
        if ($null -eq $ext) { continue }
        $e = ($ext.ToString()).Trim()
        if ([string]::IsNullOrWhiteSpace($e)) { continue }
        if (-not $e.StartsWith('.')) { $e = '.' + $e }
        $allowedSet.Add($e) | Out-Null
    }
    $allowedSet.Add('.rom') | Out-Null
    $allowedSet.Add('.zip') | Out-Null

    $removed = 0
    $files = if ($TopLevelOnly) {
        @(Get-ChildItem -LiteralPath $FolderPath -File -ErrorAction SilentlyContinue)
    }
    else {
        @(Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue)
    }
    foreach ($file in $files) {
        if ($DeleteAllFiles -or (-not $allowedSet.Contains($file.Extension))) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $removed++
            }
            catch {
            }
        }
    }
    return [pscustomobject]@{ FilesRemoved = $removed }
}

function Test-IsSgbEnhancedRomName {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $Name -like '*SGB Enhanced*'
}

function Test-IncludeSgbEnhancedForConsole {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][string]$ConsoleKeyLower
    )
    if (-not (Test-IsSgbEnhancedRomName -Name $Name)) {
        return $false
    }
    $ext = $Extension.ToLowerInvariant()
    if (-not $ext.StartsWith('.')) {
        $ext = '.' + $ext
    }
    if ($ConsoleKeyLower -eq 'nintendo super game boy (gb original)') {
        return ($ext -eq '.gb' -or $ext -eq '.sfc')
    }
    if ($ConsoleKeyLower -eq 'nintendo super game boy (gbc original)') {
        return ($ext -eq '.gbc')
    }
    return $false
}

function Remove-SgbEnhancedFilesUnderFolder {
    param([Parameter(Mandatory = $true)][string]$FolderPath)
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return }
    $toRemove = @(Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object { Test-IsSgbEnhancedRomName -Name $_.Name })
    foreach ($f in $toRemove) {
        try {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
        }
        catch {
        }
    }
}

function Invoke-Everdrive256FolderChunking {
    <#
    .SYNOPSIS
        When a folder has more than MaxFiles loose files, split them into numbered subfolders named like 01 - First - Last sorted by name - Everdrive-style 256-item directory limits.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [int]$MaxFiles = 256
    )
    if ($MaxFiles -le 0) { return }
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) { return }

    function Split-FlatFilesIntoEverdriveSubfolders {
        param(
            [Parameter(Mandatory = $true)][string]$FolderPath,
            [Parameter(Mandatory = $true)][int]$Threshold
        )
        $files = @(Get-ChildItem -LiteralPath $FolderPath -File -ErrorAction SilentlyContinue | Sort-Object Name)
        if ($files.Count -le $Threshold) { return }

        $chunks = [System.Collections.ArrayList]::new()
        for ($i = 0; $i -lt $files.Count; $i += $Threshold) {
            $end = [math]::Min($i + $Threshold - 1, $files.Count - 1)
            $slice = $files[$i..$end]
            [void]$chunks.Add($slice)
        }

        for ($j = 0; $j -lt $chunks.Count; $j++) {
            $chunk = $chunks[$j]
            if (-not $chunk -or $chunk.Count -eq 0) { continue }
            $firstWord = (@($chunk[0].BaseName -split '\s+')[0])
            $lastWord = (@($chunk[-1].BaseName -split '\s+')[0])
            $batchNum = '{0:D2}' -f ($j + 1)
            $folderName = "$batchNum - $firstWord - $lastWord" -replace '[<>:"/\\|?*]', ''
            $chunkFolder = Join-Path $FolderPath $folderName
            if (-not (Test-Path -LiteralPath $chunkFolder)) {
                New-Item -Path $chunkFolder -ItemType Directory -Force | Out-Null
            }
            foreach ($file in $chunk) {
                try {
                    Move-Item -LiteralPath $file.FullName -Destination $chunkFolder -Force -ErrorAction Stop
                }
                catch {
                }
            }
        }
    }

    $childDirs = @(Get-ChildItem -LiteralPath $RootPath -Directory -ErrorAction SilentlyContinue)
    $regionLike = @($childDirs | Where-Object { $_.Name -match '^\d+\s*-\s*' })
    if ($regionLike.Count -gt 0) {
        foreach ($d in $regionLike) {
            Split-FlatFilesIntoEverdriveSubfolders -FolderPath $d.FullName -Threshold $MaxFiles
        }
    }
    else {
        Split-FlatFilesIntoEverdriveSubfolders -FolderPath $RootPath -Threshold $MaxFiles
    }
}

function Invoke-ExistingDestination {
    param(
        [Parameter(Mandatory = $true)][string]$FolderPath,
        [Parameter(Mandatory = $true)][bool]$Organize,
        [Parameter(Mandatory = $true)][string[]]$ArchiveExtensions
    )
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return }

    $archives = @(Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $ArchiveExtensions -contains $_.Extension.ToLowerInvariant()
        })
    foreach ($archive in $archives) {
        try {
            Initialize-7z
            $tempExtract = Join-Path $TempRoot ([Guid]::NewGuid().ToString('N'))
            New-Item -Path $tempExtract -ItemType Directory -Force | Out-Null
            try {
                Invoke-7z -Arguments @('x', '-y', '-bso1', '-bse1', '-bsp1', "-o$tempExtract", $archive.FullName) -ProgressLabel "Extracting" -ProgressName $archive.Name
                $extractedItems = @(Get-ChildItem -LiteralPath $tempExtract -Force -ErrorAction SilentlyContinue)
                if (-not $extractedItems -or $extractedItems.Count -eq 0) { continue }
                $allExtractedFiles = @(Get-ChildItem -LiteralPath $tempExtract -Recurse -File -ErrorAction SilentlyContinue)
                $hasBin = @($allExtractedFiles | Where-Object { $_.Extension -ieq '.bin' }).Count -gt 0
                $hasCue = @($allExtractedFiles | Where-Object { $_.Extension -ieq '.cue' }).Count -gt 0
                $isBinCueArchive = ($hasBin -and $hasCue)
                $region = Get-RegionFromFiles -Files $(if ($isBinCueArchive) { $allExtractedFiles } else { $extractedItems })
                $destRoot = Get-RegionDestRootFromRegion -BasePath $FolderPath -Region $region -Organize $Organize
                if (-not (Test-Path -LiteralPath $destRoot)) {
                    New-Item -Path $destRoot -ItemType Directory -Force | Out-Null
                }
                if ($isBinCueArchive) {
                    $gameFolderName = [System.IO.Path]::GetFileNameWithoutExtension($archive.Name)
                    $destGameFolder = Join-Path $destRoot $gameFolderName
                    if (-not (Test-Path -LiteralPath $destGameFolder)) {
                        New-Item -Path $destGameFolder -ItemType Directory -Force | Out-Null
                    }
                    $filesToCopy = @($allExtractedFiles)
                    if ($filesToCopy.Count -gt 0) {
                        Copy-ItemsFlatNoOverwrite -Items $filesToCopy -DestRoot $destGameFolder | Out-Null
                    }
                }
                else {
                    $filesToCopy = @($extractedItems | Where-Object { -not $_.PSIsContainer })
                    if ($filesToCopy.Count -gt 0) {
                        Copy-ItemsFlatNoOverwrite -Items $filesToCopy -DestRoot $destRoot | Out-Null
                    }
                }
            }
            finally {
                if (Test-Path -LiteralPath $tempExtract) {
                    Remove-Item -LiteralPath $tempExtract -Recurse -Force
                }
            }
        }
        catch {
            $lineInfo = $_.InvocationInfo.ScriptLineNumber
            $msg = Get-CopyErrorMessage -ExceptionMessage $_.Exception.Message
            Add-Error ("{0}: {1} (line {2})" -f $archive.Name, $msg, $lineInfo)
        }
        finally {
            Remove-Item -LiteralPath $archive.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-DestinationFileNameSet {
    param([Parameter(Mandatory = $true)][string]$FolderPath)
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return $set }
    $files = @(Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        $set.Add($file.Name) | Out-Null
    }
    return $set
}

function Convert-NameSet {
    param([Parameter(Mandatory = $true)][object]$NameSet)
    $hashSetStringType = [System.Collections.Generic.HashSet[string]]
    if ($NameSet -is $hashSetStringType) { return $NameSet }
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @($NameSet)) {
        if ($name) { $set.Add($name.ToString()) | Out-Null }
    }
    return $set
}

function Add-NameToSet {
    param(
        [Parameter(Mandatory = $true)][ref]$Set,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if (-not $Name) { return }
    $hashSetStringType = [System.Collections.Generic.HashSet[string]]
    try {
        if (-not $Set.Value -or -not ($Set.Value -is $hashSetStringType)) {
            $Set.Value = Convert-NameSet -NameSet $Set.Value
        }
        if ($Set.Value) { $Set.Value.Add($Name) | Out-Null }
    }
    catch {
        $Set.Value = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $Set.Value.Add($Name) | Out-Null
    }
}

function Remove-EmptyFolders {
    param([Parameter(Mandatory = $true)][string]$RootPath)
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return [pscustomobject]@{ FoldersRemoved = 0 }
    }
    $dirs = Get-ChildItem -LiteralPath $RootPath -Directory -Recurse -ErrorAction SilentlyContinue |
        Sort-Object -Property FullName -Descending
    $removed = 0
    foreach ($dir in $dirs) {
        $hasItems = (Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
        if (-not $hasItems) {
            try {
                Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction Stop
                $removed++
            }
            catch {
            }
        }
    }
    return [pscustomobject]@{ FoldersRemoved = $removed }
}

function Remove-ShareDrive {
    param([Parameter(Mandatory = $true)][string]$DrivePath)
    $driveName = ($DrivePath -split ':')[0]
    if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $driveName -ErrorAction SilentlyContinue
    }
}

function Resolve-DestinationPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bs = '\'
    $unc2 = $bs + $bs
    $p = $Path.Trim()
    if (-not $p) { return $p }
    # Fix UNC when the path starts with a single backslash instead of two.
    if ($p.StartsWith($bs) -and -not $p.StartsWith($unc2)) {
        $p = $bs + $p
    }
    # Collapse doubled backslashes after the server so the share resolves.
    if ($p.StartsWith($unc2) -and $p.Length -gt 2) {
        $p = $unc2 + $p.Substring(2).Replace($unc2, $bs)
    }
    return $p
}

function Resolve-DestinationGamesSubfolder {
    param([Parameter(Mandatory = $true)][string]$Path)
    $p = $Path.Trim()
    if ([string]::IsNullOrWhiteSpace($p)) { return $p }
    $bs = '\'
    $p = $p.TrimEnd($bs).TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($p)) { return $Path }
    # Use Path/GetFileName instead of Join-Path so missing drive letters do not throw.
    $leaf = [System.IO.Path]::GetFileName($p)
    if ($leaf -ieq 'games') {
        return $p
    }
    $sep = [System.IO.Path]::DirectorySeparatorChar
    # Bare drive roots like E: need the separator before combining with games.
    if ($p -match '^[A-Za-z]:$') {
        return $p + $sep + 'games'
    }
    return [System.IO.Path]::Combine($p, 'games')
}

function Test-DestinationLocationReachable {
    param([Parameter(Mandatory = $true)][string]$Path)
    $p = $Path.Trim()
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    $bs = '\'
    $unc2 = $bs + $bs
    try {
        if ($p.StartsWith($unc2)) {
            if ($p -match '^(\\\\[^\\]+\\[^\\]+)') {
                return Test-Path -LiteralPath $Matches[1] -ErrorAction SilentlyContinue
            }
            return $false
        }
        if ($p -match '^([A-Za-z]):') {
            return $null -ne (Get-PSDrive -Name $Matches[1] -ErrorAction SilentlyContinue)
        }
        return Test-Path -LiteralPath $p -ErrorAction SilentlyContinue
    }
    catch {
        return $false
    }
}

function Test-GamePopulatorCleanupDestinationAccessible {
    param([Parameter(Mandatory = $true)][string]$DestinationRoot)
    $p = $DestinationRoot.Trim()
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    return (Test-DestinationLocationReachable -Path $p)
}

function Get-ArchiveUnpackedSizeBytesVia7z {
    param(
        [Parameter(Mandatory = $true)][string]$ArchiveLiteralPath,
        [Parameter(Mandatory = $true)][string]$SevenZipExeLiteralPath
    )
    if (-not (Test-Path -LiteralPath $ArchiveLiteralPath -PathType Leaf)) {
        return $null
    }
    if (-not (Test-Path -LiteralPath $SevenZipExeLiteralPath -PathType Leaf)) {
        return $null
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $SevenZipExeLiteralPath
    $quotedArchive = if ($ArchiveLiteralPath -match '\s') { '"' + $ArchiveLiteralPath + '"' } else { $ArchiveLiteralPath }
    $psi.Arguments = @('l', '-slt', '-bso1', '-bse0', '-bsp0', $quotedArchive) -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    try {
        $process = [System.Diagnostics.Process]::Start($psi)
    }
    catch {
        return $null
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $null = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        return $null
    }
    $sum = [long]0
    foreach ($line in $stdout -split "`r?`n") {
        if ($line -match '^\s*Size\s*=\s*(\d+)\s*$') {
            $sum += [long]$Matches[1]
        }
    }
    return $sum
}

function Measure-DirectoryFileCountAndBytes {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralDirectoryPath,
        [string]$SevenZipExeForUnpackedEstimate = '',
        [string[]]$ArchiveExtensionsForUnpackedEstimate = @(),
        # When set, only files whose extension is allowed for that system (or matches ArchiveExtensions) are counted.
        [System.Collections.Generic.HashSet[string]]$AllowedExtensionsForEligibility = $null,
        # When true, optical sources count every file under detected BIN/CUE game folders (matches copy), then loose CHDs and other eligible files.
        [switch]$UseOpticalCopySemantics
    )
    $p = $LiteralDirectoryPath.Trim()
    if ([string]::IsNullOrWhiteSpace($p)) {
        return [pscustomobject]@{ FileCount = 0; TotalBytes = [long]0 }
    }
    if (-not (Test-Path -LiteralPath $p -PathType Container)) {
        return [pscustomobject]@{ FileCount = 0; TotalBytes = [long]0 }
    }
    $archiveExtEligible = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($e in @($ArchiveExtensionsForUnpackedEstimate)) {
        if ([string]::IsNullOrWhiteSpace($e)) { continue }
        $ex = $e.Trim()
        if (-not $ex.StartsWith('.')) { $ex = '.' + $ex }
        [void]$archiveExtEligible.Add($ex.ToLowerInvariant())
    }
    $useUnpacked = -not [string]::IsNullOrWhiteSpace($SevenZipExeForUnpackedEstimate) -and
    (Test-Path -LiteralPath $SevenZipExeForUnpackedEstimate -PathType Leaf) -and
    ($archiveExtEligible.Count -gt 0)

    function Get-NormalizedFileExtension {
        param([System.IO.FileInfo]$FileItem)
        $ext = $FileItem.Extension
        if ([string]::IsNullOrWhiteSpace($ext)) {
            return ''
        }
        return $ext.ToLowerInvariant()
    }

    function Test-EligibleForCountedStats {
        param([string]$ExtNorm)
        if ($null -eq $AllowedExtensionsForEligibility) {
            return $true
        }
        if ($AllowedExtensionsForEligibility.Contains($ExtNorm)) {
            return $true
        }
        if ($archiveExtEligible.Contains($ExtNorm)) {
            return $true
        }
        return $false
    }

    if ($UseOpticalCopySemantics -and ($null -ne $AllowedExtensionsForEligibility)) {
        $allFiles = @(Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue)
        $countedPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $fc = 0
        $tb = [long]0
        foreach ($dirPath in @(Get-BinCueFoldersFromItems -Items $allFiles)) {
            $dirInfo = Get-Item -LiteralPath $dirPath -ErrorAction SilentlyContinue
            if (-not $dirInfo -or -not $dirInfo.PSIsContainer) { continue }
            foreach ($nf in @(Get-ChildItem -LiteralPath $dirInfo.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)) {
                if ($countedPaths.Add($nf.FullName)) {
                    $fc++
                    $tb += [long]$nf.Length
                }
            }
        }
        foreach ($f in $allFiles) {
            if ($countedPaths.Contains($f.FullName)) { continue }
            $extNorm = Get-NormalizedFileExtension -FileItem $f
            if ($extNorm -eq '.chd' -and $AllowedExtensionsForEligibility.Contains('.chd')) {
                $fc++
                $tb += [long]$f.Length
                [void]$countedPaths.Add($f.FullName)
                continue
            }
            if (-not (Test-EligibleForCountedStats -ExtNorm $extNorm)) {
                continue
            }
            $fc++
            $len = [long]$f.Length
            if ($useUnpacked -and ($archiveExtEligible.Count -gt 0) -and $archiveExtEligible.Contains($extNorm)) {
                $unpacked = Get-ArchiveUnpackedSizeBytesVia7z -ArchiveLiteralPath $f.FullName -SevenZipExeLiteralPath $SevenZipExeForUnpackedEstimate
                if ($null -ne $unpacked) {
                    $tb += $unpacked
                }
                else {
                    $tb += $len
                }
            }
            else {
                $tb += $len
            }
            [void]$countedPaths.Add($f.FullName)
        }
        return [pscustomobject]@{ FileCount = $fc; TotalBytes = $tb }
    }

    $fc = 0
    $tb = [long]0
    Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $extNorm = Get-NormalizedFileExtension -FileItem $_
        if (-not (Test-EligibleForCountedStats -ExtNorm $extNorm)) {
            return
        }
        $fc++
        $len = [long]$_.Length
        if ($useUnpacked -and ($archiveExtEligible.Count -gt 0) -and $archiveExtEligible.Contains($extNorm)) {
            $unpacked = Get-ArchiveUnpackedSizeBytesVia7z -ArchiveLiteralPath $_.FullName -SevenZipExeLiteralPath $SevenZipExeForUnpackedEstimate
            if ($null -ne $unpacked) {
                $tb += $unpacked
            }
            else {
                $tb += $len
            }
        }
        else {
            $tb += $len
        }
    }
    return [pscustomobject]@{ FileCount = $fc; TotalBytes = $tb }
}

function Backup-GamePopulatorLibraryFileIfPresent {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)
    if (Test-Path -LiteralPath $LiteralPath -PathType Leaf) {
        $bak = $LiteralPath + '.backup'
        Copy-Item -LiteralPath $LiteralPath -Destination $bak -Force
    }
}

# Windows SMB: one authenticated identity per UNC server. Tracking avoids slow failing retries when creds clash.
function Get-SmbCredFingerprintFromShareCred {
    param([string]$User, [SecureString]$Password)
    if ([string]::IsNullOrWhiteSpace($User) -or $null -eq $Password) {
        return '[implicit]'
    }
    return $User.Trim().ToLowerInvariant()
}

function Get-FriendlyDescriptionForSmbCredFingerprint {
    param([Parameter(Mandatory = $true)][string]$Fingerprint)
    if ($Fingerprint -eq '[implicit]') {
        return 'logged-on Windows credentials (no ShareUser/SharePassword in settings)'
    }
    return 'stored SMB credentials (user ' + $Fingerprint + ')'
}

function Initialize-SmbEstablishmentTracking {
    if ($null -eq $script:SmbEstablishedAuthFingerprintsByUncServer) {
        $script:SmbEstablishedAuthFingerprintsByUncServer = @{}
    }
}

function Get-CanonicalUncServerPrefix {
    param([Parameter(Mandatory = $true)][string]$UncResolvedPath)
    $bs = '\'
    $unc2 = $bs + $bs
    $p = $UncResolvedPath.Trim()
    if (-not $p.StartsWith($unc2)) { return $null }
    $rest = $p.Substring(2)
    $slash = $rest.IndexOf($bs)
    if ($slash -lt 0) {
        if ([string]::IsNullOrWhiteSpace($rest)) { return $null }
        return ($unc2 + $rest.Trim().TrimEnd($bs).ToUpperInvariant())
    }
    $server = $rest.Substring(0, $slash)
    if ([string]::IsNullOrWhiteSpace($server)) { return $null }
    return ($unc2 + $server.Trim().ToUpperInvariant())
}

function Expand-SmbConnectErrorHint {
    param([string]$RawMessage, [string]$UncPath)
    if ([string]::IsNullOrWhiteSpace($RawMessage)) { return '' }
    $multConnRegex = '(?i)multiple connections'
    if ($RawMessage -notmatch $multConnRegex) {
        return ''
    }
    $srvRoot = Resolve-DestinationPath -Path $UncPath
    $pfx = Get-CanonicalUncServerPrefix -UncResolvedPath $srvRoot
    if (-not $pfx) { return 'Use one SMB username per server, or omit ShareUser and SharePassword so all UNC paths match one identity.' }
    $onlyServerName = $pfx.Substring(2)
    $netWildPath = '\\' + $onlyServerName + '\*'
    return ('Use the same SMB account for UNC paths under \\' + $onlyServerName + ', or disconnect first: net use "' + $netWildPath + '" /delete /yes, then retry.')
}

function Disconnect-GamePopulatorNetworkMappings {
    param(
        [Parameter(Mandatory = $true)][String[]]$UncPathCandidates,
        [switch]$Quiet
    )
    if (-not $Quiet) {
        Write-Info 'Removing temporary PSDrives created by this script (names matching SRC###### / DST######)...'
    }
    $pspDrives = @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)
    foreach ($d in $pspDrives) {
        if ($d.Name -match '^(SRC|DST)[0-9a-fA-F]{6}$') {
            Remove-PSDrive -Name $d.Name -Force -Scope Global -ErrorAction SilentlyContinue
            if (-not $Quiet) {
                Write-Host ('  Removed PSDrive ' + $d.Name) -ForegroundColor DarkGray
            }
        }
    }
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $bs = '\'
    $unc2 = $bs + $bs
    foreach ($raw in $UncPathCandidates) {
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $r = $null
        try { $r = Resolve-DestinationPath -Path $raw.Trim() } catch { continue }
        if (-not $r -or -not $r.StartsWith($unc2)) { continue }
        $pfx = Get-CanonicalUncServerPrefix -UncResolvedPath $r
        if (-not $pfx) { continue }
        $serverNamePart = $pfx.Substring(2)
        $null = $set.Add($serverNamePart)
    }
    $uncServerList = $set.ToArray()
    if (-not $Quiet) {
        if ($uncServerList.Count -eq 0) {
            Write-Info 'No UNC paths in the supplied list - script PSDrives cleared only.'
        }
        else {
            $joined = $uncServerList -join ', '
            Write-Info ('Running net use /delete per UNC server from your config: ' + $joined)
        }
    }
    foreach ($h in $uncServerList) {
        $wild = '\\' + $h + '\*'
        $out = & net.exe use $wild /delete /yes 2>&1
        if (-not $Quiet) {
            if ($LASTEXITCODE -eq 0) {
                Write-Host ('  Disconnected: net use "' + $wild + '"') -ForegroundColor DarkGray
            }
            else {
                $msg = ($out | Where-Object { $_ } | ForEach-Object { $_.ToString().Trim() }) -join ' '
                Write-Host ('  net use for "' + $wild + '" exited ' + $LASTEXITCODE + ' (' + $msg + ')') -ForegroundColor DarkGray
            }
        }
    }
    $script:SmbEstablishedAuthFingerprintsByUncServer = @{}
    if (-not $Quiet) {
        Write-Info 'Cleared in-script SMB credential tracking (per UNC server).'
    }
}

function Test-SmbEstablishedCredentialCompatibility {
    param([Parameter(Mandatory = $true)][string]$UncRoot, [Parameter(Mandatory = $true)][string]$Purpose, [string]$ShareUser, [SecureString]$SharePassword)
    $srvRoot = Resolve-DestinationPath -Path $UncRoot
    $serverPref = Get-CanonicalUncServerPrefix -UncResolvedPath $srvRoot
    if (-not $serverPref) { return }

    Initialize-SmbEstablishmentTracking

    $nowFp = Get-SmbCredFingerprintFromShareCred -User $ShareUser -Password $SharePassword
    $priorFp = $script:SmbEstablishedAuthFingerprintsByUncServer[$serverPref]
    if (-not $priorFp) { return }
    if ($priorFp -eq $nowFp) { return }

    $uncSrvDisp = $serverPref.Substring(2)
    $netWild = '\\' + $uncSrvDisp + '\*'
    $friendlyNow = Get-FriendlyDescriptionForSmbCredFingerprint -Fingerprint $nowFp
    $friendlyPrior = Get-FriendlyDescriptionForSmbCredFingerprint -Fingerprint $priorFp
    $partA = 'Cannot open ' + $Purpose + ' using ' + $friendlyNow + ' for \\' + $uncSrvDisp + ': SMB already uses ' + $friendlyPrior + '.'
    $partB = ' Disconnect or remap: net use "' + $netWild + '" /delete /yes  Or use identical ShareUser and password, or omit both, for the destination and every UNC source under \\' + $uncSrvDisp + '.'
    $compoundErr = $partA + $partB
    $cmpExObj = New-Object System.InvalidOperationException -ArgumentList $compoundErr
    throw $cmpExObj
}

function Register-SmbEstablishmentForUncPath {
    param([Parameter(Mandatory = $true)][string]$UncRoot, [string]$ShareUser, [SecureString]$SharePassword)
    $srvRoot = Resolve-DestinationPath -Path $UncRoot
    $serverPref = Get-CanonicalUncServerPrefix -UncResolvedPath $srvRoot
    if (-not $serverPref) { return }

    Initialize-SmbEstablishmentTracking
    $script:SmbEstablishedAuthFingerprintsByUncServer[$serverPref] = Get-SmbCredFingerprintFromShareCred -User $ShareUser -Password $SharePassword
}

function Start-DestinationUncConnectionCountdownDisplay {
    param(
        [Parameter(Mandatory = $true)][int]$AdvisoryLimitSeconds
    )
    return (Start-ThreadJob -ScriptBlock {
            param($Limit)
            $getDestinationUncConnectingStatusLine = {
                param(
                    [int]$ElapsedSeconds,
                    [int]$AdvisorySeconds
                )
                if ($ElapsedSeconds -lt $AdvisorySeconds) {
                    $remaining = $AdvisorySeconds - $ElapsedSeconds
                    'Connecting to destination... {0}s elapsed ({1}s to advisory limit)   ' -f $ElapsedSeconds, $remaining
                }
                else {
                    'Connecting to destination... {0}s elapsed (past {1}s - waiting for Windows SMB; Ctrl+C to stop)   ' -f $ElapsedSeconds, $AdvisorySeconds
                }
            }
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            while ($true) {
                $elapsed = [int][math]::Floor($sw.Elapsed.TotalSeconds)
                $line = & $getDestinationUncConnectingStatusLine -ElapsedSeconds $elapsed -AdvisorySeconds $Limit
                try {
                    [Console]::Error.Write(('{0}{1,-80}' -f "`r", $line))
                    [Console]::Error.Flush()
                }
                catch { }
                Start-Sleep -Milliseconds 800
            }
        } -ArgumentList $AdvisoryLimitSeconds)
}

function Stop-GamePopulatorBackgroundStatusDisplay {
    param([System.Management.Automation.Job]$Job)
    if ($Job) {
        Stop-Job $Job -ErrorAction SilentlyContinue
        Remove-Job $Job -Force -ErrorAction SilentlyContinue
    }
    try {
        $blank80 = ''.PadRight(80)
        [Console]::Error.Write("`r$blank80`n")
        [Console]::Error.Flush()
    }
    catch {
    }
}

function Start-CleanupActivityElapsedDisplay {
    return (Start-ThreadJob -ScriptBlock {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            while ($true) {
                $elapsed = [int][math]::Floor($sw.Elapsed.TotalSeconds)
                $line = "Destination cleanup (scan/remove)... $($elapsed)s elapsed   "
                try {
                    if ($line.Length -gt 80) {
                        $padded = $line.Substring(0, 80)
                    }
                    else {
                        $padded = $line.PadRight(80)
                    }
                    [Console]::Error.Write("`r$padded")
                    [Console]::Error.Flush()
                }
                catch {
                }
                Start-Sleep -Milliseconds 900
            }
        })
}

function Initialize-DestinationRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$User,
        [SecureString]$Password,
        [switch]$Quiet
    )
    $Path = Resolve-DestinationPath -Path $Path
    $bs = '\'
    $unc2 = $bs + $bs
    if (-not $Path.StartsWith($unc2)) {
        return @{ Path = $Path; Drive = $null }
    }
    if ($script:ScriptDiag) {
        Write-Host "[diag] Initialize-DestinationRoot: mapping UNC (this can block if the server is down)" -ForegroundColor Magenta
        Write-Host "[diag]   $Path" -ForegroundColor Magenta
        Invoke-OutputFlush
    }
    Test-SmbEstablishedCredentialCompatibility -UncRoot $Path -Purpose 'destination' -ShareUser $User -SharePassword $Password

    if (-not $Quiet) {
        Write-Host ''
        Write-Host 'Connecting to destination share (UNC can take a moment if the server is slow or unreachable):' -ForegroundColor White
        Write-Host ("  $Path") -ForegroundColor Green
    }
    $driveName = "DST{0}" -f ([Guid]::NewGuid().ToString('N').Substring(0, 6))
    if ([string]::IsNullOrWhiteSpace($User) -or $null -eq $Password) {
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $Path -ErrorAction Stop -Scope Global | Out-Null
    }
    else {
        $cred = New-Object System.Management.Automation.PSCredential ($User, $Password)
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $Path -Credential $cred -ErrorAction Stop -Scope Global | Out-Null
    }
    Register-SmbEstablishmentForUncPath -UncRoot $Path -ShareUser $User -SharePassword $Password
    return @{ Path = "$driveName`:\\"; Drive = $driveName }
}

$script:GamePopulatorStructuredNdjsonLiteralPath = $null

function Add-StructuredNdjsonLine {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][hashtable]$Record
    )
    if (-not ($Record.ContainsKey('ts'))) {
        $Record['ts'] = (Get-Date).ToUniversalTime().ToString('o')
    }
    $json = ''
    try {
        $json = $Record | ConvertTo-Json -Compress -Depth 10
    }
    catch {
        return
    }
    try {
        Add-Content -LiteralPath $LiteralPath -Encoding utf8 -Value $json -ErrorAction Stop
    }
    catch {
    }
}

function Get-DirectorySize {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return 0 }
    return (Get-ChildItem -LiteralPath $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
}

$script:errors = New-Object System.Collections.Generic.List[string]

function Get-CopyErrorMessage {
    param([string]$ExceptionMessage)
    if ([string]::IsNullOrWhiteSpace($ExceptionMessage)) { return $ExceptionMessage }
    if ($ExceptionMessage -match 'not enough space|space on the disk') {
        return "Destination full (not enough space on disk): " + $ExceptionMessage
    }
    return $ExceptionMessage
}

function Add-Error {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:errors.Add($Message) | Out-Null
    $pth = ''
    try { $pth = [string]$script:GamePopulatorStructuredNdjsonLiteralPath } catch { $pth = '' }
    if ($pth -and (Test-Path -LiteralPath ([System.IO.Path]::GetDirectoryName($pth)) -PathType Container)) {
        Add-StructuredNdjsonLine -LiteralPath $pth -Record @{ type = 'error'; severity = 'error'; message = $Message }
    }
    Write-Warn $Message
}

