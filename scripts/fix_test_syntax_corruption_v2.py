#!/usr/bin/env python3
"""Comprehensive repair for Swift Testing migration corruption."""

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


def remove_balanced_block(text: str, start: int) -> tuple[str, int]:
    if start >= len(text) or text[start] != "{":
        return text, start
    depth = 0
    i = start
    while i < len(text):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[:start] + text[i + 1 :], i + 1
        i += 1
    return text, start


def remove_override_method(text: str, name: str) -> str:
    marker = f"override func {name}()"
    while True:
        idx = text.find(marker)
        if idx == -1:
            break
        brace = text.find("{", idx)
        if brace == -1:
            break
        text, _ = remove_balanced_block(text, brace)
        # remove signature line back to previous newline
        line_start = text.rfind("\n", 0, idx) + 1
        text = text[:line_start] + text[brace if brace < len(text) else idx :]
        # simpler: find marker, find opening brace, remove from line_start to end of block
    return text


def remove_override_method_v2(text: str, name: str) -> str:
    pattern = rf"\n\s*override func {name}\(\)[^{{]*\{{"
    while True:
        m = re.search(pattern, text)
        if not m:
            break
        brace = m.end() - 1
        new_text, _ = remove_balanced_block(text, brace)
        if new_text == text:
            break
        # remove from match start
        text = text[: m.start()] + text[brace + (len(text) - len(new_text)) :]
        # The remove_balanced_block removes from start index wrong - rewrite
    return text


def strip_lifecycle_methods(text: str) -> str:
    for method in ("setUp", "tearDown"):
        token = f"override func {method}()"
        while token in text:
            start = text.index(token)
            line_start = text.rfind("\n", 0, start)
            line_start = 0 if line_start == -1 else line_start + 1
            brace = text.find("{", start)
            if brace == -1:
                break
            depth = 0
            end = brace
            for i in range(brace, len(text)):
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                    if depth == 0:
                        end = i + 1
                        break
            text = text[:line_start] + text[end:].lstrip("\n")
    return text


def inject_inmemory_setup(text: str) -> str:
    if "ModelContainerFactory.makeInMemoryContext()" in text:
        return text
    if "modelContext" not in text and "ModelContext" not in text:
        return text

    def repl(m: re.Match[str]) -> str:
        indent = m.group(1)
        return (
            f"{indent}@Test func {m.group(2)}() throws {{\n"
            f"{indent}    let (modelContainer, modelContext) = "
            f"try ModelContainerFactory.makeInMemoryContext()\n"
        )

    return re.sub(
        r"(\n\s*)@Test func (\w+)\(\) throws \{",
        repl,
        text,
    )


def fix_extra_close_parens(content: str) -> str:
    # #expect(!expr)) -> #expect(!expr) when expr is simple member access
    content = re.sub(
        r"#expect\(!([A-Za-z0-9_.]+(\([^)]*\))?)\)\)",
        r"#expect(!(\1))",
        content,
    )
    # #expect(!func(""))) -> #expect(!(func("")))
    content = re.sub(
        r'#expect\(!([A-Za-z0-9_.]+\("[^"]*"\))\)\)',
        r"#expect(!(\1))",
        content,
    )
    return content


def fix_array_literal_close(content: str) -> str:
    # == ["a", "b") -> == ["a", "b"])
    content = re.sub(
        r'(== \[[^\]]*"[^"]*"(?:, "[^"]*")*)("\))',
        r"\1]\2",
        content,
    )
    # title == "Client A"]) -> title == "Client A")
    content = re.sub(
        r'(== "[^"]+)("\]\))',
        r'\1")',
        content,
    )
    return content


def fix_broken_throws_error_block(content: str) -> str:
    pattern = re.compile(
        r"#expect\(throws: \(any Error\)\.self\) \{ try ([^}]+)\} \) \{ error in\n"
        r"((?:.*\n)*?)\s*\}",
        re.M,
    )

    def repl(m: re.Match[str]) -> str:
        try_expr = m.group(1).strip()
        body = m.group(2)
        body = body.replace("return XCTFail(", "Issue.record(")
        body = re.sub(r"\bXCTFail\(", "Issue.record(", body)
        return (
            "do {\n"
            f"            _ = try {try_expr}\n"
            '            Issue.record("Expected error")\n'
            "        } catch {\n"
            f"{body}"
            "        }"
        )

    return pattern.sub(repl, content)


def fix_remaining_xctest(content: str) -> str:
    content = re.sub(
        r"return XCTFail\(([^)]+)\)",
        r"Issue.record(\1)",
        content,
    )
    content = re.sub(r"\bXCTFail\(([^)]+)\)", r"Issue.record(\1)", content)
    content = re.sub(
        r"XCTAssertLessThanOrEqual\(([^,]+),\s*([^)]+)\)",
        r"#expect(\1 <= \2)",
        content,
    )
    content = re.sub(
        r"XCTAssertGreaterThanOrEqual\(\s*([^,]+),\s*([^)]+)\)",
        r"#expect(\1 >= \2)",
        content,
    )
    content = re.sub(
        r"XCTAssertNoThrow\(try ([^)]+)\)",
        r"#expect(throws: Never.self) { try \1 }",
        content,
    )
    return content


def fix_compliance_approval(content: str) -> str:
    if "BillingHubComplianceApprovalPolicyTests" not in content:
        return content
    return content.replace(
        """        #expect(!(BillingHubComplianceApprovalPolicy.canApprove(
                isBusy: true, hasBlockers: false,
                checkCompleted: true))
        #expect(BillingHubComplianceApprovalPolicy.canApprove(
                isBusy: false, hasBlockers: false,
                checkCompleted: true))
        )""",
        """        #expect(!(BillingHubComplianceApprovalPolicy.canApprove(
                isBusy: true, hasBlockers: false,
                checkCompleted: true)))
        #expect(BillingHubComplianceApprovalPolicy.canApprove(
                isBusy: false, hasBlockers: false,
                checkCompleted: true))""",
    )


def fix_relationship_deletion_duplicate(content: str) -> str:
    if "RelationshipDeletionTests" not in content:
        return content
    # Remove empty duplicate @Test stubs
    content = re.sub(
        r"\n\s*@Test func (\w+)\(\) throws \{\s*\n\s*\n\s*@Test func \1\(\) throws \{",
        r"\n    @Test func \1() throws {",
        content,
    )
    return content


def convert_xctest(content: str) -> str:
    out = content
    out = re.sub(r"^import XCTest\s*\n", "import Testing\n", out, flags=re.M)
    out = re.sub(r"final class (\w+): XCTestCase \{", r"@Suite struct \1 {", out)
    out = re.sub(r"\bfunc test(\w+)\(\)", r"@Test func \1()", out)
    out = strip_lifecycle_methods(out)
    # import restore_and_convert assertion logic inline - skip, run restore script separately
    return out


def process_file(path: Path, repo: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    content = original
    content = fix_extra_close_parens(content)
    content = fix_array_literal_close(content)
    content = fix_broken_throws_error_block(content)
    content = fix_remaining_xctest(content)
    content = fix_compliance_approval(content)
    content = fix_relationship_deletion_duplicate(content)
    if content != original:
        path.write_text(content, encoding="utf-8")
        return True
    return False


def restore_relationship_deletion(repo: Path) -> None:
    rel = "Packages/Data/Tests/DataTests/Validation/RelationshipDeletionTests.swift"
    original = git_show(repo, rel)
    if not original:
        return
    # Use restore_and_convert_tests module
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "conv", repo / "scripts/restore_and_convert_tests.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    converted = mod.convert_xctest(original)
    converted = strip_lifecycle_methods(converted)
    converted = inject_inmemory_setup(converted)
    converted = fix_remaining_xctest(converted)
    converted = fix_extra_close_parens(converted)
    if "import Foundation" not in converted:
        converted = converted.replace("import Testing\n", "import Foundation\nimport Testing\n", 1)
    (repo / rel).write_text(converted, encoding="utf-8")


def main() -> int:
    repo = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    restore_relationship_deletion(repo)
    changed = 0
    for path in sorted((repo / "Packages").rglob("*Tests*.swift")):
        if process_file(path, repo):
            changed += 1
            print(path.relative_to(repo))
    print(f"fixed {changed} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
