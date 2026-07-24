## 2026-06-10T03:01:20Z
You are teamwork_preview_explorer (Explorer).
Your working directory is /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_invoices_1_gen1.
Your mission is to audit Packages/Feature.Invoices for UI token and component standardization compliance.
Please review the requirements in /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_gen3_5605b009/PROJECT.md and /Users/user/Developer/InvoicingApplication/InvoicingApplication/ORIGINAL_REQUEST.md.
Specifically:
1. Scan for raw numeric literals used for padding, corner-radius, or spacing within the Views/ directory of Packages/Feature.Invoices.
2. Scan for raw colors (Color(red:...), Color.blue, Color.red, hex codes, etc.) used in Views.
3. Scan for raw font sizes/system fonts (.font(.system(size:...))).
4. Check if standard components (StatusBadge, FormField, EnhancedGroupBoxStyle, SidebarItemRow) from SharedUI are used, or if custom ones are defined.
5. Check if standard panel shells (.standardPanelShell(role:)) are used for split views, panels, detail columns, sidebars.
6. Check if DetailCardsLayout is used for detail panels.
7. Check if there are raw column widths.

Write your findings to analysis.md and write a handoff.md in your working directory. Ensure you provide file paths, line numbers, and exact code snippets for every compliance gap found.
