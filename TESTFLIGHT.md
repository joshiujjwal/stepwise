# Shipping stepwise to TestFlight

This repo includes a complete, validated TestFlight pipeline. The build + upload
runs on a GitHub **macOS runner** (Xcode + iOS platform preinstalled). You only
need to do the one-time Apple setup and add repo secrets — then click **Run**.

> What's already done for you: iOS project (bundle id `com.joshiujjwal.stepwise`,
> deployment target 16.0), the MediaPipe static-linkage Podfile fix, fastlane
> lanes, `ExportOptions.plist`, and `.github/workflows/ios-testflight.yml`
> (manual trigger). Tests gate the release.

---

## What only you can do (Apple-side, ~20 min, one time)
1. **Enroll** in the Apple Developer Program ($99/yr): <https://developer.apple.com/programs/>.
2. **Register the App ID** `com.joshiujjwal.stepwise` (or change it — see below) at
   Certificates, Identifiers & Profiles.
3. **Create the app record** in App Store Connect (<https://appstoreconnect.apple.com>)
   with that bundle id, name "Stepwise".
4. **App Store Connect API key** (Users and Access → Integrations → App Store Connect API):
   create a key with **App Manager** role. Download the `.p8` (once!). Note the
   **Key ID** and **Issuer ID**.
5. **Distribution signing** — easiest is to let Xcode create an *Apple Distribution*
   certificate + an *App Store* provisioning profile for the App ID, then export:
   - the certificate as a **.p12** (with a password), and
   - the **.mobileprovision** profile.
   (Or adopt fastlane `match` later for team signing.)

## Repo secrets to add
GitHub → repo **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | What it is |
|---|---|
| `ASC_KEY_ID` | App Store Connect API **Key ID** |
| `ASC_ISSUER_ID` | App Store Connect API **Issuer ID** |
| `ASC_KEY_P8` | **Full contents** of the `.p8` file (paste the text, incl. BEGIN/END lines) |
| `APPLE_TEAM_ID` | Your 10-char Developer **Team ID** — this account's is **`ABHGN3M845`** |
| `APP_STORE_CONNECT_TEAM_ID` | App Store Connect team id (often same; from `fastlane`/portal) |
| `DIST_CERT_P12_BASE64` | `base64 -i dist.p12` of your distribution cert |
| `DIST_CERT_PASSWORD` | password you set when exporting the `.p12` |
| `PROVISIONING_PROFILE_BASE64` | `base64 -i profile.mobileprovision` |

Generate the base64 values locally:
```bash
base64 -i dist.p12 | pbcopy            # -> DIST_CERT_P12_BASE64
base64 -i stepwise.mobileprovision | pbcopy   # -> PROVISIONING_PROFILE_BASE64
```

## Ship it
GitHub → **Actions → iOS TestFlight → Run workflow** (optionally type a "What to
test" note). The workflow:
1. `flutter pub get` and **`flutter test`** (release is gated on green tests),
2. imports your cert + profile, fills the team id into `ExportOptions.plist`,
3. `flutter build ipa` (injects the **on-device Gemma** model config so the app
   downloads the model from the public CDN on first launch — see note below),
4. `bundle exec fastlane ios upload` → TestFlight.

When processing finishes (a few minutes), the build appears in App Store Connect →
TestFlight. Add yourself as an internal tester to install via the TestFlight app.

> **Model config.** Without a `GEMMA_MODEL_*` dart-define the app ships in offline
> **demo mode** (no on-device Gemma). CI passes the public Front Door CDN URL via
> `--dart-define=GEMMA_MODEL_CDN_URL=…` (fetched tokenless — **no SAS secret in the
> IPA**), plus `GEMMA_MODEL_TYPE=gemmaIt` and `GEMMA_MAX_TOKENS=2048`. Override the
> URL with a repo/environment variable `GEMMA_MODEL_CDN_URL`. The model (~3.6 GB) is
> downloaded on first launch. Locally, `--dart-define-from-file=gemma.local.json`
> supplies the same values.

---

## Run it locally instead (this Mac has Xcode)
```bash
cd ios && bundle install
# export the same env vars as the secrets above, then:
cd .. && flutter build ipa --release \
  --dart-define-from-file=gemma.local.json \
  --export-options-plist=ios/ExportOptions.plist
cd ios && bundle exec fastlane ios upload
# sanity check auth only (no build): bundle exec fastlane ios check_auth
```
> Note: producing a device archive requires the iOS **platform** installed in Xcode
> (Settings → Components). The CI runner has it preinstalled, which is why the
> GitHub Actions path is recommended.

## Changing the bundle id / signing
- Bundle id appears in `ios/Runner.xcodeproj/project.pbxproj`,
  `ios/fastlane/Appfile`, `ios/fastlane/Fastfile`, and `.github/workflows/ios-testflight.yml`.
  Change all four (search `com.joshiujjwal.stepwise`).
- Prefer **fastlane match** for team signing? Add a `Matchfile` and swap the cert/
  profile import steps for `match(type: "appstore")`.

## Android (bonus)
`flutter build appbundle --release` produces a Play-ready `.aab`. Play Internal
Testing is the Android analog of TestFlight (not wired here yet).
