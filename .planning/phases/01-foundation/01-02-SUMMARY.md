---
phase: 01-foundation
plan: "02"
subsystem: models
tags: [models, sealed-class, barrel-export, update-check, tdd]
dependency_graph:
  requires:
    - FileHash (MODEL-02, from Plan 01)
    - UpdateProgress (MODEL-03, from Plan 01)
    - UpdateError sealed hierarchy (MODEL-04, from Plan 01)
  provides:
    - UpdateInfo (MODEL-01)
    - UpdateCheckResult sealed type (MODEL-05)
    - Barrel export for all 5 foundation types
  affects:
    - Wave 3+ plans that depend on UpdateInfo and UpdateCheckResult
    - Consumer imports — all 5 types accessible via single barrel import
tech_stack:
  added: []
  patterns:
    - "final class with const constructor and @immutable (flutter/foundation.dart)"
    - "copyWith using `field ?? this.field` pattern"
    - "sealed class for UpdateCheckResult exhaustive switch without default arm"
    - "barrel export with hide to prevent ambiguous_export for same-named v1 type"
key_files:
  created:
    - lib/src/models/update_info.dart
    - lib/src/errors/update_check_result.dart
    - test/models_test.dart
  modified:
    - lib/desktop_updater.dart
decisions:
  - "UpdateCheckResult lives in lib/src/errors/ per D-11 directory layout despite not being an error type — pairs logically with UpdateError in the errors layer"
  - "src/models/update_progress.dart exported with `hide UpdateProgress` to prevent ambiguous_export conflict with v1 src/update_progress.dart — resolved in Phase 5 when v1 exports are removed"
  - "Comment references to non-visible symbols (checkForUpdate, downloadUpdate) replaced with plain text to satisfy comment_references lint"
metrics:
  duration: "8m"
  completed: "2026-03-26T10:00:00Z"
  tasks_completed: 4
  files_created: 3
  files_modified: 1
---

# Phase 01 Plan 02: UpdateInfo, UpdateCheckResult, and Barrel Export Summary

**One-liner:** UpdateInfo model (with FileHash dependency) and sealed UpdateCheckResult type wired into the barrel export, completing the 5-type foundation vocabulary for v2.

## What Was Built

Four artifacts delivering the remaining foundation types:

1. **`lib/src/models/update_info.dart`** — `UpdateInfo` final class with const constructor and 4 required fields: `version` (String, display only), `buildNumber` (int, used for comparison), `remoteBaseUrl` (String), `changedFiles` (List<FileHash>). `copyWith` uses the `this.field` pattern.

2. **`lib/src/errors/update_check_result.dart`** — `sealed class UpdateCheckResult` with two variants: `UpToDate()` (const, no fields) and `UpdateAvailable(UpdateInfo info)`. An exhaustive switch on both arms compiles without a `default` case.

3. **`lib/desktop_updater.dart`** — Updated barrel with 5 new exports: `file_hash`, `update_info`, `update_progress` (models), `update_error`, and `update_check_result`. All existing v1 exports preserved. `update_progress` from models is exported with `hide UpdateProgress` to avoid conflict with the v1 `src/update_progress.dart` export.

4. **`test/models_test.dart`** — 9 unit tests covering `FileHash` (copyWith, fromJson, toJson), `UpdateInfo` (copyWith), and `UpdateProgress` (copyWith). All tests pass.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create UpdateInfo model (MODEL-01) | 0becff7 | lib/src/models/update_info.dart |
| 2 | Create UpdateCheckResult sealed type (MODEL-05) | 05973fc | lib/src/errors/update_check_result.dart |
| 3 | Add new types to barrel export (D-13) | ee18f63 | lib/desktop_updater.dart |
| 4 | Write copyWith unit tests for models | d6f63e5 | test/models_test.dart |

## Verification Results

- `flutter test test/models_test.dart` — **All 9 tests pass**
- `flutter analyze lib/src/models/update_info.dart` — No issues found
- `flutter analyze lib/src/errors/update_check_result.dart` — No issues found
- `flutter analyze lib/desktop_updater.dart` — 11 pre-existing `public_member_api_docs` info issues in the v1 `DesktopUpdater` class (confirmed pre-existing, not introduced by this plan)
- All structural checks pass: exports verified, v1 exports preserved

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed comment_references lint for non-visible symbols**
- **Found during:** Task 1 and Task 2 (flutter analyze)
- **Issue:** `[downloadUpdate]` and `[checkForUpdate]` in doc comments triggered `comment_references` lint — these functions don't exist yet
- **Fix:** Replaced bracketed references with plain text in doc comments
- **Files modified:** `lib/src/models/update_info.dart`, `lib/src/errors/update_check_result.dart`
- **Commit:** Included in task commits 0becff7 and 05973fc

**2. [Rule 1 - Bug] Fixed ambiguous_export error for UpdateProgress**
- **Found during:** Task 3 (flutter analyze)
- **Issue:** Both `src/update_progress.dart` (v1) and `src/models/update_progress.dart` (v2) export `UpdateProgress`, causing an `ambiguous_export` error and a `return_of_invalid_type` error in the `DesktopUpdater.updateApp` method
- **Fix:** Added `hide UpdateProgress` to the `src/models/update_progress.dart` export so the v1 class remains the exported one for now; the v1 export is removed in Phase 5
- **Files modified:** `lib/desktop_updater.dart`
- **Commit:** ee18f63

**3. [Rule 3 - Reorder] Fixed directives_ordering lint for new exports**
- **Found during:** Task 3 (flutter analyze)
- **Issue:** New package: exports added after relative export triggered `directives_ordering` lint
- **Fix:** Placed all package: exports before the relative `"desktop_updater_inherited_widget.dart"` export
- **Files modified:** `lib/desktop_updater.dart`
- **Commit:** ee18f63

## Known Stubs

None — all files are complete type definitions with no placeholder values or unresolved data sources.
