# Phase 7: CLI & Dependencies - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Simplify CLI tools (release.dart, archive.dart) to macOS-only by removing Windows/Linux code paths. Bump SDK constraint to Dart 3.7+/Flutter 3.29+. Update all dependencies to latest compatible versions. Remove unused dependencies.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion (all areas)

- **CLI simplification:** Remove Windows/Linux platform checks and build paths from `bin/release.dart` and `bin/archive.dart`. Keep only macOS logic. Simplify the platform argument validation to only accept "macos".
- **SDK constraint:** Update `pubspec.yaml` environment to `sdk: ">=3.7.0 <4.0.0"` and `flutter: ">=3.29.0"`.
- **Dependency updates:** Update to latest compatible:
  - `cryptography_plus` → `^3.0.0` (verify Blake2b API unchanged — research confirmed it is)
  - `cryptography_flutter_plus` → `^3.0.0`
  - `http` → latest (currently 1.2.2)
  - `archive` → latest (currently 4.0.2)
  - `flutter_lints` → latest (currently 5.0.0)
  - `plugin_platform_interface` → latest (currently 2.0.2)
  - `path` → latest (currently 1.9.0)
  - `pubspec_parse` → latest (currently 1.5.0)
- **Remove unused deps:** Check if `args` package is still needed after CLI simplification. Remove if not imported.
- **archive.dart refactoring:** The archive CLI still uses old `FileHashModel` references — must update to use new `FileHash` model from `lib/src/models/file_hash.dart` or keep its own local hash generation (since CLI runs independently of the Flutter plugin).
- **pubspec.yaml platforms:** Keep `macos`, `windows`, `linux` in platforms section (native code still exists for Windows/Linux even if untouched).
- **Version bump:** Update package version in pubspec.yaml to `2.0.0`.

</decisions>

<canonical_refs>
## Canonical References

### CLI Files
- `bin/release.dart` — Release build CLI (remove Windows/Linux paths)
- `bin/archive.dart` — Archive/hash CLI (remove Windows/Linux paths, update FileHash references)
- `bin/helper/copy.dart` — Copy utility used by archive

### Package Config
- `pubspec.yaml` — SDK constraint, dependencies, version
- `analysis_options.yaml` — Lint config (may need flutter_lints version update)

### v2 Models (for archive.dart)
- `lib/src/models/file_hash.dart` — New FileHash model

### Research
- `.planning/research/STACK.md` — Recommended dependency versions, cryptography_plus 3.x compatibility

### Project Context
- `.planning/REQUIREMENTS.md` — CLI-01 through CLI-06
- `.planning/ROADMAP.md` — Phase 7 success criteria (4 criteria)

</canonical_refs>

<code_context>
## Existing Code Insights

### Known Issues
- `bin/archive.dart` imports old `lib/src/app_archive.dart` (deleted in Phase 5) — needs fix
- `bin/archive.dart` uses `FileHashModel` (old name) — needs update to `FileHash` or local type
- CLI files may have broken imports after Phase 5 deletions

### Integration Points
- CLI tools are standalone Dart scripts — they don't import Flutter plugin barrel
- `archive.dart` has its own `genFileHashes()` function that duplicates logic from engine
- `hashes.json` format must remain compatible with engine's `FileHash.fromJson()`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — standard updates.

</specifics>

<deferred>
## Deferred Ideas

None

</deferred>

---

*Phase: 07-cli-dependencies*
*Context gathered: 2026-03-27*
