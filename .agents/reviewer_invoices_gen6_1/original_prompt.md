## 2026-06-11T01:12:13Z
You are teamwork_preview_reviewer (identity: reviewer_invoices_gen6_1).
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/reviewer_invoices_gen6_1`.

Your task is to review and verify the token unification and layout standardisation in `Packages/Feature.Invoices` to ensure it satisfies all acceptance criteria in `PROJECT.md`.

### Verification Steps:
1. **Analyze Design Token Compliance**:
   - Inspect files under `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/` to ensure all padding, corner radius, fonts, and colors are mapped to design tokens (`StyleGuide`, `ColorSystem`, `PanelShellTokens`).
   - Specifically verify that the custom section headers in `InvoiceInspectorFormView` and `InvoiceLineItemsSection` are replaced with `DetailSectionHeader` from `SharedUI`.
   - Verify that `InvoicesDetailColumn` uses `.standardPanelShell(role: .detailPanel)` at its root view level.
2. **Execute Build and Test commands**:
   - Verify the package compiles cleanly and passes all tests: `swift test --package-path Packages/Feature.Invoices`
   - Run the global verification script: `bash scripts/refactor-verify.sh`
   - Document any compilation warnings/errors or test failures.
3. **Write Handoff Report**:
   - Write your review findings and verification log to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/reviewer_invoices_gen6_1/handoff.md`. Include exact commands executed and their output.

### MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
