# Phase 2: UpdateSource Contract - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Define the `abstract interface class UpdateSource` — the single abstraction that decouples the update engine from any specific backend. Consumers implement this to connect Firebase Remote Config, REST APIs, local files, or any other data source. Also create a `MockUpdateSource` for testing.

</domain>

<decisions>
## Implementation Decisions

### Method Signatures
- **D-14:** `getLatestUpdateInfo()` returns `Future<UpdateInfo?>` — null means app is up-to-date, non-null means update available. Consumer constructs `UpdateInfo` with version, buildNumber, remoteBaseUrl, and empty changedFiles (engine populates changedFiles via hash diffing).
- **D-15:** `getRemoteFileHashes(String remoteBaseUrl)` returns `Future<List<FileHash>>` — engine passes the remoteBaseUrl from UpdateInfo, consumer fetches and parses hashes from their backend.
- **D-16:** Use `abstract interface class` (Dart 3 modifier) — enforces implement-only semantics, consumers cannot extend.

### Error Boundary
- **D-17:** Engine wraps every `UpdateSource` call in try-catch. Unknown exceptions from consumer implementations are caught and mapped to `UpdateError.networkError` (or appropriate subtype). No raw exceptions escape the UpdateSource boundary.
- **D-18:** Consumer does NOT need to throw `UpdateError` — they throw whatever their backend throws, engine handles mapping.

### Claude's Discretion
- File placement (recommendation: `lib/src/update_source.dart` flat under src/)
- Whether to add dartdoc examples showing a sample implementation
- MockUpdateSource test structure and test cases
- Whether `UpdateSource` gets its own barrel export or goes through main barrel

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Types (dependencies)
- `lib/src/models/update_info.dart` — UpdateInfo model that UpdateSource returns
- `lib/src/models/file_hash.dart` — FileHash model that getRemoteFileHashes returns
- `lib/src/errors/update_error.dart` — UpdateError sealed hierarchy for error mapping

### Project Context
- `.planning/PROJECT.md` — Project vision, abstract data source pattern decision
- `.planning/REQUIREMENTS.md` — API-01 and API-02 requirements
- `.planning/ROADMAP.md` — Phase 2 success criteria (3 criteria)

### Research
- `.planning/research/STACK.md` — `abstract interface class` recommendation, Dart 3 modifier rationale
- `.planning/research/ARCHITECTURE.md` — UpdateSource pattern, error boundary design

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `UpdateInfo` model (Phase 1) — returned by `getLatestUpdateInfo()`
- `FileHash` model (Phase 1) — returned by `getRemoteFileHashes()`
- `UpdateError` sealed hierarchy (Phase 1) — used for error mapping at boundary

### Established Patterns
- `final class` with `const` constructors and `@immutable` (Phase 1 convention)
- Package imports: `package:desktop_updater/src/...`
- Double quotes, trailing commas

### Integration Points
- `lib/desktop_updater.dart` barrel — needs to export UpdateSource
- Future Phase 3 engine will call UpdateSource methods and wrap in try-catch

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Research recommended the Firebase Remote Config-like pattern which aligns with the user's original vision.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-updatesource-contract*
*Context gathered: 2026-03-26*
