#!/usr/bin/env bash
# Exports an App Store IPA from an archive built with --no-codesign, keeping each target's entitlements.
#
# xcodebuild -exportArchive takes entitlements from the archived signatures. An unsigned archive has none, so the
# exported app loses push, Sign in with Apple, universal links and the App Group (3.2x iOS builds shipped like that).
# This script ad-hoc signs every bundle with its ios/<Target>/<Target>.entitlements first, exports with the
# App Store Connect API key, and then refuses an IPA where a bundle lacks an entitlement from its source file.
#
# Usage: tool/ios_export_ipa.sh <archive> <export-dir> <ExportOptions.plist>
# Env:   ASC_KEY_ID (default B3QRNA5QHB), ASC_KEY_PATH (default ~/.asc/keys/AuthKey_<id>.p8), ASC_ISSUER_ID
#        (default: asc --profile prism auth issuer-id).
set -euo pipefail

ARCHIVE="${1:?archive path}"
OUT="${2:?export dir}"
OPTIONS="${3:?ExportOptions.plist}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY_ID="${ASC_KEY_ID:-B3QRNA5QHB}"
KEY_PATH="${ASC_KEY_PATH:-$HOME/.asc/keys/AuthKey_${KEY_ID}.p8}"
ISSUER="${ASC_ISSUER_ID:-$(asc --profile prism auth issuer-id | tr -d '[:space:]')}"
APP="$ARCHIVE/Products/Applications/Runner.app"
[ -d "$APP" ] || { echo "error: no Runner.app in $ARCHIVE" >&2; exit 1; }

entitlements_for() { # bundle path -> source entitlements file, or empty
  local name; name="$(basename "$1")"; name="${name%.*}"
  local file="$ROOT/ios/$name/$name.entitlements"
  [ -f "$file" ] && echo "$file" || true
}

sign() { # bundle [entitlements]
  if [ -n "${2:-}" ]; then codesign -f -s - --entitlements "$2" "$1"; else codesign -f -s - "$1"; fi
}

# Inner code first: the outer signature records the nested ones.
while IFS= read -r -d '' code; do sign "$code"; done \
  < <(find "$APP" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0)
for appex in "$APP"/PlugIns/*.appex; do sign "$appex" "$(entitlements_for "$appex")"; done
sign "$APP" "$(entitlements_for "$APP")"

rm -rf "$OUT"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT" -exportOptionsPlist "$OPTIONS" \
  -allowProvisioningUpdates -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" -quiet

IPA="$(ls "$OUT"/*.ipa)"
CHECK="$(mktemp -d)"
trap 'rm -rf "$CHECK"' EXIT
unzip -q "$IPA" -d "$CHECK"
status=0
for bundle in "$CHECK"/Payload/Runner.app "$CHECK"/Payload/Runner.app/PlugIns/*.appex; do
  source_file="$(entitlements_for "$bundle")"
  [ -n "$source_file" ] || continue
  codesign -d --entitlements :- "$bundle" 2>/dev/null > "$CHECK/signed.plist"
  if ! python3 - "$source_file" "$CHECK/signed.plist" "$(basename "$bundle")" <<'EOF'
import plistlib, sys
want = plistlib.load(open(sys.argv[1], "rb"))
got = plistlib.load(open(sys.argv[2], "rb"))
missing = [k for k in want if k not in got or (isinstance(want[k], list) and not set(want[k]) <= set(got[k]))]
if missing:
    print(f"error: {sys.argv[3]} is missing entitlements {missing}. Check its App ID and profile.", file=sys.stderr)
    sys.exit(1)
print(f"{sys.argv[3]}: entitlements OK ({', '.join(sorted(want))})")
EOF
  then status=1; fi
done
[ "$status" -eq 0 ] || exit 1
echo "Exported $IPA"
