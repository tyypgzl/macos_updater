# Roadmap: Desktop Updater v2.0.0

## Overview

Refactor `desktop_updater` from a bundled-UI, hardcoded-URL update tool into a headless, backend-agnostic OTA engine for macOS Flutter apps. The journey: establish the type vocabulary (models, errors, platform interface), define the UpdateSource abstraction, build the engine functions, wire them into a clean public API, strip all UI code, fix critical Swift native bugs, and simplify CLI tooling. Every phase delivers a complete, verifiable capability. Phases 1-4 are sequentially dependent. Phases 5, 6, and 7 are independent and can run in any order after Phase 4 completes.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Data models, sealed errors, and platform interface that everything else depends on (completed 2026-03-26)
- [x] **Phase 2: UpdateSource Contract** - Abstract interface class that decouples engine from backend (completed 2026-03-26)
- [x] **Phase 3: Core Engine** - Delta diffing, file download, and progress stream internals (completed 2026-03-26)
- [x] **Phase 4: Public API** - Orchestrator wiring engine into clean function-based API (completed 2026-03-27)
- [ ] **Phase 5: UI Removal** - Delete all widget code and produce consumer migration guide
- [ ] **Phase 6: Swift Native** - Fix terminate race condition, add sandbox guard, modernize async
- [ ] **Phase 7: CLI & Dependencies** - Simplify tools to macOS-only and bump all dependency versions

## Phase Details

### Phase 1: Foundation
**Goal**: The type vocabulary for the entire v2 codebase exists and is locked
**Depends on**: Nothing (first phase)
**Requirements**: MODEL-01, MODEL-02, MODEL-03, MODEL-04, MODEL-05, API-06
**Success Criteria** (what must be TRUE):
  1. A consumer can import `UpdateInfo`, `FileHash`, `UpdateProgress`, `UpdateError`, and `UpdateCheckResult` from the package with no other imports
  2. `UpdateError` is a sealed class — an exhaustive switch on it compiles without a default case and covers all subtypes: NetworkError, HashMismatch, NoPlatformEntry, IncompatibleVersion, RestartFailed
  3. `UpdateCheckResult` is a sealed class with `UpToDate` and `UpdateAvailable(UpdateInfo)` variants that pattern-match exhaustively
  4. `getCurrentVersion()` is callable via the platform interface and returns the app's build number string on macOS
  5. Every new model has a `copyWith()` unit test asserting round-trip equality on all fields
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Leaf type definitions: FileHash (MODEL-02), UpdateProgress (MODEL-03), UpdateError sealed hierarchy (MODEL-04)
- [x] 01-02-PLAN.md — Dependent types and barrel: UpdateInfo (MODEL-01), UpdateCheckResult (MODEL-05), barrel export update, copyWith unit tests
- [x] 01-03-PLAN.md — Platform interface: getCurrentVersion() return type change to Future<int> on interface, method channel, and test mock (API-06)

**UI hint**: no

### Phase 2: UpdateSource Contract
**Goal**: The abstract boundary between engine and consumer backends is defined and documented
**Depends on**: Phase 1
**Requirements**: API-01, API-02
**Success Criteria** (what must be TRUE):
  1. A consumer can implement `UpdateSource` by writing two async methods — `getLatestUpdateInfo()` and `getRemoteFileHashes(String remoteBaseUrl)` — with no other boilerplate
  2. A `MockUpdateSource` implementation exists in tests that returns controlled `UpdateInfo` and `List<FileHash>` values
  3. Any exception thrown by a consumer's `UpdateSource` implementation is caught by the engine and mapped to a typed `UpdateError` — no raw exceptions escape the boundary
**Plans**: 1 plan

Plans:
- [x] 02-01-PLAN.md — UpdateSource interface (API-01, API-02), barrel export, MockUpdateSource test double, error boundary contract tests

### Phase 3: Core Engine
**Goal**: Delta diffing, file downloading, and progress streaming work correctly in isolation
**Depends on**: Phase 2
**Requirements**: ENG-01, ENG-02, ENG-03
**Success Criteria** (what must be TRUE):
  1. Given a list of local file hashes and remote file hashes, the engine identifies exactly the changed files (by Blake2b comparison) with no false positives or negatives
  2. A changed file downloads from a remote URL to a local staging path with streaming progress events emitted for each chunk received
  3. A `Stream<UpdateProgress>` emits `completedFiles`, `totalFiles`, `currentFile`, `receivedBytes`, and `totalBytes` throughout a download — a consumer can display a progress indicator from this stream alone
  4. Local file hashes for the running app bundle are computed via `generateLocalFileHashes()` without error on macOS
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md — File hasher: generateLocalFileHashes() and diffFileHashes() in lib/src/engine/file_hasher.dart (ENG-01)
- [x] 03-02-PLAN.md — File downloader and progress stream: downloadFiles() returning Stream<UpdateProgress> in lib/src/engine/file_downloader.dart (ENG-02, ENG-03)

### Phase 4: Public API
**Goal**: Consumers can check for updates, download them, and trigger restart using four clean functions
**Depends on**: Phase 3
**Requirements**: API-03, API-04, API-05, API-07
**Success Criteria** (what must be TRUE):
  1. A consumer calls `checkForUpdate(source)` and receives either `UpdateCheckResult.upToDate` or `UpdateCheckResult.updateAvailable(info)` — no internal types leak into the return value
  2. A consumer calls `downloadUpdate(info, onProgress: callback)` and the callback receives progress events while only changed files are downloaded
  3. A consumer calls `applyUpdate()` and the app restarts on macOS — the function throws `UpdateError.restartFailed` on failure rather than an untyped exception
  4. `generateLocalFileHashes()` is callable from the public API and returns the bundle's file hashes as `List<FileHash>`
  5. The public barrel `desktop_updater.dart` exports exactly the engine API symbols — no widget or controller classes appear in the export
**Plans**: 1 plan

Plans:
- [x] 04-01-PLAN.md — API orchestration layer: checkForUpdate, downloadUpdate, applyUpdate, generateLocalFileHashes functions + barrel export (API-03, API-04, API-05, API-07)

### Phase 5: UI Removal
**Goal**: All widget, controller, and localization code is deleted and consumers have a clear migration path
**Depends on**: Phase 4
**Requirements**: REM-01, REM-02, REM-03, REM-04, REM-05
**Success Criteria** (what must be TRUE):
  1. The package contains zero widget files — `update_card.dart`, `update_dialog.dart`, `update_widget.dart`, `update_sliver.dart`, `update_direct_card.dart` are gone
  2. `DesktopUpdaterController` and `DesktopUpdateInheritedWidget` are gone — no stateful controller abstraction remains in the package
  3. `DesktopUpdateLocalization` is gone — the package has no localizable strings
  4. The public barrel exports only engine API symbols — importing the package produces no widget-related identifiers
  5. CHANGELOG contains a migration section that shows a consumer exactly what to replace for each removed symbol, referencing the new function-based API
**Plans**: 2 plans

Plans:
- [x] 05-01-PLAN.md — Delete all v1/widget files, rewrite barrel to v2-only exports, update example app (REM-01, REM-02, REM-03, REM-04, REM-05)
- [ ] 05-02-PLAN.md — Write CHANGELOG v2.0.0 migration section with before/after examples for each removed symbol (REM-05)

### Phase 6: Swift Native
**Goal**: The macOS restart sequence is reliable and the sandbox incompatibility is surfaced clearly
**Depends on**: Phase 1
**Requirements**: NAT-01, NAT-02, NAT-03, NAT-04
**Success Criteria** (what must be TRUE):
  1. `applyUpdate()` reliably restarts the app on macOS — file copy and process relaunch complete before `NSApplication.terminate()` is called
  2. Running the app inside App Sandbox causes `applyUpdate()` to return `UpdateError.noPlatformEntry` (or a sandbox-specific error) with a message explaining the incompatibility — it does not silently fail
  3. The macOS deployment target in Package.swift is `macOS("10.15")` — the plugin does not target Mojave
  4. The method channel handler uses `Task {}` bridging for async operations and dispatches file operations on a GCD background queue
**Plans**: TBD

### Phase 7: CLI & Dependencies
**Goal**: CLI tools are macOS-only and all dependencies are at latest compatible versions
**Depends on**: Phase 1
**Requirements**: CLI-01, CLI-02, CLI-03, CLI-04, CLI-05, CLI-06
**Success Criteria** (what must be TRUE):
  1. `dart run desktop_updater:release macos` builds the macOS app and produces `hashes.json` — Windows/Linux code paths are removed from `release.dart`
  2. `dart run desktop_updater:archive macos` generates the archive and hash file for macOS — Windows/Linux code paths are removed from `archive.dart`
  3. `pubspec.yaml` SDK constraint is `sdk: ">=3.7.0 <4.0.0"` and `flutter: ">=3.29.0"` — the package requires Dart 3.7+
  4. `cryptography_plus` is at `^3.0.0`, `http`, `archive`, `flutter_lints`, and `plugin_platform_interface` are at their latest compatible versions, and any unused dependencies are removed

## Progress

**Execution Order:**
Phases 1 → 2 → 3 → 4 are sequential. Phases 5, 6, 7 are independent and can run after Phase 4 (or Phase 1 for Phase 6).

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete   | 2026-03-26 |
| 2. UpdateSource Contract | 1/1 | Complete   | 2026-03-26 |
| 3. Core Engine | 2/2 | Complete   | 2026-03-26 |
| 4. Public API | 1/1 | Complete   | 2026-03-27 |
| 5. UI Removal | 1/2 | In Progress|  |
| 6. Swift Native | 0/TBD | Not started | - |
| 7. CLI & Dependencies | 0/TBD | Not started | - |
