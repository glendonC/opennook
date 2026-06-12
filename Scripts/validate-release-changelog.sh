#!/usr/bin/env bash
# Fail if a git tag does not have a non-empty CHANGELOG section.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <tag-or-version>" >&2
  exit 2
fi

raw="$1"
tag="${raw#v}"
changelog="${CHANGELOG:-CHANGELOG.md}"

if [[ ! "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "tag must look like vMAJOR.MINOR.PATCH (got: $raw)" >&2
  exit 1
fi

if [[ ! -f "$changelog" ]]; then
  echo "missing $changelog" >&2
  exit 1
fi

if ! grep -q "^## \\[$tag\\]" "$changelog"; then
  echo "CHANGELOG.md has no section for [$tag]" >&2
  exit 1
fi

body="$(CHANGELOG="$changelog" "$(dirname "$0")/extract-changelog-section.sh" "$tag" | sed '/^[[:space:]]*$/d')"
if [[ -z "$body" ]]; then
  echo "CHANGELOG section [$tag] is empty" >&2
  exit 1
fi

echo "CHANGELOG section [$tag] OK"
