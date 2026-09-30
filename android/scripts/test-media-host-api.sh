#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_PATH="${1:-$ROOT/android/app/src/main/kotlin/com/hash/prism/PrismMediaHostApiImpl.kt}"
SOURCE_REV=""
if [[ "${1:-}" == "--git" ]]; then
  SOURCE_REV="${2:?usage: test-media-host-api.sh [source.kt | --git <revision>]}"
fi
GRADLE_CACHE="${GRADLE_USER_HOME:-$HOME/.gradle-prism}/caches/modules-2/files-2.1"
KOTLIN_VERSION=2.3.0

jar_for() {
  find "$1" -type f -name "$2" -print -quit 2>/dev/null || true
}

COMPILER="$(jar_for "$GRADLE_CACHE/org.jetbrains.kotlin/kotlin-compiler-embeddable/$KOTLIN_VERSION" 'kotlin-compiler-embeddable-*.jar')"
STDLIB="$(jar_for "$GRADLE_CACHE/org.jetbrains.kotlin/kotlin-stdlib/$KOTLIN_VERSION" 'kotlin-stdlib-*.jar')"
SCRIPT_RUNTIME="$(jar_for "$GRADLE_CACHE/org.jetbrains.kotlin/kotlin-script-runtime/$KOTLIN_VERSION" 'kotlin-script-runtime-*.jar')"
REFLECT="$(jar_for "$GRADLE_CACHE/org.jetbrains.kotlin/kotlin-reflect" 'kotlin-reflect-*.jar')"
TROVE="$(jar_for "$GRADLE_CACHE/org.jetbrains.intellij.deps/trove4j" 'trove4j-*.jar')"
ANNOTATIONS="$(jar_for "$GRADLE_CACHE/org.jetbrains/annotations" 'annotations-*.jar')"
COROUTINES="$(jar_for "$GRADLE_CACHE/org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm" 'kotlinx-coroutines-core-jvm-*.jar')"

for required in "$COMPILER" "$STDLIB" "$SCRIPT_RUNTIME" "$REFLECT" "$TROVE" "$ANNOTATIONS" "$COROUTINES"; do
  if [[ -z "$required" ]]; then
    echo "Missing cached Kotlin $KOTLIN_VERSION compiler dependency; run the app build first." >&2
    exit 2
  fi
done
if [[ -z "$SOURCE_REV" && ! -f "$SOURCE_PATH" ]]; then
  echo "Media source not found: $SOURCE_PATH" >&2
  exit 2
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/classes"
if [[ -n "$SOURCE_REV" ]]; then
  SOURCE_PATH="$TMP_DIR/PrismMediaHostApiImpl.kt"
  git -C "$ROOT" show "$SOURCE_REV:android/app/src/main/kotlin/com/hash/prism/PrismMediaHostApiImpl.kt" > "$SOURCE_PATH"
fi
COMPILER_CP="$COMPILER:$STDLIB:$SCRIPT_RUNTIME:$REFLECT:$TROVE:$ANNOTATIONS:$COROUTINES"
HARNESS_CP="$STDLIB:$ANNOTATIONS"
STUBS=()
while IFS= read -r -d '' stub; do STUBS+=("$stub"); done \
  < <(find "$ROOT/android/scripts/media-harness/stubs" -type f -name '*.kt' -print0)

java -cp "$COMPILER_CP" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler \
  -no-stdlib -no-reflect -classpath "$HARNESS_CP" -jvm-target 17 -d "$TMP_DIR/classes" \
  "$SOURCE_PATH" "$ROOT/android/scripts/media-harness/MediaHarnessTest.kt" "${STUBS[@]}"
java -cp "$TMP_DIR/classes:$STDLIB:$ANNOTATIONS" com.hash.prism.MediaHarnessTestKt
