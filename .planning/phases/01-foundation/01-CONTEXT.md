# Phase 1: Foundation - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish the type vocabulary for the entire v2 codebase: data models (`UpdateInfo`, `FileHash`, `UpdateProgress`), sealed error hierarchy (`UpdateError`), sealed result type (`UpdateCheckResult`), and platform interface (`getCurrentVersion()`). These types are the foundation that all subsequent phases build on.

</domain>

<decisions>
## Implementation Decisions

### Model Design
- **D-01:** Manual `final class` models — no code generation (freezed/json_serializable). Plugin stays dependency-free for build tooling.
- **D-02:** Clean naming without suffixes — `UpdateInfo` not `UpdateInfoModel`, `FileHash` not `FileHashModel`. Cleaner API surface.
- **D-03:** JSON serialization (fromJson/toJson) only on `FileHash` — engine reads/writes `hashes.json` internally. `UpdateInfo` and `UpdateProgress` are constructed by consumers or engine directly, no JSON needed.
- **D-04:** All model fields are `final` with `const` constructors where possible. `copyWith()` methods on models that need mutation patterns.

### Error Type Design
- **D-05:** Sealed `UpdateError implements Exception` with `message` (String) and optional `cause` (Object?) on the base class.
- **D-06:** Subtypes can carry additional typed fields (e.g., `HashMismatch` has `filePath`).
- **D-07:** 5 subtypes: `NetworkError`, `HashMismatch`, `NoPlatformEntry`, `IncompatibleVersion`, `RestartFailed`. No `SandboxError` — `NoPlatformEntry` covers that case.

### Version Comparison
- **D-08:** Version comparison uses `int buildNumber` — simple integer comparison (remote.buildNumber > local). Same approach as v1's `shortVersion`.
- **D-09:** `version` (String) field on `UpdateInfo` is for display only — not used for comparison logic.
- **D-10:** `getCurrentVersion()` returns `int` (build number from native CFBundleVersion on macOS).

### File Organization
- **D-11:** Subdirectory structure under `lib/src/`: `models/`, `errors/`, `engine/` (engine used in Phase 3+).
- **D-12:** Platform interface files stay at `lib/` root level (existing convention).
- **D-13:** Barrel export in `lib/desktop_updater.dart` — single entry point for consumers.

### Claude's Discretion
- Implementation details of `copyWith()` methods
- Whether to use `@immutable` annotation
- Exact field order in constructors
- Whether `UpdateCheckResult` uses factory constructors or named constructors

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Project vision, constraints (Dart 3.7+, macOS focus, breaking v2)
- `.planning/REQUIREMENTS.md` — MODEL-01 through MODEL-05, API-06 requirements for this phase
- `.planning/ROADMAP.md` — Phase 1 success criteria (5 criteria to verify against)

### Existing Code (to replace)
- `lib/src/app_archive.dart` — Current models (`AppArchiveModel`, `ItemModel`, `ChangeModel`, `FileHashModel`) being replaced
- `lib/src/update_progress.dart` — Current `UpdateProgress` model being redesigned
- `lib/desktop_updater_platform_interface.dart` — Platform interface to update with `getCurrentVersion() → int`
- `lib/desktop_updater_method_channel.dart` — Method channel implementation to update

### Research
- `.planning/research/STACK.md` — Dart 3.7 features, `abstract interface class` vs `abstract class`, `final class` recommendations
- `.planning/research/ARCHITECTURE.md` — Layer structure, sealed state patterns
- `.planning/research/PITFALLS.md` — copyWith bug in current code (line 98), sealed class addition is breaking change

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `UpdateProgress` model structure (5 fields: totalBytes, receivedBytes, currentFile, totalFiles, completedFiles) — keep same fields, redesign as `final class`
- `FileHashModel` fields (filePath, calculatedHash, length) — rename to `FileHash`, drop nullable pattern
- Platform interface pattern (`DesktopUpdaterPlatform` + `MethodChannelDesktopUpdater`) — extend with `getCurrentVersion() → int`

### Established Patterns
- Package imports: `package:desktop_updater/...` (enforced by lint)
- Double quotes for strings
- `require_trailing_commas`, `prefer_final_locals`, `omit_local_variable_types`

### Integration Points
- `lib/desktop_updater.dart` barrel export — needs to be updated to export new models instead of old ones
- Method channel `"desktop_updater"` — `getCurrentVersion` already exists, needs return type change from `String?` to `int`

### Known Bugs to Fix
- `copyWith` bug in `ItemModel` line 98: `changedFiles: changedFiles ?? changedFiles` should be `changedFiles ?? this.changedFiles` — must not be reproduced in v2 models

</code_context>

<specifics>
## Specific Ideas

- Models preview format shown and confirmed:
  ```dart
  final class UpdateInfo {
    const UpdateInfo({
      required this.version,
      required this.buildNumber,
      required this.remoteBaseUrl,
      required this.changedFiles,
    });
    final String version;
    final int buildNumber;
    final String remoteBaseUrl;
    final List<FileHash> changedFiles;
  }
  ```
- Error hierarchy preview confirmed with message + cause pattern
- File structure preview confirmed with models/errors/engine subdirectories

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-03-26*
