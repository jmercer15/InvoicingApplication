#!/usr/bin/env python3
"""Fix #expect lines broken by XCTAssertEqual(call-with-commas, expected) migration."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def fix_multiarg_expect(line: str) -> str:
    # #expect(f(a == label: b), expected) -> #expect(f(a, label: b) == expected)
    pattern = re.compile(r"#expect\((.+?) == (\w+): ([^)]+)\), (.+)\)\s*$")
    m = pattern.match(line.rstrip())
    if m:
        expr, label, arg, expected = m.groups()
        return f"#expect({expr}, {label}: {arg}) == {expected})"
    return line


def fix_for_error_fallback(line: str) -> str:
    # for: error == fallback: "msg" -> for: error, fallback: "msg"
    return re.sub(
        r"for: (\w+) == (\w+):",
        r"for: \1, \2:",
        line,
    )


def fix_current_requested(line: str) -> str:
    return re.sub(
        r"current: (\w+) == requested: (\w+)",
        r"current: \1, requested: \2",
        line,
    )


def fix_invoice_number_presentation(line: str) -> str:
    return re.sub(
        r"invoiceNumber: ([^=]+) == presentation:",
        r"invoiceNumber: \1, presentation:",
        line,
    )


def fix_parse_calls(line: str) -> str:
    line = re.sub(
        r"\.parse\(\"([^\"]+)\" == locale: locale\)",
        r'.parse("\1", locale: locale)',
        line,
    )
    line = re.sub(
        r"\.parse\(display == locale: locale\)",
        r".parse(display, locale: locale)",
        line,
    )
    line = re.sub(
        r"\.parse\(\"([^\"]+)\" == in: ([^)]+)\)",
        r'.parse("\1", in: \2)',
        line,
    )
    line = re.sub(
        r"\.parse\(display == in: ([^,]+), locale: locale\)",
        r".parse(display, in: \1, locale: locale)",
        line,
    )
    line = re.sub(
        r"\.parse\(text == in: ([^)]+)\)",
        r".parse(text, in: \1)",
        line,
    )
    line = re.sub(
        r"\.parse\(\"([^\"]+)\" == in: 0\.\.\.maximum\)",
        r'.parse("\1", in: 0...maximum)',
        line,
    )
    return line


def fix_restored_text(line: str) -> str:
    return re.sub(
        r"restoredText\(for: \"(\w+)\" == baseline: \"([^\"]+)\"\)",
        r'restoredText(for: "\1", baseline: "\2")',
        line,
    )


def fix_project_spec(line: str) -> str:
    return re.sub(
        r"project\(invoices: invoices == spec: spec\)",
        r"project(invoices: invoices, spec: spec)",
        line,
    )


def fix_minimum_maximum(line: str) -> str:
    return re.sub(
        r"minimum: ([^=]+) == maximum:",
        r"minimum: \1, maximum:",
        line,
    )


def fix_moved_record(line: str) -> str:
    return re.sub(
        r"movedRecord\(\"(\w+)\" == to:",
        r'movedRecord("\1", to:',
        line,
    )


def fix_receipt_readiness(line: str) -> str:
    line = re.sub(r"message\(paidDate: nil == notes:", r"message(paidDate: nil, notes:", line)
    line = re.sub(r"message\(paidDate: paidDate == notes:", r"message(paidDate: paidDate, notes:", line)
    line = re.sub(r"paidDate: paidDate == notes:", r"paidDate: paidDate, notes:", line)
    return line


def fix_bulk_copy(line: str) -> str:
    line = re.sub(r"Progress\(completed: (\d+) == total:", r"Progress(completed: \1, total:", line)
    line = re.sub(r"Result\(processed: (\d+) == blocked:", r"Result(processed: \1, blocked:", line)
    return line


def fix_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    lines = []
    changed = False
    for line in original.splitlines(keepends=True):
        new = line
        new = fix_multiarg_expect(new)
        new = fix_for_error_fallback(new)
        new = fix_current_requested(new)
        new = fix_invoice_number_presentation(new)
        new = fix_parse_calls(new)
        new = fix_restored_text(new)
        new = fix_project_spec(new)
        new = fix_minimum_maximum(new)
        new = fix_moved_record(new)
        new = fix_receipt_readiness(new)
        new = fix_bulk_copy(new)
        if new != line:
            changed = True
        lines.append(new)
    if changed:
        path.write_text("".join(lines), encoding="utf-8")
    return changed


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    count = 0
    for path in sorted((root / "Packages").rglob("*Tests*.swift")):
        if fix_file(path):
            count += 1
            print(path.relative_to(root))
    print(f"fixed {count} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
