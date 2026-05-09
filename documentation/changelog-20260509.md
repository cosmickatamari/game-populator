### Commited Changes

**05/09/2026 (`game-populator.ps1`, `libraries\helpers.ps1`, new `libraries\game-populator-functions.ps1`, plus split config/templates)**

1. **Repository layout migrated to `libraries\`** - The workspace is now structured around `libraries\` for runtime config and helper code. Compared to the reference root layout, shared-name files such as `helpers.ps1`, `console-names.json`, `console-names.template.json`, and `settings.template.json` now live under `libraries\` and differ in content.
2. **Main script responsibilities narrowed + delegated** - `game-populator.ps1` acts more as bootstrap/entry orchestration while substantial menu and run logic is delegated into `libraries\game-populator-functions.ps1` (**new file; 51 functions**).
3. **Helper layer expanded materially** - `helpers.ps1` moved to `libraries\helpers.ps1` and expanded. The helper now has additional SMB, cleanup, formatting, logging, and archive/copy support logic.
4. **Source model split from single template to category templates** - Workspace replaces this with category specific templates in `libraries\`: `console-sources.template.psd1`, `hacks-sources.template.psd1`, `trans-sources.template.psd1`, `addons-sources.template.psd1` (plus active `.psd1` runtime counterparts).
5. **Name catalogs split and expanded by category** - Instead of only root `console-names*.json`, workspace includes `libraries\console/hacks/trans/addons` name templates and active files.
6. **Settings template schema expanded** - `settings.template.json` moved to `libraries\settings.template.json` and now includes additional operational keys. Added keys vs reference: `MaxFilesPerFolder`, `MaxConcurrentFileCopies`, `StructuredRunLog`, `UseRunCheckpoint`.

---

The sections below group the same changes for reviewers scanning by file.

## Entry script (`game-populator.ps1`)
- **Bootstrap shape** - Workspace entry now centers on `libraries\` initialization, config/template seeding, and loading helper/function libraries.

## Helpers (`helpers.ps1` -> `libraries\helpers.ps1`)
- **Operational impact** - Expanded utility responsibilities now include broader SMB session/connectivity handling, archive/copy helper coverage, and supporting runtime/reporting helpers used by the extracted function library.

## New library (`libraries\game-populator-functions.ps1`)
- **Scope** - Consolidates higher-level workflow behavior (source aggregation, config validation flows, interactive menu actions/wizards, and run/checkpoint helpers) that previously lived primarily in the entry script and root helper mix.

## Templates and metadata changes

- **`console-names.json`** - moved to `libraries\console-names.json`; content differs (`+481 / -56`).
- **`console-names.template.json`** - moved to `libraries\console-names.template.json`; content differs (`+481 / -56`).
- **`settings.template.json`** - moved to `libraries\settings.template.json`; content differs (`+9 / -1`) with new runtime-control keys.
- **`sources.template.psd1`** (reference root) - replaced by split category source templates under `libraries\` in workspace.

## Workspace only files

- `libraries\game-populator-functions.ps1`
- `libraries\settings.json`
- `libraries\console-sources.psd1`
- `libraries\console-sources.template.psd1`
- `libraries\hacks-sources.psd1`
- `libraries\hacks-sources.template.psd1`
- `libraries\trans-sources.psd1`
- `libraries\trans-sources.template.psd1`
- `libraries\addons-sources.psd1`
- `libraries\addons-sources.template.psd1`
- `libraries\hacks-names.json`
- `libraries\hacks-names.template.json`
- `libraries\trans-names.json`
- `libraries\trans-names.template.json`
- `libraries\addons-names.json`
- `libraries\addons-names.template.json`

## Reference only files
- `sources.template.psd1`