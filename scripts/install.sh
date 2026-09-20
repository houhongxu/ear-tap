#!/bin/bash
set -euo pipefail
repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
source_app="$repo_dir/build/EarTap.app"
destination="${1:-$HOME/Applications}/EarTap.app"
if [[ ! -x "$source_app/Contents/MacOS/EarTap" ]]; then
  echo 'Run ./scripts/build.sh first.' >&2
  exit 1
fi
if [[ -e "$destination" ]]; then
  identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist")
  [[ "$identifier" == io.github.houhongxu.eartap ]] || { echo 'Destination is not EarTap.' >&2; exit 1; }
fi
"$source_app/Contents/MacOS/EarTap" --stop
mkdir -p "$(dirname -- "$destination")"
staging="$(mktemp -d "$(dirname -- "$destination")/.eartap-install.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$source_app" "$staging/EarTap.app"
codesign --verify --strict "$staging/EarTap.app"
rm -rf "$destination"
mv "$staging/EarTap.app" "$destination"
printf 'Installed: %s\nOpen this app and use its menu to check Accessibility permission.\n' "$destination"
