#!/bin/bash
set -euo pipefail
repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/eartap-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -Wall -Wextra -Werror -O0 -g -mmacosx-version-min=13.0   "$repo_dir/tests/Tests.m" "$repo_dir/src/Shortcut.m"   -framework Cocoa -framework ApplicationServices -framework Carbon -framework MediaPlayer   -o "$test_dir/tests"
"$test_dir/tests" "$repo_dir/resources/shortcut.json" "$test_dir"
