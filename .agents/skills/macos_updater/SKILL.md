---
name: macos_updater
description: >
  Build macOS release, generate delta update hashes, create DMG installer, and publish to GitHub.
  Use this skill whenever the user wants to build a macOS release, create a new version,
  publish an update, deploy to GitHub, generate hashes, create a DMG, or prepare an OTA update.
  Triggers on: "release", "build release", "yeni versiyon", "publish", "deploy macos",
  "release yap", "versiyon cikar", "github release", "update yayinla", "build al",
  "dmg olustur", "dmg yap", "create dmg".
---

# macOS Release

Build, hash, create DMG, and publish macOS updates to `tyypgzl/appshot-releases`.

Files are pushed to the repo and served via `raw.githubusercontent.com` URLs.
The `macos_updater` package downloads individual files from `remoteBaseUrl/filePath` —
raw URLs preserve directory structure, so the package works without any custom logic.

## Release Flow

### Step 1: Get Version

Ask the user for the new version if not provided. Format: `X.Y.Z+buildNumber` (e.g. `1.0.0+1`).

### Step 2: Update pubspec.yaml

Update `version:` field in `app/pubspec.yaml` with the new version.

### Step 3: Build Release

Run from the **project root**:

```bash
cd app && FLUTTER_ROOT="$(cd ../.fvm/flutter_sdk && pwd)" fvm dart run macos_updater:release macos
```

`$(cd ../.fvm/flutter_sdk && pwd)` resolves the FVM symlink to an absolute path — `readlink -f` is not available on macOS by default.

Output: `app/dist/{buildNumber}/appshot-{version}+{buildNumber}-macos/appshot.app`

### Step 4: Generate Hashes

Try the Dart archive command first:

```bash
cd app && fvm dart run macos_updater:archive macos
```

If it fails (e.g. Dart SDK compatibility errors), use the shell script fallback:

```bash
bash .agents/skills/macos_updater/scripts/generate_hashes.sh <version> <buildNumber>
```

Example: `bash .agents/skills/macos_updater/scripts/generate_hashes.sh 1.0.0 1`

**Important:** Do NOT generate hashes manually with `shasum`. The hashes must be **base64-encoded SHA-256** (not hex) and use the `filePath` JSON key to match the Dart runtime. The shell script handles this correctly.

Output: `app/dist/{buildNumber}/{version}+{buildNumber}-macos/` containing all `.app/Contents/` files + `hashes.json`

### Step 5: Upload OTA Files

Run from the **project root**:

```bash
bash .agents/skills/macos_updater/scripts/upload_release.sh <version> <buildNumber>
```

Example: `bash .agents/skills/macos_updater/scripts/upload_release.sh 1.0.0 1`

The script:
1. Clones `appshot-releases` to a temp dir
2. Copies archive files to `v{version}/`
3. Commits and pushes to `main`
4. Creates a GitHub release tag for version tracking
5. Prints the Remote Config JSON to copy

If files exceed GitHub's 100MB limit, the script warns. Use Git LFS in that case.

### Step 6: Create DMG

Run from the **project root**:

```bash
bash .agents/skills/macos_updater/scripts/create_dmg.sh <version> <buildNumber>
```

Example: `bash .agents/skills/macos_updater/scripts/create_dmg.sh 1.0.0 1`

The script handles the full pipeline:
1. Flutter build (obfuscated, with debug symbols saved to `dist/{buildNumber}/debug-symbols/`)
2. Xcode archive with Distribution entitlements (swaps Release.entitlements temporarily)
3. Developer ID export via `xcodebuild -exportArchive`
4. DMG creation via `create-dmg` (npm) — auto-styled with app icon and Applications shortcut
5. Apple notarization via `notarytool` + staple
6. Upload DMG to the GitHub release tag (created in Step 5)

**Prerequisites:**
- `npm install --global create-dmg`
- Developer ID provisioning profile installed
- Notarytool keychain profile `appshot-notary` (set up via `xcrun notarytool store-credentials`)
- `ExportOptions.plist` at `app/macos/ExportOptions.plist`

Output: `app/dist/Appshot-{version}.dmg` — signed, notarized, stapled, uploaded to GitHub release.

Download URL: `https://github.com/tyypgzl/appshot-releases/releases/download/v{version}/Appshot-{version}.dmg`

### Step 7: Update Firebase Remote Config

Update the `update` key in Firebase Remote Config console:

```json
{
  "macos": {
    "minimum": "<minimum_version>",
    "latest": "<new_version>",
    "active": true,
    "url": "https://raw.githubusercontent.com/tyypgzl/appshot-releases/main/v<new_version>"
  }
}
```

## Package Reference: `macos_updater`

### Overview

`macos_updater` is a headless Flutter plugin for macOS desktop OTA updates. It downloads only changed files by comparing base64-encoded SHA-256 hashes. No built-in UI — consumers implement `UpdateSource` to connect any backend and build their own UI.

### Consumer Integration

Single import:

```dart
import 'package:macos_updater/macos_updater.dart';
```

#### 1. Implement `UpdateSource`

```dart
class MyUpdateSource implements UpdateSource {
  @override
  Future<UpdateDetails?> getUpdateDetails() async {
    // Fetch from Firebase Remote Config, REST API, etc.
    final json = await fetchFromBackend();
    final macosJson = json['macos'] as Map<String, dynamic>?;
    if (macosJson == null) return null;
    return UpdateDetails(
      macos: PlatformUpdateDetails(
        minimum: macosJson['minimum'] as String,
        latest: macosJson['latest'] as String,
        active: macosJson['active'] as bool,
        url: macosJson['url'] as String?,
      ),
      remoteBaseUrl: json['remoteBaseUrl'] as String?,
    );
  }

  @override
  Future<List<FileHash>> getRemoteFileHashes(String remoteBaseUrl) async {
    final response = await http.get(Uri.parse('$remoteBaseUrl/hashes.json'));
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => FileHash.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

#### 2. Check, Download, Apply

```dart
// Check for update — returns sealed UpdateCheckResult
final result = await checkForUpdate(source, enableLogging: true);

switch (result) {
  case UpToDate():
    // No update available
    break;
  case ForceUpdateRequired(:final info):
    // Must update — current version below minimum
    await downloadUpdate(info, onProgress: (p) {
      print('${p.completedFiles}/${p.totalFiles} files');
    });
    await applyUpdate(); // Restarts the app
    break;
  case OptionalUpdateAvailable(:final info):
    // Optional — show UI, let user decide
    await downloadUpdate(info);
    await applyUpdate();
    break;
}
```

### Error Handling

Sealed `UpdateError` hierarchy (exhaustive switch):

| Error | When |
|-------|------|
| `NetworkError` | HTTP failure during fetch or download |
| `HashMismatch` | Downloaded file hash doesn't match expected base64 SHA-256 |
| `NoPlatformEntry` | Bundle directory missing or App Sandbox detected |
| `IncompatibleVersion` | Remote build not newer than installed |
| `RestartFailed` | Native restart (file copy / relaunch) failed |

### CLI Commands

#### `dart run macos_updater:release macos`

Builds a Flutter macOS release and copies the `.app` bundle to `dist/`.

**What it does:**
1. Reads `name` and `version` from `pubspec.yaml` (e.g. `appshot` / `1.0.0+1`)
2. Runs `flutter build macos` with the resolved `FLUTTER_ROOT`
3. Copies built `.app` from `build/macos/Build/Products/Release/` to `dist/{buildNumber}/{name}-{version}+{buildNumber}-macos/{name}.app`

**Requirements:**
- `FLUTTER_ROOT` env var must be set (path to Flutter SDK)
- Run from the app's root directory (where `pubspec.yaml` lives)

**Extra args:** Passes additional arguments to `flutter build macos` (e.g. `--obfuscate`)

**Output structure:**
```
dist/
└── 1/                                    # buildNumber
    └── appshot-1.0.0+1-macos/
        └── appshot.app/
            └── Contents/
                ├── MacOS/appshot
                ├── Frameworks/
                ├── Resources/
                └── ...
```

#### `dart run macos_updater:archive macos`

Copies `.app/Contents/` to a flat archive directory and generates `hashes.json`.

**What it does:**
1. Finds the latest build number folder in `dist/`
2. Locates the `.app` bundle for the specified platform
3. Copies `{name}.app/Contents/` to `dist/{buildNumber}/{version}+{buildNumber}-macos/`
4. Generates `hashes.json` with base64-encoded SHA-256 hashes for every file

**Output structure:**
```
dist/
└── 1/
    ├── appshot-1.0.0+1-macos/            # .app bundle (from release)
    │   └── appshot.app/Contents/...
    └── 1.0.0+1-macos/                    # archive (from archive)
        ├── hashes.json
        ├── MacOS/appshot
        ├── Frameworks/Flutter.framework/...
        ├── Resources/...
        └── ...
```

### hashes.json Format

**Critical:** All hash generation tools (Dart CLI, shell scripts) MUST produce this exact format.

```json
[
  {
    "filePath": "MacOS/appshot",
    "hash": "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=",
    "length": 12345
  },
  {
    "filePath": "Frameworks/Flutter.framework/Flutter",
    "hash": "kXr0X1s6Z7c8GtR5e+2hBg8kN7jL4f9mQpV3w1yA0oI=",
    "length": 67890
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `filePath` | `String` | Relative path from `Contents/` (forward slashes) |
| `hash` | `String` | **Base64-encoded** SHA-256 digest (NOT hex) |
| `length` | `int` | File size in bytes |

**Hash algorithm:** `sha256.convert(fileBytes)` → `base64.encode(digest.bytes)`

Shell equivalent: `openssl dgst -sha256 -binary "$file" | base64`

**WARNING:** `shasum -a 256` produces **hex** output — this is NOT compatible. Always use `openssl dgst -sha256 -binary | base64`.

## How It Works

### OTA Delta Updates

```
raw.githubusercontent.com/tyypgzl/appshot-releases/main/v1.0.0/
├── hashes.json
├── MacOS/appshot
├── Frameworks/Flutter.framework/...
├── Resources/...
└── ...
```

1. App fetches Remote Config `update` key → gets `url`
2. `macos_updater` fetches `{url}/hashes.json`
3. Compares remote hashes vs local app bundle hashes
4. Downloads only changed files from `{url}/{filePath}`
5. Applies update and restarts

### DMG Distribution

DMG is for fresh installs and users who prefer manual download. Hosted on GitHub Releases alongside the OTA files. Signed with Developer ID and notarized by Apple — opens without Gatekeeper warnings.
