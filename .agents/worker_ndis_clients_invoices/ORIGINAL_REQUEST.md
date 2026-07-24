## 2026-06-12T05:51:08Z
You are teamwork_preview_worker. Your working directory is /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_ndis_clients_invoices.
Your task is:
1. Initialize your BRIEFING.md and progress.md in your working directory.
2. Address styling violations in Feature.NDIS and Feature.Clients, specifically:
   - Identify and replace all hardcoded/raw `.animation` duration and spring properties with corresponding tokens from `StyleGuide.Animations` (e.g. `StyleGuide.Animations.durationShort`, `StyleGuide.Animations.durationMedium`, `StyleGuide.Animations.durationLong`, `StyleGuide.Animations.springResponse`, `StyleGuide.Animations.springDamping`).
   - Specifically fix files:
     - `NDISCatalogueNavigationView.swift`
     - `NDISDetailCards.swift`
     - `ClientDetailBillingInfoCard.swift`
     - `ClientDetailClientInformationCard.swift`
     - Any other files in Feature.NDIS or Feature.Clients with raw animation definitions.
3. Verify that Feature.Invoices is fully clean.
4. Run tests for `Feature.NDIS`, `Feature.Clients`, and `Feature.Invoices` to ensure they compile and all tests pass with zero warnings/errors.
   - Use SPM test commands: `swift test --package-path Packages/Feature.NDIS` etc.
5. Create a structured report `handoff.md` in your working directory summarizing the changes made, files modified, and test results.
6. When done, send a message back with your findings.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
