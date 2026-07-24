# Master Plan: InvoicingApplication Polish & Accessibility

## Objective
Implement polish, accessibility features, keyboard shortcuts, VoiceOver announcements, input validations, and test coverage across `Feature.Invoices` and `Feature.InvoiceTemplateEditor`, verifying all 4 acceptance criteria pass cleanly.

## Milestones

### Milestone 1: Exploration & Requirement Analysis
- **Goal**: Explore codebase for `Feature.Invoices` and `Feature.InvoiceTemplateEditor` to map exact files, existing views, state management, VoiceOver implementations, and existing unit tests.
- **Workers**: 3 Explorers (`explorer_1`, `explorer_2`, `explorer_3`).
- **Deliverables**: Detailed exploration report in `.agents/explorer_1/analysis.md`, `.agents/explorer_2/analysis.md`, `.agents/explorer_3/analysis.md`.

### Milestone 2: Feature.Invoices Polish & Accessibility (R1)
- **Goal**: Implement R1 requirements in `Packages/Feature.Invoices`:
  1. Empty state matching feedback with active filter summaries and quick filter clear button.
  2. Keyboard shortcuts (`Cmd+Delete`) for batch deletion and clean selection reconciliation.
  3. VoiceOver announcements for filter changes and multi-selection counts.
- **Workers**: Explorer -> Worker -> Reviewer -> Challenger -> Forensic Auditor.

### Milestone 3: Feature.InvoiceTemplateEditor Polish & Accessibility (R2)
- **Goal**: Implement R2 requirements in `Packages/Feature.InvoiceTemplateEditor`:
  1. Page navigation keyboard shortcuts (`Page Up` / `Page Down` / `Home` / `End`) and VoiceOver announcements in document preview.
  2. Persistent save-failure recovery banner accessibility and focus management.
  3. Input validation and error feedback in validated decimal fields.
- **Workers**: Explorer -> Worker -> Reviewer -> Challenger -> Forensic Auditor.

### Milestone 4: Test Coverage & Verification (R3)
- **Goal**: Implement R3 unit test regressions and run verification commands:
  1. `swift test --package-path Packages/Feature.Invoices`
  2. `swift test --package-path Packages/Feature.InvoiceTemplateEditor`
  3. `xcodebuild test -scheme InvoicingApplication -destination 'platform=macOS'`
  4. `./scripts/architecture-check.sh`
- **Workers**: Worker -> Reviewer -> Challenger.

### Milestone 5: Final Integrity Audit & Synthesis
- **Goal**: Forensic Auditor integrity verification, final synthesis report, writing `handoff.md`, and completion notification.

## Verification Gate Criteria
- 100% test pass on all 3 test suites.
- Architecture check passes without violations.
- Forensic Auditor verdict is CLEAN.
