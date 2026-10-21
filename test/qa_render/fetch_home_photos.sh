#!/bin/sh
# Downloads the photos the home render test shows: 24 portrait walls (w01..w24), 2 landscape (l01, l02), 1 avatar.
# Safe to rerun: files that exist are skipped. Usage: sh test/qa_render/fetch_home_photos.sh [dir]
# Then render: fvm flutter test test/qa_render/home_render.dart --dart-define=QA_RENDER=1 (PNGs in /tmp/prism-qa/home-renders).
dir="${1:-/tmp/prism-qa/home-photos}"
mkdir -p "$dir"
i=1
for id in 1015 1016 1018 1019 1020 1021 1022 1025 1035 1036 1037 1039 1040 1041 1043 1044 1047 1048 1049 1050 1051 1052 1053 1054; do
  printf 'https://picsum.photos/id/%s/600/1200 w%02d.jpg\n' "$id" "$i"
  i=$((i + 1))
done > "$dir/.list"
printf 'https://picsum.photos/id/1056/1200/720 l01.jpg\nhttps://picsum.photos/id/1057/1200/720 l02.jpg\nhttps://picsum.photos/id/1005/400/400 avatar.jpg\n' >> "$dir/.list"
while read -r url name; do
  [ -s "$dir/$name" ] || curl -sL -m 40 -o "$dir/$name" "$url"
done < "$dir/.list"
ls "$dir" | wc -l
