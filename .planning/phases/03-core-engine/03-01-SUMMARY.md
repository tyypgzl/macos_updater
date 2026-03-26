---
phase: 03-core-engine
plan: 01
subsystem: core-engine
tags: [dart, blake2b, cryptography_plus, file-hashing, delta-update]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: FileHash model (lib/src/models/file_hash.dart) and UpdateError hierarchy (lib/src/errors/update_error.dart)
provides:
  - generateLocalFileHashes() — scans app bundle, returns List<FileHash> in-memory using Blake2b
  - diffFileHashes() — pure in-memory comparison returning only changed/new remote entries
affects:
  - 03-02 (engine orchestration that will call these two functions)
  - 07-cli (CLI produces hashes.json consumed at runtime by generateLocalFileHashes)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Optional path injection pattern: functions accept String? path to override Platform.resolvedExecutable in tests"
    - "Pure in-memory diff: no temp files written, Map<filePath, FileHash> lookup for O(n) comparison"
    - "macOS bundle resolution: strip last path segment then call .parent to reach Contents/ root"

key-files:
  created:
    - lib/src/engine/file_hasher.dart
    - test/engine/file_hasher_test.dart
  modified: []

key-decisions:
  - "generateLocalFileHashes returns List<FileHash> directly — no temp file written to disk, clean in-memory API"
  - "diffFileHashes is purely local/remote comparison by filePath key — O(n) via Map lookup"
  - "NoPlatformEntry thrown (not generic Exception) when bundle directory missing, aligning with UpdateError hierarchy"

patterns-established:
  - "Path injection: pass String? path to override Platform.resolvedExecutable for test isolation"
  - "macOS-aware bundle dir: dir.parent called only when Platform.isMacOS"

requirements-completed: [ENG-01]

# Metrics
duration: 3min
completed: 2026-03-26
---

# Phase 03 Plan 01: File Hasher Engine Summary

**Blake2b file hasher with in-memory generateLocalFileHashes() and pure diffFileHashes() replacing v1 temp-file-based genFileHashes()/verifyFileHashes() pair**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-26T13:43:06Z
- **Completed:** 2026-03-26T13:46:15Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `lib/src/engine/file_hasher.dart` with two top-level functions satisfying ENG-01
- `generateLocalFileHashes()` scans app bundle via Blake2b, returns `List<FileHash>` directly — no temp file written
- `diffFileHashes()` performs pure in-memory Map-based comparison returning only changed or new remote entries
- 9 unit tests passing covering all specified behaviors including NoPlatformEntry, empty dir, single file, and all diff scenarios

## Task Commits

Each task was committed atomically:

1. **Task 1: Create file_hasher.dart with generateLocalFileHashes and diffFileHashes** - `01e7289` (feat)
2. **Task 2: Create file_hasher_test.dart covering hash diff and local hash generation** - `0707466` (test)

## Files Created/Modified

- `lib/src/engine/file_hasher.dart` — generateLocalFileHashes and diffFileHashes top-level functions
- `test/engine/file_hasher_test.dart` — 9 unit tests covering all behaviors

## Decisions Made

- `generateLocalFileHashes` returns `List<FileHash>` directly (no temp file) — v1 wrote hashes.json to a temp dir which is unnecessary for runtime engine use
- `diffFileHashes` uses `Map<String, FileHash>` lookup for O(n) comparison instead of nested loops
- Throws `NoPlatformEntry` (not generic Exception) when bundle dir missing, consistent with sealed UpdateError hierarchy

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `[parent]` and `[Platform.resolvedExecutable]` doc comment references**
- **Found during:** Task 1 (lint verification after creation)
- **Issue:** `comment_references` lint rule requires doc comment cross-references to resolve in scope; `[parent]` and `[Platform.resolvedExecutable]` were unresolved
- **Fix:** Changed unresolvable `[references]` to backtick code spans `` `parent` `` and `` `Platform.resolvedExecutable` ``
- **Files modified:** lib/src/engine/file_hasher.dart
- **Verification:** `flutter analyze lib/src/engine/file_hasher.dart` — 0 issues
- **Committed in:** 01e7289 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed test file lint issues (cascade, void assignment, wildcard)**
- **Found during:** Task 2 (lint verification after test creation)
- **Issue:** `createSync()` returns void (cannot assign to variable); `_` wildcard identifier not supported; `avoid_single_cascade_in_expression_statements` violation
- **Fix:** Removed void assignments, removed `_` discard pattern, changed `..writeAsBytesSync` cascade to direct call
- **Files modified:** test/engine/file_hasher_test.dart
- **Verification:** `flutter analyze test/engine/file_hasher_test.dart` — 0 issues
- **Committed in:** 0707466 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - bugs found during lint verification)
**Impact on plan:** Both required for zero-issues lint compliance. No scope creep.

## Issues Encountered

None beyond the lint deviations documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `generateLocalFileHashes` and `diffFileHashes` are ready for use by the engine orchestration layer in Phase 03-02
- Both functions are fully tested and lint-clean
- No blockers

---
*Phase: 03-core-engine*
*Completed: 2026-03-26*

## Self-Check: PASSED

- lib/src/engine/file_hasher.dart: FOUND
- test/engine/file_hasher_test.dart: FOUND
- .planning/phases/03-core-engine/03-01-SUMMARY.md: FOUND
- Commit 01e7289: FOUND
- Commit 0707466: FOUND
