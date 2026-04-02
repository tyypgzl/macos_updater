## 2.3.0

### Breaking
- **hashes.json format standardized**: JSON keys are now `filePath`, `hash`, `length` (previously `path`, `calculatedHash`, `length`). Regenerate your hashes.json with `dart run macos_updater:archive macos`.

### Changed
- `FileHash.fromJson()` and `toJson()` use consistent keys matching Dart field names
- Removed dual-format fallback — single format, single source of truth

## 2.2.3

### Fixed
- `FileHash.fromJson()` now supports both JSON key formats: CLI format (`path`, `calculatedHash`) and alternative format (`filePath`, `hash`). Previously crashed with `type 'Null' is not a subtype of type 'String'` when hashes.json used `filePath`/`hash` keys.

## 2.2.2

### Fixed
- Fixed `type 'Null' is not a subtype of type 'String'` crash when `CFBundleShortVersionString` is not set in Info.plist. Now returns `'0.0.0'` as fallback instead of crashing.

## 2.2.1

### Added
- `PlatformUpdateDetails.url` — per-platform URL for update files. The engine checks `platformDetails.url` first, falling back to `UpdateDetails.remoteBaseUrl` if null.

### Fixed
- Fixed `type 'Null' is not a subtype of type 'String'` crash when `remoteBaseUrl` was null and URL was inside the platform config object.

## 2.2.0

**Breaking changes** — semver version model replaces integer build numbers.

### Migration from 2.1.0

#### UpdateSource

Before:

```dart
class MyUpdateSource implements UpdateSource {
  @override
  Future<UpdateInfo?> getLatestUpdateInfo() async {
    return UpdateInfo(
      version: '2.0.0',
      buildNumber: 200,
      remoteBaseUrl: 'https://example.com/updates',
      changedFiles: const [],
      minBuildNumber: 150,
    );
  }
}
```

After:

```dart
class MyUpdateSource implements UpdateSource {
  @override
  Future<UpdateDetails?> getUpdateDetails() async {
    return UpdateDetails(
      macos: const PlatformUpdateDetails(
        minimum: '1.5.0',
        latest: '2.0.0',
        active: true,
      ),
      remoteBaseUrl: 'https://example.com/updates',
    );
  }
}
```

#### UpdateCheckResult switch

Before (2-way):

```dart
switch (result) {
  case UpToDate(): ...
  case UpdateAvailable(:final info):
    if (info.isMandatory) { /* force */ }
    else { /* optional */ }
}
```

After (3-way):

```dart
switch (result) {
  case UpToDate(): ...
  case ForceUpdateRequired(:final info): ...  // was isMandatory=true
  case OptionalUpdateAvailable(:final info): ... // was isMandatory=false
}
```

#### Removed fields

| Removed | Replacement |
|---------|-------------|
| `UpdateInfo.buildNumber` (int) | `UpdateInfo.version` (semver String) |
| `UpdateInfo.minBuildNumber` (int?) | `UpdateInfo.minimumVersion` (String?) |
| `UpdateInfo.isMandatory` (bool) | Separate result types |
| `UpdateSource.getLatestUpdateInfo()` | `UpdateSource.getUpdateDetails()` |
| `UpdateCheckResult.UpdateAvailable` | `ForceUpdateRequired` or `OptionalUpdateAvailable` |

### New types

- `PlatformUpdateDetails` — platform-specific config: `{ minimum, latest, active }`
- `UpdateDetails` — wraps platform configs: `{ macos: PlatformUpdateDetails?, remoteBaseUrl: String? }`
- `ForceUpdateRequired(UpdateInfo)` — current version is below minimum
- `OptionalUpdateAvailable(UpdateInfo)` — update available, current version is valid

### Version comparison

The engine now uses `pub_semver` for all comparisons:
- `currentVersion < minimum` — `ForceUpdateRequired`
- `minimum <= currentVersion < latest` — `OptionalUpdateAvailable`
- `currentVersion >= latest` — `UpToDate`

## 2.1.0

### New features

- `UpdateInfo` gains three optional fields: `isMandatory` (bool, default `false`),
  `minBuildNumber` (int?), and `releaseNotes` (String?). Existing `UpdateSource`
  implementations require no changes — all fields have defaults.
- `checkForUpdate()` automatically sets `isMandatory = true` when
  `minBuildNumber != null && localBuild < minBuildNumber`. If the `UpdateSource`
  already sets `isMandatory = true`, the engine preserves it.
- `UpdateInfo.copyWith()` now accepts all three new fields.

## 2.0.0

**Breaking change:** v2.0.0 is a complete API rewrite. The package is now a headless
engine — all widget, controller, and localization code has been removed. Consumers own
their own UI.

### Removed symbols

| Removed | Reason |
|---------|--------|
| `MacosUpdater` class | Replaced by top-level functions |
| `MacosUpdaterController` | Replaced by `checkForUpdate` / `downloadUpdate` functions |
| `DesktopUpdateInheritedWidget` | No longer needed (no controller) |
| `DesktopUpdateWidget` | Consumers build their own UI |
| `DesktopUpdateSliver` | Consumers build their own UI |
| `DesktopUpdateDirectCard` | Consumers build their own UI |
| `UpdateDialogListener` | Consumers build their own UI |
| `DesktopUpdateLocalization` | Package has no localizable strings |
| `ItemModel`, `AppArchiveModel`, `ChangeModel` | Replaced by `UpdateInfo` |
| `FileHashModel` | Replaced by `FileHash` |
| `UpdateProgress` (v1) | Replaced by v2 `UpdateProgress` in `src/models/` |

### Migration guide

#### Step 1 — Implement UpdateSource

Before (v1): `MacosUpdaterController` fetched the app-archive JSON for you.

After (v2): Implement `UpdateSource` to fetch version metadata from your own backend.

```dart
// v2: implement UpdateSource
class MyUpdateSource implements UpdateSource {
  @override
  Future<UpdateInfo?> getLatestUpdateInfo() async {
    // fetch from your server and return UpdateInfo, or null if up-to-date
    final response = await http.get(Uri.parse("https://example.com/app-archive.json"));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    // parse and return UpdateInfo(...)
  }

  @override
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) async {
    final response = await http.get(Uri.parse("$remoteBaseUrl/hashes.json"));
    // parse and return List<FileHash>
  }
}
```

#### Step 2 — Check for updates

Before (v1):
```dart
// v1: controller-based
final controller = MacosUpdaterController(
  appArchiveUrl: Uri.parse("https://example.com/app-archive.json"),
  localization: const DesktopUpdateLocalization(...),
);
// controller was placed in widget tree via DesktopUpdateWidget
```

After (v2):
```dart
// v2: function-based
final result = await checkForUpdate(MyUpdateSource());
switch (result) {
  case UpToDate():
    // nothing to do
  case UpdateAvailable(:final info):
    // info.changedFiles contains only the files that changed
    await downloadUpdate(info, onProgress: (progress) {
      // update your UI
    });
    await applyUpdate(); // restarts the app
}
```

#### Step 3 — Remove widget imports

Before (v1):
```dart
import "package:macos_updater/updater_controller.dart";
import "package:macos_updater/widget/update_widget.dart";

// in build():
return DesktopUpdateWidget(
  controller: _controller,
  child: myChild,
);
```

After (v2):
```dart
import "package:macos_updater/macos_updater.dart";

// Build your own UI — the package provides no widgets.
// Use checkForUpdate / downloadUpdate / applyUpdate from your state management layer.
```

#### Complete import change

Before (v1):
```dart
import "package:macos_updater/macos_updater.dart";        // MacosUpdater class
import "package:macos_updater/updater_controller.dart";     // MacosUpdaterController
import "package:macos_updater/widget/update_widget.dart";   // DesktopUpdateWidget
```

After (v2):
```dart
import "package:macos_updater/macos_updater.dart"; // everything in one import
```

## 1.3.0
* Revert fix macOS issues, sorry for the inconvenience, do not use 1.2.0 for macOS

## 1.2.0
* Fix macOS issues (thanks to @TheFilyng)

## 1.1.1

* Fix download and skip this version localization and add colors

## 1.1.0

* Fix alert dialog skip condition

## 1.0.5

* Add alert dialog option

## 1.0.4

* Add custom direct widget for theme colors

## 1.0.3

* Fix mandotory skip issue

## 1.0.2

* Lower macOS platform requirement to 10.14
* Add DesktopUpdateSliver widget
* Update version to 1.0.2

## 1.0.1

* Add repository link to pubspec.yaml
* Add example visual to README.md

## 1.0.0

* First version of plugin
