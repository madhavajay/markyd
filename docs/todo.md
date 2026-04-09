# Markyd Release & Auto-Update TODO

## What's done

- [x] GitHub Actions CI workflow (build + test on every push/PR)
- [x] GitHub Actions Release workflow (sign, notarize, upload on release publish)
- [x] `Scripts/package_app.sh` — builds `.app` bundle (debug/release modes)
- [x] `Scripts/sign-and-notarize.sh` — sign → notarize → staple → verify → zip
- [x] `Scripts/release.sh` — one-shot release (bump versions, changelog, build, tag, push, create GitHub Release)
- [x] `Scripts/validate_changelog.sh` — ensures CHANGELOG.md is finalized
- [x] `version.env` — centralized version tracking
- [x] `CHANGELOG.md` — release notes template
- [x] `Info.plist` — Sparkle `SUFeedURL` set to `https://raw.githubusercontent.com/madhavajay/markyd/main/appcast.xml`
- [x] `.gitignore` — excludes `.app` bundles and release artifacts

## Code signing & notarization

- [ ] Get your own Developer ID Application certificate (requires Apple Developer Program, $99/year)
- [ ] Update signing identity in `Scripts/sign-and-notarize.sh` — replace `"Developer ID Application: Peter Steinberger (Y5PE65HELJ)"` with your own
- [ ] Update signing identity in `.github/workflows/release.yml` — replace `APP_IDENTITY` env var

## GitHub Secrets

Set these in **Settings → Secrets and variables → Actions** on `madhavajay/markyd`:

- [ ] `APP_STORE_CONNECT_API_KEY_P8` — `.p8` key file contents (from App Store Connect → Users and Access → Keys)
- [ ] `APP_STORE_CONNECT_KEY_ID` — the Key ID shown next to your API key
- [ ] `APP_STORE_CONNECT_ISSUER_ID` — the Issuer ID at the top of the Keys page

## Sparkle auto-update

### 1. Add Sparkle dependency

- [ ] Add to `Markyd/Package.swift`:
  ```swift
  .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
  ```
- [ ] Add `"Sparkle"` to the Markyd executable target dependencies

### 2. Generate ed25519 signing keys

- [ ] Install Sparkle tools: `brew install sparkle`
- [ ] Run `generate_keys` — this outputs a public key and saves the private key
- [ ] Store the private key file securely (you'll need it for every release)
- [ ] Set `SPARKLE_PRIVATE_KEY_FILE` env var pointing to the private key for local releases

### 3. Add public key to Info.plist

- [ ] Add `SUPublicEDKey` to `Markyd/Info.plist`:
  ```xml
  <key>SUPublicEDKey</key>
  <string>YOUR_PUBLIC_ED25519_KEY_HERE</string>
  ```

### 4. Wire Sparkle into the app

- [ ] Add `SPUStandardUpdaterController` or `SPUUpdater` in `MarkydApp.swift`
- [ ] Optionally add a "Check for Updates" menu item in `MenuContentView.swift`
- [ ] Update `Scripts/package_app.sh` to embed `Sparkle.framework` into `Contents/Frameworks/` and set rpath

### 5. Create appcast

- [ ] After first signed release, generate appcast:
  ```bash
  SPARKLE_PRIVATE_KEY_FILE=path/to/key ./Scripts/make_appcast.sh Markyd-0.1.0.zip
  ```
- [ ] Write a `Scripts/make_appcast.sh` (adapted from Trimmy's)
- [ ] Write a `Scripts/changelog-to-html.sh` for HTML release notes in appcast
- [ ] Commit `appcast.xml` to repo root
- [ ] Sparkle reads updates from `SUFeedURL` → `appcast.xml` → downloads new `.zip` from GitHub Releases

## First release checklist

1. [ ] Complete all items above
2. [ ] Finalize `CHANGELOG.md` — change `Unreleased` to today's date
3. [ ] Run `swift test` locally
4. [ ] Run `Scripts/release.sh 0.1.0 1`
5. [ ] Verify the GitHub Release has `Markyd-0.1.0.zip` and `Markyd-0.1.0.dSYM.zip`
6. [ ] Verify `appcast.xml` is committed and accessible at the raw URL
7. [ ] Test auto-update by installing the app and publishing a `0.1.1` release
