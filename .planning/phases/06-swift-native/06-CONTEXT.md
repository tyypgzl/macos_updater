# Phase 6: Swift Native - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the macOS restart sequence reliability (terminate race condition), add App Sandbox detection, modernize Swift code with async/await via Task{} bridging, and bump deployment target to 10.15.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion (all areas)

- **Restart sequence fix:** Current code calls `NSApplication.shared.terminate(nil)` BEFORE `copyAndReplaceFiles()` and `Process.run()`. Fix: copy files first → launch new process → then terminate. This is the root cause of the v1.2.0 regression per research.
- **Sandbox detection:** Check `ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]` — if non-nil, app is sandboxed and cannot write to its own bundle. Return error via FlutterResult instead of silently failing.
- **Task{} bridging:** Wrap file operations in `Task { }` blocks inside the `handle()` method. The FlutterPlugin protocol still requires completion-handler style `handle(_:result:)` — bridge back to `result` at the boundary.
- **GCD background queue:** Dispatch file copy operations to a background `DispatchQueue` to avoid blocking the main thread.
- **Deployment target:** Bump `Package.swift` from `.macOS("10.14")` to `.macOS("10.15")` — required for Task{}/async-await.
- **getCurrentVersion() return type:** Currently returns String in Swift but Dart expects int. Return the integer directly from Swift side (`Int(version)` on CFBundleVersion).
- **Remove print() calls:** Replace with proper error propagation via FlutterResult.
- **Clean up unused methods:** Remove `getExecutablePath` and `sayHello` if no longer used by v2 API.

</decisions>

<canonical_refs>
## Canonical References

### Existing Swift Code
- `macos/desktop_updater/Sources/desktop_updater/DesktopUpdaterPlugin.swift` — Current Swift plugin (102 lines, all changes here)
- `macos/desktop_updater/Package.swift` — SwiftPM config (deployment target change)

### Dart Platform Layer
- `lib/desktop_updater_platform_interface.dart` — Platform interface (getCurrentVersion returns Future<int>)
- `lib/desktop_updater_method_channel.dart` — Method channel impl (invokeMethod<int>)

### Research
- `.planning/research/PITFALLS.md` — terminate race condition, sandbox detection, code signing
- `.planning/research/STACK.md` — Swift Task{} bridging pattern, macOS 10.15 requirement

### Project Context
- `.planning/REQUIREMENTS.md` — NAT-01 through NAT-04
- `.planning/ROADMAP.md` — Phase 6 success criteria (4 criteria)

</canonical_refs>

<code_context>
## Existing Code Insights

### Known Bugs
- `restartApp()` line 15: `NSApplication.shared.terminate(nil)` called BEFORE file copy (lines 17-23) and process relaunch (lines 25-33) — race condition
- `getCurrentVersion()` returns String but Dart side expects int
- `print()` calls on lines 13, 22, 34 violate best practices

### Reusable Assets
- `copyAndReplaceFiles()` logic is correct for file operations — just needs to be called in the right order
- `FlutterMethodChannel` registration pattern is standard — keep

### Integration Points
- Method channel name `"desktop_updater"` must remain unchanged
- `restartApp` method name must match Dart `invokeMethod<void>("restartApp")`
- `getCurrentVersion` must now return `Int` to match Dart `invokeMethod<int>`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — Claude decides based on research.

</specifics>

<deferred>
## Deferred Ideas

None

</deferred>

---

*Phase: 06-swift-native*
*Context gathered: 2026-03-27*
