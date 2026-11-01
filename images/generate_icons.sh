#!/usr/bin/env bash
# Regenerates every platform icon from images/app.svg.
set -euo pipefail
cd "$(dirname "$0")/.."

render() { rsvg-convert -w "$2" -h "$2" "$1" -o "$3"; }

render images/app.svg 512 images/app.png
render images/tray.svg 64 images/tray.png
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for size in 16 24 32 48 64 128 256; do render images/app.svg "$size" "$work/$size.png"; done
magick "$work"/{16,24,32,48,64,128,256}.png images/app.ico
[ -f windows/runner/resources/app_icon.ico ] && cp images/app.ico windows/runner/resources/app_icon.ico

# Existing icons of Apple platforms keep their size. They must be opaque squares.
for file in ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png \
  macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png; do
  size="$(magick identify -format '%w' "$file")"
  render images/app.svg "$size" "$work/apple.png"
  magick "$work/apple.png" -background '#2F6BDD' -alpha remove -alpha off "$file"
done

res=android/app/src/main/res
# Launchers mask adaptive icons, so the mark needs its 108dp canvas without the tile.
sed -e 's#<g id="tile">.*</g>##' -e 's#viewBox="0 0 1024 1024"#viewBox="-128 -128 1280 1280"#' \
  images/app.svg > "$work/foreground.svg"
for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density="${pair%%:*}"
  size="${pair##*:}"
  render images/app.svg "$size" "$res/mipmap-$density/ic_launcher.png"
  render "$work/foreground.svg" "$((size * 108 / 48))" "$res/mipmap-$density/ic_launcher_foreground.png"
done
