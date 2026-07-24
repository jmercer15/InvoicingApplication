## 2026-06-11T01:05:36Z
You are teamwork_preview_explorer.
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_invoices_1_gen9`.
Please analyze the `Feature.Invoices` views (under `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`) to identify styling violations and layout issues, and propose a fix strategy.
Specifically:
1. Scan for raw numeric padding calls (e.g. `.padding(16)`), raw spacing, and raw corner radii (e.g. `.cornerRadius(8)`).
2. Scan for hard-coded Color definitions or system hex code conversions not using ColorSystem.
3. Recommend how to replace them with `StyleGuide` and `ColorSystem` tokens.
Read PROJECT.md at the workspace root for guidelines. Write your findings to `analysis.md` in your working directory and summarize them.
