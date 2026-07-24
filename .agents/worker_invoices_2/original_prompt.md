## 2026-06-10T06:11:00Z
You are teamwork_preview_worker (identity: worker_invoices_2).
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_2`.

Your task is to migrate and standardize UI design tokens in `Packages/Feature.Invoices` to satisfy the requirements in `PROJECT.md` and the findings of the Explorer's handoff report.

### Input Context:
- Explorer's Handoff Report: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_invoices_3_3/handoff.md`
- Project Plan: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/PROJECT.md`
- Spacing, typography, and color tokens defined in `Packages/SharedUI/Sources/SharedUI/` (e.g. `StyleGuide`, `ColorSystem`, `PanelShellTokens`).

### Objective & Instructions:
1. **Refactor Fonts & Colors in Feature.Invoices Views**:
   - Replace standard font styles (e.g., `.font(.caption)`, `.font(.headline)`) with appropriate `StyleGuide.Typography` tokens.
   - Replace hardcoded colors (e.g., `Color("White", bundle: .sharedUI)`, `Color("Gray20", bundle: .sharedUI)`, `"Red70"`, `"Blue70"`, `Color.accentColor`) with approved colors from `ColorSystem` or `StyleGuide.Colors`.
2. **Refactor Spacing & Padding**:
   - Replace raw spacing and padding values (e.g. `.padding(.horizontal, 12)`, `HStack(spacing: 8)`) with `StyleGuide.Dimensions` tokens.
3. **Rebuild Section Headers**:
   - Migrate custom section headers in `InvoiceInspectorFormView` and `InvoiceLineItemsSection` to use the reusable `DetailSectionHeader` from `SharedUI`.
4. **Enforce Panel Shells**:
   - Apply `.standardPanelShell(role: .detailPanel)` at the root view level in `InvoicesDetailColumn.swift` (and apply standard content padding/modifiers from `PanelShellTokens`).
5. **Verify Build & Test Integrity**:
   - Ensure the project builds cleanly: `xcodebuild -scheme InvoicingApplication -destination 'platform=macOS'` (or similar command).
   - Ensure package/app tests pass: `swift test --package-path Packages/Feature.Invoices`.

### Scope Boundaries:
- Do not modify files in `Packages/SharedUI` unless a missing token needs to be added (highly unlikely).
- Do not edit PDFKit templates or code inside `InvoiceTemplateRendererView` as they are bound by PDF generation requirements.

### Completion Criteria:
- No raw numeric literals for padding, corner-radius, or spacing inside `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`.
- No local custom Color calls or direct asset name lookups in views; all must use `ColorSystem`.
- Write your handoff report to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_2/handoff.md` containing the list of modified files, code changes summary, and output/logs of passing build and test commands.

### MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
