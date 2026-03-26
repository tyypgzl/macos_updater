# Stack Research

**Domain:** Flutter macOS desktop plugin — OTA update engine with abstract data sources
**Researched:** 2026-03-26
**Confidence:** HIGH (all versions verified against pub.dev and official docs)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Dart SDK | ^3.7.0 | Plugin logic, data models, error types | 3.7 adds wildcard variables and inference-using-bounds; 3.8 adds null-aware collection elements. Minimum 3.7 unlocks modern formatter and establishes the clean break from v1. Sealed classes, enhanced enums, and pattern matching are all stable since Dart 3.0 — 3.7+ is the right floor. |
| Flutter | >=3.29.0 | Plugin runtime | 3.29 shipped with SwiftPM improvements and Dart 3.7. Setting this floor aligns with the macOS-primary focus and ensures consumers have current desktop support. Do not lower to 3.3 (current floor) — that allows Dart 3.0 which predates wildcard variable support needed by the new formatter style. |
| Swift 5.9+ | via SwiftPM tools-version 5.9 | macOS native method channel | Swift 5.9 is the SwiftPM minimum Flutter supports. The plugin already uses Package.swift with swift-tools-version 5.9 — keep it. Swift 5.9 has stable async/await, structured concurrency, and `withCheckedContinuation` for bridging the completion-handler-based FlutterMethodChannel API. |
| plugin_platform_interface | ^2.1.8 | Platform abstraction base class | The flutter.dev-canonical package for any plugin that needs a Dart-side platform interface. Required to support the `DesktopUpdaterPlatform` abstract base. Current version 2.1.8 (published by flutter.dev, stable for 2 years — no churn expected). |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| cryptography_plus | ^3.0.0 | Blake2b hashing for delta diffing | The fork of the abandoned `cryptography` package, now maintained under emz-hanauer. Version 3.0.0 published 23 days ago. **Keep this** — it is the only pure-Dart Blake2b implementation that works on all platforms without FFI. |
| cryptography_flutter_plus | ^3.0.0 | Hardware-accelerated crypto on macOS | Companion package to cryptography_plus. Provides native acceleration on Apple platforms. Version 3.0.0 matches cryptography_plus 3.0.0 — they must be upgraded together. |
| http | ^1.6.0 | HTTP downloads (used by consumers in their UpdateSource, or by core for file downloads) | Official dart.dev package. Version 1.6.0. The plugin's core engine still needs HTTP for the actual binary file download (even though version-check HTTP calls move to the consumer's UpdateSource). Do not replace with `dio` — this is a plugin, not an app; minimal transitive deps matter. |
| archive | ^4.0.9 | Decompressing update .zip bundles | Version 4.0.9. Stable, maintained by loki3d. Required for unpacking downloaded update archives before file replacement. |
| path | ^1.9.1 | Cross-platform path construction | Official dart.dev package. Version 1.9.1. Essential for safely constructing `.app/Contents/` paths on macOS without string concatenation. |
| args | ^2.7.0 | CLI argument parsing (bin/release.dart, bin/archive.dart) | Official dart.dev package. Version 2.7.0. Only in the CLI tools — not a runtime dependency for consumers. |
| pubspec_parse | ^1.5.0 | Version extraction in CLI tools | Version 1.5.0. Only used in CLI tools to read pubspec.yaml during release/archive operations. No changes needed. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| flutter_lints | ^6.0.0 | Static analysis and linting | Current version 6.0.0 (published by flutter.dev, ~10 months ago). Up from 5.0.0 in v1. Bump required — 6.0.0 targets Dart 3.1+ and enables modern lint rules. |
| flutter_test (SDK) | Unit and widget testing | No widget tests needed in v2 (UI removed). Unit tests for UpdateSource, model serialization, and update lifecycle. |
| integration_test (SDK) | End-to-end plugin testing | Keep for macOS-specific method channel tests (restart, version fetch). |

---

## Installation

```yaml
# pubspec.yaml — v2.0.0 target

environment:
  sdk: ^3.7.0
  flutter: ">=3.29.0"

dependencies:
  archive: ^4.0.9
  args: ^2.7.0
  cryptography_flutter_plus: ^3.0.0
  cryptography_plus: ^3.0.0
  flutter:
    sdk: flutter
  http: ^1.6.0
  path: ^1.9.1
  plugin_platform_interface: ^2.1.8
  pubspec_parse: ^1.5.0

dev_dependencies:
  flutter_lints: ^6.0.0
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

---

## Language Feature Decisions

### Dart Side

**Use `abstract interface class` for `UpdateSource`**

```dart
// Correct modifier for a public contract consumers implement
abstract interface class UpdateSource {
  Future<UpdateVersion?> fetchLatestVersion();
  Future<List<UpdateFile>> fetchFileManifest(String version);
}
```

- `abstract interface class` prevents inheritance (consumers cannot extend, only implement) — the right constraint for a data source contract that must be independently implemented per backend (Firebase, REST, local).
- Plain `abstract class` would allow `extends`, leaking implementation details. `sealed` would lock subclasses to the same library — wrong for a public plugin API where consumers must subclass.
- Confidence: HIGH — verified against dart.dev/language/class-modifiers

**Use `sealed class` for typed error results**

```dart
sealed class UpdateError {
  const UpdateError();
}
final class NetworkError extends UpdateError { ... }
final class HashMismatchError extends UpdateError { ... }
final class VersionParseError extends UpdateError { ... }
```

The official Flutter architecture guide (docs.flutter.dev/app-architecture/design-patterns/result) recommends exactly this pattern. Sealed + final subclasses give:
- Exhaustive `switch` at call sites
- No external subclassing of error types
- Zero runtime overhead vs. generic `Exception`

**Use `sealed class Result<T>` for operation returns**

Return `Result<T>` from core operations (`checkForUpdate`, `downloadUpdate`) rather than throwing. This is the official Flutter recommended pattern (as of 2025 — documented at docs.flutter.dev). Consumers get compile-time exhaustiveness checking without needing a third-party package.

**Use wildcard variables (Dart 3.7)**

`_` can now be reused in the same scope — use in callbacks and pattern destructuring where values are intentionally ignored. Minor ergonomic improvement that the new formatter style encourages.

**Do NOT use `freezed`**

Freezed is appropriate for app-layer models with lots of copyWith/fromJson boilerplate. For a plugin with 3-5 lean model classes, it adds a code-generation dependency and build_runner to consumer build steps. Write models by hand using Dart 3 records for value semantics where useful.

### Swift Side

**Use completion-handler style for `FlutterMethodChannel` — bridge with `withCheckedContinuation` where needed**

The `FlutterPlugin` protocol requires `handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)` — this is a completion-handler API that Flutter's tooling does not yet generate as async/await (tracked in flutter/flutter#123867, unresolved as of 2026-03). The correct modern pattern is:

```swift
public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
  switch call.method {
  case "restartApp":
    Task {
      await restartApp(result: result)
    }
  default:
    result(FlutterMethodNotImplemented)
  }
}

private func restartApp(result: @escaping FlutterResult) async {
  // Swift async/await internally, completion handler at the boundary
  do {
    try await performFileReplacement()
    result(nil)
  } catch {
    result(FlutterError(code: "RESTART_FAILED", message: error.localizedDescription, details: nil))
  }
}
```

Use `Task { }` to bridge the sync `handle` call into an async context. Use `withCheckedContinuation` when calling Apple APIs that are callback-only. This gives modern Swift internals while satisfying the FlutterPlugin protocol.

**Use GCD for background file operations, not DispatchQueue.main**

The macOS method channel handler runs on the main (UI) thread. File copy operations during `restartApp` must be dispatched to a background queue to avoid blocking. The Task Queue API documented for iOS is NOT documented for macOS — use GCD directly:

```swift
DispatchQueue.global(qos: .userInitiated).async {
  // File operations
  DispatchQueue.main.async {
    result(nil)
  }
}
```

**Bump macOS deployment target to 10.15 in Package.swift**

Current Package.swift targets macOS 10.14. Swift `async`/`await` requires macOS 10.15 (Catalina). Update:

```swift
// swift-tools-version: 5.9
platforms: [.macOS("10.15")]
```

macOS 10.14 Mojave is EOL and unsupported by Apple. Flutter 3.22+ dropped 10.13 support. 10.15 is the right minimum for 2026 shipping.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `abstract interface class UpdateSource` | `abstract class UpdateSource` | Use `abstract class` only if you want to provide default method implementations consumers can call via `super`. UpdateSource should be a pure contract — no defaults. |
| `sealed class UpdateError` with typed subclasses | Generic `Exception` subclasses | Use generic exceptions only in simple scripts. A plugin's public API must be typed for consumer ergonomics. |
| Hand-written `Result<T>` | `result_dart`, `multiple_result` packages | Use pub.dev packages if you want richer chainable APIs (map, flatMap). For a plugin with 4-5 operations, the official minimal sealed implementation is sufficient — avoids a transitive dependency. |
| `http` for downloads | `dio` | Use `dio` if you need interceptors, retry logic, or request cancellation in a consumer app. A plugin should carry minimal deps — `http` 1.6 does streaming downloads adequately. |
| `cryptography_plus` + `cryptography_flutter_plus` | `crypto` (dart.dev) | Use `crypto` if you only need SHA-256/MD5. Blake2b is not in `crypto` — `cryptography_plus` is the only option for the project's delta-diff hashing algorithm. |
| `flutter_lints` 6.0.0 | `very_good_analysis` | Use `very_good_analysis` for stricter rules on consumer apps. A plugin should use the official flutter.dev baseline to minimize friction for contributors. |
| SwiftPM (Package.swift already present) | CocoaPods (Podspec) | Use CocoaPods only for backward compat with Flutter <3.24 consumers. Flutter 3.29+ minimum means SwiftPM is always available — no Podspec maintenance needed. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `freezed` + `build_runner` | Adds code-gen to the plugin's dev workflow AND forces consumers to run `build_runner` if they use generated model classes. Wrong for a plugin with few, stable models. | Hand-written classes with Dart 3 records for value types |
| `dio` | Heavyweight HTTP client with interceptors, form data, etc. — transitive dep burden on consumers for download-only use. | `http` 1.6.0 |
| `dartz` / Either type from fpdart | Functional programming overhead; unusual for Dart/Flutter ecosystem norms; adds pub.dev dependency. | Official `sealed class Result<T>` pattern from docs.flutter.dev |
| `get_it` / `injectable` | Service locator and DI frameworks are app-layer concerns. A plugin must not dictate how consumers wire their dependencies. | Dart constructors; abstract interface class passed by consumer at initialization |
| macOS deployment target 10.14 (Mojave) | EOL, no Swift async/await support. Every Flutter 3.29+ user has macOS 10.15+. | Minimum `.macOS("10.15")` in Package.swift |
| `flutter_lints` 5.0.0 (current in v1) | Outdated — misses rules added in lints 4.0.0 baseline that flutter_lints 6.0.0 enables. | `flutter_lints: ^6.0.0` |
| `plugin_platform_interface` 2.0.2 (current in v1) | Outdated — 2.1.8 is the current stable release with minor fixes. | `^2.1.8` |
| Pigeon for code generation | Pigeon currently generates completion-handler protocols (not async/await) for Swift — no ergonomic gain for this plugin's simple 3-4 method channel. | Hand-written `FlutterMethodChannel` with Task { } bridging |

---

## Stack Patterns by Variant

**If the consumer uses Firebase Remote Config as the update source:**
- They implement `UpdateSource` with `firebase_remote_config` in their own package
- The plugin has zero Firebase dependency — this is correct by design

**If a future maintainer wants to add Windows/Linux native modernization:**
- Windows C++ plugin does not support async/await — use `std::thread` + PostMessage pattern
- Linux C plugin is stable, no modernization needed — keep passive
- This research covers macOS only; Windows/Linux native code changes are out of scope for v2.0.0

**If Blake2b performance becomes a bottleneck:**
- `cryptography_flutter_plus` 3.0.0 already uses Apple CryptoKit acceleration on macOS — no native FFI layer needed
- Only revisit if profiling shows hashing as the bottleneck at >10,000 files

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| cryptography_plus ^3.0.0 | cryptography_flutter_plus ^3.0.0 | These two packages are versioned together — always bump both. 3.0.0 is a major version; verify no breaking API changes before upgrading from 2.x. |
| Dart ^3.7.0 | Flutter >=3.29.0 | Flutter 3.29 ships with Dart 3.7. Pairing these ensures no mismatch between SDK constraint and actual language features used. |
| swift-tools-version: 5.9 | macOS 10.15+ deployment target | Swift async/await in `Task {}` requires macOS 10.15+. If tools version stays at 5.9 but deployment drops to 10.14, async code will fail to compile or run. |
| flutter_lints ^6.0.0 | Dart ^3.1.0+ | flutter_lints 6.0.0 requires Dart 3.1+. Dart 3.7 satisfies this. Do not use flutter_lints 6.0.0 with a Dart ^3.0.0 floor. |

---

## Sources

- [pub.dev/packages/http](https://pub.dev/packages/http) — Verified version 1.6.0 (HIGH confidence)
- [pub.dev/packages/archive](https://pub.dev/packages/archive) — Verified version 4.0.9 (HIGH confidence)
- [pub.dev/packages/cryptography_plus](https://pub.dev/packages/cryptography_plus) — Verified version 3.0.0, new maintainer (HIGH confidence)
- [pub.dev/packages/cryptography_flutter_plus](https://pub.dev/packages/cryptography_flutter_plus) — Verified version 3.0.0 (HIGH confidence)
- [pub.dev/packages/plugin_platform_interface](https://pub.dev/packages/plugin_platform_interface) — Verified version 2.1.8 (HIGH confidence)
- [pub.dev/packages/flutter_lints](https://pub.dev/packages/flutter_lints) — Verified version 6.0.0 (HIGH confidence)
- [pub.dev/packages/path](https://pub.dev/packages/path) — Verified version 1.9.1 (HIGH confidence)
- [pub.dev/packages/args](https://pub.dev/packages/args) — Verified version 2.7.0 (HIGH confidence)
- [pub.dev/packages/pubspec_parse](https://pub.dev/packages/pubspec_parse) — Verified version 1.5.0 (HIGH confidence)
- [dart.dev/resources/whats-new](https://dart.dev/resources/whats-new) — Dart 3.7 features: wildcard variables, inference-using-bounds, formatter overhaul; Dart 3.8: null-aware collection elements (HIGH confidence)
- [dart.dev/language/class-modifiers](https://dart.dev/language/class-modifiers) — abstract vs abstract interface vs sealed class guidance (HIGH confidence)
- [docs.flutter.dev/app-architecture/design-patterns/result](https://docs.flutter.dev/app-architecture/design-patterns/result) — Official sealed Result<T> pattern recommendation (HIGH confidence)
- [docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors) — SwiftPM Package.swift structure, deployment targets (HIGH confidence)
- [docs.flutter.dev/platform-integration/platform-channels](https://docs.flutter.dev/platform-integration/platform-channels) — Method channel threading model for macOS; confirmed Task Queue API is iOS-only; GCD pattern for macOS background work (HIGH confidence)
- [github.com/flutter/flutter/issues/123867](https://github.com/flutter/flutter/issues/123867) — Pigeon async/await for Swift: unresolved as of research date (MEDIUM confidence — open issue may progress)
- [blog.flutter.dev/whats-new-in-flutter-3-29](https://blog.flutter.dev/whats-new-in-flutter-3-29-f90c380c2317) — Flutter 3.29 release notes, SwiftPM improvements (HIGH confidence)

---

*Stack research for: flutter_desktop_updater v2.0.0 — macOS OTA update plugin*
*Researched: 2026-03-26*
