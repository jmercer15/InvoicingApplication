# Original User Request

## 2026-07-24T06:15:23Z

Continue improving and polishing both the Invoices feature (Packages/Feature.Invoices) and Invoice Template Editor feature (Packages/Feature.InvoiceTemplateEditor).

Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication
Integrity mode: development

## Requirements

### R1. Feature.Invoices Polish & Accessibility
- Enhance empty state matching feedback with active filter summaries and quick filter clear button.
- Add keyboard shortcuts (`Cmd+Delete`) for batch deletion and clean selection reconciliation.
- Ensure VoiceOver announcements for filter changes and multi-selection counts.

### R2. Feature.InvoiceTemplateEditor Polish & Accessibility
- Add page navigation keyboard shortcuts (`Page Up` / `Page Down` / `Home` / `End`) and VoiceOver announcements in document preview.
- Enhance persistent save-failure recovery banner accessibility and focus management.
- Provide input validation and error feedback in validated decimal fields.

### R3. Comprehensive Test Verification
- Ensure all existing unit tests in `Feature.Invoices` and `Feature.InvoiceTemplateEditor` remain 100% green.
- Add regression test coverage for new zero-state filter summaries, keyboard shortcuts, and preview page navigation.

## Acceptance Criteria

### Automated Tests & Quality
- [ ] `swift test --package-path Packages/Feature.Invoices` passes with 0 failures
- [ ] `swift test --package-path Packages/Feature.InvoiceTemplateEditor` passes with 0 failures
- [ ] `xcodebuild test -scheme InvoicingApplication -destination 'platform=macOS'` passes with 0 failures
- [ ] `./scripts/architecture-check.sh` passes without architectural violations

## Follow-up — 2026-07-24T10:05:51Z

Expand and enhance core functionality and capabilities of both Invoices (Packages/Feature.Invoices) and Invoice Template Editor (Packages/Feature.InvoiceTemplateEditor).

Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication
Integrity mode: development

## Requirements

### R1. Feature.Invoices Capability Enhancements
- Revenue & Status Analytics Summary: Provide high-level metrics cards (Total Billed, Total Received, Outstanding/Overdue, Draft count) broken down by currency.
- Invoice Duplication Workflow: Add action to duplicate/clone selected invoice with auto-incremented invoice number and refreshed dates.
- Batch Data Export: Support exporting invoice summary projections to CSV or JSON formats.

### R2. Feature.InvoiceTemplateEditor Capability Enhancements
- Template Preset Management: Support loading and saving custom visual layout presets (margins, font scale, accent color, header layout).
- Brand Accent & Logo Customization: Provide controls for primary accent colors and header branding layout.
- Page Margin & Pagination Controls: Add interactive page margin adjustments and pagination breakpoint markers in document preview.

### R3. Comprehensive Verification & Testing
- Add unit test coverage for revenue analytics calculations, invoice cloning, export generation, and template preset serialization.
- Ensure all existing unit tests in `Feature.Invoices` and `Feature.InvoiceTemplateEditor` remain 100% green.
- Verify `xcodebuild test` and `./scripts/architecture-check.sh` pass cleanly.

## Acceptance Criteria

### Automated Tests & Quality
- [ ] `swift test --package-path Packages/Feature.Invoices` passes with 0 failures
- [ ] `swift test --package-path Packages/Feature.InvoiceTemplateEditor` passes with 0 failures
- [ ] `xcodebuild test -scheme InvoicingApplication -destination 'platform=macOS'` passes with 0 failures
- [ ] `./scripts/architecture-check.sh` passes with 0 violations

## 2026-08-10T03:58:18Z

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview

Map out the current architecture of the codebase and identify concrete opportunities for streamlining and consolidation to produce an actionable refactor plan for production.

Working directory: ~/teamwork_projects/architecture_refactor_plan
Integrity mode: benchmark

## Verification Resources
- Existing test suites and evaluation scripts within the codebase. Use these to understand current behavior and ensure proposed architectural changes do not violate expected behavior.

## Requirements

### R1. Comprehensive Architecture Analysis
Analyze the current codebase to identify architectural bottlenecks, overly complex data flows, duplicated code, and disorganized file structures.

### R2. Actionable Refactor Plan
Produce a detailed markdown document that outlines specific refactoring steps. The plan must include explicit file paths, proposed structural changes, and strategies for deduplication and consolidation.

## Acceptance Criteria

### Analysis Quality
- [ ] The analysis covers both macro-level architecture (data flow, component boundaries) and micro-level issues (code duplication, file organization).
- [ ] At least three concrete areas for consolidation or deduplication are identified.

### Plan Actionability
- [ ] The refactor plan is presented as a markdown file.
- [ ] Every proposed change includes the specific file paths involved.
- [ ] The plan clearly distinguishes between structural changes, file reorganizations, and code deduplication.

## 2026-08-12T20:59:17Z

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview

Implement the entire refactoring plan outlined in `REFACTOR_PLAN.md` to improve the application's architecture, including macro-architecture fixes, file decompositions, and code deduplication.

Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication
Integrity mode: development

## Verification Resources
- `xcodebuild test` for unit and UI tests
- `refactor-verify.sh` and `architecture-check.sh` scripts in the repository

## Requirements

### R1. Complete Implementation of REFACTOR_PLAN.md
Execute all refactoring tasks outlined in the `REFACTOR_PLAN.md` file. This includes fixing `@State` initialization hazards, splitting the 4 mapped bloated files, and completing the 4 specified deduplications in `SharedUI` and `Core`.

### R2. Maintain Existing Functionality
The implementation must not break existing features. The app must continue to function exactly as before, with changes restricted to structural and architectural improvements.

## Acceptance Criteria

### Verification Passing
- [ ] `xcodebuild test` passes with a 100% success rate.
- [ ] `refactor-verify.sh` runs and completes successfully.
- [ ] `architecture-check.sh` runs with no new violations.

### Refactoring Completeness
- [ ] The bloated files identified in the plan have been successfully split.
- [ ] Code duplication in `SharedUI` and `Core` has been consolidated as per the plan.



