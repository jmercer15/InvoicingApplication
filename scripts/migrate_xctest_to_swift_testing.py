#!/usr/bin/env python3
"""Mechanical XCTest → Swift Testing migration for Phase 5."""

from __future__ import annotations

import re
import sys
from pathlib import Path

SKIP_DIRS = {"BuildData", ".build", "SourcePackages"}

ASSERT_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"XCTAssertEqual\(\s*([^,]+?)\s*,\s*([^,)]+?)\s*,\s*accuracy:\s*([^)]+)\)"), r"#expect(\1 == \2) // was accuracy: \3"),
    (re.compile(r"XCTAssertEqual\(\s*([^,]+?)\s*,\s*([^)]+?)\)"), r"#expect(\1 == \2)"),
    (re.compile(r"XCTAssertNotEqual\(\s*([^,]+?)\s*,\s*([^)]+?)\)"), r"#expect(\1 != \2)"),
    (re.compile(r"XCTAssertNil\(\s*([^)]+?)\)"), r"#expect(\1 == nil)"),
    (re.compile(r"XCTAssertNotNil\(\s*([^)]+?)\)"), r"#expect(\1 != nil)"),
    (re.compile(r"XCTAssertTrue\(\s*([^)]+?)\)"), r"#expect(\1)"),
    (re.compile(r"XCTAssertFalse\(\s*([^)]+?)\)"), r"#expect(!(\1))"),
    (re.compile(r"XCTAssertGreaterThan\(\s*([^,]+?)\s*,\s*([^)]+?)\)"), r"#expect(\1 > \2)"),
    (re.compile(r"XCTAssertGreaterThanOrEqual\(\s*([^,]+?)\s*,\s*([^)]+?)\)"), r"#expect(\1 >= \2)"),
    (re.compile(r"XCTAssertLessThan\(\s*([^,]+?)\s*,\s*([^)]+?)\)"), r"#expect(\1 < \2)"),
    (re.compile(r"XCTAssertLessThanOrEqual\(\s*([^,]+?)\s*,\s*([^)]+?)\)"), r"#expect(\1 <= \2)"),
    (re.compile(r"XCTAssertThrowsError\(\s*try\s+([^)]+?)\)"), r"#expect(throws: (any Error).self) { try \1 }"),
    (re.compile(r"XCTFail\(\s*\"([^\"]*)\"\s*\)"), r'Issue.record("\1")'),
    (re.compile(r"XCTFail\(\)"), r"Issue.record()"),
    (re.compile(r"XCTUnwrap\(\s*([^)]+?)\s*\)"), r"try #require(\1)"),
    (re.compile(r"XCTSkip\(\s*\"([^\"]*)\"\s*\)"), r'throw Skip("\1")'),
    (re.compile(r"XCTSkip\(\)"), r"throw Skip()"),
]

SETUP_BLOCK = re.compile(
    r"\n\s*override func setUp(?:WithError|)\(\)(?: async)? throws \{.*?\n\s*\}\n",
    re.DOTALL,
)
TEARDOWN_BLOCK = re.compile(
    r"\n\s*override func tearDown(?:WithError|)\(\)(?: async)? throws \{.*?\n\s*\}\n",
    re.DOTALL,
)
CLASS_PATTERN = re.compile(
    r"(@MainActor\s+)?(?:public\s+|private\s+|internal\s+|fileprivate\s+)?final class (\w+): XCTestCase"
)
FUNC_PATTERN = re.compile(r"\n(\s*)func (test\w+)\(\)")


def infer_tag(content: str) -> str:
    integration_markers = [
        "ModelContainer",
        "ModelContext",
        "SwiftData",
        "makeInMemoryContext",
        "ViewModel",
        "async throws",
        "BillingHub",
        "EventKit",
        "importExport",
        "CloudKit",
    ]
    lower = content.lower()
    if any(m.lower() in lower for m in integration_markers):
        return ".integration"
    return ".unit"


def migrate_content(content: str, filepath: Path) -> str:
    if "import XCTest" not in content:
        return content

    # Preserve @MainActor from class onto struct
    main_actor = ""
    class_match = CLASS_PATTERN.search(content)
    if class_match and class_match.group(1):
        main_actor = "@MainActor\n"

    tag = infer_tag(content)

    content = content.replace("import XCTest", "import Testing")

    def replace_class(m: re.Match[str]) -> str:
        name = m.group(2)
        return f"{main_actor}@Suite(.tags({tag}))\nstruct {name}"

    content = CLASS_PATTERN.sub(replace_class, content)

    # Remove setUp/tearDown blocks (tests should use per-test helpers)
    content = SETUP_BLOCK.sub("\n", content)
    content = TEARDOWN_BLOCK.sub("\n", content)

    # func testFoo() -> @Test func foo()  (strip test prefix for cleaner names)
    def replace_test_func(m: re.Match[str]) -> str:
        indent, name = m.group(1), m.group(2)
        clean = name[4:] if name.startswith("test") else name
        clean = clean[0].lower() + clean[1:] if clean else name
        return f"\n{indent}@Test func {clean}()"

    content = FUNC_PATTERN.sub(replace_test_func, content)

    # func testFoo() async throws — handle async variant
    content = re.sub(
        r"\n(\s*)func (test\w+)\(\) async throws",
        lambda m: f"\n{m.group(1)}@Test func {m.group(2)[4:][0].lower() + m.group(2)[4:][1:] if m.group(2).startswith('test') else m.group(2)}() async throws",
        content,
    )
    content = re.sub(
        r"\n(\s*)func (test\w+)\(\) throws",
        lambda m: f"\n{m.group(1)}@Test func {m.group(2)[4:][0].lower() + m.group(2)[4:][1:] if m.group(2).startswith('test') else m.group(2)}() throws",
        content,
    )
    content = re.sub(
        r"\n(\s*)func (test\w+)\(\) async",
        lambda m: f"\n{m.group(1)}@Test func {m.group(2)[4:][0].lower() + m.group(2)[4:][1:] if m.group(2).startswith('test') else m.group(2)}() async",
        content,
    )

    for pattern, repl in ASSERT_PATTERNS:
        content = pattern.sub(repl, content)

    # Remove leftover private var modelContext/modelContainer from setUp if unused at class level
    content = re.sub(r"\n\s*private var modelContext: ModelContext!\n", "\n", content)
    content = re.sub(r"\n\s*private var modelContainer: ModelContainer!\n", "\n", content)

    # Add makeContext helper for Data integration tests missing one
    if "makeInMemoryContext" in content and "func makeContext()" not in content:
        if "@Suite" in content and "struct " in content:
            struct_match = re.search(r"struct \w+ \{", content)
            if struct_match:
                insert_at = struct_match.end()
                helper = """
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }
"""
                content = content[:insert_at] + helper + content[insert_at:]

    return content


def should_process(path: Path) -> bool:
    parts = set(path.parts)
    if parts & SKIP_DIRS:
        return False
    if "_deferred_phase5" in path.parts:
        return True
    return path.suffix == ".swift" and "Packages" in path.parts


def main(root: Path) -> int:
    migrated = 0
    for path in sorted(root.rglob("*.swift")):
        if not should_process(path):
            continue
        original = path.read_text(encoding="utf-8")
        if "import XCTest" not in original:
            continue
        updated = migrate_content(original, path)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            migrated += 1
            print(f"migrated: {path.relative_to(root)}")
    print(f"\nTotal migrated: {migrated}")
    return 0


if __name__ == "__main__":
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    raise SystemExit(main(root))
