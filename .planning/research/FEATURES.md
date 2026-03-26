# Feature Research

**Domain:** Flutter macOS desktop OTA update engine (pure engine, no UI)
**Researched:** 2026-03-26
**Confidence:** HIGH (based on codebase analysis, Tauri updater, Sparkle framework, kmp-app-updater, and Flutter official docs)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features consumers of a headless update engine take for granted. Absence causes rejection or forking.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Abstract `UpdateSource` interface | Consumers connect any backend (Firebase Remote Config, REST, S3, local file). Hardcoded URL is a blocker for most integrations. | MEDIUM | Single abstract class with `checkForUpdate()` returning a typed result. Consumer owns HTTP logic. |
| Typed version model | Callers need to inspect version, build number, download URL, and file list without parsing raw JSON themselves. | LOW | `UpdateInfo` (or equivalent) sealed/final class. Fields: version string, build integer, remote base URL, list of changed files with hashes and sizes. |
| Delta (changed-files-only) download | Downloading the full app bundle on every update is a non-starter for large Flutter apps (~200 MB+). Only download what changed. | MEDIUM | Already implemented via Blake2b hash comparison. Keep and expose cleanly in v2. |
| Streaming download progress | Consumers must be able to show a progress indicator. A `Future<void>` without progress is unusable for UX. | MEDIUM | `Stream<UpdateProgress>` with bytes received, total bytes, current file name, completed/total file count. |
| Typed error surface | Generic `Exception` strings break consumer error handling and localization. Each error category needs its own type. | MEDIUM | Sealed class `UpdateError` with subtypes: `NetworkError`, `HashMismatch`, `IncompatibleVersion`, `NoPlatformEntry`, `RestartFailed`. |
| Restart / apply update API | Without a restart method, the engine is useless — files are staged but never activated. | LOW | `applyUpdate()` native method channel call. macOS-specific implementation already exists. |
| Current version retrieval | Consumers need the running version to compare against remote. Must work without them writing native code. | LOW | `getCurrentVersion()` → `String` (build number). Already implemented via method channel on macOS. |
| CLI release tool (`dart run desktop_updater:release macos`) | CI/CD pipelines require a reproducible one-command build + hash generation. Without it consumers write their own tooling and diverge. | MEDIUM | Generates `hashes.json` alongside the release artifact. macOS-only in v2. |
| File hash generation (`dart run desktop_updater:archive`) | Consumers need to pre-compute hashes before uploading to their CDN. | LOW | Standalone CLI that walks the `.app` bundle, writes `hashes.json`. Already exists; simplify for macOS only. |

---

### Differentiators (Competitive Advantage)

Features that distinguish this engine from `auto_updater` (Sparkle wrapper) and a bare HTTP download.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Pluggable `UpdateSource` abstract class | No other Flutter desktop updater separates "where is update metadata?" from "how to download files". Consumers implement one class to plug in Firebase Remote Config, a REST API, or a local JSON file. `auto_updater` hardcodes an appcast XML URL; `desktop_updater` v1 hardcodes a JSON URL. | MEDIUM | Interface with two async methods: `checkForUpdate() → UpdateInfo?` and optionally `resolveDownloadUrl(String path) → Uri`. Consumer owns all networking for metadata; engine owns file download. |
| Blake2b delta diffing built-in | Most updaters (Sparkle, Electron, Tauri) send full replacement bundles or require server-side delta generation tooling. This engine computes deltas client-side by comparing hashes at check time, with zero server infrastructure beyond static file hosting. | HIGH | Existing implementation. Keep and expose the hash comparison result as part of `UpdateInfo.changedFiles`. |
| Pure engine — no UI, no state management | `auto_updater` forces Sparkle's native UI. `desktop_updater` v1 bundles Flutter widgets and a ChangeNotifier controller. A pure engine with a functional API lets consumers build any UI (dialog, banner, system notification) without fighting the package. | LOW | Removing ~7 files (widgets, controller, inherited widget, localization). This is a removal differentiator — less code, more value. |
| Function-based API (not class-instance lifecycle) | Instance-based APIs (controller pattern) create hidden state ordering bugs (call `download` before `check` → undefined behavior). Function-based API with explicit inputs makes each operation composable and testable. | LOW | `checkForUpdate(source)`, `downloadUpdate(updateInfo, {onProgress})`, `applyUpdate()`. Each function is independently callable. |
| Sealed `UpdateResult` / `UpdateError` with exhaustive matching | Tauri uses typed errors in Rust but Flutter packages typically throw generic `Exception`. Sealed classes force callers to handle every error case at compile time using `switch` expressions (Dart 3.7+). | LOW | `sealed class UpdateError` with 5 subtypes. Consumer `switch` is exhaustive — compiler error if a case is missed. |
| No forced HTTP client dependency | v1 uses the `http` package for both metadata fetch (app-archive.json) and file downloads. v2 moves metadata fetch entirely to the consumer (via `UpdateSource`). Engine only uses HTTP for the actual file payload download, which is internal. Reduces version conflicts. | LOW | Consumers bring their own Dio, http, or Retrofit for metadata. Engine uses `http` internally for file streaming only. |

---

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Built-in UI widgets (dialog, banner, card, sliver) | Reduces integration effort for simple cases | Couples the engine to Flutter's widget lifecycle and Material Design. Every consumer's app looks identical. Impossible to animate, theme, or localize without fighting the package's internals. Creates a ChangeNotifier dependency that breaks non-widget callers (background services, CLI). v1 already proved this — the UI is the most common modification request. | Expose a clean `Stream<UpdateState>` (or functional callbacks) so consumers build exactly the UI they need. Ship a separate example app showing a reference implementation. |
| Auto-update without user consent | Convenient for "silent background updates" | macOS Gatekeeper and notarization rules require user-visible consent for replacing app binaries. Silent replacement can trigger security dialogs or fail on hardened runtime. It is also a security anti-pattern — a compromised CDN could silently push malicious code. | Provide a `checkForUpdate()` that returns a result, then require an explicit `downloadUpdate()` + `applyUpdate()` call sequence. Consumer decides when and how to prompt. |
| Windows/Linux native code active development | Cross-platform reach | macOS is the validated, supported target. Windows and Linux native method channel implementations exist but are untested in v2. Adding Windows/Linux CI, path resolution logic, and native code review multiplies maintenance cost without a validated use case. | Keep existing native stubs passively (don't delete), but document macOS as the only supported platform for v2. Mark Windows/Linux as "community-maintained". |
| Mandatory update enforcement (forced restart) | Some teams need all users on latest version | Forced restarts lose unsaved user work with no recovery. macOS does not allow an app to force-quit itself without user confirmation in all scenarios. Mandatory enforcement belongs in the consumer's UX layer, not the engine. | Return `UpdateInfo.isMandatory` as a boolean field for the consumer to act on. Engine never forces anything. |
| Built-in rollback / version history | Enterprise feature request | Rollback requires storing previous app bundle snapshots, which doubles storage requirements and adds a full reverse-delta pipeline. No Flutter desktop OTA package implements this. Out of scope for a pub.dev open-source package. | Document that consumers should maintain previous release artifacts on their CDN if rollback is needed. Engine is forward-only. |
| Signature verification of downloaded files | Security-conscious consumers ask for this | Blake2b hash comparison already verifies file integrity against the `hashes.json` manifest. Adding asymmetric signature verification (like Sparkle's EdDSA) requires consumers to manage private/public keys in their release pipeline — significant operational complexity for a pub.dev package. | Use hash-based integrity (already implemented). Document that HTTPS transport provides authenticity guarantees for static CDN hosting. Add a roadmap note for EdDSA as a future opt-in. |
| In-process file replacement (no restart) | Zero-downtime updates | macOS locks app bundle files while the process is running. In-process replacement is impossible for `.app` bundles without a helper launcher/shim process. The native restart + copy approach is the correct macOS pattern (used by Sparkle, Electron, Tauri). | Keep the current staged-files + restart model. |

---

## Feature Dependencies

```
[Abstract UpdateSource]
    └──required by──> [Version Check API]
                          └──required by──> [Delta File List (changedFiles)]
                                                └──required by──> [Download API]
                                                                       └──required by──> [Apply / Restart]

[Blake2b Hash Generation]
    └──required by──> [Delta File List (changedFiles)]

[Typed UpdateError (sealed)]
    └──enhances──> [Version Check API]
    └──enhances──> [Download API]
    └──enhances──> [Apply / Restart]

[Stream<UpdateProgress>]
    └──enhances──> [Download API]

[getCurrentVersion()]
    └──required by──> [Version Check API]  (compare local vs remote shortVersion)

[CLI release tool]
    └──produces──> [hashes.json]
                      └──consumed by──> [Delta File List (changedFiles)]
```

### Dependency Notes

- **Version Check requires UpdateSource:** The consumer provides `UpdateSource.checkForUpdate()` which returns `UpdateInfo?`. Without this abstraction, version checking is hardcoded to a URL.
- **Download requires changedFiles:** `downloadUpdate(updateInfo)` uses `updateInfo.changedFiles` (the delta). If `checkForUpdate` returned null (up-to-date), download must not be callable.
- **Apply requires download to complete:** `applyUpdate()` triggers native file move + restart. If called before download completes, the app restarts with partially-copied files.
- **CLI produces what engine consumes:** `dart run desktop_updater:release macos` generates `hashes.json` which is later fetched at runtime by the engine during version check. Breaking CLI output format breaks runtime delta comparison.
- **Typed errors enhance all stages:** Each lifecycle step (check, download, apply) should return or throw a typed `UpdateError` subtype rather than a generic `Exception`.

---

## MVP Definition

This is a v2.0.0 refactor of an existing pub.dev package. "MVP" here means the minimum API surface that makes v2 a clean replacement for v1.

### Launch With (v2.0.0)

- [x] `UpdateSource` abstract class with `checkForUpdate() → Future<UpdateInfo?>` — core abstraction that replaces hardcoded URL
- [x] `UpdateInfo` typed model — version, buildNumber, remoteBaseUrl, changedFiles list with hashes/sizes
- [x] `checkForUpdate(UpdateSource source) → Future<UpdateInfo?>` function — wraps hash comparison + version comparison
- [x] `downloadUpdate(UpdateInfo info, {void Function(UpdateProgress)? onProgress}) → Future<void>` function — streams progress to callback
- [x] `applyUpdate() → Future<void>` — native restart via method channel
- [x] `getCurrentVersion() → Future<String>` — exposed on platform interface
- [x] Sealed `UpdateError` with `NetworkError`, `HashMismatch`, `NoPlatformEntry`, `IncompatibleVersion`, `RestartFailed` subtypes
- [x] `UpdateProgress` model — totalBytes, receivedBytes, currentFile, completedFiles, totalFiles
- [x] CLI `dart run desktop_updater:release macos` — macOS-only, generates dist artifact + hashes.json
- [x] CLI `dart run desktop_updater:archive macos` — hashes only, for upload verification

### Add After Validation (v2.x)

- [ ] `isMandatory` field on `UpdateInfo` — when consumers report a need to enforce updates, add as a field the consumer acts on
- [ ] Parallel vs sequential download mode toggle — single option on `downloadUpdate`, add when download speed becomes a complaint
- [ ] `prepareUpdate(UpdateSource)` helper that only fetches and computes the delta without downloading — when consumers want to pre-check size before prompting

### Future Consideration (v3+)

- [ ] EdDSA signature verification of `hashes.json` — deferred; operational complexity requires key management docs
- [ ] Windows/Linux active support — only when a maintainer volunteers and adds CI coverage
- [ ] Rollback support — requires full previous-bundle storage; deferred indefinitely

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Abstract `UpdateSource` | HIGH | MEDIUM | P1 |
| `checkForUpdate()` function-based API | HIGH | LOW | P1 |
| `downloadUpdate()` with `Stream<UpdateProgress>` | HIGH | LOW (refactor existing) | P1 |
| `applyUpdate()` / restart | HIGH | LOW (exists, expose cleanly) | P1 |
| Typed `UpdateError` sealed class | HIGH | LOW | P1 |
| `UpdateInfo` typed model | HIGH | LOW | P1 |
| Remove UI/controller/localization code | HIGH (reduction) | LOW | P1 |
| CLI tools macOS-only simplification | MEDIUM | LOW | P1 |
| `getCurrentVersion()` exposed cleanly | MEDIUM | LOW (exists) | P1 |
| `isMandatory` field on `UpdateInfo` | MEDIUM | LOW | P2 |
| Parallel download toggle | LOW | LOW | P3 |
| EdDSA signature verification | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for v2.0.0 launch
- P2: Should have, add in v2.x when consumers request
- P3: Nice to have, defer to v3+

---

## Competitor Feature Analysis

| Feature | auto_updater (Sparkle/WinSparkle) | desktop_updater v1 | v2 Approach |
|---------|------------------------------------|--------------------|-------------|
| Update metadata source | Hardcoded appcast XML URL | Hardcoded JSON URL | Abstract `UpdateSource` — consumer implements |
| Delta updates | Server-side delta packages (generate_appcast) | Client-side Blake2b hash diff | Client-side Blake2b hash diff (keep) |
| UI | Native Sparkle UI (forced) | Flutter widgets (bundled) | None — pure engine, consumer owns UI |
| Error handling | Native exceptions (opaque) | Generic `Exception` strings | Sealed `UpdateError` subtypes |
| Progress tracking | Native Sparkle progress (opaque to Flutter) | `Stream<UpdateProgress>` | `Stream<UpdateProgress>` or callback |
| Restart / apply | Sparkle handles automatically | `restartApp()` method channel | `applyUpdate()` method channel |
| Version comparison | Integer shortVersion via appcast | Integer shortVersion via JSON | Integer buildNumber via `UpdateInfo` |
| Backend flexibility | Low (any appcast-compatible server) | Low (specific JSON schema + URL) | High (consumer implements `UpdateSource`) |
| Dart 3 / sealed classes | No | No | Yes — Dart 3.7+, sealed errors |
| CLI tooling | generate_appcast binary | `release` + `archive` dart scripts | `release` + `archive` dart scripts (macOS only) |

---

## Sources

- Codebase analysis: `lib/src/version_check.dart`, `lib/src/update.dart`, `lib/src/file_hash.dart`, `lib/src/app_archive.dart`, `lib/src/update_progress.dart`, `lib/src/prepare.dart` (HIGH confidence — primary source)
- [Tauri Updater Plugin docs](https://v2.tauri.app/plugin/updater/) — lifecycle stage reference (Check → Download → Install → Restart), typed events (HIGH confidence)
- [kmp-app-updater state machine](https://github.com/pavi2410/kmp-app-updater) — Idle → Checking → UpdateAvailable → Downloading → ReadyToInstall pattern (MEDIUM confidence)
- [Sparkle framework](https://sparkle-project.org/documentation/) — macOS updater standard; delta updates, phased rollout, mandatory updates reference (HIGH confidence)
- [auto_updater pub.dev](https://pub.dev/packages/auto_updater) — Flutter desktop competitor; setFeedURL / checkForUpdates / setScheduledCheckInterval API surface (HIGH confidence)
- [Flutter error handling with Result objects](https://docs.flutter.dev/app-architecture/design-patterns/result) — sealed class Result/Error pattern recommendation from Flutter team (HIGH confidence)
- [Dart sealed classes](https://dev.to/finitefield/darts-sealed-classes-a-powerful-tool-for-type-safety-and-exhaustiveness-nc9) — exhaustive switch for typed error handling (HIGH confidence)
- `.planning/PROJECT.md` — validated requirements and out-of-scope constraints (HIGH confidence — source of truth)

---

*Feature research for: Flutter macOS desktop OTA update engine (no UI)*
*Researched: 2026-03-26*
