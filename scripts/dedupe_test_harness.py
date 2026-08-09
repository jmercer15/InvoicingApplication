#!/usr/bin/env python3
"""Deduplicate harness boilerplate inserted twice per test."""

import re
import sys
from pathlib import Path

HARNESS_BLOCK = re.compile(
    r"(?:\s*let harness = try BillingHarness\(\)\s*"
    r"(?:\s*let (?:context|billingService|configService|integration) = harness\.\w+\s*)+)+",
    re.MULTILINE,
)

SINGLE_BLOCK = """
        let harness = try BillingHarness()
        let context = harness.context
        let billingService = harness.billingService
        let configService = harness.configService
        let integration = harness.integration
"""


def dedupe_harness(text: str) -> str:
    def replacer(match: re.Match[str]) -> str:
        return SINGLE_BLOCK

    return HARNESS_BLOCK.sub(replacer, text)


def add_throws_to_tests(text: str) -> str:
    return re.sub(
        r"@Test func (\w+)\(\) \{",
        r"@Test func \1() throws {",
        text,
    )


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    for rel in [
        "Packages/Data/Tests/DataTests/BusinessLogic/NDISGeoAndTimeModifierTests.swift",
        "Packages/Data/Tests/DataTests/BusinessLogic/NDISEstablishmentFeeGatingTests.swift",
        "Packages/Data/Tests/DataTests/BusinessLogic/NDISActivityTravelTests.swift",
    ]:
        path = root / rel
        text = path.read_text(encoding="utf-8")
        text = dedupe_harness(text)
        text = add_throws_to_tests(text)
        # async tests already have throws
        text = text.replace("@Test func ", "@Test func ")
        path.write_text(text, encoding="utf-8")
        print(f"deduped: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
