# Game Populator
![7-Zip](https://img.shields.io/badge/7--Zip-Required-blue) ![PowerShell](https://img.shields.io/badge/PowerShell-7.6.1-blue) ![Windows](https://img.shields.io/badge/Windows-11-blue) ![GitHub License](https://img.shields.io/github/license/cosmickatamari/game-populator)


Game Populator is a PowerShell based utility for preparing and copying game libraries tailored to the MiSTer environment.

It supports:
- Extract and copy sets for archive based collections.
- Optional destination side zip creation for non-optical cores.
- Region organization and destination cleanup.
- Interactive single system and fully custom runs.
- Config validation, source reachability checks, and resume/checkpoint support.

## Requirements

- Windows with PowerShell 7.6.1.
- [7-Zip](https://www.7-zip.org/) 26.00 installed.
- Read access to your source game folders (local and/or SMB).
- Write access to destination and temp folders.

## Project Layout

- `game-populator.ps1`: main project script, config checks, and top level runtime flow.
- `libraries/helpers.ps1`: shared utility layer. Logic for:
	- logging
	- detailed help
	- system population analysis
	- SMB/session helpers
	- 7-Zip wrappers
	- copy/cleanup logic
	- region organization.
- `libraries/game-populator-functions.ps1`: shared higher level app logic. Logic for:
	- config/source merging
	- interactive menus
	- validation reports
	- guided/custom run workflows
	- checkpoint/cache operations
- `libraries/*.template.*`: default templates used to regenerate missing or invalid config files.
- `libraries/*.psd1` / `libraries/*.json`: active sources and system metadata used at runtime.

## Quick Start

1. Open PowerShell 7 and navigate to the extracted folder.
2. Run: `.\game-populator.ps1`
3. On first run, the script checks and bootstraps required config under `libraries\`.
4. Additionally, the destination location will be checked for `games\` folder which will be created if not found.
5. Use the interactive menu to configure sources/settings, validate connectivity, and run copy workflows.

### Optional startup flags

- `-Help`: show built-in help and menu usage
- `-Diag`: print startup diagnostics (useful when troubleshooting hangs or slow startup), can be used if creating a GitHub issue.

## Configuration Files (`libraries\`)

### `settings.json` fields

Defaults come from `libraries/settings.template.json`:

| Parameter | Description | Default Value
| -- | -- | -- |
| DestinationRoot | target root for copied/extracted content | (none) |
| TempRoot | working temp directory used during processing | (none) |
| SevenZipExe | full path to `7z.exe` | `C:\Program Files\7-Zip\7z.exe` |
| ArchiveExtensions | which archive types to process | `.zip`, `.7z`, `.rar` |
| MaxFilesPerFolder | folder chunking threshold (e.g., EverDrive-style splitting) | 256 |
| MaxConcurrentFileCopies | copy concurrency cap | 4 |
| StructuredRunLog | enable NDJSON run logs | true |
| UseRunCheckpoint | enable resumable checkpoints | true |
| ShareUser / SharePassword | SMB credentials | mister / dontplay

## Source and Name Mapping Model

The script merges multiple source lists and name-definition lists:

- Sources (`*.psd1`) define `Name` + `SourcePath` and optional enable state by comment/uncomment blocks.
- Names (`*.json`) define system metadata by `Name` (matching source entries), including `ShortName`, optional `SubDir`, extensions, and flags such as optical/music behavior.

Because the app merges by name, source entries should always match a valid name entry in the corresponding names JSON files.

## Interactive Menu Overview

Maintenance:
- `1` Toggle and edit source paths
- `2` Edit settings
- `3` Validate config files
- `4` Validate active source locations/connectivity
- `5` Cleanup destination files/folders
- `6` Reset SMB connections
- `7` Recreate config files from templates
- `8` Self-update from GitHub

Actions:
- `9` Extract/copy with region organization
- `10` Extract/copy without region organization
- `11` Zip on destination with region organization (non-optical cores)
- `12` Zip on destination without region organization (non-optical cores)
- `13` Guided single system copy
- `14` Custom run wizard (source/destination/temp and options)

## Runtime Notes

- The script keeps config under `libraries\` and can auto-recover missing templates from GitHub.
- The script can perform source/destination reachability checks, including SMB preflight validation.
- The script will skip repeated verification when source/settings fingerprints are unchanged (cache-based).
- Optional checkpointing supports interrupted run recovery.
- Structured logs/cache/checkpoints are written to runtime log/cache files.

## Script Responsibilities (PS1 Files)

### `game-populator.ps1`
- Enforces PowerShell 7 requirement
- Moves legacy config into `libraries\` when needed
- Dot (.) sources helper/function libraries
- Bootstraps missing config from templates
- Loads settings and launches interactive runtime/menu paths

### `libraries/helpers.ps1`
- Console output and user prompt helpers
- Help screen
- 7-Zip discovery and execution wrappers
- Copy, extract, merge, cleanup utilities
- Region detection & organization helpers
- SMB credential & session tracking and mapping helpers
- File size and file count measurement and structured logging utilities

### `libraries/game-populator-functions.ps1`
- Imports and merges source & name config arrays
- Manages source block enabling/disabling in .PSD1 files
- Produces config and active source validation reports
- Handles guided single-system and custom run interaction
- Maintains run checkpoint and source verification cache logic
- Prints the main menu and action routing support functions

## Recommended Workflow

1. Run menu `2` to confirm settings (`DestinationRoot`, `TempRoot`).
2. Run menu `1` to enable/edit source paths.
3. Run menu `4` to preflight active source connectivity.
4. Run menu `9` or `10` for a full extract/copy pass.
5. Run menu `11` or `12` for a full archive copy pass (non-optical systems are only compressed).
6. Run menu `13` for a single system to be populated.
5. Use menu `5` cleanup and `6` SMB reset as needed between runs.

## Troubleshooting

- Script exits immediately: verify PowerShell 7 (`pwsh`) is used.
- Missing config/template files: use menu `7` (or restart and allow auto-recreate/download).
- Archive failures: verify `SevenZipExe` and archive extensions in `settings.json`.
- Network share issues: validate credentials (`ShareUser`/`SharePassword`) and run menu `6`.
- Slow/unclear startup: launch with `-Diag`.

## Repository

Official Home: [cosmickatamari/game-populator](https://github.com/cosmickatamari/game-populator)

## License

GNU General Public License v3.0 - see [LICENSE](LICENSE).
