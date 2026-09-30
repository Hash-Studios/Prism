#!/usr/bin/env bash
# Writes a stub lib/firebase_options.dart for CI and size builds that run with
# --dart-define=SKIP_FIREBASE_INIT=true. Keeps a real file if one exists.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

target=lib/firebase_options.dart
if [[ -f "$target" ]] && ! grep -q "CI stub" "$target"; then
  echo "$target is not a stub; keeping it."
  exit 0
fi

cat >"$target" <<'EOF'
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError('CI stub');
}
EOF
