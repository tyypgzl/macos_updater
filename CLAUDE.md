# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Headless Flutter plugin for macOS desktop OTA updates (v2.0.0). Downloads only changed files by comparing Blake2b file hashes. No built-in UI — consumers implement `UpdateSource` to connect any backend and build their own UI using the function-based API.

## Build & Test Commands

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/macos_updater_api_test.dart

# Analyze (lint) — must pass with zero issues
flutter analyze

# Build the example app
cd example && flutter build macos

# CLI: Build release artifacts (requires FLUTTER_ROOT env var)
dart run macos_updater:release macos

# CLI: Generate hashes and prepare archive from dist/
dart run macos_updater:archive macos
```

## Architecture

### Update Flow
1. Consumer implements `UpdateSource` with `getLatestUpdateInfo()` and `getRemoteFileHashes()`
2. `checkForUpdate(source)` calls source, compares `buildNumber` (int), diffs local vs remote Blake2b hashes
3. Returns sealed `UpdateCheckResult`: `UpToDate` or `UpdateAvailable(info)` with changed files list
4. `downloadUpdate(info, onProgress:)` downloads only changed files with streaming progress callback
5. `applyUpdate()` triggers native Swift restart: copy files → relaunch → terminate (fixed race condition from v1)

### Key Layers
- **Models** (`lib/src/models/`): `UpdateInfo`, `FileHash`, `UpdateProgress` — immutable `final class` types
- **Errors** (`lib/src/errors/`): Sealed `UpdateError` (5 subtypes), sealed `UpdateCheckResult`
- **Engine** (`lib/src/engine/`): `FileHasher` (Blake2b diff), `FileDownloader` (HTTP streaming + progress)
- **Contract** (`lib/src/update_source.dart`): `abstract interface class UpdateSource` — consumer implements this
- **Public API** (`lib/src/macos_updater_api.dart`): `checkForUpdate()`, `downloadUpdate()`, `applyUpdate()`, `generateLocalFileHashes()`
- **Platform** (`lib/macos_updater_platform_interface.dart`): Method channel for `restartApp`, `getCurrentVersion` (returns int)
- **Native** (`macos/`): Swift with Task{} bridging, sandbox detection, correct terminate sequence
- **CLI** (`bin/`): macOS-only `release.dart` and `archive.dart`

### macOS Path Resolution
- `Platform.resolvedExecutable` → `.app/Contents/MacOS/Runner`
- Engine resolves to `.app/Contents/` via `dir.parent.parent`
- Update files staged in `.app/Contents/update/`

## Code Style

- Double quotes for strings (`prefer_double_quotes` lint rule)
- Strict analysis with extensive lint rules in `analysis_options.yaml` — zero issues required
- `prefer_final_locals`, `require_trailing_commas`, `omit_local_variable_types` enforced
- `final class` for models, `sealed class` for errors/results
- `abstract interface class` for consumer contracts
- Package imports only (`package:macos_updater/...`), no relative imports

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Desktop Updater**

A Flutter plugin for macOS desktop OTA updates. Downloads only changed files by comparing Blake2b file hashes between local and remote versions. Provides a clean API with an abstract data source pattern so consumers can fetch version/update metadata from any backend (Firebase Remote Config, REST API, local file, etc.).

**Core Value:** Reliable, delta-based OTA updates for macOS desktop Flutter apps — only download what changed, restart seamlessly.

### Constraints

- **SDK**: Flutter 3.29+ / Dart 3.7+ minimum
- **Platform focus**: macOS primary — Windows/Linux native code untouched but kept
- **Breaking change**: This is a major version bump (v2.0.0) — API surface changes completely
- **Backward compatibility**: Not required — clean break from v1 API
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Dart 3.6.0+ - Core plugin logic and Flutter widgets
- Swift - macOS native implementation
- C++ - Windows native implementation
- C - Linux native implementation
- Dart (CLI) - Build tooling for `release` and `archive` commands
## Runtime
- Flutter 3.3.0+
- Dart 3.6.0+ SDK
- Pub (Dart package manager)
- Lockfile: `pubspec.lock` present
## Frameworks
- Flutter 3.3.0+ - Cross-platform mobile/desktop framework
- flutter_test (from SDK) - Unit and widget testing
- integration_test (from SDK) - Integration testing
- flutter_lints 5.0.0 - Linting rules and analysis
## Key Dependencies
- http 1.2.2 - HTTP client for downloading updates and fetching app-archive.json
- archive 4.0.2 - Archive handling for update packages
- path 1.9.0 - Cross-platform path utilities
- plugin_platform_interface 2.0.2 - Interface for platform-specific implementations
- cryptography_plus 2.7.1 - Core cryptographic operations
- cryptography_flutter_plus 2.3.4 - Flutter-specific crypto (file hashing with Blake2b)
- args 2.6.0 - Command-line argument parsing for CLI tools
- pubspec_parse 1.5.0 - Parsing pubspec.yaml for version extraction
## Configuration
- Configured via `environment` block in `pubspec.yaml`
- SDK version: ^3.6.0
- Flutter version: >=3.3.0
- No .env file-based configuration detected
- `pubspec.yaml` - Main package manifest
- `analysis_options.yaml` - Linter configuration with Flutter-specific rules
- Platform-specific build files:
## Platform Support
- macOS - Native Swift implementation
- Windows - Native C++ implementation
- Linux - Native C implementation
- Uses platform channels via `plugin_platform_interface`
- macOS: `MacosUpdaterPlugin` class
- Windows: `MacosUpdaterPluginCApi` (C API variant)
- Linux: `MacosUpdaterPlugin` class
## Development Environment
- Dart SDK 3.6.0+
- Flutter 3.3.0+
- Platform-specific SDKs:
- Analysis via `flutter analyze` using `flutter_lints` rules
- 87 active linter rules configured in `analysis_options.yaml`
- Strict enforcement: always declare return types, package imports, avoid dynamic calls, require API docs
## CLI Tools
- `dart pub global activate macos_updater` - Install as global CLI tool
- `dart run macos_updater:release [platform]` - Prepare release build
- `dart run macos_updater:archive [platform]` - Create distributable archive
- CLI scripts in `bin/` directory:
## Testing Configuration
- Unit/widget tests: `example/test/` and `test/`
- Integration tests: `example/integration_test/`
- Platform-specific native tests:
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- PascalCase for public library files: `MacosUpdater.dart`, `UpdateProgress.dart`
- snake_case for private library files: `file_hash.dart`, `version_check.dart`
- PascalCase for widgets: `UpdateDialog.dart`, `UpdateCard.dart`
- suffixed naming for private implementations: `macos_updater_method_channel.dart`, `macos_updater_platform_interface.dart`
- camelCase for all function names: `updateAppFunction()`, `versionCheckFunction()`, `getFileHash()`
- Descriptive verb-based names: `verifyFileHashes()`, `prepareUpdateAppFunction()`, `downloadFile()`
- camelCase for local variables and parameters: `executablePath`, `directoryPath`, `receivedBytes`
- camelCase for private fields with leading underscore: `_appName`, `_needUpdate`, `_isDownloading`
- CONSTANT_CASE for compile-time constants (rare usage in this codebase)
- PascalCase for classes and models: `FileHashModel`, `ItemModel`, `UpdateProgress`, `MacosUpdaterController`
- PascalCase for exceptions: `HttpException`
- Suffix `Model` for data classes: `AppArchiveModel`, `ChangeModel`
- Suffix `State` for private State classes: `_UpdateDialogListenerState`, `_UpdateCardState`
## Code Style
- Uses package:flutter_lints/flutter.yaml baseline linting configuration
- Double quotes for strings (enforce via `prefer_double_quotes` rule)
- Trailing commas required on multiline constructs (enforce via `require_trailing_commas` rule)
- Maximum line length not strictly enforced at lint level (commented rule: `lines_longer_than_80_chars`)
- Enabled via `analysis_options.yaml` with 60+ strict linter rules
- Key enforced rules:
## Import Organization
- All imports use full package paths: `package:macos_updater/...`
- Import aliasing for namespacing: `import "package:http/http.dart" as http;` and `import "package:path/path.dart" as path;`
- No wildcard or relative imports
## Error Handling
- Throw specific exceptions: `throw Exception("Desktop Updater: App archive do not exist")`
- Throw `HttpException` for HTTP failures: `throw HttpException("Failed to download file: $url")`
- Use explicit error messages with context prefix: "Desktop Updater: [description]"
- Catch-all blocks exist in async operations (see `src/update.dart` line 97-100)
- Stream error handling via `.addError()` on StreamController
## Logging
- Used for user-facing messages: `print("Using url: $appArchiveUrl")`
- Used for progress tracking: `print("Completed: ${file.filePath}")`
- Used for debugging: `print("Skip update: $_skipUpdate")`
- **Note:** Violates `avoid_print` linter rule - should migrate to structured logging
## Comments
- Only on complex or non-obvious logic
- Turkish and English comments mixed throughout codebase (inconsistent)
- Comments on function signatures for parameter explanation (rare)
- Used for public APIs and classes
- Triple-slash `///` comments for documentation
- Primarily on widget classes and public model classes
- Example from `src/localization.dart`:
## Function Design
- Functions range from ~10 lines to 100+ lines
- Complex async operations are in dedicated files: `download.dart`, `version_check.dart`, `file_hash.dart`
- Helper functions are top-level functions, not methods
- Named parameters with `required` keyword for public functions
- Example: `Future<String?> verifyFileHash(String oldHashFilePath, String newHashFilePath)`
- Optional trailing parameters for callbacks: `void Function(double receivedKB, double totalKB)? progressCallback`
- Explicit type annotations required (linter enforced)
- `Future<T>` for async operations
- Nullable return types with `?`: `Future<String?>`, `Future<List<FileHashModel?>>`
- Stream return types for progress updates: `Future<Stream<UpdateProgress>>`
## Module Design
- Main export file: `lib/macos_updater.dart`
- Barrel pattern used: exports key classes and types
- Example:
- `lib/macos_updater.dart` aggregates public API
- Simplifies consumer imports: can import from main package only
## Class Organization
- `const` constructors for immutable classes: `const UpdateDialogListener({...})`
- Named constructor parameters with documentation
- Property initialization in parameter list with proper ordering (sort_constructors_first enforced)
- Private properties use leading underscore: `String? _appName;`
- Getter pattern for readonly access: `String? get appName => _appName;`
- Getters and setters follow encapsulation patterns
- Example from `updater_controller.dart`:
## Immutability & Const
- Models use `const` constructors when all fields are final
- `copyWith()` method pattern for creating modified copies
- Example from `src/app_archive.dart`:
## Type Safety
- Generic type annotations on collections: `List<FileHashModel?>`, `List<Future<dynamic>>`
- Explicit type casting on JSON decoding: `jsonDecode(oldString) as List<dynamic>`
- Null coalescing and null awareness: `element?.filePath ?? ""`, `value?.url`
- Late initialization for variables set after declaration: `late String? currentVersion;`
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Platform-agnostic Dart plugin exposing native functionality via method channels
- Dual-layer approach: high-level Dart API + low-level native platform calls
- Stream-based progressive download tracking
- Model-driven version checking and file hash verification
- Controller-based state management using ChangeNotifier pattern
- Re-usable UI widgets for update presentation
## Layers
- Purpose: Define platform-specific contracts and route calls to native implementations
- Location: `lib/macos_updater_platform_interface.dart`, `lib/macos_updater_method_channel.dart`
- Contains: Abstract platform interface and method channel implementation
- Depends on: Flutter services, plugin_platform_interface
- Used by: Core API layer
- Purpose: Provide high-level public API for version checking, updating, and file operations
- Location: `lib/macos_updater.dart`
- Contains: `MacosUpdater` class wrapping all public operations
- Depends on: Platform abstraction, business logic functions
- Used by: Controller and application code
- Purpose: Implement core update workflows and file operations
- Location: `lib/src/` directory
- Contains: Version checking, download coordination, file hashing, app archive parsing
- Depends on: HTTP client, cryptography libraries, platform I/O
- Used by: Core API layer
- Purpose: Manage UI state and coordinate update workflow
- Location: `lib/updater_controller.dart`
- Contains: `MacosUpdaterController` extending ChangeNotifier
- Depends on: Core API, update progress models
- Used by: UI widgets and application
- Purpose: Present update UI components
- Location: `lib/widget/` directory
- Contains: Dialogs, cards, slivers, and update widgets
- Depends on: State management layer
- Used by: Flutter applications integrating the plugin
## Data Flow
- `MacosUpdaterController` holds all update state
- State includes: version info, download progress, UI flags, release notes
- `ChangeNotifier` pattern allows UI to listen to specific state changes
- `InheritedWidget` pattern via `MacosUpdaterInheritedNotifier` passes controller down tree
## Key Abstractions
- Purpose: Represent platform-specific version information and changes
- Examples: `lib/src/app_archive.dart` defines `AppArchiveModel`, `ItemModel`, `ChangeModel`
- Pattern: JSON-serializable data models with factory constructors
- Purpose: Track file paths and cryptographic hashes for change detection
- Examples: `lib/src/app_archive.dart` defines `FileHashModel`
- Pattern: JSON-serializable, compared by path and hash value
- Purpose: Report incremental download progress
- Examples: `lib/src/update_progress.dart` defines `UpdateProgress`
- Pattern: Immutable data class with byte counts and file metadata
- Purpose: Define contract for native platform implementations
- Examples: `lib/macos_updater_platform_interface.dart`
- Pattern: Abstract base class with platform-specific concrete implementation
## Entry Points
- Location: `lib/macos_updater.dart`
- Triggers: Direct instantiation by applications
- Responsibilities: Expose all update operations, coordinate with platform layer
- Location: `lib/updater_controller.dart`
- Triggers: Construction with archive URL
- Responsibilities: Manage complete update workflow, maintain UI state
- Location: `lib/widget/update_dialog.dart`, `lib/widget/update_widget.dart`, `lib/widget/update_card.dart`
- Triggers: Widget tree placement
- Responsibilities: Display update UI, respond to controller changes, trigger download/restart
- Location: `bin/release.dart`
- Triggers: Command-line invocation with platform argument
- Responsibilities: Build application, generate file hashes, prepare release artifacts
- Location: `bin/archive.dart`
- Triggers: Command-line invocation
- Responsibilities: Create app-archive.json metadata, compute hashes for all files
## Error Handling
- `MacosUpdater` methods throw `Exception` for null/invalid state (e.g., missing archive URL)
- `versionCheckFunction()` validates: directory exists, files downloaded successfully, platform version found
- `updateAppFunction()` catches download errors via `catchError()` and adds to response stream
- `verifyFileHashes()` throws if hash files don't exist
- All HTTP operations check status codes and throw `HttpException` on failure
- Platform calls via method channel can throw if native implementation unavailable
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
