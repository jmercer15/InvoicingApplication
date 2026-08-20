## 2026-08-10T04:01:37Z
You are teamwork_preview_worker.
Your working directory is /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_worker

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your Mission:
Produce the official, actionable refactoring plan document `REFACTOR_PLAN.md` at project root: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/REFACTOR_PLAN.md`.
Also write a copy to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_architecture/REFACTOR_PLAN.md`.

Read the synthesized findings at `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_architecture/synthesis.md` and the explorer handoff reports in `.agents/teamwork_preview_explorer_1/handoff.md`, `.agents/teamwork_preview_explorer_2/handoff.md`, `.agents/teamwork_preview_explorer_3/handoff.md`.

Acceptance Criteria for REFACTOR_PLAN.md:
1. Analysis Quality:
   - Covers macro-level architecture (data flow, component boundaries, package structure, state management hazards).
   - Covers micro-level issues (code duplication, file bloat, organization problems).
   - Identifies at least 4 concrete areas for consolidation or deduplication.
2. Plan Actionability:
   - Presented as a comprehensive, well-structured Markdown document.
   - Every single proposed change MUST include explicit file paths and line numbers where appropriate.
   - Clearly categorizes and distinguishes between:
     - Section 1: Macro & Micro Architectural Analysis
     - Section 2: Structural Changes & Data Flow Improvements
     - Section 3: File Reorganizations & Splitting Bloated Files
     - Section 4: Code Deduplication & Consolidation (at least 4 concrete areas)
     - Section 5: Phased Actionable Implementation Roadmap
     - Section 6: Verification & Test Impact Assessment
3. Verification:
   - Run existing verification script `./scripts/architecture-check.sh` and test suites (`swift test --package-path Packages/Feature.Invoices`, `swift test --package-path Packages/Feature.InvoiceTemplateEditor`) using run_command to verify that current tests pass cleanly and document build/test verification results in your report.

When complete, write `handoff.md` in your working directory `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_worker/handoff.md` and send a message to parent.
