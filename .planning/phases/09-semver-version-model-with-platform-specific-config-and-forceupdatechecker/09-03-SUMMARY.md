---
phase: 09-semver-version-model-with-platform-specific-config-and-forceupdatechecker
plan: "03"
subsystem: api/barrel/tests
tags: [semver, checkForUpdate, pub_semver, barrel, tests, example]
dependency_graph:
  requires: [09-01, 09-02]
  provides: [checkForUpdate-semver, barrel-new-exports, tests-green]
  affects:
    - lib/src/macos_updater_api.dart
    - lib/macos_updater.dart
    - test/macos_updater_api_test.dart
    - test/macos_updater_test.dart
    - example/lib/app.dart
tech_stack:
  added: []
  patterns: [pub_semver-Version.parse, three-way-sealed-result, semver-comparison]
key_files:
  created: []
  modified:
    - lib/src/macos_updater_api.dart
    - lib/macos_updater.dart
    - test/macos_updater_api_test.dart
    - test/macos_updater_test.dart
    - example/lib/app.dart
decisions:
  - "checkForUpdate() uses pub_semver Version.parse() for all version comparisons — replaces int buildNumber comparison"
  - "Three-way result: UpToDate | ForceUpdateRequired | OptionalUpdateAvailable — UpdateAvailable fully removed"
  - "Example app updated to use getUpdateDetails() with PlatformUpdateDetails and the new 3-way switch"
metrics:
  duration: 4m
  completed_date: "2026-03-26"
  tasks_completed: 2
  files_changed: 5
---

# Phase 09 Plan 03: checkForUpdate() Semver Rewrite and Barrel Update Summary

checkForUpdate() rewritten to use pub_semver Version.parse() for three-way semver comparison (UpToDate / ForceUpdateRequired / OptionalUpdateAvailable); barrel exports PlatformUpdateDetails and UpdateDetails; all API tests rewritten for new contracts; example app migrated.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Rewrite checkForUpdate() with semver logic | 65e9c46 | lib/src/macos_updater_api.dart |
| 2 | Update barrel exports and all API tests | 6001f22 | lib/macos_updater.dart, test/macos_updater_api_test.dart, test/macos_updater_test.dart, example/lib/app.dart |

## What Was Built

- **checkForUpdate()** completely rewritten: calls `source.getUpdateDetails()`, reads `details.macos` (PlatformUpdateDetails), calls `getCurrentVersion()` returning String, uses `Version.parse()` for all comparisons, returns 3-way sealed result
- **Semver logic**: `currentVersion >= latestVersion` → UpToDate; `currentVersion < minimumVersion` → ForceUpdateRequired; else → OptionalUpdateAvailable
- **Barrel** (`lib/macos_updater.dart`): added exports for `platform_update_details.dart` and `update_details.dart`; `update_check_result.dart` export already covers ForceUpdateRequired/OptionalUpdateAvailable
- **API tests** completely rewritten: MockUpdateSource uses `getUpdateDetails()`, MockMacosUpdaterPlatform.versionToReturn is `String`, helper `_makeUpdateDetails()` builds test fixtures, 8 checkForUpdate test cases covering all branches
- **Example app** migrated to new API: `JsonUpdateSource.getUpdateDetails()` fetching platform config JSON, exhaustive switch on ForceUpdateRequired/OptionalUpdateAvailable
- **89 tests pass**; **flutter analyze** reports zero issues project-wide

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Unused import in macos_updater_api.dart**
- **Found during:** Task 1 analysis
- **Issue:** `update_details.dart` import was added per plan spec but not needed — types are accessed via `source.getUpdateDetails()` return type inference
- **Fix:** Removed unused import; `flutter analyze` confirmed zero issues
- **Files modified:** lib/src/macos_updater_api.dart

**2. [Rule 1 - Bug] macos_updater_test.dart MockMacosUpdaterPlatform returns Future<int> for getCurrentVersion()**
- **Found during:** Task 2 — full `flutter test` run
- **Issue:** `test/macos_updater_test.dart` had `Future<int> getCurrentVersion()` but platform interface changed to `Future<String>` in Plan 02 — compilation error
- **Fix:** Updated `MockMacosUpdaterPlatform.getCurrentVersion()` to return `Future<String>` with value `'1.0.0'`
- **Files modified:** test/macos_updater_test.dart

**3. [Rule 3 - Blocking] Example app used removed UpdateAvailable and deleted buildNumber**
- **Found during:** Task 2 — `flutter analyze` after barrel update
- **Issue:** `example/lib/app.dart` used `getLatestUpdateInfo()`, `buildNumber`, `isMandatory`, and `UpdateAvailable` — all removed in Plans 01/02
- **Fix:** Rewrote `JsonUpdateSource` to implement `getUpdateDetails()`, updated `_checkForUpdate()` to use exhaustive switch on ForceUpdateRequired/OptionalUpdateAvailable, removed isMandatory field (now inferred from result type)
- **Files modified:** example/lib/app.dart

## Known Stubs

None — all fields are fully implemented. No placeholder values or TODO items.

## Self-Check: PASSED

Files verified:
- lib/src/macos_updater_api.dart — FOUND
- lib/macos_updater.dart — FOUND
- test/macos_updater_api_test.dart — FOUND
- test/macos_updater_test.dart — FOUND
- example/lib/app.dart — FOUND

Commits verified:
- 65e9c46 (checkForUpdate rewrite) — FOUND
- 6001f22 (barrel + tests + example) — FOUND
