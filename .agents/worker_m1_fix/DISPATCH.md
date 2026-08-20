# DISPATCH — Worker M1 Fix (SwiftDataStoreChangeMonitorTests Fix)

## Objective
Apply the test fix to `Packages/Data/Tests/DataTests/Services/SwiftDataStoreChangeMonitorTests.swift` as detailed in Explorer M1 Fix report:
- Update `waitForRevision` helper in `SwiftDataStoreChangeMonitorTests.swift` so it awaits both `monitor.revision >= expected` AND `(observedRevisions().max() ?? 0) >= expected`.
- Run `swift test --package-path Packages/Data` to confirm.
- Run `./scripts/refactor-verify.sh` to confirm the entire 14-package test suite passes cleanly with 0 errors and exit code 0.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## References
- Explorer M1 Fix report: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m1_fix/handoff.md`
- Original Request: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/ORIGINAL_REQUEST.md`

## Required Output
Write report with build/test results to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_m1_fix/handoff.md`.
