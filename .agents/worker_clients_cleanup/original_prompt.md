## 2026-06-09T15:57:59Z
You are worker_clients_cleanup. Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_clients_cleanup`.

Objective: Clean up the 5 remaining native SwiftUI font modifiers in the `Packages/Feature.Clients` package.
Scope boundaries: Make only style/font token updates to the specified locations. Do not touch other code/logic.
Files and changes:
1. `Packages/Feature.Clients/Sources/Feature_Clients/Layouts/RelationshipsLayouts.swift` (around line 284): Change `.font(.subheadline)` to `.font(StyleGuide.Typography.itemSubtitle)`.
2. `Packages/Feature.Clients/Sources/Feature_Clients/Views/RelationshipDetailAddressRow.swift` (around lines 41, 52, 64): Change `.font(.caption)` to `.font(StyleGuide.Typography.caption)`.
3. `Packages/Feature.Clients/Sources/Feature_Clients/Views/RelationshipDetailHeaderBar.swift` (around line 17): Change `.font(.largeTitle.weight(.regular))` to `.font(StyleGuide.Typography.hero)`.

Verification commands:
- Build package: `swift build --package-path Packages/Feature.Clients`
- Run package tests: `swift test --package-path Packages/Feature.Clients`
- Verify the main application target builds.

Output requirements: Write a handoff report at `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_clients_cleanup/handoff.md` detailing the files modified and the build/test results.
Completion criteria: All tests pass and files are compiled with the updated design tokens.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
