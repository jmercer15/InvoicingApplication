# BRIEFING — 2026-06-11T11:12:00+10:00

## Mission
Standardize UI design tokens in `Packages/Feature.Invoices` to meet StyleGuide requirements.

## 🔒 My Identity
- Archetype: worker
- Roles: implementer, qa, specialist
- Working directory: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_4`
- Original parent: `a3a568f0-65db-4530-8bf8-52dc57f25926`
- Milestone: Design Token Standardization

## 🔒 Key Constraints
- CODE_ONLY network mode. No external HTTP.
- Do not modify files in Packages/SharedUI unless token is missing.
- Do not edit PDFKit templates/InvoiceTemplateRendererView.
- No raw numeric literals for padding, corner-radius, spacing inside Packages/Feature.Invoices/Sources/Feature_Invoices/Views/ (except allowed).
- No local custom Color calls or direct asset name lookups.

## Current Parent
- Conversation ID: `25e7b02e-f579-447a-b2c0-add2eb0d4e91`
- Updated: not yet

## Task Summary
- **What to build**: Migrate design tokens (fonts, colors, spacing, panel shells) in Feature.Invoices.
- **Success criteria**: Zero raw layout metrics, zero direct assets/hardcoded colors, detail panel shell applied.
- **Interface contracts**: `SharedUI` tokens.
- **Code layout**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`

## Key Decisions Made
- Setup BRIEFING.md.

## Artifact Index
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen6_4/handoff.md` — Final worker report.

## Change Tracker
- **Files modified**: None
- **Build status**: Untested
- **Pending issues**: None

## Quality Status
- **Build/test result**: Untested
- **Lint status**: Untested
- **Tests added/modified**: None

## Loaded Skills
- None
