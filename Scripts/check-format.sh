#!/usr/bin/env bash
# Lint Swift formatting on changed files only (not a whole-repo reformat).
# Uses the repo .swift-format config and `swift format lint --strict`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/.swift-format"

if [ ! -f "$CONFIG" ]; then
  echo "::error::missing $CONFIG"
  exit 1
fi

# Resolve the merge base for "what changed in this PR/push".
base_ref() {
  if [ -n "${BASE_REF:-}" ]; then
    echo "$BASE_REF"
    return
  fi
  if [ -n "${GITHUB_BASE_REF:-}" ]; then
    echo "origin/${GITHUB_BASE_REF}"
    return
  fi
  if [ -n "${GITHUB_EVENT_BEFORE:-}" ] && [ "$GITHUB_EVENT_BEFORE" != "0000000000000000000000000000000000000000" ]; then
    echo "$GITHUB_EVENT_BEFORE"
    return
  fi
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    echo "origin/main"
    return
  fi
  if git rev-parse --verify main >/dev/null 2>&1; then
    echo "main"
    return
  fi
  echo "HEAD~1"
}

BASE="$(base_ref)"
if [[ "$BASE" == origin/* ]]; then
  git fetch origin "${BASE#origin/}" --depth=1 2>/dev/null || true
fi

lintable=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    Sources/*|Tests/*|Examples/*|App/*|Package.swift)
      if [ -f "$ROOT/$f" ]; then
        lintable+=("$ROOT/$f")
      fi
      ;;
  esac
done < <(git diff --name-only --diff-filter=ACMRTUXB "$BASE"...HEAD -- '*.swift' 2>/dev/null || true)

if [ "${#lintable[@]}" -eq 0 ]; then
  echo "No changed Swift source files to lint (base: $BASE)."
  exit 0
fi

echo "Linting ${#lintable[@]} changed Swift file(s) against $BASE ..."
swift format lint \
  --configuration "$CONFIG" \
  --strict \
  --parallel \
  "${lintable[@]}"
