# BRIEFING — 2026-06-10T07:58:38Z

## Mission
Migrate and standardize UI design tokens in `Packages/Feature.Invoices` to satisfy PROJECT.md and Explorer's handoff report.

## 🔒 My Identity
- Archetype: worker
- Roles: implementer, qa, specialist
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_3
- Original parent: 4932e38a-3d91-43dc-8f93-36daaba43034
- Milestone: UI design token migration and standardization in Feature.Invoices

## 🔒 Key Constraints
- CODE_ONLY network mode.
- Do not modify files in `Packages/SharedUI` unless a missing token needs to be added.
- Do not edit PDFKit templates or code inside `InvoiceTemplateRendererView.swift`.
- No raw numeric literals for padding, corner-radius, or spacing inside `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`.
- No local custom Color calls or direct asset name lookups in views; all must use `ColorSystem`.

## Current Parent
- Conversation ID: 4932e38a-3d91-43dc-8f93-36daaba43034
- Updated: not yet

## Task Summary
- **What to build**: Migration and standardization of UI design tokens in Feature.Invoices.
- **Success criteria**: No raw numeric literals for padding, corner-radius, or spacing in views; all colors/fonts standardized; custom headers replaced; panel shell applied; build/tests pass.
- **Interface contracts**: `PROJECT.md`, `Packages/SharedUI` API.
- **Code layout**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`.

## Key Decisions Made
- Initial spawn and configuration setup.

## Artifact Index
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_3/original_prompt.md` — Original agent instructions
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_3/BRIEFING.md` — Briefing document
