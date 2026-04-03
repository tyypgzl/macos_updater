# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

macOS Updater (v2.2.1) — a headless Flutter plugin for macOS desktop OTA updates. Downloads only changed files by comparing SHA-256 hashes. No built-in UI — consumers implement `UpdateSource` to connect any backend and build their own UI. Version comparison uses semantic versioning via `pub_semver`.

## Build & Test Commands

```bash
# Run all tests (89 tests)
flutter test

# Run a single test file
flutter test test/macos_updater_api_test.dart

# Analyze — must pass with zero issues
flutter analyze

# Build the example app
cd example && flutter build macos

# CLI: Build release (requires FLUTTER_ROOT env var)
dart run macos_updater:release macos

# CLI: Generate hashes.json for built artifact
dart run macos_updater:archive macos
```

## Architecture

### Update Flow
1. Consumer implements `UpdateSource` with `getUpdateDetails()` and `getRemoteFileHashes()`
2. `checkForUpdate(source)` gets platform config, reads `CFBundleShortVersionString`, compares semver via `pub_semver`
3. Returns 3-way sealed `UpdateCheckResult`:
   - `UpToDate` — current >= latest
   - `ForceUpdateRequired(info)` — current < minimum
   - `OptionalUpdateAvailable(info)` — minimum <= current < latest
4. `downloadUpdate(info, onProgress:)` downloads only changed files with progress callback
5. `applyUpdate()` triggers native Swift restart: copy files → relaunch → terminate

### Key Layers
- **Models** (`lib/src/models/`): `UpdateInfo`, `FileHash`, `UpdateProgress`, `PlatformUpdateDetails`, `UpdateDetails`
- **Errors** (`lib/src/errors/`): Sealed `UpdateError` (5 subtypes), sealed `UpdateCheckResult` (3 variants)
- **Engine** (`lib/src/engine/`): `FileHasher` (SHA-256 diff), `FileDownloader` (HTTP streaming + progress)
- **Contract** (`lib/src/update_source.dart`): `abstract interface class UpdateSource`
- **Public API** (`lib/src/macos_updater_api.dart`): `checkForUpdate()`, `downloadUpdate()`, `applyUpdate()`, `generateLocalFileHashes()`
- **Platform** (`lib/macos_updater_platform_interface.dart`): Method channel for `restartApp`, `getCurrentVersion` (returns String — semver)
- **Native** (`macos/`): Swift with Task{} bridging, sandbox detection, correct terminate sequence
- **CLI** (`bin/`): macOS-only `release.dart` and `archive.dart`

### macOS Path Resolution
- `Platform.resolvedExecutable` → `.app/Contents/MacOS/Runner`
- Engine resolves to `.app/Contents/` via `dir.parent.parent`
- Update files staged in `.app/Contents/update/`

## Code Style

- Single quotes for strings (`prefer_single_quotes` lint rule)
- Strict analysis via `analysis_options.yaml` — zero issues required
- `prefer_final_locals`, `require_trailing_commas`, `omit_local_variable_types` enforced
- `lines_longer_than_80_chars` enforced
- `final class` for models, `sealed class` for errors/results
- `abstract interface class` for consumer contracts
- Package imports only (`package:macos_updater/...`), no relative imports
- `@immutable` from `package:meta/meta.dart` (NOT `package:flutter/foundation.dart` — models must be importable by CLI tools via `dart run`)
- `/// doc comments` required on all public members
- `test/**` excluded from analyzer (tests use double quotes from earlier phases)

## Key Dependencies

- `pub_semver` — semver parsing and comparison
- `crypto` — SHA-256 file hashing
- `http` — HTTP streaming for file downloads
- `plugin_platform_interface` — Flutter plugin pattern

## Platform Config JSON

Consumer's backend returns:
```json
{
  "macos": {
    "minimum": "1.0.1",
    "latest": "1.0.2",
    "active": true,
    "url": "https://server.com/updates/1.0.2"
  }
}
```
