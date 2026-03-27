---
phase: 07-cli-dependencies
plan: 02
subsystem: pubspec
tags: [dependencies, version-bump, sdk-constraint, dart-3.7, flutter-3.29]
dependency_graph:
  requires: []
  provides: [pubspec.yaml@v2.0.0]
  affects: [pubspec.lock]
tech_stack:
  added: []
  patterns: [flutter-pub-get]
key_files:
  created: []
  modified:
    - pubspec.yaml
decisions:
  - "Used flutter pub get instead of dart pub get — package requires Flutter SDK"
  - "All 55 dart analyze issues are info-level pre-existing; zero errors introduced by flutter_lints 6.0.0"
metrics:
  duration: 98s
  completed: "2026-03-27"
  tasks: 2
  files_changed: 1
requirements: [CLI-03, CLI-04, CLI-05, CLI-06]
---

# Phase 07 Plan 02: Update pubspec.yaml to v2.0.0 Summary

**One-liner:** Bumped package to v2.0.0 with Dart 3.7+/Flutter 3.29+ SDK constraints, cryptography_plus/flutter_plus ^3.0.0, updated all deps to latest, removed args.

## Tasks Completed

| # | Task | Status | Commit |
|---|------|--------|--------|
| 1 | Update pubspec.yaml — version, SDK, and all dependencies | Done | 9fc2728 |
| 2 | Verify dart analyze clean after dependency bump | Done | (analysis-only, no files changed) |

## What Was Built

Updated `pubspec.yaml` with all v2.0.0 changes:

- **Version:** `1.4.0` → `2.0.0`
- **SDK constraint:** `^3.6.0` → `">=3.7.0 <4.0.0"`
- **Flutter constraint:** `">=3.3.0"` → `">=3.29.0"`
- **cryptography_plus:** `^2.7.1` → `^3.0.0`
- **cryptography_flutter_plus:** `^2.3.4` → `^3.0.0`
- **archive:** `^4.0.2` → `^4.0.9`
- **http:** `^1.2.2` → `^1.6.0`
- **path:** `^1.9.0` → `^1.9.1`
- **plugin_platform_interface:** `^2.0.2` → `^2.1.8`
- **args:** REMOVED entirely (no longer used after Phase 7 CLI simplification)
- **flutter_lints:** `^5.0.0` → `^6.0.0`

`flutter pub get` resolved all dependencies cleanly. `dart analyze` exits 0 with 55 pre-existing info-level issues — no errors, no new lint failures introduced by flutter_lints 6.0.0.

## Verification Results

```
version: 2.0.0                           ✓
sdk: ">=3.7.0 <4.0.0"                   ✓
flutter: ">=3.29.0"                      ✓
args: (not present)                      ✓
cryptography_plus: ^3.0.0               ✓
cryptography_flutter_plus: ^3.0.0       ✓
flutter_lints: ^6.0.0                   ✓
dart analyze exit code: 0               ✓
```

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

**Note:** Plan specified `dart pub get` but the package requires Flutter SDK. Used `flutter pub get` instead — this is the correct command for Flutter plugins (per CLAUDE.md `Build & Test Commands`).

## Decisions Made

- Used `flutter pub get` instead of `dart pub get` (Flutter SDK dependency required it)
- 55 info-level lint issues confirmed pre-existing — not introduced by flutter_lints 6.0.0 bump

## Self-Check: PASSED
