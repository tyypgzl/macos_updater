---
phase: 05-ui-removal
plan: "01"
subsystem: lib
tags:
  - ui-removal
  - barrel-cleanup
  - v1-deletion
dependency_graph:
  requires:
    - "04-01: public-api — provides v2 API functions and types barrel must export"
  provides:
    - "clean v2-only barrel (lib/desktop_updater.dart)"
    - "no widget or v1 engine code under lib/"
  affects:
    - "consumers of desktop_updater package (breaking: v1 symbols removed)"
    - "bin/archive.dart (updated to v2 FileHash model)"
tech_stack:
  added: []
  patterns:
    - "Barrel-only exports: no import statements, no class definitions in lib/desktop_updater.dart"
key_files:
  created: []
  modified:
    - lib/desktop_updater.dart
    - example/lib/app.dart
    - lib/desktop_updater_platform_interface.dart
    - lib/desktop_updater_method_channel.dart
    - bin/archive.dart
    - test/desktop_updater_test.dart
    - test/desktop_updater_api_test.dart
    - example/integration_test/plugin_integration_test.dart
  deleted:
    - lib/widget/update_card.dart
    - lib/widget/update_dialog.dart
    - lib/widget/update_widget.dart
    - lib/widget/update_sliver.dart
    - lib/widget/update_direct_card.dart
    - lib/updater_controller.dart
    - lib/desktop_updater_inherited_widget.dart
    - lib/src/localization.dart
    - lib/src/app_archive.dart
    - lib/src/version_check.dart
    - lib/src/update.dart
    - lib/src/download.dart
    - lib/src/prepare.dart
    - lib/src/file_hash.dart
    - lib/src/update_progress.dart
decisions:
  - "Deleted DesktopUpdater class entirely from barrel — all functionality is now top-level functions in desktop_updater_api.dart"
  - "Removed v1 methods (verifyFileHash, prepareUpdateApp, generateFileHashes, updateApp) from DesktopUpdaterPlatform — v2 engine handles these directly"
  - "Updated bin/archive.dart to use v2 FileHash model (hash: field) instead of v1 FileHashModel (calculatedHash: field)"
metrics:
  duration: "~10m"
  completed: "2026-03-27"
  tasks_completed: 2
  files_modified: 8
  files_deleted: 15
---

# Phase 05 Plan 01: UI Removal and Barrel Cleanup Summary

**One-liner:** Deleted 15 v1 widget/engine files and rewrote barrel to export only 7 v2 type/API directives with zero errors from flutter analyze.

## What Was Built

All v1 widget code (5 widget files), the controller, inherited widget, localization, and 6 v1 engine files were deleted. The public barrel (`lib/desktop_updater.dart`) was rewritten to a clean 7-line export-only file with no class definitions and no import statements. The example app was rewritten to use only v2 API patterns.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Delete all v1 and widget files | fa002b1 | 15 files deleted |
| 2 | Rewrite barrel and update example app | b9173c8 | 8 files modified |

## Decisions Made

1. **Deleted DesktopUpdater class entirely** — All functionality is now in top-level functions (`checkForUpdate`, `downloadUpdate`, `applyUpdate`, `generateLocalFileHashes`) in `desktop_updater_api.dart`. The class was a v1 wrapper with no v2 purpose.

2. **Removed v1 platform interface methods** — `verifyFileHash`, `prepareUpdateApp`, `generateFileHashes`, `updateApp` were removed from `DesktopUpdaterPlatform`. The v2 engine handles these operations directly without calling the platform interface.

3. **Updated bin/archive.dart to v2 FileHash** — Changed import from `app_archive.dart` to `models/file_hash.dart` and updated constructor from `calculatedHash:` to `hash:` to match v2 model field names.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed DesktopUpdaterPlatform importing deleted app_archive.dart**
- **Found during:** Task 2 (flutter analyze after barrel rewrite)
- **Issue:** `lib/desktop_updater_platform_interface.dart` imported `app_archive.dart` (deleted) and declared methods using `FileHashModel` (v1, deleted)
- **Fix:** Removed app_archive import, removed v1 methods (verifyFileHash, prepareUpdateApp, generateFileHashes, updateApp), added documentation comments
- **Files modified:** `lib/desktop_updater_platform_interface.dart`
- **Commit:** b9173c8

**2. [Rule 1 - Bug] Fixed MethodChannelDesktopUpdater overriding deleted updateApp method**
- **Found during:** Task 2
- **Issue:** `lib/desktop_updater_method_channel.dart` had `@override updateApp()` but platform interface no longer has that method
- **Fix:** Removed the updateApp override
- **Files modified:** `lib/desktop_updater_method_channel.dart`
- **Commit:** b9173c8

**3. [Rule 1 - Bug] Fixed test/desktop_updater_test.dart using deleted DesktopUpdater class and FileHashModel**
- **Found during:** Task 2
- **Issue:** Test file referenced `DesktopUpdater()` class (deleted from barrel) and `FileHashModel` (v1, deleted)
- **Fix:** Rewrote test to call `DesktopUpdaterPlatform.instance.getPlatformVersion()` directly; updated mock to extend rather than implement platform (no longer needs v1 methods)
- **Files modified:** `test/desktop_updater_test.dart`
- **Commit:** b9173c8

**4. [Rule 1 - Bug] Fixed bin/archive.dart importing deleted app_archive.dart**
- **Found during:** Task 2
- **Issue:** `bin/archive.dart` imported `app_archive.dart` (deleted) and used `FileHashModel` (v1)
- **Fix:** Updated import to `models/file_hash.dart`, renamed type from `FileHashModel` to `FileHash`, updated constructor parameter from `calculatedHash:` to `hash:`
- **Files modified:** `bin/archive.dart`
- **Commit:** b9173c8

**5. [Rule 1 - Bug] Fixed integration test using deleted DesktopUpdater class**
- **Found during:** Task 2
- **Issue:** `example/integration_test/plugin_integration_test.dart` instantiated `DesktopUpdater()` (deleted class)
- **Fix:** Updated to call `DesktopUpdaterPlatform.instance.getPlatformVersion()` directly
- **Files modified:** `example/integration_test/plugin_integration_test.dart`
- **Commit:** b9173c8

**6. [Rule 1 - Bug] Removed unused import in test/desktop_updater_api_test.dart**
- **Found during:** Task 2 (flutter analyze warning)
- **Issue:** Unused import of `update_progress.dart` after barrel cleanup
- **Fix:** Removed the unused import
- **Files modified:** `test/desktop_updater_api_test.dart`
- **Commit:** b9173c8

## Known Stubs

None — all exports are wired to real v2 implementations.

## Verification Results

All plan success criteria met:
- Zero widget, controller, localization, or v1 engine files exist under lib/
- lib/desktop_updater.dart contains only 7 export directives (no imports, no class)
- flutter analyze reports zero errors and zero warnings on the package
- example/lib/app.dart references only v2 API symbols (UpdateSource, checkForUpdate, etc.)

## Self-Check: PASSED
