## 2026-06-18T12:32:31Z
You are the Template Editor Refactoring Worker. Your task is to refactor the template editor layout, sizing, and geometry logic to resolve identified bugs and prevent division-by-zero or negative geometry issues.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT
hardcode test results, create dummy/facade implementations, or
circumvent the intended task. A Forensic Auditor will independently
verify your work. Integrity violations WILL be detected and your
work WILL be rejected.

Please perform the following refactoring steps:

1. **FlexibleSizeCalculator.swift (R1 Layout Sizing)**:
   - In `calculateSizes` (around line 211), replace the incorrect `else if usedFixedSpace > flexibleSpace` block with a corrected structure that handles both overflow scaling and redistribution of unused space:
     ```swift
     } else {
         // No expand items, and we might have unused space or overflow.
         if usedFixedSpace > flexibleSpace {
             // Normalize / scale down Fixed items
             let scale = usedFixedSpace > 0 ? flexibleSpace / usedFixedSpace : 0
             for i in 0..<count {
                 let isFixed = i < sizingModes.count ? (sizingModes[i] == .fixed) : true
                 if isFixed {
                     sizes[i] *= scale
                 }
             }
         } else if usedFixedSpace < flexibleSpace {
             // Re-distribute remaining flexible space to Fixed items proportionally to their ratios.
             let remainingUnused = flexibleSpace - usedFixedSpace
             if remainingUnused > 0 {
                 // Sum of ratios of Fixed items
                 var totalFixedRatio: CGFloat = 0
                 for i in 0..<count {
                     let isFixed = i < sizingModes.count ? (sizingModes[i] == .fixed) : true
                     if isFixed {
                         totalFixedRatio += (i < ratios.count) ? ratios[i] : 0
                     }
                 }
                 
                 if totalFixedRatio > 0 {
                     for i in 0..<count {
                         let isFixed = i < sizingModes.count ? (sizingModes[i] == .fixed) : true
                         if isFixed {
                             let ratio = (i < ratios.count) ? ratios[i] : 0
                             let extra = remainingUnused * (ratio / totalFixedRatio)
                             sizes[i] += extra
                         }
                     }
                 }
             }
         }
     }
     ```

2. **SectionSplit+ComponentRegistry.swift (R2 Division by Zero)**:
   - In `rowColumn(for cellIndex: Int)` (around line 111), clamp the divisor `gridColumns` to at least 1 using `max(1, gridColumns)` to prevent runtime division-by-zero crashes:
     ```swift
     func rowColumn(for cellIndex: Int) -> (row: Int, column: Int) {
         let cols = max(1, gridColumns)
         let row = cellIndex / cols
         let column = cellIndex % cols
         return (row: row, column: column)
     }
     ```

3. **SectionSplit.swift (R2 Geometry Bounds)**:
   - Ensure `gridRows` and `gridColumns` are clamped to at least 1 in all constructors and decoders to prevent division by zero or infinite size multipliers:
     - In `public init(gridRows: Int, gridColumns: Int, heightRatios: [CGFloat]? = nil, widthRatios: [CGFloat]? = nil)`:
       ```swift
       self.gridRows = max(1, gridRows)
       self.gridColumns = max(1, gridColumns)
       ```
     - In `public init(from decoder: Decoder) throws`:
       ```swift
       let decodedGridRows = try container.decodeIfPresent(Int.self, forKey: .gridRows) ?? 2
       gridRows = max(1, decodedGridRows)
       let decodedGridColumns = try container.decodeIfPresent(Int.self, forKey: .gridColumns) ?? 2
       gridColumns = max(1, decodedGridColumns)
       ```

4. **Verify Implementation**:
   - Run build command: `swift build --package-path Packages/Feature.InvoiceTemplateEditor`
   - Run tests command: `swift test --package-path Packages/Feature.InvoiceTemplateEditor`
   - Ensure the package builds cleanly with no new errors or warnings, and all existing tests pass.

Write a detailed handoff report when complete at `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_worker_refactor_1/handoff.md` and send a message back to the orchestrator (conversation ID: 25125e7b-460a-4052-bf62-f389b7dfa12e).

Your workspace directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_worker_refactor_1/`.
