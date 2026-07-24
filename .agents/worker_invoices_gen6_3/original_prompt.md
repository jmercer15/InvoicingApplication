## 2026-06-10T13:28:24Z
You are teamwork_preview_worker (identity: worker_invoices_gen6_3).
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_3`.

Your task is to migrate and standardize UI design tokens in `Packages/Feature.Invoices` to satisfy the requirements in `PROJECT.md` and the findings of the Explorers' handoff reports.

### Input Context:
- Explorer's Handoff Report 1: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_invoices_3_3/handoff.md`
- Explorer's Handoff Report 2: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_invoices_3_1/handoff.md`
- Project Plan: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/PROJECT.md`
- Design tokens defined in `Packages/SharedUI/Sources/SharedUI/` (e.g. `StyleGuide`, `ColorSystem`, `PanelShellTokens`, `PanelShellModifiers.swift`).

### Objective & Instructions:
1. **Refactor Fonts & Colors in Feature.Invoices Views**:
   - Replace standard font styles (e.g., `.font(.caption)`, `.font(.headline)`) with appropriate `StyleGuide.Typography` tokens (e.g. `StyleGuide.Typography.itemTitle`, `StyleGuide.Typography.caption`, `StyleGuide.Typography.itemSubtitle`).
   - Replace hardcoded colors (e.g., `Color("White", bundle: .sharedUI)`, `Color("Gray20", bundle: .sharedUI)`, `Color("Red70", bundle: .sharedUI)`, `Color("Blue70", bundle: .sharedUI)`, `Color.accentColor`, `Color(NSColor.controlBackgroundColor)`) with approved colors from `ColorSystem` (e.g. `ColorSystem.Neutral.white`, `ColorSystem.Status.error`, `ColorSystem.Primary.blue`) or `StyleGuide.Colors.secondary` / `PanelShellTokens.panelSecondaryBackground`.
2. **Refactor Spacing & Padding**:
   - Replace raw spacing and padding values (e.g. `.padding(.horizontal, 12)`, `.padding(.vertical, 6)`, `HStack(spacing: 8)`) with `StyleGuide.Dimensions` tokens.
3. **Rebuild Section Headers**:
   - Migrate custom section headers in `InvoiceInspectorFormView` and `InvoiceLineItemsSection` to use the reusable `DetailSectionHeader` from `SharedUI`.
4. **Enforce Panel Shells**:
   - Apply `.standardPanelShell(role: .detailPanel)` at the root view level in `InvoicesDetailColumn.swift` (and apply standard content padding/modifiers from `PanelShellTokens`).
5. **Verify Build & Test Integrity**:
   - Ensure the project builds cleanly: `xcodebuild -scheme InvoicingApplication -destination 'platform=macOS'` or `swift build -p Packages/Feature.Invoices`.
   - Ensure package/app tests pass: `swift test --package-path Packages/Feature.Invoices` or using `scripts/refactor-verify.sh`.

### Scope Boundaries:
- Do not modify files in `Packages/SharedUI` unless a missing token needs to be added (highly unlikely).
- Do not edit PDFKit templates or code inside `InvoiceTemplateRendererView` as they are bound by PDF generation requirements.

### Completion Criteria:
- No raw numeric literals for padding, corner-radius, or spacing inside `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/` (except where specifically allowed/documented).
- No local custom Color calls or direct asset name lookups in views; all must use `ColorSystem`.
- Write your handoff report to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_3/handoff.md` containing the list of modified files, code changes summary, and output/logs of passing build and test commands.
