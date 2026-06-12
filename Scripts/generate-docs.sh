#!/usr/bin/env bash
# generate-docs.sh
# Builds the OpenNook API reference as a combined, static-hostable DocC site from
# the framework's own doc comments - the same documentation Swift Package Index
# builds and hosts per release (the targets are pinned in .spi.yml).
#
# The swift-docc-plugin is an opt-in dependency: it is added to Package.swift only
# when OPENNOOK_BUILD_DOCS is set (which this script does), so consumers of OpenNook
# never resolve or fetch it.
#
# Usage:
#   ./Scripts/generate-docs.sh [output-dir] [hosting-base-path]
# Defaults: output-dir = ./.docs-out, hosting-base-path = opennook
#
# Preview locally after generating:
#   (cd .docs-out && python3 -m http.server 8000)
#   then open http://localhost:8000/opennook/documentation/nookapp/

set -euo pipefail

cd "$(dirname "$0")/.."

OUTPUT_DIR="${1:-$PWD/.docs-out}"
BASE_PATH="${2:-opennook}"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

OPENNOOK_BUILD_DOCS=1 swift package \
  --allow-writing-to-directory "$OUTPUT_DIR" \
  generate-documentation \
  --enable-experimental-combined-documentation \
  --target NookApp \
  --target NookKit \
  --target NookSurface \
  --target NookComponents \
  --transform-for-static-hosting \
  --hosting-base-path "$BASE_PATH" \
  --output-path "$OUTPUT_DIR"

echo
echo "DocC site generated at: $OUTPUT_DIR (hosting-base-path: /$BASE_PATH)"
