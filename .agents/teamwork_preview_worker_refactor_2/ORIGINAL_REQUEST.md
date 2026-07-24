## 2026-06-18T12:37:12Z
You are the Template Editor Refactoring Worker 2. Your task is to implement further hardening of the geometry logic in the template editor layout package.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT
hardcode test results, create dummy/facade implementations, or
circumvent the intended task. A Forensic Auditor will independently
verify your work. Integrity violations WILL be detected and your
work WILL be rejected.

Please perform the following refactoring steps:

1. **FlexibleSizeCalculator.swift**:
   - In `calculateSizes` (around line 34), clamp intrinsic sizes to be non-negative:
     Replace:
     ```swift
     let size = intrinsicSizes[i] ?? 50 // Default min size if unknown
     ```
     With:
     ```swift
     let size = max(0, intrinsicSizes[i] ?? 50) // Default min size if unknown
     ```
   - At the end of `calculateSizes` (around line 252), explicitly protect the output sizes array against `NaN` and `Infinity` inputs/computations:
     Replace:
     ```swift
     for i in 0..<count {
         sizes[i] = max(0, sizes[i])
     }
     ```
     With:
     ```swift
     for i in 0..<count {
         let val = sizes[i]
         sizes[i] = (val.isNaN || val.isInfinite) ? 0 : max(0, val)
     }
     ```

2. **ResizeHelpers.swift**:
   - Guard `scaleFactor` calculation (around line 69) against division-by-zero if `finalTotal` is 0 or negative:
     Replace:
     ```swift
     let finalTotal = newCurrentRatio + newNextRatio
     let scaleFactor = totalRatio / finalTotal
     ```
     With:
     ```swift
     let finalTotal = newCurrentRatio + newNextRatio
     let scaleFactor = finalTotal > 0 ? totalRatio / finalTotal : 1.0
     ```

3. **Verify and Update Tests**:
   - Check if `LayoutAdversarialTests.swift` has a test asserting that negative intrinsic sizes expand the container. If so, update the assertion to confirm that negative intrinsic sizes are now safely clamped to 0 (and do not expand the container).
   - Run package tests using: `swift test --package-path Packages/Feature.InvoiceTemplateEditor`
   - Run main app build/test to confirm no regression.

Write a detailed handoff report when complete at `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_worker_refactor_2/handoff.md` and send a message back to the orchestrator (conversation ID: 25125e7b-460a-4052-bf62-f389b7dfa12e).

Your workspace directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_worker_refactor_2/`.
