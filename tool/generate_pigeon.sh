#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Generating Pigeon bindings..."

cd "$PROJECT_ROOT"

fvm dart run pigeon \
  --input=pigeons/prism_media_api.dart \
  --dart_out=lib/core/platform/pigeon/prism_media_api.g.dart \
  --java_out=android/app/src/main/java/com/hash/Prism/pigeon/PrismMediaApi.java \
  --java_package=com.hash.prism.pigeon \
  --swift_out=ios/Runner/Pigeon/PrismMediaApi.swift

echo "Pigeon generation complete!"
echo "  - Dart: lib/core/platform/pigeon/prism_media_api.g.dart"
echo "  - Java: android/app/src/main/java/com/hash/Prism/pigeon/PrismMediaApi.java"
echo "  - Swift: ios/Runner/Pigeon/PrismMediaApi.swift"
