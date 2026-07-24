# BRIEFING — 2026-06-10T07:58:45Z

## Mission
Migrate and standardize UI design tokens in Packages/Feature.Invoices to satisfy PROJECT.md and the findings of the Explorers' handoff reports.

## 🔒 My Identity
- Archetype: teamwork_preview_worker
- Roles: implementer, qa, specialist
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_1
- Original parent: a3a568f0-65db-4530-8bf8-52dc57f25926
- Milestone: Migrate and standardize Invoices UI design tokens

## 🔒 Key Constraints
- CODE_ONLY network mode.
- DO NOT CHEAT. All implementations must be genuine.
- No raw numeric literals for padding, corner-radius, or spacing inside Packages/Feature.Invoices/Sources/Feature_Invoices/Views/ (except where allowed/documented).
- No local custom Color calls or direct asset name lookups in views; all must use ColorSystem.

## Current Parent
- Conversation ID: 4932e38a-3d91-43dc-8f93-36daaba43034
- Updated: 2026-06-10T07:59:15Z

## Task Summary
- **What to build**: Refactor Views in Feature.Invoices to use design tokens (ColorSystem, StyleGuide, PanelShellTokens, DetailSectionHeader, standardPanelShell).
- **Success criteria**: All spacing/padding/colors/fonts refactored to token systems; tests pass; clean macOS target build.
- **Interface contracts**: Packages/SharedUI/Sources/SharedUI/
- **Code layout**: Packages/Feature.Invoices/Sources/Feature_Invoices/Views/

## Key Decisions Made
- [TBD]

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_1/original_prompt.md — Original prompt
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_1/progress.md — Progress tracker
