# DISPATCH — Explorer M1 Fix (SwiftDataStoreChangeMonitorTests Async Race Condition)

## Objective
Investigate test failure in `Packages/Data/Tests/DataTests/Services/SwiftDataStoreChangeMonitorTests.swift:33`:
- Test: `ContainerLevelMonitorObservesSavesFromIndependentContexts`
- Failure: `Expectation failed: observedRevisions.max() ?? 0 >= 2`
- Analysis from Challenger 2:
  - Lines 29-33:
    ```swift
    settingsContext.insert(Business(abn: "22 222 222 222"))
    try settingsContext.save()
    try await waitForRevision(monitor, atLeast: 2)

    #expect(observedRevisions.max() ?? 0 >= 2)
    ```
  - `waitForRevision` awaits `monitor.revision >= 2`, but `observedRevisions` array is updated in the `onRevisionChange` async callback/closure. When `monitor.revision` increments, `observedRevisions` callback may not have appended the new element yet before line 43 checks `observedRevisions`.
- Inspect `SwiftDataStoreChangeMonitorTests.swift` and `SwiftDataStoreChangeMonitor.swift` (or relevant service code) to understand how `waitForRevision` or `observedRevisions` synchronization works and recommend a thread-safe / deterministic assertion fix (e.g., waiting for `observedRevisions.count >= 2` or syncing array append before checking expectation).

## References
- Challenger 2 report: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/challenger_m1_2/handoff.md`
- Gate status: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_refactor/GATE_STATUS.md`

## Output
Write fix strategy to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m1_fix/handoff.md`.
