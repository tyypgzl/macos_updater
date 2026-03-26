# Project Research Summary

**Project:** flutter_desktop_updater v2.0.0
**Domain:** Flutter macOS desktop plugin — headless OTA update engine with abstract data sources
**Researched:** 2026-03-26
**Confidence:** HIGH

## Executive Summary

`flutter_desktop_updater` v2.0.0 is a refactor of an existing pub.dev plugin from a bundled-UI, hardcoded-URL update tool into a headless, backend-agnostic OTA engine. The established expert pattern for this domain — validated against Tauri, Sparkle, Electron, and `auto_updater` — is a strict separation of concerns: the engine owns file diffing, downloading, and native restart mechanics, while the consumer owns update metadata retrieval via an injected `UpdateSource` abstract interface. The v2 architecture directly implements this pattern, replacing v1's hardcoded JSON URL with a consumer-defined `abstract interface class UpdateSource`. The entire UI layer (`UpdateDialog`, `UpdateSliver`, `DesktopUpdaterController`) is removed. This is not a regression — it is the primary differentiator.

The recommended technical approach is: Dart 3.7+ with `sealed class` hierarchies for typed errors and a `Stream<UpdateState>` lifecycle, a function-based public API (`check()`, `download()`, `apply()`), Blake2b delta diffing via `cryptography_plus ^3.0.0`, and a Swift 5.9 native layer using `Task {}` bridging and GCD for background file operations. Freezed and code-generation dependencies are explicitly rejected — v2 has 3-5 lean model classes that should be handwritten. The plugin should use `http ^1.6.0` only for the internal file download step; all metadata fetching moves to the consumer's `UpdateSource` implementation.

The most critical risk is macOS code signature invalidation: replacing individual files inside a signed `.app` bundle at runtime invalidates the `_CodeSignature/CodeResources` manifest, causing Gatekeeper to block the next launch on notarized builds. This is the confirmed root cause of the 1.2.0 macOS reversion. The second most dangerous pitfall is the `NSApplication.terminate()` race condition in the existing Swift restart implementation — file copy and process relaunch code placed after `terminate()` is unreliable. Both must be resolved in the native code phase before v2.0.0 ships. The mitigation for signing is to document the non-notarized constraint explicitly and add a runtime sandbox detection guard; the mitigation for the race condition is to sequence all file operations and process relaunch *before* calling `terminate()`.

---

## Key Findings

### Recommended Stack

The stack is a tightly versioned set of official and well-maintained packages. Dart SDK floor is `^3.7.0` (not lower — wildcard variables and modern formatter require 3.7; Dart 3.0 is insufficient) paired with Flutter `>=3.29.0`. The macOS native layer uses Swift 5.9 via SwiftPM `swift-tools-version: 5.9` with a `macOS("10.15")` deployment target (10.14 Mojave is EOL and incompatible with Swift async/await). All versions have been verified against pub.dev and official docs as of 2026-03-26.

**Core technologies:**
- Dart `^3.7.0` + Flutter `>=3.29.0` — runtime; enables sealed classes, pattern matching, wildcard variables
- `plugin_platform_interface ^2.1.8` — platform abstraction base; required for `DesktopUpdaterPlatform`
- `cryptography_plus ^3.0.0` + `cryptography_flutter_plus ^3.0.0` — Blake2b hashing for delta diffing; only pure-Dart Blake2b; always upgrade together
- `http ^1.6.0` — internal file download only; do not replace with `dio` (transitive dep burden)
- `archive ^4.0.9` — decompressing update `.zip` bundles
- `path ^1.9.1` — safe macOS bundle path construction
- Swift 5.9 via SwiftPM — macOS method channel; `Task {}` bridging for async/await internals
- `flutter_lints ^6.0.0` — linting; bump from v1's 5.0.0

**Key language decisions:**
- `abstract interface class UpdateSource` — pure contract, no default implementations, cannot be extended
- `sealed class UpdateError` with typed subclasses — exhaustive `switch` at consumer call sites; design the full set before v2.0.0 tag (adding subtypes later is a breaking change)
- `sealed class Result<T>` for operation returns — official Flutter pattern from docs.flutter.dev
- No `freezed` — adds build_runner to consumer build steps; unjustified for 3-5 lean models

### Expected Features

The feature set draws a sharp line between what belongs in v2.0.0 and what should be deferred. The v2 MVP replaces every hardcoded-URL and bundled-UI aspect of v1 with clean abstractions.

**Must have (table stakes for v2.0.0):**
- `UpdateSource` abstract interface — core abstraction; without it v2 is identical to v1
- `checkForUpdate(UpdateSource) → Future<UpdateInfo?>` — function-based; replaces monolithic auto-start
- `downloadUpdate(UpdateInfo, {onProgress}) → Future<void>` — streaming progress via callback/stream
- `applyUpdate() → Future<void>` — native restart via method channel
- `getCurrentVersion() → Future<String>` — exposed cleanly on platform interface
- Sealed `UpdateError` with `NetworkError`, `HashMismatch`, `NoPlatformEntry`, `IncompatibleVersion`, `RestartFailed`
- `UpdateProgress` model — `totalBytes`, `receivedBytes`, `currentFile`, `completedFiles`, `totalFiles`
- CLI `dart run desktop_updater:release macos` — one-command build + `hashes.json` generation
- CLI `dart run desktop_updater:archive macos` — hash-only, for upload verification
- Remove all UI exports (`UpdateDialog`, `UpdateSliver`, `UpdateDirectCard`, `DesktopUpdaterController`, `InheritedWidget`)

**Should have (differentiators already designed in):**
- `abstract interface class UpdateSource` separating metadata retrieval from file download — no other Flutter desktop updater does this
- Blake2b client-side delta diffing — zero server infrastructure required beyond static file hosting
- `sealed class UpdateState` stream for lifecycle — replaces boolean flag soup in v1 controller
- `Stream<UpdateState>` broadcast stream — consumer maps to their own state management

**Defer (v2.x and beyond):**
- `isMandatory` field on `UpdateInfo` — add when consumers report enforcement need
- Parallel download toggle — add when download speed is a reported complaint
- EdDSA signature verification of `hashes.json` — requires consumer key management; v3+
- Windows/Linux active support — community-maintained until a maintainer adds CI
- Rollback support — requires previous-bundle storage; out of scope

### Architecture Approach

The architecture follows the inversion-of-control / repository pattern, with the engine holding a reference typed to the `UpdateSource` abstraction and the consumer injecting the concrete implementation at construction. The component graph is strict: public API layer (`DesktopUpdater`) → core engine (`VersionChecker`, `FileHasher`, `FileDownloader`) → abstract `UpdateSource` (consumer-owned) and `PlatformInterface` → native Swift. No layer reaches upward. The plugin imports zero framework-layer packages (`get_it`, `riverpod`, `bloc`, `freezed`) — it is a pure engine.

**Major components:**
1. `abstract interface class UpdateSource` — consumer contract; defines `getLatestUpdateInfo()` and `getRemoteFileHashes()`; the single boundary between plugin and consumer
2. `DesktopUpdater` — public API orchestrator; wires `UpdateSource`, engine functions, platform calls; emits `Stream<UpdateState>`
3. `UpdateEngine` (`VersionChecker`, `FileHasher`, `FileDownloader`) — three narrowly scoped stateless functions; independently unit-testable with mocked inputs
4. `DesktopUpdaterPlatform` + `MethodChannelImpl` — abstract + concrete method channel; exposes `getCurrentVersion()`, `getExecutablePath()`, `restartApp()`
5. Swift native (`DesktopUpdaterPlugin.swift`) — `CFBundleVersion`, file replacement, process restart; main-thread-safe via GCD
6. CLI tools (`bin/release.dart`, `bin/archive.dart`) — developer tools outside `lib/`; produce `hashes.json` consumed by engine at runtime

**Recommended file structure:**
```
lib/
├── desktop_updater.dart                    # barrel export
├── src/
│   ├── update_source.dart                  # abstract interface class
│   ├── models/                             # UpdateInfo, FileHash, UpdateProgress, UpdateResult
│   ├── engine/                             # version_checker, file_hasher, file_downloader
│   ├── updater.dart                        # orchestrator
│   └── errors.dart                         # sealed UpdaterError hierarchy
├── desktop_updater_platform_interface.dart
└── desktop_updater_method_channel.dart
bin/
├── release.dart
└── archive.dart
```

### Critical Pitfalls

1. **macOS code signature invalidation** — Replacing files inside a signed `.app` bundle invalidates `_CodeSignature/CodeResources`; Gatekeeper blocks next launch on notarized builds. Prevention: document the non-notarized constraint; stage files outside the bundle; add a runtime sandbox/entitlement detection guard; consider full-bundle atomic replacement (like Sparkle) for notarized builds. This is confirmed as the root cause of the 1.2.0 regression.

2. **`NSApplication.terminate()` race condition** — Code after `terminate()` executes in an indeterminate state as the Cocoa run loop unwinds. File copy and `Process.run()` placed after `terminate()` fail intermittently. Prevention: perform all file operations and launch the relaunch process *before* calling `terminate()`.

3. **App Sandbox blocks writes to `Contents/`** — Sandboxed apps cannot write to their own bundle. The current staging logic silently fails under App Sandbox. Prevention: add `ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]` detection; surface `UpdateError.sandboxIncompatible`; document that App Sandbox is incompatible with v2's in-bundle update mechanism.

4. **Sealed class addition is a breaking change** — Adding a new subtype to any `sealed` class in a minor/patch release breaks all consumer `switch` statements at compile time. Prevention: enumerate all error/state subtypes exhaustively before the v2.0.0 tag; treat the sealed surface as a locked public API.

5. **`copyWith` bug in existing models** — `ItemModel.copyWith` in `app_archive.dart` line 98 uses `changedFiles: changedFiles ?? changedFiles` (parameter shadows itself, never reads `this.changedFiles`). This silently drops the changed files list. Prevention: fix the bug; add a unit test asserting `model.copyWith()` equals the original on all fields for every new model.

**Additional notable pitfalls:**
- Integer version comparison fragility (`int.parse` on `CFBundleVersion` throws on semantic version strings) — wrap with typed `FormatException` handling
- `UpdateSource` async contract mismatch — catch all source exceptions and map to typed `UpdaterError`; do not let `FirebaseException` leak through
- UI removal without a migration guide causes immediate compile failures for all consumers — write the migration guide first, before touching any barrel file

---

## Implications for Roadmap

The research establishes clear phase dependencies: models must precede engine; engine must precede orchestrator; UI removal and migration guide must happen together; native Swift fixes are independent but must complete before v2.0.0 ships.

### Phase 1: Foundation — Data Models, Errors, Platform Interface

**Rationale:** Models define the types every other component depends on. Zero risk of circular imports. Engine functions cannot be written without the types they accept and return. This is the no-dependency base layer.
**Delivers:** `src/models/` (UpdateInfo, FileHash, UpdateProgress, UpdateResult), `src/errors.dart` (sealed UpdaterError hierarchy with all subtypes locked), `DesktopUpdaterPlatform` abstract + `MethodChannelImpl`
**Addresses:** Abstract typed model (table stakes), sealed `UpdateError` (table stakes), `getCurrentVersion()` platform interface
**Avoids:** copyWith bug (write unit tests for every new model's `copyWith()` immediately); sealed class breaking change (finalize all subtypes in this phase before anything else references them)
**Research flag:** Standard patterns — well-documented Dart 3 sealed class and `plugin_platform_interface` patterns; skip research-phase

### Phase 2: Abstract UpdateSource Contract

**Rationale:** `UpdateSource` depends on models (its method signatures reference `UpdateInfo` and `FileHash`), so it must follow Phase 1. It is the central abstraction of v2 — defined before the engine that consumes it to ensure the contract is designed from the consumer's perspective, not retrofitted from the engine's needs.
**Delivers:** `src/update_source.dart` — `abstract interface class UpdateSource` with `getLatestUpdateInfo()` and `getRemoteFileHashes()`; error propagation contract documented; `MockUpdateSource` for tests
**Addresses:** Pluggable UpdateSource (primary differentiator); backend flexibility
**Avoids:** UpdateSource async contract mismatch (define error semantics in this phase; all exceptions from source methods caught and mapped to UpdaterError)
**Research flag:** Standard patterns — `abstract interface class` is well-documented in Dart language spec; skip research-phase

### Phase 3: Core Engine Refactoring

**Rationale:** Engine functions depend on models (Phase 1) and the UpdateSource contract (Phase 2). Splitting the current monolithic `versionCheckFunction()` into three testable units (`VersionChecker`, `FileHasher`, `FileDownloader`) is the structural heart of the v2 refactor.
**Delivers:** `src/engine/version_checker.dart`, `src/engine/file_hasher.dart`, `src/engine/file_downloader.dart`; each independently unit-testable with mocked inputs; `PlatformPathResolver` utility replacing all inline `dir.parent.parent` calls; streaming download progress; post-download hash re-verification
**Addresses:** Delta download (table stakes), streaming progress (table stakes), `checkForUpdate()` function-based API (differentiator)
**Avoids:** Scattered path logic (single `PlatformPathResolver`); missing post-download verification; `http.Client` per request (share one client across downloads); temp directory accumulation (cleanup in `finally` blocks); version comparison fragility (typed `FormatException` handling)
**Research flag:** Standard patterns — known algorithms and Dart patterns; skip research-phase

### Phase 4: Orchestrator and Public API

**Rationale:** `DesktopUpdater` wires all components — it depends on everything above. The public barrel file is a thin re-export layer on top. Delaying the orchestrator until all components exist prevents premature API surface decisions.
**Delivers:** `src/updater.dart` (orchestrates UpdateSource + engine + platform; emits `Stream<UpdateState>`); `lib/desktop_updater.dart` (barrel export); `sealed class UpdateState` hierarchy
**Addresses:** Function-based lifecycle API (differentiator); `Stream<UpdateState>` for consumer state management; `applyUpdate()`
**Avoids:** Stateful controller anti-pattern (no ChangeNotifier; sealed state stream only); mixed concerns in version check
**Research flag:** Standard patterns — sealed state machine and broadcast stream patterns are well-documented; skip research-phase

### Phase 5: UI Removal and Consumer Migration

**Rationale:** UI removal is a self-contained deletion operation, but it produces the most consumer-visible breaking change in v2. It must be paired with a complete migration guide before any code is touched. Ordering after the public API is established (Phase 4) means the migration guide can reference the actual new API.
**Delivers:** Removal of `update_dialog.dart`, `update_direct_card.dart`, `update_sliver.dart`, `desktop_updater_inherited_widget.dart`, `desktop_updater_controller.dart`; updated barrel file with no widget exports; `@Deprecated` shims for one minor version if feasible; CHANGELOG migration section with consumer-side replacement code for every removed symbol; updated README with v2 usage example
**Addresses:** Pure engine differentiator (removal = value); no forced `InheritedWidget` coupling
**Avoids:** UI removal breaks consumers without migration path (write guide first, before touching code)
**Research flag:** No research needed — this is purely deletion and documentation

### Phase 6: Swift Native Code Modernization

**Rationale:** The two critical macOS-specific pitfalls (terminate race condition and code signature invalidation) live entirely in `DesktopUpdaterPlugin.swift`. This phase is independent of Dart refactoring and can overlap with Phases 3-4, but must complete before v2.0.0 ships.
**Delivers:** Fixed restart sequence (file ops and relaunch before `terminate()`); sandbox detection guard surfacing `UpdateError.sandboxIncompatible`; `macOS("10.15")` deployment target in Package.swift; GCD background queue for file operations; code signing constraint documented in README and code comments
**Addresses:** `applyUpdate()` reliability (table stakes); `getCurrentVersion()` via method channel
**Avoids:** `terminate()` race condition; App Sandbox silent failure; macOS 10.14 deployment target (EOL, no Swift async)
**Research flag:** Needs careful verification — code signing behavior under Gatekeeper and the `applicationWillTerminate` sequencing model are complex and platform-version-sensitive; recommend testing on a clean macOS 13+ VM with `codesign --verify --deep --strict` validation in the acceptance criteria

### Phase 7: CLI Tools Simplification

**Rationale:** `bin/release.dart` and `bin/archive.dart` are independent of the runtime library and can be simplified last. macOS-only simplification removes Windows/Linux code paths that are untested and unmaintained.
**Delivers:** macOS-only `dart run desktop_updater:release macos` and `dart run desktop_updater:archive macos`; validated `hashes.json` output format compatibility with engine's delta comparison; updated `args ^2.7.0` and `pubspec_parse ^1.5.0`
**Addresses:** CLI release tool (table stakes for CI/CD); file hash generation
**Avoids:** CLI output format change breaking runtime delta comparison (validate format compatibility explicitly)
**Research flag:** Standard patterns — `args` and `pubspec_parse` are official dart.dev packages with stable APIs; skip research-phase

### Phase Ordering Rationale

- Phases 1-2 establish the type vocabulary before any logic is written — prevents rework cascading through engine and orchestrator
- Phase 3 (engine) can begin as soon as Phase 2 is complete; engine functions are stateless and testable in isolation
- Phase 4 (orchestrator) is a pure assembly step — fast once Phases 1-3 are done
- Phase 5 (UI removal) is ordered after Phase 4 so the migration guide can reference real, final API
- Phase 6 (Swift) is independent and can run in parallel with Phases 3-4; it is listed sixth because it requires macOS hardware testing
- Phase 7 (CLI) is genuinely independent throughout and can be done any time after Phase 1 models are stable

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 6 (Swift native):** Code signing + Gatekeeper behavior under macOS 13/14/15, `applicationWillTerminate` sequencing, and the `codesign --force` implications of in-place bundle modification are complex and not fully resolved by existing research. Validate with `codesign --verify --deep --strict` on a notarized build before finalizing the approach.

Phases with standard patterns (skip research-phase):
- **Phase 1:** Dart sealed classes, `plugin_platform_interface` — extensively documented
- **Phase 2:** `abstract interface class` — dart.dev language spec
- **Phase 3:** Blake2b via `cryptography_plus`, `http` streaming — stable packages with clear APIs
- **Phase 4:** Sealed state machine, broadcast stream — Flutter official patterns
- **Phase 5:** Deletion and documentation — no research needed
- **Phase 7:** `args`, `pubspec_parse` — official dart.dev packages

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All package versions verified against pub.dev as of 2026-03-26; language feature decisions verified against dart.dev spec and Flutter official docs |
| Features | HIGH | Based on direct codebase analysis plus Tauri, Sparkle, and `auto_updater` competitor analysis; MVP scope is conservative and well-bounded |
| Architecture | HIGH | Patterns (abstract data source, sealed state machine, function-based API) are directly from Flutter official app architecture documentation; component boundaries are clear |
| Pitfalls | HIGH | Critical pitfalls (code signing, terminate race, sandbox) confirmed against Apple documentation and the existing CONCERNS.md which documents the 1.2.0 regression |

**Overall confidence:** HIGH

### Gaps to Address

- **Code signing strategy for notarized builds:** Research confirms the problem but does not prescribe whether v2 should: (a) document non-notarized as a hard requirement, (b) implement full-bundle atomic replacement (like Sparkle), or (c) add a runtime warning only. This decision requires a product/policy call before Phase 6 planning. Recommendation: option (a) for v2.0.0, with option (b) as a documented future path.

- **`hashes.json` format stability:** The CLI tools produce `hashes.json` which the engine consumes at runtime. Any format change in Phase 7 breaks all existing consumer CDN deployments. The format must be explicitly versioned or frozen before Phase 7. Address during Phase 7 planning.

- **Windows/Linux native stubs:** Research is macOS-only. Existing Windows (C++) and Linux (C) native stubs will remain as-is. No regression testing is planned for these platforms in v2. Document as "community-maintained" in README. If a contributor surfaces a Windows/Linux regression during v2 development, it is out of scope.

- **`cryptography_plus 3.0.0` major version:** The package's new maintainer published 3.0.0 23 days before research. API breaking changes from 2.x have not been fully audited. Verify no API changes affect `Blake2b` usage in `file_hasher.dart` before Phase 3 begins.

---

## Sources

### Primary (HIGH confidence)
- [pub.dev verified packages](https://pub.dev) — all dependency versions (http 1.6.0, archive 4.0.9, cryptography_plus 3.0.0, plugin_platform_interface 2.1.8, flutter_lints 6.0.0, path 1.9.1, args 2.7.0, pubspec_parse 1.5.0)
- [dart.dev/language/class-modifiers](https://dart.dev/language/class-modifiers) — `abstract interface class` vs `sealed` vs `abstract class` guidance
- [docs.flutter.dev/app-architecture/design-patterns/result](https://docs.flutter.dev/app-architecture/design-patterns/result) — official sealed `Result<T>` pattern
- [docs.flutter.dev/platform-integration/platform-channels](https://docs.flutter.dev/platform-integration/platform-channels) — method channel threading; GCD for macOS background work; Task Queue API is iOS-only
- [docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors) — SwiftPM structure and deployment targets
- [dart.dev/resources/whats-new](https://dart.dev/resources/whats-new) — Dart 3.7 feature list
- [Apple TN2206: macOS Code Signing In Depth](https://developer.apple.com/library/archive/technotes/tn2206/_index.html) — code signature invalidation mechanics
- [Apple Security: Gatekeeper and runtime protection](https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web) — notarization and runtime enforcement
- Codebase inspection: `lib/src/app_archive.dart` line 98 (copyWith bug), `macos/.../DesktopUpdaterPlugin.swift` (terminate race), `.planning/codebase/CONCERNS.md` (1.2.0 regression)

### Secondary (MEDIUM confidence)
- [Tauri Updater Plugin docs](https://v2.tauri.app/plugin/updater/) — lifecycle stage pattern reference
- [Sparkle framework documentation](https://sparkle-project.org/documentation/) — macOS updater reference; delta updates, restart sequencing
- [auto_updater pub.dev](https://pub.dev/packages/auto_updater) — competitor feature surface
- [Peter Steinberger: Code Signing and Notarization — Sparkle and Tears (2025)](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears) — practical code signing implications
- [github.com/flutter/flutter/issues/123867](https://github.com/flutter/flutter/issues/123867) — Pigeon async/await for Swift: unresolved as of 2026-03

### Tertiary (LOW confidence)
- [kmp-app-updater state machine](https://github.com/pavi2410/kmp-app-updater) — Idle/Checking/Downloading/ReadyToInstall pattern reference only

---

*Research completed: 2026-03-26*
*Ready for roadmap: yes*
