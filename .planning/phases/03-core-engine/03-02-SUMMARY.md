---
phase: 03-core-engine
plan: "02"
subsystem: engine
tags: [file-downloader, http-streaming, progress, blake2b, tdd]
dependency_graph:
  requires:
    - "03-01 (file_hasher.dart — FileHash model and engine directory)"
    - "Phase 1 models: FileHash, UpdateProgress, UpdateError"
    - "package:http (http.Client.send + StreamedResponse.stream)"
    - "package:cryptography_plus (Blake2b)"
  provides:
    - "lib/src/engine/file_downloader.dart — downloadFiles() returning Stream<UpdateProgress>"
    - "Post-download Blake2b hash verification per file"
  affects:
    - "Phase 4 orchestrator (consumes downloadFiles)"
tech_stack:
  added: []
  patterns:
    - "Broadcast StreamController for multi-listener stream compatibility"
    - "Local async function downloadOne() for per-file try/catch error isolation"
    - "unawaited(Future.wait(...).whenComplete()) for fire-and-forget parallel downloads"
    - "MockClient.streaming() for unit tests without real HTTP"
    - "Blake2b re-hash after write for post-download integrity verification"
key_files:
  created:
    - lib/src/engine/file_downloader.dart
    - test/engine/file_downloader_test.dart
  modified: []
decisions:
  - "Used local async function downloadOne() instead of .catchError() chain to work around FutureOr<Null> return type constraint while satisfying unnecessary_lambdas lint"
  - "Post-download hash verification added inside _downloadSingleFile — throws HashMismatch on mismatch before returning"
  - "http.Client injected via optional client parameter for testability (MockClient in tests, default http.Client() in production)"
metrics:
  duration: "~10 minutes"
  completed: "2026-03-26"
  tasks: 2
  files: 2
---

# Phase 3 Plan 2: File Downloader Summary

**One-liner:** HTTP streaming file downloader with Blake2b post-download verification, broadcast Stream<UpdateProgress>, and fixed byte accumulation (v1 `+=` bug fix).

## What Was Built

### `lib/src/engine/file_downloader.dart`

Two functions:

**`_downloadSingleFile(client, url, stagingPath, onChunk, expectedHash)`** (private)
- Streams a single file via `http.Client.send()` + `StreamedResponse.stream`
- Calls `onChunk(chunk.length)` for each received chunk
- Throws `NetworkError` on non-200 HTTP status
- Closes file sink in `finally` block (satisfies `close_sinks` lint)
- After write: re-hashes file with Blake2b, throws `HashMismatch` if hash differs

**`downloadFiles({remoteBaseUrl, changedFiles, appDir, client?})`** (public)
- Returns `Stream<UpdateProgress>` directly (not `Future<Stream>`)
- `StreamController<UpdateProgress>.broadcast()` for multi-listener support
- Empty `changedFiles` → stream closes immediately, no events
- `totalBytes` = sum of all `FileHash.length` values (raw bytes, never `/1024`)
- `receivedBytes += chunkBytes` accumulation (v1 critical bug fixed)
- `completedFiles` increments after each file's download future resolves
- Errors emitted via `controller.addError()` — stream does not crash
- `unawaited(Future.wait(...).whenComplete(...))` closes both client and controller

### `test/engine/file_downloader_test.dart`

6 test cases covering all required behaviors:

| Test | Verifies |
|------|----------|
| Empty changedFiles | Stream closes immediately, no events |
| Single file success | Events emitted, final completedFiles == 1 |
| Multi-chunk byte accumulation | receivedBytes == 7 (not 4), confirms += fix |
| HTTP 404 error | NetworkError emitted on stream |
| Client injection | MockClient passed via optional param is called |
| Hash mismatch | HashMismatch emitted when file hash doesn't match |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `.catchError()` chain incompatible with strict lint rules**
- **Found during:** Task 1 implementation
- **Issue:** The plan's suggested `.catchError((error) { controller.addError(error); })` pattern failed three lints simultaneously: `unnecessary_lambdas` (use tearoff), `invalid_return_type_for_catch_error` (void vs FutureOr<Null>), and `argument_type_not_assignable` (StackTrace optional vs required)
- **Fix:** Replaced `.then().catchError()` chain with a local async function `downloadOne(FileHash file)` containing a `try/on Object catch` block. This satisfies all lint rules while preserving identical error-propagation semantics.
- **Files modified:** `lib/src/engine/file_downloader.dart`
- **Commit:** 91d8035

## Verification Results

All plan success criteria met:

```
flutter analyze lib/src/engine/file_downloader.dart   → No issues found
flutter analyze test/engine/file_downloader_test.dart → No issues found
flutter test test/engine/file_downloader_test.dart    → 6/6 tests passed
grep "receivedBytes +=" lib/src/engine/file_downloader.dart → FOUND
grep "print(" lib/src/engine/file_downloader.dart     → (no output — correct)
grep "Stream<UpdateProgress> downloadFiles" lib/src/engine/file_downloader.dart → FOUND
```

## Known Stubs

None. All functionality is fully implemented and verified.

## Self-Check: PASSED

Files created:
- `lib/src/engine/file_downloader.dart` — FOUND
- `test/engine/file_downloader_test.dart` — FOUND

Commits:
- `91d8035` — FOUND (feat: file_downloader.dart implementation)
- `4f5ba80` — FOUND (test: file_downloader_test.dart)
