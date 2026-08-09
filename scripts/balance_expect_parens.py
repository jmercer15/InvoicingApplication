#!/usr/bin/env python3
"""Close unbalanced #expect(!( ... ) blocks missing trailing ))."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def balance_expect_blocks(text: str) -> str:
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.strip().startswith("#expect(!("):
            block = [line]
            j = i + 1
            open_p = line.count("(") - line.count(")")
            while j < len(lines) and open_p > 0:
                block.append(lines[j])
                open_p += lines[j].count("(") - lines[j].count(")")
                j += 1
            joined = "".join(block).rstrip()
            # If block ends with single ) but started with #expect(!(, need one more )
            if joined.startswith("#expect(!(") and joined.endswith(")") and not joined.endswith("))"):
                block[-1] = block[-1].rstrip().rstrip(")") + "))\n"
            out.extend(block)
            i = j
            continue
        out.append(line)
        i += 1
    return "".join(out)


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    count = 0
    for path in sorted((root / "Packages").rglob("*Tests*.swift")):
        original = path.read_text(encoding="utf-8")
        fixed = balance_expect_blocks(original)
        if fixed != original:
            path.write_text(fixed, encoding="utf-8")
            count += 1
            print(path.relative_to(root))
    print(f"balanced {count} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
