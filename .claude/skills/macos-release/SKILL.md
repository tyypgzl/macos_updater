---
name: macos-release
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
bash .claude/skills/macos-release/scripts/generate_hashes.sh <version> <buildNumber>
```

Example: `bash .claude/skills/macos-release/scripts/generate_hashes.sh 1.0.0 1`

**Important:** Do NOT generate hashes manually with `shasum`. The hashes must be **base64-encoded SHA-256** (not hex) and use the `filePath` JSON key to match the Dart runtime. The shell script handles this correctly.

Output: `app/dist/{buildNumber}/{version}+{buildNumber}-macos/` containing all `.app/Contents/` files + `hashes.json`

### Step 5: Upload OTA Files

Run from the **project root**:

```bash
bash .claude/skills/macos-release/scripts/upload_release.sh <version> <buildNumber>
```

Example: `bash .claude/skills/macos-release/scripts/upload_release.sh 1.0.0 1`

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
bash .claude/skills/macos-release/scripts/create_dmg.sh <version> <buildNumber>
```

Example: `bash .claude/skills/macos-release/scripts/create_dmg.sh 1.0.0 1`

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
