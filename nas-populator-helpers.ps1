<#
NAS-Populator - Helper functions
https://github.com/cosmickatamari/nas-populator

Created by: cosmickatamari
Updated: 03/08/2026
#>

# Single source for name and version; change here only.
$script:ScriptName = 'NAS Populator'
$script:ScriptVersion = '2026.3.8'

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

function Show-Help {
    Clear-Host
    Write-Host "=== [ $script:ScriptName ]===" -ForegroundColor Blue
    Write-Host "=== [ Version $script:ScriptVersion ] ===`n" -ForegroundColor Blue

    Write-Info "Organizes game image files for NAS-based sharing."
    Write-Info "Extracts archives to folders or compresses files into ZIP archives with maximum compression.`n"

    Write-Host "Parameters:" -ForegroundColor DarkYellow
    Write-Host "  -Help             Show this help." -ForegroundColor White
    Write-Host "  -RawOrg           RAW with region organization + cleanup." -ForegroundColor White
    Write-Host "  -RawNoOrg         RAW without region organization + cleanup." -ForegroundColor White
    Write-Host "  -ZipOrg           ZIP with region organization + cleanup (ZIP files copied as-is)." -ForegroundColor White
    Write-Host "  -ZipNoOrg         ZIP without region organization + cleanup (ZIP files copied as-is)." -ForegroundColor White
    Write-Host "  -Cleanup          Cleanup only." -ForegroundColor White
    Write-Host "  -DestinationRoot  Specifies destination root folder. (ignores JSON value)" -ForegroundColor White
    Write-Host "  -TempRoot         Specifies temp extraction folder. (ignores JSON value)`n" -ForegroundColor White

    Write-Host "Interactive menu (when run without a mode parameter):" -ForegroundColor DarkYellow
    Write-Host "  1-4. Same as -RawOrg/ -RawNoOrg/ -ZipOrg/ -ZipNoOrg." -ForegroundColor White
    Write-Host "  5.   Empty destination folder cleanup and removal of files with invalid extensions." -ForegroundColor White
    Write-Host "  6.   Recreate config files from templates (prompts for each file)." -ForegroundColor White
    Write-Host "  E.   Exit.`n" -ForegroundColor White

    Write-Host "Config Files:" -ForegroundColor DarkYellow
    Write-Host "  nas-populator-settings.json          Paths, 7-Zip, and share credentials." -ForegroundColor White
    Write-Host "  nas-populator-sources.psd1           Console share list (uncomment to enable)." -ForegroundColor White
    Write-Host "  nas-populator-console-names.json     Official names, short names, subdirs, allowed extensions.`n" -ForegroundColor White

    Write-Host "Templates:" -ForegroundColor DarkYellow
    Write-Host "  nas-populator-settings.template.json" -ForegroundColor White
    Write-Host "  nas-populator-sources.template.psd1" -ForegroundColor White
    Write-Host "  nas-populator-console-names.template.json" -ForegroundColor White
    Write-Host "  - Used to recreate config files (option 6 or when a file is missing/invalid).`n" -ForegroundColor White

    Write-Host "Notes:" -ForegroundColor DarkYellow
    Write-Host "  - Existing destination files are never overwritten." -ForegroundColor White
    Write-Host "  - CHD files are copied as-is." -ForegroundColor White
    Write-Host "  - Folders with extracted BIN/CUE are copied as-is in a separate game folder." -ForegroundColor White
    Write-Host "  - Region organization moves files into region folders during processing." -ForegroundColor White
    Write-Host "  - Cleanup removes destination files whose extension is not in the console allow list (.rom and .zip always allowed)." -ForegroundColor White
    Write-Host "  - Boot ROMs files are never moved to region folders and are always copied to the root of the destination folder.`n" -ForegroundColor White

    Write-Host "Examples:" -ForegroundColor DarkYellow
    Write-Host "  .\nas-populator.ps1 -Help" -ForegroundColor White
    Write-Host "  .\nas-populator.ps1 -ZipOrg" -ForegroundColor White
    Write-Host "  .\nas-populator.ps1 -ZipNoOrg -DestinationRoot \\server\storage" -ForegroundColor White
    Write-Host "  .\nas-populator.ps1 -RawNoOrg -TempRoot D:\temp`n" -ForegroundColor White
    exit 0
}

function Read-YesNoDefaultYes {
    param([Parameter(Mandatory = $true)][string]$Prompt)
    while ($true) {
        Write-Host $Prompt -NoNewline -ForegroundColor White
        Write-Host " (Y/N) [Y] " -NoNewline -ForegroundColor Cyan
        $answer = [Console]::ReadLine().Trim()
        if ([string]::IsNullOrWhiteSpace($answer)) { return $true }
        if ($answer -match '^(y|yes)$') { return $true }
        if ($answer -match '^(n|no)$') { return $false }
        Write-Warn "Please enter Y or N."
    }
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
        return ("{0} day {1:00}:{2:00}:{3:00}" -f $Elapsed.Days, $Elapsed.Hours, $Elapsed.Minutes, $Elapsed.Seconds)
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
        } elseif ($line -match '^(Extracting|Compressing|Updating)\s+(.+)$') {
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
        [Parameter(Mandatory = $true)][string]$DestRoot
    )
    $copiedBytes = 0L
    $copiedFiles = 0
    foreach ($item in $Items) {
        $relative = [System.IO.Path]::GetRelativePath($SourceRoot, $item.FullName)
        $destPath = Join-Path $DestRoot $relative
        if ($item.PSIsContainer) {
            if (-not (Test-Path -LiteralPath $destPath)) {
                New-Item -Path $destPath -ItemType Directory -Force | Out-Null
            }
            continue
        }
        if (Test-Path -LiteralPath $destPath) { continue }
        $destDir = Split-Path -Parent $destPath
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        Copy-Item -LiteralPath $item.FullName -Destination $destPath
        $copiedBytes += $item.Length
        $copiedFiles += 1
    }
    return @{
        Bytes = $copiedBytes
        Files = $copiedFiles
    }
}

function New-ShareDrive {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$User,
        [SecureString]$Password
    )
    $driveName = "SRC{0}" -f ([Guid]::NewGuid().ToString('N').Substring(0, 6))
    if ([string]::IsNullOrWhiteSpace($User) -or $null -eq $Password) {
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $Root -ErrorAction Stop -Scope Global | Out-Null
    } else {
        $cred = New-Object System.Management.Automation.PSCredential ($User, $Password)
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $Root -Credential $cred -ErrorAction Stop -Scope Global | Out-Null
    }
    return "$driveName`:\"
}

function Copy-ItemsFlatNoOverwrite {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileSystemInfo[]]$Items,
        [Parameter(Mandatory = $true)][string]$DestRoot
    )
    $copiedBytes = 0L
    $copiedFiles = 0
    foreach ($item in $Items) {
        if ($item.PSIsContainer) { continue }
        $destPath = Join-Path $DestRoot $item.Name
        if (Test-Path -LiteralPath $destPath) { continue }
        if (-not (Test-Path -LiteralPath $DestRoot)) {
            New-Item -Path $DestRoot -ItemType Directory -Force | Out-Null
        }
        Copy-Item -LiteralPath $item.FullName -Destination $destPath
        $copiedBytes += $item.Length
        $copiedFiles += 1
    }
    return @{
        Bytes = $copiedBytes
        Files = $copiedFiles
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

function Add-RegionCountWithRegion {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Counts,
        [Parameter(Mandatory = $true)][string]$Region,
        [Parameter(Mandatory = $true)][bool]$Organize
    )
    if (-not $Organize -or -not $Region) { return }
    if (-not $Counts.ContainsKey($Region)) { $Counts[$Region] = 0 }
    $Counts[$Region]++
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

function Move-SgbTaggedFilesToDestination {
    param(
        [Parameter(Mandatory = $true)][string]$SourceFolderPath,
        [Parameter(Mandatory = $true)][string]$DestFolderPath,
        [Parameter(Mandatory = $true)][bool]$Organize,
        [string]$ProgressConsoleName,
        [System.Diagnostics.Stopwatch]$ProgressStopwatch
    )
    if (-not (Test-Path -LiteralPath $SourceFolderPath -PathType Container)) { return }

    $files = @(Get-ChildItem -LiteralPath $SourceFolderPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -imatch '\(SGB'
    })

    foreach ($file in $files) {
        if ($ProgressConsoleName -and $ProgressStopwatch) {
            Update-OrganizeProgress -ConsoleName $ProgressConsoleName -Stopwatch $ProgressStopwatch
            Write-OrganizeProgressLine -ConsoleName $ProgressConsoleName -Elapsed $ProgressStopwatch.Elapsed
        }
        $destRoot = Get-RegionDestRoot -BasePath $DestFolderPath -Name $file.Name -Organize $Organize
        if (-not (Test-Path -LiteralPath $destRoot -PathType Container)) {
            New-Item -Path $destRoot -ItemType Directory -Force | Out-Null
        }
        $destFile = Join-Path $destRoot $file.Name
        $sourceFull = [System.IO.Path]::GetFullPath($file.FullName)
        $destFull = [System.IO.Path]::GetFullPath($destFile)
        if ($sourceFull -ieq $destFull) { continue }
        if (Test-Path -LiteralPath $destFile) { continue }
        Move-Item -LiteralPath $file.FullName -Destination $destFile
    }

    Remove-EmptyFolders -RootPath $SourceFolderPath
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
        } else {
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
        [Parameter(Mandatory = $true)][string[]]$AllowedExtensions
    )
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return }
    $allowedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($ext in $AllowedExtensions) {
        $e = $ext.Trim()
        if (-not $e.StartsWith('.')) { $e = '.' + $e }
        $allowedSet.Add($e) | Out-Null
    }
    $allowedSet.Add('.rom') | Out-Null
    $allowedSet.Add('.zip') | Out-Null

    $files = @(Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        if (-not $allowedSet.Contains($file.Extension)) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-ExistingDestination {
    param(
        [Parameter(Mandatory = $true)][string]$FolderPath,
        [Parameter(Mandatory = $true)][string]$Mode,
        [Parameter(Mandatory = $true)][bool]$Organize,
        [Parameter(Mandatory = $true)][string[]]$ArchiveExtensions
    )
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { return }

    if ($Mode -eq 'Raw') {
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
                    } else {
                        $filesToCopy = @($extractedItems | Where-Object { -not $_.PSIsContainer })
                        if ($filesToCopy.Count -gt 0) {
                            Copy-ItemsFlatNoOverwrite -Items $filesToCopy -DestRoot $destRoot | Out-Null
                        }
                    }
                } finally {
                    if (Test-Path -LiteralPath $tempExtract) {
                        Remove-Item -LiteralPath $tempExtract -Recurse -Force
                    }
                }
            } catch {
                $lineInfo = $_.InvocationInfo.ScriptLineNumber
                $msg = Get-CopyErrorMessage -ExceptionMessage $_.Exception.Message
                Add-Error ("{0}: {1} (line {2})" -f $archive.Name, $msg, $lineInfo)
            } finally {
                Remove-Item -LiteralPath $archive.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        $archiveSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($ext in $ArchiveExtensions) { $archiveSet.Add($ext) | Out-Null }
        $archiveSet.Add('.chd') | Out-Null

        $files = @(Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
            -not $archiveSet.Contains($_.Extension)
        })
        foreach ($file in $files) {
            if ($file.Extension -ieq '.rom') {
                $fileFull = [System.IO.Path]::GetFullPath($file.FullName)
                if ($file.Name -imatch 'boot') {
                    $rootDest = Join-Path $FolderPath $file.Name
                    $rootDestFull = [System.IO.Path]::GetFullPath($rootDest)
                    if ($fileFull -ine $rootDestFull -and -not (Test-Path -LiteralPath $rootDest)) {
                        Move-Item -LiteralPath $file.FullName -Destination $rootDest
                    }
                    continue
                }
                $romDestRoot = Get-RegionDestRoot -BasePath $FolderPath -Name $file.Name -Organize $Organize
                if (-not (Test-Path -LiteralPath $romDestRoot)) {
                    New-Item -Path $romDestRoot -ItemType Directory -Force | Out-Null
                }
                $romDestFile = Join-Path $romDestRoot $file.Name
                $romDestFull = [System.IO.Path]::GetFullPath($romDestFile)
                if ($fileFull -ieq $romDestFull) { continue }
                if (Test-Path -LiteralPath $romDestFile) { continue }
                Move-Item -LiteralPath $file.FullName -Destination $romDestFile
                continue
            }
            $zipRoot = Get-RegionDestRoot -BasePath $FolderPath -Name $file.Name -Organize $Organize
            if (-not (Test-Path -LiteralPath $zipRoot)) {
                New-Item -Path $zipRoot -ItemType Directory -Force | Out-Null
            }
            $destFile = Join-Path $zipRoot ($file.BaseName + '.zip')
            if (Test-Path -LiteralPath $destFile) {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
                continue
            }
            $tempZip = Join-Path $TempRoot ([Guid]::NewGuid().ToString('N') + '.zip')
            try {
                Initialize-7z
                Invoke-7z -Arguments (@('a') + $zipCompressionArgs + @(
                    '-mmt=on'
                    '-bso1'
                    '-bse1'
                    '-bsp1'
                    $tempZip
                    $file.FullName
                )) -ProgressLabel "Compressing" -ProgressName ($file.BaseName + '.zip')
                Copy-Item -LiteralPath $tempZip -Destination $destFile
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
            } catch {
                $msg = Get-CopyErrorMessage -ExceptionMessage $_.Exception.Message
                Add-Error ("{0}: {1}" -f $file.Name, $msg)
            } finally {
                if (Test-Path -LiteralPath $tempZip) {
                    Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
                }
            }
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
    if ($NameSet -is [System.Collections.Generic.HashSet[string]]) { return $NameSet }
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
    try {
        if (-not $Set.Value -or -not ($Set.Value -is [System.Collections.Generic.HashSet[string]])) {
            $Set.Value = Convert-NameSet -NameSet $Set.Value
        }
        if ($Set.Value) { $Set.Value.Add($Name) | Out-Null }
    } catch {
        $Set.Value = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $Set.Value.Add($Name) | Out-Null
    }
}

function Remove-EmptyFolders {
    param([Parameter(Mandatory = $true)][string]$RootPath)
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) { return }
    $dirs = Get-ChildItem -LiteralPath $RootPath -Directory -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending
    foreach ($dir in $dirs) {
        $hasItems = (Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
        if (-not $hasItems) {
            Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue
        }
    }
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
    $p = $Path.Trim()
    if (-not $p) { return $p }
    # Fix malformed UNC: single leading \ (e.g. from JSON "\\host\\share" -> \host\share) must be \\
    if ($p.StartsWith('\') -and -not $p.StartsWith('\\')) {
        $p = '\' + $p
    }
    # Normalize \\host\\share -> \\host\share so Windows resolves the share correctly
    if ($p.StartsWith('\\') -and $p.Length -gt 2) {
        $p = '\\' + $p.Substring(2).Replace('\\', '\')
    }
    return $p
}

function Initialize-DestinationRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$User,
        [SecureString]$Password
    )
    $Path = Resolve-DestinationPath -Path $Path
    if (-not $Path.StartsWith('\\')) {
        return @{ Path = $Path; Drive = $null }
    }
    $driveName = "DST{0}" -f ([Guid]::NewGuid().ToString('N').Substring(0, 6))
    if ([string]::IsNullOrWhiteSpace($User) -or $null -eq $Password) {
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $Path -ErrorAction Stop -Scope Global | Out-Null
    } else {
        $cred = New-Object System.Management.Automation.PSCredential ($User, $Password)
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $Path -Credential $cred -ErrorAction Stop -Scope Global | Out-Null
    }
    return @{ Path = "$driveName`:\\"; Drive = $driveName }
}

function Get-DirectorySize {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return 0 }
    return (Get-ChildItem -LiteralPath $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
}

function ConvertTo-ZipCompressionArgs {
    param([Parameter(Mandatory = $true)][string[]]$Args)
    $normalized = @()
    foreach ($arg in $Args) {
        if ($arg -ieq '-m0=Deflate64') {
            $normalized += '-mm=Deflate64'
        } elseif ($arg -ieq '-m0=Deflate') {
            $normalized += '-mm=Deflate'
        } elseif ($arg -match '^(-tzip|-mx=\d+|-mm=Deflate64|-mm=Deflate)$') {
            $normalized += $arg
        } else {
            continue
        }
    }
    if (-not ($normalized -match '^-tzip$')) { $normalized += '-tzip' }
    if (-not ($normalized -match '^-mx=\d+$')) { $normalized += '-mx=9' }
    if (-not ($normalized -match '^-mm=Deflate64$|^-mm=Deflate$')) { $normalized += '-mm=Deflate' }
    return $normalized
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
    Write-Warn $Message
}
