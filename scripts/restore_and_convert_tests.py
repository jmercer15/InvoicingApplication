#!/usr/bin/env python3
"""Convert XCTest to Swift Testing using balanced-paren assertion parsing."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


def git_show(repo: Path, rel: str) -> str | None:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo), "show", f"HEAD:{rel}"],
            text=True,
        )
    except subprocess.CalledProcessError:
        return None


def split_top_level_args(s: str) -> list[str]:
    args: list[str] = []
    depth = 0
    current: list[str] = []
    in_string = False
    escape = False
    for ch in s:
        if in_string:
            current.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
            current.append(ch)
        elif ch == "(":
            depth += 1
            current.append(ch)
        elif ch == ")":
            depth -= 1
            current.append(ch)
        elif ch == "," and depth == 0:
            args.append("".join(current).strip())
            current = []
        else:
            current.append(ch)
    if current:
        args.append("".join(current).strip())
    return args


def extract_call(text: str, start: int) -> tuple[str, int] | None:
    """Return inside-parens content and index after closing paren."""
    if start >= len(text) or text[start] != "(":
        return None
    depth = 0
    in_string = False
    escape = False
    i = start
    while i < len(text):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return text[start + 1 : i], i + 1
        i += 1
    return None


def convert_assertion(name: str, args: list[str]) -> str | None:
    msg = ""
    if name in {"Equal", "NotEqual", "GreaterThan", "GreaterThanOrEqual", "LessThan", "LessThanOrEqual"}:
        if len(args) >= 3 and args[2].startswith('"'):
            msg = f", {args[2]}"
        if name == "Equal" and len(args) >= 2:
            return f"#expect({args[0]} == {args[1]}{msg})"
        if name == "NotEqual" and len(args) >= 2:
            return f"#expect({args[0]} != {args[1]}{msg})"
        if name == "GreaterThan" and len(args) >= 2:
            return f"#expect({args[0]} > {args[1]}{msg})"
        if name == "GreaterThanOrEqual" and len(args) >= 2:
            return f"#expect({args[0]} >= {args[1]}{msg})"
        if name == "LessThan" and len(args) >= 2:
            return f"#expect({args[0]} < {args[1]}{msg})"
        if name == "LessThanOrEqual" and len(args) >= 2:
            return f"#expect({args[0]} <= {args[1]}{msg})"
    if name == "True" and args:
        if len(args) >= 2 and args[1].startswith('"'):
            return f"#expect({args[0]}, {args[1]})"
        return f"#expect({args[0]})"
    if name == "False" and args:
        if len(args) >= 2 and args[1].startswith('"'):
            return f"#expect(!({args[0]}), {args[1]})"
        return f"#expect(!({args[0]}))"
    if name == "Nil" and args:
        if len(args) >= 2 and args[1].startswith('"'):
            return f"#expect({args[0]} == nil, {args[1]})"
        return f"#expect({args[0]} == nil)"
    if name == "NotNil" and args:
        if len(args) >= 2 and args[1].startswith('"'):
            return f"#expect({args[0]} != nil, {args[1]})"
        return f"#expect({args[0]} != nil)"
    return None


NAMES = (
    "AssertEqual",
    "AssertNotEqual",
    "AssertTrue",
    "AssertFalse",
    "AssertNil",
    "AssertNotNil",
    "AssertGreaterThan",
    "AssertGreaterThanOrEqual",
    "AssertLessThan",
    "AssertLessThanOrEqual",
)


def replace_assertions(text: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(text):
        matched = False
        for prefix in NAMES:
            token = f"XCT{prefix}"
            if text.startswith(token, i):
                call = extract_call(text, i + len(token))
                if call is None:
                    break
                body, end = call
                name = prefix.removeprefix("Assert")
                converted = convert_assertion(name, split_top_level_args(body))
                if converted:
                    out.append(converted)
                    i = end
                    matched = True
                    break
        if matched:
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def convert_xctest(content: str) -> str:
    out = content
    out = re.sub(r"^import XCTest\s*\n", "import Testing\n", out, flags=re.M)
    out = re.sub(r"final class (\w+): XCTestCase \{", r"@Suite struct \1 {", out)
    out = re.sub(r"\bfunc test(\w+)\(\)", r"@Test func \1()", out)
    for method in ("setUp", "tearDown"):
        token = f"override func {method}()"
        while token in out:
            start = out.index(token)
            line_start = out.rfind("\n", 0, start)
            line_start = 0 if line_start == -1 else line_start + 1
            brace = out.find("{", start)
            if brace == -1:
                break
            depth = 0
            end = brace
            for i in range(brace, len(out)):
                if out[i] == "{":
                    depth += 1
                elif out[i] == "}":
                    depth -= 1
                    if depth == 0:
                        end = i + 1
                        break
            out = out[:line_start] + out[end:].lstrip("\n")

    prev = None
    while prev != out:
        prev = out
        out = replace_assertions(out)

    out = re.sub(r"XCTUnwrap\((.*?)\)", r"try #require(\1)", out, flags=re.S)
    out = re.sub(
        r"XCTAssertThrowsError\(\s*try\s*(.*?)\s*\)",
        r"#expect(throws: (any Error).self) { try \1 }",
        out,
        flags=re.S,
    )

    if "import Testing" in out and not re.search(r"^import Foundation\s*$", out, re.M):
        if re.search(r"\b(UUID|Date|Locale|Decimal|FileManager|TimeZone|Calendar)\b", out):
            out = out.replace("import Testing\n", "import Foundation\nimport Testing\n", 1)

    return out


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    converted = 0
    for path in sorted((root / "Packages").rglob("*Tests*.swift")):
        rel = path.relative_to(root).as_posix()
        original = git_show(root, rel)
        if original is None or "import XCTest" not in original:
            continue
        path.write_text(convert_xctest(original), encoding="utf-8")
        converted += 1
    print(f"converted {converted} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
