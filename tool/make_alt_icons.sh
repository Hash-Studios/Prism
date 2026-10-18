#!/bin/bash
# Renders the alternate app icons (noir, glass, sunset, mono) from tool/app_icons/<variant>.svg with headless Chrome.
# Writes the iOS alternate icons, the Android adaptive and legacy launcher icons, and the shop previews.
# Set CHROME to a Chrome or Chromium binary if none is found.
set -e

ROOT="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
cd "$ROOT"

VARIANTS="noir glass sunset mono"
# density:legacy launcher px:adaptive layer px (48dp and 108dp)
DENSITIES="mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432"
RES=android/app/src/main/res

find_chrome() {
  local candidate
  for candidate in "$CHROME" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "$(command -v google-chrome || true)" "$(command -v chromium || true)" "$(command -v chromium-browser || true)" \
    "$HOME"/.cache/ms-playwright/chromium-*/chrome-*/chrome \
    "$HOME"/Library/Caches/ms-playwright/chromium-*/chrome-mac*/Chromium.app/Contents/MacOS/Chromium; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done
  echo "make_alt_icons: no Chrome found, set CHROME" >&2
  exit 1
}
CHROME_BIN="$(find_chrome)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

shoot() { # url out size
  "$CHROME_BIN" --headless --no-sandbox --disable-gpu --hide-scrollbars --default-background-color=00000000 \
    --window-size="$3,$3" --screenshot="$2" "$1" >/dev/null 2>&1
  [ -s "$2" ] || { echo "make_alt_icons: render failed for $2" >&2; exit 1; }
}

for variant in $VARIANTS; do
  src="$ROOT/tool/app_icons/$variant.svg"
  name="AppIcon$(echo "${variant:0:1}" | tr '[:lower:]' '[:upper:]')${variant:1}"

  # Android shows the middle 72dp of a 108dp adaptive layer, so widen the view box by half to add bleed.
  sed 's|viewBox="0 0 1024 1024"|viewBox="-256 -256 1536 1536"|' "$src" >"$WORK/$variant-bleed.svg"
  # Pre-API-26 launchers take the icon as drawn: a rounded square with a small margin.
  cat >"$WORK/$variant-legacy.html" <<HTML
<html><body style="margin:0;background:transparent">
<img src="file://$src" style="position:absolute;inset:4%;width:92%;height:92%;border-radius:22%">
</body></html>
HTML

  dir="ios/Runner/Assets.xcassets/$name.appiconset"
  mkdir -p "$dir"
  shoot "file://$src" "$dir/$name.png" 1024
  cat >"$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$name.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

  shoot "file://$src" "assets/app_icons/icon_$variant.png" 512

  for density in $DENSITIES; do
    IFS=: read -r bucket legacy layer <<<"$density"
    mkdir -p "$RES/drawable-$bucket"
    shoot "file://$WORK/$variant-bleed.svg" "$RES/drawable-$bucket/ic_launcher_${variant}_background.png" "$layer"
    shoot "file://$WORK/$variant-legacy.html" "$RES/mipmap-$bucket/ic_launcher_$variant.png" "$legacy"
  done

  cat >"$RES/mipmap-anydpi-v26/ic_launcher_$variant.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@drawable/ic_launcher_${variant}_background"/>
  <foreground android:drawable="@android:color/transparent"/>
</adaptive-icon>
XML
done

echo "make_alt_icons: done"
