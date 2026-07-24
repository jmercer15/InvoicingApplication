# Context — Invoice Template Editor layout and sizing refactoring

## Target Package
- `Feature.InvoiceTemplateEditor`

## Key Source Files
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/FlexibleSizeCalculator.swift`
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayout.swift`
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/SplittableRectangleView.swift`
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/GridSplitView.swift`
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/LinearSplitView.swift`
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Layout/SectionSplit+ComponentRegistry.swift`
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Layout/SectionSplit.swift`

## Target Tests
- `Feature_InvoiceTemplateEditorTests`
- Files:
  - `DefaultInvoiceTemplateTests.swift`
  - `SectionSplitGridMutationTests.swift`

## Findings and Discovered Logic Bugs
1. **FlexibleSizeCalculator.swift (R1 Layout Sizing)**:
   - There is a logic error in `calculateSizes`:
     ```swift
     } else if usedFixedSpace > flexibleSpace {
         let remainingUnused = flexibleSpace - usedFixedSpace
         if remainingUnused > 0 { ... }
     }
     ```
     This block is unreachable because `remainingUnused > 0` requires `usedFixedSpace < flexibleSpace`, which contradicts the `else if` condition.
     - Fixed items are never scaled down if they overflow.
     - Unused space is never redistributed to Fixed items when there are no Expand items if `usedFixedSpace < flexibleSpace`.
     - *Fix*: Structure the `else` block to check `usedFixedSpace > flexibleSpace` (scale down) vs `usedFixedSpace < flexibleSpace` (redistribute unused space).

2. **SectionSplit+ComponentRegistry.swift (R2 Division by Zero)**:
   - `rowColumn(for:)` performs `cellIndex / gridColumns` and `cellIndex % gridColumns`. If `gridColumns` is 0, this causes a crash.
   - *Fix*: Clamp the divisor to `max(1, gridColumns)`.

3. **SectionSplit.swift (R2 Geometry Bounds)**:
   - Grid dimensions `gridRows` and `gridColumns` can be initialized or decoded to 0 or negative values, leading to division by zero or infinite proportions (`1.0 / CGFloat(gridRows)`).
   - *Fix*: Ensure both `gridRows` and `gridColumns` are clamped to `max(1, value)` in all initializers, mutators, and custom decoders.

