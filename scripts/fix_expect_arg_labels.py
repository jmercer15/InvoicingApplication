#!/usr/bin/env python3
"""Fix remaining broken arg labels: `val == label:` → `val, label:` in test files."""

from __future__ import annotations

import re
import sys
from pathlib import Path

FIX = re.compile(r"([^=!<>]) == (\w+):")


def fix_content(text: str) -> str:
    return FIX.sub(r"\1, \2:", text)


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    count = 0
    for path in sorted((root / "Packages").rglob("*Tests*.swift")):
        original = path.read_text(encoding="utf-8")
        fixed = fix_content(original)
        if fixed != original:
            path.write_text(fixed, encoding="utf-8")
            count += 1
            print(path.relative_to(root))
    print(f"fixed {count} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
