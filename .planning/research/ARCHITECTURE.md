# Architecture Research

**Domain:** Headless Flutter desktop update engine plugin with abstract data source
**Researched:** 2026-03-26
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                      Consumer Application                        │
│  ┌───────────────────┐   ┌─────────────────────────────────────┐ │
│  │  Consumer UI       │   │  ConcreteUpdateSource               │ │
│  │  (owns widgets)    │   │  (implements UpdateSource)          │ │
│  │                    │   │  e.g. FirebaseSource, RestApiSource │ │
│  └────────┬───────────┘   └──────────────┬──────────────────────┘ │
│           │  Stream<UpdateState>          │ UpdateInfo / hashes    │
└───────────┼───────────────────────────────┼──────────────────────┘
            │                               │
┌───────────▼───────────────────────────────▼──────────────────────┐
│                     desktop_updater package                       │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                   DesktopUpdater (public API)              │   │
│  │  check() · prepare() · download() · apply() · restart()   │   │
│  └────────────────────┬───────────────────────────────────────┘   │
│                       │                                           │
│  ┌────────────────────▼───────────────────────────────────────┐   │
│  │                  UpdateEngine (core)                       │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │   │
│  │  │VersionChecker│  │ FileHasher   │  │ FileDownloader  │  │   │
│  │  │              │  │ (Blake2b)    │  │ (streaming)     │  │   │
│  │  └──────────────┘  └──────────────┘  └─────────────────┘  │   │
│  └────────────────────┬───────────────────────────────────────┘   │
│                       │                                           │
│  ┌────────────────────▼───────────────────────────────────────┐   │
│  │              abstract UpdateSource                         │   │
│  │  getUpdateInfo() → UpdateInfo                              │   │
│  │  getFileHashes(version) → List<FileHash>                   │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │           Platform Abstraction (method channel)            │   │
│  │  getCurrentVersion() · restartApp() · getExecutablePath()  │   │
│  └────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
            │
┌───────────▼──────────────────────────────────────────────────────┐
│                   Native Layer (Swift macOS)                      │
│  CFBundleVersion · NSApplication restart · file replace          │
└──────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `UpdateSource` (abstract) | Contract: fetch update metadata and remote hashes | Implemented by consumer |
| `DesktopUpdater` | Public API surface — orchestrates lifecycle steps | `UpdateEngine`, `PlatformInterface` |
| `UpdateEngine` | Core workflows: version compare, hash diff, download | `UpdateSource`, `FileHasher`, `FileDownloader`, `PlatformInterface` |
| `VersionChecker` | Compare build numbers, decide if update is needed | `UpdateSource`, `PlatformInterface` |
| `FileHasher` | Generate local Blake2b hashes, compare with remote | Filesystem, `UpdateSource` |
| `FileDownloader` | Stream files from URLs into `update/` staging dir | `UpdateSource` (provides URLs) |
| `PlatformInterface` | Abstract method channel contract | Native (Swift/C++/C) |
| `MethodChannelImpl` | Concrete method channel implementation | macOS Swift plugin |
| Native (Swift) | `CFBundleVersion`, file replacement, process restart | OS |
| Consumer `UpdateSource` | Fetch `UpdateInfo` from any backend | Any: Firebase, REST, local |
| Consumer UI | Observe `Stream<UpdateState>`, render progress | `DesktopUpdater` stream |

## Recommended Project Structure

```
lib/
├── desktop_updater.dart          # Public barrel: exports only stable API surface
├── src/
│   ├── update_source.dart        # abstract UpdateSource — the consumer contract
│   ├── models/
│   │   ├── update_info.dart      # UpdateInfo (version, downloadUrl)
│   │   ├── file_hash.dart        # FileHash (filePath, blake2b, length)
│   │   ├── update_progress.dart  # UpdateProgress (receivedBytes, totalBytes, currentFile)
│   │   └── update_result.dart    # sealed UpdateResult (success, upToDate, error variants)
│   ├── engine/
│   │   ├── version_checker.dart  # int build number comparison
│   │   ├── file_hasher.dart      # genFileHashes(), verifyFileHashes()
│   │   └── file_downloader.dart  # downloadFiles() → Stream<UpdateProgress>
│   ├── updater.dart              # DesktopUpdater class — wires engine + platform + source
│   └── errors.dart               # sealed UpdaterError hierarchy
├── desktop_updater_platform_interface.dart
└── desktop_updater_method_channel.dart

bin/
├── release.dart                  # macOS-only CLI build + hash generation
└── archive.dart                  # macOS-only app-archive generation

macos/
└── desktop_updater/
    └── Sources/desktop_updater/
        └── DesktopUpdaterPlugin.swift
```

### Structure Rationale

- **`src/update_source.dart` at top of `src/`:** The abstract contract is the single most important file — its position signals that it is the boundary between the plugin and the consumer.
- **`src/models/`:** All data types are co-located so consumers importing the barrel get clean, minimal DTOs with no hidden coupling.
- **`src/engine/`:** Three narrowly scoped files — each has one reason to change. `VersionChecker` changes only if version comparison logic changes; `FileHasher` changes only if the hash algorithm changes; `FileDownloader` changes only if download strategy changes.
- **`src/updater.dart`:** The orchestrator. Wires together `UpdateSource` (injected), engine functions, and platform calls. This is the only file that knows the full lifecycle sequence.
- **`src/errors.dart`:** A `sealed` class hierarchy replaces bare `Exception` throws, giving consumers exhaustive switch matching on error cases.
- **`bin/`:** CLI tools remain outside `lib/` — they are developer tools, not runtime code.

## Architectural Patterns

### Pattern 1: Abstract Data Source (Inversion of Control)

**What:** `UpdateSource` is an `abstract interface class` with two async methods. The plugin holds a reference typed to the abstract class. The consumer provides the concrete implementation at construction time.

**When to use:** Any time the plugin cannot know at compile time where update metadata comes from. Firebase Remote Config, REST API, local JSON file, and hard-coded values all satisfy the same contract.

**Trade-offs:** Consumer writes one more class, but gains complete control over auth, caching, retry, and backend choice. The plugin ships zero HTTP code for the metadata fetch.

**Example:**
```dart
// In the plugin — the contract
abstract interface class UpdateSource {
  /// Returns null if no update is available.
  Future<UpdateInfo?> getLatestUpdateInfo();

  /// Returns hashes.json content for the given version's download URL.
  Future<List<FileHash>> getRemoteFileHashes(String downloadUrl);
}

// In the consumer app — one implementation
class FirebaseUpdateSource implements UpdateSource {
  @override
  Future<UpdateInfo?> getLatestUpdateInfo() async {
    final config = FirebaseRemoteConfig.instance;
    final version = int.parse(config.getString('latest_build'));
    final url = config.getString('download_url');
    return UpdateInfo(buildNumber: version, downloadUrl: url);
  }

  @override
  Future<List<FileHash>> getRemoteFileHashes(String downloadUrl) async {
    final response = await http.get(Uri.parse('$downloadUrl/hashes.json'));
    return (jsonDecode(response.body) as List)
        .map((e) => FileHash.fromJson(e))
        .toList();
  }
}
```

### Pattern 2: Sealed State Machine for Lifecycle

**What:** `UpdateState` is a `sealed class` with one subclass per lifecycle phase. `DesktopUpdater` exposes a `Stream<UpdateState>` so the consumer reacts to transitions without polling.

**When to use:** Any time there is a fixed, ordered sequence of states with distinct data at each step. Exhaustive `switch` ensures the consumer handles every state at compile time.

**Trade-offs:** More upfront type definitions, but eliminates boolean flag soup (`isDownloading`, `isDownloaded`, `needUpdate` all separate fields) that exists in the current controller.

**Example:**
```dart
sealed class UpdateState {}

class UpdateIdle extends UpdateState {}
class UpdateChecking extends UpdateState {}
class UpdateAvailable extends UpdateState {
  final UpdateInfo info;
  final List<FileHash> changedFiles;
  UpdateAvailable({required this.info, required this.changedFiles});
}
class UpdateDownloading extends UpdateState {
  final UpdateProgress progress;
  UpdateDownloading(this.progress);
}
class UpdateReady extends UpdateState {}   // downloaded, awaiting restart
class UpdateUpToDate extends UpdateState {}
class UpdateError extends UpdateState {
  final UpdaterError error;
  UpdateError(this.error);
}

// Consumer switch is exhaustive:
switch (state) {
  case UpdateIdle() => ...,
  case UpdateChecking() => ...,
  case UpdateAvailable(:final info) => ...,
  case UpdateDownloading(:final progress) => ...,
  case UpdateReady() => ...,
  case UpdateUpToDate() => ...,
  case UpdateError(:final error) => ...,
}
```

### Pattern 3: Function-Based Lifecycle API (Explicit Steps)

**What:** Instead of a single `start()` method that runs everything, expose discrete async steps: `check()`, `prepare()`, `download()`, `apply()`, `restart()`. The consumer calls them explicitly, giving them control over UX decisions (e.g., ask permission before downloading).

**When to use:** Update flows where the consumer needs to present consent dialogs, defer downloads, or apply updates at a specific moment (e.g., on next launch). This replaces the current controller's monolithic auto-start.

**Trade-offs:** More calls in consumer code. Compensated by the stream — consumer can also just call `check()` then react to `UpdateAvailable` to drive further steps.

**Example:**
```dart
class DesktopUpdater {
  DesktopUpdater({required UpdateSource source});

  Stream<UpdateState> get states; // broadcast stream

  Future<void> check();     // idle → checking → available | upToDate | error
  Future<void> prepare();   // available → (validates, computes delta)
  Future<void> download();  // available → downloading → ready | error
  Future<void> restart();   // ready → (file replacement + process relaunch)
}
```

## Data Flow

### Lifecycle Flow

```
Consumer calls check()
    ↓
UpdateEngine.check(source)
    ↓ calls source.getLatestUpdateInfo()
    ↓ calls platform.getCurrentVersion()
    ↓ compares build numbers
    ├─ no update → emit UpdateUpToDate
    └─ update available →
            calls source.getRemoteFileHashes(downloadUrl)
            calls FileHasher.genFileHashes() [local Blake2b scan]
            calls FileHasher.verifyFileHashes(local, remote)
            emit UpdateAvailable(info, changedFiles)

Consumer calls download()
    ↓
FileDownloader.downloadFiles(changedFiles, downloadUrl, appDir)
    ↓ for each changed file:
        HTTP GET → stream to appDir/update/{relativePath}
        emit UpdateProgress chunk
    ↓ all complete
    emit UpdateReady

Consumer calls restart()
    ↓
platform.restartApp()
    ↓ (Swift) NSApplication.terminate(nil)
       copyAndReplaceFiles(update/ → Contents/)
       Process().run(executablePath)
```

### Update Source Data Flow

```
UpdateSource (consumer-owned)
    ↓ getLatestUpdateInfo()
UpdateInfo { buildNumber: int, downloadUrl: String }
    ↓ (if buildNumber > current)
UpdateSource.getRemoteFileHashes(downloadUrl)
List<FileHash> { filePath, calculatedHash, length }
    ↓ diff vs local hashes
List<FileHash> changedFiles   ← only what actually changed
    ↓ passed to FileDownloader
UpdateProgress events stream  ← consumer renders progress bar
```

### Error Flow

```
Any engine step throws
    ↓
Caught in DesktopUpdater orchestrator
    ↓
Mapped to typed UpdaterError (sealed class)
    ↓ emitted as UpdateError(error) state
Consumer switch handles:
    UpdaterError.sourceUnavailable  — backend unreachable
    UpdaterError.versionParseFailed — malformed build number
    UpdaterError.hashMismatch       — corrupted local install
    UpdaterError.downloadFailed     — network error mid-transfer
    UpdaterError.applyFailed        — permission error during file replace
```

## Component Boundaries (What Talks to What)

| Boundary | Direction | Communication | Notes |
|----------|-----------|---------------|-------|
| Consumer → `DesktopUpdater` | Inbound | Direct method calls + stream subscription | Only stable public API |
| `DesktopUpdater` → `UpdateSource` | Outbound | Async method calls on injected interface | Consumer provides concrete impl |
| `DesktopUpdater` → `UpdateEngine` | Internal | Direct function calls | Engine functions are pure/stateless |
| `UpdateEngine` → `PlatformInterface` | Downward | Abstract method calls | Routed to native via method channel |
| `PlatformInterface` → Swift | Downward | FlutterMethodChannel | Only 4 calls: version, path, restart, getPlatformVersion |
| `FileDownloader` → HTTP | Outward | `package:http` streaming GET | Consumer's `UpdateSource` provides URL base |
| Consumer `UpdateSource` → Backend | Outward | Consumer's choice (Firebase SDK, `http`, local file) | Plugin has no opinion on this |

## Suggested Build Order

Dependencies flow upward — build lower layers first.

```
Phase 1 — Foundation (no dependencies)
├── src/models/         (pure data classes, no imports within plugin)
├── src/errors.dart     (sealed error hierarchy)
└── Platform interface  (abstract + method channel, depends only on Flutter SDK)

Phase 2 — Core Engine (depends on models + platform)
├── src/engine/file_hasher.dart    (depends on models, dart:io, cryptography_plus)
├── src/engine/file_downloader.dart (depends on models, http package)
└── src/engine/version_checker.dart (depends on models, platform interface)

Phase 3 — Abstract Contract (depends on models)
└── src/update_source.dart   (abstract interface referencing model types)

Phase 4 — Orchestrator (depends on all above)
└── src/updater.dart         (wires UpdateSource + engine + platform, emits UpdateState stream)

Phase 5 — Public API (depends on orchestrator)
└── lib/desktop_updater.dart (barrel export, DesktopUpdater public class)

Phase 6 — CLI Tools (independent of runtime lib)
├── bin/release.dart
└── bin/archive.dart
```

**Rationale for this order:**
- Models define the types everything else speaks — zero risk of circular imports if built first.
- Engine functions are pure (input → output) and can be unit tested before the orchestrator exists.
- `UpdateSource` depends on models for its method signatures — must follow models.
- `Updater` depends on everything and is the last pure-Dart piece.
- The public barrel is a thin re-export layer — changing it never cascades into engine logic.

## Anti-Patterns

### Anti-Pattern 1: Baking HTTP Into the Version Check Step

**What people do:** `versionCheckFunction()` downloads `app-archive.json` from a hard-coded URL pattern and parses it internally (current v1 behaviour).

**Why it's wrong:** The plugin becomes the authority on how version metadata is fetched. Any consumer wanting Firebase Remote Config, signed URLs, or JWT-authenticated endpoints must fork the package or work around the fetch.

**Do this instead:** `UpdateSource.getLatestUpdateInfo()` returns `UpdateInfo`. The HTTP call (or Firebase call, or local file read) lives entirely in consumer code. The engine receives the result.

### Anti-Pattern 2: Stateful Controller Bundled Inside the Plugin

**What people do:** Ship a `DesktopUpdaterController extends ChangeNotifier` with 10+ boolean fields, release notes list, download size calculations, and `InheritedWidget` glue (current v1 behaviour).

**Why it's wrong:** Locks consumers into `ChangeNotifier`/`InheritedWidget` state management. Consumers using Riverpod, Bloc, or signals must wrap or duplicate the controller. The plugin owns state it shouldn't own.

**Do this instead:** `DesktopUpdater` emits a `Stream<UpdateState>` (a sealed class hierarchy). Each consumer maps the stream to their state management choice. The plugin has no `flutter/material.dart` import.

### Anti-Pattern 3: Mixed Concerns in Version Check

**What people do:** `versionCheckFunction()` fetches the archive, parses it, gets current version, downloads hashes.json, generates local hashes, and computes the diff — all in one 170-line async function (current v1 behaviour).

**Why it's wrong:** The function is untestable in parts. Cannot unit-test hash diffing without triggering an HTTP request. Cannot test version comparison without a real file system.

**Do this instead:** Split into `VersionChecker.check(source, platform)`, `FileHasher.genLocalHashes()`, `FileHasher.diff(local, remote)`. Each function is independently testable with mocked inputs.

### Anti-Pattern 4: Nullable List Items (`List<FileHashModel?>`)

**What people do:** Use `List<FileHashModel?>` throughout — the current signature of `verifyFileHashes`, `updateApp`, and `prepareUpdateApp`.

**Why it's wrong:** Every call site must null-check list elements. This spreads defensive code across the codebase and hides the invariant that a hash entry is either present or absent from the list entirely.

**Do this instead:** `List<FileHash>` (non-nullable). Use `whereType<FileHash>()` at the parse boundary to strip any parse failures before they enter the engine.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Any update backend (Firebase, REST) | Consumer implements `UpdateSource` | Plugin never touches this layer |
| `package:http` | Used only by `FileDownloader` for binary file downloads | Stays inside plugin — consumer does not need it |
| `package:cryptography_plus` | Used only by `FileHasher` (Blake2b) | Internal, not re-exported |
| macOS Swift native | `FlutterMethodChannel` ("desktop_updater") | 4 methods: version, path, restart, getPlatformVersion |
| Filesystem (`dart:io`) | Direct in `FileHasher`, `FileDownloader` | macOS path: `.app/Contents` via `parent.parent` of executable |

### Internal Boundaries

| Boundary | Communication | Constraint |
|----------|---------------|------------|
| Public API ↔ Engine | Direct Dart function calls | Engine functions must be pure (no side effects beyond filesystem staging) |
| Engine ↔ `UpdateSource` | `async` method call on interface | `UpdateSource` methods must not throw — return `null` for "no update" |
| Engine ↔ Platform | `async` method channel calls | Can throw `PlatformException`; engine maps to `UpdaterError` |
| Engine ↔ Native filesystem | `dart:io` `File`/`Directory` | Staging area is always `{appContentsDir}/update/`; applied atomically by Swift on restart |

## Scaling Considerations

This is a client-side plugin — "scaling" means increasing app install base, not servers.

| Concern | Implication | Approach |
|---------|-------------|----------|
| Large update bundles | Many files, slow hash scan | Hash scan is already async; consider excluding known-unchanged asset types in CLI tool |
| Concurrent updates blocked | Two instances of same app | File locking on staging dir prevents corruption; out of scope for plugin |
| Download interruption | Partial staging dir | `FileDownloader` should write to temp paths and move atomically; resumable downloads are a future enhancement |
| Backend rate limits | Consumer's concern | `UpdateSource` abstraction lets consumer implement backoff/retry without plugin changes |

## Sources

- Flutter official app architecture documentation: https://docs.flutter.dev/app-architecture/design-patterns
- Repository pattern and abstract data sources in Flutter: https://codewithandrea.com/articles/abstraction-repository-pattern-flutter/
- Sealed classes and state machines in Dart 3: https://dev.to/finitefield/darts-sealed-classes-a-powerful-tool-for-type-safety-and-exhaustiveness-nc9
- Dart class modifiers (sealed, interface, final): https://quickbirdstudios.com/blog/flutter-dart-class-modifiers/
- Existing codebase analysis: `.planning/codebase/ARCHITECTURE.md` (2026-03-26)

---
*Architecture research for: headless Flutter desktop update engine plugin*
*Researched: 2026-03-26*
