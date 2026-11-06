#!/bin/bash
# Uploads iOS dSYM + Flutter symbols to Firebase Crashlytics after each device build.
set +e

if [ "${PLATFORM_NAME}" != "iphoneos" ]; then
  exit 0
fi

PATH="${PATH}:${FLUTTER_ROOT}/bin:${PUB_CACHE}/bin:${HOME}/.pub-cache/bin"
PROJECT_ROOT="${PROJECT_DIR}/.."
FIREBASE_JSON_PATH="${PROJECT_ROOT}/firebase.json"
GSP_PATH="${PROJECT_DIR}/Runner/GoogleService-Info.plist"
UPLOAD_SYMBOLS="${PODS_ROOT}/FirebaseCrashlytics/upload-symbols"

if [ -z "$PODS_ROOT" ] || [ ! -d "$PODS_ROOT/FirebaseCrashlytics" ]; then
  DERIVED_DATA_PATH=$(echo "$BUILD_ROOT" | sed -E 's|(.*DerivedData/[^/]+).*|\1|')
  CRASHLYTICS_RUN="${DERIVED_DATA_PATH}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
else
  CRASHLYTICS_RUN="${PODS_ROOT}/FirebaseCrashlytics/run"
fi

upload_via_flutterfire() {
  if [ ! -f "$FIREBASE_JSON_PATH" ]; then
    echo "warning: firebase.json not found; skipping flutterfire symbol upload."
    return 1
  fi

  local cmd=(upload-crashlytics-symbols
    --upload-symbols-script-path="${CRASHLYTICS_RUN}"
    --platform=ios
    --apple-project-path="${SRCROOT}"
    --env-platform-name="${PLATFORM_NAME}"
    --env-configuration="${CONFIGURATION}"
    --env-project-dir="${PROJECT_DIR}"
    --env-built-products-dir="${BUILT_PRODUCTS_DIR}"
    --env-dwarf-dsym-folder-path="${DWARF_DSYM_FOLDER_PATH}"
    --env-dwarf-dsym-file-name="${DWARF_DSYM_FILE_NAME}"
    --env-infoplist-path="${INFOPLIST_PATH}"
    --default-config=default)

  if command -v flutterfire >/dev/null 2>&1; then
    flutterfire "${cmd[@]}"
    return $?
  fi

  if [ -f "${PROJECT_ROOT}/pubspec.yaml" ]; then
    (cd "${PROJECT_ROOT}" && dart run flutterfire_cli:flutterfire "${cmd[@]}")
    return $?
  fi

  echo "warning: flutterfire CLI not found."
  return 1
}

upload_via_pods() {
  if [ ! -x "$UPLOAD_SYMBOLS" ]; then
    echo "warning: FirebaseCrashlytics/upload-symbols not found."
    return 1
  fi
  if [ ! -f "$GSP_PATH" ]; then
    echo "warning: GoogleService-Info.plist not found."
    return 1
  fi
  if [ ! -d "${DWARF_DSYM_FOLDER_PATH}" ]; then
    echo "warning: dSYM folder not found at ${DWARF_DSYM_FOLDER_PATH}."
    return 1
  fi

  "$UPLOAD_SYMBOLS" -gsp "$GSP_PATH" -p ios "${DWARF_DSYM_FOLDER_PATH}"
  return $?
}

if upload_via_flutterfire; then
  echo "Crashlytics symbols uploaded via flutterfire."
  exit 0
fi

if upload_via_pods; then
  echo "Crashlytics symbols uploaded via FirebaseCrashlytics/upload-symbols."
  exit 0
fi

echo "warning: Crashlytics symbol upload did not run successfully."
exit 0
