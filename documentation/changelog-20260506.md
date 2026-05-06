### Commited Changes

**05/06/2026 (`game-populator.ps1`, `helpers.ps1`, plus local config)** — compared to the local GitHub checkout (same filenames: `game-populator.ps1`, `helpers.ps1`, `console-names.json`, `console-names.template.json`, `sources.template.psd1`, `settings.template.json`).

1. **Shipped config parity** — In this comparison, **`console-names.json`**, **`console-names.template.json`**, **`sources.template.psd1`**, and **`settings.template.json`** are **byte-identical** between the GitHub tree and **`mister-nas-populate`**; no schema or catalog edits in those four files for this drop.
2. **Local working config** — **`settings.json`** under **`mister-nas-populate`** is a **populated** runtime file (non-empty destination/temp paths and share fields) versus the **empty-placeholder** values in **`settings.template.json`** in the repo snapshot. **`sources.psd1`** in the working folder is a **live** data file (uncommented **`Sources`** entries with real share paths); it is **not** the same as the all-commented **`sources.template.psd1`**, by design. A file named **`sources - Copy.psd1`** in the working folder was **not** treated as part of the baseline diff (local backup/duplicate only).
3. **Logging and summaries** — Runs now create a **`logs`** directory beside the script and write a timestamped **`gamerun-*.log`** containing the **completion summary**, **console summary**, and **region** blocks (including a **Grand Total** line for region counts). **Error logs** move from the **current working directory** into **`logs\errorlog-*.log`**, with adjusted on-screen wording. When cleanup runs, the script tallies **files removed** and **empty folders removed** and includes those counts in both the console summary and the gamerun log.
4. **Live status on slow operations** — **`helpers.ps1`** adds **background thread jobs** that print a **rolling status line on stderr** while **connecting to a UNC destination** (30s “advisory limit” hint, then indicates Windows SMB may still be waiting) during **interactive cleanup-only** flows, and during **destination cleanup (scan/remove)**. **`Initialize-DestinationRoot`** messaging splits the “connecting…” line and prints the **UNC path in green** when not in **`-Quiet`** mode.
5. **`helpers.ps1` behavior tweaks** — **`Invoke-GamePopulatorSelfUpdate`** now uses a clearer multi-line prompt and **`Read-YesNoDefaultNo`** for the final **“OK to proceed?”** step (default **no**). **`Format-Elapsed`** uses **“day” / “days”** for multi-day spans. **`Remove-DestinationFilesNotMatchingExtensions`** and **`Remove-EmptyFolders`** return **`pscustomobject`** tallies and use **try/catch** around **`Remove-Item`** instead of silent failure-only removal.
6. **Interactive UX (main script)** — Banner lines use **dark green** instead of blue; **Settings** header and path highlights use **cyan / green**. **Turn on/off systems** and **path edit** prompts are **reworded** (including **`[Enter]`** phrasing and a short **comma-separated numbers** example). **`Show-MainMenu`** labels are tightened (“**Toggle visibility**…”, “**Edit network share mapping**”, “**file & folder cleanup**”, section headers **cyan**). **`Read-Host`** prompts for the numeric main menu and settings editor are **phrased differently**; invalid menu input no longer **repaints the entire menu** each time (menu shows once until a valid choice advances). **`-Cleanup`** from the command line sets **`RestartAfterInteractiveCleanup`** when **stdin is not redirected**, aligning behavior with menu-driven cleanup restarts.
7. **Maintenance options 4–6** — **Recreate config from templates (option 4)** now defaults to **no** per file (**`Read-YesNoDefaultNo`**) instead of **yes**, reducing accidental overwrites. **GitHub install (option 5)** always **executes the self-update helper and then restarts**, even when the user **declines** the download (formerly a **decline** could leave you on the menu without restarting). **Reset SMB / reconnect destination (option 6)** asks **Proceed?** with default **no**; **`settings.json`** is called out in **green** in the explanatory text; after a successful run it can prompt with **`[Console]::ReadKey`** for **Enter** before restart (fallback to **`Read-Host`**).
8. **End-of-run prompts** — When the script restarts after **interactive cleanup**, the **“press Enter”** wait prefers **`Console.ReadKey`** for **Enter** with a **`Read-Host`** fallback, with clearer **dark green `[Enter]`** labeling.

---

The sections below group the same changes for reviewers scanning by file.

## Entry script (`game-populator.ps1`)

- **Rough size** — On the machines compared here, **`git diff --stat`** reported on the order of **~297 insertions / ~110 deletions** versus the GitHub copy; most churn is UX, logging, and cleanup counting rather than core copy loops.
- **Completion path** — Builds **`logs`**, aggregates **`cleanupFilesRemoved` / `cleanupFoldersRemoved`**, writes **`gamerun-*.log`**, redirects **error logs** under **`logs\`**, extends **region totals** output with **Grand Total**, and adjusts error banner wording.
- **UNC / cleanup UX** — Optional **stderr countdown** job while connecting to **`\\`** destinations in the **interactive cleanup-only** restart path (`Start-DestinationUncConnectionCountdownDisplay` / **`Stop-GamePopulatorBackgroundStatusDisplay`**).

## Helpers (`helpers.ps1`)

- **`git diff --stat`** — On the order of **~81 insertions / ~8 deletions**, dominated by logging helpers, tally returns, **`Format-Elapsed`** pluralization, self-update prompting, **`Initialize-DestinationRoot`** formatting, and the **thread-job** status writers.

## Shipped templates and console metadata

- **`settings.template.json`**, **`sources.template.psd1`**, **`console-names.template.json`**, **`console-names.json`** — No differences **between `C:\Users\Cosmic\Documents\GitHub\game-populator` and `D:\scripts\mister-nas-populate`** for these four files **in this comparison**.

## Local-only files (`settings.json`, `sources.psd1`)

- **`settings.json`** — Expect differences from **`settings.template.json`** whenever you configure real **`DestinationRoot`**, **`TempRoot`**, or credentials; commit **templates**, not secrets, to GitHub.
- **`sources.psd1`** — Maintained locally; uncomment and set **`SourcePath`** values per machine. **`sources.template.psd1`** remains the **commented skeleton** shipped with the repo.

## Notes for publishing

If you intend to **`git push`** the **`D:\scripts\mister-nas-populate`** script changes onto **`game-populator`**, consider addressing **menu option 5** always restarting after a declined update (either restore conditional restart or document it as deliberate). Optionally bump **`$script:ScriptVersion`** / header **Updated** dates when distributing a labeled release.

