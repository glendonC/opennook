#!/usr/bin/env bash
# Print the Keep a Changelog body for a released version (header excluded).
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <version-without-v>" >&2
  exit 2
fi

version="$1"
changelog="${CHANGELOG:-CHANGELOG.md}"

if [[ ! -f "$changelog" ]]; then
  echo "missing $changelog" >&2
  exit 1
fi

awk -v version="$version" '
  $0 ~ "^## \\[" version "\\]" { capture = 1; next }
  capture && $0 ~ "^## \\[" { exit }
  capture { print }
' "$changelog"
