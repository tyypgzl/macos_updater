#!/bin/bash
set -euo pipefail

# Usage: upload_release.sh <version> <buildNumber>
# Example: upload_release.sh 1.0.0 1
#
# Pushes update files to tyypgzl/appshot-releases repo so they're
# accessible via raw.githubusercontent.com URLs. The macos_updater
# package downloads individual files from remoteBaseUrl/filePath,
# and raw URLs preserve the directory structure.

VERSION="${1:?Usage: upload_release.sh <version> <buildNumber>}"
BUILD_NUMBER="${2:?Usage: upload_release.sh <version> <buildNumber>}"
REPO="tyypgzl/appshot-releases"
# dist/ may be at project root or under app/
if [ -d "dist/${BUILD_NUMBER}" ]; then
  DIST_ROOT="dist"
elif [ -d "app/dist/${BUILD_NUMBER}" ]; then
  DIST_ROOT="app/dist"
else
  echo "Error: dist/${BUILD_NUMBER} not found at project root or under app/"
  exit 1
fi
ARCHIVE_DIR="${DIST_ROOT}/${BUILD_NUMBER}/${VERSION}+${BUILD_NUMBER}-macos"
TEMP_DIR=$(mktemp -d)
REMOTE_DIR="v${VERSION}"
PROJECT_DIR="$(pwd)"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [ ! -d "$ARCHIVE_DIR" ]; then
  echo "Error: Archive directory not found: $ARCHIVE_DIR"
  echo "Run 'dart run macos_updater:release macos' and 'dart run macos_updater:archive macos' first."
  exit 1
fi

if [ ! -f "$ARCHIVE_DIR/hashes.json" ]; then
  echo "Error: hashes.json not found in $ARCHIVE_DIR"
  echo "Run 'dart run macos_updater:archive macos' first."
  exit 1
fi

echo "=== macOS Release Upload ==="
echo "Version:  $VERSION"
echo "Build:    $BUILD_NUMBER"
echo "Archive:  $ARCHIVE_DIR"
echo "Target:   $REPO/$REMOTE_DIR"
echo ""

# Clone or init the releases repo
echo "Cloning $REPO..."
if ! gh repo clone "$REPO" "$TEMP_DIR" -- --depth 1 2>/dev/null; then
  echo "Empty repo detected, initializing..."
  cd "$TEMP_DIR"
  git init
  git remote add origin "https://github.com/$REPO.git"
  cd "$PROJECT_DIR"
fi

# Configure git lfs for large files (Flutter framework binaries)
cd "$TEMP_DIR"
if command -v git-lfs &>/dev/null; then
  git lfs install --local 2>/dev/null || true
  git lfs track "*.dylib" "*.so" "*.framework" 2>/dev/null || true
fi
cd "$PROJECT_DIR"

# Clear old version dir if exists, then copy new files
rm -rf "$TEMP_DIR/$REMOTE_DIR"
mkdir -p "$TEMP_DIR/$REMOTE_DIR"

echo "Copying files..."
cp -R "$ARCHIVE_DIR/" "$TEMP_DIR/$REMOTE_DIR/"

# Remove .DS_Store files
find "$TEMP_DIR/$REMOTE_DIR" -name ".DS_Store" -delete 2>/dev/null || true

# Count files
FILE_COUNT=$(find "$TEMP_DIR/$REMOTE_DIR" -type f | wc -l | tr -d ' ')
echo "Copied $FILE_COUNT files to $REMOTE_DIR/"

# Check for files over GitHub's 100MB limit
LARGE_FILES=$(find "$TEMP_DIR/$REMOTE_DIR" -type f -size +100M 2>/dev/null || true)
if [ -n "$LARGE_FILES" ]; then
  echo ""
  echo "WARNING: Files over 100MB detected (GitHub limit):"
  echo "$LARGE_FILES"
  echo ""
  echo "Consider using Git LFS or splitting large files."
  echo "Continuing anyway..."
fi

# Commit and push
cd "$TEMP_DIR"
git add -A
git commit -m "Release v${VERSION} (build ${BUILD_NUMBER})"
git push origin main

# Return to project dir before cleanup
cd "$PROJECT_DIR"

echo ""
echo "=== Upload Complete ==="
echo ""
echo "Remote base URL:"
echo "https://raw.githubusercontent.com/$REPO/main/$REMOTE_DIR"
echo ""
echo "Verify hashes.json:"
echo "https://raw.githubusercontent.com/$REPO/main/$REMOTE_DIR/hashes.json"
echo ""
echo "Update Firebase Remote Config 'update' key:"
echo '{'
echo '  "macos": {'
echo "    \"minimum\": \"$VERSION\","
echo "    \"latest\": \"$VERSION\","
echo '    "active": true,'
echo "    \"url\": \"https://raw.githubusercontent.com/$REPO/main/$REMOTE_DIR\""
echo '  }'
echo '}'

# Create a GitHub release tag for tracking
echo ""
echo "Creating GitHub release tag..."
gh release create "v${VERSION}" \
  --repo "$REPO" \
  --title "v${VERSION}" \
  --notes "macOS release v${VERSION} (build ${BUILD_NUMBER})" \
  2>/dev/null || echo "Release tag v${VERSION} already exists, skipping."

echo ""
echo "Done!"
