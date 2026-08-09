#!/usr/bin/env python3
"""Repair broken #expect lines from mechanical XCTest migration."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def fix_nil_expect(line: str) -> str:
    if "#expect(" not in line or " == nil" not in line:
        return line
    m = re.match(r"(\s*#expect\()(.+?)( == nil.*)$", line)
    if not m:
        return line
    prefix, expr, suffix = m.group(1), m.group(2), m.group(3)
    if expr.count("(") > expr.count(")"):
        expr = expr + ")"
        line = prefix + expr + suffix
    # trailing double paren: == nil))
    line = re.sub(r" == nil\)\)", " == nil)", line)
    return line


def fix_false_call(line: str) -> str:
    # #expect(!(fn(a)), b, c)) -> #expect(!fn(a, b, c))
    return re.sub(
        r"#expect\(!\((.+?)\), (.+)\)\)",
        r"#expect(!\1, \2))",
        line,
    )


def fix_throws_error(line: str) -> str:
    # broken: #expect(throws: (any Error).self) { try foo( }) { error in
    line = re.sub(
        r"#expect\(throws: \(any Error\)\.self\) \{ try ([^(]+)\( \}\) \{ error in",
        r"#expect(throws: (any Error).self) { try \1() } catch: { error in",
        line,
    )
    line = re.sub(
        r"#expect\(throws: \(any Error\)\.self\) \{ try ([^{]+)\}(?!\s*catch)",
        lambda m: m.group(0) if "catch" in m.group(0) else m.group(0),
        line,
    )
    # InvoiceEditorSeparation: missing closing paren in throws block
    line = re.sub(
        r"\{ try InvoicePDFFileWriter\.write\(source: missingSource, to: destination \}",
        r"{ try InvoicePDFFileWriter.write(source: missingSource, to: destination) }",
        line,
    )
    return line


def fix_accuracy(line: str) -> str:
    # #expect(expr, 12.5, accuracy: 0.001) -> tolerance compare
    m = re.search(r"#expect\((.+?), ([^,]+), accuracy: ([0-9.]+)\)", line)
    if m:
        expr, expected, acc = m.group(1), m.group(2), m.group(3)
        return f"#expect(abs(({expr}) - ({expected})) <= {acc})"
    return line


def fix_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    lines = original.splitlines(keepends=True)
    changed = False
    new_lines = []
    for line in lines:
        new = line
        new = fix_nil_expect(new)
        new = fix_false_call(new)
        new = fix_throws_error(new)
        new = fix_accuracy(new)
        if new != line:
            changed = True
        new_lines.append(new)
    if changed:
        path.write_text("".join(new_lines), encoding="utf-8")
    return changed


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    count = 0
    for path in sorted((root / "Packages").rglob("*Tests*.swift")):
        if fix_file(path):
            count += 1
            print(f"repaired: {path.relative_to(root)}")
    app_test = root / "InvoicingApplicationTests"
    if app_test.exists():
        for path in sorted(app_test.rglob("*.swift")):
            if fix_file(path):
                count += 1
                print(f"repaired: {path.relative_to(root)}")
    print(f"repaired files: {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
