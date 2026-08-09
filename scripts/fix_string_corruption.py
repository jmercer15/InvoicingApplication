#!/usr/bin/env python3
"""Undo arg-label script damage inside strings and array literals."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def fix_quoted_strings(text: str) -> str:
    def repl(match: re.Match[str]) -> str:
        return match.group(0).replace(" == ", ", ")

    return re.sub(r'"[^"\\]*(?:\\.[^"\\]*)*"', repl, text)


def fix_string_adjacent_equals(text: str) -> str:
    return re.sub(r'"\s*==\s*"', '", "', text)


def fix_incomplete_expect_lines(text: str) -> str:
    # #expect(expr)\n without == expected at end of broken migrations
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped.startswith("#expect(") and "==" not in stripped and not stripped.endswith("{") and "throws:" not in stripped:
            if stripped.endswith(")"):
                out.append(line)
                i += 1
                continue
            # collect multiline #expect missing close
            block = [line]
            j = i + 1
            while j < len(lines) and not lines[j].strip().startswith("#expect") and not lines[j].strip().startswith("@"):
                block.append(lines[j])
                if lines[j].strip().endswith(")"):
                    break
                j += 1
            joined = "".join(block)
            if joined.count("(") > joined.count(")"):
                block[-1] = block[-1].rstrip() + ")\n"
            out.extend(block)
            i = j + 1
            continue
        out.append(line)
        i += 1
    return "".join(out)


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    count = 0
    for path in sorted((root / "Packages").rglob("*Tests*.swift")):
        original = path.read_text(encoding="utf-8")
        fixed = fix_incomplete_expect_lines(fix_string_adjacent_equals(fix_quoted_strings(original)))
        if fixed != original:
            path.write_text(fixed, encoding="utf-8")
            count += 1
            print(path.relative_to(root))
    print(f"fixed {count} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
