### Release notes - 05/06/2026

---

### Fixes and correctness

- **Error logs live with the script** - Errors go under **`logs\errorlog-*.log`** instead of whatever the **current working directory** happened to be, and the on-screen wording matches that layout.
- **Cleanup results are real numbers** - Destination cleanup reports **files removed** and **empty folders removed**; those counts appear in both the **console wrap-up** and the **gamerun** log.
- **Safer deletes** - **`Remove-DestinationFilesNotMatchingExtensions`** and **`Remove-EmptyFolders`** return simple **tally objects** and wrap **`Remove-Item`** in **try/catch** so failures surface instead of vanishing.
- **Self-update confirmation** - The final **“OK to proceed?”** for **`Invoke-GamePopulatorSelfUpdate`** defaults to **no** and reads a little clearer across multiple lines.

---

### New features and UX

- **Gamerun log beside the script** - Each run can write **`logs\gamerun-*.log`** with the **completion summary**, **console summary**, and **region** sections, including a **Grand Total** line for region counts when that block runs.
- **Live status on slow work** - While **connecting to a UNC destination** (interactive cleanup-only restart path) and during **destination cleanup scan/remove**, a **background job** can print a **rolling status line on stderr** so a long SMB wait does not look frozen.
	- There is a soft **30s** advisory before the message reflects that Windows may still be trying.
- **Clearer UNC connect messaging** - **`Initialize-DestinationRoot`** separates the “connecting…” line from the path and, when not in **`-Quiet`**, prints the **UNC in green** so the eye lands on the server share.
- **Elapsed time wording** - **`Format-Elapsed`** spells out **day / days** when a span crosses whole days.
- **Menu look and feel**:
	- Banner uses **dark green**
	- settings headers and path callouts use **cyan / green**
	- **Turn systems on/off** and **path edit** prompts are reworded (including **`[Enter]`** hints and a short **comma-separated numbers** example).
	- Section headers lean **cyan**
	- labels are tightened (**Toggle visibility…**, **Edit network share mapping**, **file & folder cleanup**)
- **Less noisy invalid menu input** - A bad choice no longer **redraw the entire main menu** every time; the menu stays until you pick something valid.
- **Command-line cleanup** - **`-Cleanup`** sets **restart-after-interactive-cleanup** when **stdin is not redirected**, matching the menu-driven cleanup restart story.

---

### Maintenance menu (options 4–6)

- **Recreate from templates (4)** - Defaults to **no** per file so a slip on **Enter** is less likely to wipe a good **`settings.json`** or share list.
- **Install from GitHub (5)** - Always runs the self-update helper and **restarts the script** when you return from that flow—even if you **decline** the download—so you are not left on an odd half-updated menu state.
- **Reset SMB / reconnect (6)**:
	- **Proceed?** defaults to **no**
	- **`settings.json`** is highlighted in **green** in the explanation. 
	- After success it may wait on **Enter** via **`ReadKey`** with a **`Read-Host`** fallback.

---

### End-of-run and restart prompts

When the script restarts after **interactive cleanup**, the **“press Enter”** wait prefers **`Console.ReadKey`** for **Enter**, with **`Read-Host`** as fallback, and the **`[Enter]`** hint is styled in **dark green**.