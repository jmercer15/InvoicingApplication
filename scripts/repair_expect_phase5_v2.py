#!/usr/bin/env python3
"""Repair #expect lines broken by mechanical XCTest→Swift Testing migration."""

from __future__ import annotations

import re
import sys
from pathlib import Path

# foo: bar == baz: qux  →  foo: bar, baz: qux  (inside broken call args)
ARG_FIX = re.compile(r"(\w+):\s*([^=][^,)]*?)\s*==\s*(\w+):")


def fix_broken_arg_labels(text: str) -> str:
    return ARG_FIX.sub(r"\1: \2, \3:", text)


def fix_not_wrapped_parens(line: str) -> str:
    stripped = line.rstrip()
    if "#expect(!(" not in stripped:
        return line
    # #expect(!(expr)) or #expect(!(expr) with closing paren on next line handled elsewhere
    if stripped.count("(") == stripped.count(")"):
        inner = stripped.replace("#expect(!(", "#expect(!", 1)
        if inner.endswith("))"):
            inner = inner[:-1]
        return inner + ("\n" if line.endswith("\n") else "")
    return line


def fix_multiline_equal_expect(lines: list[str], i: int) -> tuple[list[str], int]:
    """#expect(expr,\n    expected\n) → #expect(expr == expected)"""
    line = lines[i]
    if not line.strip().startswith("#expect("):
        return lines, i

    # Collect until closing paren at same indent level as #expect
    block = [line]
    j = i + 1
    while j < len(lines):
        block.append(lines[j])
        if lines[j].strip() == ")":
            break
        j += 1
    if j >= len(lines) or lines[j].strip() != ")":
        return lines, i

    joined = "".join(block)
    m = re.search(
        r"#expect\((.+?),\s*\n\s*(.+?)\s*\n\s*\)",
        joined,
        re.DOTALL,
    )
    if not m:
        return lines, i

    expr = fix_broken_arg_labels(m.group(1).strip())
    expected = m.group(2).strip()
    if expected.endswith(","):
        return lines, i

    indent = re.match(r"(\s*)", line).group(1)
    new_line = f"{indent}#expect({expr} == {expected})\n"
    new_lines = lines[:i] + [new_line] + lines[j + 1 :]
    return new_lines, i


def fix_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    text = fix_broken_arg_labels(original)

    lines = text.splitlines(keepends=True)
    i = 0
    while i < len(lines):
        lines, i = fix_multiline_equal_expect(lines, i)
        i += 1

    new_lines = [fix_not_wrapped_parens(line) for line in lines]

    # Fix broken parsedValue strings: "$1 == 234.56" → "$1,234.56"
    content = "".join(new_lines)
    content = content.replace('parsedValue("$1 == 234.56")', 'parsedValue("$1,234.56")')
    content = content.replace('parsedValue("AUD 1.234 == 56")', 'parsedValue("AUD 1,234.56")')

    # Fix stray brace from bad merge
    content = content.replace("<= 0.001)}", "<= 0.001)")

    if content != original:
        path.write_text(content, encoding="utf-8")
        return True
    return False


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    count = 0
    for path in sorted((root / "Packages").rglob("*Tests*.swift")):
        if fix_file(path):
            count += 1
            print(path.relative_to(root))
    print(f"repaired {count} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
