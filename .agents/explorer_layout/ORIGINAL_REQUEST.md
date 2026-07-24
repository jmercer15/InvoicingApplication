## 2026-06-30T08:50:55Z
Objective: Explore the codebase to locate files and logic related to Bug 1 (vertical layout undercount) and Bug 2 (horizontal layout undercount).
Working Directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_layout/
Target Directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication
Role: Codebase Explorer

Please perform the following:
1. Initialize your BRIEFING.md and progress.md in your working directory.
2. Locate the following files and trace the relevant logic:
   - File 1: `LeafComponentFrameSizing.swift` (find `intrinsicVerticalSize`, `contentVerticalSize`, and `estimatedSingleLineAutoRowHeight`).
   - File 2: `InvoiceComponent.swift` (find `minIntrinsicWidth` and check how columns are summed and check for missing border width).
   - File 3: `DocumentGridComponent.swift` and `DocumentGridComponent+AnalyticHeight.swift` or similar files (find `analyticGridHeight`, `effectiveGridHeight`, and `resolvedGridLayoutWidth`, and see how they calculate height and width).
   - File 4: `SectionSplit.swift` and `FlexibleSizeCalculator.swift` (understand how they use `intrinsicSizeForChild`).
3. Explain:
   - Why `component.idealSize?.height` is nil on the first layout pass.
   - Why `estimatedSingleLineAutoRowHeight × rowCount` is used as a fallback, and why it causes under-allocation when multi-line content exists.
   - How `analyticGridHeight` or `effectiveGridHeight` can be used synchronously or calculated on the model level (or if `LeafComponentFrameSizing` has enough information to compute it).
   - How `minIntrinsicWidth` calculates the width and where the border width is missing.
4. Document the exact line numbers and code snippets.
5. Suggest a concrete strategy for fixing both Bug 1 and Bug 2 without introducing first-pass layout jitter or compilation errors.
6. Write your findings to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_layout/handoff.md` and report back.
