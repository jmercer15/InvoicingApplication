# BRIEFING — 2026-06-10T13:01:07+10:00

## Mission
Migrate and standardize UI design tokens in `Packages/Feature.Invoices` according to design token guidelines.

## 🔒 My Identity
- Archetype: implementer/qa/specialist
- Roles: implementer, qa, specialist
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_1
- Original parent: c5f37a78-afcd-41e6-a399-089c401e2094
- Milestone: UI Design Token Standardization

## 🔒 Key Constraints
- No raw numeric literals for padding, corner-radius, or spacing inside `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`.
- No local custom Color calls or direct asset name lookups in views; use ColorSystem.
- Do not modify files in Packages/SharedUI unless token needs to be added (unlikely).
- Do not edit PDFKit templates/InvoiceTemplateRendererView.
- Perform clean build/test.

## Current Parent
- Conversation ID: c5f37a78-afcd-41e6-a399-089c401e2094
- Updated: not yet

## Task Summary
- **What to build**: Design token migration in `Packages/Feature.Invoices`.
- **Success criteria**: Zero raw numeric spacing, padding, corner-radius. Section headers converted. Panel shell applied. Tests and builds pass.
- **Interface contracts**: PROJECT.md
- **Code layout**: Packages/Feature.Invoices/Sources/Feature_Invoices/Views/

## Key Decisions Made
- [TBD]

## Artifact Index
- [TBD]

## Change Tracker
- **Files modified**: [None yet]
- **Build status**: [TBD]
- **Pending issues**: [TBD]

## Quality Status
- **Build/test result**: [TBD]
- **Lint status**: [TBD]
- **Tests added/modified**: [TBD]

## Loaded Skills
- None
