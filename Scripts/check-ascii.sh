#!/usr/bin/env bash
# Fail if banned typography appears in comments or markdown prose.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/Scripts/normalize-ascii-typography.py" --check
