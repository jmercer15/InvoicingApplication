# plan.md — Styling Cleanup

## Goal
Audit the InvoicingApplication codebase to remove unnecessary custom styling, such as non-native shadows, hover effects, and custom selection highlights, restoring standard macOS native UI behaviors.

## Verification Protocol
All milestones must be verified by a worker running compilation and test checks.
The final phase will undergo a Forensic Audit check via `teamwork_preview_auditor`.

## Milestones
- [ ] Milestone 1: Audit & Investigation
  - Identify specific files and lines with custom shadows, hover effects, and custom selection highlights.
- [ ] Milestone 2: Feature.NDIS Styling Cleanup
  - Remove unneeded custom shadows, hover effects, and selection styles from Feature.NDIS.
- [ ] Milestone 3: Feature.Clients Styling Cleanup
  - Remove unneeded custom shadows, hover effects, and selection styles from Feature.Clients.
- [ ] Milestone 4: Feature.Invoices Styling Cleanup
  - Remove unneeded custom shadows, hover effects, and selection styles from Feature.Invoices.
- [ ] Milestone 5: Feature.BillingHub & Feature.Calendar Styling Cleanup
  - Remove unneeded custom shadows, hover effects, and selection styles from Feature.BillingHub and Feature.Calendar.
- [ ] Milestone 6: Feature.InvoiceTemplateEditor & Feature.Settings Styling Cleanup
  - Remove unneeded custom shadows, hover effects, and selection styles from Feature.InvoiceTemplateEditor and Feature.Settings.
- [ ] Milestone 7: AppShell & SharedUI Styling Cleanup
  - Remove unneeded custom shadows, hover effects, and selection styles from AppShell and SharedUI.
- [ ] Milestone 8: Final Review & Acceptance Validation
  - Run all tests and builds. Verify that all custom styles are successfully removed and standard macOS native UI behaviors are restored.
