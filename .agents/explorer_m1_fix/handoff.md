# Handoff Report — Explorer M1 Fix (SwiftDataStoreChangeMonitorTests Async Race Condition)

## 1. Observation

### Test Failure Context
- **Script**: `./scripts/refactor-verify.sh` (fails during full multi-package test suite execution)
- **Failing File**: `Packages/Data/Tests/DataTests/Services/SwiftDataStoreChangeMonitorTests.swift`
- **Failing Test**: `ContainerLevelMonitorObservesSavesFromIndependentContexts()`
- **Error Line**: `SwiftDataStoreChangeMonitorTests.swift:33:9`
- **Verbatim Error Output**:
  ```text
  􀢄  Test ContainerLevelMonitorObservesSavesFromIndependentContexts() recorded an issue at SwiftDataStoreChangeMonitorTests.swift:33:9: Expectation failed: observedRevisions.max() ?? 0 >= 2
  􀄵  observedRevisions.max() ?? 0 >= 2 → false
  􀄵    observedRevisions.max() ?? 0 → 1
  􀢄  Test ContainerLevelMonitorObservesSavesFromIndependentContexts() failed after 1.038 seconds with 1 issue.
  ```

### Code Analysis
1. `Packages/Data/Tests/DataTests/Services/SwiftDataStoreChangeMonitorTests.swift`:
   ```swift
   16: var observedRevisions: [Int] = []
   17: monitor.onRevisionChange { revision in
   18:     observedRevisions.append(revision)
   19: }
   ...
   29: settingsContext.insert(Business(abn: "22 222 222 222"))
   30: try settingsContext.save()
   31: try await waitForRevision(monitor, atLeast: 2)
   32: 
   33: #expect(observedRevisions.max() ?? 0 >= 2)
   ```
2. Helper method in `SwiftDataStoreChangeMonitorTests.swift`:
   ```swift
   36: private func waitForRevision(
   37:     _ monitor: SwiftDataStoreChangeMonitor,
   38:     atLeast expected: Int,
   39:     timeout: TimeInterval = 5.0
   40: ) async throws {
   41:     let deadline = Date().addingTimeInterval(timeout)
   42:     while monitor.revision < expected {
   43:         if Date() >= deadline {
   44:             Issue.record("Expected revision >= \(expected), got \(monitor.revision)")
   45:             return
   46:         }
   47:         await Task.yield()
   48:         try await Task.sleep(nanoseconds: 10_000_000)
   49:     }
   50: }
   ```
3. Callback mechanism in `Packages/Data/Sources/Data/Services/SwiftDataStoreChangeMonitor.swift`:
   ```swift
   53: public func onRevisionChange(_ handler: @escaping @MainActor (Int) -> Void) {
   54:     beginRevisionObservation(handler: handler)
   55:     handler(revision)
   56: }
   57: 
   58: private func beginRevisionObservation(handler: @escaping @MainActor (Int) -> Void) {
   59:     withObservationTracking {
   60:         _ = revision
   61:     } onChange: { [weak self] in
   62:         Task { @MainActor in
   63:             guard let self else { return }
   64:             handler(self.revision)
   65:             self.beginRevisionObservation(handler: handler)
   66:         }
   67:     }
   68: }
   ```

---

## 2. Logic Chain

1. **Observation**: `SwiftDataStoreChangeMonitor` uses `@Observable` for `revision` and handles subscriptions via `onRevisionChange`.
2. **Observation**: When `self.revision &+= 1` is called inside `scheduleRevisionBump`, Swift's `withObservationTracking` `onChange` closure runs **synchronously**.
3. **Observation**: Inside `onChange`, a new asynchronous task is dispatched to `@MainActor`: `Task { @MainActor in handler(self.revision); ... }`.
4. **Observation**: In `SwiftDataStoreChangeMonitorTests.swift`, `waitForRevision(monitor, atLeast: 2)` loops while `monitor.revision < 2`.
5. **Observation**: As soon as `self.revision &+= 1` sets `monitor.revision` to 2 on `@MainActor`, `waitForRevision` observes `monitor.revision == 2` and exits its `while` loop immediately.
6. **Observation**: Control in the test proceeds directly to line 33: `#expect(observedRevisions.max() ?? 0 >= 2)`.
7. **Logical Inference**: Because line 33 executes in the same event loop turn right after `monitor.revision` is set, the asynchronous `Task` enqueued by `onChange` to append `2` to `observedRevisions` has not yet executed on `@MainActor`.
8. **Logical Inference**: Under concurrent multi-package test suite execution (`./scripts/refactor-verify.sh`), `observedRevisions` is still `[0, 1]` when line 33 executes, causing `observedRevisions.max() ?? 0` to evaluate to `1` and fail the assertion.
9. **Conclusion**: The test fails because `waitForRevision` synchronizes on internal state (`monitor.revision`) rather than waiting for the consumer callback array (`observedRevisions`) to append the expected revision.

---

## 3. Caveats

- **Read-Only Scope**: Per subagent instructions, no source code or test files were directly modified during this investigation.
- **Production Code Status**: `SwiftDataStoreChangeMonitor.swift` implementation is correct and does not require modification; the race condition is entirely within test assertion synchronization.
- **Isolation behavior**: Running `SwiftDataStoreChangeMonitorTests` in isolation (`swift test --package-path Packages/Data --filter SwiftDataStoreChangeMonitorTests`) passes because low MainActor task queue load allows the microtask to complete fast enough; the failure manifests under full test suite load (`./scripts/refactor-verify.sh`).

---

## 4. Conclusion

### Fix Strategy
Update `Packages/Data/Tests/DataTests/Services/SwiftDataStoreChangeMonitorTests.swift` so `waitForRevision` synchronizes on `observedRevisions` reaching `expected` (or both `monitor.revision` AND `observedRevisions`).

### Proposed Code Change (Patch)

**Target File**: `Packages/Data/Tests/DataTests/Services/SwiftDataStoreChangeMonitorTests.swift`

```swift
<<<<
        workspaceContext.insert(Business(abn: "11 111 111 111"))
        try workspaceContext.save()
        try await waitForRevision(monitor, atLeast: 1)
        try await Task.sleep(for: .milliseconds(100))

        settingsContext.insert(Business(abn: "22 222 222 222"))
        try settingsContext.save()
        try await waitForRevision(monitor, atLeast: 2)

        #expect(observedRevisions.max() ?? 0 >= 2)
    }

    private func waitForRevision(
        _ monitor: SwiftDataStoreChangeMonitor,
        atLeast expected: Int,
        timeout: TimeInterval = 5.0
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while monitor.revision < expected {
            if Date() >= deadline {
                Issue.record("Expected revision >= \(expected), got \(monitor.revision)")
                return
            }
            await Task.yield()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
====
        workspaceContext.insert(Business(abn: "11 111 111 111"))
        try workspaceContext.save()
        try await waitForRevision(monitor, observedRevisions: observedRevisions, atLeast: 1)

        settingsContext.insert(Business(abn: "22 222 222 222"))
        try settingsContext.save()
        try await waitForRevision(monitor, observedRevisions: observedRevisions, atLeast: 2)

        #expect(observedRevisions.max() ?? 0 >= 2)
    }

    private func waitForRevision(
        _ monitor: SwiftDataStoreChangeMonitor,
        observedRevisions: @autoclosure () -> [Int],
        atLeast expected: Int,
        timeout: TimeInterval = 5.0
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while monitor.revision < expected || (observedRevisions().max() ?? 0) < expected {
            if Date() >= deadline {
                Issue.record("Expected revision >= \(expected), got monitor.revision \(monitor.revision), observedRevisions max \(observedRevisions().max() ?? 0)")
                return
            }
            await Task.yield()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
>>>>
```

### Key Benefits of this Fix Strategy
1. **Deterministic Execution**: `waitForRevision` now polls until `observedRevisions` actually receives the callback notification for `expected`.
2. **Eliminates Arbitrary Sleep**: Removes `try await Task.sleep(for: .milliseconds(100))` since waiting on `observedRevisions` makes hardcoded delays redundant.
3. **No Risk to Production**: No changes to production `SwiftDataStoreChangeMonitor.swift`.

---

## 5. Verification Method

To verify the fix once implemented:

```bash
# 1. Run full refactor verification script with sandbox bypass on macOS
./scripts/refactor-verify.sh

# 2. Alternatively run Data package tests
swift test --package-path Packages/Data --filter SwiftDataStoreChangeMonitorTests
```

### Invalidation Conditions
- If `./scripts/refactor-verify.sh` exits with non-zero code or records any issue in `SwiftDataStoreChangeMonitorTests`, the fix is invalid.
