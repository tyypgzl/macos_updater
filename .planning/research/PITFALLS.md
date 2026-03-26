# Pitfalls Research

**Domain:** Flutter macOS desktop plugin — major version refactoring (v1 to v2)
**Researched:** 2026-03-26
**Confidence:** HIGH (most pitfalls are confirmed against Apple documentation, Dart language spec, and codebase inspection)

---

## Critical Pitfalls

### Pitfall 1: macOS Code Signature Invalidation on File Replacement

**What goes wrong:**
The current `restartApp()` Swift implementation copies files from `Contents/update/` directly into `Contents/` using `FileManager.replaceItem`. This invalidates the app bundle's code signature. On macOS Ventura and later, Gatekeeper blocks the next launch of any notarized app whose signature is no longer valid — even if the quarantine extended attribute has been removed. The app silently fails to reopen after the update.

**Why it happens:**
Developers treat the app bundle like a regular directory. Every file inside a signed bundle is covered by the `_CodeSignature/CodeResources` sealed manifest. Replacing even a single binary file without re-signing breaks the seal. This was a documented cause of the 1.2.0 macOS reversion (see CONCERNS.md).

**How to avoid:**
- Downloaded update files must be staged outside the app bundle (e.g., `~/Library/Application Support/<app>/pending-update/`)
- After file replacement, the entire app bundle must be re-signed with `codesign -f -s "Developer ID Application: ..." --options runtime --deep`
- If the app is notarized, re-signing may require a full notarization round-trip (not possible at runtime for end-user installs)
- The pragmatic approach: document that consumers must distribute un-sandboxed, un-notarized builds, OR design the update to replace the entire `.app` bundle atomically (like Sparkle does) rather than individual files inside it
- At minimum, add a hardened runtime entitlement check before attempting file replacement and surface a clear error if the operation will invalidate the signature

**Warning signs:**
- Update completes but app does not relaunch
- macOS shows "App is damaged and can't be opened" or "Developer cannot be verified"
- `codesign --verify --deep --strict MyApp.app` reports "main executable failed strict validation"
- CONCERNS.md already documents the 1.2.0 macOS reversion — this is the most likely root cause

**Phase to address:** API/core refactoring phase (the restart mechanism is central; document the signing constraint explicitly in README and code comments before shipping v2)

---

### Pitfall 2: Sealed Class Addition = Compile-Breaking Change for All Consumers

**What goes wrong:**
If v2 exposes result types or state types as `sealed` classes (e.g., `sealed class UpdateResult`, `sealed class UpdateError`), then adding any new subtype in a future v2.x patch is a **hard breaking change** for every consumer. Their `switch` statements become non-exhaustive and their code stops compiling. This is equivalent to adding a new value to an enum.

**Why it happens:**
Sealed classes are attractive for expressing update lifecycle states. Developers use them without recognising that adding subtypes later is a compile-time breaking change for downstream code — the same as removing a method from an interface.

**How to avoid:**
- Use `sealed` only for states that are definitively closed and will never gain new variants (e.g., a two-state success/failure result that is inherently complete)
- For types likely to grow (e.g., error categories, progress stages), use `final class` hierarchies with a default fallback instead of `sealed`
- Document explicitly which sealed types are stable and which may gain variants
- If `sealed` is used for `UpdateError`, enumerate all error cases during design and commit to that surface before publishing v2.0.0

**Warning signs:**
- Temptation to add a new `UpdateErrorType` subtype in a minor patch
- Consumer code using exhaustive switches without a default arm
- Changelog entry saying "added new error type" in a minor version

**Phase to address:** Data model redesign phase (decide the sealed-vs-final boundary before writing any new models)

---

### Pitfall 3: NSApplication.terminate() Does Not Return — Code After It Never Runs

**What goes wrong:**
The current `restartApp()` Swift implementation calls `NSApplication.shared.terminate(nil)` and then immediately calls `FileManager` copy operations and `Process().run()` to relaunch the app. `terminate()` initiates an asynchronous shutdown sequence — it may not immediately halt execution, but the Cocoa run loop is unwinding. File copy and process launch operations placed after it are unreliable: they may execute partially, not at all, or race against the termination sequence.

**Why it happens:**
`terminate(nil)` looks like a synchronous call but is actually a deferred shutdown. The method posts a termination notification and returns to the caller. Subsequent code executes in an indeterminate state as the app delegate receives `applicationWillTerminate` and the run loop drains. Any async work (file I/O, process launch) scheduled after `terminate` is racing against the OS cleanup.

**How to avoid:**
- Move all file copy operations and the relaunch `Process.run()` call to **before** `terminate(nil)` is called, or
- Use `applicationWillTerminate` delegate callback to sequence the relaunch, or
- Use a separate small launcher helper binary/script that is launched first, waits for the parent process to exit, then performs the file replacement and relaunch
- The Sparkle framework uses an XPC-based installer service precisely to avoid this race

**Warning signs:**
- Intermittent update failures where files are partially copied
- App sometimes does not relaunch after update
- `Process.run()` throwing because the executable path is already being replaced

**Phase to address:** Swift native code modernization phase

---

### Pitfall 4: Abstract UpdateSource Async Contract Mismatch

**What goes wrong:**
The abstract `UpdateSource` interface (replacing the current URL-based `versionCheck`) will be called from Dart's async machinery. If the interface declares `Future<UpdateInfo> checkForUpdate()` but a consumer implements it with blocking I/O, HTTP calls on the main isolate, or Firebase SDK calls that require a specific async context, the plugin's internal await chain will block or throw in unexpected ways. Conversely, if the plugin's internal code does not `await` the source's result correctly, version checks silently return stale data.

**Why it happens:**
Abstract data source interfaces look straightforward but the caller and callee must agree on execution context (isolate, threading) and error propagation contract. Firebase Remote Config, for example, throws `FirebaseException` — if the plugin wraps the source call in a bare `try/catch (Exception e)` it will swallow typed errors and expose a generic failure to the consumer.

**How to avoid:**
- Define the `UpdateSource` contract to return typed `Result`-style objects (or use `Either`) rather than throwing; OR document precisely which exceptions propagate through
- Do not assume what a consumer's implementation will throw — all errors from `UpdateSource` methods should be caught and wrapped in the plugin's typed error hierarchy
- Write a `MockUpdateSource` implementation in the plugin's own tests to verify the contract is actually callable and that errors are handled

**Warning signs:**
- `UpdateSource.checkForUpdate()` silently returning null when Firebase throws
- Consumer reporting "update check hangs forever" (no timeout on source call)
- Stack traces showing Firebase exceptions leaking through plugin code

**Phase to address:** API design phase (define the `UpdateSource` interface contract, including error semantics, before writing any implementation)

---

### Pitfall 5: Removing UI Exports Without a Deprecation Window Breaks Consumers Immediately

**What goes wrong:**
The current `desktop_updater.dart` barrel file directly exports `update_dialog.dart`, `update_direct_card.dart`, `update_sliver.dart`, and `desktop_updater_inherited_widget.dart`. Removing these exports in v2.0.0 with no shim means any consumer using `import 'package:desktop_updater/desktop_updater.dart'` gets compile errors on every widget reference. Since this is a major version bump this is technically acceptable, but without a migration guide, consumers have no path forward.

**Why it happens:**
Package authors remove internal UI code and assume "it's a major version, consumers expected this." In practice, consumers have integrated the widgets deeply (InheritedWidget for state propagation, the dialog's `addPostFrameCallback` pattern) and rebuilding that layer is non-trivial without documentation.

**How to avoid:**
- Write a migration guide (CHANGELOG entry + README section) that explicitly lists removed symbols and provides the equivalent code consumers must write themselves
- Consider keeping the barrel file with `@Deprecated` re-exports pointing to the new location for one minor version before removal, to surface errors during `pub upgrade` rather than at compile time
- Document the minimum viable consumer-side replacement for each removed widget (e.g., "replace `UpdateDialog` with a manual `StreamBuilder` on `DesktopUpdater.updateStream`")

**Warning signs:**
- CHANGELOG says "removed UI widgets" without a migration example
- README still shows the old widget-based API
- No example app showing the v2 usage pattern

**Phase to address:** UI removal phase (first thing in that phase: write the migration guide before touching any code)

---

### Pitfall 6: macOS App Sandbox Blocks Writing to the App Bundle's Own Contents Directory

**What goes wrong:**
Sandboxed macOS apps cannot write to their own app bundle. The entire `/Applications/MyApp.app/Contents/` tree is outside the sandbox container. Any attempt to write files there results in a silent permission denial or `NSCocoaErrorDomain` error 513 (operation not permitted). The current download-and-stage logic writes to `Contents/update/` from within the running app process — this works only for unsigned/un-sandboxed developer builds. A consumer who enables App Sandbox entitlements (required for Mac App Store distribution) will find the entire update mechanism silently broken.

**Why it happens:**
Development builds of Flutter macOS apps are typically not sandboxed. The plugin works in development, gets published, and only breaks for consumers who try to ship through the Mac App Store or who enable hardened runtime with sandbox entitlement.

**How to avoid:**
- Document clearly in v2 README: "This plugin requires a non-sandboxed macOS app. App Sandbox (`com.apple.security.app-sandbox`) is incompatible with the current in-bundle update mechanism."
- Add a runtime assertion or warning: detect `ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]` and surface a clear error to the developer if sandbox is active
- The correct sandbox-compatible approach is a privileged XPC helper service for file operations — out of scope for v2 but should be a documented future path

**Warning signs:**
- Update silently fails on user machines but works in development
- `FileManager` operations return without error but files are not written
- Consumer reports "update completes but app still shows old version"

**Phase to address:** Swift native code modernization phase (add the sandbox detection guard)

---

### Pitfall 7: Version Comparison Using Integer shortVersion Is Fragile

**What goes wrong:**
The current `versionCheck` function compares `latestVersion.shortVersion > int.parse(currentVersion!)`. `currentVersion` comes from `CFBundleVersion` via the method channel, which is typically an integer build number but is not guaranteed to be parseable as `int`. Any build that uses a semantic version string (`"3.2.1"`) in `CFBundleVersion` instead of a build number integer causes `int.parse` to throw a `FormatException`, crashing the entire update check. The v2 API redesign must harden this.

**Why it happens:**
Developers conflate `CFBundleShortVersionString` (human-readable, e.g. "1.3.0") with `CFBundleVersion` (build number, e.g. "103"). Both are strings; `int.parse` on either one works only if the consumer uses strictly integer build numbers.

**How to avoid:**
- In v2, use `package:pub_semver` for version comparison, or define an explicit version contract (`int`-only build numbers) and validate at `UpdateSource` return time
- Catch `FormatException` from `int.parse` and surface it as a typed `UpdateError.invalidVersionFormat` rather than an uncaught exception
- Document that `CFBundleVersion` must be a pure integer build number for the plugin to work

**Warning signs:**
- Update check throws `FormatException` on consumer machines using semantic `CFBundleVersion`
- CI passes (developer uses integer build numbers) but production fails (CI/CD pipeline uses `"1.3.0"`)

**Phase to address:** Data model redesign phase

---

### Pitfall 8: Dart's copyWith Bug Carried Forward into v2 Models

**What goes wrong:**
`ItemModel.copyWith` in `app_archive.dart` line 98 contains `changedFiles: changedFiles ?? changedFiles` — the `??` falls back to the parameter, not `this.changedFiles`. This means `changedFiles` is never preserved from the existing object; calling `copyWith()` without the `changedFiles` argument silently drops the existing value and stores `null`. If this model is carried forward or its bug pattern is reproduced in new v2 models, delta file lists will be silently discarded.

**Why it happens:**
Copy-paste error in manual `copyWith` implementations. The pattern `field ?? field` compiles without warning; only careful review catches it.

**How to avoid:**
- Use `package:freezed` code generation for all v2 data models — generated `copyWith` is always correct
- If manual models are preferred, add a unit test: `model.copyWith()` must return an object equal to the original on every field
- The existing bug must be fixed in the refactoring, not carried forward

**Warning signs:**
- Tests pass but changed files list is null after `copyWith` call
- Progress tracking shows 0 files to download when files have changed

**Phase to address:** Data model redesign phase (fix the existing bug, use code generation to prevent recurrence)

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode `dir.parent.parent` for macOS app bundle root | Avoids building a path resolver utility | Breaks silently for any non-standard bundle structure; duplicated in 4 files | Never — create a `PlatformPathResolver` in v2 |
| Skip post-download hash verification | Faster download flow | Corrupt partial download applied to app; no way to detect | Never for production |
| `int.parse(currentVersion!)` without null/format guard | One line of code | Crash on any consumer using non-integer CFBundleVersion | Never — always guard |
| New http.Client() per download request | Simple code | No connection reuse; overhead on multi-file delta updates | Acceptable in MVP, fix in performance pass |
| Print statements for all logging | Fast debugging | Logs leak to production console; no log levels | Never ship with bare `print()` — use a `debugPrint` guard or structured logging |
| Ignore temp directory cleanup | Simpler code | `/tmp` accumulates `desktop_updater*` dirs on every update check | Never — always clean up in `finally` blocks |

---

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Firebase Remote Config as UpdateSource | Calling `remoteConfig.fetchAndActivate()` inside `checkForUpdate()` without timeout | Always set `fetchTimeout` on Remote Config and propagate the `FirebaseException` as a typed `UpdateError` |
| REST API UpdateSource | Returning raw JSON model fields to the plugin (exposing `changes`, `date`, `mandatory` that v2 doesn't have) | Consumer maps their API response to the minimal `UpdateInfo` model the plugin defines — no extra fields leak through |
| CDN-hosted hashes.json | Assuming 200 OK means valid JSON (CDN may return 200 with an error HTML page on cache miss) | Validate Content-Type header; parse defensively with try/catch; surface `UpdateError.invalidManifest` |
| macOS method channel from Swift async context | Calling `result()` callback from a Swift async Task (wrong thread) | Call `result()` only from the main thread; use `DispatchQueue.main.async` wrapper around any `result(...)` call |
| Self-signed developer certificate | Update works in dev; Gatekeeper blocks on user machine | Document that Developer ID Application certificate is required; test on a machine where the developer cert is NOT in the keychain |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Blake2b hash every file in bundle on every update check | Update check takes 10+ seconds on large apps | Cache hashes with file mtime; only re-hash changed files | Apps > 200MB or 5000+ files |
| Sequential download of changed files | Long update times for many small changed files | Use `Future.wait` with bounded concurrency (e.g., 4 parallel downloads) | Updates with > 20 changed files |
| Loading entire hashes.json into memory as `List` | Memory spike on update check | Stream-parse the JSON; process hashes incrementally | Apps with > 50,000 files |
| No progress backpressure on download stream | UI thread saturated with progress events | Throttle progress callbacks to max 30fps using `throttle` or timer-based batching | Slow connections with many chunks |
| New http.Client per file download | Connection overhead multiplied by changed file count | Shared `http.Client` singleton across all downloads in one update session | Delta updates with > 10 files |

---

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| No post-download hash verification of downloaded files | MITM attacker substitutes malicious binary; hash is checked before download but not after | Re-verify Blake2b hash of each downloaded file against `hashes.json` before moving to `Contents/update/` |
| HTTPS not enforced; any URL accepted as `remoteUpdateFolder` | Consumer misconfiguration sends update traffic over HTTP; MITM possible | Validate that `UpdateSource`-provided URLs use `https://` scheme; throw `UpdateError.insecureUrl` for `http://` |
| hashes.json itself not signed | Attacker modifies `hashes.json` in transit to reference malicious binaries with matching hashes | Consider EdDSA signature on `hashes.json` (Sparkle uses this); at minimum enforce HTTPS and document the trust model |
| Temporary files not cleaned up | Sensitive app binaries accumulate in world-readable `/tmp` | Always delete temp dirs in `finally` blocks; use `NSFileProtectionComplete` on sensitive staging directories |
| restartApp() executes arbitrary path from Bundle.main.executablePath | If bundle is modified by attacker before restart, executes attacker's binary | Validate `executablePath` is within the expected bundle before running; do not use user-supplied paths |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but have a missing critical piece.

- [ ] **UpdateSource abstract class:** Verify the interface has an error propagation contract (not just happy-path return types) — a source that throws is not the same as one that returns `null`
- [ ] **UI removal:** Verify `desktop_updater.dart` barrel file no longer exports any widget or `InheritedWidget` symbols — the barrel is the contract, not individual files
- [ ] **Swift restart sequence:** Verify `restartApp()` launches the new process BEFORE calling `NSApplication.shared.terminate(nil)` — code after `terminate` is unreliable
- [ ] **Version check:** Verify `int.parse(currentVersion!)` is wrapped in a try/catch `FormatException` handler — it will crash silently otherwise
- [ ] **Temp cleanup:** Verify every code path that creates a `Directory.systemTemp.createTemp("desktop_updater")` has a corresponding `deleteSync(recursive: true)` in a `finally` block
- [ ] **copyWith on new models:** Verify `model.copyWith()` with no arguments returns an object equal to the original — catches the existing `??` parameter-shadow bug pattern
- [ ] **Post-download verification:** Verify downloaded files are re-hashed against the manifest after download, not just before
- [ ] **macOS path resolution:** Verify there is a single `PlatformPathResolver` utility rather than inline `dir.parent` calls in 4 separate files
- [ ] **Sealed class design:** Verify that any `sealed` type exposed in the public API has been reviewed for completeness — adding a subtype later is a breaking change
- [ ] **CHANGELOG migration guide:** Verify the v2 CHANGELOG includes explicit "Removed:" sections with consumer-side replacement code, not just a list of removed symbols

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Code signature invalidation shipped to users | HIGH | Publish a patch that reverts to the last valid bundle; document as a known issue; users must manually re-download the full app from original source |
| Sealed class subtype added in minor version | HIGH | Major version bump required; publish a migration guide; v2.x consumers must add `default` arms to their switches |
| `terminate()` race condition in production | MEDIUM | Publish Swift fix that moves file ops before terminate; users experiencing non-relaunch can manually restart the app |
| `int.parse` crash on version check | LOW | Patch release adding `int.tryParse` with typed error; no data loss |
| Sandbox writes silently failing | MEDIUM | Add runtime detection and an `UpdateError.sandboxIncompatible` error; update README with the non-sandbox requirement |
| Temp directory accumulation | LOW | Publish a patch with explicit cleanup; add a cleanup-on-startup scan for `desktop_updater*` temp dirs older than 24 hours |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|-----------------|--------------|
| Code signature invalidation | Swift native code modernization | `codesign --verify --deep --strict` passes after a simulated in-place update |
| Sealed class addition = breaking change | Data model redesign | All sealed types reviewed and locked before v2.0.0 tag |
| terminate() race condition | Swift native code modernization | Integration test: app relaunches reliably 10/10 times after update |
| UpdateSource async contract mismatch | API design (UpdateSource interface) | `MockUpdateSource` throws typed exception; plugin surfaces it as `UpdateError` |
| UI removal breaks consumers | UI removal phase | Example app builds cleanly with no imported widget symbols from the package |
| App Sandbox incompatibility | Swift native code modernization | Sandbox detection guard present; README documents the constraint |
| Integer version comparison fragility | Data model redesign | Unit test: `int.parse("1.3.0")` wrapped and returns `UpdateError.invalidVersionFormat` |
| copyWith bug carried forward | Data model redesign | Unit test: `model.copyWith()` equals original on all fields |
| Missing post-download hash verification | Core update engine refactoring | Test: tampered download file detected and rejected before application |
| Scattered `dir.parent` path logic | Core update engine refactoring | Single `PlatformPathResolver` class, no inline `.parent` calls outside it |

---

## Sources

- Apple TN2206: macOS Code Signing In Depth — https://developer.apple.com/library/archive/technotes/tn2206/_index.html
- Apple Developer Forums: Can I update a resource in a signed app — https://developer.apple.com/forums/thread/129657
- Apple Security: Gatekeeper and runtime protection in macOS — https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web
- Peter Steinberger: Code Signing and Notarization — Sparkle and Tears (2025) — https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears
- Dart Language: Class modifiers for API maintainers — https://dart.dev/language/class-modifiers-for-apis
- Sparkle Project: Publishing an update — https://sparkle-project.org/documentation/publishing/
- Flutter: Writing custom platform-specific code (method channel threading) — https://docs.flutter.dev/platform-integration/platform-channels
- macOS gist: distribution, code signing, notarization, quarantine — https://gist.github.com/rsms/929c9c2fec231f0cf843a1a796a416f5
- Codebase inspection: `.planning/codebase/CONCERNS.md` (known bugs, fragile areas, tech debt)
- Codebase inspection: `lib/src/app_archive.dart` line 98 (copyWith bug), `macos/.../DesktopUpdaterPlugin.swift` (terminate/relaunch race)

---
*Pitfalls research for: Flutter macOS desktop updater plugin — v1 to v2 refactoring*
*Researched: 2026-03-26*
