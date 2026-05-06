### Commited Changes

**05/04/2026 (`game-populator.ps1`, `helpers.ps1`, config assets)** — compared to the desktop snapshot under `mister-nas-populate - Copy` (`nas-populator.ps1`, `nas-populator-helpers.ps1`, `nas-populator-settings.template.json`, `nas-populator-console-names(.template).json`, `nas-populator-sources.template.psd1`), representing **NAS Populator** circa **2026.3.8** (per script headers).

1. **Rename and repository** — Project and entry script are **Game Populator** on [github.com/cosmickatamari/game-populator](https://github.com/cosmickatamari/game-populator). On-disk filenames drop the `nas-populator-` prefix: **`game-populator.ps1`**, **`helpers.ps1`**, **`settings.json`** (from **`settings.template.json`**), **`sources.psd1`** (from **`sources.template.psd1`**), **`console-names.json`** (from **`console-names.template.json`**). The helpers file is no longer named `nas-populator-helpers.ps1`.
2. **MiSTer-oriented copy pipeline** — Help and behavior describe organizing images for **MiSTer** (network shares or local/USB), with archives **extracted** and material laid out for use on the device; the older **Raw vs Zip** split (`-RawOrg` / `-RawNoOrg` / `-ZipOrg` / `-ZipNoOrg` and `Mode`) is replaced by **`-Org`** and **`-NoOrg`**. **`settings.template.json`** no longer carries **`ZipCompressionArgs`** (the older stack could run a “ZIP mode” path and apply heavy 7-Zip compression settings for outputs).
3. **CLI and diagnostics** — Added **`-Diag`** for startup progress lines (useful when the script appears to hang, e.g. on UNC work). **`Read-YesNoDefaultYes`** / related prompts use **`Read-Host`** with optional console flush instead of **`[Console]::ReadLine()`**, which could block in some hosts.
4. **Interactive experience** — The menu is reorganized into **Maintenance** (toggle systems from `sources.psd1`, edit `settings.json`, cleanup, recreate configs, **reinstall latest from GitHub**, **reset SMB mappings**) and **Performing** (same idea as former modes 1–4 plus a **custom run**). Option numbering and labels differ from the old 1–6 + E layout.
5. **Network and templates** — **SMB** handling is stricter and more discoverable: per-server credential consistency, **fingerprinting** to catch auth mismatches early, **expanded error hints**, and explicit **destination `games` folder** normalization when the path does not already end in `games`. Missing **template** files can be **downloaded from GitHub** at startup; **self-update** prefers **`git pull`** when a `.git` folder and `git` exist, otherwise falls back to **main branch ZIP** extraction, preserving existing `settings.json`, `sources.psd1`, and `console-names.json`.
6. **`console-names` data** — **`console-names.json`** / **`.template.json`** are **not** byte-identical to the NAS Populator copies: entries are **reordered**, **BBC Bridge Companion** is added, several systems use **refined `ShortName` / `SubDir` / `Extensions`** (e.g. **Game Boy Color** as **`GBC`**, **Game Gear** as **`GameGear`**, **WonderSwan Color** as **`WonderSwanColor`**, **ColecoVision** vs **Sega SG-1000** under shared **`Coleco`** with subfolders, **Philips CD-i** display name shortened). Some rows present only in the older file (e.g. standalone **Nintendo Satellaview**) are folded into the newer **SNES / Satellaview** style entries; **Nintendo 64** allowed extensions differ (older list included **`.gb` / `.gbc`**). **Atari 2600** in the old JSON incorrectly reused the **`Atari7800`** short name; the new file corrects that pattern.

---

The sections below expand the same comparison for readers migrating folders or diffing behavior.

## Entry script (`game-populator.ps1`)

- **Bootstrap** — Resolves **`$script:EntryScriptPath`**, stashes **`$script:GamePopulatorBoundParameters`**, loads **`helpers.ps1`** with an explicit missing-file check, and wraps **`Clear-Host`** in **try/catch** for hosts where it fails.
- **Templates** — If any of **`settings.template.json`**, **`sources.template.psd1`**, or **`console-names.template.json`** is missing locally, the script attempts **`Restore-GamePopulatorTemplatesFromGitHub`** and **re-execs** the entry script.
- **Volume** — Line count roughly **doubles** versus `nas-populator.ps1` in the compared snapshot, driven by the richer menu, settings editor, custom run, SMB helpers, and self-update paths.

## Helpers (`helpers.ps1`)

- **Branding** — **`$script:ScriptName`** is **Game Populator**; **`$script:ScriptVersion`** advanced to **2026.5.4** in the compared tree.
- **New surface** — **`Invoke-GamePopulatorSelfUpdate`**, **`Restore-GamePopulatorTemplatesFromGitHub`**, **`Invoke-OutputFlush`**, **`Format-PathForDisplay`**, **`Read-YesNoDefaultNo`**, SMB guard/registration helpers (e.g. **`Test-SmbEstablishedCredentialCompatibility`**, **`Expand-SmbConnectErrorHint`**), and related **UNC** utilities.
- **Help text** — Rewritten around MiSTer layout, **`games`** path behavior, UNC credential rules, template download, and new examples invoking **`game-populator.ps1`**.

## Settings template (`settings.template.json`)

- **Removed** — **`ZipCompressionArgs`** array (paired with removal of output-side ZIP compression configuration from the settings model in this release direction).
- **Unchanged in the compared pair** — **`DestinationRoot`**, **`TempRoot`**, **`SevenZipExe`**, **`ArchiveExtensions`**, **`ShareUser`**, **`SharePassword`** keys still appear with the same placeholder shape.

## Sources template (`sources.template.psd1`)

- **Commented catalog** — Same overall “uncomment to enable” structure; differences include **BBC Bridge Companion**, **Sega Genesis - Mega Drive** vs **Mega Drive - Sega Genesis** naming, **Nintendo Super Game Boy** block with **`SGB`** path, **Philips Compact Disc-Interactive** naming alignment, and removal of the old **Nintendo Satellaview** commented stub in favor of the SNES-oriented entries (see JSON side for the authoritative split).

## Console names (`console-names.json`, `console-names.template.json`)

- Treat the **NAS Populator** and **Game Populator** JSON files as **different datasets**: same *kind* of file (array of objects with **`Name`**, **`ShortName`**, optional **`SubDir`**, **`Optical`**, **`Extensions`**), but **hashes differ** and **row sets and field values** diverge as summarized in item 6 above. After upgrade, **do not assume** you can swap the file back without re-validating paths and allowed extensions.

## Migration notes

- Replace **script and helper** names in shortcuts, Task Scheduler, and docs: run **`game-populator.ps1`** and dot-source **`helpers.ps1`** only from the new layout.
- Rename or recreate config files to the **new basenames** (or use **recreate from template** in the menu) so paths in **`settings.json`** and share lists in **`sources.psd1`** match what the new script expects.
- If you relied on **ZIP output mode** or **`ZipCompressionArgs`**, plan a quick test pass: the **Game Populator** direction compared here emphasizes **extraction and copy** for MiSTer rather than maintaining a parallel “leave as ZIP on destination” workflow.
