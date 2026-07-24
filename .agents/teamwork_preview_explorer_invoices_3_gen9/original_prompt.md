## 2026-06-11T01:05:36Z
Analyze the `Feature.Invoices` views (under `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`) to identify typography issues and component unification opportunities, and propose a fix strategy.
Specifically:
1. Scan for raw `.font(.system(size:...))` or similar calls that bypass typography tokens.
2. Scan for custom localized components (e.g. badges, form fields, headers) that should be replaced with `SharedUI` components (`StatusBadge`, `FormField`, `EnhancedGroupBoxStyle`, `SidebarItemRow`).
Read PROJECT.md at the workspace root for guidelines. Write your findings to `analysis.md` in your working directory and summarize them.
