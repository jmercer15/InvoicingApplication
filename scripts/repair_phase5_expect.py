#!/usr/bin/env python3
"""Repair Phase 5 XCTest→Swift Testing migration artifacts in test files."""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Commas inside call args were corrupted to " == label:"
ARG_LABEL_FIXES = [
    (r" == locale:", ", locale:"),
    (r" == in:", ", in:"),
    (r" == to:", ", to:"),
    (r" == from:", ", from:"),
    (r" == notes:", ", notes:"),
    (r" == total:", ", total:"),
    (r" == totalCount:", ", totalCount:"),
    (r" == blocked:", ", blocked:"),
    (r" == maximum:", ", maximum:"),
    (r" == minimum:", ", minimum:"),
    (r" == baseline:", ", baseline:"),
    (r" == spec:", ", spec:"),
    (r" == invoiceTotal:", ", invoiceTotal:"),
    (r" == presentation:", ", presentation:"),
    (r" == requested:", ", requested:"),
    (r" == externalIdentifier:", ", externalIdentifier:"),
    (r" == statusToken:", ", statusToken:"),
    (r" == hasInvoice:", ", hasInvoice:"),
    (r" == savedEdits:", ", savedEdits:"),
    (r" == whileTemplateSaveFailed:", ", whileTemplateSaveFailed:"),
    (r" == context:", ", context:"),
    (r" == file:", ", file:"),
    (r" == line:", ", line:"),
    (r" == invoiceNumbers:", ", invoiceNumbers:"),
    (r" == eventIdentifier:", ", eventIdentifier:"),
    (r" == end:", ", end:"),
    (r" == start:", ", start:"),
]

# Numeric/thousands separators inside string literals: "1 == 234.50" -> "1,234.50"
NUMERIC_STRING = re.compile(r'"(\d+) == (\d[\d.]*)"')
# Array element separators: "a" == "b" -> "a", "b"
ARRAY_STRING = re.compile(r'"([^"]+)" == "([^"]+)"')
# Empty string corruption: parse("" == -> parse("",
EMPTY_PARSE = re.compile(r'\.parse\("" == ')


def fix_arg_labels(line: str) -> str:
    for pattern, repl in ARG_LABEL_FIXES:
        line = line.replace(pattern, repl)
    return line


def fix_string_corruption(line: str) -> str:
    line = EMPTY_PARSE.sub('.parse("", ', line)
    line = NUMERIC_STRING.sub(r'"\1,\2"', line)
    # Only fix array-like patterns inside [ ... ]
    if "[" in line and " == " in line:
        line = ARRAY_STRING.sub(r'"\1", "\2"', line)
    return line


def split_merged_expects(line: str) -> list[str]:
    """Split lines with multiple #expect calls onto separate lines."""
    if line.count("#expect") <= 1:
        return [line]
    indent = re.match(r"(\s*)", line).group(1)
    parts = re.split(r"(?=#expect)", line.strip())
    result = []
    for part in parts:
        part = part.strip()
        if not part:
            continue
        # Preserve trailing brace on last part only
        if part.endswith("}") and not part.startswith("#expect"):
            continue
        trailing = ""
        if part.endswith("    }") or part.endswith("  }") or part.endswith("\t}"):
            idx = part.rfind("}")
            trailing = part[idx:]
            part = part[:idx].rstrip()
        result.append(f"{indent}{part}{trailing}\n")
    return result if result else [line]


def fix_throws_blocks(line: str) -> str:
    line = re.sub(
        r"#expect\(throws: \(any Error\)\.self\) \{ try ([^(]+)\( context: \"([^\"]+)\" \}\)",
        r'#expect(throws: (any Error).self) { try \1(context: "\2") }',
        line,
    )
    line = re.sub(
        r"\{ try InvoicePDFFileWriter\.write\(source: missingSource, to: destination \}",
        r"{ try InvoicePDFFileWriter.write(source: missingSource, to: destination) }",
        line,
    )
    return line


def fix_corrupted_comment_expect(line: str) -> str:
    # #expect(expr, "message" == expected) -> #expect(expr == expected, "message")
    m = re.search(
        r"#expect\((.+?), (\"(?:\\.|[^\"])*\") == (.+)\)\s*$",
        line.rstrip(),
    )
    if m:
        expr, msg, expected = m.group(1), m.group(2), m.group(3)
        return f"#expect({expr} == {expected}, {msg})\n"
    return line


def is_comment_second_arg(second: str) -> bool:
    second = second.strip()
    if second.startswith('"'):
        return True
    if second.startswith("file:") or second.startswith("sourceLocation:"):
        return True
    return False


def convert_two_arg_expect(line: str) -> str:
    """#expect(a, b) -> #expect(a == b) when b is not a comment."""
    stripped = line.rstrip()
    if not stripped.lstrip().startswith("#expect("):
        return line
    if "throws:" in stripped or "try #require" in stripped:
        return line

    m = re.match(r"(\s*)#expect\((.+)\)\s*(.*)$", stripped)
    if not m:
        return line
    indent, inner, trailing = m.group(1), m.group(2), m.group(3)

    # Find top-level comma separating condition from second arg
    depth = 0
    split_idx = -1
    in_string = False
    escape = False
    for i, ch in enumerate(inner):
        if escape:
            escape = False
            continue
        if ch == "\\":
            escape = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            split_idx = i
            break

    if split_idx < 0:
        return line

    first = inner[:split_idx].strip()
    second = inner[split_idx + 1 :].strip()

    if is_comment_second_arg(second):
        return line

    # Multiline second arg with closing paren on next line handled elsewhere
    if trailing.strip() in (")", ")", "}"):
        second = second + " " + trailing.strip()
        trailing = ""

    return f"{indent}#expect({first} == {second}){trailing}\n"


def fix_broken_fetch_expect(line: str) -> str:
    # #expect(try context.fetch(...) == nil).first?.notes) -> proper form
    line = re.sub(
        r"#expect\(try context\.fetch\(FetchDescriptor<Invoice>\(\)\) == nil\)\.first\?\.notes\)",
        r"#expect(try context.fetch(FetchDescriptor<Invoice>()).first?.notes == nil)",
        line,
    )
    return line


def fix_trailing_junk(line: str) -> str:
    line = re.sub(r"\)\s+\)\s*$", ")\n", line.rstrip()) + ("\n" if line.endswith("\n") else "")
    line = re.sub(r"#expect\((.+)\) == nil\)\.first\?", r"#expect(\1.first?", line)
    return line


def fix_false_negation(line: str) -> str:
    return re.sub(
        r"#expect\(!\((.+?)\), (.+)\)\)",
        r"#expect(!\1, \2))",
        line,
    )


def fix_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    lines: list[str] = []
    changed = False

    for line in original.splitlines(keepends=True):
        new = line
        new = fix_arg_labels(new)
        new = fix_string_corruption(new)
        new = fix_throws_blocks(new)
        new = fix_corrupted_comment_expect(new)
        new = fix_broken_fetch_expect(new)
        new = fix_trailing_junk(new)
        new = fix_false_negation(new)
        new = convert_two_arg_expect(new)

        if new != line:
            changed = True

        for split_line in split_merged_expects(new):
            if split_line != line:
                changed = True
            lines.append(split_line)

    text = "".join(lines)
    # Cleanup duplicate blank lines from splits
    text = re.sub(r"\n{3,}", "\n\n", text)

    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return changed


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    count = 0
    for path in sorted((root / "Packages").rglob("*Tests*.swift")):
        if fix_file(path):
            count += 1
            print(path.relative_to(root))
    app_test = root / "InvoicingApplicationTests"
    if app_test.exists():
        for path in sorted(app_test.rglob("*.swift")):
            if fix_file(path):
                count += 1
                print(path.relative_to(root))
    print(f"repaired {count} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
