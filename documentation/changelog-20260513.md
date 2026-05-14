### Release notes - 05/13/2026

### Fixes and correctness

- **Region totals match what is on disk** - Region counting follows real MiSTer-style region buckets (translations, MSU-style folders, and other non-region labels are not mistaken for regions). Counts use **files under each region folder**, not only immediate children, so totals line up with a real folder tree.
- **Console summaries stay readable** - Per-console rows at the end of a run are **sorted alphabetically** by display name. The region block uses the same idea so long console lists scan predictably.
- **MKDIR** - if a `\games` directory does not exist on the destination, the script will attempt to make it at startup.


---

### New features and UX

- **Run finished: table instead of a paragraph per system** - After a copy run, the **Console Summary** is a simple **markdown-style table** (columns: System, Elapsed Time, Files Copied, File Size). Columns pad to the widest value so it lines up in the terminal. The **same table** is written into the **gamerun** text summary log, so logs and screen match.
- **Clearer sizing in the table** - File sizes still use the existing human formatter (automatic **B / KB / MB / GB** based on how large the copy was).

---

### Behavior and tooling (helpers + entry script)

- **Regions and paths** - Helpers to resolve region tokens to folder names, treat “geo” organize folders sensibly, and handle Mega CD-style layout variants where paths fork in awkward ways.
- **7-Zip** - More defensive discovery of the **7-Zip** executable when the obvious path is missing or wrong.
- **Archives** - Listing and measuring what is inside archives (filtered through **7z**) for reporting and decisions without unpacking everything first.
- **Cleanup** - Dedicated cleanup log line writing so removals can be traced without spelunking the main log alone.
- **Game Boy / Super Game Boy counting rules** - Extra guards so certain folder layouts are counted the way you expect for GB/SGB setups.

---

### Settings and function library

- **`MaxFilesPerFolder`** - **`libraries\game-populator-functions.ps1`** still reads **`MaxFilesPerFolder`** from **`libraries\settings.json`** and exposes it as **`$script:GamePopulatorMaxFilesPerFolder`** for the copy pipeline.
- **Hacks marked optical** - **hack display names** from **`libraries\hacks-names.json`** where **`Optical`** is **`yes`**, and uses that for **per-archive / per-game folder** layout behavior for those hacks.

---

### Catalog and JSON choices

- **`console-names.json`** (and **`.template.json`**):
	- **Neo Geo** is oriented around **`.zip`** on the NAS side
	- **Super Cassette Vision** keeps **`.0` / `.1`** as well as **`.bin`** where the stock file had simplified extensions
	- **Game Gear** extension lists differ (whether **`.sms`** is included with the rest). 
	- **Super Game Boy** rows may omit the extra **`SubDir`** split the stock JSON added for GB vs GBC—your tree matches how you actually folder the destination.
- **`hacks-names.json`** (and **`.template.json`**):
	- **Different `SubDir` numbering** (folder sort prefixes), **`.sms`** allowed on several Genesis-class hack rows, some rows **no longer marked 
	- `Optical: yes`** where you treat them as ordinary subfolders
	- **32X MSU-MD** paths adjusted to your numbering scheme.