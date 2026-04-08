#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Markyd"
APP_IDENTITY="Developer ID Application: Peter Steinberger (Y5PE65HELJ)"
APP_BUNDLE="Markyd.app"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/version.env"
ZIP_NAME="Markyd-${MARKETING_VERSION}.zip"
DSYM_ZIP="Markyd-${MARKETING_VERSION}.dSYM.zip"

if [[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  echo "Missing APP_STORE_CONNECT_* env vars (API key, key id, issuer id)." >&2
  exit 1
fi

echo "$APP_STORE_CONNECT_API_KEY_P8" | sed 's/\\n/\n/g' > /tmp/markyd-api-key.p8
trap 'rm -f /tmp/markyd-api-key.p8 /tmp/MarkydNotarize.zip' EXIT

cd "$ROOT"

swift build -c release --arch arm64
./Scripts/package_app.sh release

echo "Signing with $APP_IDENTITY"
codesign --force --deep --options runtime --timestamp --sign "$APP_IDENTITY" "$APP_BUNDLE"

DITTO_BIN=${DITTO_BIN:-/usr/bin/ditto}
"$DITTO_BIN" -c -k --keepParent --sequesterRsrc "$APP_BUNDLE" /tmp/MarkydNotarize.zip

echo "Submitting for notarization"
xcrun notarytool submit /tmp/MarkydNotarize.zip \
  --key /tmp/markyd-api-key.p8 \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

echo "Stapling ticket"
xcrun stapler staple "$APP_BUNDLE"

"$DITTO_BIN" -c -k --keepParent --sequesterRsrc "$APP_BUNDLE" "$ZIP_NAME"

spctl -a -t exec -vv "$APP_BUNDLE"
stapler validate "$APP_BUNDLE"

echo "Packaging dSYM"
DSYM_PATH=".build/arm64-apple-macosx/release/Markyd.dSYM"
if [[ ! -d "$DSYM_PATH" ]]; then
  echo "Missing dSYM at $DSYM_PATH" >&2
  exit 1
fi
"$DITTO_BIN" -c -k --keepParent "$DSYM_PATH" "$DSYM_ZIP"

echo "Done: $ZIP_NAME and $DSYM_ZIP"
