# BRIEFING — 2026-06-05T12:42:00Z

## Mission
Plan remediation for SwiftData fetching issues and concurrency violations (Milestone 2) in InvoicingApplication.

## 🔒 My Identity
- Archetype: Explorer
- Roles: Read-only investigator, analyzer
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_fetching_1
- Original parent: 7609d953-24ad-485f-ab85-76cf8f2e9fc8
- Milestone: Milestone 2 (Data-Fetching & Concurrency Remediation Plan)

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Analyze specifically the 10 target files
- Focus on eliminating synchronous Main Thread loops with `model(for:)` and fixing ModelContext concurrency violations
- Propose exact replacement snippets with line numbers

## Current Parent
- Conversation ID: 7609d953-24ad-485f-ab85-76cf8f2e9fc8
- Updated: not yet

## Investigation State
- **Explored paths**: All 10 target files in Features.Clients, Features.InvoiceTemplateEditor, Features.Settings, Features.Invoices, Features.Calendar, Data, DataInterfaces
- **Key findings**: Concurrency violations found in ServiceAssignmentSheetView, ModernTemplateEditorView, and TravelChargeAutomationTestView. Synchronous main-thread model(for:) loop resolution found in ClientDetailViewModel, PayeeDetailViewModel, PlanManagerDetailViewModel, InvoicesContainerViewModel, ClaimBatchesViewModel, TravelChargeReviewViewModel, and CalendarViewModel.
- **Unexplored areas**: None, all 10 targets successfully analyzed.

## Key Decisions Made
- Use direct batch FetchDescriptors directly on the Main Actor's ModelContext instead of multi-step ID fetches mapped in a synchronous loop.
- Use MainActor.run or task main-actor-isolation for background-to-main actor context mapping to resolve concurrency violations.

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_fetching_1/analysis.md — Data-Fetching Remediation Plan
