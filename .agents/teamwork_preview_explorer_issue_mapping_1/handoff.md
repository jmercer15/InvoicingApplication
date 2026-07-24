# Handoff Report — performance_bottlenecks_scan

## 1. Observation
- Observed two structural layout issues with standard vertical stack inside a ScrollView wrapping a ForEach over potentially large collections:
  - `DocumentOutlinePanel.swift` at lines 14-15: `ScrollView { VStack(...) { ForEach(outline) { node in`
  - `NativeAddressSearchField.swift` at lines 109-111: `ScrollView { VStack(...) { ForEach(0..<service.searchResults.count) { index in`
- Observed one nested ScrollView on the same axis issue:
  - `ImportExportView.swift` at lines 351-358 nested inside the main view `ScrollView` (line 369): `SettingsCard(title: "Details") { ScrollView { LazyVStack(...) { ... } } }`
- Observed GeometryReader preference updating layout that registers undo events on layout/render passes:
  - `DocumentGridComponent+Layout.swift` at lines 55-58 in `updateComponentHeight`:
    ```swift
    document.saveStateForUndo(actionName: "Resize Table")
    document.updateComponent(id: currentComponent.id) { component in
        component.size.height = height
    }
    ```
- Observed multiple synchronous model resolution loops via `modelContext.model(for:)` executing on the `@MainActor` or background cooperative threads (causing concurrency warnings and/or blocking the Main Thread):
  - `ClientDetailViewModel+Loading.swift` (lines 23-25, 43-44)
  - `PayeeDetailViewModel.swift` (lines 98-99)
  - `PlanManagerDetailViewModel.swift` (lines 90-91)
  - `ServiceAssignmentSheetView.swift` (line 66) — accesses main thread context on background cooperative task thread.
  - `InvoicesContainerViewModel+List.swift` (line 35)
  - `ClaimBatchesViewModel.swift` (lines 49, 59)
  - `TravelChargeAutomationTestView.swift` (lines 127-128) — concurrency violation (accessing context on background task).
  - `TravelChargeReviewViewModel.swift` (line 51)
  - `CalendarViewModel+Fetching.swift` (line 174)
  - `ModernTemplateEditorView.swift` (lines 63-64) — concurrency violation.

---

## 2. Logic Chain
1. *Layout Performance*: Eager stacks (`VStack`/`HStack`) inside a scroll view instantiate all child views on the first render pass. For collections with unbounded data (such as address search queries or outline document nodes), this blocks the Main Thread and causes noticeable scroll stutter. Replacing these with `LazyVStack` deferments resolves this issue.
2. *Nested Scrolling*: Standard SwiftUI nested scroll views within the same orientation confuse the physics and measurement of the parent scroll area. Restricting the inner scroll height or presenting it in an independent modal sheet avoids layout ambiguity.
3. *Undo History Pollution*: Triggering model updates that register undo actions (`saveStateForUndo`) in response to automatically measured layout changes (`GeometryReader`) pollutes the system's `UndoManager`. This destroys the user's undo history of actual edits, since layout passes push auto-sized undo blocks. Additionally, this layout-modify-layout cycle causes duplicate layout sweeps.
4. *Main-Thread Blockers*: `modelContext.model(for:)` performs database entity lookups. Mapping large arrays of IDs in synchronous loops on the `@MainActor` blocks UI interaction during view transitions/setup.
5. *SwiftData Concurrency*: Invoking `modelContext.model(for:)` inside background tasks without main actor isolation accesses the context from background threads, directly violating SwiftData's thread isolation guarantees.

---

## 3. Caveats
- Checked static swift codebase code; did not run runtime Instruments time profilers to measure exact millisecond impacts.
- Assumed standard SwiftData concurrency rules (ModelContext is strictly bound to its creator thread, which is typically the main thread for `@Query` or views' `modelContext`).
- Did not modify code, in accordance with the read-only audit constraint.

---

## 4. Conclusion
The codebase contains multiple layout bottlenecks, undo stack pollution points, and main-thread synchronous queries. Correcting these in a subsequent implementer run will resolve frame drops during template editing, calendar navigation, and relationship lookups, while restoring normal undo/redo behaviors.

---

## 5. Verification Method
- Execute the verification build script: `bash scripts/refactor-verify.sh`.
- Review the analysis report: `cat .agents/teamwork_preview_explorer_issue_mapping_1/analysis.md` to locate exact file and line mappings.
- Concurrency warnings can be observed under Xcode with Strict Concurrency Checking enabled.
