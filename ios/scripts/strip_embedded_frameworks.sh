#!/bin/bash
set -euo pipefail

# Xcode's stripSwiftSymbols export option only strips the Swift runtime.
# Remove local symbols from embedded SDKs, not their cached build products.
if [[ "${CONFIGURATION:-}" != Release || "${PLATFORM_NAME:-}" != iphoneos ]]; then
  echo 'Skip SDK symbol stripping outside Release/iphoneos.'
  exit 0
fi

: "${TARGET_BUILD_DIR:?}" "${WRAPPER_NAME:?}" "${FRAMEWORKS_FOLDER_PATH:?}"
if [[ "$WRAPPER_NAME" != *.app || "$WRAPPER_NAME" == */* ||
      "$FRAMEWORKS_FOLDER_PATH" != "$WRAPPER_NAME/Frameworks" ]]; then
  echo 'error: SDK symbol stripping requires the embedded app Frameworks directory.' >&2
  exit 1
fi

frameworks="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [[ -L "${TARGET_BUILD_DIR}/${WRAPPER_NAME}" || -L "$frameworks" ]]; then
  echo 'error: Refusing to strip a symlinked app or Frameworks directory.' >&2
  exit 1
fi
[[ -d "$frameworks" ]] || exit 0

if [[ "${CODE_SIGNING_ALLOWED:-}" != NO && "${CODE_SIGNING_REQUIRED:-}" != NO &&
      -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
  echo 'error: A signing identity is required to re-sign stripped SDK frameworks.' >&2
  exit 1
fi

for framework in "$frameworks"/*.framework; do
  [[ -d "$framework" ]] || continue
  name="$(basename "$framework" .framework)"
  case "$name" in App|Flutter) continue ;; esac
  binary="$framework/$name"
  if [[ -L "$framework" || -L "$binary" || ! -f "$binary" ]]; then
    echo "error: Expected an embedded, non-symlink SDK binary: $binary" >&2
    exit 1
  fi

  # strip can return success for a non-Mach-O input. Reject it first.
  xcrun lipo -archs "$binary" >/dev/null
  before="$(stat -f%z "$binary")"
  xcrun strip -x "$binary"
  # CocoaPods signs before this phase. Restore each modified nested signature
  # before Xcode signs the outer app, using the same signing gates as CocoaPods.
  if [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" &&
        "${CODE_SIGNING_REQUIRED:-}" != NO && "${CODE_SIGNING_ALLOWED:-}" != NO ]]; then
    read -r -a signing_flags <<< "${OTHER_CODE_SIGN_FLAGS:-}"
    /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
      ${signing_flags[@]+"${signing_flags[@]}"} \
      --preserve-metadata=identifier,entitlements "$framework"
    /usr/bin/codesign --verify --strict "$framework"
  fi
  echo "Stripped $name: $before -> $(stat -f%z "$binary") bytes"
done
