# BRIEFING — 2026-06-10T23:32:00+10:00

## Mission
Standardize visual design system tokens in Packages/Feature.Invoices package views using design tokens defined in Packages/SharedUI.

## 🔒 My Identity
- Archetype: teamwork_preview_worker
- Roles: implementer, qa, specialist
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen3_1
- Original parent: 5605b009-141e-4813-8e31-fa7d9cf7e707
- Milestone: Invoices UI Standardisation

## 🔒 Key Constraints
- Avoid raw numeric literals for padding, corner-radius, or spacing. Use StyleGuide.Dimensions tokens.
- Avoid raw asset catalog color lookup strings. Use ColorSystem or StyleGuide.Colors.
- Avoid raw system semantic font size/system font modifiers. Use StyleGuide.Typography tokens.
- Keep other code structure and layout unchanged.
- Compile and verify changes with scripts/refactor-verify.sh.

## Current Parent
- Conversation ID: 5605b009-141e-4813-8e31-fa7d9cf7e707
- Updated: not yet

## Task Summary
- **What to build**: Standardize colors, fonts, spacing, padding, corner radii in Packages/Feature.Invoices views to use SharedUI StyleGuide / ColorSystem.
- **Success criteria**: Successful compilation, refactor-verify.sh execution passes, and code matches design tokens.
- **Interface contracts**: Packages/SharedUI StyleGuide API.
- **Code layout**: Packages/Feature.Invoices and Packages/SharedUI directories.

## Key Decisions Made
- Use replace_file_content or multi_replace_file_content for minimal edits.
- Ensure all token replacements map correctly to design guidelines.

## Artifact Index
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen3_1/changes.md` — List of file changes
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen3_1/handoff.md` — Forensic Handoff Report

## Change Tracker
- **Files modified**: None
- **Build status**: Untested
- **Pending issues**: None

## Quality Status
- **Build/test result**: Untested
- **Lint status**: Untested
- **Tests added/modified**: None

## Loaded Skills
- **Source**: None
- **Local copy**: None
- **Core methodology**: None
