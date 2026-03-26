# Coding Conventions

**Analysis Date:** 2026-03-26

## Naming Patterns

**Files:**
- PascalCase for public library files: `DesktopUpdater.dart`, `UpdateProgress.dart`
- snake_case for private library files: `file_hash.dart`, `version_check.dart`
- PascalCase for widgets: `UpdateDialog.dart`, `UpdateCard.dart`
- suffixed naming for private implementations: `desktop_updater_method_channel.dart`, `desktop_updater_platform_interface.dart`

**Functions:**
- camelCase for all function names: `updateAppFunction()`, `versionCheckFunction()`, `getFileHash()`
- Descriptive verb-based names: `verifyFileHashes()`, `prepareUpdateAppFunction()`, `downloadFile()`

**Variables:**
- camelCase for local variables and parameters: `executablePath`, `directoryPath`, `receivedBytes`
- camelCase for private fields with leading underscore: `_appName`, `_needUpdate`, `_isDownloading`
- CONSTANT_CASE for compile-time constants (rare usage in this codebase)

**Types:**
- PascalCase for classes and models: `FileHashModel`, `ItemModel`, `UpdateProgress`, `DesktopUpdaterController`
- PascalCase for exceptions: `HttpException`
- Suffix `Model` for data classes: `AppArchiveModel`, `ChangeModel`
- Suffix `State` for private State classes: `_UpdateDialogListenerState`, `_UpdateCardState`

## Code Style

**Formatting:**
- Uses package:flutter_lints/flutter.yaml baseline linting configuration
- Double quotes for strings (enforce via `prefer_double_quotes` rule)
- Trailing commas required on multiline constructs (enforce via `require_trailing_commas` rule)
- Maximum line length not strictly enforced at lint level (commented rule: `lines_longer_than_80_chars`)

**Linting:**
- Enabled via `analysis_options.yaml` with 60+ strict linter rules
- Key enforced rules:
  - `always_declare_return_types`: All functions must explicitly declare return types
  - `always_use_package_imports`: Use `package:` imports, not relative paths
  - `avoid_print`: Production code should not use `print()` (violations exist in codebase)
  - `prefer_final_locals`: Local variables should be `final` when possible
  - `cascade_invocations`: Use cascade operator for method chaining where applicable
  - `only_throw_errors`: Only throw Error or Exception subclasses
  - `type_annotate_public_apis`: Public APIs must have explicit type annotations
  - `omit_local_variable_types`: Local variable type inference is preferred
  - `use_super_parameters`: Use `super` parameter syntax in constructors (Dart 3.0+)

## Import Organization

**Order:**
1. Dart imports: `import "dart:async"; import "dart:io";`
2. Flutter imports: `import "package:flutter/material.dart";`
3. Package imports: `import "package:http/http.dart" as http;`
4. Same-package imports: `import "package:desktop_updater/...";`

**Path Aliases:**
- All imports use full package paths: `package:desktop_updater/...`
- Import aliasing for namespacing: `import "package:http/http.dart" as http;` and `import "package:path/path.dart" as path;`
- No wildcard or relative imports

## Error Handling

**Patterns:**
- Throw specific exceptions: `throw Exception("Desktop Updater: App archive do not exist")`
- Throw `HttpException` for HTTP failures: `throw HttpException("Failed to download file: $url")`
- Use explicit error messages with context prefix: "Desktop Updater: [description]"
- Catch-all blocks exist in async operations (see `src/update.dart` line 97-100)
- Stream error handling via `.addError()` on StreamController

**Example from `src/file_hash.dart`:**
```dart
try {
  final List<int> fileBytes = await file.readAsBytes();
  final hash = await Blake2b().hash(fileBytes);
  return base64.encode(hash.bytes);
} catch (e) {
  print("Error reading file ${file.path}: $e");
  return "";
}
```

**Example from `src/update.dart`:**
```dart
try {
  // ... operations ...
  return responseStream.stream;
} catch (e) {
  responseStream.addError(e);
  await responseStream.close();
}
```

## Logging

**Framework:** Native `print()` function (no logging framework)

**Patterns:**
- Used for user-facing messages: `print("Using url: $appArchiveUrl")`
- Used for progress tracking: `print("Completed: ${file.filePath}")`
- Used for debugging: `print("Skip update: $_skipUpdate")`
- **Note:** Violates `avoid_print` linter rule - should migrate to structured logging

**Example:**
```dart
print("Latest version: ${latestVersion.shortVersion}");
print("New version found: ${latestVersion.version}");
print("File downloaded to $fullSavePath");
```

## Comments

**When to Comment:**
- Only on complex or non-obvious logic
- Turkish and English comments mixed throughout codebase (inconsistent)
- Comments on function signatures for parameter explanation (rare)

**JSDoc/TSDoc:**
- Used for public APIs and classes
- Triple-slash `///` comments for documentation
- Primarily on widget classes and public model classes
- Example from `src/localization.dart`:
```dart
/// Localization for the update card texts,
/// There are 5 texts that can be localized:
///
/// - updateAvailableText
/// - newVersionAvailableText
class DesktopUpdateLocalization {
```

**Example from `widget/update_dialog.dart`:**
```dart
  /// The background color of the dialog. if null, it will use Theme.of(context).colorScheme.surfaceContainerHigh,
  final Color? backgroundColor;
```

## Function Design

**Size:**
- Functions range from ~10 lines to 100+ lines
- Complex async operations are in dedicated files: `download.dart`, `version_check.dart`, `file_hash.dart`
- Helper functions are top-level functions, not methods

**Parameters:**
- Named parameters with `required` keyword for public functions
- Example: `Future<String?> verifyFileHash(String oldHashFilePath, String newHashFilePath)`
- Optional trailing parameters for callbacks: `void Function(double receivedKB, double totalKB)? progressCallback`

**Return Values:**
- Explicit type annotations required (linter enforced)
- `Future<T>` for async operations
- Nullable return types with `?`: `Future<String?>`, `Future<List<FileHashModel?>>`
- Stream return types for progress updates: `Future<Stream<UpdateProgress>>`

## Module Design

**Exports:**
- Main export file: `lib/desktop_updater.dart`
- Barrel pattern used: exports key classes and types
- Example:
```dart
export "package:desktop_updater/src/app_archive.dart";
export "package:desktop_updater/src/localization.dart";
export "package:desktop_updater/widget/update_dialog.dart";
```

**Barrel Files:**
- `lib/desktop_updater.dart` aggregates public API
- Simplifies consumer imports: can import from main package only

## Class Organization

**Constructor Patterns:**
- `const` constructors for immutable classes: `const UpdateDialogListener({...})`
- Named constructor parameters with documentation
- Property initialization in parameter list with proper ordering (sort_constructors_first enforced)

**Property Declaration:**
- Private properties use leading underscore: `String? _appName;`
- Getter pattern for readonly access: `String? get appName => _appName;`
- Getters and setters follow encapsulation patterns
- Example from `updater_controller.dart`:
```dart
String? _appName;
String? get appName => _appName;

String? _appVersion;
String? get appVersion => _appVersion;
```

## Immutability & Const

**Patterns:**
- Models use `const` constructors when all fields are final
- `copyWith()` method pattern for creating modified copies
- Example from `src/app_archive.dart`:
```dart
ItemModel copyWith({
  String? version,
  int? shortVersion,
  // ... parameters ...
}) {
  return ItemModel(
    version: version ?? this.version,
    shortVersion: shortVersion ?? this.shortVersion,
    // ...
  );
}
```

## Type Safety

**Patterns:**
- Generic type annotations on collections: `List<FileHashModel?>`, `List<Future<dynamic>>`
- Explicit type casting on JSON decoding: `jsonDecode(oldString) as List<dynamic>`
- Null coalescing and null awareness: `element?.filePath ?? ""`, `value?.url`
- Late initialization for variables set after declaration: `late String? currentVersion;`

---

*Convention analysis: 2026-03-26*
