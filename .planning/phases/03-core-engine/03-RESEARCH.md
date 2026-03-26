# Phase 3: Core Engine - Research

**Researched:** 2026-03-26
**Domain:** Dart file hashing (Blake2b), HTTP streaming download, Stream<UpdateProgress> design, macOS bundle path resolution
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All decisions deferred to Claude — no locked user choices.

### Claude's Discretion (all areas)
- **Download staging:** Keep existing `app/update/` staging path convention. Engine downloads to `{appDir}/update/{filePath}`.
- **Progress reporting:** Use `Stream<UpdateProgress>` (more composable than callbacks). Engine's download orchestrator returns a broadcast stream.
- **File hasher:** Refactor `genFileHashes()` and `verifyFileHashes()` into a `FileHasher` class or top-level functions under `lib/src/engine/file_hasher.dart`. Use new `FileHash` model (non-nullable).
- **File downloader:** Refactor `downloadFile()` into `lib/src/engine/file_downloader.dart`. Keep HTTP streaming approach. Report per-file progress.
- **Error handling:** All engine functions throw typed `UpdateError` subtypes. `NetworkError` for HTTP failures, `HashMismatch` for integrity issues.
- **Concurrent downloads:** Keep existing parallel download approach (`Future.wait` on all files).
- **Blake2b implementation:** Continue using `cryptography_plus` package's `Blake2b().hash()`.
- **generateLocalFileHashes():** Refactor `genFileHashes()` to return `List<FileHash>` directly (in-memory). Remove temp-file write.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENG-01 | File hash comparison engine using Blake2b to determine changed files between local and remote | Blake2b API verified stable (cryptography_plus 2.7.1 → 3.0.0 no breaking changes). In-memory List<FileHash> diff pattern documented below. |
| ENG-02 | File downloader that streams individual changed files from remote URL to local staging | http.Client streaming pattern verified. `received += chunk.length` bug fix documented. Shared http.Client across all downloads. |
| ENG-03 | Stream-based update lifecycle emitting progress events during download | StreamController.broadcast() pattern. UpdateProgress model from Phase 1 confirmed compatible. Error propagation via addError(). |
</phase_requirements>

---

## Summary

Phase 3 refactors three existing v1 source files (`file_hash.dart`, `download.dart`, `update.dart`) into clean engine functions under `lib/src/engine/`. The core algorithms (Blake2b hashing, HTTP streaming, StreamController progress) are sound and stable — the refactoring is primarily about removing bugs, tightening types from nullable to non-nullable, moving from temp-file I/O to in-memory comparison, and replacing `print()` with no-op (satisfying the enforced `avoid_print` lint rule).

The most significant technical change is in `FileDownloader`: the existing `received = chunk.length` bug (assignment instead of accumulation) must be fixed to `received += chunk.length`. The v1 code also creates a new `http.Client()` per file download — the refactored code should use one shared client across the `Future.wait` parallel download batch.

`cryptography_plus` 3.0.0 (released ~23 days before this research date) shows **no breaking changes** to the `Blake2b().hash(List<int>)` API or the `Hash.bytes` return type. The existing call pattern can be carried forward unchanged.

**Primary recommendation:** Two top-level function files (not classes) under `lib/src/engine/` — `file_hasher.dart` and `file_downloader.dart` — mirroring the established project pattern of function-based modules. Return `List<FileHash>` and `Stream<UpdateProgress>` directly, throw typed `UpdateError` subtypes, remove all `print()` calls, and fix the byte-accumulation bug.

---

## Project Constraints (from CLAUDE.md)

| Directive | Enforcement |
|-----------|-------------|
| Double quotes for all strings | `prefer_double_quotes` lint rule — enforced |
| Strict lint with 87 rules | `analysis_options.yaml` — any `print()` fails `avoid_print` |
| `prefer_final_locals` | All local variables must be `final` unless reassigned |
| `require_trailing_commas` | All multiline argument lists need trailing comma |
| `omit_local_variable_types` | No explicit type on local variables (use `var`/`final`) |
| `public_member_api_docs: true` | Every public function/class/member needs `///` doc comment |
| `always_declare_return_types` | All functions must have explicit return types |
| `avoid_print: true` | **Zero `print()` calls** — existing v1 code violates this, must be removed |
| `only_throw_errors` | Only throw `Error`/`Exception` subtypes — `UpdateError implements Exception` satisfies this |
| `avoid_dynamic_calls: true` | No dynamic dispatch — all types must be explicit |
| `cancel_subscriptions: true` | All StreamSubscriptions must be cancelled when done |
| `close_sinks: true` | All IOSink/StreamController must be closed |
| `unawaited_futures: true` | No fire-and-forget futures — must use `unawaited()` explicitly |
| `type_annotate_public_apis: true` | Public function params and return types must be explicitly typed |
| `sort_constructors_first: true` | Constructor before fields in class declarations |
| No codegen (no freezed/build_runner) | Manual model implementations only |
| Package imports only | `always_use_package_imports` — no relative imports |

---

## Standard Stack

### Core (already in pubspec.yaml)

| Library | Locked Version | Purpose | Notes |
|---------|---------------|---------|-------|
| `cryptography_plus` | 2.7.1 (lock), 3.0.0 available | Blake2b file hashing | API unchanged between 2.x and 3.0.0 — `Blake2b().hash()` call pattern stable. Phase 7 (CLI-04) will bump to 3.x. |
| `http` | 1.2.2 (lock), 1.6.0 available | HTTP streaming download | `http.Client.send()` + `StreamedResponse.stream` pattern used in v1 — keep. |
| `path` | 1.9.0 | Path joining for staging directory | `path.join()` and `path.dirname()` used in v1 `download.dart` — keep. |
| `dart:io` | SDK | File/Directory operations, Platform | `Platform.resolvedExecutable`, `File.openWrite()`, `Directory.create()` |
| `dart:async` | SDK | StreamController, Future.wait, unawaited | Core async primitives |
| `dart:convert` | SDK | `base64.encode()` for hash bytes → string | Same as v1 `getFileHash()` |

### Supporting (test only)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flutter_test` | SDK | Unit test framework | All engine unit tests |
| `http` (testing library) | 1.6.0 | `MockClient.streaming()` | Test FileDownloader without real HTTP |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `cryptography_plus` Blake2b | `crypto` package SHA-256 | crypto is simpler but Blake2b is already in use, hashes.json format depends on it |
| `StreamController.broadcast()` | Single-subscription StreamController | Broadcast allows multiple listeners (e.g., Phase 4 can re-expose stream to consumer). Single-sub is simpler but limits Phase 4 API surface. |
| `Future.wait` parallel downloads | Sequential download loop | Parallel is already the v1 approach and is correct for delta-only small file lists |
| Shared `http.Client` per download session | New `http.Client()` per file | Shared client reuses connections; v1 wastes resources with per-file clients |

**Installation:** No new packages needed. All dependencies are already in pubspec.yaml.

---

## Architecture Patterns

### Recommended Engine File Structure

```
lib/src/engine/
├── file_hasher.dart      # generateLocalFileHashes(), diffFileHashes()
└── file_downloader.dart  # downloadFiles() → Stream<UpdateProgress>
```

Both files use top-level functions (not classes), consistent with the existing project pattern (`getFileHash()`, `downloadFile()`, `updateAppFunction()` are all top-level). The ARCHITECTURE.md research file shows `FileHasher` and `FileDownloader` as conceptual names — the actual implementation uses top-level functions per the project's established convention.

### Pattern 1: In-Memory Hash Generation (ENG-01)

**What:** `generateLocalFileHashes()` replaces `genFileHashes()`. Scans the app bundle directory, computes Blake2b for each file, returns `List<FileHash>` directly in memory. No temp file write.

**When to use:** Called before downloading, to determine which files have changed.

**v1 issues fixed:**
- Removes temp file creation and path return — caller no longer needs to read a file back
- Replaces `FileHashModel` (nullable v1 type) with `FileHash` (non-nullable v2 type)
- Removes `print()` calls
- Uses `path` package for proper path manipulation

```dart
// Source: Refactored from lib/src/file_hash.dart genFileHashes()
// Returns in-memory list instead of writing to temp file

/// Computes Blake2b hashes for all files in the running app bundle.
///
/// Uses [Platform.resolvedExecutable] to locate the bundle root.
/// On macOS the executable is inside `Contents/MacOS/` so [dir.parent]
/// resolves to the `Contents/` root.
///
/// Throws [NoPlatformEntry] if the bundle directory cannot be found.
Future<List<FileHash>> generateLocalFileHashes({String? path}) async {
  final executablePath = path ?? Platform.resolvedExecutable;

  final directoryPath = executablePath.substring(
    0,
    executablePath.lastIndexOf(Platform.pathSeparator),
  );

  var dir = Directory(directoryPath);

  if (Platform.isMacOS) {
    dir = dir.parent;
  }

  if (!await dir.exists()) {
    throw NoPlatformEntry(
      message: "Desktop Updater: Bundle directory does not exist: ${dir.path}",
    );
  }

  final hashList = <FileHash>[];

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      final fileBytes = await entity.readAsBytes();
      final hash = await Blake2b().hash(fileBytes);
      final hashString = base64.encode(hash.bytes);
      final relativePath = entity.path.substring(dir.path.length + 1);

      if (hashString.isNotEmpty) {
        hashList.add(FileHash(
          filePath: relativePath,
          hash: hashString,
          length: entity.lengthSync(),
        ));
      }
    }
  }

  return hashList;
}
```

### Pattern 2: In-Memory Hash Diff (ENG-01)

**What:** `diffFileHashes()` replaces `verifyFileHashes()`. Takes two `List<FileHash>` (local, remote) and returns only the files that differ. No file I/O — pure in-memory computation.

**v1 issues fixed:**
- Eliminates file-path-based interface (old code took two file paths and read from disk)
- Removes `FileHashModel?` nullable types — works with non-nullable `FileHash`
- Field rename: v1 `calculatedHash` → v2 `hash`

```dart
// Source: Refactored from lib/src/file_hash.dart verifyFileHashes()

/// Returns the subset of [remoteHashes] that differ from [localHashes].
///
/// A file is considered changed if it is absent from [localHashes] or
/// if its [FileHash.hash] differs from the local entry with the same path.
List<FileHash> diffFileHashes(
  List<FileHash> localHashes,
  List<FileHash> remoteHashes,
) {
  final localByPath = {
    for (final h in localHashes) h.filePath: h,
  };

  return [
    for (final remote in remoteHashes)
      if (localByPath[remote.filePath]?.hash != remote.hash) remote,
  ];
}
```

### Pattern 3: HTTP Streaming Download (ENG-02)

**What:** `_downloadSingleFile()` replaces `downloadFile()`. Keeps the streaming HTTP approach but fixes the byte-accumulation bug and removes `print()`. The public-facing function `downloadFiles()` orchestrates parallel downloads and emits `UpdateProgress` events.

**v1 bugs fixed:**
- `received = chunk.length` → `received += chunk.length` (critical: v1 never accumulates correctly)
- `print("File downloaded to ...")` → removed (avoid_print lint)
- New `http.Client()` per file → shared client passed as parameter

```dart
// Source: Refactored from lib/src/download.dart downloadFile()

/// Downloads a single file from [url] into [stagingPath], calling
/// [onChunk] with the number of bytes received in each chunk.
///
/// Throws [NetworkError] on non-200 response or network failure.
Future<void> _downloadSingleFile(
  http.Client client,
  String url,
  String stagingPath,
  void Function(int chunkBytes) onChunk,
) async {
  final request = http.Request("GET", Uri.parse(url));
  final response = await client.send(request);

  if (response.statusCode != 200) {
    throw NetworkError(
      message: "Failed to download file: $url (HTTP ${response.statusCode})",
    );
  }

  final saveDir = Directory(path.dirname(stagingPath));
  if (!saveDir.existsSync()) {
    await saveDir.create(recursive: true);
  }

  final sink = File(stagingPath).openWrite();
  try {
    await response.stream.listen(
      (final List<int> chunk) {
        sink.add(chunk);
        onChunk(chunk.length);   // accumulation happens in caller
      },
      cancelOnError: true,
    ).asFuture<void>();
  } finally {
    await sink.close();
  }
}
```

### Pattern 4: Stream<UpdateProgress> Orchestrator (ENG-03)

**What:** `downloadFiles()` replaces `updateAppFunction()`. Returns a `Stream<UpdateProgress>` using a broadcast `StreamController`. Parallel downloads via `Future.wait`. Errors propagated via `addError()` and stream is closed in `finally`.

**Design choices:**
- **Broadcast stream:** Phase 4's public API can re-expose the same stream to multiple consumers (UI, logging). Single-subscription would prevent this.
- **`unawaited()` on Future.wait:** v1 uses `unawaited(Future.wait(...).then(...))` — this is the correct pattern when returning the stream before downloads complete. The `unawaited_futures` lint requires explicit `unawaited()` wrapping.
- **Bytes vs KB:** `UpdateProgress.totalBytes` and `receivedBytes` are `double` (inherited from Phase 1 model). The Phase 1 model spec says "All byte values are in bytes (not KB/MB) — consumers format for display." The v1 code stores KB — the refactored code must store raw bytes.

```dart
// Source: Refactored from lib/src/update.dart updateAppFunction()

/// Downloads [changedFiles] from [remoteBaseUrl] into the app's staging
/// directory, emitting [UpdateProgress] events on the returned stream.
///
/// The stream is a broadcast stream and closes when all downloads complete
/// or when an error occurs. Errors are emitted via [Stream.addError] and
/// the stream is closed immediately after.
///
/// Throws nothing directly — all errors appear as stream error events.
Stream<UpdateProgress> downloadFiles({
  required String remoteBaseUrl,
  required List<FileHash> changedFiles,
  required String appDir,
}) {
  final controller = StreamController<UpdateProgress>.broadcast();

  if (changedFiles.isEmpty) {
    controller.close();
    return controller.stream;
  }

  final totalBytes = changedFiles.fold<double>(
    0,
    (sum, f) => sum + f.length,
  );
  final totalFiles = changedFiles.length;
  var receivedBytes = 0.0;
  var completedFiles = 0;
  final client = http.Client();

  final futures = [
    for (final file in changedFiles)
      _downloadSingleFile(
        client,
        "$remoteBaseUrl/${file.filePath}",
        path.join(appDir, "update", file.filePath),
        (chunkBytes) {
          receivedBytes += chunkBytes;
          controller.add(UpdateProgress(
            totalBytes: totalBytes,
            receivedBytes: receivedBytes,
            currentFile: file.filePath,
            totalFiles: totalFiles,
            completedFiles: completedFiles,
          ));
        },
      ).then((_) {
        completedFiles += 1;
        controller.add(UpdateProgress(
          totalBytes: totalBytes,
          receivedBytes: receivedBytes,
          currentFile: file.filePath,
          totalFiles: totalFiles,
          completedFiles: completedFiles,
        ));
      }).catchError((final Object error) {
        controller.addError(error);
      }),
  ];

  unawaited(
    Future.wait(futures).whenComplete(() async {
      client.close();
      await controller.close();
    }),
  );

  return controller.stream;
}
```

### Pattern 5: macOS Bundle Path Resolution

**What:** `Platform.resolvedExecutable` on macOS returns a path like `/Applications/MyApp.app/Contents/MacOS/MyApp`. One `.parent` gives `Contents/MacOS/`, another `.parent` gives `Contents/` — which is the bundle root for file staging and hashing.

**Key facts (verified against existing codebase):**
- v1 `file_hash.dart` and `update.dart` both use the same pattern: `dir.parent` on macOS
- v1 `prepare.dart` has the same pattern
- All three files have inline `dir.parent` — Phase 3 consolidates this into a single helper `_resolveAppContentsDir()` in `file_hasher.dart`
- **This pattern is identical in all three v1 files** — single consolidation point eliminates duplication and satisfies the PITFALLS.md note: "create a `PlatformPathResolver` in v2"

```dart
// Source: Consolidated from lib/src/file_hash.dart, lib/src/update.dart,
//         lib/src/prepare.dart (all three have identical logic)

/// Returns the app bundle's [Contents/] directory on macOS, or the
/// executable's parent directory on other platforms.
///
/// On macOS, [Platform.resolvedExecutable] points to
/// `MyApp.app/Contents/MacOS/MyApp`, so two [parent] calls reach
/// `MyApp.app/Contents/`, which is the bundle root used for staging
/// and for hashing.
Directory _resolveAppContentsDir([String? overridePath]) {
  final executablePath = overridePath ?? Platform.resolvedExecutable;

  final directoryPath = executablePath.substring(
    0,
    executablePath.lastIndexOf(Platform.pathSeparator),
  );

  var dir = Directory(directoryPath);

  if (Platform.isMacOS) {
    dir = dir.parent;
  }

  return dir;
}
```

### Anti-Patterns to Avoid

- **Temp file write in hash generation:** v1 writes `List<FileHash>` to a temp JSON file then returns the path. Callers read it back and parse JSON. Pointless I/O — refactor to return in-memory list directly.
- **`received = chunk.length` bug:** Critical bug in v1 `download.dart` line 48. Use `+=` not `=`.
- **`print()` calls:** v1 has `print()` in `file_hash.dart`, `download.dart`, `update.dart`, and `prepare.dart`. All must be removed — `avoid_print` lint will fail the build.
- **Nullable list items `List<FileHash?>`:** v1 uses `List<FileHashModel?>` throughout. All engine functions in Phase 3 use non-nullable `List<FileHash>`.
- **`new http.Client()` per file:** v1 creates a new client inside `downloadFile()`. One shared client per download session (created in `downloadFiles()` and closed in `whenComplete()`).
- **Bytes vs KB in progress:** v1 progress stores KB values. Phase 1 `UpdateProgress` model stores raw bytes (see model docstring: "All byte values are in bytes"). Engine must pass raw bytes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Blake2b hashing | Custom hash algorithm | `cryptography_plus` `Blake2b().hash()` | Already in pubspec.yaml, hashes.json format depends on it, API is stable |
| HTTP streaming with progress | Manual socket I/O | `http.Client().send()` + `StreamedResponse.stream` | Already in pubspec.yaml, handles chunked transfer encoding, content-length |
| Mock HTTP in tests | Manual test HTTP server | `http` package `MockClient.streaming()` | Built into the same package already in pubspec.yaml — no extra dep |
| Path manipulation | String manipulation | `package:path` `path.join()`, `path.dirname()` | Already in pubspec.yaml, cross-platform separator handling |
| Staging directory creation | Manual exists check | `Directory.create(recursive: true)` | Single SDK call, creates all intermediate directories |

**Key insight:** Every utility needed for this phase is already in pubspec.yaml. No new packages.

---

## Common Pitfalls

### Pitfall 1: byte-accumulation bug carried forward

**What goes wrong:** v1 `download.dart` line 48: `received = chunk.length` — assignment instead of accumulation. Progress events show only the current chunk size, not total received. UI progress bar oscillates or never reaches 100%.

**Why it happens:** Copy-paste from an example that tracks single-file progress; not noticed because tests don't verify accumulated byte counts.

**How to avoid:** `received += chunk.length`. Add a unit test that sends a multi-chunk mock response and asserts `receivedBytes` equals the sum of all chunk sizes.

**Warning signs:** `receivedBytes` never exceeds `chunk.length` at any single progress event.

---

### Pitfall 2: bytes vs KB in UpdateProgress

**What goes wrong:** v1 `update.dart` stores KB in `totalBytes`/`receivedBytes` (divides by 1024). Phase 1 `UpdateProgress` model docstring says "All byte values are in bytes (not KB/MB) — consumers format for display." Storing KB violates the model contract.

**Why it happens:** v1 was written before the Phase 1 model redefined the units.

**How to avoid:** Pass raw byte values. Use `file.length` (not `file.length / 1024`) for `totalBytes`. Use `chunk.length` (not `chunk.length / 1024`) for chunk accumulation.

**Warning signs:** `totalBytes` equals `file.length / 1024` — a fraction of the actual file size.

---

### Pitfall 3: broadcast stream listener count

**What goes wrong:** Using `StreamController()` (single-subscription) when Phase 4 needs to pass the stream to a consumer who may listen multiple times or pass it around. Single-subscription streams throw `StateError: Stream has already been listened to` on a second `listen()` call.

**Why it happens:** Default `StreamController` is single-subscription.

**How to avoid:** `StreamController.broadcast()`. The Phase 4 public API wraps this stream — using broadcast now prevents the constraint from propagating up.

**Warning signs:** `StateError: Stream has already been listened to` in Phase 4 integration.

---

### Pitfall 4: lint failures from v1 patterns

**What goes wrong:** Direct copy of v1 code into new files fails `flutter analyze` due to `avoid_print`, `prefer_final_locals` (v1 has `var hashList = <FileHashModel>[]`), and `omit_local_variable_types` violations.

**Why it happens:** v1 predates the strict lint configuration.

**How to avoid:** After each file is written, run `flutter analyze lib/src/engine/`. Fix all issues before moving to the next file. Do not copy `print()` calls.

**Warning signs:** `avoid_print`, `prefer_final_locals`, `omit_local_variable_types` lint errors.

---

### Pitfall 5: unawaited_futures lint on Future.wait pattern

**What goes wrong:** `Future.wait(futures).then((_) => controller.close())` without `unawaited()` wrapping causes the `unawaited_futures` lint to fire. The v1 code already uses `unawaited()` correctly — this must be preserved.

**Why it happens:** The stream is returned before the futures complete. We intentionally do not await `Future.wait` at the call site. The lint requires explicit `unawaited()` to signal intentional fire-and-forget.

**How to avoid:** `unawaited(Future.wait(futures).whenComplete(() async { client.close(); await controller.close(); }));`

**Warning signs:** `unawaited_futures` lint error on the `Future.wait` line.

---

### Pitfall 6: close_sinks lint on StreamController

**What goes wrong:** `close_sinks` lint requires `StreamController` to be closed on all code paths. If `Future.wait` throws before `controller.close()`, the sink leaks.

**Why it happens:** `then()` vs `whenComplete()` — `then()` only runs on success; `whenComplete()` runs on both success and error.

**How to avoid:** Use `.whenComplete()` to close both the `http.Client` and `StreamController`. Alternatively use `try/finally` around `Future.wait`.

**Warning signs:** `close_sinks` lint warning on the StreamController variable.

---

### Pitfall 7: macOS path resolution in tests

**What goes wrong:** `generateLocalFileHashes()` calls `Platform.resolvedExecutable` which returns the test binary path during `flutter test`. The function tries to scan the test runner's directory, not a mock app bundle. Tests pass in CI but scan unexpected files.

**Why it happens:** `Platform.resolvedExecutable` is a real system property, not mockable without dependency injection.

**How to avoid:** Add an optional `String? path` parameter (as in v1 `genFileHashes({String? path})`). Tests pass a temp directory. The `_resolveAppContentsDir([String? overridePath])` helper uses the override when provided.

**Warning signs:** Tests scan the Dart SDK's `bin/` directory or similar unexpected paths.

---

## Code Examples

### Verified: Blake2b hash generation (confirmed API unchanged)

```dart
// Source: cryptography_plus pub.dev documentation (verified 2026-03-26)
// API: Blake2b().hash(List<int> input) → Future<Hash>
// Hash.bytes → List<int>

import "dart:convert";
import "package:cryptography_plus/cryptography_plus.dart";

Future<String> _computeHash(List<int> fileBytes) async {
  final hash = await Blake2b().hash(fileBytes);
  return base64.encode(hash.bytes);
}
```

### Verified: HTTP streaming with MockClient in tests

```dart
// Source: http package pub.dev documentation (verified 2026-03-26)
// MockClient.streaming() — accepts StreamedRequest, returns StreamedResponse

import "package:http/http.dart" as http;
import "package:http/testing.dart";

final mockClient = MockClient.streaming((request, bodyStream) async {
  final body = [1, 2, 3, 4, 5]; // fake file bytes
  return http.StreamedResponse(
    Stream.value(body),
    200,
    contentLength: body.length,
  );
});
```

### Verified: Broadcast StreamController with unawaited Future.wait

```dart
// Source: Dart SDK documentation — dart:async
// StreamController.broadcast() + unawaited() pattern

import "dart:async";

final controller = StreamController<UpdateProgress>.broadcast();

unawaited(
  Future.wait(futures).whenComplete(() async {
    client.close();
    await controller.close();
  }),
);

return controller.stream;
```

### Verified: Directory listing for hash scan

```dart
// Source: dart:io documentation
// dir.list(recursive: true, followLinks: false) — async generator

await for (final entity in dir.list(recursive: true, followLinks: false)) {
  if (entity is File) {
    // process entity
  }
}
```

---

## State of the Art

| Old Approach (v1) | v2 Approach (Phase 3) | Impact |
|-------------------|----------------------|--------|
| `genFileHashes()` writes temp JSON file, returns path | `generateLocalFileHashes()` returns `List<FileHash>` in-memory | Eliminates temp file I/O, simplifies caller, removes temp dir cleanup requirement |
| `verifyFileHashes(String, String)` reads two JSON files | `diffFileHashes(List<FileHash>, List<FileHash>)` pure in-memory | No file I/O, trivially testable with constructed lists |
| `List<FileHashModel?>` nullable items | `List<FileHash>` non-nullable | Eliminates null-check boilerplate at call sites |
| `received = chunk.length` (assignment bug) | `received += chunk.length` | Correct progress accumulation |
| New `http.Client()` per file | Shared `http.Client` per batch | Connection reuse, lower overhead for multi-file deltas |
| `print()` for logging | No logging | Satisfies `avoid_print` lint |
| `Future<Stream<UpdateProgress>>` return type | `Stream<UpdateProgress>` return type | Removes spurious `Future` wrapper — stream is returned immediately, downloads start asynchronously |
| KB in `totalBytes`/`receivedBytes` | Raw bytes in `totalBytes`/`receivedBytes` | Consistent with Phase 1 `UpdateProgress` model spec |

---

## Open Questions

1. **`cryptography_plus` 3.0.0 upgrade timing**
   - What we know: 3.0.0 has no breaking changes to Blake2b API. Phase 7 (CLI-04) is earmarked for the version bump.
   - What's unclear: Whether Phase 3 should run against 2.7.1 (current lock) or bump to 3.0.0 now.
   - Recommendation: Keep 2.7.1 for Phase 3 (API is identical, version bump is low-risk but is CLI scope). Phase 7 bumps it. No impact on Phase 3 code.

2. **Post-download hash verification**
   - What we know: PITFALLS.md flags "Missing post-download hash verification" as a critical security concern. ENG-02 spec says "streams individual changed files from remote URL to local staging" — no explicit re-hash requirement in the requirement text.
   - What's unclear: Whether Phase 3 should add post-download re-verification or leave it for Phase 4 orchestration.
   - Recommendation: Add `_verifyDownloadedFile()` inside `file_downloader.dart` that re-hashes the staged file against the expected `FileHash.hash` after each download completes. This is internal to the downloader, adds one Blake2b call per file, and eliminates a security gap.

3. **`http.Client` injection vs internal instantiation**
   - What we know: For testability, `MockClient.streaming()` must be injectable. The test pattern requires passing a client.
   - What's unclear: Whether the public `downloadFiles()` function signature should expose `http.Client` as an optional parameter or use an internal factory.
   - Recommendation: Add `http.Client? client` as an optional named parameter with `client ?? http.Client()` as the default. Tests pass `MockClient.streaming()`. Production uses the default. This is the established pattern in the `http` package's own docs.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 3 is a pure Dart code refactoring. No external tools, services, databases, or CLI utilities beyond the project's existing Flutter/Dart SDK are required. All packages are already in pubspec.yaml.

---

## Sources

### Primary (HIGH confidence)

- `lib/src/file_hash.dart` — existing v1 Blake2b hash implementation (inspected 2026-03-26)
- `lib/src/download.dart` — existing v1 HTTP streaming download (inspected 2026-03-26)
- `lib/src/update.dart` — existing v1 StreamController progress pattern (inspected 2026-03-26)
- `lib/src/models/file_hash.dart` — Phase 1 FileHash model (inspected 2026-03-26)
- `lib/src/models/update_progress.dart` — Phase 1 UpdateProgress model (inspected 2026-03-26)
- `lib/src/errors/update_error.dart` — Phase 1 sealed UpdateError hierarchy (inspected 2026-03-26)
- `lib/src/update_source.dart` — Phase 2 UpdateSource interface (inspected 2026-03-26)
- `analysis_options.yaml` — 87 enforced lint rules (inspected 2026-03-26)
- `pubspec.lock` — cryptography_plus 2.7.1 confirmed (inspected 2026-03-26)
- https://pub.dev/documentation/cryptography_plus/latest/cryptography_plus/Blake2b-class.html — Blake2b API verified: `hash(List<int>) → Future<Hash>`, `.bytes` unchanged
- https://pub.dev/documentation/http/latest/testing/MockClient-class.html — MockClient.streaming() verified

### Secondary (MEDIUM confidence)

- `.planning/research/ARCHITECTURE.md` — engine layer split design (2026-03-26)
- `.planning/research/PITFALLS.md` — macOS path resolution, terminate race, temp dir cleanup (2026-03-26)
- https://pub.dev/packages/cryptography_plus/changelog — 3.0.0 changelog: no Blake2b breaking changes listed
- https://pub.dev/packages/http/changelog — http 1.6.0 latest, MockClient stable

### Tertiary (LOW confidence)

- WebSearch: dart StreamController broadcast vs single-subscription — community consensus aligns with Dart official docs

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already in pubspec.yaml, versions verified from lockfile and pub.dev
- Architecture: HIGH — patterns refactored from existing v1 code, no new paradigms introduced
- Blake2b API stability: HIGH — verified against pub.dev documentation, changelog shows no breaking changes
- Pitfalls: HIGH — byte bug verified by code inspection (line 48 download.dart), lint violations verified against analysis_options.yaml
- Testing strategy: HIGH — MockClient.streaming() verified from official http package docs

**Research date:** 2026-03-26
**Valid until:** 2026-04-26 (stable domain — cryptography_plus API unlikely to change; valid until next major version)
