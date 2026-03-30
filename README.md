# Desktop Updater

A headless Flutter plugin for macOS desktop OTA updates. Downloads only changed files by comparing Blake2b file hashes — no full app re-download needed. Bring your own backend via the abstract `UpdateSource` interface (Firebase Remote Config, REST API, S3, local file, etc.).

**v2.2.0** introduces a semver version model. See [CHANGELOG.md](CHANGELOG.md) for the migration guide if upgrading from v2.1.0.

## Getting Started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  macos_updater: ^2.2.0
```

## Usage

### 1. Implement `UpdateSource`

Connect the engine to your backend by implementing two methods:

```dart
import "package:macos_updater/macos_updater.dart";

class MyUpdateSource implements UpdateSource {
  @override
  Future<UpdateDetails?> getUpdateDetails() async {
    // Fetch version config from your server.
    // Return null if no update config is available.
    final response = await http.get(
      Uri.parse("https://your-server.com/update-details.json"),
    );
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final macosJson = json["macos"] as Map<String, dynamic>?;
    if (macosJson == null) return null;

    return UpdateDetails(
      macos: PlatformUpdateDetails(
        minimum: macosJson["minimum"] as String,   // minimum version — below this forces update
        latest: macosJson["latest"] as String,     // latest available version
        active: macosJson["active"] as bool,       // false disables update checking
      ),
      remoteBaseUrl: json["remoteBaseUrl"] as String,
    );
  }

  @override
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) async {
    // Fetch hashes.json from your update server.
    final response = await http.get(
      Uri.parse("$remoteBaseUrl/hashes.json"),
    );
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => FileHash.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

The JSON your server returns should look like:

```json
{
  "macos": {
    "minimum": "1.0.1",
    "latest": "1.0.2",
    "active": true
  },
  "remoteBaseUrl": "https://your-server.com/updates/1.0.2"
}
```

### 2. Check for Updates

The engine compares the running app's version (read from `CFBundleShortVersionString`) against `PlatformUpdateDetails.minimum` and `PlatformUpdateDetails.latest` using semantic versioning. The result is a 3-way sealed type:

```dart
final source = MyUpdateSource();
final result = await checkForUpdate(source);

switch (result) {
  case UpToDate():
    print("App is up to date!");
  case ForceUpdateRequired(:final info):
    // Current version is below the minimum — user must update.
    print("Required update to ${info.version}");
    showForceUpdateBanner(info);
  case OptionalUpdateAvailable(:final info):
    // Update available but current version meets the minimum.
    print("Optional update to ${info.version}");
    print("${info.changedFiles.length} files to download");
    showOptionalUpdatePrompt(info);
}
```

**Version comparison logic:**

| Current version vs config | Result |
|---------------------------|--------|
| `current >= latest` | `UpToDate` |
| `current < minimum` | `ForceUpdateRequired` |
| `minimum <= current < latest` | `OptionalUpdateAvailable` |

**Fields on `UpdateInfo`:**

| Field | Type | Description |
|-------|------|-------------|
| `version` | `String` | Latest version (semver string) |
| `minimumVersion` | `String?` | Minimum required version |
| `remoteBaseUrl` | `String` | Base URL where update files are hosted |
| `changedFiles` | `List<FileHash>` | Files that differ from the running version |

### 3. Download Update

```dart
// Only changed files are downloaded (delta update)
await downloadUpdate(
  info,
  onProgress: (progress) {
    print("${progress.completedFiles}/${progress.totalFiles} files");
    print("${progress.receivedBytes}/${progress.totalBytes} bytes");
  },
);
```

### 4. Apply Update (Restart)

```dart
try {
  await applyUpdate();
} on RestartFailed catch (e) {
  print("Restart failed: ${e.message}");
}
```

## Firebase Remote Config Example

```dart
class FirebaseUpdateSource implements UpdateSource {
  @override
  Future<UpdateDetails?> getUpdateDetails() async {
    final config = FirebaseRemoteConfig.instance;
    await config.fetchAndActivate();

    final latest = config.getString("macos_latest_version");
    if (latest.isEmpty) return null;

    return UpdateDetails(
      macos: PlatformUpdateDetails(
        minimum: config.getString("macos_minimum_version"),
        latest: latest,
        active: config.getBool("macos_update_active"),
      ),
      remoteBaseUrl: config.getString("macos_update_base_url"),
    );
  }

  @override
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) async {
    final response = await http.get(
      Uri.parse("$remoteBaseUrl/hashes.json"),
    );
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => FileHash.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

## Error Handling

All errors are typed via the sealed `UpdateError` hierarchy. Use exhaustive switch — the compiler enforces all cases:

```dart
try {
  final result = await checkForUpdate(source);
  // ...
} on UpdateError catch (e) {
  switch (e) {
    case NetworkError(:final message):
      print("Network error: $message");
    case HashMismatch(:final filePath):
      print("Hash mismatch for: $filePath");
    case NoPlatformEntry(:final message):
      print("Platform error: $message");
    case IncompatibleVersion(:final message):
      print("Version error: $message");
    case RestartFailed(:final message):
      print("Restart failed: $message");
  }
}
```

## API Reference

### Functions

| Function | Description |
|----------|-------------|
| `checkForUpdate(UpdateSource source)` | Returns `UpToDate`, `ForceUpdateRequired(info)`, or `OptionalUpdateAvailable(info)` |
| `downloadUpdate(UpdateInfo info, {onProgress})` | Downloads only changed files with progress callback |
| `applyUpdate()` | Restarts the app to apply the downloaded update |
| `generateLocalFileHashes({String? path})` | Computes Blake2b hashes for the running app bundle |

### Types

| Type | Description |
|------|-------------|
| `UpdateSource` | Abstract interface — implement to connect your backend |
| `UpdateDetails` | Version config returned by `getUpdateDetails()`: wraps per-platform `PlatformUpdateDetails` |
| `PlatformUpdateDetails` | Per-platform config: `minimum` (String), `latest` (String), `active` (bool) |
| `UpdateInfo` | Version metadata populated by engine: `version`, `minimumVersion`, `remoteBaseUrl`, `changedFiles` |
| `FileHash` | File path + Blake2b hash + file length |
| `UpdateProgress` | Download progress: `totalBytes`, `receivedBytes`, `currentFile`, `totalFiles`, `completedFiles` |
| `UpdateCheckResult` | Sealed: `UpToDate`, `ForceUpdateRequired(info)`, or `OptionalUpdateAvailable(info)` |
| `UpdateError` | Sealed: `NetworkError`, `HashMismatch`, `NoPlatformEntry`, `IncompatibleVersion`, `RestartFailed` |

## CLI Commands

Build your macOS app and generate update artifacts:

```bash
# 1. Build release and copy to dist/
dart run macos_updater:release macos

# 2. Generate hashes.json for the built artifact
dart run macos_updater:archive macos
```

This creates a `dist/{version}-macos/` folder with your app files and a `hashes.json` manifest. Upload this folder to your server — the engine downloads individual files from it.

## How Delta Updates Work

1. **Build time:** CLI generates `hashes.json` with Blake2b hashes for every file in your `.app` bundle
2. **Runtime:** Engine computes local file hashes and compares against remote `hashes.json`
3. **Download:** Only files with different hashes are downloaded (delta update)
4. **Apply:** Native Swift code copies updated files into the app bundle and restarts

## Requirements

- Flutter 3.29+ / Dart 3.7+
- macOS 10.15+ (deployment target)
- App must NOT be sandboxed (App Sandbox blocks bundle writes)

## Migrating from v2.1.0

v2.2.0 replaces integer build numbers with semantic versioning. See [CHANGELOG.md](CHANGELOG.md) for the full migration guide with before/after code examples.

**Key changes:**
- `getLatestUpdateInfo()` → `getUpdateDetails()` returning `UpdateDetails`
- `UpdateAvailable` → `ForceUpdateRequired` or `OptionalUpdateAvailable`
- `UpdateInfo.buildNumber` (int) → `UpdateInfo.version` (semver String)
- `UpdateInfo.minBuildNumber` (int?) → `UpdateInfo.minimumVersion` (String?)
- `UpdateInfo.isMandatory` (bool) → Inferred from result type

## Migrating from v1

v2.0.0 removes all built-in UI and the `MacosUpdaterController`. See [CHANGELOG.md](CHANGELOG.md) for the full migration guide with before/after code examples.

**Key changes:**
- `MacosUpdaterController` → `checkForUpdate()` + `downloadUpdate()` + `applyUpdate()`
- `DesktopUpdateWidget` / `DesktopUpdateSliver` → Build your own UI using the function API
- `appArchiveUrl` parameter → Implement `UpdateSource` interface
- `FileHashModel` → `FileHash`
- `ItemModel` / `AppArchiveModel` → `UpdateInfo`

## License

See [LICENSE](LICENSE) for details.
