---
phase: 07-cli-dependencies
plan: 01
subsystem: cli-tools
tags: [cli, macos-only, simplification, release, archive]
dependency_graph:
  requires: []
  provides: [macOS-only release CLI, macOS-only archive CLI]
  affects: [bin/release.dart, bin/archive.dart]
tech_stack:
  added: []
  patterns: [macOS-only platform guard, import from helper/copy.dart]
key_files:
  created: []
  modified:
    - bin/release.dart
    - bin/archive.dart
decisions:
  - "macOS-only platform validation: single 'if (platform != macos)' guard replaces three-way check"
  - "copyDirectory imported from helper/copy.dart in release.dart, no inline redefinition"
  - "genFileHashes() in archive.dart left unchanged — hashes.json format stability preserved"
metrics:
  duration: 2m
  completed: 2026-03-27
  tasks_completed: 2
  files_modified: 2
---

# Phase 7 Plan 01: CLI macOS-Only Simplification Summary

macOS-only CLI rewrites removing all Windows/Linux dead code paths from release.dart and archive.dart, with clear error messages for unsupported platforms.

## What Was Built

Both `bin/release.dart` and `bin/archive.dart` were rewritten to accept only `"macos"` as the platform argument. The validation in both files was simplified from a three-way `platform != "macos" && platform != "windows" && platform != "linux"` guard to a single `platform != "macos"` check. Error messages in both locations (empty-args print and validation check) were updated to `"Only macos is supported. Usage: dart run desktop_updater:{release|archive} macos"`.

In `bin/release.dart`:
- `Platform.isWindows` flutter executable detection block removed; replaced with `const flutterExecutable = "flutter"`
- `late Directory buildDir` triple-branch if/else replaced with direct macOS-only `final buildDir`
- Windows/Linux dist path ternary replaced with macOS-only `distPath`
- Inline `copyDirectory` function (48 lines) removed; `import "helper/copy.dart"` added

In `bin/archive.dart`:
- Windows and Linux `copyDirectory` branches removed; only macOS branch retained
- `genFileHashes()` function left completely unchanged — `hashes.json` format stability preserved
- All imports unchanged: `dart:convert`, `dart:io`, `cryptography_plus`, `file_hash.dart`, `helper/copy.dart`

## Verification

```
dart analyze bin/release.dart bin/archive.dart bin/helper/copy.dart
```
Result: 20 info-level `avoid_print` warnings (pre-existing in CLI scripts), zero errors.

```
grep -n "windows|linux|Platform.isWindows|Platform.isLinux" bin/release.dart bin/archive.dart
```
Result: no output (zero matches).

## Commits

| Task | Description | Hash |
|------|-------------|------|
| 1 | feat(07-01): rewrite bin/release.dart to macOS-only | a11e062 |
| 2 | feat(07-01): rewrite bin/archive.dart to macOS-only | d48a723 |

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- bin/release.dart exists and contains no Windows/Linux references
- bin/archive.dart exists and contains no Windows/Linux platform checks
- Commits a11e062 and d48a723 exist in git log
