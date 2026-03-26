---
phase: 01-foundation
plan: 03
subsystem: api
tags: [dart, flutter, platform-interface, method-channel, type-safety]

# Dependency graph
requires:
  - phase: 01-01
    provides: Foundation data models and initial project structure

provides:
  - "DesktopUpdaterPlatform.getCurrentVersion() returns Future<int> (not Future<String?>)"
  - "MethodChannelDesktopUpdater.getCurrentVersion() uses invokeMethod<int> with non-null assertion"
  - "DesktopUpdater.getCurrentVersion() wrapper returns Future<int>"
  - "version_check.dart uses int comparison directly without int.parse()"
  - "Test mock MockDesktopUpdaterPlatform.getCurrentVersion() returns Future<int>"

affects:
  - 03-engine
  - 07-cli

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "invokeMethod<int> with non-null assertion (version!) for native integer channels"
    - "Direct int comparison for version numbers — no String parsing needed"

key-files:
  created: []
  modified:
    - lib/desktop_updater_platform_interface.dart
    - lib/desktop_updater_method_channel.dart
    - lib/desktop_updater.dart
    - lib/src/version_check.dart
    - test/desktop_updater_test.dart

key-decisions:
  - "getCurrentVersion() returns Future<int> not Future<String?> — engine (Phase 3) compares integers directly, eliminating int.parse() fragility"
  - "Non-null assertion (version!) on invokeMethod<int> result — null CFBundleVersion is a native configuration error that should surface loudly"

patterns-established:
  - "Pattern: Native integer channels use invokeMethod<int> with ! assertion, not String-then-parse"

requirements-completed: [API-06]

# Metrics
duration: 3min
completed: 2026-03-26
---

# Phase 01 Plan 03: getCurrentVersion Return Type Update Summary

**Platform interface getCurrentVersion() changed from Future<String?> to Future<int> with cascading updates to method channel, wrapper, version_check caller, and test mock**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-26T09:35:08Z
- **Completed:** 2026-03-26T09:38:01Z
- **Tasks:** 3 (+ 1 auto-fix)
- **Files modified:** 5

## Accomplishments
- `DesktopUpdaterPlatform.getCurrentVersion()` now declared as `Future<int>` — eliminates nullable String fragility
- `MethodChannelDesktopUpdater.getCurrentVersion()` uses `invokeMethod<int>` with `!` assertion for fail-loud behavior
- `version_check.dart` comparison simplified from `int.parse(currentVersion!)` to direct int comparison
- Test mock returns `Future.value(42)` matching new `Future<int>` contract

## Task Commits

Each task was committed atomically:

1. **Task 1: Update platform interface and wrapper** - `da52482` (feat)
2. **Task 2: Update method channel to invokeMethod<int>** - `b85d636` (feat)
3. **Task 3: Update test mock to Future<int>** - `fe30a67` (feat)
4. **Rule 1 fix: Update version_check.dart for Future<int>** - `4540a66` (fix)

## Files Created/Modified
- `lib/desktop_updater_platform_interface.dart` - getCurrentVersion() changed from Future<String?> to Future<int>
- `lib/desktop_updater_method_channel.dart` - getCurrentVersion() uses invokeMethod<int> with version! assertion
- `lib/desktop_updater.dart` - getCurrentVersion() wrapper returns Future<int>
- `lib/src/version_check.dart` - currentVersion changed from String? to int; int.parse() removed
- `test/desktop_updater_test.dart` - MockDesktopUpdaterPlatform.getCurrentVersion() returns Future.value(42)

## Decisions Made
- Non-null assertion `version!` on `invokeMethod<int>` result: null CFBundleVersion is a misconfiguration that should throw, not silently return null
- Linux path parses `version.json` build_number with `int.parse()` for consistency (still a string in the JSON file)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed version_check.dart type mismatch after getCurrentVersion() return type change**
- **Found during:** Task 3 verification (flutter test run)
- **Issue:** `lib/src/version_check.dart` used `late String? currentVersion` and assigned the `Future<int>` result to it, causing a type error. Also called `int.parse(currentVersion!)` which would be unnecessary after the type change.
- **Fix:** Changed `currentVersion` to `late int`, removed `int.parse()` call, simplified the else branch to `currentVersion = await DesktopUpdater().getCurrentVersion()`
- **Files modified:** `lib/src/version_check.dart`
- **Verification:** `flutter test test/desktop_updater_test.dart` — all 2 tests pass
- **Committed in:** `4540a66`

---

**Total deviations:** 1 auto-fixed (Rule 1 — type mismatch cascading from API return type change)
**Impact on plan:** Fix was necessary for correctness — the type change propagated into a caller file not listed in the plan. No scope creep.

## Issues Encountered
- The analyze command exits with code 1 due to pre-existing `public_member_api_docs` info-level warnings across public members in the platform interface and desktop_updater.dart files. These are pre-existing and not caused by this plan's changes — they will be addressed in the API documentation plan.

## Next Phase Readiness
- getCurrentVersion() contract is now `Future<int>` throughout — Phase 3 engine can call and compare directly without parsing
- All 5 files updated and tests passing
- No blockers for dependent phases

---
*Phase: 01-foundation*
*Completed: 2026-03-26*
