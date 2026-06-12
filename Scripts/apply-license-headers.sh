#!/usr/bin/env bash
# Apply SPDX license headers to source files. Idempotent - skips files that already carry
# an `SPDX-License-Identifier` line. Run from the repo root.
set -euo pipefail

APACHE_HEADER='// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

'

MIT_HEADER='// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim — DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin — OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

'

prepend_header_if_missing() {
    local file="$1"
    local header="$2"
    if grep -q "SPDX-License-Identifier" "$file" 2>/dev/null; then
        return 0
    fi
    printf '%s' "$header" | cat - "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
    echo "headed: $file"
}

apply_to_target() {
    local target_path="$1"
    local header="$2"
    while IFS= read -r -d '' file; do
        prepend_header_if_missing "$file" "$header"
    done < <(find "$target_path" -name '*.swift' -type f -print0)
}

apply_to_target "Sources/NookKit" "$APACHE_HEADER"
apply_to_target "Sources/NookApp" "$APACHE_HEADER"
apply_to_target "Sources/NookExecutable" "$APACHE_HEADER"
apply_to_target "Tests/NookKitTests" "$APACHE_HEADER"
apply_to_target "Sources/NookSurface" "$MIT_HEADER"
