#!/bin/sh
# Align embedded native-asset framework Info.plist MinimumOSVersion with the
# framework binary's actual minimum OS version, then re-sign.
#
# Why this exists:
# Flutter hardcodes `const targetIOSVersion = 13` when generating the Info.plist
# for native-asset frameworks (see flutter_tools .../native_assets/ios/native_assets.dart).
# Some prebuilt native binaries — notably `qdrant_edge_ffi` pulled in transitively
# by flutter_gemma — are compiled for a higher minimum (iOS 16). App Store
# validation then rejects the build with:
#   "Invalid Bundle ... does not support the minimum OS Version specified in the
#    Info.plist. (90208)"
# because the binary requires 16 while the plist advertises 13.
#
# This script makes the plist honest (matches the binary) so validation passes.
# It is self-healing: it reads the real minos from each binary, so it keeps
# working if versions change or new native-asset frameworks are added.
set -eu

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [ ! -d "${FRAMEWORKS_DIR}" ]; then
  echo "fix_native_asset_min_os: no Frameworks dir at ${FRAMEWORKS_DIR}; nothing to do."
  exit 0
fi

for FRAMEWORK in "${FRAMEWORKS_DIR}"/*.framework; do
  [ -d "${FRAMEWORK}" ] || continue

  NAME="$(basename "${FRAMEWORK}" .framework)"
  BINARY="${FRAMEWORK}/${NAME}"
  PLIST="${FRAMEWORK}/Info.plist"

  [ -f "${BINARY}" ] || continue
  [ -f "${PLIST}" ] || continue

  BINARY_MIN_OS="$(xcrun vtool -show-build "${BINARY}" 2>/dev/null | awk '/minos/{print $2; exit}')"
  [ -n "${BINARY_MIN_OS}" ] || continue

  PLIST_MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "${PLIST}" 2>/dev/null || echo '')"

  if [ "${PLIST_MIN_OS}" = "${BINARY_MIN_OS}" ]; then
    continue
  fi

  echo "fix_native_asset_min_os: ${NAME} MinimumOSVersion ${PLIST_MIN_OS:-<none>} -> ${BINARY_MIN_OS}"
  /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion ${BINARY_MIN_OS}" "${PLIST}" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string ${BINARY_MIN_OS}" "${PLIST}"

  # Re-sign the framework so its modified Info.plist is sealed. Skipped for
  # unsigned builds (e.g. `flutter build ios --no-codesign`).
  if [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" "${FRAMEWORK}"
  fi
done
