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
xcrun clang -fobjc-arc -Wall -Wextra -Werror -O2 -mmacosx-version-min=13.0   "$repo_dir"/src/*.m -framework Cocoa -framework ApplicationServices -framework Carbon -framework MediaPlayer   -o "$staging/EarTap.app/Contents/MacOS/EarTap"
codesign --force --sign - --identifier io.github.houhongxu.eartap "$staging/EarTap.app"
codesign --verify --strict "$staging/EarTap.app"
# Replace only our named build artifact after compilation succeeds.
rm -rf "$app"
mv "$staging/EarTap.app" "$app"
printf 'Built: %s\n' "$app"
