# NAS Populator

![7-Zip](https://img.shields.io/badge/7--Zip-required-blue) ![PowerShell](https://img.shields.io/badge/PowerShell-7-blue) ![Windows](https://img.shields.io/badge/Windows-10%2F11-blue)

**NAS Populator** is a PowerShell script that copies retro game media from SMB/network shares into a structured destination folder, using a layout commonly used with [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer/wiki). This should work with other emulator suites like RetroArch. It can extract archives, optionally compress loose ROMs into `.zip` files (MiSTer doesn't support .7z archives), sort titles into region folders using No-Intro–style filename tags, and run cleanup that only removes extensions you did not allow per console. Optionally, you can simply copy `.zip` files to the destination share. 

## Overview

This tool is built for **repeatable bulk imports**: through the support files, you define consoles you wish to migrate, their source UNC paths, and output folder names in config files, then run one of several modes. It connects to each source share (with optional credentials), walks the tree recursively, and places files under `DestinationRoot` using short folder names and optional subfolders. Existing files are **never overwritten**; skipping duplicates is by design.

The script also **pre-organizes** destinations that already contain files, moving loose ROMs into region folders (when enabled) and keeping BIN/CUE game folders intact, before it copies them from sources. `.chd` file support is also programmed to simply copy the file to the console's root directory, based on the parameters being passed. When finished, it prints a **completion summary** (time, bytes, file counts, per-console breakdown, and region totals when region mode was used). Errors are collected and, if any occurred, written to a timestamped log in the **current working directory**.

## Purpose

- Populate or refresh a **NAS-style games tree** from one or more collection shares.
- **Normalize layout**: regions, optical (CHD / BIN+CUE) handling, music player configurations.
- **Optional space-saving path**: ZIP mode compresses loose eligible files while leaving existing `.zip` archives on disk as-is.

## Features

- **Raw mode** — Extract `.zip` / `.7z` / `.rar` (plus archives detected via 7-Zip in raw flows); copy loose allowed extensions; copy **CHD** and **BIN/CUE** sets inside per-game folders.
- **Zip mode** — Build `.zip` files from loose ROMs with configurable 7-Zip arguments; **input `.zip` files are copied as-is** (not recompressed).
- **Region organization** — Optional folders such as `01 - USA`, `02 - Japan`, from `(USA)`, `(Japan)`, etc. in filenames; **boot** `*.rom` files stay at the console root.
- **Optical systems** — Consoles marked `"Optical": "yes"` always use raw-style disc layout (CHD / BIN+CUE), even if you chose Zip mode.
- **Super Game Boy** — Game Boy / Game Boy Color items with `(SGB` in the name can be routed to the Super Game Boy destination folder.
- **Cleanup** — Remove files whose extensions are not in each console’s allow list (`.rom` and `.zip` always kept), then delete empty folders.
- **Resilience** — Missing or invalid config can be recreated from predefined templates; settings JSON may be auto-corrected for common backslash escaping mistakes.
- **Interactive menu** when no mode switch is passed; **CLI switches** for automation.

## System Requirements

- **PowerShell 7.x** only (the script checks the major version and exits on Windows PowerShell 6.xx and lower).
- **7-Zip** — Default path `C:\Program Files\7-Zip\7z.exe`, or set `SevenZipExe` in `nas-populator-settings.json`, or enter the path when prompted.
- **Network** — SMB/UNC access to any sources and destinations you configure.
- **Permissions** — Network permissions - Read on sources; create/write on destination.

## Recommended Hardware

- **Gigabit (or faster) ethernet** when both source and destination live on a NAS; copying and extraction are often network-bound.
- **Fast local disk for `TempRoot`** — SSD preferred; extractions and temporary ZIPs use this path heavily in busy libraries.
- **Adequate free space** on `TempRoot` and destination for peak extract + copy workloads.

** *Note:* ** Developed and used on Windows with PowerShell 7 and a recent 7-Zip x64 build. UNC destinations are supported via `New-PSDrive`; paths are normalized to avoid common `\\server\\share` typos.

## Mode Differences

|  | Raw + regions<br>(menu **1** / `-RawOrg`) | Raw, flat rules<br>(**2** / `-RawNoOrg`) | Zip + regions<br>(**3** / `-ZipOrg`) | Zip, flat<br>(**4** / `-ZipNoOrg`) | Cleanup only<br>(**5** / `-Cleanup`) |
| -- | -- | -- | -- | -- | -- |
| Archives | Extract | Extract | Extract then zip loose output; **copy `.zip` as-is** | Same as Zip + regions, no region folders | -- |
| Loose ROMs | Copy as files | Copy as files | Compress to `.zip` | Compress to `.zip` | -- |
| Region folders | Yes | No | Yes | No | -- |
| Post-run cleanup | Yes | Yes | Yes | Yes | Yes |
| Copy from sources | Yes | Yes | Yes | Yes | No |

**Optical** consoles (see `nas-populator-console-names.json`) **always** follow raw-style CHD / BIN+CUE handling even when Zip mode is selected (you’ll see a warning).

Menu **6** recreates config files from templates (prompts per file); it does not copy games.

## Results

There is no single “compression ratio” figure, the job size depends on your library. When a run finishes (modes **1–4**), the script reports:

- Total elapsed time (and organize time if existing folders were processed).
- Files copied and total bytes; in Zip mode, count and size of **new** compressed archives where applicable.
- Per-console summary (time, files, bytes).
- With region organization: **Region summary** per system and **Region totals**.

If errors were logged, the console shows the count and a filename like `errorlog-YYYYMMDD-HHMMSS.log` in the directory from which you launched the script.

## Usage

On-screen reference (built-in help):

```powershell
.\nas-populator.ps1 -Help
```

Interactive menu (choose Raw/Zip, regions, cleanup, or template reset):

```powershell
.\nas-populator.ps1
```

Extract archives, organize by region, then cleanup:

```powershell
.\nas-populator.ps1 -RawOrg
```

Zip loose ROMs, no region folders, then cleanup:

```powershell
.\nas-populator.ps1 -ZipNoOrg
```

Override destination and temp for this run only (ignores JSON values for these two):

```powershell
.\nas-populator.ps1 -ZipOrg -DestinationRoot "\\nas\MiSTer\games" -TempRoot "D:\temp\nas-populator"
```

Cleanup only (extension filter + empty folders):

```powershell
.\nas-populator.ps1 -Cleanup
```

Using `pwsh` explicitly:

```powershell
pwsh -File .\nas-populator.ps1 -RawNoOrg
```

** *Note:* ** If required config files are missing or invalid, the script prompts to recreate them from `*.template.*` files. Edit `nas-populator-settings.json`, uncomment sources in `nas-populator-sources.psd1`, and ensure every enabled source `Name` exists in `nas-populator-console-names.json` before expecting copies to run.

## Key Parameters

### Flags / mode switches

Use **only one** mode switch at a time (`-RawOrg`, `-RawNoOrg`, `-ZipOrg`, `-ZipNoOrg`, or `-Cleanup`).

- `-Help` — Show parameter and config file reference, then exit.
- `-RawOrg` — Raw extraction/copy **with** region folders + cleanup.
- `-RawNoOrg` — Raw **without** region folders + cleanup.
- `-ZipOrg` — Zip mode **with** region folders + cleanup (`.zip` inputs copied as-is).
- `-ZipNoOrg` — Zip mode **without** region folders + cleanup.
- `-Cleanup` — Cleanup pass only (no source scanning).

### Paths

- `-DestinationRoot <path>` — Output root (local or UNC). When passed, overrides `DestinationRoot` in `nas-populator-settings.json`.
- `-TempRoot <path>` — Working folder for extracts/temp ZIPs; created if missing. Overrides JSON when passed.

Other behavior (archive extensions, 7-Zip path, ZIP compression arguments, credentials) comes from **`nas-populator-settings.json`**.

## Config files (quick reference)

| File | Role |
| -- | -- |
| `nas-populator-settings.json` | `DestinationRoot`, `TempRoot`, `SevenZipExe`, `ArchiveExtensions`, `ZipCompressionArgs`, `ShareUser`, `SharePassword`. |
| `nas-populator-sources.psd1` | `@( @{ Name = '...'; SourcePath = '\\server\share\...' } )` — **uncomment** entries to enable. `Name` must match `nas-populator-console-names.json`. |
| `nas-populator-console-names.json` | `Name`, `ShortName`, optional `SubDir`, `Extensions`, optional `Optical`. |
| `*.template.*` | Used to recreate the three files above (first run, invalid JSON, or menu **6**). |

**Credentials:** `SharePassword` is stored in JSON as plain text. Do not commit real production secrets to a public repo.

**ZIP arguments:** `ZipCompressionArgs` is **normalized** in code (`ConvertTo-ZipCompressionArgs` in `nas-populator-helpers.ps1`); only a subset of 7-Zip switches are forwarded.

## Notes

- **Multiple mode switches** are rejected; pick one Raw/Zip/Cleanup variant.
- **No overwrites** - destination files that already exist are skipped.
- **Cleanup** uses each console’s `Extensions` list; **`.rom` and `.zip` are always allowed**. Consoles with **no** `Extensions` list are **skipped** for deletion (warning only).
- **BIN/CUE** sets stay inside per-game folders; they are not flattened to the region or console root.
- **Boot** `*.rom` files (name contains `boot`, case-insensitive) are not moved into region folders.
- **Error log** path follows your **shell current directory**, not necessarily the script folder.
- **JSON paths** must escape backslashes (`\\` in JSON strings). The script may offer to repair common mistakes when errors are detected.

## What You’ll See

During processing:

- Optional **“Organizing existing files for console:”** progress for destinations that already exist.
- Per-item lines for copy, extract, zip, and 7-Zip-driven operations (with elapsed time and size where applicable).

At the end:

- **Completion summary** - destination, total time, files/bytes (and compressed stats in Zip runs).
- **Console summary** - per-system time and throughput.
- **Region summary / totals** - when region organization was enabled.
- **Error count** and log filename if anything failed.

## FAQ

**Q: Why does it say PowerShell 7.x is required?**

**A:** The script uses APIs and behavior that are not limited to Windows PowerShell 5.1. Install [PowerShell 7](https://github.com/PowerShell/PowerShell) and run `pwsh` (or `pwsh -File .\nas-populator.ps1`).

**Q: Can I use UNC paths for source and destination?**

**A:** Yes. Sources are mounted with `New-PSDrive`; UNC destinations can be mapped the same way. Fix typos like a single leading `\`—the script normalizes `\\server\share` forms.

**Q: Why were no files copied?**

**A:** Common causes: every source entry is still commented out in `nas-populator-sources.psd1`; `Name` does not match `nas-populator-console-names.json`; or everything already exists at the destination (no-overwrite).

**Q: Why does Zip mode still copy some things as raw?**

**A:** **Optical** systems always use raw CHD / BIN+CUE handling. Existing `.zip` archives are always copied as-is. BIN+CUE sets extracted from archives are copied as folders, not re-zipped as a single game archive in the same way as a single loose ROM.

**Q: Where is the error log?**

**A:** `errorlog-YYYYMMDD-HHMMSS.log` in the **folder you ran the command from** (current working directory), not automatically next to the `.ps1` file.

**Q: How do I reset config to defaults?**

**A:** Run the script, choose menu **6**, and confirm which files to recreate from templates—or delete the JSON/PSD1 and let first-run prompts copy templates.

**Q: Is it safe to run cleanup?**

**A:** Cleanup **deletes** files under each console folder whose extension is **not** allowed for that console (plus always keeps `.rom` / `.zip`). If `Extensions` is missing for a console, that folder is **not** cleaned. Review `nas-populator-console-names.json` before using option **5** or `-Cleanup`.

**Q: Does this include ROMs or BIOS files?**

**A:** No. The script only copies what you already have on your shares. You are responsible for complying with copyright and licensing.

## Project

Repository: https://github.com/cosmickatamari/nas-populator

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
