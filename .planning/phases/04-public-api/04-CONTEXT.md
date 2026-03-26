# Phase 4: Public API - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire engine functions (FileHasher, FileDownloader) and UpdateSource into four clean consumer-facing functions: `checkForUpdate()`, `downloadUpdate()`, `applyUpdate()`, `generateLocalFileHashes()`. Update barrel exports to expose only the v2 engine API. This is the orchestration layer — no new engine logic, just wiring.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion (all areas)
User deferred all decisions. Research and prior phase patterns guide:

- **API style:** Top-level functions in a dedicated file (e.g., `lib/src/desktop_updater_api.dart` or refactor existing `lib/desktop_updater.dart` class). Research recommended function-based API over class instance.
- **checkForUpdate(source):** Calls `source.getLatestUpdateInfo()`, if non-null calls `generateLocalFileHashes()` + `source.getRemoteFileHashes()` + `diffFileHashes()`, returns `UpdateCheckResult` (sealed). Wraps UpdateSource calls in try-catch per D-17.
- **downloadUpdate(info, {onProgress}):** Calls `downloadFiles()` from engine, bridges `Stream<UpdateProgress>` to onProgress callback. Success criteria says "callback receives progress events" so callback style, not raw stream exposure.
- **applyUpdate():** Calls existing `DesktopUpdater().restartApp()` via platform interface. Catches platform exceptions and throws `UpdateError.restartFailed`.
- **generateLocalFileHashes():** Re-exports engine's `generateLocalFileHashes()` as public API.
- **Barrel exports:** Update `lib/desktop_updater.dart` to export v2 types + API functions. v1 exports stay until Phase 5 removes them.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Engine Functions (Phase 3)
- `lib/src/engine/file_hasher.dart` — `generateLocalFileHashes()`, `diffFileHashes()`
- `lib/src/engine/file_downloader.dart` — `downloadFiles()` returning `Stream<UpdateProgress>`

### Types (Phase 1)
- `lib/src/models/update_info.dart` — UpdateInfo model
- `lib/src/models/file_hash.dart` — FileHash model
- `lib/src/models/update_progress.dart` — UpdateProgress model
- `lib/src/errors/update_error.dart` — UpdateError sealed hierarchy
- `lib/src/errors/update_check_result.dart` — UpdateCheckResult sealed type

### Contract (Phase 2)
- `lib/src/update_source.dart` — UpdateSource abstract interface

### Platform Layer
- `lib/desktop_updater.dart` — Current barrel + DesktopUpdater class (has restartApp())
- `lib/desktop_updater_platform_interface.dart` — Platform interface

### Project Context
- `.planning/PROJECT.md` — Constraints
- `.planning/REQUIREMENTS.md` — API-03, API-04, API-05, API-07
- `.planning/ROADMAP.md` — Phase 4 success criteria (5 criteria)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DesktopUpdater.restartApp()` — existing method channel call for app restart
- `DesktopUpdater.getCurrentVersion()` — already returns `Future<int>` (Phase 1)
- All engine functions from Phase 3 ready to wire

### Integration Points
- `lib/desktop_updater.dart` barrel needs v2 API exports added
- Existing `DesktopUpdater` class can be refactored or new top-level functions added alongside

</code_context>

<specifics>
## Specific Ideas

No specific requirements — Claude decides based on research recommendations.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-public-api*
*Context gathered: 2026-03-26*
