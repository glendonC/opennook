#!/usr/bin/env python3
"""Normalize banned typography to ASCII in comments and markdown prose only."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

BANNED = {
    "\u2013": "-",
    "\u2026": "...",
    "\u2018": "'",
    "\u2019": "'",
    "\u201c": '"',
    "\u201d": '"',
    "\u2192": "->",
    "\u2194": "<->",
}

SPDX_RE = re.compile(r"^\s*//\s*SPDX-License-Identifier:")


def normalize_em_dash(text: str) -> str:
    return re.sub(r"\s*\u2014\s*", " - ", text)


def convert_banned(text: str) -> str:
    out = normalize_em_dash(text)
    for src, dst in BANNED.items():
        out = out.replace(src, dst)
    return out


def is_spdx_line(line: str) -> bool:
    return bool(SPDX_RE.match(line))


def transform_swift(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)

    while i < n:
        # Line comment
        if text.startswith("//", i):
            line_end = text.find("\n", i)
            if line_end == -1:
                line_end = n
            line = text[i:line_end]
            out.append(line if is_spdx_line(line) else convert_banned(line))
            i = line_end
            continue

        # Block comment
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end == -1:
                out.append(convert_banned(text[i:]))
                break
            out.append(convert_banned(text[i : end + 2]))
            i = end + 2
            continue

        # Multiline string
        if text.startswith('"""', i):
            end = text.find('"""', i + 3)
            if end == -1:
                out.append(text[i:])
                break
            out.append(text[i : end + 3])
            i = end + 3
            continue

        # Single-line string
        if text[i] == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    j += 1
                    break
                j += 1
            out.append(text[i:j])
            i = j
            continue

        # Regular code: copy until next token boundary.
        j = i + 1
        while j < n:
            if text[j] in '"':
                break
            if text.startswith("//", j) or text.startswith("/*", j) or text.startswith('"""', j):
                break
            j += 1
        out.append(text[i:j])
        i = j

    return "".join(out)


def transform_markdown(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    in_fence = False
    fence_marker = ""

    while i < n:
        line_end = text.find("\n", i)
        if line_end == -1:
            line_end = n
        line = text[i:line_end]
        newline = text[line_end : line_end + 1] if line_end < n else ""

        stripped = line.lstrip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            marker = stripped[:3]
            if not in_fence:
                in_fence = True
                fence_marker = marker
            elif stripped.startswith(fence_marker):
                in_fence = False
                fence_marker = ""
            out.append(line + newline)
            i = line_end + len(newline)
            continue

        if in_fence:
            out.append(line + newline)
        else:
            out.append(transform_markdown_line(line) + newline)
        i = line_end + len(newline)

    return "".join(out)


def transform_markdown_line(line: str) -> str:
    parts: list[str] = []
    i = 0
    n = len(line)
    while i < n:
        if line[i] == "`":
            j = line.find("`", i + 1)
            if j == -1:
                parts.append(convert_banned(line[i:]))
                break
            parts.append(line[i : j + 1])
            i = j + 1
            continue
        j = i
        while j < n and line[j] != "`":
            j += 1
        parts.append(convert_banned(line[i:j]))
        i = j
    return "".join(parts)


def transform_shell_or_yaml(text: str) -> str:
    out_lines: list[str] = []
    for line in text.splitlines(keepends=True):
        body = line.rstrip("\n\r")
        ending = line[len(body) :]
        hash_idx = body.find("#")
        if hash_idx == -1:
            out_lines.append(line)
            continue
        before = body[:hash_idx]
        comment = body[hash_idx:]
        out_lines.append(before + convert_banned(comment) + ending)
    return "".join(out_lines)


def transform_file(path: Path) -> str | None:
    text = path.read_text(encoding="utf-8")
    suffix = path.suffix.lower()

    if suffix == ".swift":
        new = transform_swift(text)
    elif suffix in {".md", ".mdx"}:
        new = transform_markdown(text)
    elif suffix == ".plist":
        return None
    elif suffix in {".sh", ".yml", ".yaml"} or path.name == ".gitignore":
        new = transform_shell_or_yaml(text)
    else:
        return None

    return new if new != text else None


def tracked_text_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    skip_suffix = {
        ".png", ".jpg", ".jpeg", ".ico", ".svg",
        ".woff", ".woff2", ".otf", ".ttf", ".plist",
    }
    files: list[Path] = []
    for rel in result.stdout.splitlines():
        p = REPO_ROOT / rel
        if p.suffix.lower() in skip_suffix or not p.is_file():
            continue
        try:
            p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        files.append(p)
    return files


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    check = "--check" in sys.argv
    changed = 0
    violations: list[str] = []
    for path in tracked_text_files():
        new_text = transform_file(path)
        if new_text is None:
            continue
        changed += 1
        rel = path.relative_to(REPO_ROOT)
        if check:
            violations.append(str(rel))
        elif dry_run:
            print(rel)
        else:
            path.write_text(new_text, encoding="utf-8")
            print(rel)
    if check:
        if violations:
            print("Banned typography found in comments/markdown prose:", file=sys.stderr)
            for v in violations:
                print(f"  {v}", file=sys.stderr)
            return 1
        print("ASCII typography check passed.", file=sys.stderr)
        return 0
    action = "Would change" if dry_run else "Changed"
    print(f"{action} {changed} file(s)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
