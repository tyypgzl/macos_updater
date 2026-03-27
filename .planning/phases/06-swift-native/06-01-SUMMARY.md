---
phase: 06-swift-native
plan: 01
subsystem: native
tags: [swift, macos, method-channel, async, sandbox, app-restart]

# Dependency graph
requires:
  - phase: 04-public-api
    provides: restartApp() Dart method channel call (invokeMethod<void>) and getCurrentVersion() invokeMethod<int>
provides:
  - Rewritten DesktopUpdaterPlugin.swift with correct restart sequence (copy → launch → terminate)
  - App Sandbox detection returning FlutterError(SANDBOX_INCOMPATIBLE) instead of silent failure
  - Task{} async bridging for restartApp in handle(_:result:)
  - GCD background queue dispatch for all file operations
  - getCurrentVersion() returning Int (not String) to match Dart invokeMethod<int>
  - Package.swift with .macOS("10.15") deployment target
affects: [07-cli-tools]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DispatchQueue.global(qos: .userInitiated) + DispatchQueue.main.async for file ops in Flutter method channel handlers"
    - "Task { [weak self] in } bridging for sync handle(_:result:) to non-blocking call"
    - "APP_SANDBOX_CONTAINER_ID environment check as sandbox detection guard"

key-files:
  created: []
  modified:
    - macos/desktop_updater/Sources/desktop_updater/DesktopUpdaterPlugin.swift
    - macos/desktop_updater/Package.swift

key-decisions:
  - "terminate(nil) called last — after copyAndReplaceFiles() and process.run() succeed — fixes race condition that caused unreliable restarts"
  - "Task{} used in handle(_:result:) for restartApp even though restartApp() itself is synchronous — bridges sync handler into non-blocking call per STACK.md"
  - "Removed getPlatformVersion, getExecutablePath, and sayHello cases from handle() — only restartApp and getCurrentVersion remain, matching v2 Dart platform interface"
  - "result(nil) called before NSApplication.shared.terminate(nil) — Dart receives success signal before app terminates"

patterns-established:
  - "FlutterResult error propagation pattern: result(FlutterError(code:message:details:)) instead of print() for all error paths"
  - "Sandbox guard at method entry — check APP_SANDBOX_CONTAINER_ID before any file I/O"

requirements-completed: [NAT-01, NAT-02, NAT-03, NAT-04]

# Metrics
duration: 3min
completed: 2026-03-26
---

# Phase 6 Plan 1: Swift Native Rewrite Summary

**Swift macOS plugin rewritten with correct copy-then-launch-then-terminate restart sequence, App Sandbox guard, Task{} bridging, and Package.swift bumped to macOS 10.15**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-26T16:27:00Z
- **Completed:** 2026-03-26T16:30:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Fixed critical terminate() race condition — NSApplication.shared.terminate(nil) now fires AFTER copyAndReplaceFiles() and process.run() complete (was firing first, making restart unreliable)
- Added App Sandbox detection at entry of restartApp() — returns FlutterError(SANDBOX_INCOMPATIBLE) with actionable message instead of silently failing
- Modernized method channel handler with Task{} bridging and GCD background queue for file operations
- getCurrentVersion() now returns Int? via Int(version) cast — matches Dart invokeMethod<int> expectation
- Removed all print() calls — all error paths propagate via FlutterResult
- Removed unused method cases (getExecutablePath, getPlatformVersion, sayHello)
- Bumped Package.swift deployment target from macOS 10.14 to 10.15

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite DesktopUpdaterPlugin.swift** - `f96d7ca` (feat)
2. **Task 2: Bump Package.swift deployment target to macOS 10.15** - `3f50ee1` (chore)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `macos/desktop_updater/Sources/desktop_updater/DesktopUpdaterPlugin.swift` - Fully rewritten: sandbox guard, GCD background queue, correct terminate ordering, Task{} bridging, Int return for getCurrentVersion, FlutterResult error propagation
- `macos/desktop_updater/Package.swift` - Platforms array changed from .macOS("10.14") to .macOS("10.15")

## Decisions Made

- terminate(nil) called last after result(nil) — Dart receives success signal before app process exits, avoiding lost message
- Task { [weak self] in } used in handle() for restartApp even though the method itself is synchronous — this is the correct pattern per STACK.md research to prevent blocking the main thread during file I/O dispatch
- Removed getPlatformVersion, getExecutablePath from handle() switch — they are no longer part of the v2 platform interface (verified against desktop_updater_method_channel.dart)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 6 complete. macOS native plugin is trustworthy for v2.0.0 release.
- Phase 7 (CLI tools) can proceed — Package.swift is on 10.15, Swift code is clean.
- Consumers using a sandboxed macOS app will receive a clear FlutterError explaining the incompatibility rather than a silent no-op.

---
*Phase: 06-swift-native*
*Completed: 2026-03-26*

## Self-Check: PASSED

- FOUND: macos/desktop_updater/Sources/desktop_updater/DesktopUpdaterPlugin.swift
- FOUND: macos/desktop_updater/Package.swift
- FOUND: .planning/phases/06-swift-native/06-01-SUMMARY.md
- FOUND commit f96d7ca (Task 1: rewrite DesktopUpdaterPlugin.swift)
- FOUND commit 3f50ee1 (Task 2: bump Package.swift deployment target)
