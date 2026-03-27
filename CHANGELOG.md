## 2.0.0

**Breaking change:** v2.0.0 is a complete API rewrite. The package is now a headless
engine — all widget, controller, and localization code has been removed. Consumers own
their own UI.

### Removed symbols

| Removed | Reason |
|---------|--------|
| `DesktopUpdater` class | Replaced by top-level functions |
| `DesktopUpdaterController` | Replaced by `checkForUpdate` / `downloadUpdate` functions |
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

Before (v1): `DesktopUpdaterController` fetched the app-archive JSON for you.

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
final controller = DesktopUpdaterController(
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
import "package:desktop_updater/updater_controller.dart";
import "package:desktop_updater/widget/update_widget.dart";

// in build():
return DesktopUpdateWidget(
  controller: _controller,
  child: myChild,
);
```

After (v2):
```dart
import "package:desktop_updater/desktop_updater.dart";

// Build your own UI — the package provides no widgets.
// Use checkForUpdate / downloadUpdate / applyUpdate from your state management layer.
```

#### Complete import change

Before (v1):
```dart
import "package:desktop_updater/desktop_updater.dart";        // DesktopUpdater class
import "package:desktop_updater/updater_controller.dart";     // DesktopUpdaterController
import "package:desktop_updater/widget/update_widget.dart";   // DesktopUpdateWidget
```

After (v2):
```dart
import "package:desktop_updater/desktop_updater.dart"; // everything in one import
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
