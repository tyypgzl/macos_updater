# Phase 3: Core Engine - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Refactor the existing v1 engine logic (file_hash.dart, download.dart, update.dart) into clean, testable engine functions under `lib/src/engine/`. Three components: FileHasher (Blake2b hash comparison), FileDownloader (HTTP streaming download), and a progress stream that emits UpdateProgress events. These are internal engine functions — the public API wrapper comes in Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion (all areas)
User deferred all decisions to Claude. Research and established patterns guide implementation:

- **Download staging:** Keep existing `app/update/` staging path convention. Engine downloads to `{appDir}/update/{filePath}`.
- **Progress reporting:** Use `Stream<UpdateProgress>` (more composable than callbacks, research recommended). Engine's download orchestrator returns a broadcast stream.
- **File hasher:** Refactor `genFileHashes()` and `verifyFileHashes()` into a `FileHasher` class or top-level functions under `lib/src/engine/file_hasher.dart`. Use new `FileHash` model (non-nullable) instead of `FileHashModel?`.
- **File downloader:** Refactor `downloadFile()` into `lib/src/engine/file_downloader.dart`. Keep HTTP streaming approach. Report per-file progress.
- **Error handling:** All engine functions throw typed `UpdateError` subtypes. `NetworkError` for HTTP failures, `HashMismatch` for integrity issues.
- **Concurrent downloads:** Keep existing parallel download approach (Future.wait on all files).
- **Blake2b implementation:** Continue using `cryptography_plus` package's `Blake2b().hash()`.
- **generateLocalFileHashes():** Refactor `genFileHashes()` to return `List<FileHash>` directly (in-memory) instead of writing to a temp file. The temp file approach was only needed for the old JSON comparison — new code compares in-memory.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Code (to refactor)
- `lib/src/file_hash.dart` — Current `genFileHashes()`, `verifyFileHashes()`, `getFileHash()` functions
- `lib/src/download.dart` — Current `downloadFile()` function with HTTP streaming
- `lib/src/update.dart` — Current `updateAppFunction()` with StreamController<UpdateProgress>

### Phase 1 & 2 Types (dependencies)
- `lib/src/models/file_hash.dart` — New FileHash model (non-nullable, with JSON)
- `lib/src/models/update_progress.dart` — New UpdateProgress model
- `lib/src/errors/update_error.dart` — Sealed UpdateError hierarchy
- `lib/src/update_source.dart` — UpdateSource interface (Phase 2)

### Project Context
- `.planning/PROJECT.md` — Constraints (macOS focus, Dart 3.7+)
- `.planning/REQUIREMENTS.md` — ENG-01, ENG-02, ENG-03 requirements
- `.planning/ROADMAP.md` — Phase 3 success criteria (4 criteria)

### Research
- `.planning/research/ARCHITECTURE.md` — Engine layer split (FileHasher, FileDownloader, VersionChecker)
- `.planning/research/PITFALLS.md` — macOS path resolution, terminate race condition

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Blake2b().hash(fileBytes)` + `base64.encode(hash.bytes)` pattern from `getFileHash()` — keep as-is
- HTTP streaming pattern from `downloadFile()` — refactor but keep core approach
- `Platform.resolvedExecutable` → parent resolution for macOS app bundle — keep logic
- `StreamController<UpdateProgress>` pattern from `updateAppFunction()` — keep stream approach

### Established Patterns
- `package:http/http.dart as http` for HTTP client
- `package:path/path.dart as path` for path operations
- `package:cryptography_plus/cryptography_plus.dart` for Blake2b
- Files under `lib/src/engine/` per D-11

### Integration Points
- Phase 4 public API will call these engine functions
- Engine functions use `FileHash` and `UpdateProgress` models from Phase 1
- Engine functions use `UpdateSource` from Phase 2 (for getRemoteFileHashes)
- `hashes.json` format must remain compatible with CLI tools (archive.dart)

### Known Issues to Fix
- v1 `genFileHashes()` writes to temp file unnecessarily — refactor to in-memory
- v1 `verifyFileHashes()` uses nullable `FileHashModel?` — switch to non-nullable `FileHash`
- v1 `downloadFile()` has a bug: `received = chunk.length` instead of `received += chunk.length`
- v1 uses `print()` for logging — remove (lint rule `avoid_print`)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — Claude decides implementation approach based on research and existing patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-core-engine*
*Context gathered: 2026-03-26*
