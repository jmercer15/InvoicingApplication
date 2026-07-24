## 2026-06-10T01:53:59Z
You are auditor_clients. Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/auditor_clients`.
Objective: Perform a forensic audit on the Clients changes to verify that the implementation is authentic.
Scope boundaries: Inspect the modified files and verify that no hardcoding of test results or fake/dummy implementations were used.
Input information:
- Refer to the Clients worker's handoff report at `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_clients_gen2/handoff.md`.
- Audit targets are the files modified in `Packages/Feature.Clients`.
Output requirements: Write an audit report at `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/auditor_clients/handoff.md` with a verdict of CLEAN or VIOLATION/CHEATING DETECTED.
Completion criteria: Systematic inspection of modified views completes, and report is written.
