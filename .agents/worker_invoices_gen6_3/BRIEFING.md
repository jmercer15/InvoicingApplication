# BRIEFING — 2026-06-10T13:28:30Z

## Mission
Migrate and standardize UI design tokens in Packages/Feature.Invoices to comply with PROJECT.md and design system requirements.

## 🔒 My Identity
- Archetype: teamwork_preview_worker
- Roles: implementer, qa, specialist
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_3
- Original parent: a3a568f0-65db-4530-8bf8-52dc57f25926
- Milestone: Invoices UI Standardisation

## 🔒 Key Constraints
- CODE_ONLY network mode. No external HTTP.
- No raw numeric literals for padding, corner-radius, or spacing inside Views (except where allowed/documented).
- No local custom Color calls or direct asset name lookups in views; all must use ColorSystem.
- Do not modify files in Packages/SharedUI unless token missing.
- Do not edit PDFKit templates or code inside InvoiceTemplateRendererView.

## Current Parent
- Conversation ID: a3a568f0-65db-4530-8bf8-52dc57f25926
- Updated: not yet

## Task Summary
- **What to build**: Refactor Packages/Feature.Invoices views (fonts, colors, spacing, section headers, panel shells) using StyleGuide and ColorSystem.
- **Success criteria**: Code compiles, tests pass, zero raw spacing/padding/color literals in Packages/Feature.Invoices views.
- **Interface contracts**: PROJECT.md, design system in SharedUI.
- **Code layout**: Packages/Feature.Invoices/Sources/Feature_Invoices/Views/

## Key Decisions Made
- [TBD]

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_3/original_prompt.md — Original task prompt
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_3/BRIEFING.md — My briefing
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_3/progress.md — My progress heartbeat
