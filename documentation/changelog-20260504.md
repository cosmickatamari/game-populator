### Release notes - 05/04/2026

---

### Fixes and correctness

- **Prompts that could hang** - Yes/no flows use **`Read-Host`** (with optional output flush) instead of **`[Console]::ReadLine()`**, which could wedge in some hosts.
- **Hosts that dislike `Clear-Host`** - Clearing the screen is wrapped so a failure there does not take down startup.
- **`console-names` accuracy** - This catalog with Game Populator fixes mistakes in the older JSON (for example **Atari 2600** no longer reuses the wrong **`ShortName`** pattern). Treat the new file as the source of truth for paths and extensions.

---

### New features and UX

- **Project identity** - Scripts and docs are now known as **Game Populator** on [GitHub](https://github.com/cosmickatamari/game-populator).
- **MiSTer-first copy story** - Help and behavior describe **extracting archives** and laying material out for the device. 
	- The older **Raw vs Zip** switch set is replaced by a simpler **`-Org`** / **`-NoOrg`** split. 
	- There is no longer a dedicated “write everything back out as ZIP with heavy compression” path; **`ZipCompressionArgs`** is removed from the settings model so expectations stay on **copy + extract** workflows.
- **`-Diag`** - Optional startup tracing when the script feels stuck (especially useful on **UNC** paths).
- **Menu layout** - **Maintenance** (toggle systems, edit settings, cleanup, recreate configs, **pull latest from GitHub**, **reset SMB mappings**) and **Performing** (the run modes you had before, plus **custom run**). 
	- Numbering and labels differ from the old **1–6 + E** layout by design.
- **SMB and paths** — Stricter per-server credential handling, **fingerprinting** to catch “wrong password for this server” early, clearer error hints, and automatic nudging when **`DestinationRoot`** should live under a **`games`** folder but does not yet end that way.
- **Templates and updates** — Missing template files can be **downloaded from GitHub** at startup. 
	- **Self-update** prefers **`git pull`** when a repo and **`git`** are available; otherwise it pulls the **main** ZIP and keeps your existing **`settings.json`**, **`sources.psd1`**, and **`console-names.json`** where possible.

---

### Configuration and data (`console-names`)

Files **`console-names.json`** / **`.template.json`** reflect current MiSTer-style layout choices, including:

- **BBC Bridge Companion** added.
- Cleaner **`ShortName`** / **`SubDir`** / **`Extensions`** for several systems: 
	- **Game Boy Color** as **`GBC`**
	- **Game Gear** as **`GameGear`**
	- **WonderSwan Color** as **`WonderSwanColor`**
	- **ColecoVision** vs **Sega SG-1000** under **`Coleco`** with subfolders
	- Shorter **Philips CD-i** display text
- **Satellaview** folded into the **SNES**-oriented rows instead of a lone commented stub.
- **Nintendo 64** extensions trimmed to what belongs on that core (the older list had carried **`.gb` / `.gbc`**).
- General **row reordering** for readability.