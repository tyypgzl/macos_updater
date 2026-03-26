---
phase: 01-foundation
plan: "01"
subsystem: models
tags: [models, errors, sealed-class, json-serialization, tdd]
dependency_graph:
  requires: []
  provides:
    - FileHash (MODEL-02)
    - UpdateProgress (MODEL-03)
    - UpdateError sealed hierarchy (MODEL-04)
  affects:
    - Wave 2 plans that depend on FileHash (UpdateInfo, UpdateCheckResult)
tech_stack:
  added: []
  patterns:
    - "final class with const constructor and @immutable (flutter/foundation.dart)"
    - "copyWith using `field ?? this.field` pattern"
    - "sealed class hierarchy for exhaustive switch without default arm"
    - "JSON key aliasing: filePath↔'path', hash↔'calculatedHash'"
key_files:
  created:
    - lib/src/models/file_hash.dart
    - lib/src/models/update_progress.dart
    - lib/src/errors/update_error.dart
    - test/models/file_hash_test.dart
    - test/models/update_progress_test.dart
    - test/errors/update_error_test.dart
  modified: []
decisions:
  - "@immutable from package:flutter/foundation.dart instead of package:meta — flutter is already a direct dependency; avoids depend_on_referenced_packages lint violation"
  - "Docs added to all public members to satisfy public_member_api_docs lint rule"
metrics:
  duration: "3m 17s"
  completed: "2026-03-26T09:32:48Z"
  tasks_completed: 3
  files_created: 6
  files_modified: 0
---

# Phase 01 Plan 01: Leaf Model Types (FileHash, UpdateProgress, UpdateError) Summary

**One-liner:** Three foundation leaf types — FileHash with JSON key aliasing, UpdateProgress with copyWith, and a sealed UpdateError hierarchy — enabling exhaustive switch pattern matching across the plugin.

## What Was Built

Three new Dart files under `lib/src/models/` and `lib/src/errors/`:

1. **`lib/src/models/file_hash.dart`** — `FileHash` final class for delta comparison. JSON keys intentionally differ from field names (`"path"` → `filePath`, `"calculatedHash"` → `hash`) to maintain compatibility with the CLI-produced `hashes.json` format.

2. **`lib/src/models/update_progress.dart`** — `UpdateProgress` final class emitted as a stream during download. Five typed fields; `copyWith` uses the `this.field` pattern to avoid the self-reference bug found in the existing codebase.

3. **`lib/src/errors/update_error.dart`** — `sealed class UpdateError` with exactly 5 final subtypes: `NetworkError`, `HashMismatch`, `NoPlatformEntry`, `IncompatibleVersion`, `RestartFailed`. `HashMismatch` uniquely carries a `filePath` field. Consumers can switch exhaustively without a `default` arm.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | FileHash model (MODEL-02) | 2d71540 | lib/src/models/file_hash.dart, test/models/file_hash_test.dart |
| 2 | UpdateProgress model (MODEL-03) | f326387 | lib/src/models/update_progress.dart, test/models/update_progress_test.dart |
| 3 | UpdateError sealed hierarchy (MODEL-04) | 7858a63 | lib/src/errors/update_error.dart, test/errors/update_error_test.dart |

## Verification Results

- `flutter analyze lib/src/models/file_hash.dart lib/src/models/update_progress.dart lib/src/errors/update_error.dart` — **No issues found!**
- All 20 tests pass across 3 test files
- `grep -c 'final class.*extends UpdateError'` returns 5 (exactly as specified)
- JSON key contract confirmed: `"path"`, `"calculatedHash"`, `"length"` in both fromJson and toJson

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] Used `package:flutter/foundation.dart` instead of `package:meta/meta.dart`**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** `package:meta` is not a direct dependency; using it triggers `depend_on_referenced_packages` lint error
- **Fix:** Replaced `import "package:meta/meta.dart"` with `import "package:flutter/foundation.dart"` — both export `@immutable`, and `flutter` is already a direct dependency
- **Files modified:** `lib/src/models/file_hash.dart`, `lib/src/models/update_progress.dart`
- **Commit:** Included in task commits 2d71540 and f326387

**2. [Rule 2 - Missing] Added public API documentation to all public members**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** `public_member_api_docs` lint rule requires `///` docs on all public members
- **Fix:** Added documentation comments to all constructors, factory constructors, fields, and methods across all three files
- **Files modified:** All three new files

## Known Stubs

None — all three files are complete data definitions with no placeholder values or unresolved data sources.
