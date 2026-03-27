# Phase 5: UI Removal - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Delete all widget, controller, inherited widget, and localization files. Clean barrel exports to only expose v2 engine API symbols. Write CHANGELOG migration section showing consumers exact replacements for each removed symbol.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion (all areas)

- **Files to delete:** `lib/widget/update_card.dart`, `lib/widget/update_dialog.dart`, `lib/widget/update_widget.dart`, `lib/widget/update_sliver.dart`, `lib/widget/update_direct_card.dart`, `lib/updater_controller.dart`, `lib/desktop_updater_inherited_widget.dart`, `lib/src/localization.dart`
- **Barrel cleanup:** Remove all v1 widget/controller exports from `lib/desktop_updater.dart`. Keep only v2 types + API exports.
- **Old v1 engine files:** Also remove `lib/src/app_archive.dart`, `lib/src/version_check.dart`, `lib/src/update.dart`, `lib/src/download.dart`, `lib/src/prepare.dart`, `lib/src/file_hash.dart` (old v1 versions — v2 replacements exist in `lib/src/models/`, `lib/src/engine/`, `lib/src/desktop_updater_api.dart`)
- **Migration guide:** CHANGELOG entry with exact before/after code for each removed symbol (DesktopUpdaterController → checkForUpdate/downloadUpdate functions, DesktopUpdateWidget → consumer builds own UI, etc.)
- **Example app:** Update or remove if it references deleted symbols
- **`lib/desktop_updater.dart` class:** The old `DesktopUpdater` class itself should be cleaned — keep only as a namespace or remove entirely if all functionality is now in top-level functions

</decisions>

<canonical_refs>
## Canonical References

### Files to Delete
- `lib/widget/` — All 5 widget files
- `lib/updater_controller.dart` — DesktopUpdaterController
- `lib/desktop_updater_inherited_widget.dart` — InheritedWidget
- `lib/src/localization.dart` — DesktopUpdateLocalization
- `lib/src/app_archive.dart` — v1 models (replaced by lib/src/models/)
- `lib/src/version_check.dart` — v1 version check (replaced by desktop_updater_api.dart)
- `lib/src/update.dart` — v1 update function (replaced by file_downloader.dart)
- `lib/src/download.dart` — v1 download function (replaced by file_downloader.dart)
- `lib/src/prepare.dart` — v1 prepare function
- `lib/src/file_hash.dart` — v1 file hash (replaced by engine/file_hasher.dart)

### v2 API (what stays)
- `lib/src/desktop_updater_api.dart` — Public API functions
- `lib/src/update_source.dart` — UpdateSource abstract interface
- `lib/src/models/` — v2 models
- `lib/src/errors/` — v2 error types
- `lib/src/engine/` — v2 engine functions
- `lib/desktop_updater.dart` — Barrel (to be cleaned)
- `lib/desktop_updater_platform_interface.dart` — Platform interface
- `lib/desktop_updater_method_channel.dart` — Method channel

### Project Context
- `.planning/REQUIREMENTS.md` — REM-01 through REM-05
- `.planning/ROADMAP.md` — Phase 5 success criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Integration Points
- `lib/desktop_updater.dart` barrel currently exports both v1 and v2 symbols — needs cleanup
- Example app likely imports deleted symbols — needs update
- `lib/src/update_progress.dart` (v1) may conflict with `lib/src/models/update_progress.dart` (v2) — v1 version should be deleted

</code_context>

<specifics>
## Specific Ideas

No specific requirements — straightforward deletion and cleanup.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-ui-removal*
*Context gathered: 2026-03-27*
