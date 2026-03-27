---
phase: 04-public-api
plan: 01
subsystem: api
tags: [dart, flutter, update-engine, platform-interface, sealed-classes]

# Dependency graph
requires:
  - phase: 03-core-engine
    provides: generateLocalFileHashes, diffFileHashes, downloadFiles engine functions
  - phase: 02-updatesource-contract
    provides: UpdateSource abstract interface class
  - phase: 01-foundation
    provides: UpdateInfo, FileHash, UpdateProgress, UpdateCheckResult, UpdateError sealed types, DesktopUpdaterPlatform.getCurrentVersion
provides:
  - checkForUpdate(UpdateSource) top-level function with NetworkError wrapping
  - downloadUpdate(UpdateInfo, onProgress) top-level function bridging downloadFiles stream
  - applyUpdate() top-level function wrapping DesktopUpdaterPlatform.restartApp in RestartFailed
  - generateLocalFileHashes({path}) public API wrapper delegating to engine
  - All four functions exported via lib/desktop_updater.dart public barrel
affects: [05-cleanup, 06-native-swift, 07-cli-tools]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - top-level function API (no class wrapper) for the v2 public surface
    - try-catch-rethrow wrapping UpdateSource calls as NetworkError
    - hasher prefix import to disambiguate same-named engine function from public wrapper
    - MockDesktopUpdaterPlatform extends DesktopUpdaterPlatform (not Fake) to pass verifyToken
    - TestWidgetsFlutterBinding.ensureInitialized() required for platform instance setter in tests

key-files:
  created:
    - lib/src/desktop_updater_api.dart
    - test/desktop_updater_api_test.dart
  modified:
    - lib/desktop_updater.dart

key-decisions:
  - "hasher prefix import used for file_hasher.dart to disambiguate engine generateLocalFileHashes from the identically-named public wrapper"
  - "MockDesktopUpdaterPlatform extends DesktopUpdaterPlatform (not implements) so PlatformInterface.verifyToken passes on instance setter assignment"
  - "checkForUpdate wraps entire body in try-catch(Object), not just UpdateSource calls, ensuring NoPlatformEntry from generateLocalFileHashes also maps to NetworkError"
  - "downloadUpdate appDir resolved as File(Platform.resolvedExecutable).parent.parent.path — consistent with macOS Contents/ layout"

patterns-established:
  - "Public API functions are top-level (not methods) — import the package and call directly"
  - "All UpdateSource exceptions mapped to NetworkError at the API boundary"
  - "PlatformException from restartApp mapped to RestartFailed at the API boundary"

requirements-completed: [API-03, API-04, API-05, API-07]

# Metrics
duration: 3min
completed: 2026-03-26
---

# Phase 4 Plan 1: Public API Summary

**Four top-level functions (checkForUpdate, downloadUpdate, applyUpdate, generateLocalFileHashes) wiring the engine to the public barrel with typed error boundaries**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-26T13:05:04Z
- **Completed:** 2026-03-26T13:08:00Z
- **Tasks:** 4
- **Files modified:** 3

## Accomplishments
- Created `lib/src/desktop_updater_api.dart` with four documented public functions orchestrating the Phase 3 engine
- Written 10 unit tests covering all four functions with a `MockDesktopUpdaterPlatform` that properly extends the abstract class for verifyToken compatibility
- Updated `lib/desktop_updater.dart` barrel to export `desktop_updater_api.dart` — all four functions now importable from the package root
- Full test suite (63 tests) passes, flutter analyze exits with 0 errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement desktop_updater_api.dart with four public functions** - `3f4d369` (feat)
2. **Task 2: Write unit tests for all four API functions** - `2345d01` (test)
3. **Task 3: Add v2 API exports to the public barrel** - `2ddf5ec` (feat)
4. **Task 4: Full test suite and final analyzer sweep** - verification only, no new commit

## Files Created/Modified
- `lib/src/desktop_updater_api.dart` - Four top-level consumer-facing functions: checkForUpdate, downloadUpdate, applyUpdate, generateLocalFileHashes
- `test/desktop_updater_api_test.dart` - 10 unit tests covering all four functions with MockUpdateSource and MockDesktopUpdaterPlatform
- `lib/desktop_updater.dart` - Added `export 'package:desktop_updater/src/desktop_updater_api.dart'` after update_source export

## Decisions Made
- Used `import "package:desktop_updater/src/engine/file_hasher.dart" as hasher;` prefix import to avoid name collision between the engine function and the identically-named public wrapper function
- `MockDesktopUpdaterPlatform extends DesktopUpdaterPlatform` (not `implements`) so `PlatformInterface.verifyToken` passes when assigning `DesktopUpdaterPlatform.instance` in tests
- `checkForUpdate` wraps its entire body (not just UpdateSource calls) in try-catch so that NoPlatformEntry from the engine also maps to NetworkError
- `downloadUpdate` resolves `appDir` as `File(Platform.resolvedExecutable).parent.parent.path` — mirrors macOS `.app/Contents/` layout established in the engine

## Deviations from Plan

None - plan executed exactly as written.

The worktree branch was behind `main` and lacked Phase 3 engine files; a `git merge main` fast-forward was performed before execution began. This is a worktree setup issue, not a plan deviation.

## Issues Encountered
- Worktree branch `worktree-agent-a148b624` was based on the pre-Phase-3 `origin/main` commit. Ran `git merge main` (fast-forward) to bring in all Phase 3 engine files before starting task execution.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Public API is complete and exported; Phase 5 (cleanup) can remove v1 widget exports and the `DesktopUpdater` class from the barrel
- All four API symbols are accessible via `import 'package:desktop_updater/desktop_updater.dart'`
- No blockers for Phase 5

---
*Phase: 04-public-api*
*Completed: 2026-03-26*
