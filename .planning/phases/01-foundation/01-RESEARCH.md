# Phase 1: Foundation - Research

**Researched:** 2026-03-26
**Domain:** Dart 3.7 type system — sealed classes, final classes, platform interface pattern
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Manual `final class` models — no code generation (freezed/json_serializable). Plugin stays dependency-free for build tooling.
- **D-02:** Clean naming without suffixes — `UpdateInfo` not `UpdateInfoModel`, `FileHash` not `FileHashModel`. Cleaner API surface.
- **D-03:** JSON serialization (fromJson/toJson) only on `FileHash` — engine reads/writes `hashes.json` internally. `UpdateInfo` and `UpdateProgress` are constructed by consumers or engine directly, no JSON needed.
- **D-04:** All model fields are `final` with `const` constructors where possible. `copyWith()` methods on models that need mutation patterns.
- **D-05:** Sealed `UpdateError implements Exception` with `message` (String) and optional `cause` (Object?) on the base class.
- **D-06:** Subtypes can carry additional typed fields (e.g., `HashMismatch` has `filePath`).
- **D-07:** 5 subtypes: `NetworkError`, `HashMismatch`, `NoPlatformEntry`, `IncompatibleVersion`, `RestartFailed`. No `SandboxError` — `NoPlatformEntry` covers that case.
- **D-08:** Version comparison uses `int buildNumber` — simple integer comparison (remote.buildNumber > local). Same approach as v1's `shortVersion`.
- **D-09:** `version` (String) field on `UpdateInfo` is for display only — not used for comparison logic.
- **D-10:** `getCurrentVersion()` returns `int` (build number from native CFBundleVersion on macOS).
- **D-11:** Subdirectory structure under `lib/src/`: `models/`, `errors/`, `engine/` (engine used in Phase 3+).
- **D-12:** Platform interface files stay at `lib/` root level (existing convention).
- **D-13:** Barrel export in `lib/desktop_updater.dart` — single entry point for consumers.

### Claude's Discretion

- Implementation details of `copyWith()` methods
- Whether to use `@immutable` annotation
- Exact field order in constructors
- Whether `UpdateCheckResult` uses factory constructors or named constructors

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MODEL-01 | `UpdateInfo` model with version, buildNumber, remoteBaseUrl, and changedFiles list | `final class` pattern, `const` constructor, `copyWith()` correctness pattern |
| MODEL-02 | `FileHash` model with filePath, hash, and length (non-nullable, clean) | `final class`, `fromJson`/`toJson` with correct JSON key mapping (`"path"` key in hashes.json), non-nullable fields |
| MODEL-03 | `UpdateProgress` model with totalBytes, receivedBytes, currentFile, completedFiles, totalFiles | Port from existing `update_progress.dart`, redesign as `final class`, add `copyWith()` |
| MODEL-04 | Sealed `UpdateError` with subtypes: `NetworkError`, `HashMismatch`, `NoPlatformEntry`, `IncompatibleVersion`, `RestartFailed` | `sealed class implements Exception` pattern, base `message`/`cause` fields, subtype-specific extra fields |
| MODEL-05 | Sealed `UpdateCheckResult` with `UpToDate` and `UpdateAvailable(UpdateInfo)` variants | Two-variant sealed class, factory vs named constructor choice, exhaustive switch |
| API-06 | `getCurrentVersion()` function on platform interface returning build number as int | Change existing `Future<String?>` to `Future<int>` on both abstract and method channel; update method channel invocation type |
</phase_requirements>

---

## Summary

Phase 1 is a pure Dart type-definition phase — no logic, no I/O, no dependencies beyond `plugin_platform_interface`. All six deliverables (three data models, two sealed hierarchies, one platform interface change) are handwritten `final`/`sealed` classes using Dart 3.7 features.

The existing codebase provides direct migration anchors: `FileHashModel` becomes `FileHash` (drop nullable pattern, keep JSON keys), `UpdateProgress` is structurally identical (same 5 fields, just redesigned as a `final class`), and the platform interface already has the `getCurrentVersion()` method — only its return type changes from `Future<String?>` to `Future<int>`. The two entirely new types are `UpdateError` (sealed hierarchy) and `UpdateCheckResult` (two-variant sealed result).

The single highest-risk detail in this phase is the `copyWith()` correctness pattern. The existing `ItemModel.copyWith()` at line 98 contains the bug `changedFiles: changedFiles ?? changedFiles` (parameter shadows itself instead of falling back to `this.changedFiles`). Every new model's `copyWith()` must use `field ?? this.field`, and a unit test asserting round-trip equality must accompany each model.

**Primary recommendation:** Write all six deliverables in the order dictated by their dependency graph (FileHash first because UpdateInfo references it, UpdateError before UpdateCheckResult, models before the platform interface update). Unit-test every `copyWith()` for round-trip equality before moving to Phase 2.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Dart SDK | ^3.7.0 | Sealed classes, final classes, `const` constructors, pattern matching | Dart 3.0 introduced sealed/final/interface modifiers; 3.7 is the project minimum — all features needed here are available |
| plugin_platform_interface | ^2.1.8 | Base class for `DesktopUpdaterPlatform` | flutter.dev canonical package for platform abstraction; already in use |
| flutter_test (SDK) | SDK | Unit tests for models and copyWith correctness | No additional install; part of Flutter SDK |

No new dependencies are introduced in this phase. Phase 1 has zero pub.dev additions — all deliverables are pure Dart class definitions.

**Installation:** No new packages. Existing `pubspec.yaml` dependencies are sufficient.

---

## Architecture Patterns

### Recommended Project Structure (Phase 1 scope)

```
lib/
├── desktop_updater.dart                       # Barrel — update exports in this phase
├── src/
│   ├── models/
│   │   ├── update_info.dart                   # MODEL-01: UpdateInfo final class
│   │   ├── file_hash.dart                     # MODEL-02: FileHash final class (fromJson/toJson)
│   │   └── update_progress.dart               # MODEL-03: UpdateProgress final class
│   └── errors/
│       ├── update_error.dart                  # MODEL-04: sealed UpdateError + 5 subtypes
│       └── update_check_result.dart           # MODEL-05: sealed UpdateCheckResult
├── desktop_updater_platform_interface.dart    # API-06: getCurrentVersion() → Future<int>
└── desktop_updater_method_channel.dart        # API-06: invokeMethod<int>("getCurrentVersion")
```

Note: `lib/src/engine/` directory is created empty (or not yet) — engine files are added in Phase 3.

### Pattern 1: `final class` Data Model

**What:** Model fields are `final`, constructor is `const`, `copyWith()` uses `field ?? this.field`.
**When to use:** All three data models (UpdateInfo, FileHash, UpdateProgress).

```dart
// Source: dart.dev/language/class-modifiers + D-01, D-04 decisions
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

  UpdateInfo copyWith({
    String? version,
    int? buildNumber,
    String? remoteBaseUrl,
    List<FileHash>? changedFiles,
  }) {
    return UpdateInfo(
      version: version ?? this.version,
      buildNumber: buildNumber ?? this.buildNumber,
      remoteBaseUrl: remoteBaseUrl ?? this.remoteBaseUrl,
      changedFiles: changedFiles ?? this.changedFiles,
    );
  }
}
```

### Pattern 2: `sealed class` Error Hierarchy

**What:** Base class carries `message` and optional `cause`. Subtypes add typed domain-specific fields. The base class `implements Exception` so it works with Dart's existing exception-handling idioms.
**When to use:** `UpdateError` (MODEL-04).

```dart
// Source: dart.dev/language/class-modifiers, docs.flutter.dev/app-architecture/design-patterns/result
sealed class UpdateError implements Exception {
  const UpdateError({required this.message, this.cause});

  final String message;
  final Object? cause;
}

final class NetworkError extends UpdateError {
  const NetworkError({required super.message, super.cause});
}

final class HashMismatch extends UpdateError {
  const HashMismatch({
    required super.message,
    required this.filePath,
    super.cause,
  });

  final String filePath;
}

final class NoPlatformEntry extends UpdateError {
  const NoPlatformEntry({required super.message, super.cause});
}

final class IncompatibleVersion extends UpdateError {
  const IncompatibleVersion({required super.message, super.cause});
}

final class RestartFailed extends UpdateError {
  const RestartFailed({required super.message, super.cause});
}
```

### Pattern 3: Two-Variant Sealed Result Type

**What:** `UpdateCheckResult` is a sealed class with exactly two variants. Claude's discretion applies to whether named constructors or subclasses are used — subclasses are preferred here for consistency with `UpdateError`.
**When to use:** `UpdateCheckResult` (MODEL-05).

```dart
// Source: docs.flutter.dev/app-architecture/design-patterns/result
sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

final class UpToDate extends UpdateCheckResult {
  const UpToDate();
}

final class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.info);

  final UpdateInfo info;
}

// Consumer usage (exhaustive switch — no default needed):
switch (result) {
  case UpToDate() => showUpToDateMessage(),
  case UpdateAvailable(:final info) => promptDownload(info),
}
```

### Pattern 4: `FileHash` with JSON Serialization

**What:** Only `FileHash` gets `fromJson`/`toJson` (D-03). The JSON key for file path is `"path"` (matching existing `hashes.json` format from `FileHashModel.fromJson` in `app_archive.dart`).
**When to use:** MODEL-02.

```dart
final class FileHash {
  const FileHash({
    required this.filePath,
    required this.hash,
    required this.length,
  });

  factory FileHash.fromJson(Map<String, dynamic> json) {
    return FileHash(
      filePath: json["path"] as String,
      hash: json["calculatedHash"] as String,
      length: json["length"] as int,
    );
  }

  final String filePath;
  final String hash;
  final int length;

  Map<String, dynamic> toJson() {
    return {
      "path": filePath,
      "calculatedHash": hash,
      "length": length,
    };
  }
}
```

**Critical:** The JSON key is `"path"` (not `"filePath"`) and `"calculatedHash"` (not `"hash"`) — these must match the `hashes.json` format produced by the existing CLI tools that are unchanged in this phase.

### Pattern 5: Platform Interface `getCurrentVersion()` Return Type Change

**What:** Change `Future<String?>` to `Future<int>` on both the abstract class and the method channel implementation.
**When to use:** API-06.

In `desktop_updater_platform_interface.dart`:
```dart
Future<int> getCurrentVersion() {
  throw UnimplementedError("getCurrentVersion() has not been implemented.");
}
```

In `desktop_updater_method_channel.dart`:
```dart
@override
Future<int> getCurrentVersion() async {
  final version = await methodChannel.invokeMethod<int>("getCurrentVersion");
  return version!;
}
```

The native Swift side already returns `CFBundleVersion` as an integer via the `"getCurrentVersion"` method channel call — the Dart side was unnecessarily widening it to `String?`. The `!` is safe here because a missing or null version number is a configuration error that should surface loudly.

### Anti-Patterns to Avoid

- **`field ?? field` in copyWith:** The existing bug at `app_archive.dart:98`. Always write `field ?? this.field`. The parameter name and the instance field name are identical — the `??` falls back to the parameter (always null when not passed), not to the existing instance value. This silently drops data.
- **Nullable list items (`List<FileHash?>`):** The v1 pattern throughout the codebase. In v2, `List<FileHash>` is non-nullable. Strip parse failures at the JSON boundary, not downstream.
- **`@immutable` without `const` constructor:** Using `@immutable` annotation is fine for documentation, but it has no enforcement effect unless the constructor is also `const`. All three data models use `const` constructors — the annotation is redundant but harmless.
- **Putting `UpdateCheckResult` variants as factory constructors on the base:** Works, but factory constructors cannot be `const` when they delegate to subclass constructors via `return`. Subclass pattern (as shown above) allows `const` instances.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sealed error hierarchy | Generic `Exception` subclasses | `sealed class UpdateError implements Exception` with typed subtypes | Consumers get exhaustive switch without a default case; compiler enforces all cases are handled |
| Result type | `bool` return + output parameter, or throwing | `sealed class UpdateCheckResult` | Official Flutter recommended pattern; zero external dependency; consumer code is readable |
| Platform abstraction | Custom abstract class | `PlatformInterface` from `plugin_platform_interface` | Required for Flutter plugin ecosystem; provides token-based verification that prevents fake implementations |
| `copyWith()` | Code generation (freezed) | Manual with `field ?? this.field` | D-01 locks out code generation; manual is 3 lines per field, no build step |

**Key insight:** This phase has no logic — it is exclusively type definitions. The temptation to add helper methods, validation, or serialization beyond what D-03 permits must be resisted. Keep models lean; add nothing not explicitly required.

---

## Common Pitfalls

### Pitfall 1: The `copyWith` Parameter-Shadow Bug

**What goes wrong:** `changedFiles: changedFiles ?? changedFiles` — the parameter shadows `this.changedFiles` and the null-coalescing fallback goes to the parameter (which is null when not passed), not the instance field. The existing object's value is silently dropped.
**Why it happens:** Copy-paste in manual `copyWith` implementations; compiles without warning.
**How to avoid:** Always write `field ?? this.field`. The `this.` prefix is load-bearing.
**Warning signs:** Unit test `model.copyWith() == model` fails — a `copyWith()` with no arguments should return a structurally equal object.

### Pitfall 2: Wrong JSON Keys in `FileHash`

**What goes wrong:** Using `"filePath"` as the JSON key instead of `"path"`, or `"hash"` instead of `"calculatedHash"`. The CLI tools (Phase 7) produce `hashes.json` using the existing keys — a mismatch here causes silent parse failures or `Null` cast errors at runtime.
**Why it happens:** Renaming the Dart field (`filePath` instead of `calculatedHash` to `hash`) without checking what the CLI writes.
**How to avoid:** Verify against `FileHashModel.fromJson` in `app_archive.dart` — the existing keys are `"path"`, `"calculatedHash"`, `"length"`. These are the contract between the CLI and engine; keep them stable.
**Warning signs:** `FileHash.fromJson` throws a `TypeError` on a live `hashes.json` file.

### Pitfall 3: Sealed Class Addition Is a Breaking Change

**What goes wrong:** Adding a 6th subtype to `UpdateError` in a v2.x minor version. Every consumer using an exhaustive switch without a default arm gets a compile error.
**Why it happens:** The 5-subtype set looks incomplete at first glance — e.g., "what about download errors?". But `NetworkError` covers download failures. Premature extension urge.
**How to avoid:** Commit to the 5 subtypes locked in D-07. Document that `sealed` means the set is closed. Any future addition is a major version bump.
**Warning signs:** PR or issue saying "add `DownloadError` as a new subtype" — redirect to documenting it as a major version change.

### Pitfall 4: `getCurrentVersion()` Returning Nullable Int

**What goes wrong:** Declaring `Future<int?>` to match the old `Future<String?>` pattern. Downstream callers (Phase 3 version comparison) then need null checks, and `null` has no meaningful semantic — a null version number means the native layer failed.
**Why it happens:** Conservative "stay close to the original" instinct.
**How to avoid:** Return `Future<int>` and throw (or let the PlatformException propagate) if the native layer fails. D-10 specifies `int` not `int?`.
**Warning signs:** Method channel test using `Future.value(null)` as the mock return.

### Pitfall 5: Test File Still References Old Types

**What goes wrong:** The existing `test/desktop_updater_test.dart` imports `FileHashModel` and implements the old `DesktopUpdaterPlatform` interface. After Phase 1 changes, the test file will no longer compile.
**Why it happens:** The test was written for v1. Phase 1 changes the interface contract.
**How to avoid:** Update `test/desktop_updater_test.dart` as part of this phase — replace `MockDesktopUpdaterPlatform` with a v2-compatible mock that implements `Future<int> getCurrentVersion()` and removes the methods being deleted from the platform interface.

---

## Code Examples

### `UpdateProgress` — Port from Existing, Redesign as `final class`

```dart
// Source: lib/src/update_progress.dart (existing) + D-01, D-04
final class UpdateProgress {
  const UpdateProgress({
    required this.totalBytes,
    required this.receivedBytes,
    required this.currentFile,
    required this.totalFiles,
    required this.completedFiles,
  });

  final double totalBytes;
  final double receivedBytes;
  final String currentFile;
  final int totalFiles;
  final int completedFiles;

  UpdateProgress copyWith({
    double? totalBytes,
    double? receivedBytes,
    String? currentFile,
    int? totalFiles,
    int? completedFiles,
  }) {
    return UpdateProgress(
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      currentFile: currentFile ?? this.currentFile,
      totalFiles: totalFiles ?? this.totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
    );
  }
}
```

The 5 fields and their types are identical to the existing `UpdateProgress`. The change is class modifier (`final`) and constructor (`const`).

### Exhaustive Switch on `UpdateError` (Consumer Usage Reference)

```dart
// This MUST compile without a default arm — verifies sealed hierarchy is correct
void handleError(UpdateError error) {
  switch (error) {
    case NetworkError(:final message) => showNetworkError(message),
    case HashMismatch(:final filePath) => showCorruptionError(filePath),
    case NoPlatformEntry(:final message) => showPlatformError(message),
    case IncompatibleVersion(:final message) => showVersionError(message),
    case RestartFailed(:final message) => showRestartError(message),
  }
}
```

If any subtype is missing from the switch, the analyzer reports a non-exhaustive switch — this is the compile-time safety the sealed pattern provides.

### Barrel Export Update

```dart
// lib/desktop_updater.dart — Phase 1 scope (v1 exports removed, new types added)
export "package:desktop_updater/src/models/update_info.dart";
export "package:desktop_updater/src/models/file_hash.dart";
export "package:desktop_updater/src/models/update_progress.dart";
export "package:desktop_updater/src/errors/update_error.dart";
export "package:desktop_updater/src/errors/update_check_result.dart";
```

The v1 exports (`app_archive.dart`, `localization.dart`, `update_dialog.dart`, etc.) are NOT removed in Phase 1 — that is Phase 5 (UI Removal). Phase 1 only adds the new exports alongside the old ones. The barrel is not a breaking API surface change at this stage.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `class FileHashModel` (nullable fields, `Model` suffix) | `final class FileHash` (non-nullable, no suffix) | Dart 3.0 (May 2023) — `final` class modifier available | Non-nullable by default removes null-check noise at call sites |
| `Future<String?> getCurrentVersion()` returning string build number | `Future<int> getCurrentVersion()` | This refactoring (v2.0.0) | Callers no longer need `int.parse()` with FormatException risk |
| Generic `Exception` throws for typed error conditions | `sealed class UpdateError` with exhaustive switch | Dart 3.0 sealed classes (May 2023) | Compile-time exhaustiveness checking replaces runtime instanceof chains |
| `class UpdateProgress` (plain class, mutable possible) | `final class UpdateProgress` with `const` constructor | Dart 3.0 `final` modifier | Prevents subclassing; makes the type self-documenting as a data-only struct |

**Deprecated/outdated in this phase:**
- `FileHashModel`: Replaced by `FileHash`. File `lib/src/app_archive.dart` is the old source — do not import it in new code.
- `ItemModel`, `AppArchiveModel`, `ChangeModel`: These exist only until Phase 5 removes them. New code in Phase 1 does not reference them.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified — this phase is pure Dart class definitions with no CLI tools, services, or runtimes beyond the project's existing Flutter/Dart SDK).

---

## Open Questions

1. **`@immutable` annotation on models**
   - What we know: D-04 specifies `final` fields and `const` constructors. `@immutable` is from `package:meta` (transitive via Flutter).
   - What's unclear: Whether the linter enforces `@immutable` or whether it's optional documentation.
   - Recommendation: Include `@immutable` on all three data models — it's already transitively available, self-documents intent, and the analyzer warns if a subclass adds mutable state. No cost, positive signal.

2. **`UpdateCheckResult` factory vs named constructors vs subclasses**
   - What we know: Claude's discretion per CONTEXT.md. Both approaches produce exhaustive switches.
   - What's unclear: Whether a future developer might want to add a third variant (e.g., `CheckFailed`).
   - Recommendation: Use subclasses (`UpToDate`, `UpdateAvailable`) matching the `UpdateError` pattern — consistency is more valuable than syntactic brevity. `CheckFailed` would be a breaking change either way since the class is `sealed`.

3. **`UpdateInfo.changedFiles` field inclusion**
   - What we know: The model preview in CONTEXT.md shows `changedFiles: List<FileHash>` as a field on `UpdateInfo`.
   - What's unclear: Whether `changedFiles` belongs on `UpdateInfo` (set by consumers when constructing) or is computed by the engine during `checkForUpdate`. In Phase 3, the engine diffs local vs remote hashes to produce the changed file list.
   - Recommendation: Keep `changedFiles` on `UpdateInfo` per the locked preview (D-01 shows the class structure). The engine populates it after diffing; it is part of the result passed to `downloadUpdate`. This is consistent with CONTEXT.md `<specifics>` section.

---

## Sources

### Primary (HIGH confidence)

- `lib/src/app_archive.dart` — Existing `FileHashModel` JSON keys (`"path"`, `"calculatedHash"`, `"length"`) verified by direct file read
- `lib/src/update_progress.dart` — Existing 5-field structure confirmed by direct file read
- `lib/desktop_updater_platform_interface.dart` — Existing `getCurrentVersion()` signature confirmed (`Future<String?>`)
- `lib/desktop_updater_method_channel.dart` — Existing method channel invocation confirmed (`invokeMethod<String>`)
- `.planning/phases/01-foundation/01-CONTEXT.md` — All locked decisions (D-01 through D-13) and model preview
- `.planning/research/STACK.md` — Dart 3.7 class modifiers, sealed class guidance, `final class` rationale (HIGH confidence, verified against dart.dev)
- `.planning/research/ARCHITECTURE.md` — Layer structure, `src/models/` and `src/errors/` file layout
- `.planning/research/PITFALLS.md` — copyWith bug at line 98, sealed class breaking change risk, version comparison fragility

### Secondary (MEDIUM confidence)

- `dart.dev/language/class-modifiers` — `abstract interface`, `sealed`, `final` modifier semantics (referenced in STACK.md, HIGH confidence from primary)
- `docs.flutter.dev/app-architecture/design-patterns/result` — Official sealed `Result<T>` pattern recommendation (referenced in STACK.md)

---

## Project Constraints (from CLAUDE.md)

The following directives from `CLAUDE.md` apply to this phase:

| Directive | Impact on Phase 1 |
|-----------|-------------------|
| Double quotes for all strings (`prefer_double_quotes`) | All new `.dart` files must use `"double quotes"` not single quotes |
| `require_trailing_commas` | All multiline constructor parameter lists must have trailing commas |
| `prefer_final_locals` | Local variables in test code and any helper functions must be `final` |
| `omit_local_variable_types` | Do not write explicit type on `final` local variable declarations where type is inferred |
| All imports use full package paths `package:desktop_updater/...` | New files must import sibling files via `package:desktop_updater/src/...` not relative paths |
| `flutter analyze` must pass | No new analysis warnings; existing warnings not introduced by Phase 1 are not Phase 1's concern |
| `flutter test` to run tests | Tests live in `test/`; run with `flutter test` |
| No freezed / no code generation | D-01 locks this; CLAUDE.md confirms no build_runner in dev workflow |

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; existing Flutter/Dart SDK is sufficient
- Architecture: HIGH — file layout is locked by D-11/D-12/D-13; patterns are standard Dart 3 idioms
- Pitfalls: HIGH — copyWith bug is confirmed by direct code inspection at `app_archive.dart:98`; JSON key mismatch verified by reading both `FileHashModel.fromJson` and the field rename

**Research date:** 2026-03-26
**Valid until:** 2026-09-26 (Dart language spec for sealed/final classes is stable; no churn expected)
