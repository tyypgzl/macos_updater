# Codebase Concerns

**Analysis Date:** 2026-03-26

## Tech Debt

**Download Progress Tracking Bug:**
- Issue: Progress calculation in `download.dart` resets per chunk instead of accumulating across all chunks
- Files: `lib/src/download.dart` (line 48)
- Impact: Progress bar appears to restart for each file chunk, showing incorrect cumulative progress. Users see jumpy progress updates instead of smooth progress tracking
- Fix approach: Track cumulative `receivedBytes` across all chunks. Change `received = chunk.length` to `received += chunk.length` and maintain a total counter

**Progress Reporting Accuracy Issue:**
- Issue: In `update.dart`, progress callbacks don't accurately track cumulative download across multiple files
- Files: `lib/src/update.dart` (lines 56-66)
- Impact: The `receivedBytes` variable is incremented per callback without resetting between files, causing inaccurate progress reporting that doesn't align with actual download completion
- Fix approach: Reset progress tracking appropriately at file boundaries or use a more granular tracking mechanism

**macOS Platform-Specific Path Logic Inconsistency:**
- Issue: macOS path handling using `dir.parent` is hardcoded in multiple places without validation
- Files: `lib/src/file_hash.dart` (line 88), `lib/src/update.dart` (line 23), `lib/src/version_check.dart` (line 22), `lib/src/prepare.dart` (line 20)
- Impact: Fragile to directory structure changes; if app bundle structure differs, update logic may fail silently or update wrong directories
- Fix approach: Create shared platform-aware path utility function; add validation that parent directory is valid app bundle structure

**Version Comparison Logic:**
- Issue: In `app_archive.dart` line 98, `copyWith` has a bug where `changedFiles ?? changedFiles` returns the original parameter instead of the current value
- Files: `lib/src/app_archive.dart` (line 98)
- Impact: Changed files may not be properly preserved when copying ItemModel; defaults don't work as intended
- Fix approach: Change to `changedFiles ?? this.changedFiles`

## Known Bugs

**Download Accumulation Error:**
- Symptoms: Progress bar jumps erratically during multi-file downloads; total downloaded KB calculation becomes incorrect
- Files: `lib/src/download.dart`, `lib/src/update.dart`
- Trigger: Download multiple files where each file has HTTP chunks; progress callback fires per chunk
- Workaround: Total progress will eventually show correct value after all downloads complete, but intermediate progress is misleading

**macOS Update 1.2.0 Revert:**
- Symptoms: Version 1.2.0 introduced macOS issues that forced reversion in 1.3.0
- Files: All core update logic (affects macOS platform)
- Trigger: Using version 1.2.0 on macOS
- Workaround: Users must downgrade to 1.1.1 or upgrade to 1.3.0+; do not use 1.2.0

**Missing HTTP Error Handling on Hash File Downloads:**
- Symptoms: If hashes.json download fails with non-200 status, exception is thrown but not logged
- Files: `lib/src/prepare.dart` (line 34-45)
- Trigger: Network error or remote file missing when downloading hashes.json
- Workaround: None; update process fails. Check server logs and network connectivity

**Version Comparison Error on Linux:**
- Symptoms: Potential null pointer exception when version.json file doesn't exist or is malformed
- Files: `lib/src/version_check.dart` (lines 89-97)
- Trigger: Linux deployment without proper version.json file in flutter_assets
- Workaround: Ensure version.json is properly bundled in assets directory

## Security Considerations

**Unvalidated HTTP URLs:**
- Risk: No URL validation before making HTTP requests; could be susceptible to URL injection
- Files: `lib/src/download.dart` (line 17), `lib/src/version_check.dart` (lines 35, 121), `lib/src/prepare.dart` (line 32)
- Current mitigation: URLs come from controlled sources (app-archive.json), but no explicit validation
- Recommendations: Validate URLs against whitelist; enforce HTTPS; add certificate pinning for secure channels

**JSON Parsing Without Validation:**
- Risk: Unvalidated JSON deserialization can cause exceptions or unexpected state
- Files: `lib/src/version_check.dart` (line 61), `lib/src/file_hash.dart` (lines 45-54)
- Current mitigation: Basic exception handling for file reads, but JSON structure not validated
- Recommendations: Add schema validation for app-archive.json and hashes.json; handle malformed JSON gracefully

**File Operations Without Permission Checks:**
- Risk: Directory creation and file writes don't check filesystem permissions
- Files: `lib/src/download.dart` (lines 31-33), `lib/src/file_hash.dart` (lines 92-94, 108)
- Current mitigation: Exceptions are thrown if operations fail
- Recommendations: Check write permissions before attempting operations; provide clear error messages

**Temporary Directory Files Not Cleaned:**
- Risk: Temporary directories created during hash generation and version checking may accumulate
- Files: `lib/src/file_hash.dart` (line 94), `lib/src/version_check.dart` (lines 28, 115), `lib/src/prepare.dart` (line 27)
- Current mitigation: System temp directory auto-cleanup (eventually)
- Recommendations: Explicitly clean up temp directories after use; implement temp directory cleanup on app startup

**No Verification of Downloaded Files:**
- Risk: Downloaded files aren't verified against hashes after download completes
- Files: `lib/src/update.dart` (entire function), `lib/src/download.dart` (entire function)
- Current mitigation: Hashes are compared before download (prepareUpdateApp), but not after download
- Recommendations: Re-verify file hashes after download; implement retry logic for failed downloads

## Performance Bottlenecks

**Synchronous File Operations in Async Context:**
- Problem: `lengthSync()` blocks thread when calculating file hashes
- Files: `lib/src/file_hash.dart` (line 120)
- Cause: Using synchronous file operations in async function
- Improvement path: Use `length` property asynchronously or cache during initial read

**Full Directory Traversal for Hash Generation:**
- Problem: Recursively walking entire application directory to generate hashes is slow for large apps
- Files: `lib/src/file_hash.dart` (lines 108-125)
- Cause: No filtering of unnecessary files (caches, temp files, build artifacts)
- Improvement path: Whitelist/blacklist specific directories; skip hidden files and symlinks (already skipping symlinks)

**HTTP Client Lifecycle Management:**
- Problem: Multiple HTTP clients created without proper pooling; clients may not be reused
- Files: `lib/src/version_check.dart` (lines 31, 117), `lib/src/prepare.dart` (line 30), `lib/src/download.dart` (line 16)
- Cause: New client created per download instead of reusing single client
- Improvement path: Use shared HTTP client singleton; implement connection pooling

**Blake2b Hashing for All Files:**
- Problem: Hashing entire application directory on every update check is CPU-intensive
- Files: `lib/src/file_hash.dart` (lines 9-24)
- Cause: Cryptographic hash calculation for every file
- Improvement path: Cache hash results; only re-hash files that might have changed; consider faster hash for initial comparison

**Stream Listening Without Backpressure:**
- Problem: Stream progress callbacks may be called faster than UI can process
- Files: `lib/src/update.dart` (lines 56-66)
- Cause: No rate limiting or backpressure handling
- Improvement path: Buffer progress updates; throttle callback frequency to UI refresh rate

## Fragile Areas

**DesktopUpdaterController State Management:**
- Files: `lib/updater_controller.dart`
- Why fragile: 15+ independent state variables managed with ChangeNotifier; state mutations not atomic. For example, downloading state could finish before progress reaches 100% due to race conditions
- Safe modification: Use immutable state objects or riverpod for reactive state management; group related state
- Test coverage: Only basic unit tests exist; no integration tests for state transitions

**Platform-Specific Path Resolution:**
- Files: `lib/src/update.dart`, `lib/src/file_hash.dart`, `lib/src/version_check.dart`, `lib/src/prepare.dart`
- Why fragile: macOS `.parent` directory assumption works for app bundles but fails if app is in different structure. Linux hardcodes `/proc/self/exe` and assumes specific asset directory structure
- Safe modification: Create PlatformPathResolver class; add unit tests for each platform; document expected directory structures
- Test coverage: No tests for platform-specific paths; could break with small app structure changes

**Update Dialog Rendering in PostFrameCallback:**
- Files: `lib/widget/update_dialog.dart` (lines 71-87)
- Why fragile: Dialog shown via `addPostFrameCallback` which fires on every build; multiple dialogs could queue up
- Safe modification: Add guard to prevent multiple dialog instances; use Navigator.of().maybePop() to ensure single dialog
- Test coverage: No widget tests for dialog behavior under rapid rebuilds

**Error Handling in Stream Controller:**
- Files: `lib/src/update.dart` (lines 97-100)
- Why fragile: Exceptions added to stream but listener may not have subscribed yet; error handling not tested
- Safe modification: Wrap stream creation in try-catch; ensure all error paths have subscribers
- Test coverage: No error path testing; stream error scenarios untested

**JSON Deserialization Without Type Safety:**
- Files: `lib/src/app_archive.dart` (lines 9-16, 44-54), `lib/src/file_hash.dart` (lines 45-54)
- Why fragile: Cast `json["items"]` to `List<dynamic>` without validation; will throw if field missing
- Safe modification: Use freezed or built_value for type-safe JSON models; add validation layer
- Test coverage: No tests for malformed JSON; no validation tests

## Scaling Limits

**Single HTTP Client Connection Pool:**
- Current capacity: One connection per download function call
- Limit: Under heavy concurrent downloads, could exhaust connection limits
- Scaling path: Implement connection pooling via custom HTTP client or use dio package with connection pool support

**Temporary Directory Storage:**
- Current capacity: Multiple temp directories can accumulate (no cleanup)
- Limit: Could fill /tmp partition on long-running applications
- Scaling path: Implement explicit temp cleanup; monitor temp directory size; auto-delete old temp dirs

**In-Memory Hash Lists:**
- Current capacity: Entire application's file hashes loaded into memory as List
- Limit: Large applications (>10GB) with millions of files could exhaust memory
- Scaling path: Stream-based hash processing; lazy evaluation; database-backed hash storage

**Single-Threaded Download Loop:**
- Current capacity: Sequential downloads of files (Future.wait runs concurrently but processes serially)
- Limit: Could be slow for updates with thousands of small files
- Scaling path: Configurable download concurrency; parallel HTTP streams per file

## Dependencies at Risk

**cryptography_plus Package:**
- Risk: External cryptography package; Blake2b implementation could have vulnerabilities
- Impact: If package is abandoned or has security issues, hash verification becomes unreliable
- Migration plan: Switch to `crypto` package (dart-lang official) if needed; implement fallback to SHA256

**http Package Version ^1.2.2:**
- Risk: Version constraint is loose (^1.2.2); HTTP client may have breaking changes in v2
- Impact: Future Flutter updates could pull http v2, causing compilation errors
- Migration plan: Test against http v2; pin version to specific minor version if incompatible

**archive Package ^4.0.2:**
- Risk: Used for app extraction in build process; loose version constraint
- Impact: Breaking changes could break release/archive CLI tools
- Migration plan: Review release.dart and archive.dart compatibility; add tests for compression

## Missing Critical Features

**No Resume/Retry Logic:**
- Problem: If download fails mid-file, entire download restarts from beginning
- Blocks: Unreliable updates on poor network conditions; no delta sync

**No Staging/Rollback Mechanism:**
- Problem: Files updated in-place; if update fails partway, app is in corrupted state
- Blocks: Safe updates; recovery from interrupted updates

**No Update Scheduling:**
- Problem: Updates trigger immediately when detected; no option to schedule for later
- Blocks: User control over update timing; batch updates in low-bandwidth periods

**No Bandwidth Throttling:**
- Problem: Downloads use all available bandwidth
- Blocks: Updates interrupt active user work; no QoS support

**No Update Signing/Verification:**
- Problem: app-archive.json and files not cryptographically signed
- Blocks: Protection against man-in-the-middle attacks; verification of update authenticity

## Test Coverage Gaps

**Download Progress Calculation:**
- What's not tested: Progress accumulation across multiple chunks and files
- Files: `lib/src/download.dart`, `lib/src/update.dart`
- Risk: Progress bugs could go unnoticed; users see broken progress bars
- Priority: High

**Platform-Specific Path Logic:**
- What's not tested: macOS bundle parent directory, Linux /proc/self/exe fallback, Windows path handling
- Files: `lib/src/file_hash.dart`, `lib/src/update.dart`, `lib/src/version_check.dart`
- Risk: Updates fail silently on different app structures; platform-specific bugs in production
- Priority: High

**Error Scenarios:**
- What's not tested: Network failures, missing files, corrupted JSON, permission errors
- Files: `lib/src/download.dart`, `lib/src/version_check.dart`, `lib/src/prepare.dart`
- Risk: Unhelpful error messages; silent failures; no error recovery
- Priority: High

**State Transitions in DesktopUpdaterController:**
- What's not tested: Rapid state changes; concurrent version check and download; skip update behavior
- Files: `lib/updater_controller.dart`
- Risk: State inconsistencies; race conditions; controller behaves unpredictably
- Priority: Medium

**Widget Rendering:**
- What's not tested: Update dialog appears multiple times, card rendering with different constraints, sliver widget integration
- Files: `lib/widget/update_dialog.dart`, `lib/widget/update_card.dart`
- Risk: UI glitches; multiple dialogs; poor user experience
- Priority: Medium

**JSON Deserialization Edge Cases:**
- What's not tested: Missing fields in app-archive.json, malformed hashes.json, empty items array
- Files: `lib/src/app_archive.dart`, `lib/src/file_hash.dart`
- Risk: Exceptions during normal update flow; no graceful degradation
- Priority: Medium

---

*Concerns audit: 2026-03-26*
