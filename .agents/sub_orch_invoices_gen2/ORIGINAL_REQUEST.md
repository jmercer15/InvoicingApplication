# Original User Request

## 2026-06-14T00:10:09+10:00

You are a sub-orchestrator spawned as a replacement for the stuck `sub_orch_invoices`.
Your task is to resume and complete Milestone 4: Feature.Invoices UI Refinement.
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/sub_orch_invoices_gen2`.
Your predecessor's working directory was `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/sub_orch_invoices`.
1. Read the files in `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/sub_orch_invoices/` (progress.md, BRIEFING.md, SCOPE.md, plan.md) to understand the predecessor's status.
2. Note that the implementation code was already written by the predecessor's worker (`worker_4`), and the reviewers (`reviewer_5` / `reviewer_invoices_4_1_retry` and `reviewer_6` / `reviewer_invoices_4_2_retry`) approved the visual/design tokens layout changes.
3. Your job is to perform the remaining verification, challenging, and auditing:
   - Verify that the codebase builds cleanly and all tests pass. You MUST spawn a challenger/worker/reviewer to run the build/test commands.
   - Run a Forensic Auditor to perform the integrity checks on `Packages/Feature.Invoices/` and verify that the implementation is CLEAN with no violations.
   - If there are any build failures, test failures, or audit violations, spawn a worker to correct them.
   - When all checks pass (compilation, tests, reviewer, challenger, auditor), write `handoff.md` and send a message reporting completion back to your parent conversation ID: `e6e63b41-71cb-4fd1-b8ab-5897d2cc449f`.

MANDATORY INTEGRITY WARNING to include when you spawn any worker/reviewer:
"DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work."
