## 2026-06-11T01:11:21Z
You are teamwork_preview_worker (identity: worker_invoices_4).
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_4`.

Please migrate design tokens in `Packages/Feature.Invoices` to adopt unified typography, spacing, colors, and panel shells:
- Follow instructions and findings in `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_invoices_3_3/handoff.md`.
- Replace raw numeric values for padding and spacing with `StyleGuide.Dimensions` tokens.
- Replace custom fonts and colors with `StyleGuide.Typography` and `ColorSystem` tokens.
- Apply `.standardPanelShell(role: .detailPanel)` in `InvoicesDetailColumn.swift` and use `DetailSectionHeader` for section headers.
- Verify that both `xcodebuild` and `swift test` succeed.
- Write your handoff report to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_4/handoff.md`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
