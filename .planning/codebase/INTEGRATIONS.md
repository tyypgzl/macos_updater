# External Integrations

**Analysis Date:** 2026-03-26

## APIs & External Services

**Update Distribution:**
- Custom HTTP endpoints for app-archive.json
  - SDK/Client: `http 1.2.2`
  - Fetched via: `lib/src/version_check.dart` - versionCheckFunction()
  - Expected format: JSON manifest with version metadata

**Update Download Sources:**
- Supported: GitHub, GitLab, local file systems, S3
  - SDK/Client: `http 1.2.2`
  - Implementation: `lib/src/download.dart` - downloadFile()
  - Authentication: Via URL (no built-in auth headers, relies on public or pre-signed URLs)

**Hash Verification Downloads:**
- Hashes file (hashes.json) from update server
  - SDK/Client: `http 1.2.2`
  - Location: `{update_url}/hashes.json`
  - Purpose: Delta update detection via Blake2b hash comparison

## Data Storage

**Databases:**
- Not applicable - Plugin operates on local filesystem only

**File Storage:**
- Local filesystem only
  - Update files downloaded to: `{app_directory}/update/` (dynamically created)
  - Hash files cached to system temp directory: `Directory.systemTemp.createTemp("desktop_updater")`
  - macOS: Parent directory of executable used due to .app bundle structure
  - Linux: Uses `/proc/self/exe` symbolic link resolution
  - Implementation: `lib/src/download.dart`, `lib/src/file_hash.dart`

**Temporary Storage:**
- System temp directory (platform-specific)
  - JSON manifests and hash files stored temporarily during verification
  - Created via: `Directory.systemTemp.createTemp("desktop_updater")`

**Caching:**
- None - Files downloaded fresh on each update check

## Authentication & Identity

**Auth Provider:**
- Custom/None - No built-in authentication
- Implementation: URL-based only
  - Users provide full URLs (e.g., S3 signed URLs, GitHub raw content URLs)
  - No OAuth, JWT, or API key support in plugin code
  - Environment variables: None required

## Version Management

**Current Version Detection:**
- Platform-specific:
  - macOS/Windows: Native platform channel `getCurrentVersion()`
  - Linux: Reads `version.json` from `data/flutter_assets` directory
  - Implementation: `lib/src/version_check.dart`
  - Comparison: Uses `shortVersion` integer field (incremental build number)

## File Hash Verification

**Cryptographic Hashing:**
- Algorithm: Blake2b
  - SDK: `cryptography_plus 2.7.1`, `cryptography_flutter_plus 2.3.4`
  - Purpose: Detect changed files between versions
  - Implementation: `lib/src/file_hash.dart`
    - `getFileHash()` - Computes Blake2b hash of individual files
    - `verifyFileHashes()` - Compares old vs. new hash manifests
    - `genFileHashes()` - Generates hash manifest for all app files

**Hash Format:**
- Base64-encoded Blake2b digest
- Stored in JSON: `hashes.json`
- Structure: Array of FileHashModel objects with filePath, calculatedHash, length

## Archive Handling

**Compression/Extraction:**
- Framework: `archive 4.0.2`
- Purpose: Unpack downloaded update archives
- Location: `lib/src/` (integrated into update flow)

## Platform-Specific Native Integrations

**macOS (Swift):**
- Location: `macos/desktop_updater/Sources/desktop_updater/DesktopUpdaterPlugin.swift`
- Provides: App restart, executable path resolution, version retrieval
- Method channels: Used for Dart-to-Swift communication

**Windows (C++):**
- Location: `windows/desktop_updater_plugin.cpp`
- C API variant: `windows/desktop_updater_plugin_c_api.cpp`
- Provides: App restart, executable path resolution, version retrieval from native registry/metadata

**Linux (C):**
- Location: `linux/` directory
- Provides: App restart via system calls, executable path from `/proc/self/exe`
- Version: Reads from Dart-compiled `version.json` asset file

## Webhooks & Callbacks

**Incoming:**
- None - Plugin is entirely pull-based

**Outgoing:**
- None - No callback/webhook mechanism to remote servers

**Progress Reporting:**
- Internal only: UpdateProgress stream
  - Implementation: `lib/src/update_progress.dart`
  - Used by UI widgets in `lib/widget/`
  - Reports: Download progress (receivedKB, totalKB), update stage

## Environment Configuration

**Required env vars:**
- None - Configuration via Dart API parameters

**URL Configuration:**
- `appArchiveUrl`: Full HTTP(S) URL provided to DesktopUpdaterController
  - Expected: Publicly accessible JSON manifest
  - No auth headers or API keys supported

**Secrets location:**
- Not applicable - No secrets management in plugin
- Users responsible for secure hosting (HTTPS, firewall rules, etc.)

## Content Delivery

**Supported Hosting:**
- Any HTTP(S) server
- GitHub (raw content URLs)
- GitLab (raw project files)
- AWS S3 (public or signed URLs)
- Self-hosted servers
- Local file systems (via file:// URIs in example/testing)

**Update Package Format:**
- Directory structure with application binaries
- Requires parallel `hashes.json` file at same URL
- Platform-specific subdirectories (windows, macos, linux)

## Configuration Files

**App Archive Manifest Format (app-archive.json):**
```json
{
  "appName": "App display name",
  "description": "Description text",
  "items": [
    {
      "version": "1.0.0",
      "shortVersion": 1,
      "changes": [{"type": "feat", "message": "Feature description"}],
      "date": "2025-01-10",
      "mandatory": true,
      "url": "https://example.com/updates/1.0.0",
      "platform": "windows|macos|linux"
    }
  ]
}
```

**Hash Manifest Format (hashes.json):**
```json
[
  {
    "path": "relative/file/path",
    "calculatedHash": "base64_blake2b_hash",
    "length": 12345
  }
]
```

## Version File Format (Linux)

**Location:** `data/flutter_assets/version.json`
```json
{
  "build_number": "1"
}
```

## Update Process Flow

1. **Check Version**: Fetch app-archive.json from remote server
2. **Compare**: Get current version from native code or version.json
3. **Hash Verification**: Download hashes.json, compare with local files via Blake2b
4. **Download Deltas**: Download only changed files from update URL
5. **Verify Integrity**: Confirm downloaded files match expected hashes
6. **Extract**: Unpack archive using `archive` package
7. **Restart**: Trigger native app restart via platform channel

---

*Integration audit: 2026-03-26*
