#!/usr/bin/env bash
# Builds the APK that the app_size CI job measures into <out-dir>/app-<mode>.apk,
# with the build log beside it. Run it from the repo root.
#
#   tool/build_size_apk.sh <out-dir>
#   tool/build_size_apk.sh --key <commit>   # prints the cache key of that commit's APK inputs
#
# It deletes build/app/outputs first. When a second APK builds in the same
# workspace, Gradle patches the old APK in place and leaves the replaced
# libapp.so as dead bytes, so the file grows by ~16 MiB with no content change.
# With the outputs gone, Gradle packages the APK from scratch.

set -euo pipefail

if [ "$1" = --key ]; then
  git ls-tree "$2" -- lib android assets shaders packages pubspec.yaml pubspec.lock .fvmrc \
    tool/build_size_apk.sh tool/write_firebase_options_stub.sh | git hash-object --stdin
  exit 0
fi

out_dir=$1
mode=${APP_SIZE_BUILD_MODE:-profile}
platform=${APP_SIZE_TARGET_PLATFORM:-android-arm64}

rm -rf build/app/outputs
flutter pub get
tool/write_firebase_options_stub.sh
mkdir -p "$out_dir"
flutter build apk --"$mode" --target-platform="$platform" --dart-define=SKIP_FIREBASE_INIT=true 2>&1 |
  tee "$out_dir/build.log"
cp "build/app/outputs/flutter-apk/app-$mode.apk" "$out_dir/"
