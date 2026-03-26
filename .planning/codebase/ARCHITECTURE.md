# Architecture

**Analysis Date:** 2026-03-26

## Pattern Overview

**Overall:** Layered plugin architecture with platform-specific native integration and Flutter UI layer

**Key Characteristics:**
- Platform-agnostic Dart plugin exposing native functionality via method channels
- Dual-layer approach: high-level Dart API + low-level native platform calls
- Stream-based progressive download tracking
- Model-driven version checking and file hash verification
- Controller-based state management using ChangeNotifier pattern
- Re-usable UI widgets for update presentation

## Layers

**Platform Abstraction Layer:**
- Purpose: Define platform-specific contracts and route calls to native implementations
- Location: `lib/desktop_updater_platform_interface.dart`, `lib/desktop_updater_method_channel.dart`
- Contains: Abstract platform interface and method channel implementation
- Depends on: Flutter services, plugin_platform_interface
- Used by: Core API layer

**Core API Layer:**
- Purpose: Provide high-level public API for version checking, updating, and file operations
- Location: `lib/desktop_updater.dart`
- Contains: `DesktopUpdater` class wrapping all public operations
- Depends on: Platform abstraction, business logic functions
- Used by: Controller and application code

**Business Logic Layer:**
- Purpose: Implement core update workflows and file operations
- Location: `lib/src/` directory
- Contains: Version checking, download coordination, file hashing, app archive parsing
- Depends on: HTTP client, cryptography libraries, platform I/O
- Used by: Core API layer

**State Management Layer:**
- Purpose: Manage UI state and coordinate update workflow
- Location: `lib/updater_controller.dart`
- Contains: `DesktopUpdaterController` extending ChangeNotifier
- Depends on: Core API, update progress models
- Used by: UI widgets and application

**UI Layer:**
- Purpose: Present update UI components
- Location: `lib/widget/` directory
- Contains: Dialogs, cards, slivers, and update widgets
- Depends on: State management layer
- Used by: Flutter applications integrating the plugin

## Data Flow

**Version Check Flow:**

1. Application initializes `DesktopUpdaterController` with archive URL
2. Controller calls `checkVersion()` → `DesktopUpdater.versionCheck()`
3. `versionCheckFunction()` in `lib/src/version_check.dart`:
   - Downloads `app-archive.json` from remote URL
   - Extracts platform-specific version from archive
   - Gets current app version via native platform call
   - Downloads `hashes.json` from remote update folder
   - Compares old and new file hashes via `verifyFileHashes()`
   - Returns `ItemModel` with changed files and release notes
4. Controller updates state and notifies listeners
5. UI widgets respond to state changes

**Update Download Flow:**

1. User initiates download via UI
2. Controller calls `downloadUpdate()` → `DesktopUpdater.updateApp()`
3. `updateAppFunction()` in `lib/src/update.dart`:
   - Determines application directory (macOS special case: parent directory)
   - Creates `StreamController<UpdateProgress>` for progress tracking
   - Iterates through changed files
   - For each file: calls `downloadFile()` which:
     - Makes HTTP GET request to remote update folder
     - Streams response to `update/` subdirectory with directory structure
     - Reports chunk-based progress via callback
   - Aggregates progress from all concurrent downloads
   - Streams aggregated `UpdateProgress` objects
4. Controller listens to progress stream and updates download metrics
5. UI displays progress from controller state
6. On completion, user can restart application
7. Native code replaces old files with downloaded updates

**File Verification Flow:**

1. `verifyFileHashes()` in `lib/src/file_hash.dart`:
   - Reads old hashes file (generated at build time)
   - Reads new hashes file (downloaded during version check)
   - Parses both as `List<FileHashModel>`
   - Compares by file path and hash value
   - Returns only changed/new files

**State Management:**

- `DesktopUpdaterController` holds all update state
- State includes: version info, download progress, UI flags, release notes
- `ChangeNotifier` pattern allows UI to listen to specific state changes
- `InheritedWidget` pattern via `DesktopUpdaterInheritedNotifier` passes controller down tree

## Key Abstractions

**Version Metadata:**
- Purpose: Represent platform-specific version information and changes
- Examples: `lib/src/app_archive.dart` defines `AppArchiveModel`, `ItemModel`, `ChangeModel`
- Pattern: JSON-serializable data models with factory constructors

**File Hash Model:**
- Purpose: Track file paths and cryptographic hashes for change detection
- Examples: `lib/src/app_archive.dart` defines `FileHashModel`
- Pattern: JSON-serializable, compared by path and hash value

**Update Progress:**
- Purpose: Report incremental download progress
- Examples: `lib/src/update_progress.dart` defines `UpdateProgress`
- Pattern: Immutable data class with byte counts and file metadata

**Platform Interface:**
- Purpose: Define contract for native platform implementations
- Examples: `lib/desktop_updater_platform_interface.dart`
- Pattern: Abstract base class with platform-specific concrete implementation

## Entry Points

**Plugin Entry:**
- Location: `lib/desktop_updater.dart`
- Triggers: Direct instantiation by applications
- Responsibilities: Expose all update operations, coordinate with platform layer

**Controller Entry:**
- Location: `lib/updater_controller.dart`
- Triggers: Construction with archive URL
- Responsibilities: Manage complete update workflow, maintain UI state

**UI Entry Points:**
- Location: `lib/widget/update_dialog.dart`, `lib/widget/update_widget.dart`, `lib/widget/update_card.dart`
- Triggers: Widget tree placement
- Responsibilities: Display update UI, respond to controller changes, trigger download/restart

**Release Tool Entry:**
- Location: `bin/release.dart`
- Triggers: Command-line invocation with platform argument
- Responsibilities: Build application, generate file hashes, prepare release artifacts

**Archive Tool Entry:**
- Location: `bin/archive.dart`
- Triggers: Command-line invocation
- Responsibilities: Create app-archive.json metadata, compute hashes for all files

## Error Handling

**Strategy:** Exception propagation with validation checks at each layer

**Patterns:**
- `DesktopUpdater` methods throw `Exception` for null/invalid state (e.g., missing archive URL)
- `versionCheckFunction()` validates: directory exists, files downloaded successfully, platform version found
- `updateAppFunction()` catches download errors via `catchError()` and adds to response stream
- `verifyFileHashes()` throws if hash files don't exist
- All HTTP operations check status codes and throw `HttpException` on failure
- Platform calls via method channel can throw if native implementation unavailable

## Cross-Cutting Concerns

**Logging:** Print statements throughout for debug visibility (version checks, downloads, hashes)

**Validation:** Version comparison uses `shortVersion` integers; file comparison uses hash values

**Authentication:** Optional - depends on remote server configuration; not handled by plugin

**File I/O:** Uses `dart:io` for all file operations; respects platform-specific paths (macOS parent directory special case)

**HTTP:** Uses `http` package for all remote file downloads with streaming support

**Cryptography:** Blake2b hash algorithm via `cryptography_plus` for file integrity verification

---

*Architecture analysis: 2026-03-26*
