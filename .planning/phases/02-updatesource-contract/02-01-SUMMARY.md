---
phase: 02-updatesource-contract
plan: "01"
subsystem: api
tags: [dart, flutter, abstract-interface, update-source, mock, tdd]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: UpdateInfo, FileHash, UpdateError models used as UpdateSource return types

provides:
  - abstract interface class UpdateSource with getLatestUpdateInfo() and getRemoteFileHashes()
  - MockUpdateSource test double with configurable fixtures for use in Phase 3 unit tests
  - ThrowingUpdateSource test double for verifying engine error-boundary pattern
  - UpdateSource exported from lib/desktop_updater.dart barrel

affects:
  - 03-core-engine (calls UpdateSource methods, wraps in try-catch mapping to UpdateError)
  - consumers (implement UpdateSource to connect any backend — Firebase, REST, local)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - abstract interface class (Dart 3 modifier) for consumer-implemented contracts
    - engine error-boundary pattern: catch any exception, map to typed UpdateError subtype
    - MockUpdateSource pattern: configurable fixtures via constructor parameters

key-files:
  created:
    - lib/src/update_source.dart
    - test/update_source_test.dart
  modified:
    - lib/desktop_updater.dart

key-decisions:
  - "getLatestUpdateInfo() returns Future<UpdateInfo?> — null means up-to-date (D-14)"
  - "getRemoteFileHashes(String remoteBaseUrl) returns Future<List<FileHash>> (D-15)"
  - "abstract interface class modifier used (Dart 3, D-16) — enforces implement-only, not extend"
  - "UpdateError imported in update_source.dart for dartdoc comment_references lint compliance"
  - "ThrowingUpdateSource throws plain Exception (not UpdateError) — confirms consumers need not use UpdateError"

patterns-established:
  - "UpdateSource interface: two-method contract with no boilerplate for consumer implementations"
  - "MockUpdateSource pattern: constructor-injected fixtures, zero state mutation"
  - "Engine error-boundary: withErrorBoundary() wraps any UpdateSource call in try-catch, maps to NetworkError"

requirements-completed: [API-01, API-02]

# Metrics
duration: 2min
completed: 2026-03-26
---

# Phase 2 Plan 01: UpdateSource Interface Contract Summary

**`abstract interface class UpdateSource` with two typed async methods (getLatestUpdateInfo/getRemoteFileHashes), exported from barrel, with MockUpdateSource test double and 6 contract tests establishing the engine-consumer boundary**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-26T11:29:52Z
- **Completed:** 2026-03-26T11:32:26Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Defined `abstract interface class UpdateSource` in `lib/src/update_source.dart` with exactly two method signatures, full dartdoc, and a minimal consumer implementation example
- Exported UpdateSource from `lib/desktop_updater.dart` barrel so consumers get it from a single import: `package:desktop_updater/desktop_updater.dart`
- Created `test/update_source_test.dart` with MockUpdateSource, ThrowingUpdateSource, and 6 passing contract tests (4 mock behavior + 2 error boundary mapping)

## Interface Signature

```dart
abstract interface class UpdateSource {
  Future<UpdateInfo?> getLatestUpdateInfo();
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl);
}
```

- `getLatestUpdateInfo()` returns `Future<UpdateInfo?>` — null signals up-to-date
- `getRemoteFileHashes(String remoteBaseUrl)` returns `Future<List<FileHash>>`

## MockUpdateSource Structure (for Phase 3)

```dart
class MockUpdateSource implements UpdateSource {
  MockUpdateSource({this.updateInfo, this.fileHashes = const []});

  final UpdateInfo? updateInfo;
  final List<FileHash> fileHashes;

  @override
  Future<UpdateInfo?> getLatestUpdateInfo() async => updateInfo;

  @override
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) async =>
      fileHashes;
}
```

Phase 3 can instantiate `MockUpdateSource(updateInfo: someInfo, fileHashes: someList)` for any test scenario.

## Task Commits

Each task was committed atomically:

1. **Task 1: Define UpdateSource interface and export from barrel** - `bd186e1` (feat)
2. **Task 2: MockUpdateSource test double and contract tests** - `bd25d49` (test)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `lib/src/update_source.dart` — abstract interface class UpdateSource with two method signatures, full dartdoc including consumer example
- `test/update_source_test.dart` — MockUpdateSource, ThrowingUpdateSource, withErrorBoundary helper, 6 contract tests
- `lib/desktop_updater.dart` — added `export "package:desktop_updater/src/update_source.dart";` in alphabetical order after update_progress

## Decisions Made

- Added `import "package:desktop_updater/src/errors/update_error.dart";` to `update_source.dart` to satisfy `comment_references` lint for `[UpdateError]` dartdoc references — required by the project's strict analysis rules
- Used tearoff `source.getLatestUpdateInfo` instead of `() => source.getLatestUpdateInfo()` to satisfy `unnecessary_lambdas` lint rule

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added UpdateError import for dartdoc comment_references lint**
- **Found during:** Task 1 (Define UpdateSource interface)
- **Issue:** `flutter analyze` reported `comment_references` lint on `[UpdateError]` in class-level dartdoc — the type wasn't imported so the reference wasn't resolvable
- **Fix:** Added `import "package:desktop_updater/src/errors/update_error.dart";` as first import in `update_source.dart`
- **Files modified:** `lib/src/update_source.dart`
- **Verification:** `flutter analyze lib/src/update_source.dart` reports "No issues found"
- **Committed in:** `bd186e1` (Task 1 commit)

**2. [Rule 1 - Bug] Fixed unnecessary_lambdas lint in test error boundary**
- **Found during:** Task 2 (MockUpdateSource test double)
- **Issue:** `flutter analyze` reported `unnecessary_lambdas` at `() => source.getLatestUpdateInfo()` — closure is a tearoff
- **Fix:** Changed to `source.getLatestUpdateInfo` tearoff syntax
- **Files modified:** `test/update_source_test.dart`
- **Verification:** `flutter analyze test/update_source_test.dart` reports "No issues found", all 6 tests still pass
- **Committed in:** `bd25d49` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 missing import for lint compliance, 1 lint bug fix)
**Impact on plan:** Both auto-fixes required for zero-warning compliance with project's strict analysis rules. No scope creep.

## Issues Encountered

- Pre-existing `public_member_api_docs` warnings in old `DesktopUpdater` class in `lib/desktop_updater.dart` — these are out of scope (not caused by this phase's changes, will be addressed when that class is refactored in a later phase). Deferred to `deferred-items.md`.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- UpdateSource interface is finalized and exported — Phase 3 (Core Engine) can import it and call its methods
- MockUpdateSource in `test/update_source_test.dart` is ready to copy/import in Phase 3 unit tests
- Error-boundary pattern demonstrated: engine wraps UpdateSource calls in try-catch, maps any exception to NetworkError
- Full test suite passes: 38 total tests, 0 failures, no Phase 1 regressions
- Concerns: pre-existing analyze warnings in old `DesktopUpdater` class do not affect Phase 3

---
*Phase: 02-updatesource-contract*
*Completed: 2026-03-26*

## Self-Check: PASSED

- FOUND: lib/src/update_source.dart
- FOUND: test/update_source_test.dart
- FOUND: .planning/phases/02-updatesource-contract/02-01-SUMMARY.md
- FOUND commit: bd186e1 (feat(02-01): define UpdateSource abstract interface class and export from barrel)
- FOUND commit: bd25d49 (test(02-01): add MockUpdateSource, ThrowingUpdateSource, and contract tests)
