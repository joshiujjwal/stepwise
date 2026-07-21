#!/usr/bin/env bash
#
# build-script.bash — Regenerate a release IPA for App Store / TestFlight with
# the on-device Gemma model baked in so it downloads at runtime from Azure Blob
# Storage using a SAS token.
#
# WHY THIS SCRIPT EXISTS
#   `flutter build ipa` in CI does NOT pass any model defines, so the released
#   app falls back to the offline demo planner. To ship an app that downloads
#   the real Gemma model on first launch, the model URL must be compiled into
#   the IPA via --dart-define (see lib/main.dart `_gemmaService`).
#
# IMPORTANT — Azure Blob SAS auth:
#   flutter_gemma sends an auth token as an "Authorization: Bearer <token>"
#   header (smart_downloader.dart). Azure Blob SAS is NOT a bearer token — its
#   signature must be in the URL query string. So we APPEND the SAS to the model
#   URL and pass NO token. (The model id/filename is derived from the URL path
#   only, so the query string does not affect installed-model detection.)
#
#   Do NOT use --dart-define=AZURE_BLOB_SAS_TOKEN for a Blob SAS URL: it becomes
#   a Bearer header that Azure ignores, and the download 403s.
#
# CONFIG SOURCES (first match wins, per setting)
#   1. Environment variables (or an untracked `.env.build` shell file).
#   2. `gemma.local.json` (git-ignored) holding the FULL signed model URL:
#        {
#          "GEMMA_MODEL_URL": "https://acct.../model.litertlm?sv=...&sig=...&sr=f",
#          "GEMMA_MODEL_TYPE": "gemmaIt",
#          "GEMMA_MAX_TOKENS": "2048"
#        }
#
#   The model source may be supplied in any of these ways (first match wins):
#     - GEMMA_MODEL_CDN_URL .... tokenless Azure Front Door / CDN URL (PREFERRED;
#         edge-cached per region, no SAS in the IPA). Provision it with
#         tool/infra/setup_frontdoor.sh.
#     - GEMMA_MODEL_URL ........ full Blob URL with the SAS query string already on it
#     - or GEMMA_MODEL_BASE_URL + AZURE_BLOB_SAS_TOKEN ... composed by this script
#
#   APPLE_TEAM_ID is required (defaults to the project's DEVELOPMENT_TEAM if set
#   there). Then run:  ./build-script.bash
#
#   The resulting IPA is written to build/ios/ipa/*.ipa.
#
# SECURITY
#   With a SAS URL, the SAS lands in the compiled binary, so anyone with the IPA
#   can extract it. Use a short-lived, read-only, single-blob SAS and rotate it,
#   or prefer GEMMA_MODEL_CDN_URL which ships no secret at all. Never commit
#   `.env.build` (it is git-ignored).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

EXPORT_OPTIONS="ios/ExportOptions.plist"

# ---- 1. Load optional .env.build (does not override already-exported vars) ----
if [[ -f .env.build ]]; then
  echo "==> Loading config from .env.build"
  set -o allexport
  # shellcheck disable=SC1091
  source .env.build
  set +o allexport
fi

# ---- 1b. Fall back to gemma.local.json for any unset model settings ----
if [[ -f gemma.local.json ]]; then
  json_get() { python3 -c "import json,sys; print(json.load(open('gemma.local.json')).get('$1',''))"; }
  : "${GEMMA_MODEL_CDN_URL:=$(json_get GEMMA_MODEL_CDN_URL)}"
  : "${GEMMA_MODEL_URL:=$(json_get GEMMA_MODEL_URL)}"
  : "${GEMMA_MODEL_TYPE:=$(json_get GEMMA_MODEL_TYPE)}"
  : "${GEMMA_MAX_TOKENS:=$(json_get GEMMA_MAX_TOKENS)}"
  : "${GEMMA_MAX_DOWNLOAD_RETRIES:=$(json_get GEMMA_MAX_DOWNLOAD_RETRIES)}"
fi

# Default the team to whatever the Xcode project already targets.
if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  APPLE_TEAM_ID="$(grep -m1 'DEVELOPMENT_TEAM = ' ios/Runner.xcodeproj/project.pbxproj \
    | sed -E 's/.*DEVELOPMENT_TEAM = ([A-Z0-9]+);.*/\1/' || true)"
fi

# ---- 2. Resolve the model source (CDN wins; else a signed Blob URL) ----
GEMMA_MODEL_TYPE="${GEMMA_MODEL_TYPE:-gemmaIt}"

# Front Door / CDN is preferred: a single, tokenless, edge-cached URL served
# near every user. When set it takes precedence and NO SAS is compiled into the
# IPA (the edge handles origin auth — see tool/infra/setup_frontdoor.sh and
# lib/main.dart selectModelNetworkSource).
USE_CDN=false
if [[ -n "${GEMMA_MODEL_CDN_URL:-}" ]]; then
  USE_CDN=true
elif [[ -z "${GEMMA_MODEL_URL:-}" ]]; then
  # Compose from base URL + SAS query string when a full URL wasn't provided.
  : "${GEMMA_MODEL_BASE_URL:?Provide GEMMA_MODEL_CDN_URL, or GEMMA_MODEL_URL (full, with SAS), or GEMMA_MODEL_BASE_URL + AZURE_BLOB_SAS_TOKEN}"
  : "${AZURE_BLOB_SAS_TOKEN:?Provide AZURE_BLOB_SAS_TOKEN (SAS query string) when using GEMMA_MODEL_BASE_URL}"
  # Normalize the SAS: tolerate a leading '?' or '&' from copy/paste.
  SAS="${AZURE_BLOB_SAS_TOKEN#\?}"
  SAS="${SAS#&}"
  if [[ "$GEMMA_MODEL_BASE_URL" == *"?"* ]]; then
    GEMMA_MODEL_URL="${GEMMA_MODEL_BASE_URL}&${SAS}"
  else
    GEMMA_MODEL_URL="${GEMMA_MODEL_BASE_URL}?${SAS}"
  fi
fi

: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your 10-character Apple Developer Team ID}"

if [[ "$USE_CDN" == true ]]; then
  echo "==> Model source: CDN (tokenless) ${GEMMA_MODEL_CDN_URL}"
else
  # Redacted preview so we never print the SAS signature to logs/CI.
  echo "==> Model URL: ${GEMMA_MODEL_URL%%\?*}?<sas-redacted>"
fi
echo "==> Model type: ${GEMMA_MODEL_TYPE}"
echo "==> Apple Team: ${APPLE_TEAM_ID}"

# ---- 4. Make a temp ExportOptions with the real Team ID ----
# Build from a COPY so the committed plist (with its placeholder + comment) is
# never modified. The temp file is removed on exit.
EXPORT_OPTIONS_BUILD="$(mktemp -t stepwise-export-options).plist"
cleanup() { rm -f "$EXPORT_OPTIONS_BUILD"; }
trap cleanup EXIT
cp "$EXPORT_OPTIONS" "$EXPORT_OPTIONS_BUILD"
/usr/libexec/PlistBuddy -c "Set :teamID ${APPLE_TEAM_ID}" "$EXPORT_OPTIONS_BUILD"

# ---- 5. Build ----
echo "==> flutter pub get"
flutter pub get

echo "==> flutter build ipa (release)"
# Optional tuning passes through if set in the environment / .env.build.
if [[ "$USE_CDN" == true ]]; then
  DART_DEFINES=(
    "--dart-define=GEMMA_MODEL_CDN_URL=${GEMMA_MODEL_CDN_URL}"
    "--dart-define=GEMMA_MODEL_TYPE=${GEMMA_MODEL_TYPE}"
  )
else
  DART_DEFINES=(
    "--dart-define=GEMMA_MODEL_URL=${GEMMA_MODEL_URL}"
    "--dart-define=GEMMA_MODEL_TYPE=${GEMMA_MODEL_TYPE}"
  )
fi
[[ -n "${GEMMA_MAX_TOKENS:-}" ]] && \
  DART_DEFINES+=("--dart-define=GEMMA_MAX_TOKENS=${GEMMA_MAX_TOKENS}")
[[ -n "${GEMMA_MAX_DOWNLOAD_RETRIES:-}" ]] && \
  DART_DEFINES+=("--dart-define=GEMMA_MAX_DOWNLOAD_RETRIES=${GEMMA_MAX_DOWNLOAD_RETRIES}")
[[ -n "${GEMMA_MODEL_SIZE_BYTES:-}" ]] && \
  DART_DEFINES+=("--dart-define=GEMMA_MODEL_SIZE_BYTES=${GEMMA_MODEL_SIZE_BYTES}")

flutter build ipa --release \
  --export-options-plist="$EXPORT_OPTIONS_BUILD" \
  "${DART_DEFINES[@]}"

# ---- 6. Report ----
echo ""
echo "==> Done. IPA(s):"
ls -1 build/ios/ipa/*.ipa 2>/dev/null || {
  echo "No IPA found in build/ios/ipa/. Check the build output above." >&2
  exit 1
}
echo ""
echo "Upload to TestFlight with:  xcrun altool / Transporter, or"
echo "  (cd ios && bundle exec fastlane ios upload)"
