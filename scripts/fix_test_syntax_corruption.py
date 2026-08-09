#!/usr/bin/env python3
"""Fix common Swift Testing syntax corruption from expect migration scripts."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def fix_unclosed_negated_expect(line: str) -> str:
    """#expect(!(expr) -> #expect(!(expr)) when missing one paren."""
    m = re.match(r"^(\s*)#expect\(!\((.+)\)\s*$", line)
    if not m:
        return line
    indent, expr = m.groups()
    if expr.count("(") == expr.count(")"):
        return f"{indent}#expect(!({expr}))"
    return line


def fix_array_expect_closing(content: str) -> str:
    """Fix #expect(x == ["a", "b") missing ] before final )."""
    return re.sub(
        r"(#expect\([^=]+== \[[^\]]*\"[^\"]+\")(\))",
        r"\1])",
        content,
    )


def fix_keys_sorted_expect(content: str) -> str:
    return re.sub(
        r"(#expect\([^=]+== \[[^\]]*\"[^\"]+\")(\))",
        r"\1])",
        content,
    )


def fix_truncated_map_title_expect(content: str) -> str:
    # Multi-line array literal ending with "Ready To Send") without ]
    return re.sub(
        r"(#expect\([^\n]+== \[\s*\n\s*\"[^\"]+\", \"[^\"]+\")(\))",
        r"\1])",
        content,
        flags=re.M,
    )


def fix_compliance_approval_tests(content: str) -> str:
    if "BillingHubComplianceApprovalPolicyTests" not in content:
        return content
    content = re.sub(
        r"#expect\(!\(BillingHubComplianceApprovalPolicy\.canApprove\(\s*"
        r"isBusy: false, hasBlockers: false,\s*checkCompleted: false\)\)",
        "#expect(!(BillingHubComplianceApprovalPolicy.canApprove(\n"
        "                isBusy: false, hasBlockers: false,\n"
        "                checkCompleted: false)))",
        content,
    )
    content = re.sub(
        r"#expect\(!\(BillingHubComplianceApprovalPolicy\.canApprove\(\s*"
        r"isBusy: false, hasBlockers: true,\s*checkCompleted: true\)\)",
        "#expect(!(BillingHubComplianceApprovalPolicy.canApprove(\n"
        "                isBusy: false, hasBlockers: true,\n"
        "                checkCompleted: true)))",
        content,
    )
    # Third test has nested expects - fix manually if still broken
    return content


def fix_throws_expect(content: str) -> str:
    """Fix #expect(throws:...) { ... } missing closing parens."""
    return re.sub(
        r"#expect\(throws: \(any Error\)\.self\) \{ try InvoicePDFFileWriter\.write\(source: missingSource, to: destination \}\s*\)",
        "#expect(throws: (any Error).self) { try InvoicePDFFileWriter.write(source: missingSource, to: destination) }",
        content,
    )


def fix_missing_closing_parens_on_init(content: str) -> str:
    """Fix NDISBillingInputVector / makeInputVector truncated inits."""
    patterns = [
        (
            r"(location: NDISLocation\(postcode: \"2000\"\))\s*\n(\s*\})",
            r"\1)\n        )\n\2",
        ),
        (
            r"(location: NDISLocation\(postcode: \"\"\))\s*\n(\s*#expect)",
            r"\1))\n        )\n\2",
        ),
    ]
    for pat, repl in patterns:
        content = re.sub(pat, repl, content)
    return content


def fix_relationship_deletion_tests(content: str) -> str:
    if "RelationshipDeletionTests" not in content:
        return content
    if "catch {" not in content:
        return content

    content = re.sub(
        r"\n\s*var modelContext: ModelContext!\s*\n\s*var modelContainer: ModelContainer!\s*\n\s*catch \{[^}]+\}\s*\n\s*\}\s*\n",
        "\n",
        content,
        flags=re.S,
    )

    def inject_setup(match: re.Match[str]) -> str:
        indent = match.group(1)
        rest = match.group(2)
        setup = (
            f"{indent}let (modelContainer, modelContext) = "
            f"try ModelContainerFactory.makeInMemoryContext()\n"
        )
        return f"{match.group(0).split('{')[0]}{{\n{setup}{rest}"

    content = re.sub(
        r"(\n\s*@Test func \w+[^{]*\{)(\n)",
        inject_setup,
        content,
    )
    return content


def process_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    content = original
    content = fix_array_expect_closing(content)
    content = fix_truncated_map_title_expect(content)
    content = fix_compliance_approval_tests(content)
    content = fix_throws_expect(content)
    content = fix_missing_closing_parens_on_init(content)
    content = fix_relationship_deletion_tests(content)

    lines = content.splitlines(keepends=True)
    content = "".join(fix_unclosed_negated_expect(l.rstrip("\n")) + l[-1:] if l.endswith("\n") else fix_unclosed_negated_expect(l) for l in lines)

    if content != original:
        path.write_text(content, encoding="utf-8")
        return True
    return False


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    changed = 0
    for path in sorted((root / "Packages").rglob("*Tests*.swift")):
        if process_file(path):
            changed += 1
            print(path.relative_to(root))
    print(f"fixed {changed} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
