## 2026-06-24T00:54:00Z
Implement visual stability and accessibility refinements in the table/cell property inspectors based on Reviewer 2 and Challenger 2 feedback.

Files to modify & changes:

1. Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+SelectionSection.swift:
   - In `TableSelectionSectionView`, replace the conditional `if` blocks for height, width, and padding controls with stable layout structures. Keep these controls always present in the layout hierarchy, but disable and dim them based on sizing modes:
     - The Column Sizing Mode's "Width" stepper control should be modified: instead of `if isColumnModeFixed { ... }`, render the stepper control always. Apply `.disabled(!isColumnModeFixed)` and `.opacity(isColumnModeFixed ? 1.0 : 0.5)` to the control.
     - The Row Sizing Mode's "Height" stepper control should be modified: instead of `if isRowModeFixed { ... }`, render the stepper control always. Apply `.disabled(!isRowModeFixed)` and `.opacity(isRowModeFixed ? 1.0 : 0.5)` to the control.
     - The Spacing & Layout's "Cell Padding" stepper control: instead of `if let cellPadding = currentStyle?.padding { ... }`, render the stepper control always. The value binding should fallback to a safe default if `currentStyle?.padding` is nil. Apply `.disabled(currentStyle?.padding == nil)` and `.opacity(currentStyle?.padding != nil ? 1.0 : 0.5)` to the stepper.

2. Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor.swift:
   - Fix the stats header overflow in minimum-sized inspector panel (220pt).
   - Instead of a single HStack rendering all three stats horizontally (Selection, Scope, Layout), stack them vertically as:
     - Row 1: Selection and Scope in an HStack (each taking `.frame(maxWidth: .infinity)`).
     - Row 2: Layout stat in its own HStack (taking `.frame(maxWidth: .infinity)`).
     This guarantees they fit without text wrapping, clipping, or visual crowding.

3. Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/AlignmentGridPicker.swift:
   - Compute a descriptive accessibility label for each button inside `AlignmentButton` based on the horizontal and vertical alignment:
     ```swift
     private var alignmentDescription: String {
         let hLabel: String
         switch horizontal {
         case .leading: hLabel = "Left"
         case .center: hLabel = "Center"
         case .trailing: hLabel = "Right"
         }
         
         let vLabel: String
         switch vertical {
         case .top: vLabel = "Top"
         case .center: vLabel = "Middle"
         case .bottom: vLabel = "Bottom"
         }
         return "\(vLabel) \(hLabel) Alignment"
     }
     ```
     Apply `.accessibilityLabel(alignmentDescription)` to the `Button`.

4. Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/Components/InspectorTypographyAndStepper.swift:
   - Add `.accessibilityLabel(suffix.isEmpty ? "Value" : "\(suffix) value")` directly to the `TextField` inside `InspectorStepper` so screen readers describe it when focused.

5. Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/Components/InspectorContentLayout.swift:
   - In `SectionHeaderButton`, add `.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")` and `.accessibilityHint("Double tap to toggle visibility")` to the disclosure button.

6. Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/Components/InspectorAccordionSection.swift:
   - In `InspectorGroupBox`, add `.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")` and `.accessibilityHint("Double tap to toggle visibility")` to the header toggle button.

Verification:
- Run all tests using: `swift test --package-path Packages/Feature.InvoiceTemplateEditor` and `bash scripts/refactor-verify.sh`.
- Ensure everything compiles clean and all 86 tests pass.
