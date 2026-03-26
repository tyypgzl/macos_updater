# Requirements: Desktop Updater v2.0.0

**Defined:** 2026-03-26
**Core Value:** Reliable, delta-based OTA updates for macOS desktop Flutter apps

## v1 Requirements

Requirements for v2.0.0 release. Each maps to roadmap phases.

### Data Models

- [x] **MODEL-01**: `UpdateInfo` model with version, buildNumber, remoteBaseUrl, and changedFiles list
- [x] **MODEL-02**: `FileHash` model with filePath, hash, and length (non-nullable, clean)
- [x] **MODEL-03**: `UpdateProgress` model with totalBytes, receivedBytes, currentFile, completedFiles, totalFiles
- [x] **MODEL-04**: Sealed `UpdateError` with subtypes: `NetworkError`, `HashMismatch`, `NoPlatformEntry`, `IncompatibleVersion`, `RestartFailed`
- [x] **MODEL-05**: Sealed `UpdateCheckResult` with `UpToDate` and `UpdateAvailable(UpdateInfo)` variants

### Core API

- [ ] **API-01**: `abstract interface class UpdateSource` with `getLatestUpdateInfo()` returning typed `UpdateInfo?`
- [ ] **API-02**: `UpdateSource.getRemoteFileHashes(String remoteBaseUrl)` returning `List<FileHash>`
- [ ] **API-03**: `checkForUpdate(UpdateSource source)` function that compares local vs remote version and returns delta file list
- [ ] **API-04**: `downloadUpdate(UpdateInfo info, {onProgress callback})` function that downloads only changed files with streaming progress
- [ ] **API-05**: `applyUpdate()` function that triggers native restart via method channel
- [x] **API-06**: `getCurrentVersion()` function exposed on platform interface returning build number string
- [ ] **API-07**: `generateLocalFileHashes()` function that computes Blake2b hashes for the running app bundle

### Engine

- [ ] **ENG-01**: File hash comparison engine using Blake2b to determine changed files between local and remote
- [ ] **ENG-02**: File downloader that streams individual changed files from remote URL to local staging
- [ ] **ENG-03**: Stream-based update lifecycle emitting progress events during download

### Code Removal

- [ ] **REM-01**: Remove all widget files (update_card.dart, update_dialog.dart, update_widget.dart, update_sliver.dart, update_direct_card.dart)
- [ ] **REM-02**: Remove DesktopUpdaterController (updater_controller.dart)
- [ ] **REM-03**: Remove DesktopUpdateInheritedWidget (desktop_updater_inherited_widget.dart)
- [ ] **REM-04**: Remove DesktopUpdateLocalization (src/localization.dart)
- [ ] **REM-05**: Clean public barrel exports to only expose engine API

### Native Modernization

- [ ] **NAT-01**: Modernize Swift method channel with async/await via Task {} bridging
- [ ] **NAT-02**: Fix terminate() race condition — file operations and relaunch must happen before terminate
- [ ] **NAT-03**: Bump macOS deployment target from 10.14 to 10.15
- [ ] **NAT-04**: Add App Sandbox detection guard with clear error when sandboxed

### CLI & Dependencies

- [ ] **CLI-01**: Simplify release.dart to macOS-only (remove Windows/Linux build paths)
- [ ] **CLI-02**: Simplify archive.dart to macOS-only (remove Windows/Linux archive paths)
- [ ] **CLI-03**: Update SDK constraint to Dart ^3.7.0 / Flutter >=3.29.0
- [ ] **CLI-04**: Update cryptography_plus to 3.x (verify Blake2b API compatibility)
- [ ] **CLI-05**: Update http, archive, flutter_lints, plugin_platform_interface to latest versions
- [ ] **CLI-06**: Remove unused dependencies (args if not needed after CLI simplification)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Future Enhancements

- **FUT-01**: `isMandatory` field on UpdateInfo for consumer-side enforcement
- **FUT-02**: Parallel vs sequential download mode toggle
- **FUT-03**: `prepareUpdate()` helper that computes delta without downloading
- **FUT-04**: EdDSA signature verification of hashes.json
- **FUT-05**: Windows/Linux active support with CI coverage
- **FUT-06**: Rollback support with previous bundle storage

## Out of Scope

| Feature | Reason |
|---------|--------|
| Built-in UI widgets | Consumers own their UI — engine is headless |
| Auto-update without user consent | macOS security concern, anti-pattern |
| Forced restart / mandatory enforcement in engine | Consumer UX decision, not engine's |
| In-process file replacement (no restart) | macOS locks app bundle files while running |
| Real-time chat/notification system | Not related to update engine |
| Built-in rollback | Requires full bundle storage, operational complexity |
| Firebase Remote Config integration | Consumer implements UpdateSource themselves |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MODEL-01 | Phase 1 | Complete |
| MODEL-02 | Phase 1 | Complete |
| MODEL-03 | Phase 1 | Complete |
| MODEL-04 | Phase 1 | Complete |
| MODEL-05 | Phase 1 | Complete |
| API-06 | Phase 1 | Complete |
| API-01 | Phase 2 | Pending |
| API-02 | Phase 2 | Pending |
| ENG-01 | Phase 3 | Pending |
| ENG-02 | Phase 3 | Pending |
| ENG-03 | Phase 3 | Pending |
| API-03 | Phase 4 | Pending |
| API-04 | Phase 4 | Pending |
| API-05 | Phase 4 | Pending |
| API-07 | Phase 4 | Pending |
| REM-01 | Phase 5 | Pending |
| REM-02 | Phase 5 | Pending |
| REM-03 | Phase 5 | Pending |
| REM-04 | Phase 5 | Pending |
| REM-05 | Phase 5 | Pending |
| NAT-01 | Phase 6 | Pending |
| NAT-02 | Phase 6 | Pending |
| NAT-03 | Phase 6 | Pending |
| NAT-04 | Phase 6 | Pending |
| CLI-01 | Phase 7 | Pending |
| CLI-02 | Phase 7 | Pending |
| CLI-03 | Phase 7 | Pending |
| CLI-04 | Phase 7 | Pending |
| CLI-05 | Phase 7 | Pending |
| CLI-06 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 30 total
- Mapped to phases: 30
- Unmapped: 0

---
*Requirements defined: 2026-03-26*
*Last updated: 2026-03-26 after roadmap creation*
