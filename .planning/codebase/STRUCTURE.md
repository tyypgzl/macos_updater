# Codebase Structure

**Analysis Date:** 2026-03-26

## Directory Layout

```
flutter_desktop_updater/
├── lib/                       # Core plugin source code
│   ├── src/                   # Business logic and utilities
│   │   ├── update.dart        # Download coordination
│   │   ├── version_check.dart # Version checking logic
│   │   ├── download.dart      # HTTP file download
│   │   ├── file_hash.dart     # File hash computation/verification
│   │   ├── app_archive.dart   # Model definitions for metadata
│   │   ├── prepare.dart       # Update preparation
│   │   ├── update_progress.dart # Progress tracking
│   │   └── localization.dart  # UI text localization
│   ├── widget/                # Flutter UI components
│   │   ├── update_dialog.dart # Update confirmation dialog
│   │   ├── update_widget.dart # Main update widget container
│   │   ├── update_card.dart   # Update card display
│   │   ├── update_sliver.dart # Sliver-based layout
│   │   └── update_direct_card.dart # Direct card variant
│   ├── desktop_updater.dart           # Main public API
│   ├── updater_controller.dart        # State management
│   ├── desktop_updater_platform_interface.dart  # Abstract platform contract
│   ├── desktop_updater_method_channel.dart      # Native method binding
│   └── desktop_updater_inherited_widget.dart    # InheritedWidget wrapper
├── bin/                       # CLI tools
│   ├── release.dart           # Build and package application
│   ├── archive.dart           # Create app-archive.json metadata
│   └── helper/
│       └── copy.dart          # File copy utilities
├── example/                   # Example Flutter application
│   ├── lib/
│   │   ├── main.dart          # App entry point
│   │   └── app.dart           # App widget
│   ├── macos/                 # macOS native code
│   ├── windows/               # Windows native code
│   ├── linux/                 # Linux native code
│   └── pubspec.yaml
├── macos/                     # macOS native implementation
│   └── desktop_updater/
│       └── Sources/
│           └── desktop_updater/  # Swift/Objective-C code
├── windows/                   # Windows native implementation
│   └── include/
│       └── desktop_updater/   # C++ headers
├── linux/                     # Linux native implementation
│   ├── include/
│   │   └── desktop_updater/   # C++ headers
│   └── test/                  # Native unit tests
├── test/                      # Dart unit tests
│   ├── desktop_updater_test.dart
│   └── desktop_updater_method_channel_test.dart
├── pubspec.yaml               # Plugin dependencies
├── README.md                  # Plugin documentation
└── CHANGELOG.md               # Version history
```

## Directory Purposes

**lib/:**
- Purpose: Core plugin implementation (public and private code)
- Contains: Dart source files for all layers
- Key files: `desktop_updater.dart` (main API), `updater_controller.dart` (state), `src/` (business logic)

**lib/src/:**
- Purpose: Private business logic and model definitions
- Contains: Update workflow functions, version checking, file operations, data models
- Key files: `version_check.dart`, `update.dart`, `download.dart`, `file_hash.dart`, `app_archive.dart`

**lib/widget/:**
- Purpose: Reusable Flutter UI components
- Contains: Dialog, card, and sliver widgets for update presentation
- Key files: `update_dialog.dart` (primary UI), `update_widget.dart` (container), `update_card.dart` (display)

**bin/:**
- Purpose: Command-line tools for developers
- Contains: Release build script and archive generation utility
- Key files: `release.dart` (builds for platform), `archive.dart` (creates metadata)

**example/:**
- Purpose: Reference implementation showing plugin usage
- Contains: Sample Flutter app with integrated updater
- Key files: `lib/main.dart`, `lib/app.dart`

**macos/, windows/, linux/:**
- Purpose: Platform-specific native code implementations
- Contains: Swift/Objective-C (macOS) and C++ (Windows/Linux) code
- Responsibility: Restart application, provide version info, handle platform-specific paths

**test/:**
- Purpose: Dart unit tests for plugin
- Contains: Mock tests and channel tests
- Key files: `desktop_updater_test.dart`, `desktop_updater_method_channel_test.dart`

## Key File Locations

**Entry Points:**
- `lib/desktop_updater.dart`: Main plugin API class - start here for public interface
- `lib/updater_controller.dart`: State management controller - where app state lives
- `lib/widget/update_dialog.dart`: Primary UI entry - where update UI appears
- `bin/release.dart`: Release tool CLI entry - runs from command line

**Configuration:**
- `pubspec.yaml`: Plugin metadata, version, and dependencies
- `pubspec.yaml` (example): Example app configuration

**Core Logic:**
- `lib/src/version_check.dart`: Version checking against remote archive
- `lib/src/update.dart`: Download orchestration and progress coordination
- `lib/src/download.dart`: Single file HTTP download with streaming
- `lib/src/file_hash.dart`: Blake2b hashing and file change detection
- `lib/src/app_archive.dart`: Data models for version metadata

**State Management:**
- `lib/updater_controller.dart`: All UI state and update workflow coordination
- `lib/desktop_updater_inherited_widget.dart`: Widget tree integration

**Platform Integration:**
- `lib/desktop_updater_platform_interface.dart`: Abstract platform contract
- `lib/desktop_updater_method_channel.dart`: Method channel binding to native code
- `macos/desktop_updater/Sources/desktop_updater/`: Native macOS implementation
- `windows/include/desktop_updater/`: Native Windows implementation
- `linux/include/desktop_updater/`: Native Linux implementation

**Testing:**
- `test/desktop_updater_test.dart`: Core functionality tests
- `test/desktop_updater_method_channel_test.dart`: Platform channel tests
- `example/test/widget_test.dart`: Widget tests
- `linux/test/`: Native Linux tests

## Naming Conventions

**Files:**
- `*_test.dart`: Unit test files - `desktop_updater_test.dart`, `update_progress_test.dart`
- `*.dart`: Source files use lowercase with underscores - `file_hash.dart`, `version_check.dart`
- No camelCase in file names

**Directories:**
- `lib/src/`: Private implementation details (not exported)
- `lib/widget/`: Reusable UI components (exported for public use)
- `macos/, windows/, linux/`: One per platform, native code only

**Classes:**
- PascalCase for all classes: `DesktopUpdater`, `DesktopUpdaterController`, `UpdateProgress`
- Private classes use leading underscore: `_UpdateDialogListenerState`
- Model classes end with Model: `FileHashModel`, `ItemModel`, `ChangeModel`

**Functions:**
- camelCase for functions: `updateAppFunction()`, `versionCheckFunction()`, `downloadFile()`
- Private functions use leading underscore: `_buildUpdateUI()`

**Variables:**
- camelCase for all variables: `downloadProgress`, `isDownloading`, `needUpdate`
- Private variables use leading underscore: `_changedFiles`, `_downloadSize`

## Where to Add New Code

**New Feature (e.g., new update check strategy):**
- Primary code: Create new file in `lib/src/` - `lib/src/my_feature.dart`
- Tests: Add tests in `test/my_feature_test.dart`
- Export: Add export to `lib/desktop_updater.dart` if public-facing

**New UI Widget:**
- Implementation: `lib/widget/my_widget.dart`
- Tests: `test/my_widget_test.dart` or `example/test/widget_test.dart`
- Integration: Export in `lib/desktop_updater.dart` and add to example usage

**New Platform Operation (e.g., get custom app property):**
- Dart interface: Add method to `lib/desktop_updater_platform_interface.dart`
- Dart binding: Add implementation to `lib/desktop_updater_method_channel.dart`
- Dart wrapper: Add public method to `lib/desktop_updater.dart`
- Native code: Implement in `macos/`, `windows/`, `linux/` respectively

**New Command-line Tool:**
- Location: `bin/my_tool.dart`
- Imports: Use `desktop_updater` lib and core Dart packages
- Run: `dart run desktop_updater:my_tool [args]`

**Utilities and Helpers:**
- Shared helpers: `lib/src/utilities.dart` or `lib/src/helpers/my_helper.dart`
- CLI helpers: `bin/helper/my_helper.dart`
- Example helpers: `example/lib/helpers/my_helper.dart`

## Special Directories

**lib/src/:**
- Purpose: Private implementation not exported from plugin
- Generated: No
- Committed: Yes
- Pattern: Only business logic and internal utilities here

**.planning/codebase/:**
- Purpose: Architecture and planning documentation
- Generated: No (manually maintained)
- Committed: No (planning directory excluded)

**build/, .dart_tool/:**
- Purpose: Build artifacts and tool cache
- Generated: Yes (by Flutter/Dart build system)
- Committed: No (.gitignore)

**example/build/, example/.dart_tool/:**
- Purpose: Example app build artifacts
- Generated: Yes
- Committed: No (.gitignore)

---

*Structure analysis: 2026-03-26*
