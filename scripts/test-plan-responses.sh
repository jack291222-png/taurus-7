#!/bin/sh
# Run on macOS: tests the actual Objective-C payload rewriter using Foundation.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if ! command -v xcrun >/dev/null 2>&1; then
    echo 'Plan response tests require macOS with Xcode Command Line Tools.' >&2
    exit 2
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
xcrun --sdk macosx clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
    -framework Foundation -I"$ROOT/tweak/Sources/Shared/AdBlock" \
    "$ROOT/tests/plan-responses/main.m" \
    "$ROOT/tweak/Sources/Shared/AdBlock/PlanResponses.m" \
    "$ROOT/tweak/Sources/Shared/AdBlock/Protobuf.m" -o "$TMP/plan-tests"
"$TMP/plan-tests"
