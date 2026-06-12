#!/usr/bin/env bash
# Export llvm-cov LCOV after `swift test --enable-code-coverage`.
# Prints a Sources-only summary to CI logs; writes coverage.lcov for Codecov.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/coverage.lcov"

profdata="$(find "$ROOT/.build" -path '*/codecov/default.profdata' -print -quit 2>/dev/null || true)"
binary="$(find "$ROOT/.build" -path '*/NookPackageTests.xctest/Contents/MacOS/NookPackageTests' -print -quit 2>/dev/null || true)"

if [ -z "$profdata" ] || [ -z "$binary" ]; then
  echo "::warning::coverage artifacts not found - skip upload"
  exit 0
fi

echo "Profdata: $profdata"
echo "Binary:   $binary"

echo "--- Library line coverage (Sources/) ---"
report="$(xcrun llvm-cov report "$binary" -instr-profile="$profdata" 2>/dev/null || true)"
if [ -n "$report" ]; then
  printf '%s\n' "$report" | awk '
    /^Sources\/NookKit\//     { kt += $8; km += $9 }
    /^Sources\/NookSurface\// { st += $8; sm += $9 }
    /^Sources\/NookComponents\// { ct += $8; cm += $9 }
    END {
      if (kt > 0) printf "NookKit:        %.1f%% lines\n", 100.0 * (kt - km) / kt
      if (st > 0) printf "NookSurface:    %.1f%% lines\n", 100.0 * (st - sm) / st
      if (ct > 0) printf "NookComponents: %.1f%% lines\n", 100.0 * (ct - cm) / ct
      total = kt + st + ct; missed = km + sm + cm
      if (total > 0) printf "Combined:       %.1f%% lines\n", 100.0 * (total - missed) / total
    }'
fi

xcrun llvm-cov export "$binary" \
  -instr-profile="$profdata" \
  -format=lcov \
  -ignore-filename-regex='Tests/' \
  -ignore-filename-regex='\.build/' \
  > "$OUT"

echo "Wrote $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"
