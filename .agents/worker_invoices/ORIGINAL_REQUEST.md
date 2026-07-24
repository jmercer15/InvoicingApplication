## 2026-07-24T10:08:04Z
You are teamwork_preview_worker working in directory /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices.

Your assignment is to implement Milestone 2: Feature.Invoices Capability Enhancements in `Packages/Feature.Invoices`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Requirements to implement:
1. Revenue & Status Analytics Summary:
   - Create `InvoiceAnalyticsEngine` (`Models/InvoiceAnalyticsEngine.swift`) to compute `RevenueAnalyticsSummary` containing metrics (Total Billed, Total Received, Outstanding/Overdue, Draft count) broken down by currency code.
   - Exclude voided/cancelled invoices from billed/outstanding metrics.
   - Integrate into `InvoicesContainerViewModel` so it updates whenever projection changes.
   - Create SwiftUI view `RevenueAnalyticsSummaryView` and place it in `InvoicesView` list header area or `listContextBar`.
2. Invoice Duplication Workflow:
   - Add `InvoiceNumberGenerator.nextInvoiceNumber(from:existingNumbers:)` to parse and auto-increment numeric suffixes (e.g., `INV-1042` -> `INV-1043`).
   - Add `duplicateInvoice(_ sourceInvoice:)` on `InvoicesContainerViewModel` to deep-clone invoice, line items, and entity snapshots, set `date` to today, reset status to `reviewDraft`, insert into ModelContext, save, and select/reveal the new invoice.
   - Wire "Duplicate Invoice" action into context menus and toolbar in `InvoicesView`.
3. Batch Data Export:
   - Create `InvoiceDataExporter` (`Services/InvoiceDataExporter.swift`) supporting RFC 4180 CSV formatting (with proper comma/quote escaping) and ISO-8601 JSON formatting.
   - Expand `InvoicesView` multi-select toolbar and menu actions to support batch export to CSV and JSON via `NSSavePanel` / `NSOpenPanel`.
4. Comprehensive Unit Tests:
   - Add unit tests in `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/` for analytics calculation (multi-currency, status exclusions, overdue logic), invoice auto-incrementing/cloning, and CSV/JSON export.
   - Ensure all existing unit tests in `Feature.Invoices` remain 100% green.

Run `swift test --package-path Packages/Feature.Invoices` to verify build and tests pass cleanly. Document build/test commands and output in your handoff report `.agents/worker_invoices/handoff.md` and send a message to parent when finished.
