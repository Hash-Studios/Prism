#!/bin/bash
# Builds the four alternate app icons (noir, glass, sunset, mono) from the launcher icon.
# Uses ImageMagick when `convert` exists, else Pillow ($PYTHON, default python3), else copies the original.
set -e

ROOT="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
cd "$ROOT"

PYTHON="${PYTHON:-python3}"
IOS_FOREGROUND=ios/Runner/AppIcon.icon/Assets/ic_foreground.png
RES=android/app/src/main/res
VARIANTS="noir glass sunset mono"
DENSITIES="mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192"

# iOS wants a flat 1024 square: the Icon Composer foreground at 115% on its black fill.
BASE="$(mktemp -d)/base.png"

write_contents() {
  local dir="$1" name="$2"
  mkdir -p "$dir"
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
}

if command -v convert >/dev/null 2>&1; then
  MODE=magick
elif "$PYTHON" -c 'import PIL' >/dev/null 2>&1; then
  MODE=pillow
else
  MODE=copy
fi
echo "make_alt_icons: mode=$MODE"

magick_variant() { # variant in out
  case "$1" in
    noir) convert "$2" -colorspace Gray -modulate 70 "$3" ;;
    glass) convert "$2" -modulate 125,85 -blur 0x1 "$3" ;;
    sunset) convert "$2" -fill '#ff8a3d' -colorize 35% "$3" ;;
    mono) convert "$2" -colorspace Gray -threshold 25% "$3" ;;
  esac
}

pillow_variant() { # variant in out
  "$PYTHON" - "$1" "$2" "$3" <<'PY'
import sys
from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps

variant, src, dst = sys.argv[1:4]
image = Image.open(src).convert("RGBA")
alpha = image.getchannel("A")
rgb = image.convert("RGB")
if variant == "noir":
    rgb = ImageEnhance.Brightness(ImageOps.grayscale(rgb).convert("RGB")).enhance(0.7)
elif variant == "glass":
    soft = rgb.filter(ImageFilter.GaussianBlur(max(1, image.width // 512 + 1)))
    rgb = Image.blend(ImageEnhance.Brightness(Image.blend(rgb, soft, 0.5)).enhance(1.25), Image.new("RGB", rgb.size, "white"), 0.12)
elif variant == "sunset":
    rgb = Image.blend(rgb, Image.new("RGB", rgb.size, "#ff8a3d"), 0.35)
else:
    rgb = ImageOps.grayscale(rgb).point(lambda v: 255 if v > 64 else 0).convert("RGB")
if alpha.getextrema() == (255, 255):
    rgb.save(dst)
else:
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    out.save(dst)
PY
}

make_variant() { # variant in out
  case "$MODE" in
    magick) magick_variant "$1" "$2" "$3" ;;
    pillow) pillow_variant "$1" "$2" "$3" ;;
    copy) cp "$2" "$3" ;;
  esac
}

if [ "$MODE" = magick ]; then
  convert -size 1024x1024 xc:black \( "$IOS_FOREGROUND" -resize 115% -gravity center -crop 1024x1024+0+0 +repage \) \
    -gravity center -composite -alpha off "$BASE"
elif [ "$MODE" = pillow ]; then
  "$PYTHON" - "$IOS_FOREGROUND" "$BASE" <<'PY'
import sys
from PIL import Image

fg = Image.open(sys.argv[1]).convert("RGBA")
scaled = fg.resize((round(fg.width * 1.15), round(fg.height * 1.15)), Image.LANCZOS)
canvas = Image.new("RGBA", fg.size, "black")
canvas.alpha_composite(scaled, ((fg.width - scaled.width) // 2, (fg.height - scaled.height) // 2))
canvas.convert("RGB").save(sys.argv[2])
PY
else
  cp "$IOS_FOREGROUND" "$BASE"
fi

for variant in $VARIANTS; do
  name="AppIcon$(echo "${variant:0:1}" | tr '[:lower:]' '[:upper:]')${variant:1}"
  dir="ios/Runner/Assets.xcassets/$name.appiconset"
  write_contents "$dir" "$name"
  make_variant "$variant" "$BASE" "$dir/$name.png"
  for density in $DENSITIES; do
    bucket="${density%%:*}"
    size="${density##*:}"
    out="$RES/mipmap-$bucket/ic_launcher_$variant.png"
    if [ "$MODE" = magick ]; then
      convert "$RES/mipmap-$bucket/ic_launcher.png" -resize "${size}x${size}" "$RES/mipmap-$bucket/.tmp_$variant.png"
      make_variant "$variant" "$RES/mipmap-$bucket/.tmp_$variant.png" "$out"
      rm "$RES/mipmap-$bucket/.tmp_$variant.png"
    else
      make_variant "$variant" "$RES/mipmap-$bucket/ic_launcher.png" "$out"
    fi
  done
done

echo "make_alt_icons: done"
