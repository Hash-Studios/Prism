#!/usr/bin/env bash
# .git/hooks/pre-commit
#
# If any staged Arsenal source files have changed, regenerate the affected
# golden PNGs and stage them so they're included in the commit automatically.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
TEST_DIR="$REPO_ROOT/test/core/arsenal"
GOLDENS_DIR="$TEST_DIR/goldens"

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
  "$TEST_DIR/ar_app_bar_test.dart"
  "$TEST_DIR/ar_bottom_nav_test.dart"
)

# Returns the test file for a given component path, or empty string.
component_test_file() {
  case "$1" in
    lib/core/arsenal/components/ar_scaffold.dart)    echo "$TEST_DIR/ar_scaffold_test.dart" ;;
    lib/core/arsenal/components/ar_button.dart)      echo "$TEST_DIR/ar_button_test.dart" ;;
    lib/core/arsenal/components/ar_progress_steps.dart) echo "$TEST_DIR/ar_progress_steps_test.dart" ;;
    lib/core/arsenal/components/ar_chip.dart)        echo "$TEST_DIR/ar_chip_test.dart" ;;
    lib/core/arsenal/components/ar_avatar.dart)      echo "$TEST_DIR/ar_avatar_test.dart" ;;
    lib/core/arsenal/components/ar_tag.dart)         echo "$TEST_DIR/ar_tag_test.dart" ;;
    lib/core/arsenal/components/ar_bottom_sheet.dart) echo "$TEST_DIR/ar_scaffold_test.dart" ;;
    lib/core/arsenal/components/ar_app_bar.dart)     echo "$TEST_DIR/ar_app_bar_test.dart" ;;
    lib/core/arsenal/components/ar_bottom_nav.dart)  echo "$TEST_DIR/ar_bottom_nav_test.dart" ;;
    *) echo "" ;;
  esac
}

# Only look at staged changes.
staged_files="$(git diff --cached --name-only 2>/dev/null || true)"

if [ -z "$staged_files" ]; then
  exit 0
fi

# Quick early exit if no arsenal files are staged.
if ! echo "$staged_files" | grep -qF "lib/core/arsenal/"; then
  exit 0
fi

echo "Arsenal changes detected — regenerating golden snapshots..."

run_tests_and_stage() {
  fvm flutter test "$@" --update-goldens
  git add "$GOLDENS_DIR"
}

# Token change → rebuild all.
for token in "${TOKEN_FILES[@]}"; do
  if echo "$staged_files" | grep -qF "$token"; then
    echo "Token file changed ($token) — regenerating ALL goldens."
    run_tests_and_stage "${ALL_TEST_FILES[@]}"
    exit 0
  fi
done

# Map component files → test files.
test_files_to_run=()
while IFS= read -r file; do
  test_file="$(component_test_file "$file")"
  if [ -n "$test_file" ]; then
    # Avoid duplicates.
    already=0
    for f in "${test_files_to_run[@]+"${test_files_to_run[@]}"}"; do
      [ "$f" = "$test_file" ] && already=1 && break
    done
    [ "$already" -eq 0 ] && test_files_to_run+=("$test_file")
  fi
done <<< "$staged_files"

if [ ${#test_files_to_run[@]} -eq 0 ]; then
  exit 0
fi

echo "Regenerating goldens for: ${test_files_to_run[*]}"
run_tests_and_stage "${test_files_to_run[@]}"
