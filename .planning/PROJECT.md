# Desktop Updater

## What This Is

A Flutter plugin for macOS desktop OTA updates. Downloads only changed files by comparing Blake2b file hashes between local and remote versions. Provides a clean API with an abstract data source pattern so consumers can fetch version/update metadata from any backend (Firebase Remote Config, REST API, local file, etc.).

## Core Value

Reliable, delta-based OTA updates for macOS desktop Flutter apps — only download what changed, restart seamlessly.

## Requirements

### Validated

- ✓ Blake2b file hash diffing for delta updates — existing
- ✓ Streaming download progress tracking — existing
- ✓ Native macOS app restart via method channel — existing
- ✓ CLI release build tool (`dart run desktop_updater:release`) — existing
- ✓ CLI archive/hash generation tool (`dart run desktop_updater:archive`) — existing
- ✓ Platform interface abstraction for native calls — existing
- ✓ Redesigned data models (UpdateInfo, FileHash, UpdateProgress, UpdateError, UpdateCheckResult) — Phase 1
- ✓ getCurrentVersion() returns int buildNumber — Phase 1
- ✓ Abstract UpdateSource interface class with getLatestUpdateInfo() and getRemoteFileHashes() — Phase 2

### Active
- [ ] Remove all UI code (widgets, controller, inherited widget) — consumers own their UI
- [ ] Modernize Dart code (Flutter 3.29+/Dart 3.7+, sealed classes, enhanced enums)
- [ ] Modernize Swift native code (async/await, modern patterns)
- [ ] Simplify CLI tools to macOS-only
- [ ] Update all dependencies to latest compatible versions
- [ ] Expose update lifecycle via clean function-based API (check, prepare, download, restart)
- [ ] Improve error handling (typed errors instead of generic Exceptions)

### Out of Scope

- Windows/Linux native code changes — keep existing but no active development
- Built-in UI widgets — consumers build their own UI
- Built-in HTTP fetching of app-archive.json — replaced by abstract UpdateSource
- Firebase Remote Config integration — consumer implements UpdateSource themselves
- Auto-update without user consent — security concern

## Context

This is an existing pub.dev package (`desktop_updater` v1.4.0) being refactored for a specific macOS Flutter app use case. The current architecture tightly couples version checking to a JSON URL fetch and bundles UI widgets. The refactoring decouples the data source (abstract class pattern like Firebase Remote Config) and removes UI, making the package a pure update engine.

**Existing codebase:**
- Native platform layer (Swift macOS, C++ Windows, C Linux) communicates via method channels
- Core Dart logic handles version comparison, file hashing, and download orchestration
- UI layer (5 widget files + controller + inherited widget) will be removed entirely
- CLI tools (release.dart, archive.dart) will be simplified to macOS-only

**Key technical notes:**
- macOS uses `Platform.resolvedExecutable` parent.parent to find `.app/Contents` root
- Linux reads version from `data/flutter_assets/version.json` (different from macOS/Windows method channel)
- File hashing uses Blake2b via `cryptography_plus`
- Some code comments are in Turkish (original author's language)

## Constraints

- **SDK**: Flutter 3.29+ / Dart 3.7+ minimum
- **Platform focus**: macOS primary — Windows/Linux native code untouched but kept
- **Breaking change**: This is a major version bump (v2.0.0) — API surface changes completely
- **Backward compatibility**: Not required — clean break from v1 API

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Abstract UpdateSource instead of URL-based config | Flexibility — consumers use any backend (Firebase, REST, local) | — Pending |
| Remove all UI code | Separation of concerns — consumers own their UI, package is pure engine | — Pending |
| Redesign data models from scratch | Current models carry unnecessary fields (appName, changes, date, mandatory) tied to old JSON format | — Pending |
| macOS-only focus, keep other platforms passive | Main use case is macOS; no breaking changes to Windows/Linux native code | — Pending |
| Flutter 3.29+ / Dart 3.7+ minimum | Leverage sealed classes, enhanced enums, modern patterns | — Pending |
| Modernize Swift native code | Align with modern Swift async/await patterns | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-26 after Phase 2 completion*
