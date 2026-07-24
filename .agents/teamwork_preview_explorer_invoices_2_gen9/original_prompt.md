## 2026-06-11T01:05:36Z
You are teamwork_preview_explorer.
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_invoices_2_gen9`.
Please analyze the `Feature.Invoices` views (under `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`) to identify structural layout and panel shell issues, and propose a fix strategy.
Specifically:
1. Scan for missing panel shell adoption on outermost content/detail/sidebar views (should use `.standardPanelShell(role:)`, `.standardPanelContentPadding()`, or `.standardContentPanelListInsets()`).
2. Scan for column sizing using raw minWidth/width literals.
3. Scan for detail panels not using `DetailCardsLayout`.
Read PROJECT.md at the workspace root for guidelines. Write your findings to `analysis.md` in your working directory and summarize them.
