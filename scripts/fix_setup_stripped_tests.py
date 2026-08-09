#!/usr/bin/env python3
"""Fix tests where setUp was stripped but instance vars remain."""

from __future__ import annotations

import re
import sys
from pathlib import Path

HARNESS_SETUP = '''
    private struct Harness {
        let container: ModelContainer
        let context: ModelContext
        let builder: BulkClaimBuilderActor

        init() throws {
            let (container, context) = try ModelContainerFactory.makeInMemoryContext()
            self.container = container
            self.context = context
            self.builder = BulkClaimBuilderActor(modelContainer: container)
        }
    }
'''

BILLING_HARNESS = '''
    private struct BillingHarness {
        let container: ModelContainer
        let context: ModelContext
        let configService: NDISBillingConfigService
        let billingService: NDISBillingService
        let integration: NDISBillingIntegrationService

        init(models: [any PersistentModel.Type]? = nil) throws {
            let (container, context): (ModelContainer, ModelContext)
            if let models {
                (container, context) = try ModelContainerFactory.makeInMemoryContext(models: models)
            } else {
                (container, context) = try ModelContainerFactory.makeInMemoryContext()
            }
            self.container = container
            self.context = context
            self.configService = NDISBillingConfigService(modelContext: context)
            self.billingService = NDISBillingService(modelContext: context, configService: configService)
            self.integration = NDISBillingIntegrationService(
                modelContainer: container,
                geocodingService: SwiftDataGeocodingService(),
                mmmZoneLookup: MMMZoneLookup()
            )
        }
    }
'''

NDIS_PRICE_MODELS = '''
    private struct PriceHarness {
        let container: ModelContainer
        let context: ModelContext

        init() throws {
            let models: [any PersistentModel.Type] = [
                NDISItem.self,
                RegionalPrice.self,
                ServiceAgreement.self,
                SupportLog.self,
                BulkClaimBatch.self,
                BulkClaimLine.self,
            ]
            let (container, context) = try ModelContainerFactory.makeInMemoryContext(models: models)
            self.container = container
            self.context = context
        }
    }
'''


def fix_bulk_claim_builder(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if "private struct Harness" in text:
        return
    text = text.replace("    private var builder: BulkClaimBuilderActor!\n\n", HARNESS_SETUP + "\n")
    text = text.replace("modelContext", "context")
    # restore helper param names - insert context param
    for fn in [
        "insertBusiness", "insertClient", "insertSession", "insertInvoice",
        "insertInvoiceItem", "insertSupportLog",
    ]:
        text = text.replace(f"private func {fn}(", f"private func {fn}(context: ModelContext, ")
    # fix makeBatch - no context
    text = text.replace("private func makeBatch(context: ModelContext, ", "private func makeBatch(")
    # each @Test gets harness
    def add_harness(m: re.Match[str]) -> str:
        indent = m.group(1)
        rest = m.group(2)
        if "let harness = try Harness()" in rest[:200]:
            return m.group(0)
        return f"{indent}@Test{rest}\n{indent}{{\\n{indent}    let harness = try Harness()"
    text = re.sub(
        r"(\s*)@Test func (\w+\(\)(?: async(?: throws)?)?)\s*\{",
        lambda m: f"{m.group(1)}@Test func {m.group(2)} {{\n{m.group(1)}    let harness = try Harness()\n{m.group(1)}    let context = harness.context\n{m.group(1)}    let builder = harness.builder",
        text,
    )
    # fix helper calls in tests - add context: context,
    for fn in [
        "insertBusiness", "insertClient", "insertSession", "insertInvoice",
        "insertInvoiceItem", "insertSupportLog",
    ]:
        text = re.sub(rf"try {fn}\(", f"try {fn}(context: context, ", text)
        text = re.sub(rf"= {fn}\(", f"= {fn}(context: context, ", text)
    path.write_text(text, encoding="utf-8")
    print(f"fixed bulk claim: {path}")


def fix_billing_file(path: Path, use_price_harness: bool = False) -> None:
    text = path.read_text(encoding="utf-8")
    harness_block = NDIS_PRICE_MODELS if use_price_harness else BILLING_HARNESS
    harness_name = "PriceHarness" if use_price_harness else "BillingHarness"

    if f"private struct {harness_name}" in text:
        # still fix syntax errors
        pass
    else:
        text = re.sub(
            r"\n\s*private var modelContainer: ModelContainer!\n\n+",
            "\n" + harness_block + "\n",
            text,
            count=1,
        )

    # Fix common migration syntax corruption
    fixes = [
        (r"hasAddressOrPostcode: true == mmmRating:", "hasAddressOrPostcode: true, mmmRating:"),
        (r"hasAddressOrPostcode: false == mmmRating:", "hasAddressOrPostcode: false, mmmRating:"),
        (r"calculateCentreCapitalCost\(context == nil\)", "calculateCentreCapitalCost(context) == nil"),
        (r"calculateEstablishmentFee\(context == nil\)", "calculateEstablishmentFee(context) == nil"),
        (r"\$0\.claimType\) == \"EstablishmentFee\"", "$0.claimType == \"EstablishmentFee\""),
        (r", accuracy: 0\.0001\)", ")"),
        (r"func test(\w+)\(\)", r"@Test func \1()"),
    ]
    for pat, repl in fixes:
        text = re.sub(pat, repl, text)

    # Replace bare billingService/configService/integration/modelContext with harness refs in tests
    if harness_name == "BillingHarness":
        if "let harness = try BillingHarness()" not in text:
            text = re.sub(
                r"(\s*)@Test func (\w+\(\)(?: async(?: throws)?)?)\s*\{",
                lambda m: (
                    f"{m.group(1)}@Test func {m.group(2)} {{\n"
                    f"{m.group(1)}    let harness = try BillingHarness()\n"
                    f"{m.group(1)}    let context = harness.context\n"
                    f"{m.group(1)}    let billingService = harness.billingService\n"
                    f"{m.group(1)}    let configService = harness.configService\n"
                    f"{m.group(1)}    let integration = harness.integration"
                ),
                text,
            )
            # tests without @Test
            text = re.sub(
                r"(\n    )@Test func (\w+\(\)(?: throws)?)\s*\{",
                lambda m: (
                    f"{m.group(1)}@Test func {m.group(2)} {{\n"
                    f"{m.group(1)}    let harness = try BillingHarness()\n"
                    f"{m.group(1)}    let billingService = harness.billingService\n"
                    f"{m.group(1)}    let configService = harness.configService"
                ),
                text,
            )

    if harness_name == "PriceHarness":
        text = text.replace("modelContext", "context")
        text = re.sub(
            r"private func createNDISItemWithPrices\(",
            "private func createNDISItemWithPrices(context: ModelContext, ",
            text,
        )
        text = re.sub(
            r"private func createNDISItemWithoutPrices\(",
            "private func createNDISItemWithoutPrices(context: ModelContext, ",
            text,
        )
        if "let harness = try PriceHarness()" not in text:
            text = re.sub(
                r"(\s*)@Test func (\w+\(\)(?: throws)?)\s*\{",
                lambda m: (
                    f"{m.group(1)}@Test func {m.group(2)} {{\n"
                    f"{m.group(1)}    let harness = try PriceHarness()\n"
                    f"{m.group(1)}    let context = harness.context"
                ),
                text,
            )
        text = re.sub(r"createNDISItemWithPrices\(", "createNDISItemWithPrices(context: context, ", text)
        text = re.sub(r"createNDISItemWithoutPrices\(", "createNDISItemWithoutPrices(context: context, ", text)

    path.write_text(text, encoding="utf-8")
    print(f"fixed billing: {path}")


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    fix_bulk_claim_builder(root / "Packages/Data/Tests/DataTests/UseCases/BulkClaimBuilderServiceTests.swift")
    for name in [
        "NDISGeoAndTimeModifierTests.swift",
        "NDISEstablishmentFeeGatingTests.swift",
        "NDISActivityTravelTests.swift",
    ]:
        fix_billing_file(root / f"Packages/Data/Tests/DataTests/BusinessLogic/{name}")
    fix_billing_file(root / "Packages/Data/Tests/DataTests/BusinessLogic/NDISPriceHandlingTests.swift", use_price_harness=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
