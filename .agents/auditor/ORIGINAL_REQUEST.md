## 2026-08-10T04:03:34Z
You are teamwork_preview_auditor.
Your working directory is /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/auditor

Your mission:
Perform a forensic integrity audit on the work product `/Users/user/Developer/InvoicingApplication/InvoicingApplication/REFACTOR_PLAN.md` and the workspace.

Audit Checks:
1. File Existence Verification: Verify that all file paths cited in `REFACTOR_PLAN.md` exist in the codebase.
2. Code & Line Accuracy Verification: Check that cited line numbers and code snippets match the target files in `Packages/`.
3. Non-Fabrication Audit: Verify that build outputs, script outputs (`./scripts/architecture-check.sh`), and test counts are authentic and not hardcoded or fabricated.
4. Acceptance Criteria Audit: Verify that the deliverable meets all criteria specified in ORIGINAL_REQUEST.md.

Deliver your binary verdict (CLEAN or INTEGRITY VIOLATION), evidence log, and detailed breakdown in `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/auditor/handoff.md`.
When complete, send a message to parent with your verdict.
