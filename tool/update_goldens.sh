#!/usr/bin/env bash
# update_goldens.sh — Regenerate Arsenal golden PNGs only for changed components.
#
# Logic:
#   1. Get all modified files (staged + unstaged vs HEAD).
#   2. Map each changed component file → its test file.
#   3. If a token file (colors/spacing/typography/theme) changed → run ALL tests.
#   4. Run `fvm flutter test <matched_test_files> --update-goldens`.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
TEST_DIR="$REPO_ROOT/test/core/arsenal"
TOKEN_FILES=(
  "lib/core/arsenal/colors.dart"
  "lib/core/arsenal/spacing.dart"
  "lib/core/arsenal/typography.dart"
  "lib/core/arsenal/theme.dart"
)
ALL_TEST_FILES=(
  "$TEST_DIR/ar_scaffold_test.dart"
  "$TEST_DIR/ar_button_test.dart"
  "$TEST_DIR/ar_progress_steps_test.dart"
  "$TEST_DIR/ar_chip_test.dart"
  "$TEST_DIR/ar_avatar_test.dart"
  "$TEST_DIR/ar_tag_test.dart"
)

# Returns the test file for a given component path, or empty string.
component_test_file() {
  case "$1" in
    lib/core/arsenal/components/ar_scaffold.dart)       echo "$TEST_DIR/ar_scaffold_test.dart" ;;
    lib/core/arsenal/components/ar_button.dart)         echo "$TEST_DIR/ar_button_test.dart" ;;
    lib/core/arsenal/components/ar_progress_steps.dart) echo "$TEST_DIR/ar_progress_steps_test.dart" ;;
    lib/core/arsenal/components/ar_chip.dart)           echo "$TEST_DIR/ar_chip_test.dart" ;;
    lib/core/arsenal/components/ar_avatar.dart)         echo "$TEST_DIR/ar_avatar_test.dart" ;;
    lib/core/arsenal/components/ar_tag.dart)            echo "$TEST_DIR/ar_tag_test.dart" ;;
    lib/core/arsenal/components/ar_bottom_sheet.dart)   echo "$TEST_DIR/ar_scaffold_test.dart" ;;
    *) echo "" ;;
  esac
}

# Collect modified files (staged + unstaged).
changed_files="$(git diff --name-only HEAD 2>/dev/null || true)"

if [ -z "$changed_files" ]; then
  echo "No Arsenal changes detected. Nothing to update."
  exit 0
fi

# Check if any token file changed → rebuild all.
for token in "${TOKEN_FILES[@]}"; do
  if echo "$changed_files" | grep -qF "$token"; then
    echo "Token file changed ($token) — regenerating ALL Arsenal goldens."
    fvm flutter test "${ALL_TEST_FILES[@]}" --update-goldens
    exit 0
  fi
done

# Map component files → test files.
test_files_to_run=()
while IFS= read -r file; do
  test_file="$(component_test_file "$file")"
  if [ -n "$test_file" ]; then
    already=0
    for f in "${test_files_to_run[@]+"${test_files_to_run[@]}"}"; do
      [ "$f" = "$test_file" ] && already=1 && break
    done
    [ "$already" -eq 0 ] && test_files_to_run+=("$test_file")
  fi
done <<< "$changed_files"

if [ ${#test_files_to_run[@]} -eq 0 ]; then
  echo "No Arsenal changes detected. Nothing to update."
  exit 0
fi

echo "Regenerating goldens for: ${test_files_to_run[*]}"
fvm flutter test "${test_files_to_run[@]}" --update-goldens
