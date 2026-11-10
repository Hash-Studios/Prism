#!/usr/bin/env bash
# Exports an App Store IPA from an archive built with --no-codesign, keeping each target's entitlements.
#
# xcodebuild -exportArchive takes entitlements from the archived signatures. An unsigned archive has none, so the
# exported app loses push, Sign in with Apple, universal links and the App Group (iOS builds 360 to 369 shipped like
# that). This script ad-hoc signs every bundle with its ios/<Target>/<Target>.entitlements first, exports with the
# App Store Connect API key, and then refuses an IPA where a bundle is missing or lacks a source entitlement.
#
# Usage: tool/ios_export_ipa.sh <archive> <export-dir> <ExportOptions.plist>
# Env:   ASC_KEY_ID (default B3QRNA5QHB), ASC_KEY_PATH (default ~/.asc/keys/AuthKey_<id>.p8), ASC_ISSUER_ID
#        (default: asc --profile prism auth issuer-id).
# Self-check of the entitlement comparison: tool/ios_export_ipa.sh --self-test
set -euo pipefail
shopt -s nullglob

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Exit 1 when the signed entitlements (argv[2]) do not cover the source ones (argv[1]).
# A list must be a subset. aps-environment must be "production", because the IPA goes to App Store Connect.
# Any other value must match exactly.
compare_py='
import plistlib, sys
want = plistlib.load(open(sys.argv[1], "rb"))
got = plistlib.load(open(sys.argv[2], "rb"))
bad = []
for key, value in want.items():
    have = got.get(key)
    if key == "aps-environment":
        ok = have == "production"
    elif isinstance(value, list):
        ok = isinstance(have, list) and set(value) <= set(have)
    else:
        ok = have == value
    if not ok:
        bad.append(f"{key} (want {value!r}, got {have!r})")
if bad:
    print(f"error: {sys.argv[3]} entitlements are wrong: " + "; ".join(bad) + ". Check its App ID and profile.",
          file=sys.stderr)
    sys.exit(1)
print(f"{sys.argv[3]}: entitlements OK ({", ".join(sorted(want))})")
'

if [ "${1:-}" = "--self-test" ]; then
  T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
  plist() { python3 -c 'import plistlib,sys,json; plistlib.dump(json.loads(sys.argv[2]), open(sys.argv[1],"wb"))' "$@"; }
  plist "$T/src" '{"aps-environment":"development","com.apple.security.application-groups":["group.a"],"com.apple.developer.applesignin":["Default"]}'
  expect() { # want-exit json label
    plist "$T/got" "$2"
    local rc=0; python3 -c "$compare_py" "$T/src" "$T/got" "$3" >/dev/null 2>&1 || rc=$?
    [ "$rc" = "$1" ] || { echo "self-test FAIL: $3 (exit $rc, want $1)"; exit 1; }
  }
  expect 0 '{"aps-environment":"production","com.apple.security.application-groups":["group.a","group.b"],"com.apple.developer.applesignin":["Default"]}' good
  expect 1 '{"com.apple.security.application-groups":["group.a"],"com.apple.developer.applesignin":["Default"]}' no-push
  expect 1 '{"aps-environment":"development","com.apple.security.application-groups":["group.a"],"com.apple.developer.applesignin":["Default"]}' dev-push
  expect 1 '{"aps-environment":"production","com.apple.security.application-groups":[],"com.apple.developer.applesignin":["Default"]}' empty-group
  expect 1 '{"aps-environment":"production","com.apple.security.application-groups":"group.a","com.apple.developer.applesignin":["Default"]}' string-not-list
  echo "self-test OK"
  exit 0
fi

ARCHIVE="${1:?archive path}"
OUT="${2:?export dir}"
OPTIONS="${3:?ExportOptions.plist}"
KEY_ID="${ASC_KEY_ID:-B3QRNA5QHB}"
KEY_PATH="${ASC_KEY_PATH:-$HOME/.asc/keys/AuthKey_${KEY_ID}.p8}"
ISSUER="${ASC_ISSUER_ID:-$(asc --profile prism auth issuer-id | tr -d '[:space:]')}"
APP="$ARCHIVE/Products/Applications/Runner.app"
[ -d "$APP" ] || { echo "error: no Runner.app in $ARCHIVE" >&2; exit 1; }
[ -n "$ISSUER" ] || { echo "error: no App Store Connect issuer id" >&2; exit 1; }

entitlements_for() { # bundle path -> source entitlements file, or empty
  local name; name="$(basename "$1")"; name="${name%.*}"
  local file="$ROOT/ios/$name/$name.entitlements"
  if [ -f "$file" ]; then echo "$file"; fi
}

sign() { # bundle [entitlements]
  if [ -n "${2:-}" ]; then codesign -f -s - --entitlements "$2" "$1"; else codesign -f -s - "$1"; fi
}

# Inner code first (find -depth lists children before parents): the outer signature records the nested ones.
NESTED="$(mktemp)"
trap 'rm -f "$NESTED"' EXIT
find "$APP" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0 > "$NESTED"
while IFS= read -r -d '' code; do sign "$code"; done < "$NESTED"
appexes=("$APP"/PlugIns/*.appex)
for appex in "${appexes[@]}"; do sign "$appex" "$(entitlements_for "$appex")"; done
sign "$APP" "$(entitlements_for "$APP")"

rm -rf "$OUT"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT" -exportOptionsPlist "$OPTIONS" \
  -allowProvisioningUpdates -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" -quiet

ipas=("$OUT"/*.ipa)
[ "${#ipas[@]}" -eq 1 ] || { echo "error: expected one .ipa in $OUT, found ${#ipas[@]}" >&2; exit 1; }
CHECK="$(mktemp -d)"
trap 'rm -f "$NESTED"; rm -rf "$CHECK"' EXIT
unzip -q "${ipas[0]}" -d "$CHECK"
status=0
# Walk the archive's bundles, so an extension the export dropped fails too.
for bundle in "$APP" "${appexes[@]}"; do
  source_file="$(entitlements_for "$bundle")"
  [ -n "$source_file" ] || continue
  exported="$CHECK/Payload/Runner.app${bundle#"$APP"}"
  if [ ! -d "$exported" ]; then
    echo "error: $(basename "$bundle") is missing from the IPA" >&2; status=1; continue
  fi
  codesign -d --entitlements :- "$exported" 2>/dev/null > "$CHECK/signed.plist" || true
  python3 -c "$compare_py" "$source_file" "$CHECK/signed.plist" "$(basename "$bundle")" || status=1
done
[ "$status" -eq 0 ] || exit 1
echo "Exported ${ipas[0]}"
