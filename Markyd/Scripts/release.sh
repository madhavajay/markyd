#!/usr/bin/env bash
# Markyd one-shot release helper.
# Usage: Scripts/release.sh [marketing_version] [build_number]
# If no version/build args are provided, values from version.env are used.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/version.env"

LOG() { printf "==> %s\n" "$*"; }
ERR() { printf "ERROR: %s\n" "$*" >&2; exit 1; }

if [[ $# -ge 2 ]]; then
  VERSION="$1"
  BUILD="$2"
else
  VERSION="$MARKETING_VERSION"
  BUILD="$BUILD_NUMBER"
fi

ZIP_NAME="Markyd-${VERSION}.zip"
DSYM_ZIP="Markyd-${VERSION}.dSYM.zip"
APP_BUNDLE="Markyd.app"

require() {
  command -v "$1" >/dev/null || ERR "Missing required command: $1"
}

require git
require swift
require gh
require curl

[[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] && \
  ERR "APP_STORE_CONNECT_* env vars must be set."

git diff --quiet || ERR "Working tree is not clean."

./Scripts/validate_changelog.sh "$VERSION"

update_file_versions() {
  LOG "Bumping versions to $VERSION ($BUILD)"
  python3 - "$VERSION" "$BUILD" <<'PY' || ERR "Failed to bump versions"
import sys, pathlib, re
ver, build = sys.argv[1], sys.argv[2]

def repl(path: pathlib.Path, pattern: str, replacement: str):
    text = path.read_text()
    new, n = re.subn(pattern, replacement, text, flags=re.M)
    if n == 0:
        raise SystemExit(f"no match in {path}")
    path.write_text(new)

repl(pathlib.Path("version.env"),
     r'^(MARKETING_VERSION=).*$',
     rf'\g<1>{ver}')
repl(pathlib.Path("version.env"),
     r'^(BUILD_NUMBER=).*$',
     rf'\g<1>{build}')
repl(pathlib.Path("Info.plist"),
     r'(CFBundleShortVersionString</key>\s*<string>)([^<]+)',
     rf'\g<1>{ver}')
repl(pathlib.Path("Info.plist"),
     r'(CFBundleVersion</key>\s*<string>)([^<]+)',
     rf'\g<1>{build}')
PY
}

update_changelog_header() {
  LOG "Ensuring changelog header is dated for $VERSION"
  python3 - "$VERSION" <<'PY' || ERR "Failed to update CHANGELOG"
import sys, pathlib, re, datetime
ver = sys.argv[1]
today = datetime.date.today().strftime("%Y-%m-%d")
p = pathlib.Path("CHANGELOG.md")
text = p.read_text()
pat = re.compile(rf"^##\s+{re.escape(ver)}\s+—\s+.*$", re.M)
new, n = pat.subn(f"## {ver} — {today}", text, count=1)
if n == 0:
    sys.exit("Changelog section not found for version")
p.write_text(new)
PY
}

run_quality_gates() {
  LOG "Running swift test"
  swift test
}

build_and_notarize() {
  LOG "Building, signing, notarizing"
  ./Scripts/sign-and-notarize.sh
}

verify_local_artifacts() {
  LOG "Verifying local artifacts"
  spctl -a -t exec -vv "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose "$APP_BUNDLE"
}

extract_notes() {
  LOG "Extracting release notes from CHANGELOG.md"
  NOTES_PATH=$(mktemp -t markyd-notes.XXXXXX)
  python3 - "$VERSION" "$NOTES_PATH" <<'PY' || ERR "Failed to extract notes"
import sys, pathlib, re
version = sys.argv[1]
out = pathlib.Path(sys.argv[2])
text = pathlib.Path("CHANGELOG.md").read_text()
pattern = re.compile(rf"^##\s+{re.escape(version)}\s+—\s+.*$", re.M)
m = pattern.search(text)
if not m:
    raise SystemExit("section not found")
start = m.end()
next_header = text.find("\n## ", start)
chunk = text[start: next_header if next_header != -1 else len(text)]
lines = [ln for ln in chunk.strip().splitlines() if ln.strip()]
out.write_text("\n".join(lines) + "\n")
PY
  NOTES_FILE="$NOTES_PATH"
}

create_tag_and_release() {
  LOG "Creating tag v$VERSION"
  git add CHANGELOG.md version.env Info.plist
  git commit -m "Release $VERSION (build $BUILD)"
  git tag "v$VERSION"
  LOG "Pushing main and tag"
  git push origin main
  git push origin "v$VERSION"

  LOG "Uploading artifacts to GitHub release"
  local notes_arg=()
  if [[ -n "${NOTES_FILE:-}" ]]; then
    notes_arg=(--notes-file "$NOTES_FILE")
  else
    ERR "Notes file missing after extraction"
  fi
  gh release create "v$VERSION" "$ZIP_NAME" "$DSYM_ZIP" \
    --title "Markyd $VERSION" \
    "${notes_arg[@]}" --draft=false --verify-tag
}

update_file_versions
update_changelog_header
run_quality_gates
build_and_notarize
verify_local_artifacts
extract_notes
create_tag_and_release

LOG "Release $VERSION (build $BUILD) completed."
