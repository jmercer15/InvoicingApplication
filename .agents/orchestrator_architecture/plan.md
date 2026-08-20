# Orchestrator Architecture Plan

## Objective
Produce a comprehensive architectural analysis and actionable refactoring plan (`REFACTOR_PLAN.md`) for InvoicingApplication.

## Strategy
1. **Phase 1: Exploration & Analysis**
   - Spawn 3 parallel `teamwork_preview_explorer` subagents to analyze the repository:
     - **Explorer 1 (`teamwork_preview_explorer_1`)**: Focus on `Packages/Feature.Invoices` and `Packages/Feature.InvoiceTemplateEditor` (UI features, data flow, component boundaries, state management, duplicated UI components).
     - **Explorer 2 (`teamwork_preview_explorer_2`)**: Focus on `Packages/Domain.*` and `Packages/Core.*` / shared packages (domain entities, persistence/SwiftData, data flow bottlenecks, duplicated models/logic).
     - **Explorer 3 (`teamwork_preview_explorer_3`)**: Focus on overall project structure, app entry point `InvoicingApplication`, scripts (`scripts/architecture-check.sh`, etc.), build configurations, file organization, and cross-package dependencies.
   - Aggregate findings in `.agents/orchestrator_architecture/synthesis.md`.

2. **Phase 2: Refactor Plan Drafting**
   - Spawn a `teamwork_preview_worker` (`worker_architecture_plan`) to write `/Users/user/Developer/InvoicingApplication/InvoicingApplication/REFACTOR_PLAN.md`.
   - Require explicit file paths, macro/micro classification, structural changes, file reorganizations, and code deduplication strategies (identifying at least 3 concrete consolidation areas).

3. **Phase 3: Verification & Auditing**
   - Spawn `teamwork_preview_reviewer` and `teamwork_preview_auditor` to evaluate `REFACTOR_PLAN.md` against requirements and check existing test suites (`swift test`, `xcodebuild test`, `./scripts/architecture-check.sh`).

4. **Phase 4: Sentinel Notification**
   - Send final completion report to Sentinel via `send_message`.
