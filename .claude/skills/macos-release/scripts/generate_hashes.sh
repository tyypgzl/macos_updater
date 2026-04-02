#!/bin/bash
set -euo pipefail

# Usage: generate_hashes.sh <version> <buildNumber>
# Example: generate_hashes.sh 1.0.0 1
#
# Generates hashes.json for the macOS release archive.
# Copies .app/Contents/ to a separate archive dir and generates SHA-256 hashes.
# The .app bundle is NOT modified or deleted.

VERSION="${1:?Usage: generate_hashes.sh <version> <buildNumber>}"
BUILD_NUMBER="${2:?Usage: generate_hashes.sh <version> <buildNumber>}"

# dist/ may be at project root or under app/
if [ -d "dist/${BUILD_NUMBER}" ]; then
  DIST_ROOT="dist"
elif [ -d "app/dist/${BUILD_NUMBER}" ]; then
  DIST_ROOT="app/dist"
else
  echo "Error: dist/${BUILD_NUMBER} not found at project root or under app/"
  exit 1
fi

APP_DIR="${DIST_ROOT}/${BUILD_NUMBER}/appshot-${VERSION}+${BUILD_NUMBER}-macos/appshot.app/Contents"
ARCHIVE_DIR="${DIST_ROOT}/${BUILD_NUMBER}/${VERSION}+${BUILD_NUMBER}-macos"

if [ ! -d "$APP_DIR" ]; then
  echo "Error: App Contents not found: $APP_DIR"
  echo "Run 'dart run macos_updater:release macos' first."
  exit 1
fi

# Clean archive dir only (not the .app dir)
rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

echo "Copying Contents from $APP_DIR..."
cp -R "$APP_DIR/" "$ARCHIVE_DIR/"

# Remove .DS_Store files
find "$ARCHIVE_DIR" -name ".DS_Store" -delete 2>/dev/null || true

echo "Generating hashes..."

# Build JSON array of file hashes
HASHES="["
FIRST=true

while IFS= read -r -d '' file; do
  REL_PATH="${file#$ARCHIVE_DIR/}"

  if [ "$REL_PATH" = "hashes.json" ]; then
    continue
  fi

  HASH=$(openssl dgst -sha256 -binary "$file" | base64)
  LENGTH=$(stat -f%z "$file")

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    HASHES="$HASHES,"
  fi

  HASHES="$HASHES{\"filePath\":\"$REL_PATH\",\"hash\":\"$HASH\",\"length\":$LENGTH}"
done < <(find "$ARCHIVE_DIR" -type f -print0 | sort -z)

HASHES="$HASHES]"

echo "$HASHES" > "$ARCHIVE_DIR/hashes.json"

FILE_COUNT=$(find "$ARCHIVE_DIR" -type f -not -name "hashes.json" | wc -l | tr -d ' ')
echo "Generated hashes for $FILE_COUNT files"
echo "Output: $ARCHIVE_DIR/hashes.json"
