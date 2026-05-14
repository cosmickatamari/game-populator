### Release notes - 05/09/2026

This is the **`libraries\`** layout: almost everything for **`game-populator.ps1`** now lives under **`libraries\`**, and a new **function library** file holds the heavy menu and run workflow so the entry script stays mostly bootstrap and wiring.

---

### New layout (where files live)

- **Helpers** - **`libraries\helpers.ps1`** (loaded first, as before conceptually, but from the subfolder).
- **Workflow code** - **`libraries\game-populator-functions.ps1`** is the new home for the big interactive flows: 
	- gathering sources
	- validating config
	- menus and wizards
	- run orchestration
	- checkpoints
- **Templates and catalogs** - **`settings.template.json`**, **`console-names*.json`**, and the split **name** and **source** templates all sit under **`libraries\`**.

---

### New features and configuration

- **Split source templates** - Instead of one root **`sources.template.psd1`**, there are four commented templates: 
	- **`console-sources.template.psd1`**
	- **`hacks-sources.template.psd1`**
	- **`trans-sources.template.psd1`**
	- **`addons-sources.template.psd1`**
		- each with the same “uncomment to enable” action scoped to that category.
- **Split name catalogs** - Beyond **`console-names`**, the tree adds: 
	- **`hacks-names`**
	- **`trans-names`**
	- **`addons-names`**
		- (each with a **`.template.json`** twin) so hacks, translations, and add-on style systems do not overload a single JSON file.
- **More settings** - 
	- **`libraries\settings.template.json`** gains practical runtime controls, including: 
		- **`MaxFilesPerFolder`**
		- **`MaxConcurrentFileCopies`**
		- **`StructuredRunLog`**
		- **`UseRunCheckpoint`**
			- so larger runs can be tuned without editing script internals.