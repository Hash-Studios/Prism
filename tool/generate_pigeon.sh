#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Generating Pigeon bindings..."

cd "$PROJECT_ROOT"

fvm dart run pigeon \
  --input=pigeons/prism_media_api.dart \
  --dart_out=lib/core/platform/pigeon/prism_media_api.g.dart \
  --kotlin_out=android/app/src/main/kotlin/com/hash/prism/pigeon/PrismMediaApi.kt \
  --kotlin_package=com.hash.prism.pigeon \
  --swift_out=ios/Runner/Pigeon/PrismMediaApi.swift

fvm dart run pigeon \
  --input=pigeons/prism_app_icon_api.dart \
  --dart_out=lib/core/platform/pigeon/prism_app_icon_api.g.dart \
  --kotlin_out=android/app/src/main/kotlin/com/hash/prism/pigeon/PrismAppIconApi.kt \
  --kotlin_package=com.hash.prism.pigeon \
  --swift_out=ios/Runner/Pigeon/PrismAppIconApi.swift

fvm dart format --line-length=120 lib/core/platform/pigeon/prism_media_api.g.dart lib/core/platform/pigeon/prism_app_icon_api.g.dart

echo "Pigeon generation complete!"
echo "  - Dart: lib/core/platform/pigeon/prism_media_api.g.dart"
echo "  - Kotlin: android/app/src/main/kotlin/com/hash/prism/pigeon/PrismMediaApi.kt"
echo "  - Swift: ios/Runner/Pigeon/PrismMediaApi.swift"
echo "  - App icon: lib/core/platform/pigeon/prism_app_icon_api.g.dart (+ Kotlin, Swift)"
