# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter plugin for desktop OTA updates (macOS, Windows, Linux). Downloads only changed files by comparing Blake2b file hashes between local and remote versions. Uses a JSON-based app-archive manifest hosted on any static server (S3, GitHub Pages, etc.) to advertise available versions.

## Build & Test Commands

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/desktop_updater_test.dart

# Analyze (lint)
flutter analyze

# Build the example app
cd example && flutter build macos   # or windows, linux

# CLI: Build release artifacts (requires FLUTTER_ROOT env var)
dart run desktop_updater:release macos    # or windows, linux

# CLI: Generate hashes and prepare archive from dist/
dart run desktop_updater:archive macos    # or windows, linux
```

## Architecture

### Update Flow
1. `DesktopUpdaterController` calls `versionCheckFunction()` with app-archive URL
2. Version check fetches `app-archive.json`, filters by platform, compares `shortVersion` (int) against current build number
3. If newer version exists, downloads remote `hashes.json` and diffs against local file hashes (Blake2b via `cryptography_plus`)
4. Only changed files are downloaded individually via `updateAppFunction()`, which streams `UpdateProgress` events
5. After download completes, `restartApp()` invokes native platform code via method channel to restart the executable

### Key Layers
- **Native platform layer** (`macos/`, `windows/`, `linux/`): Method channel handlers for `restartApp`, `getExecutablePath`, `getCurrentVersion`, `getPlatformVersion`. macOS uses Swift, Windows uses C++, Linux uses C++.
- **Platform interface** (`lib/desktop_updater_platform_interface.dart`): Abstract platform contract. `MethodChannelDesktopUpdater` is the default implementation.
- **Core logic** (`lib/src/`): Pure Dart - version checking, file hashing, downloading, update orchestration. No Flutter dependencies here except through the platform interface.
- **UI widgets** (`lib/widget/`): `DesktopUpdateWidget`, `DesktopUpdateSliver`, `DesktopUpdateDirectCard`, `UpdateDialogListener` - all consume `DesktopUpdaterController` via `DesktopUpdateInheritedWidget`.
- **CLI tools** (`bin/`): `release.dart` builds the app and copies to `dist/`, `archive.dart` generates `hashes.json` for the built artifacts.

### Platform-Specific Paths
- macOS: `Platform.resolvedExecutable` parent is inside `.app/Contents/MacOS/`, so `dir.parent` is used to get the `.app/Contents` root
- Linux: Version is read from `data/flutter_assets/version.json` instead of method channel
- Windows: Build output at `build/windows/x64/runner/Release/`

## Code Style

- Double quotes for strings (`prefer_double_quotes` lint rule)
- Strict analysis with extensive lint rules in `analysis_options.yaml`
- `prefer_final_locals`, `require_trailing_commas`, `omit_local_variable_types` enforced
- Some comments in Turkish (original author's language)
