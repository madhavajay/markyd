#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source "$ROOT/version.env"

MODE="${1:-debug}"
APP="$ROOT/Markyd.app"
BUILD_DIR="$ROOT/.build/${MODE}"

if [[ "$MODE" == "release" ]]; then
  BUILD_DIR="$ROOT/.build/arm64-apple-macosx/release"
fi

BIN="$BUILD_DIR/Markyd"

if [[ ! -f "$BIN" ]]; then
  echo "Binary not found at $BIN — run 'swift build -c $MODE' first." >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ "$MODE" == "release" ]]; then
  BUNDLE_ID="com.madhavajay.markyd"
  FEED_URL="https://raw.githubusercontent.com/madhavajay/markyd/main/appcast.xml"
  AUTO_CHECKS="true"
else
  BUNDLE_ID="com.madhavajay.markyd.debug"
  FEED_URL=""
  AUTO_CHECKS="false"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Markyd</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Markyd</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>SUFeedURL</key>
    <string>${FEED_URL}</string>
    <key>SUEnableAutomaticChecks</key>
    <${AUTO_CHECKS}/>
    <key>MarkydBuildTimestamp</key>
    <string>${BUILD_TIMESTAMP}</string>
    <key>MarkydGitCommit</key>
    <string>${GIT_COMMIT}</string>
</dict>
</plist>
PLIST

cp "$BIN" "$APP/Contents/MacOS/Markyd"
chmod +x "$APP/Contents/MacOS/Markyd"

echo "Packaged $APP ($MODE, v${MARKETING_VERSION} build ${BUILD_NUMBER})"
