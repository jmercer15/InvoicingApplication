## 2026-06-11T01:11:51Z
Please implement the design token standardization and layout improvements for `Feature.Invoices` based on the explorer findings.
Refer to these reports:
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_invoices_1_gen9/analysis.md` (Style token replacements in InvoicesView.swift)
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_invoices_2_gen9/analysis.md` (Layout & panel unification in InvoicesDetailColumn.swift, InvoiceInspectorFormView.swift, and AppShell's SmartInspectorResolverView.swift)
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_invoices_3_gen9/analysis.md` (Typography and component check)

Specifically:
1. In `InvoicesView.swift`, perform style token replacements (magic number 0.2 to StyleGuide duration token, `.cornerRadius`, `.foregroundColor`, padding alignment for action buttons).
2. Refactor `InvoiceEditorFormContent` in `InvoiceInspectorFormView.swift` from a monolithic `Form` into a card-based layout using `DetailCardsLayout` and modular `GroupBox` components (matching Feature.Clients and Feature.NDIS style).
3. Implement container-level panel shell unification:
   - Remove local `.standardPanelShell(role: .detailPanel)` and `.standardPanelTransition()` from `InvoicesDetailColumn.swift`.
   - Remove local `.standardPanelShell(role: .detailPanel)` from ClientDetailView/PayeeDetailView/PlanManagerDetailView in `Feature.Clients` if they duplicate container-level shells.
   - Add `.standardPanelShell(role: .detailPanel)` to the container in `SmartInspectorResolverView.swift` so the inspector details get styled properly for all features including NDIS Catalogue.
4. Verify the changes by compiling and running tests:
   - Run `swift test --package-path Packages/Feature.Invoices`
   - Run `bash scripts/refactor-verify.sh`

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Please report your progress in `progress.md` and write a detailed handoff in `handoff.md` in your working directory.
