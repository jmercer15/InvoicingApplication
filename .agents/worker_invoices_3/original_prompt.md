# Task Description: Feature.Invoices Token Migration

You are the Feature.Invoices Implementer worker.
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_3`.
Your identity is `teamwork_preview_worker`.
Your mission is to migrate and standardize UI design tokens in `Packages/Feature.Invoices`.

## References & Guidance
- Read the Explorer's findings in:
  `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_invoices_3_3/handoff.md`
- Keep `.cursor/rules/` (e.g. `swiftui/visual-components.mdc`, `swiftui/layout-system.mdc`) as the scoped rule source of truth.

## Key Constraints
- CODE_ONLY network mode.
- Do not modify files in `Packages/SharedUI` unless a missing token needs to be added.
- Do not edit PDFKit templates or code inside `InvoiceTemplateRendererView.swift`.
- No raw numeric literals for padding, corner-radius, or spacing inside `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/` (except where they are logical values like hash seed, OS version, or double constants).
- No local custom Color calls or direct asset name lookups in views; all must use `ColorSystem`.
- Rebuild section headers to use `DetailSectionHeader` where appropriate.
- Enforce Panel Shells by attaching `.standardPanelShell(role: .detailPanel)` in `InvoicesDetailColumn` at the root view level.

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Completion Criteria
1. Run the build command and test command for Feature.Invoices:
   `swift test --package-path Packages/Feature.Invoices`
2. Ensure everything compiles and all tests pass with exit code 0.
3. Write a completion handoff report to `handoff.md` in your working directory.

## 2026-06-10T13:28:24Z
Please migrate design tokens in `Packages/Feature.Invoices` to adopt unified typography, spacing, colors, and panel shells:
- Follow instructions and findings in `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_invoices_3_3/handoff.md`.
- Replace raw numeric values for padding and spacing with `StyleGuide.Dimensions` tokens.
- Replace custom fonts and colors with `StyleGuide.Typography` and `ColorSystem` tokens.
- Apply `.standardPanelShell(role: .detailPanel)` in `InvoicesDetailColumn.swift` and use `DetailSectionHeader` for section headers.
- Verify that both `xcodebuild` and `swift test` succeed.
- Write your handoff report to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_3/handoff.md`.
