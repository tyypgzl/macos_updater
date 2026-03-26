# Technology Stack

**Analysis Date:** 2026-03-26

## Languages

**Primary:**
- Dart 3.6.0+ - Core plugin logic and Flutter widgets
- Swift - macOS native implementation
- C++ - Windows native implementation
- C - Linux native implementation

**Secondary:**
- Dart (CLI) - Build tooling for `release` and `archive` commands

## Runtime

**Environment:**
- Flutter 3.3.0+
- Dart 3.6.0+ SDK

**Package Manager:**
- Pub (Dart package manager)
- Lockfile: `pubspec.lock` present

## Frameworks

**Core:**
- Flutter 3.3.0+ - Cross-platform mobile/desktop framework

**Testing:**
- flutter_test (from SDK) - Unit and widget testing
- integration_test (from SDK) - Integration testing

**Build/Dev:**
- flutter_lints 5.0.0 - Linting rules and analysis

## Key Dependencies

**Critical:**
- http 1.2.2 - HTTP client for downloading updates and fetching app-archive.json
- archive 4.0.2 - Archive handling for update packages
- path 1.9.0 - Cross-platform path utilities
- plugin_platform_interface 2.0.2 - Interface for platform-specific implementations

**Cryptography & Hashing:**
- cryptography_plus 2.7.1 - Core cryptographic operations
- cryptography_flutter_plus 2.3.4 - Flutter-specific crypto (file hashing with Blake2b)

**Utilities:**
- args 2.6.0 - Command-line argument parsing for CLI tools
- pubspec_parse 1.5.0 - Parsing pubspec.yaml for version extraction

## Configuration

**Environment:**
- Configured via `environment` block in `pubspec.yaml`
- SDK version: ^3.6.0
- Flutter version: >=3.3.0
- No .env file-based configuration detected

**Build:**
- `pubspec.yaml` - Main package manifest
- `analysis_options.yaml` - Linter configuration with Flutter-specific rules
- Platform-specific build files:
  - `macos/desktop_updater/Package.swift` - macOS Swift package configuration
  - Windows and Linux CMake/native build configurations in respective directories

## Platform Support

**Supported Platforms:**
- macOS - Native Swift implementation
- Windows - Native C++ implementation
- Linux - Native C implementation

**Plugin Architecture:**
- Uses platform channels via `plugin_platform_interface`
- macOS: `DesktopUpdaterPlugin` class
- Windows: `DesktopUpdaterPluginCApi` (C API variant)
- Linux: `DesktopUpdaterPlugin` class

## Development Environment

**Required Tools:**
- Dart SDK 3.6.0+
- Flutter 3.3.0+
- Platform-specific SDKs:
  - macOS: Xcode with Swift compiler
  - Windows: Visual Studio or C++ build tools
  - Linux: GCC/Clang C++ compiler

**Linting & Code Quality:**
- Analysis via `flutter analyze` using `flutter_lints` rules
- 87 active linter rules configured in `analysis_options.yaml`
- Strict enforcement: always declare return types, package imports, avoid dynamic calls, require API docs

## CLI Tools

**Build Commands:**
- `dart pub global activate desktop_updater` - Install as global CLI tool
- `dart run desktop_updater:release [platform]` - Prepare release build
- `dart run desktop_updater:archive [platform]` - Create distributable archive

**Execution:**
- CLI scripts in `bin/` directory:
  - `bin/release.dart` - Release build preparation
  - `bin/archive.dart` - Archive creation
  - `bin/helper/copy.dart` - File copying utility

## Testing Configuration

**Test Locations:**
- Unit/widget tests: `example/test/` and `test/`
- Integration tests: `example/integration_test/`
- Platform-specific native tests:
  - `windows/test/desktop_updater_plugin_test.cpp`
  - `linux/test/` directory
  - macOS tests via Xcode/Swift

---

*Stack analysis: 2026-03-26*
