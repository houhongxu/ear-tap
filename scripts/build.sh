#!/bin/bash
set -euo pipefail
repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
output_dir="${1:-$repo_dir/build}"
mkdir -p "$output_dir"
output_dir="$(CDPATH= cd -- "$output_dir" && pwd)"
app="$output_dir/EarTap.app"
if [[ -x "$app/Contents/MacOS/EarTap" ]]; then
  "$app/Contents/MacOS/EarTap" --stop
fi
staging="$(mktemp -d "$output_dir/.eartap-build.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/EarTap.app/Contents/MacOS" "$staging/EarTap.app/Contents/Resources"
cp "$repo_dir/resources/Info.plist" "$staging/EarTap.app/Contents/Info.plist"
cp "$repo_dir/resources/shortcut.json" "$staging/EarTap.app/Contents/Resources/shortcut.json"
iconset="$staging/EarTap.iconset"
mkdir -p "$iconset"
make_icon() { sips -z "$1" "$1" "$repo_dir/resources/EarTapIcon.png" --out "$iconset/$2" >/dev/null; }
make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png
iconutil -c icns "$iconset" -o "$staging/EarTap.app/Contents/Resources/EarTap.icns"
rm -rf "$iconset"
xcrun clang -fobjc-arc -Wall -Wextra -Werror -O2 -mmacosx-version-min=13.0   "$repo_dir"/src/*.m -framework Cocoa -framework ApplicationServices -framework Carbon -framework MediaPlayer   -o "$staging/EarTap.app/Contents/MacOS/EarTap"
codesign --force --sign - --identifier io.github.houhongxu.eartap "$staging/EarTap.app"
codesign --verify --strict "$staging/EarTap.app"
# Replace only our named build artifact after compilation succeeds.
rm -rf "$app"
mv "$staging/EarTap.app" "$app"
printf 'Built: %s\n' "$app"
