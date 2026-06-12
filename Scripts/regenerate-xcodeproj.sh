#!/usr/bin/env bash
# regenerate-xcodeproj.sh
# Rebuilds Nook.xcodeproj from project.yml (the source of truth).
#
# The .xcodeproj is gitignored - it's a generated artifact. Run this script
# after editing project.yml, or after a fresh clone before opening the
# project in Xcode for the first time.
#
# Requires xcodegen (`brew install xcodegen`).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen not installed. Install with:" >&2
    echo "       brew install xcodegen" >&2
    exit 1
fi

rm -rf Nook.xcodeproj
xcodegen generate
echo "Regenerated Nook.xcodeproj from project.yml"
