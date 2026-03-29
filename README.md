# Desktop Updater

A headless Flutter plugin for macOS desktop OTA updates. Downloads only changed files by comparing Blake2b file hashes — no full app re-download needed. Bring your own backend via the abstract `UpdateSource` interface (Firebase Remote Config, REST API, S3, local file, etc.).

**v2.0.0** is a complete rewrite. No built-in UI — you build your own. See the [migration guide](#migrating-from-v1) if upgrading.

## Getting Started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  macos_updater: ^2.0.0
```

## Usage

### 1. Implement `UpdateSource`

Connect the engine to your backend by implementing two methods:

```dart
import "package:macos_updater/macos_updater.dart";

class MyUpdateSource implements UpdateSource {
  @override
  Future<UpdateInfo?> getLatestUpdateInfo() async {
    // Fetch version metadata from your server.
    // Return null if the app is already up-to-date.
    // Return UpdateInfo if a newer version exists.
    final response = await http.get(
      Uri.parse("https://your-server.com/app-archive.json"),
    );
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return UpdateInfo(
      version: json["version"] as String,       // display only
      buildNumber: json["buildNumber"] as int,   // used for comparison
      remoteBaseUrl: json["url"] as String,      // where update files are hosted
      changedFiles: const [],                    // engine populates this
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

### 2. Check for Updates

```dart
final source = MyUpdateSource();
final result = await checkForUpdate(source);

switch (result) {
  case UpToDate():
    print("App is up to date!");
  case UpdateAvailable(:final info):
    print("Update available: ${info.version}");
    print("${info.changedFiles.length} files to download");
}
```

### Force vs Optional Updates

The engine automatically determines whether an update is mandatory based on the `minBuildNumber` field returned by your `UpdateSource`. If the device's build number is below `minBuildNumber`, the engine sets `isMandatory = true`. If your `UpdateSource` already sets `isMandatory = true`, the engine preserves it.

**Fields on `UpdateInfo`:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `isMandatory` | `bool` | `false` | Engine sets this; consumer uses it to drive UI |
| `minBuildNumber` | `int?` | `null` | Minimum build number that can skip the update |
| `releaseNotes` | `String?` | `null` | Optional release notes to show in update UI |

**How to set `minBuildNumber` in your `UpdateSource`:**

```dart
@override
Future<UpdateInfo?> getLatestUpdateInfo() async {
  // ... fetch from your server ...
  return UpdateInfo(
    version: "2.1.0",
    buildNumber: 20,
    remoteBaseUrl: "https://your-server.com/updates/20",
    changedFiles: const [],
    minBuildNumber: 15,        // builds below 15 must update
    releaseNotes: "Bug fixes", // optional, shown in update UI
  );
}
```

**`minBuildNumber` logic:**

| Device build | `minBuildNumber` | `isMandatory` result |
|-------------|-----------------|---------------------|
| 12 | 15 | `true` (12 < 15 — engine auto-sets) |
| 15 | 15 | from `UpdateSource` (>= min) |
| 20 | 15 | from `UpdateSource` (>= min) |

**Consumer switch pattern:**

```dart
case UpdateAvailable(:final info):
  if (info.isMandatory) {
    showForceUpdateDialog(info);
  } else {
    showOptionalUpdateBanner(info);
  }
```

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
  Future<UpdateInfo?> getLatestUpdateInfo() async {
    final config = FirebaseRemoteConfig.instance;
    await config.fetchAndActivate();

    final build = config.getInt("latest_build_number");
    if (build == 0) return null;

    return UpdateInfo(
      version: config.getString("latest_version"),
      buildNumber: build,
      remoteBaseUrl: config.getString("update_base_url"),
      changedFiles: const [],
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
| `checkForUpdate(UpdateSource source)` | Returns `UpToDate` or `UpdateAvailable(info)` |
| `downloadUpdate(UpdateInfo info, {onProgress})` | Downloads only changed files with progress callback |
| `applyUpdate()` | Restarts the app to apply the downloaded update |
| `generateLocalFileHashes({String? path})` | Computes Blake2b hashes for the running app bundle |

### Types

| Type | Description |
|------|-------------|
| `UpdateSource` | Abstract interface — implement to connect your backend |
| `UpdateInfo` | Version metadata: version, buildNumber, remoteBaseUrl, changedFiles |
| `FileHash` | File path + Blake2b hash + file length |
| `UpdateProgress` | Download progress: totalBytes, receivedBytes, currentFile, totalFiles, completedFiles |
| `UpdateCheckResult` | Sealed: `UpToDate` or `UpdateAvailable(info)` |
| `UpdateError` | Sealed: `NetworkError`, `HashMismatch`, `NoPlatformEntry`, `IncompatibleVersion`, `RestartFailed` |

## CLI Commands

Build your macOS app and generate update artifacts:

```bash
# 1. Build release and copy to dist/
dart run macos_updater:release macos

# 2. Generate hashes.json for the built artifact
dart run macos_updater:archive macos
```

This creates a `dist/{buildNumber}/{version}+{buildNumber}-macos/` folder with your app files and a `hashes.json` manifest. Upload this folder to your server — the engine downloads individual files from it.

## How Delta Updates Work

1. **Build time:** CLI generates `hashes.json` with Blake2b hashes for every file in your `.app` bundle
2. **Runtime:** Engine computes local file hashes and compares against remote `hashes.json`
3. **Download:** Only files with different hashes are downloaded (delta update)
4. **Apply:** Native Swift code copies updated files into the app bundle and restarts

## Requirements

- Flutter 3.29+ / Dart 3.7+
- macOS 10.15+ (deployment target)
- App must NOT be sandboxed (App Sandbox blocks bundle writes)

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
