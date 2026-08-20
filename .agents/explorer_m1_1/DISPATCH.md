# DISPATCH — Explorer M1 (TestTags & DTOMacros)

## Objective
Investigate Milestone 1 items:
1. Removal of `Packages/DTOMacros` empty directory.
2. Centralizing `TestTags` into `Packages/Core/Sources/Core/Testing/TestTags.swift`. Check if `Core` or `CoreTests` exports `Tag` extensions (`@Tag static var unit: Self`, `@Tag static var integration: Self`) and if all test targets (`AppShellTests`, `DataTests`, `Feature_InvoicesTests`, etc.) can import `Core` or `CoreTesting` to access these tags.
3. Verify list of 13 duplicate `TestTags.swift` files across test targets.

## Relevant Paths
- `Packages/DTOMacros/`
- `Packages/Core/Sources/Core/`
- `REFACTOR_PLAN.md` Section 4 Area 4 & Section 2.3.1
- Original Request: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/ORIGINAL_REQUEST.md`

## Required Output
Write your findings and recommendations to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m1_1/handoff.md`.
